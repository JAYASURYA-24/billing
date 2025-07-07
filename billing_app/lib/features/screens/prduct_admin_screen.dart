import 'package:billing/features/models/product.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/product_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  String _searchQuery = '';

  void _showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
  }) {
    final _nameController = TextEditingController(text: product?.name ?? '');
    final _priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    final isEdit = product != null;

    showDialog(
      barrierDismissible: false,
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(isEdit ? 'Edit Product' : 'Add Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Product Name'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                child: Text(isEdit ? 'Update' : 'Add'),
                onPressed: () {
                  final name = _nameController.text.trim();
                  final price =
                      double.tryParse(_priceController.text.trim()) ?? 0;

                  if (name.isEmpty || price <= 0) return;

                  final newProduct = Product(
                    id: product?.id ?? '',
                    name: name,
                    price: price,
                  );

                  if (isEdit) {
                    ref
                        .read(productProvider.notifier)
                        .updateProduct(newProduct);
                  } else {
                    ref.read(productProvider.notifier).addProduct(newProduct);
                  }

                  Navigator.pop(context);
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
            title: const Text('Confirm Delete'),
            content: Text('Are you sure you want to delete "${product.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 228, 137, 130),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (shouldDelete == true) {
      ref.read(productProvider.notifier).deleteProduct(product.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${product.name}" deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productProvider);

    final filteredProducts =
        products
            .where(
              (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();

    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFE3F2FD),
        appBar: AppBar(
          title: const Text(
            'Admin-Products',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color.fromARGB(255, 2, 113, 192),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showProductDialog(context, ref),
          backgroundColor: const Color.fromARGB(255, 2, 113, 192),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Column(
          children: [
            // 🔍 Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search product by name...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

            // 📋 Product List
            Expanded(
              child:
                  filteredProducts.isEmpty
                      ? const Center(child: Text('No products found.'))
                      : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredProducts.length,
                        itemBuilder: (_, index) {
                          final product = filteredProducts[index];
                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text(product.name),
                              subtitle: Text(
                                '₹ ${product.price.toStringAsFixed(2)}',
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
      ),
    );
  }
}
