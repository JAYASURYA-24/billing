import 'package:billing/core/utils/loading.dart';
import 'package:billing/core/widgets/shopserach.dart';
import 'package:billing/features/models/bill.dart';
import 'package:billing/features/models/shop.dart';
import 'package:billing/features/providers/bill_provider.dart';
import 'package:billing/features/providers/shop_provider.dart';

import 'package:billing/features/services/pdfservices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final TextEditingController shopNameController = TextEditingController();

  Shop? selectedShop;
  void _editQuantityDialog(BillItem item) {
    final controller = TextEditingController(text: item.quantity.toString());
    int updatedQty = item.quantity;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFFE3F2FD),
            title: Text('Edit Qty - ${item.name}'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              cursorColor: const Color.fromARGB(255, 2, 113, 192),
              decoration: const InputDecoration(
                hintText: 'Enter new quantity',
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 2, 113, 192),
                  ),
                ),
              ),
              onChanged: (val) {
                updatedQty = int.tryParse(val) ?? item.quantity;
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.red),
                ),
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
                child: const Text(
                  'Update',
                  style: TextStyle(color: Color.fromARGB(255, 0, 161, 5)),
                ),
              ),
            ],
          ),
    );
  }

  void _previewBillDialog() async {
    final shopName = shopNameController.text.trim();
    final (previewBill, _) = await showLoadingWhile(
      context,
      ref
          .read(billingProvider.notifier)
          .generateBill(shopName, false, isPreview: true),
    );

    bool tempPaid = true;
    final paidAmountController = TextEditingController();

    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFE3F2FD),
              title: const Text('Preview Bill'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Shop: $shopName',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),

                    if (previewBill.previousUnpaid == 0)
                      const Text(
                        'No previous pending bills...',
                        style: TextStyle(color: Color.fromARGB(255, 0, 161, 5)),
                      )
                    else
                      Text(
                        '₹${previewBill.previousUnpaid.toStringAsFixed(2)} unpaid from last bill',
                        style: const TextStyle(color: Colors.red),
                      ),

                    const Divider(),

                    const Text(
                      'Current Purchase:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 200, // adjust height as needed
                      child: ListView.builder(
                        itemCount: previewBill.items.length,
                        itemBuilder: (context, index) {
                          final item = previewBill.items[index];
                          return ListTile(
                            visualDensity: VisualDensity(vertical: -4),
                            dense: true,
                            title: Text('${item.name} x ${item.quantity}'),
                            trailing: Text(
                              '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Previous Unpaid : ',
                          style: const TextStyle(color: Colors.red),
                        ),
                        Text(
                          "₹ ${previewBill.previousUnpaid.toStringAsFixed(2)}",
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Purchase : ',
                          style: const TextStyle(
                            color: const Color.fromARGB(255, 2, 113, 192),
                          ),
                        ),
                        Text(
                          '₹ ${previewBill.currentPurchaseTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: const Color.fromARGB(255, 2, 113, 192),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Grand Total : ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '₹ ${previewBill.total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 18,
                          ),
                        ),
                      ],
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
                                activeColor: Colors.green,
                                value: true,
                                groupValue: tempPaid,
                                onChanged:
                                    (val) => setState(() => tempPaid = true),
                              ),
                              const Text('Paid'),
                              Radio<bool>(
                                activeColor: Colors.red,
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(Colors.white),
                  ),
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
                    ref.read(selectedShopProvider.notifier).state = null;

                    await generateAndOpenPdf(finalBill);
                  },
                  child: const Text(
                    'Generate PDF',
                    style: TextStyle(
                      color: const Color.fromARGB(255, 2, 113, 192),
                    ),
                  ),
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
          backgroundColor: const Color(0xFFE3F2FD),
          title: const Text('Select Products & Quantities'),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
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
                      trailing: SizedBox(
                        width: 80,
                        child: TextField(
                          cursorColor: const Color.fromARGB(255, 2, 113, 192),
                          controller: controller,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffix: Text(
                              'kg',
                              style: TextStyle(color: Colors.black),
                            ),

                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),

                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: const Color.fromARGB(255, 2, 113, 192),
                              ),
                            ),
                          ),
                        ),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(Colors.white),
              ),
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
              child: const Text(
                'Done',
                style: TextStyle(color: Color.fromARGB(255, 0, 161, 5)),
              ),
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

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),

        appBar: AppBar(
          title: const Text(
            'Billing Screen',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color.fromARGB(255, 2, 113, 192),
          actions: [
            IconButton(
              onPressed: () {
                ref.invalidate(billingProvider);
                ref.invalidate(productsProvider);
                ref.invalidate(shopNamesProvider);

                shopNameController.clear();
              },
              icon: Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              shopNamesAsync.when(
                data: (shopList) {
                  return ShopDropdown(
                    // shopList: shopList,
                    onSelected: (shop) {
                      setState(() {
                        selectedShop = shop;
                        shopNameController.text = shop.name;
                      });
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error loading shops: $e'),
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
                    onPressed: () {
                      _previewBillDialog(); // only proceed if form is valid
                    },

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
                              visualDensity: VisualDensity(vertical: -3),
                              title: Text('${item.name}  x  ${item.quantity}'),
                              subtitle: Text(
                                '₹${item.price.toStringAsFixed(2)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.orangeAccent,
                                    ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            "Products : ${bill.items.length.toString()}",
                            style: TextStyle(fontSize: 20),
                          ),
                          Text(
                            'Total : ₹ ${bill.total.toStringAsFixed(2)}',
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
      ),
    );
  }
}
