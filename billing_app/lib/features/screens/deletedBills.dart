import 'package:billing/features/providers/bill_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart';

class DeletedBillsScreen extends ConsumerWidget {
  const DeletedBillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedBillsAsync = ref.watch(deletedBillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Deleted Bills"),
        backgroundColor: Colors.redAccent,
      ),
      body: deletedBillsAsync.when(
        data: (bills) {
          if (bills.isEmpty) {
            return const Center(child: Text("No deleted bills found."));
          }

          return ListView.builder(
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              final createdAt = DateFormat(
                'dd-MM-yy',
              ).format(bill.createdAt.toDate());

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  title: Text(
                    "Bill #${bill.billNumber}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Shop: ${bill.shopName}"),
                  childrenPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text("Created:"), Text(createdAt)],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Status:"),
                        Text(bill.isPaid ? "Paid" : "Unpaid"),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Amount:"),
                        Text(bill.discountedTotal.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Paid Amount:"),
                        Text(bill.paidAmount.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Balance:"),
                        Text(bill.balance.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Restore button (optional)
                    // Align(
                    //   alignment: Alignment.centerRight,
                    //   child: TextButton.icon(
                    //     icon: const Icon(Icons.restore, color: Colors.green),
                    //     label: const Text("Restore"),
                    //     onPressed: () async {
                    //       await restoreBill(bill.billNumber); // move back to bills
                    //       ScaffoldMessenger.of(context).showSnackBar(
                    //         const SnackBar(content: Text("Bill restored!")),
                    //       );
                    //       ref.refresh(deletedBillsProvider);
                    //     },
                    //   ),
                    // ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: $e")),
      ),
    );
  }
}
