import 'package:billing/features/models/bill.dart';
import 'package:billing/features/providers/bill_provider.dart';

import 'package:billing/features/services/pdfservices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../models/product.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final TextEditingController shopNameController = TextEditingController();
  String? selectedShopName;

  void _editQuantityDialog(BillItem item) {
    final controller = TextEditingController(text: item.quantity.toString());
    int updatedQty = item.quantity;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Edit Quantity - ${item.name}'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Enter new quantity'),
              onChanged: (val) {
                updatedQty = int.tryParse(val) ?? item.quantity;
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (updatedQty > 0) {
                    ref
                        .read(billingProvider.notifier)
                        .updateItemQuantity(item, updatedQty);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  void _previewBillDialog() async {
    final shopName = shopNameController.text.trim();
    final (previewBill, _) = await ref
        .read(billingProvider.notifier)
        .generateBill(shopName, false, isPreview: true);

    bool tempPaid = false;
    final paidAmountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Preview Bill'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🧾 Shop: $shopName'),
                      const SizedBox(height: 10),

                      const Text(
                        'Previous Bill Status:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),

                      if (previewBill.previousUnpaid == 0)
                        const Text(
                          '✅ No previous pending bills.',
                          style: TextStyle(color: Colors.green),
                        )
                      else
                        Text(
                          '🔴 ₹${previewBill.previousUnpaid.toStringAsFixed(2)} unpaid from last bill',
                          style: const TextStyle(color: Colors.red),
                        ),

                      const Divider(),

                      const Text(
                        'Current Purchase:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      ...previewBill.items.map(
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
                        '🕗 Previous Unpaid Total: ₹${previewBill.previousUnpaid.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      Text(
                        '🛒 Current Purchase Total: ₹${previewBill.currentPurchaseTotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '🧾 Grand Total (Final): ₹${previewBill.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔹 Paid Amount TextField
                      TextField(
                        controller: paidAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Enter Paid Amount (if any)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🔹 Payment Status
                      Row(
                        children: [
                          const Text('Payment Status:'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Row(
                              children: [
                                Radio<bool>(
                                  value: true,
                                  groupValue: tempPaid,
                                  onChanged:
                                      (val) => setState(() => tempPaid = true),
                                ),
                                const Text('Paid'),
                                Radio<bool>(
                                  value: false,
                                  groupValue: tempPaid,
                                  onChanged:
                                      (val) => setState(() => tempPaid = false),
                                ),
                                const Text('Unpaid'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    shopNameController.clear();

                    final paidAmount =
                        double.tryParse(paidAmountController.text.trim()) ??
                        0.0;

                    final (finalBill, _) = await ref
                        .read(billingProvider.notifier)
                        .generateBill(
                          shopName,
                          tempPaid,
                          paidAmount: paidAmount,
                        );

                    await generateAndOpenPdf(finalBill);
                  },
                  child: const Text('Generate PDF'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showProductSelectionDialog() {
    final productAsync = ref.read(productsProvider);
    final Map<String, TextEditingController> quantityControllers = {};

    showDialog(
      context: context,
      barrierDismissible:
          false, // Dialog stays open until user cancels or submits
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Products & Quantities'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: productAsync.when(
              data: (products) {
                for (var product in products) {
                  quantityControllers[product.id] =
                      TextEditingController(); // No prefilled value
                }

                return ListView.separated(
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final controller = quantityControllers[product.id]!;

                    return ListTile(
                      title: Text(product.name),
                      subtitle: Row(
                        children: [
                          const Text('Qty: '),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              // decoration: const InputDecoration(
                              //   isDense: true,
                              //   contentPadding: EdgeInsets.symmetric(
                              //     horizontal: 6,
                              //     vertical: 8,
                              //   ),
                              //   border: OutlineInputBorder(),
                              // ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Failed to load products'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final products = ref.read(productsProvider).asData?.value ?? [];
                for (var product in products) {
                  final qtyStr =
                      quantityControllers[product.id]?.text.trim() ?? '0';
                  final qty = int.tryParse(qtyStr) ?? 0;
                  if (qty > 0) {
                    ref.read(billingProvider.notifier).addItem(product, qty);
                  }
                }
                Navigator.pop(context); // Close dialog after all added
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bill = ref.watch(billingProvider);
    final productAsync = ref.watch(productsProvider);
    final shopNamesAsync = ref.watch(shopNamesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),

      appBar: AppBar(
        title: const Text(
          'Billing Screen',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color.fromARGB(255, 2, 113, 192),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Shop Name Field with Autocomplete
            shopNamesAsync.when(
              data:
                  (names) => Column(
                    children: [
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '')
                            return const Iterable<String>.empty();
                          return names.where(
                            (name) => name.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            ),
                          );
                        },
                        onSelected: (String selection) {
                          shopNameController.text = selection;
                        },
                        fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          controller.text = shopNameController.text;
                          controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: controller.text.length),
                          );
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Shop Name',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (val) => shopNameController.text = val,
                          );
                        },
                      ),
                    ],
                  ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Failed to load shop names'),
            ),
            const SizedBox(height: 10),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.white),
                  ),
                  onPressed: _showProductSelectionDialog,
                  icon: const Icon(
                    Icons.add_shopping_cart,
                    color: const Color.fromARGB(255, 2, 113, 192),
                  ),
                  label: const Text(
                    'Add Products',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 2, 113, 192),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.white),
                  ),
                  onPressed: _previewBillDialog,
                  icon: const Icon(
                    Icons.preview,
                    color: const Color.fromARGB(255, 2, 113, 192),
                  ),
                  label: const Text(
                    'Preview Bill',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 2, 113, 192),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (bill.items.isNotEmpty)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Added Products:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: ListView.builder(
                        itemCount: bill.items.length,
                        itemBuilder: (_, index) {
                          final item = bill.items[index];
                          return ListTile(
                            title: Text('${item.name} x${item.quantity}'),
                            subtitle: Text(
                              '₹${item.price.toStringAsFixed(2)} each',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                ),
                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editQuantityDialog(item),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    ref
                                        .read(billingProvider.notifier)
                                        .removeItem(item);
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Total: ₹${bill.total.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
