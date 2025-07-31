import 'package:billing/core/utils/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/bill.dart';
import '../services/firestore_services.dart';

class BillExplorerScreen extends ConsumerStatefulWidget {
  const BillExplorerScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final firestore = ref.watch(firestoreServiceProvider);

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
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
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
                child: FutureBuilder<List<String>>(
                  future: firestore.fetchShopsWithpaidBills(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 2, 113, 192),
                        ),
                      );
                    }
                    final shops =
                        snapshot.data!
                            .where(
                              (shop) => shop.toLowerCase().contains(shopQuery),
                            )
                            .toList();
                    if (shops.isEmpty) {
                      return const Center(child: Text('No paid bills found.'));
                    }
                    return ListView.builder(
                      itemCount: shops.length,
                      itemBuilder: (context, index) {
                        final shop = shops[index];
                        return FutureBuilder<Bill?>(
                          future: firestore.fetchLatestpaidBillForShop(shop),
                          builder: (context, billSnap) {
                            if (!billSnap.hasData)
                              return const SizedBox.shrink();
                            final bill = billSnap.data!;
                            return ListTile(
                              title: Text(
                                shop,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Balance : \$ ${bill.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                              trailing: Text(
                                DateFormat(
                                  'dd MMM yy',
                                ).format(bill.createdAt.toDate()),
                              ),
                              onTap: () async {
                                await showLoadingWhile(
                                  context,
                                  ref
                                      .read(firestoreServiceProvider)
                                      .fetchUnpaidBillsForShop(shop),
                                );

                                _showBillDialog(context, bill);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Column(
            children: [
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
                child: FutureBuilder<List<String>>(
                  future: firestore.fetchShopsWithUnpaidBills(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color.fromARGB(255, 2, 113, 192),
                        ),
                      );
                    }
                    final shops =
                        snapshot.data!
                            .where(
                              (shop) => shop.toLowerCase().contains(shopQuery),
                            )
                            .toList();
                    if (shops.isEmpty) {
                      return const Center(
                        child: Text('No unpaid bills found.'),
                      );
                    }
                    return ListView.builder(
                      itemCount: shops.length,
                      itemBuilder: (context, index) {
                        final shop = shops[index];
                        return FutureBuilder<Bill?>(
                          future: firestore.fetchLatestUnpaidBillForShop(shop),
                          builder: (context, billSnap) {
                            if (!billSnap.hasData)
                              return const SizedBox.shrink();
                            final bill = billSnap.data!;
                            return ListTile(
                              title: Text(
                                shop,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Balance : \$ ${bill.total.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red,
                                ),
                              ),
                              trailing: Text(
                                DateFormat(
                                  'dd MMM yy',
                                ).format(bill.createdAt.toDate()),
                              ),
                              onTap: () async {
                                await showLoadingWhile(
                                  context,
                                  ref
                                      .read(firestoreServiceProvider)
                                      .fetchUnpaidBillsForShop(shop),
                                );

                                _showBillDialog(context, bill);
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
                                    '\$${bill.currentPurchaseTotal.toStringAsFixed(2)}',
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

  void _showBillDialog(BuildContext context, Bill bill) async {
    final unpaidBills = await ref
        .read(firestoreServiceProvider)
        .fetchUnpaidBillsForShop(bill.shopName);

    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFFE3F2FD),
            title: Row(
              children: [
                Text('Bill #: ${bill.billNumber}'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: bill.billNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied Bill #${bill.billNumber}'),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy, size: 18, color: Colors.grey),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Unpaid Bills',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: unpaidBills.length,
                      itemBuilder: (context, index) {
                        final b = unpaidBills[index];
                        return ListTile(
                          dense: true,
                          title: Row(
                            children: [
                              Text('Bill #${b.billNumber}'),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(
                                    ClipboardData(text: b.billNumber),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Copied Bill #${b.billNumber}',
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
                            ).format(b.createdAt.toDate()),
                          ),
                          trailing: Text(
                            '\$${b.currentPurchaseTotal.toStringAsFixed(2)}',
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Total Unpaid : \$ ${bill.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              // if (!bill.isPaid)
              //   TextButton(
              //     onPressed: () async {
              //       final confirmed = await showDialog<bool>(
              //         context: context,
              //         barrierDismissible: false,
              //         builder:
              //             (ctx) => AlertDialog(
              //               backgroundColor: const Color(0xFFE3F2FD),
              //               title: const Text('Mark as Paid?'),
              //               content: const Text(
              //                 'Are you sure you want to mark this bill as paid?',
              //               ),
              //               actions: [
              //                 TextButton(
              //                   onPressed: () => Navigator.of(ctx).pop(false),
              //                   child: const Text(
              //                     'Cancel',
              //                     style: TextStyle(color: Colors.red),
              //                   ),
              //                 ),
              //                 ElevatedButton(
              //                   style: ButtonStyle(
              //                     backgroundColor: WidgetStatePropertyAll(
              //                       Colors.white,
              //                     ),
              //                   ),
              //                   onPressed: () => Navigator.of(ctx).pop(true),
              //                   child: const Text(
              //                     'Confirm',
              //                     style: TextStyle(color: Color(0xFF00A105)),
              //                   ),
              //                 ),
              //               ],
              //             ),
              //       );
              //       if (confirmed == true) {
              //         await ref
              //             .read(firestoreServiceProvider)
              //             .updateBillPaymentStatus(bill.id, true);
              //         Navigator.pop(context);
              //         ScaffoldMessenger.of(context).showSnackBar(
              //           const SnackBar(content: Text('Marked as Paid')),
              //         );
              //         setState(() {});
              //       }
              //     },
              //     child: const Text(
              //       'Mark as Paid',
              //       style: TextStyle(color: Color(0xFF00A105)),
              //     ),
              //   ),
              TextButton(
                onPressed: () async {
                  final TextEditingController amountController =
                      TextEditingController();

                  final confirmed = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFFE3F2FD),
                          title: const Text('Enter Payment Amount'),
                          content: TextField(
                            cursorColor: Color.fromARGB(255, 2, 113, 192),
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount Paid',
                              border: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color.fromARGB(255, 2, 113, 192),
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: const ButtonStyle(
                                backgroundColor: WidgetStatePropertyAll(
                                  Colors.white,
                                ),
                              ),
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text(
                                'Submit',
                                style: TextStyle(color: Color(0xFF00A105)),
                              ),
                            ),
                          ],
                        ),
                  );

                  if (confirmed == true) {
                    final enteredAmount = double.tryParse(
                      amountController.text.trim(),
                    );
                    if (enteredAmount == null || enteredAmount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid amount entered.'),
                        ),
                      );
                      return;
                    }

                    double remaining = enteredAmount;

                    for (final b in unpaidBills) {
                      if (remaining >= b.total) {
                        await showLoadingWhile(
                          context,
                          ref
                              .read(firestoreServiceProvider)
                              .markAllUnpaidBillsAsPaid(b.shopName),
                        );
                        remaining -= b.total;
                      } else {
                        final newTotal = b.total - remaining;
                        await showLoadingWhile(
                          context,
                          ref
                              .read(firestoreServiceProvider)
                              .markUnpaidBillsAsPaidAndMakeLatestAsUnpaid(
                                b.shopName,
                                newTotal,
                              ),
                        );

                        remaining = 0;
                        break;
                      }
                    }

                    if (remaining > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Overpaid by \$${remaining.toStringAsFixed(2)}',
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Payment applied successfully.'),
                        ),
                      );
                    }

                    Navigator.pop(context);
                    setState(() {});
                  }
                },
                child: const Text(
                  'Mark as Paid',
                  style: TextStyle(color: Color(0xFF00A105)),
                ),
              ),
            ],
          ),
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
              children: [
                Text('Bill #: ${bill.billNumber}'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: bill.billNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied Bill #${bill.billNumber}'),
                      ),
                    );
                  },
                  child: const Icon(Icons.copy, size: 18, color: Colors.grey),
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
                            'Qty: ${item.quantity} x \$${item.price.toStringAsFixed(2)}',
                          ),
                          trailing: Text('\$${item.total.toStringAsFixed(2)}'),
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
                            Text('Current Total :'),
                            Text(
                              '\$ ${bill.currentPurchaseTotal.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Previous Unpaid :'),
                            Text(
                              '\$ ${bill.previousUnpaid.toStringAsFixed(2)}',
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
                        // Text(
                        //   'Paid Amount: \$ ${bill.paidAmount.toStringAsFixed(2)}',
                        // ),
                        const SizedBox(height: 4),
                        // Text(
                        //   'Total Due: \$ ${bill.remainingUnpaid.toStringAsFixed(2)}',
                        //   style: const TextStyle(
                        //     color: Colors.red,
                        //     fontWeight: FontWeight.bold,
                        //   ),
                        // ),
                        // Text(
                        //   'Total : \$ ${bill.previousUnpaid.toStringAsFixed(2)}',
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
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
