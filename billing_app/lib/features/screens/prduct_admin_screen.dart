import 'package:billing/features/models/product.dart';
import 'package:billing/features/models/shop.dart';
import 'package:billing/features/models/bill.dart';
import 'package:billing/features/services/firestore_services.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:intl/intl.dart';

import '../providers/product_provider.dart';
import '../providers/shop_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _searchQuery = '';

  Future<void> _generateProductPdf(WidgetRef ref, List<Product> products) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final now = DateTime.now();
      final billsData = await firestoreService.fetchBillsByDate(now);
      final createdBills = billsData['created'] ?? [];
      
      final Map<String, int> dailySoldQty = {};
      for (final bill in createdBills) {
        for (final item in bill.items) {
          dailySoldQty[item.productId] = (dailySoldQty[item.productId] ?? 0) + item.quantity;
        }
      }

      int totalSold = 0;
      int totalRemaining = 0;
      final List<List<String>> tableData = products.map((p) {
        final sold = dailySoldQty[p.id] ?? 0;
        totalSold += sold;
        totalRemaining += p.quantity;
        return [p.name, sold.toString(), p.quantity.toString()];
      }).toList();
      tableData.add(['TOTAL', totalSold.toString(), totalRemaining.toString()]);

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Product Stock Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text(DateFormat('dd MMM yyyy').format(now), style: const pw.TextStyle(fontSize: 16)),
                  ]
                ),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Product Name', 'Daily Sold Quantity', 'Remaining Quantity'],
                data: tableData,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 12),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Product_Stock_Report_${DateFormat('ddMMyyyy').format(now)}.pdf');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    }
  }

  // void _showProductDialog(
  //   BuildContext context,
  //   WidgetRef ref, {
  //   Product? product,
  // }) {
  //   final _nameController = TextEditingController(text: product?.name ?? '');

  //   final isEdit = product != null;

  //   showDialog(
  //     barrierDismissible: false,
  //     context: context,
  //     builder:
  //         (_) => AlertDialog(
  //           backgroundColor: const Color(0xFFE3F2FD),
  //           title: Text(isEdit ? 'Edit Product' : 'Add Product'),
  //           content: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               TextFormField(
  //                 controller: _nameController,
  //                 cursorColor: const Color.fromARGB(255, 2, 113, 192),
  //                 decoration: const InputDecoration(
  //                   labelText: 'Product Name',
  //                   labelStyle: TextStyle(color: Colors.black),
  //                   focusedBorder: UnderlineInputBorder(
  //                     borderSide: BorderSide(
  //                       color: Color.fromARGB(255, 2, 113, 192),
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text(
  //                 'Cancel',
  //                 style: TextStyle(color: Colors.red),
  //               ),
  //             ),
  //             ElevatedButton(
  //               style: ButtonStyle(
  //                 backgroundColor: WidgetStatePropertyAll(Colors.white),
  //               ),
  //               child: Text(
  //                 isEdit ? 'Update' : 'Add',
  //                 style: const TextStyle(color: Color.fromARGB(255, 0, 161, 5)),
  //               ),
  //               onPressed: () {
  //                 final name = _nameController.text.trim();

  //                 if (name.isEmpty) return;

  //                 final newProduct = Product(id: product?.id ?? '', name: name);

  //                 if (isEdit) {
  //                   ref
  //                       .read(productProvider.notifier)
  //                       .updateProduct(newProduct);
  //                 } else {
  //                   ref.read(productProvider.notifier).addProduct(newProduct);
  //                 }

  //                 Navigator.pop(context);
  //               },
  //             ),
  //           ],
  //         ),
  //   );
  // }

  // void _showProductDialog(
  //   BuildContext context,
  //   WidgetRef ref, {
  //   Product? product,
  // }) {
  //   final _nameController = TextEditingController(text: product?.name ?? '');

  //   final _quantityController = TextEditingController();

  //   final isEdit = product != null;

  //   showDialog(
  //     barrierDismissible: false,
  //     context: context,
  //     builder:
  //         (_) => AlertDialog(
  //           backgroundColor: const Color(0xFFE3F2FD),
  //           title: Text(isEdit ? 'Edit Product' : 'Add Product'),
  //           content: SingleChildScrollView(
  //             child: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               children: [
  //                 TextFormField(
  //                   controller: _nameController,
  //                   cursorColor: const Color.fromARGB(255, 2, 113, 192),
  //                   decoration: const InputDecoration(
  //                     labelText: 'Product Name',
  //                     labelStyle: TextStyle(color: Colors.black),
  //                     focusedBorder: UnderlineInputBorder(
  //                       borderSide: BorderSide(
  //                         color: Color.fromARGB(255, 2, 113, 192),
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(height: 10),

  //                 const SizedBox(height: 10),
  //                 TextFormField(
  //                   controller: _quantityController,
  //                   keyboardType: TextInputType.number,
  //                   cursorColor: const Color.fromARGB(255, 2, 113, 192),
  //                   decoration: const InputDecoration(
  //                     labelText: 'Quantity',
  //                     labelStyle: TextStyle(color: Colors.black),
  //                     focusedBorder: UnderlineInputBorder(
  //                       borderSide: BorderSide(
  //                         color: Color.fromARGB(255, 2, 113, 192),
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //           actions: [
  //             TextButton(
  //               onPressed: () => Navigator.pop(context),
  //               child: const Text(
  //                 'Cancel',
  //                 style: TextStyle(color: Colors.red),
  //               ),
  //             ),
  //             ElevatedButton(
  //               style: const ButtonStyle(
  //                 backgroundColor: WidgetStatePropertyAll(Colors.white),
  //               ),
  //               child: Text(
  //                 isEdit ? 'Update' : 'Add',
  //                 style: const TextStyle(color: Color.fromARGB(255, 0, 161, 5)),
  //               ),
  //               onPressed: () async {
  //                 final name = _nameController.text.trim();

  //                 final quantity =
  //                     int.tryParse(_quantityController.text.trim()) ?? 0;

  //                 if (name.isEmpty) return;

  //                 final firestoreService = ref.read(firestoreServiceProvider);

  //                 if (isEdit) {
  //                   // ✅ Instead of replacing, add to existing quantity
  //                   await firestoreService.increaseProductQuantity(
  //                     product!.id,
  //                     quantity,
  //                   );
  //                 } else {
  //                   // Add a new product (first time)
  //                   final newProduct = Product(
  //                     id: product?.id ?? '',
  //                     name: name,

  //                     quantity: quantity,
  //                   );
  //                   ref.read(productProvider.notifier).addProduct(newProduct);
  //                 }

  //                 Navigator.pop(context);
  //               },
  //             ),
  //           ],
  //         ),
  //   );
  // }

  void _showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
  }) {
    final _nameController = TextEditingController(text: product?.name ?? '');
    final _quantityController = TextEditingController();

    final isEdit = product != null;
    String actionType = 'add'; // default mode → add quantity

    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  backgroundColor: const Color(0xFFE3F2FD),
                  title: Text(isEdit ? 'Edit Product' : 'Add Product'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          cursorColor: const Color.fromARGB(255, 2, 113, 192),
                          decoration: const InputDecoration(
                            labelText: 'Product Name',
                            labelStyle: TextStyle(color: Colors.black),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Color.fromARGB(255, 2, 113, 192),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),

                        // ✅ Add/Subtract Selector
                        if (isEdit) ...[
                          const Text(
                            "Select Action",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ChoiceChip(
                                label: const Text('+ qty'),
                                selected: actionType == 'add',
                                selectedColor: Colors.green[100],
                                onSelected:
                                    (_) => setState(() => actionType = 'add'),
                              ),
                              const SizedBox(width: 10),
                              ChoiceChip(
                                label: const Text('- qty'),
                                selected: actionType == 'reduce',
                                selectedColor: Colors.red[100],
                                onSelected:
                                    (_) =>
                                        setState(() => actionType = 'reduce'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            cursorColor: const Color.fromARGB(255, 2, 113, 192),
                            decoration: const InputDecoration(
                              labelText: 'Enter Quantity',
                              labelStyle: TextStyle(color: Colors.black),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color.fromARGB(255, 2, 113, 192),
                                ),
                              ),
                            ),
                          ),
                        ],
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
                      style: const ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(Colors.white),
                      ),
                      child: Text(
                        isEdit ? 'Update' : 'Add',
                        style: const TextStyle(
                          color: Color.fromARGB(255, 0, 161, 5),
                        ),
                      ),
                      onPressed: () async {
                        final name = _nameController.text.trim();
                        final quantity =
                            int.tryParse(_quantityController.text.trim()) ?? 0;
                        if (name.isEmpty) return;

                        final firestoreService = ref.read(
                          firestoreServiceProvider,
                        );

                        if (isEdit) {
                          final changeBy =
                              actionType == 'reduce' ? -quantity : quantity;
                          if (changeBy == 0 ||
                              changeBy > product.quantity &&
                                  actionType == 'reduce') {
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter correct quantity"),
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }

                          await firestoreService.updateProductQuantity(
                            product!.id,
                            changeBy,
                          );
                        } else {
                          // 🆕 Add new product
                          final newProduct = Product(
                            id: product?.id ?? '',
                            name: name,
                          );
                          ref
                              .read(productProvider.notifier)
                              .addProduct(newProduct);
                        }

                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
          ),
    );
  }

  void _showShopDialog(
    BuildContext context, {
    String? shopId,
    String? shopName,
  }) {
    final _shopNameController = TextEditingController(text: shopName ?? '');
    final isEdit = shopId != null;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFFE3F2FD),
            title: Text(isEdit ? 'Edit Shop' : 'Add Shop'),
            content: TextFormField(
              controller: _shopNameController,
              cursorColor: const Color.fromARGB(255, 2, 113, 192),
              decoration: const InputDecoration(
                labelText: 'Shop Name',
                labelStyle: TextStyle(color: Colors.black),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: Color.fromARGB(255, 2, 113, 192),
                  ),
                ),
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
              Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      isEdit ? 'Update' : 'Add',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 0, 161, 5),
                      ),
                    ),
                    onPressed: () {
                      final newShopName = _shopNameController.text.trim();
                      if (newShopName.isEmpty) return;

                      final newShop = Shop(id: shopId ?? '', name: newShopName);

                      if (isEdit) {
                        ref.read(shopProvider.notifier).updateShop(newShop);
                      } else {
                        ref.read(shopProvider.notifier).addShop(newShop);
                      }

                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ],
          ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    final shouldDelete = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFFE3F2FD),
            title: const Text('Confirm Delete'),
            content: Text('Are you sure you want to delete "${product.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      ref.read(productProvider.notifier).deleteProduct(product.id);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${product.name}" deleted')));
    }
  }

  Future<void> _confirmDeleteShop(
    BuildContext context,
    WidgetRef ref,
    Shop shop,
  ) async {
    final shouldDelete = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFFE3F2FD),
            title: const Text('Confirm Delete'),
            content: Text('Delete shop "${shop.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      await ref.read(shopProvider.notifier).deleteShop(shop.id);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Shop "${shop.name}" deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider);
    final shops = ref.watch(shopProvider);

    final filteredProducts =
        products
            .where(
              (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    final filteredShops =
        shops
            .where(
              (s) => s.name.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            backgroundColor: const Color(0xFFE3F2FD),
            appBar: AppBar(
              title: const Text(
                'Admin Panel',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color.fromARGB(255, 2, 113, 192),
              bottom: const TabBar(
                indicatorColor: Colors.orangeAccent,
                labelColor: Colors.orangeAccent,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(icon: Icon(Icons.inventory), text: 'Products'),
                  Tab(icon: Icon(Icons.store), text: 'Shops'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // Tab 1: Products
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
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
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: const BoxDecoration(
                              color: Color.fromARGB(255, 2, 113, 192),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.picture_as_pdf),
                              color: Colors.white,
                              tooltip: 'Download PDF',
                              onPressed: () => _generateProductPdf(ref, filteredProducts),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Product'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                2,
                                113,
                                192,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showProductDialog(context, ref),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          filteredProducts.isEmpty
                              ? const Center(
                                child: Text('No products found...'),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                itemCount: filteredProducts.length,
                                itemBuilder: (_, index) {
                                  final product = filteredProducts[index];
                                  return Card(
                                    color: Colors.white,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: ListTile(
                                      title: Text(product.name),
                                      subtitle: Text(
                                        "Avail qty: ${product.quantity.toString()}",
                                      ),

                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.orangeAccent,
                                            ),
                                            onPressed:
                                                () => _showProductDialog(
                                                  context,
                                                  ref,
                                                  product: product,
                                                ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed:
                                                () => _confirmDelete(
                                                  context,
                                                  ref,
                                                  product,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),

                // Tab 2: Shops
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              cursorColor: Color.fromARGB(255, 2, 113, 192),
                              decoration: InputDecoration(
                                hintText: 'Search shop by name...',
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
                              onChanged: (value) {
                                setState(() => _searchQuery = value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Shop'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(
                                255,
                                2,
                                113,
                                192,
                              ),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => _showShopDialog(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          filteredShops.isEmpty
                              ? const Center(child: Text('No shops found.'))
                              : ListView.builder(
                                itemCount: filteredShops.length,
                                itemBuilder: (context, index) {
                                  final shop = filteredShops[index];
                                  return Card(
                                    color: Colors.white,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 12,
                                    ),
                                    child: ListTile(
                                      title: Text(shop.name),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              color: Colors.orangeAccent,
                                            ),
                                            onPressed:
                                                () => _showShopDialog(
                                                  context,
                                                  shopId: shop.id,
                                                  shopName: shop.name,
                                                ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              color: Colors.red,
                                            ),
                                            onPressed:
                                                () => _confirmDeleteShop(
                                                  context,
                                                  ref,
                                                  shop,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
