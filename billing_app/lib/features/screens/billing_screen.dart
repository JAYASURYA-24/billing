import 'dart:typed_data';

import 'package:billing/core/utils/loading.dart';
import 'package:billing/core/widgets/shopserach.dart';
import 'package:billing/features/models/bill.dart';
import 'package:billing/features/models/product.dart';
import 'package:billing/features/models/shop.dart';
import 'package:billing/features/providers/bill_provider.dart';
import 'package:billing/features/providers/shop_provider.dart';

import 'package:billing/features/services/pdfservices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signature/signature.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  final TextEditingController shopNameController = TextEditingController();
  Uint8List? customerSignBytes;
  Shop? selectedShop;
  final _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
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

  // global variable inside the widget

  void _showCustomerSignatureDialog(
    BuildContext context,
    void Function(void Function()) setState,
  ) {
    _controller.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFFE3F2FD),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                const Text("Customer Signature"),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
            content: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(10),
              ),
              width: 300,
              height: 200,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _controller.clear();
                },
                child: const Text("Clear"),
              ),
              TextButton(
                onPressed: () async {
                  if (_controller.isNotEmpty) {
                    final bytes = await _controller.toPngBytes();
                    if (bytes != null) {
                      setState(() {
                        customerSignBytes = bytes;
                      });
                    }
                  }
                  Navigator.pop(context);
                },
                child: const Text("Save"),
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

    bool tempPaid = false;
    bool previousBillsTallied = false;

    final paidAmountController = TextEditingController();
    final discountPercentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Initial discount values
    double discountAmount = 0.0;
    double discountedCurrentTotal = previewBill.currentPurchaseTotal;

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
              // Calculate current bill payment only
              final paidAmount =
                  double.tryParse(paidAmountController.text.trim()) ?? 0.0;
              final currentBillBalance = discountedCurrentTotal - paidAmount;

              // Payment status based on CURRENT BILL only
              tempPaid =
                  currentBillBalance <=
                  0.01; // Small tolerance for floating point

              // Total amount that will remain unpaid (previous + current bill balance)
              final totalUnpaidAfterPayment =
                  previewBill.previousUnpaid +
                  (currentBillBalance > 0 ? currentBillBalance : 0);

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
                          '\$ ${previewBill.previousUnpaid.toStringAsFixed(2)} previous pending',
                          style: const TextStyle(color: Colors.red),
                        ),
                      const Divider(),
                      // const Text(
                      //   'Current Purchase:',
                      //   style: TextStyle(fontWeight: FontWeight.bold),
                      // ),
                      // const SizedBox(height: 6),
                      // SizedBox(
                      //   height: 200,
                      //   child: ListView.builder(
                      //     itemCount: previewBill.items.length,
                      //     itemBuilder: (context, index) {
                      //       final item = previewBill.items[index];
                      //       return ListTile(
                      //         dense: true,
                      //         visualDensity: VisualDensity(vertical: -4),
                      //         title: Text('${item.name} x ${item.quantity}'),
                      //         trailing: Text(
                      //           '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                      //         ),
                      //       );
                      //     },
                      //   ),
                      // ),
                      // const Divider(),
                      const SizedBox(height: 10),

                      // Current Bill Breakdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Purchase : ',
                            style: TextStyle(
                              color: Color.fromARGB(255, 2, 113, 192),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$ ${previewBill.currentPurchaseTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 2, 113, 192),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Current Bill Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Discount Amount:"),
                                Text("\$ ${discountAmount.toStringAsFixed(2)}"),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Current Bill Total:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  "\$ ${discountedCurrentTotal.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            //   children: [
                            //     const Text("Paying:"),
                            //     Text(
                            //       "\$ ${paidAmount.toStringAsFixed(2)}",
                            //       style: const TextStyle(
                            //         fontWeight: FontWeight.bold,
                            //       ),
                            //     ),
                            //   ],
                            // ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Overall Summary
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Current Bill Balance:"),
                                Text(
                                  "\$ ${(currentBillBalance > 0 ? currentBillBalance : 0).toStringAsFixed(2)}",
                                  style: TextStyle(
                                    color:
                                        currentBillBalance > 0
                                            ? Colors.red
                                            : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Previous Unpaid:'),
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
                                  'Total Will Remain Unpaid:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '\$ ${totalUnpaidAfterPayment.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color:
                                        totalUnpaidAfterPayment > 0
                                            ? Colors.red
                                            : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 10),
                      // Discount section
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              controller: discountPercentController,
                              keyboardType: TextInputType.number,
                              cursorColor: Color.fromARGB(255, 2, 113, 192),
                              decoration: const InputDecoration(
                                prefix: Text("\$ "),
                                labelStyle: TextStyle(
                                  color: Color.fromARGB(255, 2, 113, 192),
                                ),
                                labelText: 'Discount Amount',
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  borderSide: BorderSide(
                                    color: Color.fromARGB(255, 2, 113, 192),
                                    width: 2,
                                  ),
                                ),
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                final percent =
                                    double.tryParse(value.trim()) ?? 0.0;
                                if (percent >= 0 &&
                                    percent <=
                                        previewBill.currentPurchaseTotal) {
                                  setState(() {
                                    discountAmount = percent;

                                    discountedCurrentTotal =
                                        previewBill.currentPurchaseTotal -
                                        discountAmount;
                                  });
                                  // Clear paid amount when discount changes
                                  paidAmountController.clear();
                                }
                              },
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  final percent = int.tryParse(value.trim());
                                  if (percent == null ||
                                      percent < 0 ||
                                      percent >
                                          previewBill.currentPurchaseTotal) {
                                    return 'Enter valid % (0-${previewBill.currentPurchaseTotal})';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              controller: paidAmountController,
                              keyboardType: TextInputType.number,
                              cursorColor: Color.fromARGB(255, 2, 113, 192),
                              decoration: InputDecoration(
                                prefix: Text("\$ "),
                                labelStyle: TextStyle(
                                  color: Color.fromARGB(255, 2, 113, 192),
                                ),
                                labelText:
                                    'Enter Current bill :\$ ${discountedCurrentTotal.toStringAsFixed(2)}',
                                // helperText:
                                //     'Max: \$${discountedCurrentTotal.toStringAsFixed(2)}',
                                // helperStyle: TextStyle(color: Colors.green),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                  borderSide: BorderSide(
                                    color: Color.fromARGB(255, 2, 113, 192),
                                    width: 2,
                                  ),
                                ),
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(20),
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                setState(
                                  () {},
                                ); // Trigger rebuild to update payment status
                              },
                              validator: (value) {
                                if (value == null || value.trim().isEmpty)
                                  return 'Paid amount is required';
                                final parsed = double.tryParse(value.trim());
                                if (parsed == null)
                                  return 'Enter a valid number';
                                if (parsed < 0)
                                  return 'Amount cannot be negative';
                                if (parsed > discountedCurrentTotal)
                                  return 'Cannot exceed current bill amount: \$${discountedCurrentTotal.toStringAsFixed(2)}';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Payment status display (read-only)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              tempPaid
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: tempPaid ? Colors.green : Colors.red,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              tempPaid ? Icons.check_circle : Icons.pending,
                              color: tempPaid ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Current Bill Status: ${tempPaid ? 'PAID' : 'UNPAID'}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: tempPaid ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Checkbox(
                          //   value: previousBillsTallied,
                          //   activeColor: Colors.blue,
                          //   onChanged: (val) {
                          //     if (val != null)
                          //       setState(() => previousBillsTallied = val);
                          //   },
                          // ),
                          // const Text('Previous bills are tallied'),
                          if (customerSignBytes != null)
                            Center(
                              child: Image.memory(
                                customerSignBytes!,
                                width: 150,
                                height: 80,
                              ),
                            ),
                          TextButton.icon(
                            icon: const Icon(Icons.edit),
                            label: Text(
                              customerSignBytes == null
                                  ? "Add Customer Sign"
                                  : "Edit Customer Sign",
                            ),
                            onPressed:
                                () => _showCustomerSignatureDialog(
                                  context,
                                  setState,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

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

                                    discountAmount: discountAmount,
                                    discountedTotal: discountedCurrentTotal,
                                  );

                              ref.read(selectedShopProvider.notifier).state =
                                  null;
                              await generateAndOpenPdf(
                                finalBill,
                                previousBillsTallied,
                                signBytes: customerSignBytes,
                              );
                              // Reset signature after PDF generation
                              _resetSignature();
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

  void _showProductSelectionDialog(AsyncValue<List<Product>> productAsync) {
    final Map<String, TextEditingController> quantityControllers = {};
    final Map<String, TextEditingController> priceControllers = {};
    final searchController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // final productAsync = ref.watch(productsProvider);
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
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              labelText: 'Qty',
                                              labelStyle: const TextStyle(
                                                color: Color.fromARGB(
                                                  255,
                                                  2,
                                                  113,
                                                  192,
                                                ),
                                              ),
                                              floatingLabelAlignment:
                                                  FloatingLabelAlignment.center,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 10,
                                                  ),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color.fromARGB(
                                                    255,
                                                    2,
                                                    113,
                                                    192,
                                                  ),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color.fromARGB(
                                                    255,
                                                    2,
                                                    113,
                                                    192,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
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
                                            textAlign: TextAlign.center,
                                            decoration: InputDecoration(
                                              labelText: '\$',
                                              labelStyle: const TextStyle(
                                                color: Color.fromARGB(
                                                  255,
                                                  2,
                                                  113,
                                                  192,
                                                ),
                                              ),
                                              floatingLabelAlignment:
                                                  FloatingLabelAlignment.center,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 10,
                                                  ),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color.fromARGB(
                                                    255,
                                                    2,
                                                    113,
                                                    192,
                                                  ),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
                                                  color: Color.fromARGB(
                                                    255,
                                                    2,
                                                    113,
                                                    192,
                                                  ),
                                                  width: 2,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                borderSide: const BorderSide(
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
  // void _showProductSelectionDialog(AsyncValue<List<Product>> productAsync) {
  //   final Map<String, TextEditingController> quantityControllers = {};
  //   final Map<String, TextEditingController> priceControllers = {};
  //   final searchController = TextEditingController();

  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (context) {
  //       return StatefulBuilder(
  //         builder: (context, setState) {
  //           // final productAsync = ref.watch(productsProvider);
  //           return Padding(
  //             padding: const EdgeInsets.all(8.0),
  //             child: Dialog(
  //               insetPadding: EdgeInsets.zero, // removes default margin
  //               child: Container(
  //                 decoration: BoxDecoration(
  //                   color: const Color(0xFFE3F2FD),
  //                   borderRadius: BorderRadius.circular(20),
  //                 ),
  //                 width: MediaQuery.of(context).size.width,
  //                 // full screen width
  //                 height: MediaQuery.of(context).size.height * 0.8,
  //                 padding: const EdgeInsets.all(16),

  //                 child: Column(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     const Text(
  //                       'Select Products & Qty & Price',
  //                       style: TextStyle(
  //                         fontSize: 20,
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                     const SizedBox(height: 12),
  //                     TextField(
  //                       cursorColor: const Color.fromARGB(255, 2, 113, 192),
  //                       controller: searchController,
  //                       onChanged: (_) => setState(() {}),
  //                       decoration: InputDecoration(
  //                         hintText: 'Search product by name...',
  //                         prefixIcon: const Icon(Icons.search),
  //                         filled: true,
  //                         focusedBorder: OutlineInputBorder(
  //                           borderRadius: BorderRadius.circular(20),
  //                           borderSide: const BorderSide(
  //                             color: Color.fromARGB(255, 2, 113, 192),
  //                             width: 2,
  //                           ),
  //                         ),
  //                         fillColor: Colors.white,
  //                         border: OutlineInputBorder(
  //                           borderRadius: BorderRadius.circular(20),
  //                         ),
  //                       ),
  //                     ),
  //                     const SizedBox(height: 12),
  //                     Expanded(
  //                       child: productAsync.when(
  //                         data: (products) {
  //                           // Setup controllers
  //                           for (var product in products) {
  //                             quantityControllers.putIfAbsent(
  //                               product.id,
  //                               () => TextEditingController(),
  //                             );
  //                             priceControllers.putIfAbsent(
  //                               product.id,
  //                               () => TextEditingController(),
  //                             );
  //                           }

  //                           final filteredProducts =
  //                               products
  //                                   .where(
  //                                     (p) => p.name.toLowerCase().contains(
  //                                       searchController.text.toLowerCase(),
  //                                     ),
  //                                   )
  //                                   .toList();

  //                           if (filteredProducts.isEmpty) {
  //                             return const Center(
  //                               child: Text('No products found'),
  //                             );
  //                           }

  //                           return ListView.separated(
  //                             itemCount: filteredProducts.length,
  //                             separatorBuilder:
  //                                 (_, __) => const Divider(height: 1),
  //                             itemBuilder: (context, index) {
  //                               final product = filteredProducts[index];
  //                               final qtyController =
  //                                   quantityControllers[product.id]!;
  //                               final priceController =
  //                                   priceControllers[product.id]!;

  //                               return ListTile(
  //                                 title: Text(product.name),
  //                                 trailing: SizedBox(
  //                                   width: 200,
  //                                   child: Row(
  //                                     children: [
  //                                       Expanded(
  //                                         child: TextField(
  //                                           cursorColor: const Color.fromARGB(
  //                                             255,
  //                                             2,
  //                                             113,
  //                                             192,
  //                                           ),
  //                                           controller: qtyController,
  //                                           keyboardType: TextInputType.number,
  //                                           decoration: const InputDecoration(
  //                                             suffix: Text('Qty'),
  //                                             contentPadding:
  //                                                 EdgeInsets.symmetric(
  //                                                   horizontal: 8,
  //                                                   vertical: 10,
  //                                                 ),
  //                                             focusedBorder:
  //                                                 UnderlineInputBorder(
  //                                                   borderSide: BorderSide(
  //                                                     color: Color.fromARGB(
  //                                                       255,
  //                                                       2,
  //                                                       113,
  //                                                       192,
  //                                                     ),
  //                                                   ),
  //                                                 ),
  //                                           ),
  //                                         ),
  //                                       ),
  //                                       const SizedBox(width: 8),
  //                                       Expanded(
  //                                         child: TextField(
  //                                           cursorColor: const Color.fromARGB(
  //                                             255,
  //                                             2,
  //                                             113,
  //                                             192,
  //                                           ),
  //                                           controller: priceController,
  //                                           keyboardType: TextInputType.number,
  //                                           decoration: const InputDecoration(
  //                                             suffix: Text('\$'),
  //                                             contentPadding:
  //                                                 EdgeInsets.symmetric(
  //                                                   horizontal: 8,
  //                                                   vertical: 10,
  //                                                 ),
  //                                             focusedBorder:
  //                                                 UnderlineInputBorder(
  //                                                   borderSide: BorderSide(
  //                                                     color: Color.fromARGB(
  //                                                       255,
  //                                                       2,
  //                                                       113,
  //                                                       192,
  //                                                     ),
  //                                                   ),
  //                                                 ),
  //                                           ),
  //                                         ),
  //                                       ),
  //                                     ],
  //                                   ),
  //                                 ),
  //                               );
  //                             },
  //                           );
  //                         },
  //                         loading:
  //                             () => const Center(
  //                               child: CircularProgressIndicator(
  //                                 color: Color.fromARGB(255, 2, 113, 192),
  //                               ),
  //                             ),
  //                         error:
  //                             (_, __) => const Center(
  //                               child: Text('Failed to load products'),
  //                             ),
  //                       ),
  //                     ),
  //                     const SizedBox(height: 12),
  //                     Row(
  //                       mainAxisAlignment: MainAxisAlignment.end,
  //                       children: [
  //                         TextButton(
  //                           onPressed: () => Navigator.pop(context),
  //                           child: const Text(
  //                             'Cancel',
  //                             style: TextStyle(color: Colors.red),
  //                           ),
  //                         ),
  //                         const SizedBox(width: 12),
  //                         ElevatedButton(
  //                           style: const ButtonStyle(
  //                             backgroundColor: WidgetStatePropertyAll(
  //                               Colors.white,
  //                             ),
  //                           ),
  //                           onPressed: () {
  //                             final products =
  //                                 ref.read(productsProvider).asData?.value ??
  //                                 [];
  //                             for (var product in products) {
  //                               final qtyStr =
  //                                   quantityControllers[product.id]?.text
  //                                       .trim() ??
  //                                   '0';
  //                               final prcStr =
  //                                   priceControllers[product.id]?.text.trim() ??
  //                                   '0';
  //                               final qty = int.tryParse(qtyStr) ?? 0;
  //                               final prc = double.tryParse(prcStr) ?? 0;
  //                               if (qty > 0) {
  //                                 ref
  //                                     .read(billingProvider.notifier)
  //                                     .addItem(product, qty, prc);
  //                               }
  //                             }
  //                             Navigator.pop(context);
  //                           },
  //                           child: const Text(
  //                             'Done',
  //                             style: TextStyle(
  //                               color: Color.fromARGB(255, 0, 161, 5),
  //                             ),
  //                           ),
  //                         ),
  //                       ],
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  void _resetSignature() {
    setState(() {
      customerSignBytes = null;
    });
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final bill = ref.watch(billingProvider);
    final productsAsync = ref.watch(productsProvider);

    final shopNamesAsync = ref.watch(shopNamesProvider);
    final totalAmount = bill.items.fold<double>(
      0,
      (sum, item) => sum + (item.price * item.quantity),
    );

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
                showLoadingDialog(context);

                ref.invalidate(billingProvider);
                ref.invalidate(productsProvider);
                ref.invalidate(shopNamesProvider);
                ref.invalidate(selectedShopProvider);

                shopNameController.clear();

                Future.delayed(const Duration(seconds: 1), () {
                  Navigator.of(context, rootNavigator: true).pop();
                });
              },

              icon: Icon(Icons.refresh, color: Colors.white),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              shopNamesAsync.when(
                data: (shopList) {
                  return ShopDropdown(
                    controller: shopNameController,

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
                    onPressed: () {
                      if (shopNameController.text.trim().isNotEmpty) {
                        _showProductSelectionDialog(productsAsync);
                      } else {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select a shop"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },

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
                      if (shopNameController.text.trim().isNotEmpty) {
                        _previewBillBottomSheet();
                      } else {
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select a shop"),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
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
                              contentPadding: EdgeInsets.all(0),
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
                                      //   ref
                                      //       .read(billingProvider.notifier)
                                      //       .removeItem(item);
                                      // },
                                      _showDeleteDialog(context, item);
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
                            'Total : \$ ${totalAmount.toStringAsFixed(2)}',
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

  void _showDeleteDialog(BuildContext context, item) {
    showDialog(
      context: context,
      barrierDismissible: false, // user must tap button to close
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFFE3F2FD),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Remove Products'),
              GestureDetector(
                onTap: () {
                  Navigator.of(ctx).pop();
                },
                child: const Icon(Icons.close, color: Colors.red),
              ),
            ],
          ),
          content: const Text("Are you sure want to remove this product..?"),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(billingProvider.notifier).removeItem(item);
                Navigator.of(context).pop();
              },
              child: const Text(
                "Yes, Remove",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(
                color: Color.fromARGB(255, 2, 113, 192),
              ),
              SizedBox(width: 16),
              Text("Refreshing...", style: TextStyle(fontSize: 16)),
            ],
          ),
        );
      },
    );
  }
}
