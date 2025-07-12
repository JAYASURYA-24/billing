import 'package:billing/features/models/product.dart';
import 'package:billing/features/models/shop.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/product_provider.dart';
import '../providers/shop_provider.dart';

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
            backgroundColor: const Color(0xFFE3F2FD),
            title: Text(isEdit ? 'Edit Product' : 'Add Product'),
            content: Column(
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
                const SizedBox(height: 10),
                TextFormField(
                  controller: _priceController,
                  cursorColor: const Color.fromARGB(255, 2, 113, 192),
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    labelStyle: TextStyle(color: Colors.black),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: Color.fromARGB(255, 2, 113, 192),
                      ),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
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
                child: Text(
                  isEdit ? 'Update' : 'Add',
                  style: const TextStyle(color: Color.fromARGB(255, 0, 161, 5)),
                ),
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

                // Tab 2: Shops
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search shop by name...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
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
