import 'package:billing/core/utils/loading.dart';
import 'package:billing/features/providers/bill_provider.dart';
import 'package:billing/features/providers/role_provider.dart';
import 'package:billing/features/screens/deletedBills.dart';

import 'package:billing/features/services/pdfservices.dart';

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
  String filterType = 'none';

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
        final DateTime? billDate =
            isPaid ? bill.markedAsPaidAt?.toDate() : bill.createdAt.toDate();

        if (billDate == null) continue;

        final billDateOnly = DateTime(
          billDate.year,
          billDate.month,
          billDate.day,
        );
        final todayOnly = DateTime(today.year, today.month, today.day);

        if (billDateOnly.isAtSameMomentAs(todayOnly)) {
          dailyTotal += isPaid ? bill.discountedTotal : bill.balance;
        }

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
          Row(
            children: [
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
                            dialogBackgroundColor: Colors.blueGrey[900],
                            colorScheme: ColorScheme.light(
                              primary: Color.fromARGB(255, 2, 113, 192),
                              onPrimary: Colors.white,
                              onSurface: Colors.black,
                            ),
                            textButtonTheme: TextButtonThemeData(
                              style: TextButton.styleFrom(
                                foregroundColor: Color.fromARGB(
                                  255,
                                  2,
                                  113,
                                  192,
                                ),
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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
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

  // Future<void> _generateReportPdf(
  //   BuildContext context,
  //   WidgetRef ref,
  //   DateTime date,
  // ) async {
  //   final firestore = ref.read(firestoreServiceProvider);

  //   print("STEP 1: Starting PDF...");
  //   final result = await firestore.fetchBillsByDate(date);
  //   print("STEP 2: Data fetched");

  //   final createdUpi = result["created"]?["upi"] ?? <Bill>[];
  //   final createdCash = result["created"]?["cash"] ?? <Bill>[];
  //   final createdUnpaid = result["created"]?["unpaid"] ?? <Bill>[];

  //   print(
  //     "STEP 3: Created bills: UPI=${createdUpi.length}, Cash=${createdCash.length}, Unpaid=${createdUnpaid.length}",
  //   );

  //   final paidTodayUpi = result["paidToday"]?["upi"] ?? <Bill>[];
  //   final paidTodayCash = result["paidToday"]?["cash"] ?? <Bill>[];

  //   print(
  //     "STEP 4: Paid Today: UPI=${paidTodayUpi.length}, Cash=${paidTodayCash.length}",
  //   );

  //   // -------------------
  //   // Remove duplicates
  //   // -------------------
  //   List<Bill> removeDuplicateBills(List<Bill> bills) {
  //     final seen = <String>{};
  //     return bills.where((b) => seen.add(b.id)).toList();
  //   }

  //   final allCreated = removeDuplicateBills([
  //     ...createdUpi,
  //     ...createdCash,
  //     ...createdUnpaid,
  //   ]);

  //   final allPaidToday = removeDuplicateBills([
  //     ...paidTodayUpi,
  //     ...paidTodayCash,
  //   ]);

  //   // -------------------
  //   // Totals
  //   // -------------------
  //   double sumTotal(List<Bill> bills) =>
  //       bills.fold(0.0, (sum, b) => sum + (b.discountedTotal ?? 0.0));

  //   final createdUpiTotal = sumTotal(createdUpi);
  //   final createdCashTotal = sumTotal(createdCash);
  //   final createdUnpaidTotal = sumTotal(createdUnpaid);

  //   final paidTodayUpiTotal = sumTotal(paidTodayUpi);
  //   final paidTodayCashTotal = sumTotal(paidTodayCash);

  //   final overallCreatedTotal =
  //       createdUpiTotal + createdCashTotal + createdUnpaidTotal;
  //   final overallOutstandingTotal = paidTodayUpiTotal + paidTodayCashTotal;

  //   print("STEP 5: Loading fonts...");
  //   final fontRegular = pw.Font.ttf(
  //     await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  //   );
  //   final fontBold = pw.Font.ttf(
  //     await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  //   );

  //   final pdf = pw.Document(
  //     theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
  //   );

  //   // -------------------
  //   // Bill Status Helper
  //   // -------------------
  //   String getBillStatus(Bill b) {
  //     if (b.isPaid == false) return "Unpaid";
  //     if (b.upiPayment == true) return "UPI";
  //     return "Cash";
  //   }

  //   // -------------------
  //   // Build a COMPLETE section (title + table)
  //   // -------------------
  //   // pw.Widget buildCompleteSection(String title, List<Bill> bills) {
  //   //   final data = List.generate(bills.length, (i) {
  //   //     final b = bills[i];
  //   //     return [
  //   //       (i + 1).toString(),
  //   //       b.shopName ?? "",
  //   //       getBillStatus(b),
  //   //       (b.discountedTotal ?? 0.0).toStringAsFixed(2),
  //   //       b.billNumber ?? "",
  //   //     ];
  //   //   });

  //   //   return pw.Column(
  //   //     crossAxisAlignment: pw.CrossAxisAlignment.start,
  //   //     children: [
  //   //       pw.Center(
  //   //         child: pw.Text(
  //   //           title,
  //   //           style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
  //   //         ),
  //   //       ),
  //   //       pw.SizedBox(height: 8),
  //   //       pw.Table.fromTextArray(
  //   //         headers: ['S.No', 'Shop', 'Status', 'Amount', 'Bill No'],
  //   //         data: data,
  //   //         headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //   //         cellAlignment: pw.Alignment.centerLeft,
  //   //         headerDecoration: pw.BoxDecoration(
  //   //           border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
  //   //         ),
  //   //       ),
  //   //       pw.SizedBox(height: 20),
  //   //     ],
  //   //   );
  //   // }

  //   pw.Widget buildCompleteSection(
  //     String title,
  //     List<Bill> bills,
  //     int startIndex,
  //   ) {
  //     final data = List.generate(bills.length, (i) {
  //       final b = bills[i];
  //       return [
  //         (startIndex + i + 1).toString(), // <-- continue serial number
  //         b.shopName ?? "",
  //         getBillStatus(b),
  //         (b.discountedTotal ?? 0.0).toStringAsFixed(2),
  //         b.billNumber ?? "",
  //       ];
  //     });

  //     return pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Center(
  //           child: pw.Text(
  //             title,
  //             style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
  //           ),
  //         ),
  //         pw.SizedBox(height: 8),
  //         pw.Table.fromTextArray(
  //           headers: ['S.No', 'Shop', 'Status', 'Amount', 'Bill No'],
  //           data: data,
  //           headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //           cellAlignment: pw.Alignment.centerLeft,
  //           headerDecoration: pw.BoxDecoration(
  //             border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
  //           ),
  //         ),
  //         pw.SizedBox(height: 20),
  //       ],
  //     );
  //   }

  //   // -------------------
  //   // Build summary section
  //   // -------------------
  //   pw.Widget buildSummarySection() {
  //     return pw.Column(
  //       crossAxisAlignment: pw.CrossAxisAlignment.start,
  //       children: [
  //         pw.Text(
  //           "Summary",
  //           style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
  //         ),
  //         pw.SizedBox(height: 8),
  //         pw.Row(
  //           crossAxisAlignment: pw.CrossAxisAlignment.start,
  //           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //           children: [
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Text(
  //                   "Created Bills",
  //                   style: pw.TextStyle(
  //                     fontSize: 14,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //                 pw.SizedBox(height: 6),
  //                 pw.Text("UPI : ${createdUpiTotal.toStringAsFixed(2)}"),
  //                 pw.Text("Cash : ${createdCashTotal.toStringAsFixed(2)}"),
  //                 pw.Text("Unpaid : ${createdUnpaidTotal.toStringAsFixed(2)}"),
  //                 pw.SizedBox(height: 6),
  //                 pw.Text(
  //                   "Total : ${overallCreatedTotal.toStringAsFixed(2)}",
  //                   style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                 ),
  //               ],
  //             ),
  //             pw.Column(
  //               crossAxisAlignment: pw.CrossAxisAlignment.start,
  //               children: [
  //                 pw.Text(
  //                   "Outstanding Paid Today",
  //                   style: pw.TextStyle(
  //                     fontSize: 14,
  //                     fontWeight: pw.FontWeight.bold,
  //                   ),
  //                 ),
  //                 pw.SizedBox(height: 6),
  //                 pw.Text("UPI : ${paidTodayUpiTotal.toStringAsFixed(2)}"),
  //                 pw.Text("Cash : ${paidTodayCashTotal.toStringAsFixed(2)}"),
  //                 pw.SizedBox(height: 6),
  //                 pw.Text(
  //                   "Total : ${overallOutstandingTotal.toStringAsFixed(2)}",
  //                   style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       ],
  //     );
  //   }

  //   // -------------------
  //   // Helper to split bills into chunks (for large tables)
  //   // -------------------
  //   List<List<Bill>> splitBills(List<Bill> bills, int chunkSize) {
  //     List<List<Bill>> chunks = [];
  //     for (var i = 0; i < bills.length; i += chunkSize) {
  //       final end =
  //           (i + chunkSize < bills.length) ? i + chunkSize : bills.length;
  //       chunks.add(bills.sublist(i, end));
  //     }
  //     return chunks;
  //   }

  //   // -------------------
  //   // Split tables into manageable chunks
  //   // -------------------
  //   final createdChunks = splitBills(allCreated, 25);
  //   final paidTodayChunks = splitBills(allPaidToday, 26);

  //   // -------------------
  //   // Add pages for Created Bills
  //   // -------------------
  //   // for (var chunk in createdChunks) {
  //   //   pdf.addPage(
  //   //     pw.MultiPage(
  //   //       pageFormat: PdfPageFormat.a4,
  //   //       margin: const pw.EdgeInsets.all(20),
  //   //       build:
  //   //           (context) => [
  //   //             pw.Text(
  //   //               'Bills Report - ${DateFormat('dd/MM/yyyy').format(date)}',
  //   //               style: pw.TextStyle(
  //   //                 fontSize: 18,
  //   //                 fontWeight: pw.FontWeight.bold,
  //   //               ),
  //   //             ),
  //   //             pw.SizedBox(height: 12),
  //   //             buildCompleteSection("Created Bills", chunk),
  //   //           ],
  //   //     ),
  //   //   );
  //   // }

  //   int serial = 0; // global serial for Created Bills

  //   // -------------------
  //   // Created Bills Section
  //   // -------------------

  //   for (var i = 0; i < createdChunks.length; i++) {
  //     pdf.addPage(
  //       pw.MultiPage(
  //         pageFormat: PdfPageFormat.a4,
  //         margin: const pw.EdgeInsets.all(20),
  //         build: (context) {
  //           final children = <pw.Widget>[];
  //           // Only print title and date for the first chunk
  //           if (i == 0) {
  //             children.add(
  //               pw.Text(
  //                 'Bills Report - ${DateFormat('dd/MM/yyyy').format(date)}',
  //                 style: pw.TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //             );
  //             children.add(pw.SizedBox(height: 12));
  //           }

  //           children.add(
  //             buildCompleteSection("Created Bills", createdChunks[i], serial),
  //           );

  //           serial += createdChunks[i].length;
  //           return children;
  //         },
  //       ),
  //     );
  //   }

  //   // -------------------
  //   // Outstanding Paid Today Section
  //   // -------------------
  //   serial = 0; // reset serial for new section

  //   for (var i = 0; i < paidTodayChunks.length; i++) {
  //     pdf.addPage(
  //       pw.MultiPage(
  //         pageFormat: PdfPageFormat.a4,
  //         margin: const pw.EdgeInsets.all(20),
  //         build: (context) {
  //           final children = <pw.Widget>[];
  //           // Only print section title on the first chunk
  //           // if (i == 0) {
  //           //   children.add(
  //           //     pw.Text(
  //           //       'Outstanding Paid Today',
  //           //       style: pw.TextStyle(
  //           //         fontSize: 18,
  //           //         fontWeight: pw.FontWeight.bold,
  //           //       ),
  //           //     ),
  //           //   );
  //           //   children.add(pw.SizedBox(height: 12));
  //           // }

  //           children.add(
  //             buildCompleteSection(
  //               "Outstanding Paid Today",
  //               paidTodayChunks[i],
  //               serial,
  //             ),
  //           );
  //           serial += paidTodayChunks[i].length;
  //           return children;
  //         },
  //       ),
  //     );
  //   }

  //   // -------------------
  //   // Summary Page
  //   // -------------------
  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(20),
  //       build: (context) => [buildSummarySection()],
  //     ),
  //   );

  //   // -------------------
  //   // Save PDF
  //   // -------------------
  //   final dir = await getApplicationDocumentsDirectory();
  //   final path =
  //       "${dir.path}/Bills_Report_${DateFormat('ddMMyyyy').format(date)}.pdf";
  //   final file = File(path);
  //   await file.writeAsBytes(await pdf.save());
  //   await OpenFilex.open(file.path);

  //   print("PDF Generated at: $path");
  // }

  // Future<void> _generateReportPdf(
  //   BuildContext context,
  //   WidgetRef ref,
  //   DateTime date,
  // ) async {
  //   final firestore = ref.read(firestoreServiceProvider);
  //   final result = await firestore.fetchBillsByDate(date);

  //   final createdCash = result["created"]?["cash"] ?? [];
  //   final createdUpi = result["created"]?["upi"] ?? [];
  //   final createdUnpaid = result["created"]?["unpaid"] ?? [];

  //   final paidTodayCash = result["paidToday"]?["cash"] ?? [];
  //   final paidTodayUpi = result["paidToday"]?["upi"] ?? [];

  //   final allCreated = [...createdCash, ...createdUpi, ...createdUnpaid];
  //   final allPaidToday = [...paidTodayCash, ...paidTodayUpi];
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

  // Future<void> _generateReportPdf(
  //   BuildContext context,
  //   WidgetRef ref,
  //   DateTime date,
  // ) async {
  //   final result = await ref
  //       .read(firestoreServiceProvider)
  //       .fetchBillsByDate(date);

  //   List<Bill> created = result["created"]!;
  //   List<Bill> paidToday = result["paidToday"]!;

  //   // Load fonts
  //   final fontRegular = pw.Font.ttf(
  //     await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  //   );
  //   final fontBold = pw.Font.ttf(
  //     await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  //   );

  //   final pdf = pw.Document(
  //     theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
  //   );

  //   // Status sorting order
  //   final Map<String, int> statusRank = {
  //     "Paid (UPI)": 0,
  //     "Paid (Cash)": 1,
  //     "Half Paid (UPI)": 2,
  //     "Half Paid (Cash)": 3,
  //     "Unpaid": 4,
  //   };

  //   // Sort by Status → Date
  //   List<Bill> sortBills(List<Bill> bills) {
  //     bills.sort((a, b) {
  //       final sa = classifyStatus(a);
  //       final sb = classifyStatus(b);
  //       final ra = statusRank[sa]!;
  //       final rb = statusRank[sb]!;
  //       if (ra != rb) return ra - rb;
  //       return a.createdAt.compareTo(b.createdAt);
  //     });
  //     return bills;
  //   }

  //   created = sortBills([...created]);
  //   paidToday = sortBills([...paidToday]);

  //   // Build table rows
  //   List<List<String>> buildRows(List<Bill> bills) {
  //     int i = 1;
  //     return bills.map((b) {
  //       return [
  //         (i++).toString(),
  //         b.shopName ?? '',
  //         classifyStatus(b),
  //         (b.discountedTotal ?? 0).toStringAsFixed(2),
  //         (b.paidAmount ?? 0).toStringAsFixed(2),
  //         (b.balance ?? 0).toStringAsFixed(2),
  //         b.billNumber ?? '',
  //       ];
  //     }).toList();
  //   }

  //   double fullPaidUPI(List<Bill> bills) => bills
  //       .where((b) => b.isPaid == true && b.upiPayment == true)
  //       .fold(0, (s, b) => s + (b.discountedTotal ?? 0));

  //   double fullPaidCash(List<Bill> bills) => bills
  //       .where((b) => b.isPaid == true && b.upiPayment != true)
  //       .fold(0, (s, b) => s + (b.discountedTotal ?? 0));

  //   // HALF PAID (only paid amount)
  //   double halfPaidUPI(List<Bill> bills) => bills
  //       .where((b) => !b.isPaid && b.paidAmount > 0 && (b.upiPayment == true))
  //       .fold(0, (s, b) => s + (b.paidAmount ?? 0));

  //   double halfPaidCash(List<Bill> bills) => bills
  //       .where((b) => !b.isPaid && b.paidAmount > 0 && (b.upiPayment != true))
  //       .fold(0, (s, b) => s + (b.paidAmount ?? 0));

  //   // UNPAID TOTAL (half paid balance + fully unpaid)
  //   double unpaidTotal(List<Bill> bills) =>
  //       bills.fold(0, (s, b) => s + (b.balance ?? 0));

  //   // CREATED TOTALS
  //   final totalPaidUPI_created = fullPaidUPI(created) + halfPaidUPI(created);

  //   final totalPaidCash_created = fullPaidCash(created) + halfPaidCash(created);

  //   final totalUnpaid_created = unpaidTotal(created);

  //   final total_created_today =
  //       totalPaidUPI_created + totalPaidCash_created + totalUnpaid_created;

  //   // PAID TODAY TOTALS
  //   final totalPaidUPI_today = fullPaidUPI(paidToday) + halfPaidUPI(paidToday);

  //   final totalPaidCash_today =
  //       fullPaidCash(paidToday) + halfPaidCash(paidToday);

  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(20),
  //       build:
  //           (context) => [
  //             pw.Text(
  //               "Bills Report - ${DateFormat('dd/MM/yyyy').format(date)}",
  //               style: pw.TextStyle(
  //                 fontSize: 20,
  //                 fontWeight: pw.FontWeight.bold,
  //               ),
  //             ),
  //             pw.SizedBox(height: 15),

  //             pw.Text(
  //               "Created Bills",
  //               style: pw.TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: pw.FontWeight.bold,
  //               ),
  //             ),
  //             pw.SizedBox(height: 10),

  //             pw.TableHelper.fromTextArray(
  //               headers: [
  //                 "S.No",
  //                 "Shop",
  //                 "Status",
  //                 "Amount",
  //                 "Paid",
  //                 "Balance",
  //                 "Bill No",
  //               ],
  //               data: buildRows(created),
  //               headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //               cellAlignment: pw.Alignment.centerLeft,
  //             ),
  //           ],
  //     ),
  //   );

  //   // PAGE 2 - PAID TODAY
  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(20),
  //       build:
  //           (context) => [
  //             pw.Text(
  //               "Paid Today",
  //               style: pw.TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: pw.FontWeight.bold,
  //               ),
  //             ),
  //             pw.SizedBox(height: 10),

  //             pw.TableHelper.fromTextArray(
  //               headers: [
  //                 "S.No",
  //                 "Shop",
  //                 "Status",
  //                 "Amount",
  //                 "Paid",
  //                 "Balance",
  //                 "Bill No",
  //               ],
  //               data: buildRows(paidToday),
  //               headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //               cellAlignment: pw.Alignment.centerLeft,
  //             ),
  //           ],
  //     ),
  //   );

  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a4,
  //       margin: const pw.EdgeInsets.all(20),
  //       build:
  //           (context) => [
  //             pw.Text(
  //               "Summary",
  //               style: pw.TextStyle(
  //                 fontSize: 18,
  //                 fontWeight: pw.FontWeight.bold,
  //               ),
  //             ),
  //             pw.SizedBox(height: 20),

  //             pw.Text(
  //               "Created Bills Summary",
  //               style: pw.TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: pw.FontWeight.bold,
  //               ),
  //             ),
  //             pw.SizedBox(height: 10),

  //             pw.Text(
  //               "Paid UPI Total: \$${totalPaidUPI_created.toStringAsFixed(2)}",
  //             ),
  //             pw.Text(
  //               "Paid Cash Total: \$${totalPaidCash_created.toStringAsFixed(2)}",
  //             ),
  //             pw.Text(
  //               "Unpaid Total: \$${totalUnpaid_created.toStringAsFixed(2)}",
  //             ),
  //             pw.Text(
  //               "Total Sale Today: \$${total_created_today.toStringAsFixed(2)}",
  //             ),

  //             pw.SizedBox(height: 20),

  //             pw.Text(
  //               "Paid Today Summary",
  //               style: pw.TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: pw.FontWeight.bold,
  //               ),
  //             ),
  //             pw.SizedBox(height: 10),

  //             pw.Text(
  //               "Paid UPI Total: \$${totalPaidUPI_today.toStringAsFixed(2)}",
  //             ),
  //             pw.Text(
  //               "Paid Cash Total: \$${totalPaidCash_today.toStringAsFixed(2)}",
  //             ),
  //             pw.Text("Total outstanding paid today: \$${""}"),
  //           ],
  //     ),
  //   );

  //   // Save PDF
  //   final dir = await getApplicationDocumentsDirectory();
  //   final file = File(
  //     "${dir.path}/Bills_Report_${DateFormat('ddMMyyyy').format(date)}.pdf",
  //   );

  //   await file.writeAsBytes(await pdf.save());
  //   await OpenFilex.open(file.path);
  // }

  // Future<void> _generateReportPdf(
  //   BuildContext context,
  //   WidgetRef ref,
  //   DateTime date,
  // ) async {
  //   try {
  //     final result = await ref
  //         .read(firestoreServiceProvider)
  //         .fetchBillsByDate(date);

  //     List<Bill> created = result["created"] ?? [];
  //     List<Bill> paidToday = result["paidToday"] ?? [];

  //     // Load fonts
  //     final fontRegular = pw.Font.ttf(
  //       await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  //     );
  //     final fontBold = pw.Font.ttf(
  //       await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  //     );

  //     final pdf = pw.Document(
  //       theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
  //     );

  //     //---------------------------------------------------------------------------
  //     // STATUS SORTING
  //     //---------------------------------------------------------------------------
  //     String classifyStatus(Bill b) {
  //       if (b.isPaid == true) {
  //         if (b.upiPayment == true) return "Paid (UPI)";
  //         return "Paid (Cash)";
  //       }

  //       if ((b.paidAmount ?? 0) > 0 && (b.balance ?? 0) > 0) {
  //         if (b.upiPayment == true) return "Half Paid (UPI)";
  //         return "Half Paid (Cash)";
  //       }

  //       return "Unpaid";
  //     }

  //     final statusRank = {
  //       "Paid (UPI)": 0,
  //       "Paid (Cash)": 1,
  //       "Half Paid (UPI)": 2,
  //       "Half Paid (Cash)": 3,
  //       "Unpaid": 4,
  //     };

  //     List<Bill> sortBills(List<Bill> bills) {
  //       bills.sort((a, b) {
  //         final sa = classifyStatus(a);
  //         final sb = classifyStatus(b);
  //         if (statusRank[sa] != statusRank[sb]) {
  //           return statusRank[sa]!.compareTo(statusRank[sb]!);
  //         }
  //         return a.createdAt.compareTo(b.createdAt);
  //       });
  //       return bills;
  //     }

  //     created = sortBills(created);
  //     paidToday = sortBills(paidToday);

  //     //---------------------------------------------------------------------------
  //     // TABLE ROW BUILDING
  //     //---------------------------------------------------------------------------
  //     List<List<String>> buildRows(List<Bill> bills) {
  //       int i = 1;
  //       return bills.map((b) {
  //         return [
  //           (i++).toString(),
  //           (b.shopName ?? '').toString(),
  //           classifyStatus(b),
  //           (b.discountedTotal ?? 0).toStringAsFixed(2),
  //           (b.paidAmount ?? 0).toStringAsFixed(2),
  //           (b.balance ?? 0).toStringAsFixed(2),
  //           (b.billNumber ?? '').toString(),
  //         ];
  //       }).toList();
  //     }

  //     //---------------------------------------------------------------------------
  //     // SUMMARY TOTALS
  //     //---------------------------------------------------------------------------
  //     double fullPaidUPI(List<Bill> bills) => bills
  //         .where((b) => b.isPaid == true && b.upiPayment == true)
  //         .fold(0, (s, b) => s + (b.discountedTotal ?? 0));

  //     double fullPaidCash(List<Bill> bills) => bills
  //         .where((b) => b.isPaid == true && b.upiPayment != true)
  //         .fold(0, (s, b) => s + (b.discountedTotal ?? 0));

  //     double halfPaidUPI(List<Bill> bills) => bills
  //         .where(
  //           (b) =>
  //               (b.isPaid != true) &&
  //               (b.paidAmount ?? 0) > 0 &&
  //               b.upiPayment == true,
  //         )
  //         .fold(0, (s, b) => s + (b.paidAmount ?? 0));

  //     double halfPaidCash(List<Bill> bills) => bills
  //         .where(
  //           (b) =>
  //               (b.isPaid != true) &&
  //               (b.paidAmount ?? 0) > 0 &&
  //               b.upiPayment != true,
  //         )
  //         .fold(0, (s, b) => s + (b.paidAmount ?? 0));

  //     double unpaidTotal(List<Bill> bills) =>
  //         bills.fold(0, (s, b) => s + (b.balance ?? 0));

  //     // CREATED TOTAL
  //     final totalPaidUPI_created = fullPaidUPI(created) + halfPaidUPI(created);
  //     final totalPaidCash_created =
  //         fullPaidCash(created) + halfPaidCash(created);
  //     final totalUnpaid_created = unpaidTotal(created);
  //     final total_created_today =
  //         totalPaidUPI_created + totalPaidCash_created + totalUnpaid_created;

  //     // PAID TODAY TOTAL
  //     final totalPaidUPI_today =
  //         fullPaidUPI(paidToday) + halfPaidUPI(paidToday);
  //     final totalPaidCash_today =
  //         fullPaidCash(paidToday) + halfPaidCash(paidToday);

  //     //---------------------------------------------------------------------------
  //     // FINAL PDF (ONE PAGE FLOW)
  //     //---------------------------------------------------------------------------
  //     pdf.addPage(
  //       pw.MultiPage(
  //         pageFormat: PdfPageFormat.a4,
  //         margin: const pw.EdgeInsets.all(20),
  //         build:
  //             (context) => [
  //               // TITLE
  //               pw.Text(
  //                 "Bills Report - ${DateFormat('dd/MM/yyyy').format(date)}",
  //                 style: pw.TextStyle(
  //                   fontSize: 20,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //               pw.SizedBox(height: 20),

  //               //-------------------------------------------------------------------
  //               // CREATED BILLS SECTION
  //               //-------------------------------------------------------------------
  //               pw.Text(
  //                 "Created Bills",
  //                 style: pw.TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //               pw.SizedBox(height: 10),

  //               pw.TableHelper.fromTextArray(
  //                 headers: [
  //                   "S.No",
  //                   "Shop",
  //                   "Status",
  //                   "Amount",
  //                   "Paid",
  //                   "Balance",
  //                   "Bill No",
  //                 ],
  //                 data: buildRows(created),
  //                 headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //               ),

  //               pw.SizedBox(height: 25),

  //               //-------------------------------------------------------------------
  //               // PAID TODAY SECTION
  //               //-------------------------------------------------------------------
  //               pw.Text(
  //                 "Paid Today",
  //                 style: pw.TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //               pw.SizedBox(height: 10),

  //               pw.TableHelper.fromTextArray(
  //                 headers: [
  //                   "S.No",
  //                   "Shop",
  //                   "Status",
  //                   "Amount",
  //                   "Paid",
  //                   "Balance",
  //                   "Bill No",
  //                 ],
  //                 data: buildRows(paidToday),
  //                 headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
  //               ),

  //               pw.SizedBox(height: 25),

  //               //-------------------------------------------------------------------
  //               // SUMMARY SECTION
  //               //-------------------------------------------------------------------
  //               pw.Text(
  //                 "Summary",
  //                 style: pw.TextStyle(
  //                   fontSize: 18,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //               pw.SizedBox(height: 20),

  //               pw.Text(
  //                 "Paid UPI Total (Created): \$${totalPaidUPI_created.toStringAsFixed(2)}",
  //               ),
  //               pw.Text(
  //                 "Paid Cash Total (Created): \$${totalPaidCash_created.toStringAsFixed(2)}",
  //               ),
  //               pw.Text(
  //                 "Unpaid Total (Created): \$${totalUnpaid_created.toStringAsFixed(2)}",
  //               ),
  //               pw.Text(
  //                 "Total Sale Today: \$${total_created_today.toStringAsFixed(2)}",
  //               ),

  //               pw.SizedBox(height: 20),

  //               pw.Text(
  //                 "Paid Today Summary",
  //                 style: pw.TextStyle(
  //                   fontSize: 16,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //               pw.SizedBox(height: 10),

  //               pw.Text(
  //                 "Paid UPI Today: \$${totalPaidUPI_today.toStringAsFixed(2)}",
  //               ),
  //               pw.Text(
  //                 "Paid Cash Today: \$${totalPaidCash_today.toStringAsFixed(2)}",
  //               ),
  //             ],
  //       ),
  //     );

  //     //---------------------------------------------------------------------------
  //     // SAVE & OPEN
  //     //---------------------------------------------------------------------------
  //     final dir = await getApplicationDocumentsDirectory();
  //     final file = File(
  //       "${dir.path}/Bills_Report_${DateFormat('ddMMyyyy').format(date)}.pdf",
  //     );

  //     await file.writeAsBytes(await pdf.save());
  //     print("PDF saved: ${file.path}");

  //     await OpenFilex.open(file.path);
  //   } catch (e, st) {
  //     print("PDF ERROR: $e");
  //     print(st);
  //   }
  // }

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
        if (b.isPaid == true) {
          if (b.upiPayment == true) return "Paid (UPI)";
          return "Paid (Cash)";
        }

        if ((b.paidAmount) > 0 && (b.balance) > 0) {
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
          return [
            (i++).toString(),
            b.shopName,
            classifyStatus(b),
            (b.discountedTotal).toStringAsFixed(2),
            (b.paidAmount).toStringAsFixed(2), // cumulative
            (b.balance).toStringAsFixed(2),
            b.billNumber,
          ];
        }).toList();
      }

      List<List<String>> buildRowsPaidToday(List<Bill> bills) {
        int i = 1;
        return bills.map((b) {
          return [
            (i++).toString(),
            b.shopName,
            classifyStatus(b),
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
          .where((b) => b.isPaid == true && b.upiPayment == true)
          .fold(0, (s, b) => s + b.discountedTotal);

      double fullPaidCash(List<Bill> bills) => bills
          .where((b) => b.isPaid == true && b.upiPayment != true)
          .fold(0, (s, b) => s + b.discountedTotal);

      double halfPaidUPI(List<Bill> bills) => bills
          .where((b) => !b.isPaid && b.paidAmount > 0 && b.upiPayment == true)
          .fold(0, (s, b) => s + b.paidAmount);

      double halfPaidCash(List<Bill> bills) => bills
          .where((b) => !b.isPaid && b.paidAmount > 0 && b.upiPayment != true)
          .fold(0, (s, b) => s + b.paidAmount);

      double unpaidTotal(List<Bill> bills) =>
          bills.fold(0, (s, b) => s + b.balance);

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
                unpaidBillsAsync.whenData((shopsData) async {
                  final dateFiltered = _filterShopsData(shopsData);

                  if (dateFiltered.isNotEmpty) {
                    _showShopSelectionDialog(context, dateFiltered);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No shops with balance found for current filter.',
                        ),
                      ),
                    );
                  }
                });
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
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
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

          Column(
            children: [
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
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) {
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
                              Navigator.pop(context);
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
                  onPressed: () => Navigator.pop(context),
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
                                    final bills = await firestore
                                        .fetchBillsByIds(selectedIds);
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