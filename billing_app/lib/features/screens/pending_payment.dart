import 'package:flutter/material.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by shop name...',
                    prefixIcon: Icon(Icons.search),
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
                      return const Center(child: CircularProgressIndicator());
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
                              title: Text(shop),
                              subtitle: Text(
                                'Unpaid: ₹${bill.total.toStringAsFixed(2)}',
                              ),
                              trailing: Text(
                                DateFormat(
                                  'dd MMM',
                                ).format(bill.createdAt.toDate()),
                              ),
                              onTap: () => _showBillDialog(context, bill),
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
                  controller: _billSearchController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Bill Number',
                    prefixIcon: Icon(Icons.receipt_long),
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
                                child: CircularProgressIndicator(),
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
                                    '₹${bill.total.toStringAsFixed(2)}',
                                  ),
                                  onTap: () => _showBillDialog(context, bill),
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

  void _showBillDialog(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Bill #: ${bill.billNumber}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🦾 Shop: ${bill.shopName}'),
                  Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(bill.createdAt.toDate())}',
                  ),
                  const SizedBox(height: 10),
                  const Text('Items:'),
                  ...bill.items.map(
                    (item) => ListTile(
                      dense: true,
                      title: Text('${item.name} x${item.quantity}'),
                      trailing: Text(
                        '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                      ),
                    ),
                  ),
                  const Divider(),
                  Text(
                    'Previous Unpaid: ₹${bill.previousUnpaid.toStringAsFixed(2)}',
                  ),
                  Text(
                    'Current Total: ₹${bill.currentPurchaseTotal.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ₹${bill.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    bill.isPaid ? '✅ Paid' : '🔴 Unpaid',
                    style: TextStyle(
                      color: bill.isPaid ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (!bill.isPaid)
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (ctx) => AlertDialog(
                            title: const Text('Mark as Paid?'),
                            content: const Text(
                              'Are you sure you want to mark this bill as paid?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Confirm'),
                              ),
                            ],
                          ),
                    );
                    if (confirmed == true) {
                      await ref
                          .read(firestoreServiceProvider)
                          .updateBillPaymentStatus(bill.id, true);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Marked as Paid')),
                      );
                      setState(() {});
                    }
                  },
                  child: const Text('Mark as Paid'),
                ),
              TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('Delete Bill?'),
                          content: const Text(
                            'This action cannot be undone. Proceed?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete'),
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
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
