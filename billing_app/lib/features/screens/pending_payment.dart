import 'package:billing/core/utils/loading.dart';
import 'package:billing/features/providers/bill_provider.dart';
import 'package:billing/features/providers/role_provider.dart';
import 'package:billing/features/screens/deletedBills.dart';

import 'package:billing/features/services/pdfservices.dart';
import 'package:billing/core/widgets/shopserach.dart';
import 'package:billing/features/providers/shop_provider.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import '../models/bill.dart';
import '../services/firestore_services.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dart:io';

import '../models/shop.dart';

class BillExplorerScreen extends ConsumerStatefulWidget {
  const BillExplorerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BillExplorerScreen> createState() => _BillExplorerScreenState();
}

class _BillExplorerScreenState extends ConsumerState<BillExplorerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _billSearchController = TextEditingController();
  final _shopDropdownController = TextEditingController();


  String billSearch = '';

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedShopProvider.notifier).state = null;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _searchController.dispose();
    _billSearchController.dispose();
    _shopDropdownController.dispose();
    super.dispose();
  }

  // Local filtering methods removed as filtering is now done in Firestore

  String classifyStatus(Bill b) {
    // FULL PAID
    if (b.isPaid == true) {
      if (b.upiPayment == true) return "Paid (UPI)";
      return "Paid (Cash)";
    }

    // HALF PAID
    if ((b.paidAmount ?? 0) > 0 && (b.balance ?? 0) > 0) {
      if (b.upiPayment == true) return "Half Paid (UPI)";
      return "Half Paid (Cash)";
    }

    // FULL UNPAID
    return "Unpaid";
  }

  Future<void> _generateReportPdf(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    try {
      final result = await ref
          .read(firestoreServiceProvider)
          .fetchBillsByDate(date);

      List<Bill> created = result["created"] ?? [];
      List<Bill> paidToday = result["paidToday"] ?? [];

      // Load fonts
      final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );
      final fontBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
      );

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );

      // -------------------------------------------------------------
      // CLASSIFY STATUS
      // -------------------------------------------------------------
      String classifyStatus(Bill b) {
        final reportDate = DateTime(date.year, date.month, date.day);

        bool isFullyPaidAsOfReportDate = false;
        if (b.isPaid == true) {
          if (b.markedAsPaidAt != null) {
            final mp = b.markedAsPaidAt!.toDate();
            final markedDate = DateTime(mp.year, mp.month, mp.day);
            if (!markedDate.isAfter(reportDate)) {
              isFullyPaidAsOfReportDate = true;
            }
          } else {
            isFullyPaidAsOfReportDate = true;
          }
        }

        if (isFullyPaidAsOfReportDate) {
          if (b.upiPayment == true) return "Paid (UPI)";
          return "Paid (Cash)";
        }

        bool hasPartialPaymentAsOfReportDate = false;
        if ((b.paidAmount) > 0) {
          if (b.paidTodayAt != null) {
            final pt = b.paidTodayAt!.toDate();
            final ptDate = DateTime(pt.year, pt.month, pt.day);
            if (!ptDate.isAfter(reportDate)) {
              hasPartialPaymentAsOfReportDate = true;
            }
          } else {
            hasPartialPaymentAsOfReportDate = true;
          }
        }

        if (hasPartialPaymentAsOfReportDate && !isFullyPaidAsOfReportDate && b.balance > 0) {
          if (b.upiPayment == true) return "Half Paid (UPI)";
          return "Half Paid (Cash)";
        }

        return "Unpaid";
      }

      final statusRank = {
        "Paid (UPI)": 0,
        "Paid (Cash)": 1,
        "Half Paid (UPI)": 2,
        "Half Paid (Cash)": 3,
        "Unpaid": 4,
      };

      // Sort bills
      List<Bill> sortBills(List<Bill> bills) {
        bills.sort((a, b) {
          final sa = classifyStatus(a);
          final sb = classifyStatus(b);
          if (statusRank[sa] != statusRank[sb]) {
            return statusRank[sa]!.compareTo(statusRank[sb]!);
          }
          return a.createdAt.compareTo(b.createdAt);
        });
        return bills;
      }

      created = sortBills(created);
      paidToday = sortBills(paidToday);

      // -------------------------------------------------------------
      // ROW BUILDERS
      // -------------------------------------------------------------
      List<List<String>> buildRowsCreated(List<Bill> bills) {
        int i = 1;
        return bills.map((b) {
          final status = classifyStatus(b);
          double displayPaid = b.paidAmount;
          double displayBalance = b.balance;
          
          if (status == "Unpaid") {
              displayPaid = 0.0;
              displayBalance = b.discountedTotal;
          }

          return [
            (i++).toString(),
            b.shopName,
            status,
            (b.discountedTotal).toStringAsFixed(2),
            (displayPaid).toStringAsFixed(2), // cumulative
            (displayBalance).toStringAsFixed(2),
            b.billNumber,
          ];
        }).toList();
      }

      List<List<String>> buildRowsPaidToday(List<Bill> bills) {
        int i = 1;
        return bills.map((b) {
          final status = classifyStatus(b);
          return [
            (i++).toString(),
            b.shopName,
            status,
            (b.discountedTotal).toStringAsFixed(2),
            (b.paidToday).toStringAsFixed(2), // 🔥 Today's paid only
            (b.balance).toStringAsFixed(2),
            b.billNumber,
          ];
        }).toList();
      }

      // -------------------------------------------------------------
      // SUMMARY HELPERS
      // -------------------------------------------------------------
      double fullPaidUPI(List<Bill> bills) => bills
          .where((b) => classifyStatus(b) == "Paid (UPI)")
          .fold(0, (s, b) => s + b.discountedTotal);

      double fullPaidCash(List<Bill> bills) => bills
          .where((b) => classifyStatus(b) == "Paid (Cash)")
          .fold(0, (s, b) => s + b.discountedTotal);

      double halfPaidUPI(List<Bill> bills) => bills
          .where((b) => classifyStatus(b) == "Half Paid (UPI)")
          .fold(0, (s, b) => s + b.paidAmount);

      double halfPaidCash(List<Bill> bills) => bills
          .where((b) => classifyStatus(b) == "Half Paid (Cash)")
          .fold(0, (s, b) => s + b.paidAmount);

      double unpaidTotal(List<Bill> bills) => bills
          .where((b) => classifyStatus(b) == "Unpaid")
          .fold(0, (s, b) => s + b.discountedTotal);

      // NEW: Outstanding paid today
      double outstandingPaidTodayCalc(List<Bill> bills) =>
          bills.fold(0, (s, b) => s + b.paidToday);

      // -------------------------------------------------------------
      // SUMMARY VALUES
      // -------------------------------------------------------------
      final totalPaidUPI_created = fullPaidUPI(created) + halfPaidUPI(created);

      final totalPaidCash_created =
          fullPaidCash(created) + halfPaidCash(created);

      final totalUnpaid_created = unpaidTotal(created);

      final total_created_today =
          totalPaidUPI_created + totalPaidCash_created + totalUnpaid_created;

      // final totalPaidUPI_today =
      //     fullPaidUPI(paidToday) + halfPaidUPI(paidToday);

      // final totalPaidCash_today =
      //     fullPaidCash(paidToday) + halfPaidCash(paidToday);

      // final outstandingToday = outstandingPaidTodayCalc(paidToday);

      final totalPaidUPI_today = paidToday
          .where((b) => b.upiPayment == true)
          .fold(0.0, (s, b) => s + b.paidToday);

      final totalPaidCash_today = paidToday
          .where((b) => b.upiPayment != true)
          .fold(0.0, (s, b) => s + b.paidToday);

      final outstandingToday = paidToday.fold(0.0, (s, b) => s + b.paidToday);

      // -------------------------------------------------------------
      // PDF PAGE
      // -------------------------------------------------------------
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build:
              (context) => [
                pw.Text(
                  "Bills Report - ${DateFormat('dd/MM/yyyy').format(date)}",
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),

                // -----------------------------------
                // Created Bills
                // -----------------------------------
                pw.Text(
                  "Created Bills",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.TableHelper.fromTextArray(
                  headers: [
                    "S.No",
                    "Shop",
                    "Status",
                    "Amount",
                    "Paid",
                    "Balance",
                    "Bill No",
                  ],
                  data: buildRowsCreated(created),
                ),

                pw.SizedBox(height: 25),

                // -----------------------------------
                // Paid Today
                // -----------------------------------
                pw.Text(
                  "Paid Today",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.TableHelper.fromTextArray(
                  headers: [
                    "S.No",
                    "Shop",
                    "Status",
                    "Amount",
                    "Paid Today", // 🔥 UPDATED
                    "Balance",
                    "Bill No",
                  ],
                  data: buildRowsPaidToday(paidToday),
                ),

                pw.SizedBox(height: 25),

                // -----------------------------------
                // Summary
                // -----------------------------------
                pw.Text(
                  "Summary",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),

                pw.Text(
                  "Created Bills Summary",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Text(
                  "Paid UPI Total: \$${totalPaidUPI_created.toStringAsFixed(2)}",
                ),
                pw.Text(
                  "Paid Cash Total: \$${totalPaidCash_created.toStringAsFixed(2)}",
                ),
                pw.Text(
                  "Unpaid Total: \$${totalUnpaid_created.toStringAsFixed(2)}",
                ),
                pw.Text(
                  "Total Sale Today: \$${total_created_today.toStringAsFixed(2)}",
                ),

                pw.SizedBox(height: 20),

                pw.Text(
                  "Paid Today Summary",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.Text(
                  "Paid UPI Today: \$${totalPaidUPI_today.toStringAsFixed(2)}",
                ),
                pw.Text(
                  "Paid Cash Today: \$${totalPaidCash_today.toStringAsFixed(2)}",
                ),

                pw.Text(
                  "Outstanding Paid Today: \$${outstandingToday.toStringAsFixed(2)}",
                ),
              ],
        ),
      );

      // -------------------------------------------------------------
      // SAVE & OPEN
      // -------------------------------------------------------------
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        "${dir.path}/Bills_Report_${DateFormat('ddMMyyyy').format(date)}.pdf",
      );

      await file.writeAsBytes(await pdf.save());
      await OpenFilex.open(file.path);
    } catch (e, st) {
      print("PDF ERROR: $e");
      print(st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreServiceProvider);
    final paidBillsAsync = ref.watch(paidBillsProvider);
    final unpaidBillsAsync = ref.watch(unpaidBillsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      appBar: AppBar(
        title: const Text(
          'Bill Explorer',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 2, 113, 192),
        bottom: TabBar(
          labelColor: Colors.orangeAccent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.orangeAccent,
          controller: _tabController,
          tabs: const [
            Tab(text: 'Paid Bills'),
            Tab(text: 'Unpaid Bills'),
            Tab(text: 'Search by Bill No'),
          ],
        ),

        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'deleted') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DeletedBillsScreen()),
                );
              } else if (value == 'pdf') {
                final selectedDate = await showDatePicker(
                  barrierDismissible: false,
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (selectedDate != null) {
                  await showLoadingWhilepdf(
                    context,
                    () => _generateReportPdf(context, ref, selectedDate),
                  );
                }
              } else if (value == 'shop_balance_pdf') {
                final firestore = ref.read(firestoreServiceProvider);
                final allShopsData = await showLoadingWhilepdf(
                  context,
                  () => firestore.fetchAllShopsWithUnpaidBills(),
                );
                if (allShopsData.isNotEmpty) {
                  _showShopSelectionDialog(context, allShopsData);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No shops with unpaid bills found.'),
                    ),
                  );
                }
              } else if (value == 'logout') {
                await ref.read(roleProvider.notifier).logout();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'deleted',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Deleted Bills'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pdf',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf, color: Colors.green),
                      title: Text('Download PDF Report'),
                    ),
                  ),

                  const PopupMenuItem(
                    value: 'shop_balance_pdf',
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf, color: Colors.blue),
                      title: Text('Shop Balance PDF'),
                    ),
                  ),

                  const PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: Color.fromARGB(255, 255, 145, 0),
                      ),
                      title: Text('Logout'),
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_tabController.index != 2)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ShopDropdown(
                controller: _shopDropdownController,
                onSelected: (shop) {
                  // handled by dropdown natively
                },
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    Expanded(
                      child: paidBillsAsync.when(
                        data: (shopsData) {
                          final filtered = shopsData.toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text('No paid bills found for today.'),
                            );
                          }

                          final totalPaidAcrossShops = filtered.fold<double>(
                            0,
                            (sum, shop) =>
                                sum + (shop['totalPaid'] as num).toDouble(),
                          );

                          final totalPaidUpiAcrossShops = filtered.fold<double>(
                            0,
                            (sum, shop) =>
                                sum + (shop['totalPaidUpi'] as num).toDouble(),
                          );

                          final totalPaidCashAcrossShops = filtered.fold<double>(
                            0,
                            (sum, shop) =>
                                sum + (shop['totalPaidCash'] as num).toDouble(),
                          );

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Card(
                                  color: Colors.green.shade50,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Today\'s Total Paid',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '\$ ${totalPaidAcrossShops.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'UPI: \$ ${totalPaidUpiAcrossShops.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'Cash: \$ ${totalPaidCashAcrossShops.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              'Shops:  ',
                                              style: const TextStyle(
                                                fontSize: 16,

                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${filtered.length}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              'Bills:  ',
                                              style: const TextStyle(
                                                fontSize: 14,

                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${filtered.fold<int>(0, (sum, shop) => sum + (shop['count'] as int))}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final shopData = filtered[index];
                                    final shopName =
                                        shopData['shopName'] as String;
                                    final count = shopData['count'] as int;
                                    final paidBills =
                                        shopData['bills'] as List<Bill>;

                                    return ListTile(
                                      title: Text(
                                        shopName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text('Paid Bills: $count'),
                                      trailing: Text(
                                        '\$ ${(shopData['totalPaid'] as num).toDouble().toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                        ),
                                      ),
                                      onTap: () {
                                        _showPaidBillsDialog(
                                          context,
                                          ref,
                                          paidBills,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(
                                color: Color.fromARGB(255, 2, 113, 192),
                              ),
                            ),
                        error: (err, _) => Center(child: Text('Error: $err')),
                      ),
                    ),
                  ],
                ),

                Column(
                  children: [
                    Expanded(
                      child: unpaidBillsAsync.when(
                        data: (shopsData) {
                          final filtered = shopsData.toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text('No unpaid bills found for today.'),
                            );
                          }

                          final totalUnPaidAcrossShops = filtered.fold<double>(
                            0,
                            (sum, shop) =>
                                sum + (shop['totalUnPaid'] as num).toDouble(),
                          );

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Card(
                                  color: Colors.red.shade50,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Today\'s Total Unpaid',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '\$ ${totalUnPaidAcrossShops.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              'Shops:  ',
                                              style: const TextStyle(
                                                fontSize: 16,

                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${filtered.length}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color:
                                                    Colors
                                                        .red, // value has different color
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: 16,
                                            ), // spacing between Shops and Bills
                                            Text(
                                              'Bills:  ',
                                              style: const TextStyle(
                                                fontSize: 14,

                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '${filtered.fold<int>(0, (sum, shop) => sum + (shop['count'] as int))}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color:
                                                    Colors
                                                        .red, // value has different color
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final shopData = filtered[index];
                                    final shopName =
                                        shopData['shopName'] as String;
                                    final count = shopData['count'] as int;
                                    final unpaidBills =
                                        shopData['bills'] as List<Bill>;

                                    return ListTile(
                                      title: Text(
                                        shopName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Text('UnPaid Bills: $count'),
                                      trailing: Text(
                                        '\$ ${(shopData['totalUnPaid'] as num).toDouble().toStringAsFixed(2)}',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onTap: () {
                                        _showUnPaidBillsDialog(
                                          context,
                                          ref,
                                          unpaidBills,

                                          // shopName,
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(
                                color: Color.fromARGB(255, 2, 113, 192),
                              ),
                            ),
                        error: (err, _) => Center(child: Text('Error: $err')),
                      ),
                    ),
                  ],
                ),

                // Search by Bill Number Tab (unchanged)
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        cursorColor: Color.fromARGB(255, 2, 113, 192),
                        controller: _billSearchController,
                        decoration: const InputDecoration(
                          labelText: 'Enter Bill Number',
                          prefixIcon: Icon(Icons.receipt_long),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 2, 113, 192),
                            ),
                          ),
                        ),
                        onSubmitted:
                            (val) => setState(() => billSearch = val.trim()),
                      ),
                    ),
                    Expanded(
                      child:
                          billSearch.isEmpty
                              ? const Center(
                                child: Text('Enter a bill number to search.'),
                              )
                              : FutureBuilder<Bill?>(
                                future: firestore.fetchBillByNumber(billSearch),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color.fromARGB(255, 2, 113, 192),
                                      ),
                                    );
                                  }
                                  if (!snapshot.hasData) {
                                    return const Center(
                                      child: Text('Bill not found.'),
                                    );
                                  }
                                  final bill = snapshot.data!;
                                  return ListView(
                                    children: [
                                      ListTile(
                                        title: Text(
                                          'Bill #: ${bill.billNumber}',
                                        ),
                                        subtitle: Text(
                                          'Shop: ${bill.shopName}',
                                        ),
                                        trailing: Text(
                                          '\$ ${bill.discountedTotal.toStringAsFixed(2)}',
                                        ),
                                        onTap: () {
                                          showFullBillDetailsDialog(
                                            context,
                                            bill,
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaidBillsDialog(
    BuildContext context,
    WidgetRef ref,
    List<Bill> paidBills,
  ) {
    final totalPaid = paidBills.fold<double>(
      0,
      (sum, bill) => sum + bill.discountedTotal,
    );

    final TextEditingController searchController = TextEditingController();
    List<Bill> filteredBills = List.from(paidBills);

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            void filterBills(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredBills = List.from(paidBills);
                } else {
                  filteredBills =
                      paidBills
                          .where(
                            (bill) => bill.billNumber.toLowerCase().contains(
                              query.toLowerCase(),
                            ),
                          )
                          .toList();
                }
              });
            }

            return Dialog(
              insetPadding: EdgeInsets.all(8),

              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey, width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Paid Bills',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      ),
                    ),

                    // Search field
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: searchController,
                        onChanged: filterBills,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: "Search by Bill Number",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bills list
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredBills.length,
                        itemBuilder: (context, index) {
                          final bill = filteredBills[index];
                          return ListTile(
                            dense: true,
                            title: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),

                              child: Row(
                                children: [
                                  Text('${bill.billNumber}'),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(
                                        ClipboardData(text: bill.billNumber),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Copied Bill #${bill.billNumber}',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Icon(
                                      Icons.copy,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            onLongPress: () async {
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (ctx2) => AlertDialog(
                                      backgroundColor: const Color(0xFFE3F2FD),
                                      title: const Text("Delete Bill"),
                                      content: Text(
                                        "Are you sure you want to delete Bill #${bill.billNumber}?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.of(ctx2).pop(true),
                                          child: const Text(
                                            "Delete",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.of(ctx2).pop(false),
                                          child: const Text(
                                            "Cancel",
                                            style: TextStyle(
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );

                              if (shouldDelete == true) {
                                try {
                                  await showLoadingWhileTask(context, () async {
                                    final firestore = ref.read(
                                      firestoreServiceProvider,
                                    );
                                    await firestore.deleteBill(
                                      bill.id,
                                    ); // ONLY delete here
                                  });

                                  // 🔥 After transaction is finished → now refresh providers
                                  ref.invalidate(paidBillsProvider);
                                  ref.invalidate(unpaidBillsProvider);

                                  setState(() {
                                    filteredBills.removeWhere(
                                      (b) => b.id == bill.id,
                                    );
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Deleted Bill #${bill.billNumber}",
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error deleting bill: $e"),
                                    ),
                                  );
                                }
                              }
                            },
                            subtitle: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // ✅ Created At & Marked As Paid At
                                  Text(
                                    bill.markedAsPaidAt != null
                                        ? '${DateFormat('dd MMM yyyy').format(bill.createdAt.toDate())} / ${DateFormat('dd MMM yyyy').format(bill.markedAsPaidAt!.toDate())}'
                                        : DateFormat('dd MMM yyyy').format(bill.createdAt.toDate()),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$ ${bill.discountedTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 14,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await generateAndOpenPdf(bill, false);
                                  },
                                  icon: const Icon(
                                    Icons.download,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Total: \$ ${totalPaid.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showShopSelectionDialog(
    BuildContext context,
    List<Map<String, dynamic>> shopsData,
  ) {
    String searchShop = '';
    // Calculate total unpaid amount across all shops
    final double totalUnpaidAll = shopsData.fold<double>(
      0.0,
      (sum, shop) => sum + (shop['totalUnPaid'] as num).toDouble(),
    );
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredShops =
                shopsData
                    .where(
                      (shop) => shop['shopName']
                          .toString()
                          .toLowerCase()
                          .contains(searchShop.toLowerCase()),
                    )
                    .toList();

            return AlertDialog(
              title: const Text('Select Shop for Pending Bills'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Display total unpaid amount above the search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Total Unpaid: \$${totalUnpaidAll.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search shop...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          searchShop = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredShops.length,
                        itemBuilder: (context, index) {
                          final shop = filteredShops[index];
                          return ListTile(
                            title: Text(shop['shopName']),
                            subtitle: Text(
                              'Pending Balance: \$${(shop['totalUnPaid'] as num).toDouble().toStringAsFixed(2)}',
                            ),
                            onTap: () async {
                              Navigator.pop(dialogContext);
                              await showLoadingWhilepdf(
                                context,
                                () => generateSingleShopPendingBillsPdf(
                                  shop['shopName'],
                                  shop['bills'] as List<Bill>,
                                  (shop['totalUnPaid'] as num).toDouble(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showUnPaidBillsDialog(
    BuildContext context,
    WidgetRef ref,
    List<Bill> unpaidBills,
  ) {
    final role = ref.watch(roleProvider);
    List<Bill> filteredBills = List.from(unpaidBills);
    final TextEditingController searchController = TextEditingController();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
        final selectedBills = <String, Bill>{};
        final TextEditingController _paidAmountController =
            TextEditingController();
        bool? upiPayment; // ✅ null by default

        return StatefulBuilder(
          builder: (context, setState) {
            void filterBills(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredBills = List.from(unpaidBills);
                } else {
                  filteredBills =
                      unpaidBills
                          .where(
                            (bill) => bill.billNumber.toLowerCase().contains(
                              query.toLowerCase(),
                            ),
                          )
                          .toList();
                }
              });
            }

            final totalSelectedBalance = selectedBills.values.fold<double>(
              0,
              (sum, bill) => sum + bill.balance,
            );

            return Dialog(
              insetPadding: const EdgeInsets.all(8),
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // ─── Header ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey, width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Unpaid Bills",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      ),
                    ),

                    // ─── Search ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: TextField(
                        controller: searchController,
                        onChanged: filterBills,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: "Search by Bill Number",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                        ),
                      ),
                    ),

                    // ─── Bills List ───────────────────────────
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredBills.length,
                        itemBuilder: (context, index) {
                          final bill = filteredBills[index];
                          final isSelected = selectedBills.containsKey(bill.id);

                          return InkWell(
                            onLongPress: () async {
                              final shouldDelete = await showDialog<bool>(
                                context: context,
                                barrierDismissible: false,
                                builder:
                                    (ctx2) => AlertDialog(
                                      backgroundColor: const Color(0xFFE3F2FD),
                                      title: const Text("Delete Bill"),
                                      content: Text(
                                        "Are you sure you want to delete Bill #${bill.billNumber}?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.of(ctx2).pop(true),
                                          child: const Text(
                                            "Delete",
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.of(ctx2).pop(false),
                                          child: const Text(
                                            "Cancel",
                                            style: TextStyle(
                                              color: Colors.blue,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                              );

                              if (shouldDelete == true) {
                                try {
                                  await showLoadingWhileTask(context, () async {
                                    final firestore = ref.read(
                                      firestoreServiceProvider,
                                    );
                                    await firestore.deleteBill(
                                      bill.id,
                                    ); // ONLY delete here
                                  });

                                  // 🔥 After transaction is finished → now refresh providers
                                  ref.invalidate(paidBillsProvider);
                                  ref.invalidate(unpaidBillsProvider);

                                  setState(() {
                                    filteredBills.removeWhere(
                                      (b) => b.id == bill.id,
                                    );
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Deleted Bill #${bill.billNumber}",
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text("Error deleting bill: $e"),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Row(
                              children: [
                                Checkbox(
                                  activeColor: const Color.fromARGB(
                                    255,
                                    2,
                                    113,
                                    192,
                                  ),
                                  value: isSelected,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        selectedBills[bill.id] = bill;
                                      } else {
                                        selectedBills.remove(bill.id);
                                      }
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text('${bill.billNumber}'),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(
                                                ClipboardData(
                                                  text: bill.billNumber,
                                                ),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Copied Bill #${bill.billNumber}',
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Icon(
                                              Icons.copy,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat(
                                          'dd MMM yyyy',
                                        ).format(bill.createdAt.toDate()),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$ ${bill.balance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await generateAndOpenPdf(bill, false);
                                  },
                                  icon: const Icon(
                                    Icons.download,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const Divider(),

                    // ─── Total ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Total : \$ ${totalSelectedBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),

                    // ─── Paid Amount ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Form(
                        key: _formKey,
                        child: TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _paidAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            prefixText: "\$ ",
                            labelText: 'Enter Paid Amount',
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                              borderSide: BorderSide(
                                color: Color.fromARGB(255, 2, 113, 192),
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a paid amount';
                            }
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed < 0) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ─── Admin Controls ───────────────────────
                    if (role == UserRole.admin)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: 8,
                          left: 16,
                          right: 16,
                        ),
                        child: Row(
                          children: [
                            // Payment Method Selection
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Payment Method:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: RadioListTile<bool>(
                                          title: const Text('Cash'),
                                          value: false,
                                          groupValue: upiPayment,
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          activeColor: const Color.fromARGB(
                                            255,
                                            2,
                                            113,
                                            192,
                                          ),
                                          onChanged:
                                              (value) => setState(
                                                () => upiPayment = value,
                                              ),
                                        ),
                                      ),
                                      Expanded(
                                        child: RadioListTile<bool>(
                                          title: const Text('UPI'),
                                          value: true,
                                          groupValue: upiPayment,
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          activeColor: const Color.fromARGB(
                                            255,
                                            2,
                                            113,
                                            192,
                                          ),
                                          onChanged:
                                              (value) => setState(
                                                () => upiPayment = value,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Paid Button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: const ButtonStyle(
                                  elevation: WidgetStatePropertyAll(4),
                                  backgroundColor: WidgetStatePropertyAll(
                                    Colors.white,
                                  ),
                                ),
                                onPressed: () async {
                                  if (!_formKey.currentState!.validate())
                                    return;

                                  if (selectedBills.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Please select at least one bill",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  if (upiPayment == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          "Please select a payment method",
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final firestore = ref.read(
                                    firestoreServiceProvider,
                                  );
                                  final selectedIds =
                                      selectedBills.keys.toList();
                                  final paidAmount =
                                      double.tryParse(
                                        _paidAmountController.text.trim(),
                                      ) ??
                                      0.0;

                                  await showLoadingWhileTask(context, () async {
                                    final bills = selectedBills.values.toList();
                                    await firestore.markBillsAsPaid(
                                      bills,
                                      paidAmount,
                                      upiPayment!,
                                    );
                                  });

                                  ref.invalidate(unpaidBillsProvider);
                                  Navigator.pop(context);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${selectedIds.length} bill(s) marked as paid.',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Paid',
                                  style: TextStyle(
                                    color: Color(0xFF00A105),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void showFullBillDetailsDialog(BuildContext context, Bill bill) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFFE3F2FD),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Bill #: ${bill.billNumber}'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Shop: ${bill.shopName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Created: ${DateFormat('dd MMM yyyy').format(bill.createdAt.toDate())}',
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Items',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      itemCount: bill.items.length,
                      itemBuilder: (context, index) {
                        final item = bill.items[index];
                        return ListTile(
                          dense: true,
                          title: Text(item.name),
                          subtitle: Text(
                            'Qty: ${item.quantity} x \$ ${item.price.toStringAsFixed(2)}',
                          ),
                          trailing: Text('\$ ${item.total.toStringAsFixed(2)}'),
                        );
                      },
                      separatorBuilder: (_, __) => const Divider(),
                    ),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bill Total :'),
                            Text(
                              '\$ ${bill.discountedTotal.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Paid :'),
                            Text('\$ ${bill.paidAmount.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await generateAndOpenPdf(bill, false);
                },
                child: const Text(
                  'Download',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    barrierDismissible: false,
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFFE3F2FD),
                          title: const Text('Delete Bill?'),
                          content: const Text(
                            'This action cannot be undone. Proceed?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                            ElevatedButton(
                              style: ButtonStyle(
                                backgroundColor: WidgetStatePropertyAll(
                                  Colors.white,
                                ),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(firestoreServiceProvider)
                        .deleteBill(bill.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bill deleted')),
                    );
                    setState(() {});
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}






//delete all bills button
   // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 10),
        //     child: ElevatedButton(
        //       style: ElevatedButton.styleFrom(
        //         backgroundColor: const Color.fromARGB(255, 226, 88, 78),
        //         foregroundColor: Colors.white,
        //       ),
        //       onPressed: () async {
        //         final confirmed = await showDialog<bool>(
        //           barrierDismissible: false,
        //           context: context,
        //           builder:
        //               (ctx) => AlertDialog(
        //                 backgroundColor: const Color(0xFFE3F2FD),
        //                 title: const Text('Delete ALL Bills?'),
        //                 content: const Text(
        //                   '⚠️ This will delete the entire bills collection.\nAre you sure?',
        //                 ),
        //                 actions: [
        //                   TextButton(
        //                     onPressed: () => Navigator.of(ctx).pop(false),
        //                     child: const Text(
        //                       'Cancel',
        //                       style: TextStyle(color: Colors.blue),
        //                     ),
        //                   ),
        //                   ElevatedButton(
        //                     style: ElevatedButton.styleFrom(
        //                       backgroundColor: Colors.red,
        //                     ),
        //                     onPressed: () => Navigator.of(ctx).pop(true),
        //                     child: const Text(
        //                       'Delete All',
        //                       style: TextStyle(color: Colors.white),
        //                     ),
        //                   ),
        //                 ],
        //               ),
        //         );

        //         if (confirmed == true) {
        //           await ref.read(firestoreServiceProvider).deleteAllBills();
        //           ScaffoldMessenger.of(context).clearSnackBars();
        //           ScaffoldMessenger.of(context).showSnackBar(
        //             const SnackBar(content: Text('All bills deleted')),
        //           );
        //           setState(() {});
        //         }
        //       },
        //       child: const Text('Delete All Bills'),
        //     ),
        //   ),
        // ],