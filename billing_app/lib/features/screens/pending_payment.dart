import 'package:billing/core/utils/loading.dart';
import 'package:billing/features/providers/bill_provider.dart';

import 'package:billing/features/services/pdfservices.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/bill.dart';
import '../services/firestore_services.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

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

  // Helper method to check if a bill matches the date filter
  bool _matchesDateFilter(Bill bill) {
    if (filterType == 'none') return true;

    final billDate = bill.createdAt.toDate();

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

    // Normal filtering logic
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

  // Helper method to calculate daily and monthly totals
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
        final billDate = bill.createdAt.toDate();
        final billDateOnly = DateTime(
          billDate.year,
          billDate.month,
          billDate.day,
        );
        final todayOnly = DateTime(today.year, today.month, today.day);

        // Check if bill is from today
        if (billDateOnly.isAtSameMomentAs(todayOnly)) {
          dailyTotal += isPaid ? bill.discountedTotal : bill.balance;
        }

        // Check if bill is from current month
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
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 226, 88, 78),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  barrierDismissible: false,
                  context: context,
                  builder:
                      (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFFE3F2FD),
                        title: const Text('Delete ALL Bills?'),
                        content: const Text(
                          '⚠️ This will delete the entire bills collection.\nAre you sure?',
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Delete All',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                );

                if (confirmed == true) {
                  await ref.read(firestoreServiceProvider).deleteAllBills();
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All bills deleted')),
                  );
                  setState(() {});
                }
              },
              child: const Text('Delete All Bills'),
            ),
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
                                  _showPaidBillsDialog(context, paidBills);
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
                                    unpaidBills,
                                    ref,
                                    shopName,
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

  void _showPaidBillsDialog(BuildContext context, List<Bill> paidBills) {
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

            return AlertDialog(
              contentPadding: EdgeInsets.all(0),
              backgroundColor: const Color(0xFFE3F2FD),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Paid Bills'),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
              content: SizedBox(
                // width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔍 Search field
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

                    // List of bills
                    SizedBox(
                      height: 400,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredBills.length,
                        itemBuilder: (context, index) {
                          final bill = filteredBills[index];
                          return ListTile(
                            dense: true,
                            title: Row(
                              children: [
                                Text('${bill.billNumber}'),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: bill.billNumber),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
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
                            subtitle: Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(bill.createdAt.toDate()),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '\$ ${bill.discountedTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    await generateAndOpenPdf(bill, false);
                                  },
                                  icon: Icon(
                                    Icons.download,
                                    size: 18,
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
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Total: \$ ${totalPaid.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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

  // Rest of the methods remain the same...
  // void _showPaidBillsDialog(BuildContext context, List<Bill> paidBills) {
  //   final totalPaid = paidBills.fold<double>(
  //     0,
  //     (sum, bill) => sum + bill.discountedTotal,
  //   );

  //   showDialog(
  //     barrierDismissible: false,
  //     context: context,
  //     builder:
  //         (ctx) => AlertDialog(
  //           backgroundColor: const Color(0xFFE3F2FD),
  //           title: Row(
  //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //             children: [
  //               const Text('Paid Bills'),
  //               GestureDetector(
  //                 onTap: () {
  //                   Navigator.of(context).pop();
  //                 },
  //                 child: const Icon(Icons.close, color: Colors.red),
  //               ),
  //             ],
  //           ),
  //           content: SizedBox(
  //             width: double.maxFinite,
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 SizedBox(
  //                   height: 400,
  //                   child: ListView.builder(
  //                     shrinkWrap: true,
  //                     itemCount: paidBills.length,
  //                     itemBuilder: (context, index) {
  //                       final bill = paidBills[index];
  //                       return ListTile(
  //                         dense: true,
  //                         title: Row(
  //                           children: [
  //                             Text('Bill #${bill.billNumber}'),
  //                             const SizedBox(width: 8),
  //                             GestureDetector(
  //                               onTap: () {
  //                                 Clipboard.setData(
  //                                   ClipboardData(text: bill.billNumber),
  //                                 );
  //                                 ScaffoldMessenger.of(
  //                                   context,
  //                                 ).clearSnackBars();
  //                                 ScaffoldMessenger.of(context).showSnackBar(
  //                                   SnackBar(
  //                                     content: Text(
  //                                       'Copied Bill #${bill.billNumber}',
  //                                     ),
  //                                   ),
  //                                 );
  //                               },
  //                               child: const Icon(
  //                                 Icons.copy,
  //                                 size: 18,
  //                                 color: Colors.grey,
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         subtitle: Text(
  //                           DateFormat(
  //                             'dd MMM yyyy',
  //                           ).format(bill.createdAt.toDate()),
  //                         ),
  //                         trailing: Text(
  //                           '\$ ${bill.discountedTotal.toStringAsFixed(2)}',
  //                           style: const TextStyle(color: Colors.green),
  //                         ),
  //                       );
  //                     },
  //                   ),
  //                 ),
  //                 const Divider(),
  //                 Align(
  //                   alignment: Alignment.centerRight,
  //                   child: Text(
  //                     'Total: \$ ${totalPaid.toStringAsFixed(2)}',
  //                     style: const TextStyle(
  //                       fontWeight: FontWeight.bold,
  //                       fontSize: 16,
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //   );
  // }

  void _showUnPaidBillsDialog(
    BuildContext context,
    List<Bill> unpaidBills,
    WidgetRef ref,
    String shopName,
  ) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        final selectedBills = <String, Bill>{};
        final TextEditingController _paidAmountController =
            TextEditingController();
        List<Bill> filteredBills = List.from(unpaidBills);
        final TextEditingController searchController = TextEditingController();

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

            return AlertDialog(
              contentPadding: EdgeInsets.all(0),
              backgroundColor: const Color(0xFFE3F2FD),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('UnPaid Bills'),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
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
                    SizedBox(
                      height: 400,
                      child: ListView.builder(
                        itemCount: unpaidBills.length,
                        itemBuilder: (context, index) {
                          final bill = unpaidBills[index];
                          final isSelected = selectedBills.containsKey(bill.id);

                          return Row(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  fontSize: 12,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await generateAndOpenPdf(bill, false);
                                },
                                icon: Icon(
                                  Icons.download,
                                  size: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Total : \$ ${totalSelectedBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextFormField(
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  controller: _paidAmountController,
                  cursorErrorColor: Color.fromARGB(255, 2, 113, 192),
                  cursorColor: Color.fromARGB(255, 2, 113, 192),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixText: "\$ ",
                    labelStyle: TextStyle(
                      color: Color.fromARGB(255, 2, 113, 192),
                    ),
                    labelText: 'Enter Paid Amount',
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                      borderSide: BorderSide(
                        color: Color.fromARGB(255, 2, 113, 192),
                        width: 2,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(20)),
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
                SizedBox(height: 8),
                ElevatedButton(
                  style: const ButtonStyle(
                    elevation: WidgetStatePropertyAll(4),
                    backgroundColor: WidgetStatePropertyAll(Colors.white),
                  ),
                  onPressed: () async {
                    if (_paidAmountController.text.isEmpty) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please enter the paid amount"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    if (selectedBills.isEmpty) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please select at least one bill"),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    final firestore = ref.read(firestoreServiceProvider);
                    final selectedIds = selectedBills.keys.toList();

                    final paidAmount =
                        double.tryParse(_paidAmountController.text.trim()) ??
                        0.0;

                    await showLoadingWhileTask(context, () async {
                      final bills = await firestore.fetchBillsByIds(
                        selectedIds,
                      );
                      await firestore.markBillsAsPaid(bills, paidAmount);
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
                    style: TextStyle(color: Color(0xFF00A105), fontSize: 12),
                  ),
                ),
              ],
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
