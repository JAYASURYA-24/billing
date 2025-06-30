import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController billNoController = TextEditingController();

  DateTime? startDate;
  DateTime? endDate;

  void showProductDialog(
    BuildContext context,
    WidgetRef ref, {
    Product? product,
  }) {
    if (product != null) {
      nameController.text = product.name;
      priceController.text = product.price.toString();
    } else {
      nameController.clear();
      priceController.clear();
    }

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(product == null ? 'Add Product' : 'Edit Product'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Product Name'),
                ),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                child: Text('Save'),
                onPressed: () async {
                  final name = nameController.text;
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  if (product == null) {
                    await ref
                        .read(firestoreServiceProvider)
                        .addProduct(Product(id: '', name: name, price: price));
                  } else {
                    await ref
                        .read(firestoreServiceProvider)
                        .updateProduct(
                          Product(id: product.id, name: name, price: price),
                        );
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(firestoreServiceProvider);
    final products = ref.watch(productsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: Text('Admin Panel')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: searchController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Enter Mobile Number'),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => startDate = date);
                        },
                        child: Text(
                          startDate == null
                              ? 'Start Date'
                              : DateFormat.yMMMd().format(startDate!),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => endDate = date);
                        },
                        child: Text(
                          endDate == null
                              ? 'End Date'
                              : DateFormat.yMMMd().format(endDate!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Text("OR")],
                ),
              ),
              TextField(
                controller: billNoController,
                decoration: InputDecoration(labelText: 'Enter Bill Number'),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      child: Text('Search Customer Bills'),
                      onPressed: () async {
                        final mobile = searchController.text.trim();
                        final billNo = billNoController.text.trim();

                        final bills = await service.getBills(
                          mobile: mobile.isEmpty ? null : mobile,
                          billNo: billNo.isEmpty ? null : billNo,
                          start: startDate,
                          end: endDate,
                        );

                        if (bills.isEmpty) {
                          showDialog(
                            context: context,
                            builder:
                                (_) => AlertDialog(
                                  title: Text('No Results'),
                                  content: Text(
                                    'No bills found for your query.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('OK'),
                                    ),
                                  ],
                                ),
                          );
                          return;
                        }

                        showDialog(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: Text('Bills Found'),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: bills.length,
                                    itemBuilder: (context, index) {
                                      final bill = bills[index];
                                      return ExpansionTile(
                                        title: Text('Bill No: ${bill.billNo}'),
                                        subtitle: Text(
                                          'Mobile: ${bill.customerMobile}\nDate: ${DateFormat.yMMMd().format(bill.date)}\nTotal: ₹${bill.totalAmount.toStringAsFixed(2)}',
                                        ),
                                        children: [
                                          Divider(),
                                          ...bill.items.map(
                                            (item) => ListTile(
                                              title: Text(item.product),
                                              subtitle: Text(
                                                'Qty: ${item.qty}',
                                              ),
                                              trailing: Text(
                                                '₹${item.price.toStringAsFixed(2)}',
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Close'),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              Divider(),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Available Product List',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              products.when(
                data:
                    (items) => ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder:
                          (_, index) => ListTile(
                            title: Text(items[index].name),
                            subtitle: Text(
                              '₹${items[index].price.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit),
                                  onPressed:
                                      () => showProductDialog(
                                        context,
                                        ref,
                                        product: items[index],
                                      ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed:
                                      () => ref
                                          .read(firestoreServiceProvider)
                                          .deleteProduct(items[index].id),
                                ),
                              ],
                            ),
                          ),
                    ),
                loading: () => Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => showProductDialog(context, ref),
      ),
    );
  }
}
