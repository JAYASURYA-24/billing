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

  void _previewBillBottomSheet() async {
    final shopName = shopNameController.text.trim();
    final (previewBill, _) = await showLoadingWhile(
      context,
      ref
          .read(billingProvider.notifier)
          .generateBill(shopName, false, isPreview: true),
    );

    bool tempPaid = true;
    final paidAmountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      backgroundColor: const Color(0xFFE3F2FD),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              paidAmountController.addListener(() {
                final paidAmount =
                    double.tryParse(paidAmountController.text.trim()) ?? 0.0;
                final isPaid = paidAmount >= previewBill.total;
                if (tempPaid != isPaid) {
                  setState(() {
                    tempPaid = isPaid;
                  });
                }
              });

              return SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Text(
                        'Shop: $shopName',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (previewBill.previousUnpaid == 0)
                        const Text(
                          'No previous pending bills...',
                          style: TextStyle(
                            color: Color.fromARGB(255, 0, 161, 5),
                          ),
                        )
                      else
                        Text(
                          '\$${previewBill.previousUnpaid.toStringAsFixed(2)} unpaid from last bill',
                          style: const TextStyle(color: Colors.red),
                        ),

                      const Divider(),
                      const Text(
                        'Current Purchase:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: previewBill.items.length,
                          itemBuilder: (context, index) {
                            final item = previewBill.items[index];
                            return ListTile(
                              dense: true,
                              visualDensity: VisualDensity(vertical: -4),
                              title: Text('${item.name} x ${item.quantity}'),
                              trailing: Text(
                                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Previous Unpaid : ',
                            style: TextStyle(color: Colors.red),
                          ),
                          Text(
                            '\$ ${previewBill.previousUnpaid.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Purchase : ',
                            style: TextStyle(
                              color: Color.fromARGB(255, 2, 113, 192),
                            ),
                          ),
                          Text(
                            '\$ ${previewBill.currentPurchaseTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 2, 113, 192),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grand Total : ',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            '\$ ${previewBill.total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: paidAmountController,
                        keyboardType: TextInputType.number,
                        cursorColor: Color.fromARGB(255, 2, 113, 192),
                        decoration: const InputDecoration(
                          labelText: 'Enter Paid Amount (required)',
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            borderSide: BorderSide(
                              color: Color.fromARGB(255, 2, 113, 192),
                              width: 2,
                            ),
                          ),
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Paid amount is required';
                          }

                          final parsed = double.tryParse(value.trim());
                          if (parsed == null) {
                            return 'Enter a valid number';
                          }

                          if (parsed > previewBill.total) {
                            return 'Paid amount cannot exceed grand total';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

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
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => tempPaid = val);
                                  },
                                ),
                                const Text('Paid'),
                                Radio<bool>(
                                  activeColor: Colors.red,
                                  value: false,
                                  groupValue: tempPaid,
                                  onChanged: (val) {
                                    if (val != null)
                                      setState(() => tempPaid = val);
                                  },
                                ),
                                const Text('Unpaid'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          ElevatedButton(
                            style: const ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                Colors.white,
                              ),
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;

                              Navigator.pop(context);
                              shopNameController.clear();

                              final paidAmount =
                                  double.tryParse(
                                    paidAmountController.text.trim(),
                                  ) ??
                                  0.0;
                              final (finalBill, _) = await ref
                                  .read(billingProvider.notifier)
                                  .generateBill(
                                    shopName,
                                    tempPaid,
                                    paidAmount: paidAmount,
                                  );
                              ref.read(selectedShopProvider.notifier).state =
                                  null;

                              await generateAndOpenPdf(finalBill);
                            },
                            child: const Text(
                              'Generate PDF',
                              style: TextStyle(
                                color: Color.fromARGB(255, 2, 113, 192),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showProductSelectionDialog() {
    final productAsync = ref.read(productsProvider);
    final Map<String, TextEditingController> quantityControllers = {};
    final Map<String, TextEditingController> priceControllers = {};
    final searchController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Dialog(
                insetPadding: EdgeInsets.zero, // removes default margin
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  width: MediaQuery.of(context).size.width,
                  // full screen width
                  height: MediaQuery.of(context).size.height * 0.8,
                  padding: const EdgeInsets.all(16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Products & Qty & Price',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        cursorColor: const Color.fromARGB(255, 2, 113, 192),
                        controller: searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search product by name...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 2, 113, 192),
                              width: 2,
                            ),
                          ),
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: productAsync.when(
                          data: (products) {
                            // Setup controllers
                            for (var product in products) {
                              quantityControllers.putIfAbsent(
                                product.id,
                                () => TextEditingController(),
                              );
                              priceControllers.putIfAbsent(
                                product.id,
                                () => TextEditingController(),
                              );
                            }

                            final filteredProducts =
                                products
                                    .where(
                                      (p) => p.name.toLowerCase().contains(
                                        searchController.text.toLowerCase(),
                                      ),
                                    )
                                    .toList();

                            if (filteredProducts.isEmpty) {
                              return const Center(
                                child: Text('No products found'),
                              );
                            }

                            return ListView.separated(
                              itemCount: filteredProducts.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                final qtyController =
                                    quantityControllers[product.id]!;
                                final priceController =
                                    priceControllers[product.id]!;

                                return ListTile(
                                  title: Text(product.name),
                                  trailing: SizedBox(
                                    width: 200,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            cursorColor: const Color.fromARGB(
                                              255,
                                              2,
                                              113,
                                              192,
                                            ),
                                            controller: qtyController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              suffix: Text('Qty'),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 10,
                                                  ),
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color.fromARGB(
                                                        255,
                                                        2,
                                                        113,
                                                        192,
                                                      ),
                                                    ),
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            cursorColor: const Color.fromARGB(
                                              255,
                                              2,
                                              113,
                                              192,
                                            ),
                                            controller: priceController,
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              suffix: Text('\$'),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 10,
                                                  ),
                                              focusedBorder:
                                                  UnderlineInputBorder(
                                                    borderSide: BorderSide(
                                                      color: Color.fromARGB(
                                                        255,
                                                        2,
                                                        113,
                                                        192,
                                                      ),
                                                    ),
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
                          loading:
                              () => const Center(
                                child: CircularProgressIndicator(
                                  color: Color.fromARGB(255, 2, 113, 192),
                                ),
                              ),
                          error:
                              (_, __) => const Center(
                                child: Text('Failed to load products'),
                              ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: const ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                Colors.white,
                              ),
                            ),
                            onPressed: () {
                              final products =
                                  ref.read(productsProvider).asData?.value ??
                                  [];
                              for (var product in products) {
                                final qtyStr =
                                    quantityControllers[product.id]?.text
                                        .trim() ??
                                    '0';
                                final prcStr =
                                    priceControllers[product.id]?.text.trim() ??
                                    '0';
                                final qty = int.tryParse(qtyStr) ?? 0;
                                final prc = double.tryParse(prcStr) ?? 0;
                                if (qty > 0) {
                                  ref
                                      .read(billingProvider.notifier)
                                      .addItem(product, qty, prc);
                                }
                              }
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Done',
                              style: TextStyle(
                                color: Color.fromARGB(255, 0, 161, 5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
                ref.invalidate(selectedShopProvider);

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
                    controller: shopNameController,
                    // shopList: shopList,
                    onSelected: (shop) {
                      setState(() {
                        selectedShop = shop;
                        shopNameController.text = shop.name;
                      });
                    },
                  );
                },
                loading:
                    () => const CircularProgressIndicator(
                      color: Color.fromARGB(255, 2, 113, 192),
                    ),
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
                      _previewBillBottomSheet();

                      // only proceed if form is valid
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
                                '\$${item.price.toStringAsFixed(2)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '\$${(item.price * item.quantity).toStringAsFixed(2)}',
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
                            'Total : \$ ${bill.total.toStringAsFixed(2)}',
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
