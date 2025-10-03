import 'package:billing/core/utils/loading.dart';
import 'package:billing/features/providers/bill_provider.dart';
import 'package:billing/features/providers/role_provider.dart';
import 'package:billing/features/screens/deletedBills.dart';
import 'package:billing/features/screens/login_screen.dart';

import 'package:billing/features/services/pdfservices.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

import '../models/bill.dart';
import '../services/firestore_services.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';
import 'package:excel/excel.dart' as xls;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dart:io';

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

  String shopQuery = '';
  String billSearch = '';

  // Filter variables
  DateTime? selectedDate;
  DateTime? selectedMonth;
  String filterType = 'none'; // 'none', 'date', 'month'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _billSearchController.dispose();
    super.dispose();
  }

  bool _matchesDateFilter(Bill bill) {
    if (filterType == 'none') return true;

    // pick correct date based on isPaid
    final DateTime? billDate =
        bill.isPaid ? bill.markedAsPaidAt?.toDate() : bill.createdAt.toDate();

    if (billDate == null) return false;

    if (filterType == 'date' && selectedDate != null) {
      return billDate.year == selectedDate!.year &&
          billDate.month == selectedDate!.month &&
          billDate.day == selectedDate!.day;
    }

    if (filterType == 'month' && selectedMonth != null) {
      return billDate.year == selectedMonth!.year &&
          billDate.month == selectedMonth!.month;
    }

    return true;
  }

  List<Map<String, dynamic>> _filterShopsData(
    List<Map<String, dynamic>> shopsData,
  ) {
    if (filterType == 'none') {
      return shopsData
          .map((shopData) {
            final List<Bill> bills = shopData['bills'] as List<Bill>;

            if (bills.isEmpty) return null;

            double total = 0;
            if (shopData.containsKey('totalPaid')) {
              total = bills.fold<double>(
                0,
                (sum, bill) => sum + bill.discountedTotal,
              );
              return {
                'shopName': shopData['shopName'],
                'bills': bills,
                'count': bills.length,
                'totalPaid': total,
              };
            } else {
              total = bills.fold<double>(0, (sum, bill) => sum + bill.balance);
              return {
                'shopName': shopData['shopName'],
                'bills': bills,
                'count': bills.length,
                'totalUnPaid': total,
              };
            }
          })
          .where((shop) => shop != null)
          .cast<Map<String, dynamic>>()
          .toList();
    }

    // ✅ Apply date filter when filterType != none
    return shopsData
        .map((shopData) {
          final List<Bill> bills = shopData['bills'] as List<Bill>;
          final filteredBills = bills.where(_matchesDateFilter).toList();

          if (filteredBills.isEmpty) return null;

          double total = 0;
          if (shopData.containsKey('totalPaid')) {
            total = filteredBills.fold<double>(
              0,
              (sum, bill) => sum + bill.discountedTotal,
            );
            return {
              'shopName': shopData['shopName'],
              'bills': filteredBills,
              'count': filteredBills.length,
              'totalPaid': total,
            };
          } else {
            total = filteredBills.fold<double>(
              0,
              (sum, bill) => sum + bill.balance,
            );
            return {
              'shopName': shopData['shopName'],
              'bills': filteredBills,
              'count': filteredBills.length,
              'totalUnPaid': total,
            };
          }
        })
        .where((shop) => shop != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  Map<String, double> _calculateDailyAndMonthlyTotals(
    List<Map<String, dynamic>> shopsData,
    bool isPaid,
  ) {
    final today = DateTime.now();
    final currentMonth = DateTime(today.year, today.month);

    double dailyTotal = 0.0;
    double monthlyTotal = 0.0;

    for (final shopData in shopsData) {
      final List<Bill> bills = shopData['bills'] as List<Bill>;

      for (final bill in bills) {
        // ✅ Select date field based on isPaid
        final DateTime? billDate =
            isPaid
                ? bill.markedAsPaidAt
                    ?.toDate() // paid → use markedAsPaidAt
                : bill.createdAt.toDate(); // unpaid → use createdAt

        if (billDate == null) continue;

        final billDateOnly = DateTime(
          billDate.year,
          billDate.month,
          billDate.day,
        );
        final todayOnly = DateTime(today.year, today.month, today.day);

        // Check if bill matches today
        if (billDateOnly.isAtSameMomentAs(todayOnly)) {
          dailyTotal += isPaid ? bill.discountedTotal : bill.balance;
        }

        // Check if bill matches current month
        if (billDate.year == currentMonth.year &&
            billDate.month == currentMonth.month) {
          monthlyTotal += isPaid ? bill.discountedTotal : bill.balance;
        }
      }
    }

    return {'daily': dailyTotal, 'monthly': monthlyTotal};
  }

  Widget _buildFilterChipsWithTotals(
    List<Map<String, dynamic>> shopsData,
    bool isPaid,
  ) {
    final totals = _calculateDailyAndMonthlyTotals(shopsData, isPaid);
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          // Filter Chips Row
          Row(
            children: [
              // Date Filter Chip
              FilterChip(
                selected: filterType == 'date',
                label: Text(
                  selectedDate != null
                      ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                      : 'Filter by Date',
                ),
                selectedColor: Colors.blue.shade100,
                onSelected: (bool selected) async {
                  if (selected) {
                    final DateTime? picked = await showDatePicker(
                      barrierDismissible: false,
                      context: context,
                      initialDate: selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (BuildContext context, Widget? child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            dialogBackgroundColor:
                                Colors.blueGrey[900], // 🔹 background color
                            colorScheme: ColorScheme.light(
                              primary: Color.fromARGB(
                                255,
                                2,
                                113,
                                192,
                              ), // header background color
                              onPrimary: Colors.white, // header text color
                              onSurface: Colors.black, // body text color
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Color.fromARGB(
                                  255,
                                  2,
                                  113,
                                  192,
                                ), // button text color
                              ),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                        selectedMonth = null;
                        filterType = 'date';
                      });
                    }
                  } else {
                    setState(() {
                      selectedDate = null;
                      filterType = 'none';
                    });
                  }
                },
              ),
              const SizedBox(width: 8),

              // Month Filter Chip
              FilterChip(
                selected: filterType == 'month',
                label: Text(
                  selectedMonth != null
                      ? DateFormat('MMM yyyy').format(selectedMonth!)
                      : 'Filter by Month',
                ),
                selectedColor: Colors.green.shade100,
                onSelected: (bool selected) async {
                  if (selected) {
                    final DateTime? picked = await showMonthPicker(
                      context: context,
                      initialDate: selectedMonth ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedMonth = picked;
                        selectedDate = null;
                        filterType = 'month';
                      });
                    }
                  } else {
                    setState(() {
                      selectedMonth = null;
                      filterType = 'none';
                    });
                  }
                },
              ),

              // Clear Filter Button
              if (filterType != 'none') ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      selectedDate = null;
                      selectedMonth = null;
                      filterType = 'none';
                    });
                  },
                  tooltip: 'Clear Filter',
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          // Daily and Monthly Totals Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Daily Total
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPaid ? Colors.green.shade200 : Colors.red.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.today,
                      size: 16,
                      color:
                          isPaid ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Today: \$ ${(totals['daily'] ?? 0).toDouble().toStringAsFixed(2)}',

                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            isPaid
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),

              // Monthly Total
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPaid ? Colors.green.shade200 : Colors.red.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 16,
                      color:
                          isPaid ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('MMM yyyy').format(today)}: \$ ${(totals['monthly'] ?? 0).toDouble().toStringAsFixed(2)}',

                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            isPaid
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Future<void> _generateReportExcel(
  //   BuildContext context,
  //   WidgetRef ref,
  //   DateTime date,
  // ) async {
  //   final firestore = ref.read(firestoreServiceProvider);

  //   // Fetch bills for that date (make sure you implemented this in FirestoreService)
  //   final bills = await firestore.fetchBillsByDate(date);

  //   double totalAmount = 0;
  //   double totalPaid = 0;
  //   double totalUnpaid = 0;

  //   for (var bill in bills) {
  //     totalAmount += bill.discountedTotal;
  //     if (bill.isPaid) {
  //       totalPaid += bill.paidAmount;
  //     } else {
  //       totalUnpaid += bill.balance;
  //     }
  //   }

  //   // Create Excel
  //   final excel = xls.Excel.createExcel();
  //   final sheet = excel['Report'];

  //   // Header row
  //   sheet.appendRow([
  //     xls.TextCellValue('Shop Name'),
  //     xls.TextCellValue('Bill Number'),
  //     xls.TextCellValue("Created At"),
  //     xls.TextCellValue("Paid At"),
  //     xls.TextCellValue('Total Amount'),
  //     // xls.TextCellValue('Paid Amount'),
  //     xls.TextCellValue('Balance'),
  //     xls.TextCellValue('Status'),
  //   ]);

  //   // Bill rows
  //   for (var bill in bills) {
  //     final createdAtFormatted = DateFormat(
  //       'dd-MM-yy',
  //     ).format((bill.createdAt as Timestamp).toDate());
  //     final paidAtFormatted =
  //         bill.markedAsPaidAt != null
  //             ? DateFormat(
  //               'dd-MM-yy',
  //             ).format((bill.markedAsPaidAt as Timestamp).toDate())
  //             : "-"; // show dash if null

  //     sheet.appendRow([
  //       xls.TextCellValue(bill.shopName),
  //       xls.TextCellValue(bill.billNumber),
  //       xls.TextCellValue(createdAtFormatted),
  //       xls.TextCellValue(paidAtFormatted),

  //       xls.DoubleCellValue(bill.discountedTotal),
  //       // xls.DoubleCellValue(bill.paidAmount),
  //       xls.DoubleCellValue(bill.balance),
  //       xls.TextCellValue(bill.isPaid ? "Paid" : "Unpaid"),
  //     ]);
  //   }

  //   // Add summary row
  //   sheet.appendRow([]);
  //   sheet.appendRow([
  //     xls.TextCellValue("TOTAL"),
  //     xls.TextCellValue(""),
  //     xls.TextCellValue(""),
  //     xls.DoubleCellValue(totalAmount),
  //     xls.DoubleCellValue(totalPaid),
  //     xls.DoubleCellValue(totalUnpaid),
  //     xls.TextCellValue(""),
  //   ]);

  //   // Save file
  //   final dir = await getApplicationDocumentsDirectory();
  //   print("getttinggg enterdddddd");
  //   final path =
  //       "${dir.path}/Bills_Report_${DateFormat('ddMMyyyy').format(date)}.xlsx";
  //   final fileBytes = excel.encode();
  //   if (fileBytes != null) {
  //     final file =
  //         File(path)
  //           ..createSync(recursive: true)
  //           ..writeAsBytesSync(fileBytes);

  //     // Open Excel file
  //     await OpenFilex.open(file.path);
  //   } else {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text("Failed to generate Excel file")),
  //     );
  //   }
  // }
  Future<void> _generateReportExcel(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final firestore = ref.read(firestoreServiceProvider);
    final result = await firestore.fetchBillsByDate(date);

    final createdBills = result["created"] ?? [];
    final paidBills = result["paid"] ?? [];

    final excel = xls.Excel.createExcel();
    final sheet = excel['Report'];

    // ==== Section 1: Created Bills ====
    sheet.appendRow([
      xls.TextCellValue(
        "Created Bills on ${DateFormat('dd-MM-yy').format(date)}",
      ),
    ]);
    sheet.appendRow([
      xls.TextCellValue('Shop Name'),
      xls.TextCellValue('Bill Number'),
      xls.TextCellValue("Created At"),
      xls.TextCellValue('Total Amount'),
      xls.TextCellValue('Balance'),
      xls.TextCellValue('Status'),
    ]);

    double createdTotal = 0;
    double createdPaid = 0;
    double createdUnpaid = 0;

    for (var bill in createdBills) {
      createdTotal += bill.discountedTotal;
      if (bill.isPaid) {
        createdPaid += bill.paidAmount;
      } else {
        createdUnpaid += bill.balance;
      }

      sheet.appendRow([
        xls.TextCellValue(bill.shopName),
        xls.TextCellValue(bill.billNumber),
        xls.TextCellValue(
          DateFormat('dd-MM-yy').format((bill.createdAt as Timestamp).toDate()),
        ),
        xls.DoubleCellValue(bill.discountedTotal),
        xls.DoubleCellValue(bill.balance),
        xls.TextCellValue(bill.isPaid ? "Paid" : "Unpaid"),
      ]);
    }

    // Totals for created bills
    sheet.appendRow([
      xls.TextCellValue(""),
      xls.TextCellValue(""),
      xls.TextCellValue("Totals"),
      xls.DoubleCellValue(createdTotal),
      xls.DoubleCellValue(createdUnpaid),
      xls.TextCellValue("Created & Paid: $createdPaid"),
    ]);

    // ==== Section 2: Outstanding (Paid Bills) ====
    sheet.appendRow([]);
    sheet.appendRow([
      xls.TextCellValue(
        "Outstanding Bills (Paid on ${DateFormat('dd-MM-yy').format(date)})",
      ),
    ]);
    sheet.appendRow([
      xls.TextCellValue('Shop Name'),
      xls.TextCellValue('Bill Number'),
      xls.TextCellValue("Paid At"),
      xls.TextCellValue('Paid Amount'),
      xls.TextCellValue('Status'),
    ]);

    double paidTotal = 0;
    for (var bill in paidBills) {
      paidTotal += bill.paidAmount;

      sheet.appendRow([
        xls.TextCellValue(bill.shopName),
        xls.TextCellValue(bill.billNumber),
        xls.TextCellValue(
          DateFormat(
            'dd-MM-yy',
          ).format((bill.markedAsPaidAt as Timestamp).toDate()),
        ),
        xls.DoubleCellValue(bill.paidAmount),
        xls.TextCellValue("Paid"),
      ]);
    }

    // Totals for outstanding bills
    sheet.appendRow([
      xls.TextCellValue(""),
      xls.TextCellValue(""),
      xls.TextCellValue("Total Marked as Paid Today"),
      xls.DoubleCellValue(paidTotal),
    ]);

    for (var bill in paidBills) {
      sheet.appendRow([
        xls.TextCellValue(bill.shopName),
        xls.TextCellValue(bill.billNumber),
        xls.TextCellValue(
          DateFormat(
            'dd-MM-yy',
          ).format((bill.markedAsPaidAt as Timestamp).toDate()),
        ),
        xls.DoubleCellValue(bill.paidAmount),
        xls.TextCellValue("Paid"),
      ]);
    }

    // Save & open
    final dir = await getApplicationDocumentsDirectory();
    final path =
        "${dir.path}/Bills_Report_${DateFormat('ddMMyyyy').format(date)}.xlsx";
    final fileBytes = excel.encode();

    if (fileBytes != null) {
      final file =
          File(path)
            ..createSync(recursive: true)
            ..writeAsBytesSync(fileBytes);
      await OpenFilex.open(file.path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to generate Excel file")),
      );
    }
  }

  Future<void> _generateReportPdf(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) async {
    final firestore = ref.read(firestoreServiceProvider);

    // Fetch bills separately (created vs paid)
    final result = await firestore.fetchBillsByDate(date);
    final createdBills = result["created"] ?? [];
    final paidBills = result["paid"] ?? [];

    // Totals
    double createdTotal = 0;
    double createdUnpaid = 0;
    double createdPaid = 0;

    for (var bill in createdBills) {
      createdTotal += bill.discountedTotal;
      if (bill.isPaid) {
        createdPaid += bill.paidAmount;
      } else {
        createdUnpaid += bill.balance;
      }
    }

    double paidTotal = 0;
    for (var bill in paidBills) {
      paidTotal += bill.paidAmount;
    }

    // Create PDF document
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build:
            (context) => [
              pw.Text(
                'Bills Report - ${DateFormat('dd/MM/yyyy').format(date)}',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 16),

              // Section 1: Created Bills
              pw.Text(
                "Created Bills",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Table.fromTextArray(
                headers: [
                  'Shop Name',
                  'Bill Number',
                  'Created At',
                  'Total',
                  'Balance',
                  'Status',
                ],
                data:
                    createdBills.map((b) {
                      return [
                        b.shopName,
                        b.billNumber,
                        DateFormat(
                          'dd-MM',
                        ).format((b.createdAt as Timestamp).toDate()),
                        b.discountedTotal.toStringAsFixed(2),
                        b.balance.toStringAsFixed(2),
                        b.isPaid ? "Paid" : "Unpaid",
                      ];
                    }).toList(),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Today Total Amount: ${createdTotal.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Paid: ${createdPaid.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    "Unpaid: ${createdUnpaid.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              // Section 2: Outstanding (Paid Today)
              pw.Text(
                "Outstanding (Paid Today)",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Table.fromTextArray(
                headers: ['Shop Name', 'Bill Number', 'Paid At', 'Paid Amount'],
                data:
                    paidBills.map((b) {
                      return [
                        b.shopName,
                        b.billNumber,
                        DateFormat(
                          'dd-MM',
                        ).format((b.markedAsPaidAt as Timestamp).toDate()),
                        b.paidAmount.toStringAsFixed(2),
                      ];
                    }).toList(),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.start,
                children: [
                  pw.Text(
                    "Outstanding Paid Today: ${paidTotal.toStringAsFixed(2)}",
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final path =
        "${dir.path}/Bills_Report_${DateFormat('ddMMyyyy').format(date)}.pdf";
    final file = File(path);
    await file.writeAsBytes(await pdf.save());

    await OpenFilex.open(file.path);
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
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (selectedDate != null) {
                  await showLoadingWhile(
                    context,
                    _generateReportPdf(context, ref, selectedDate),
                  );
                }
              } else if (value == 'excel') {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (selectedDate != null) {
                  await showLoadingWhile(
                    context,
                    _generateReportExcel(context, ref, selectedDate),
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
                    value: 'excel',
                    child: ListTile(
                      leading: Icon(Icons.table_chart, color: Colors.blue),
                      title: Text('Download Excel Report'),
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Paid Bills Tab
          Column(
            children: [
              // Use the enhanced filter chips with totals for paid bills
              paidBillsAsync.when(
                data:
                    (shopsData) => _buildFilterChipsWithTotals(shopsData, true),
                loading: () => _buildFilterChipsWithTotals([], true),
                error: (_, __) => _buildFilterChipsWithTotals([], true),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: TextField(
                      cursorColor: Color.fromARGB(255, 2, 113, 192),
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by shop name...',
                        prefixIcon: Icon(Icons.search),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color.fromARGB(255, 2, 113, 192),
                          ),
                        ),
                      ),
                      onChanged:
                          (value) =>
                              setState(() => shopQuery = value.toLowerCase()),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: paidBillsAsync.when(
                  data: (shopsData) {
                    // Apply date/month filter first
                    final dateFiltered = _filterShopsData(shopsData);

                    // Then apply shop name filter
                    final filtered =
                        dateFiltered
                            .where(
                              (shop) => shop['shopName']
                                  .toString()
                                  .toLowerCase()
                                  .contains(shopQuery.toLowerCase()),
                            )
                            .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          filterType != 'none'
                              ? 'No paid bills found for selected ${filterType == 'date' ? 'date' : 'month'}.'
                              : 'No paid bills found.',
                        ),
                      );
                    }

                    final totalPaidAcrossShops = filtered.fold<double>(
                      0,
                      (sum, shop) =>
                          sum + (shop['totalPaid'] as num).toDouble(),
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
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        filterType != 'none'
                                            ? 'Total Paid (${filterType == 'date' ? DateFormat('dd/MM/yyyy').format(selectedDate!) : DateFormat('MMM yyyy').format(selectedMonth!)})'
                                            : 'Total Paid Across All Shops',
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
                                                  .green, // value has different color
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
                                                  .green, // value has different color
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
                              final shopName = shopData['shopName'] as String;
                              final count = shopData['count'] as int;
                              final paidBills = shopData['bills'] as List<Bill>;

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
                                  style: const TextStyle(color: Colors.green),
                                ),
                                onTap: () {
                                  _showPaidBillsDialog(context, ref, paidBills);
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

          // Unpaid Bills Tab
          Column(
            children: [
              // Use the enhanced filter chips with totals for unpaid bills
              unpaidBillsAsync.when(
                data:
                    (shopsData) =>
                        _buildFilterChipsWithTotals(shopsData, false),
                loading: () => _buildFilterChipsWithTotals([], false),
                error: (_, __) => _buildFilterChipsWithTotals([], false),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  cursorColor: Color.fromARGB(255, 2, 113, 192),
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by shop name...',
                    prefixIcon: Icon(Icons.search),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color.fromARGB(255, 2, 113, 192),
                      ),
                    ),
                  ),
                  onChanged:
                      (value) =>
                          setState(() => shopQuery = value.toLowerCase()),
                ),
              ),
              Expanded(
                child: unpaidBillsAsync.when(
                  data: (shopsData) {
                    final dateFiltered = _filterShopsData(shopsData);

                    final filtered =
                        dateFiltered
                            .where(
                              (shop) => shop['shopName']
                                  .toString()
                                  .toLowerCase()
                                  .contains(shopQuery.toLowerCase()),
                            )
                            .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          filterType != 'none'
                              ? 'No unpaid bills found for selected ${filterType == 'date' ? 'date' : 'month'}.'
                              : 'No unpaid bills found.',
                        ),
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
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        filterType != 'none'
                                            ? 'Total Unpaid (${filterType == 'date' ? DateFormat('dd/MM/yyyy').format(selectedDate!) : DateFormat('MMM yyyy').format(selectedMonth!)})'
                                            : 'Total Unpaid Across All Shops',
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
                              final shopName = shopData['shopName'] as String;
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
                  onSubmitted: (val) => setState(() => billSearch = val.trim()),
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
                                  title: Text('Bill #: ${bill.billNumber}'),
                                  subtitle: Text('Shop: ${bill.shopName}'),
                                  trailing: Text(
                                    '\$ ${bill.discountedTotal.toStringAsFixed(2)}',
                                  ),
                                  onTap: () {
                                    showFullBillDetailsDialog(context, bill);
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
              // removes default margin
              backgroundColor: Colors.transparent, // so we can style our own
              child: Container(
                width: MediaQuery.of(context).size.width, // full width
                height: MediaQuery.of(context).size.height * 0.8, // 85% height
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
                            // subtitle: Padding(
                            //   padding: const EdgeInsets.symmetric(
                            //     horizontal: 8,
                            //   ),
                            //   child: Text(
                            //     bill.markedAsPaidAt != null
                            //         ? DateFormat(
                            //           'dd MMM yyyy',
                            //         ).format(bill.markedAsPaidAt!.toDate())
                            //         : '—',
                            //   ),
                            // ),
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
                                  final firestore = ref.read(
                                    firestoreServiceProvider,
                                  );
                                  await firestore.deleteBill(bill.id);
                                  setState(() {
                                    filteredBills.removeWhere(
                                      (b) => b.id == bill.id,
                                    );
                                  });
                                  ScaffoldMessenger.of(
                                    context,
                                  ).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Deleted Bill #${bill.billNumber}",
                                      ),
                                    ),
                                  );

                                  // Refresh providers
                                  ref.invalidate(paidBillsProvider);
                                  ref.invalidate(unpaidBillsProvider);
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
                                  // ✅ Created At
                                  Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(bill.createdAt.toDate()),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),

                                  // ✅ Marked As Paid At
                                  // Text(
                                  //   bill.markedAsPaidAt != null
                                  //       ? DateFormat(
                                  //         'dd MMM yyyy',
                                  //       ).format(bill.markedAsPaidAt!.toDate())
                                  //       : '—',
                                  //   style: const TextStyle(
                                  //     fontSize: 12,
                                  //     color: Colors.grey,
                                  //   ),
                                  // ),
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
              insetPadding: EdgeInsets.all(8),
              backgroundColor: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width, // full width
                height: MediaQuery.of(context).size.height * 0.8, // 85% height
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey, width: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "UnPaid Bills",
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
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
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
                                  final firestore = ref.read(
                                    firestoreServiceProvider,
                                  );
                                  await firestore.deleteBill(bill.id);
                                  setState(() {
                                    unpaidBills.removeWhere(
                                      (b) => b.id == bill.id,
                                    );
                                    filteredBills.removeWhere(
                                      (b) => b.id == bill.id,
                                    );
                                  });

                                  ScaffoldMessenger.of(
                                    context,
                                  ).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Deleted Bill #${bill.billNumber}",
                                      ),
                                    ),
                                  );

                                  // Refresh providers
                                  ref.invalidate(unpaidBillsProvider);
                                  ref.invalidate(paidBillsProvider);
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
                                              ).clearSnackBars();
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
                                  icon: Icon(
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
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Total : \$ ${totalSelectedBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Form(
                        key: _formKey,
                        child: TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          controller: _paidAmountController,
                          cursorErrorColor: const Color.fromARGB(
                            255,
                            2,
                            113,
                            192,
                          ),
                          cursorColor: const Color.fromARGB(255, 2, 113, 192),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            prefixText: "\$ ",
                            labelStyle: const TextStyle(
                              color: Color.fromARGB(255, 2, 113, 192),
                            ),
                            labelText: 'Enter Paid Amount',

                            errorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                              borderSide: BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                            focusedErrorBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
                              borderSide: BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
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
                    SizedBox(height: 8),
                    if (role == UserRole.admin)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ElevatedButton(
                          style: const ButtonStyle(
                            elevation: WidgetStatePropertyAll(4),
                            backgroundColor: WidgetStatePropertyAll(
                              Colors.white,
                            ),
                          ),
                          onPressed: () async {
                            // Validate the form first
                            if (!_formKey.currentState!.validate()) {
                              return; // Stop if validation fails
                            }

                            if (selectedBills.isEmpty) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please select at least one bill",
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }

                            final firestore = ref.read(
                              firestoreServiceProvider,
                            );
                            final selectedIds = selectedBills.keys.toList();

                            final paidAmount =
                                double.tryParse(
                                  _paidAmountController.text.trim(),
                                ) ??
                                0.0;

                            await showLoadingWhileTask(context, () async {
                              final bills = await firestore.fetchBillsByIds(
                                selectedIds,
                              );
                              await firestore.markBillsAsPaid(
                                bills,
                                paidAmount,
                              );
                            });

                            ref.invalidate(unpaidBillsProvider);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).clearSnackBars();
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
                              fontSize: 12,
                            ),
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