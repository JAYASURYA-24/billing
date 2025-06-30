import 'package:billing/features/models/bill.dart';
import 'package:billing/features/providers/bill_provider.dart';
import 'package:billing/features/providers/product_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class BillingScreen extends ConsumerWidget {
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final billItems = ref.watch(billItemsProvider);
    final billItemsNotifier = ref.read(billItemsProvider.notifier);
    final total = billItemsNotifier.total;

    return Scaffold(
      appBar: AppBar(
        title: Text('Billing'),
        actions: [
          ElevatedButton.icon(
            icon: Icon(Icons.refresh),
            label: Text('New Bill'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              ref.read(billItemsProvider.notifier).clear();
              ref.read(customerMobileProvider.notifier).state = '';
              mobileController.clear();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Started new bill')));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Customer Mobile
            TextField(
              controller: mobileController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Customer Mobile',
                border: OutlineInputBorder(),
              ),
              onChanged:
                  (val) =>
                      ref.read(customerMobileProvider.notifier).state = val,
            ),
            SizedBox(height: 12),

            // Product List
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Product',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged:
                        (_) => ref.refresh(
                          productsStreamProvider,
                        ), // Optional if live filter
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: productsAsync.when(
                      data: (products) {
                        final query = searchController.text.toLowerCase();
                        final filteredProducts =
                            products
                                .where(
                                  (p) => p.name.toLowerCase().contains(query),
                                )
                                .toList();

                        return ListView.builder(
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return ListTile(
                              title: Text(product.name),
                              subtitle: Text(
                                '₹${product.price.toStringAsFixed(2)}',
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.add),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder:
                                        (_) => AlertDialog(
                                          title: Text('Add ${product.name}'),
                                          content: TextField(
                                            controller: quantityController,
                                            decoration: InputDecoration(
                                              labelText: 'Quantity',
                                            ),
                                            keyboardType: TextInputType.number,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () {
                                                quantityController.clear();
                                                Navigator.pop(context);
                                              },
                                              child: Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                final qty =
                                                    int.tryParse(
                                                      quantityController.text,
                                                    ) ??
                                                    1;
                                                billItemsNotifier.addItem(
                                                  BillItem(
                                                    product: product.name,
                                                    qty: qty,
                                                    price: product.price,
                                                  ),
                                                );
                                                quantityController.clear();
                                                Navigator.pop(context);
                                              },
                                              child: Text('Add'),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                      loading: () => Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            ),

            Divider(),

            // Bill Items Preview
            if (billItems.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Current Bill',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 8),
              Container(
                height: 150,
                child: ListView.builder(
                  itemCount: billItems.length,
                  itemBuilder: (context, index) {
                    final item = billItems[index];
                    return ListTile(
                      title: Text(item.product),
                      subtitle: Text('Qty: ${item.qty}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '₹${(item.qty * item.price).toStringAsFixed(2)}',
                          ),
                          IconButton(
                            icon: Icon(Icons.edit, size: 20),
                            onPressed: () {
                              quantityController.text = item.qty.toString();
                              showDialog(
                                context: context,
                                builder:
                                    (_) => AlertDialog(
                                      title: Text(
                                        'Edit Quantity for ${item.product}',
                                      ),
                                      content: TextField(
                                        controller: quantityController,
                                        decoration: InputDecoration(
                                          labelText: 'Quantity',
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            final qty =
                                                int.tryParse(
                                                  quantityController.text,
                                                ) ??
                                                item.qty;
                                            ref
                                                .read(
                                                  billItemsProvider.notifier,
                                                )
                                                .updateItemQty(index, qty);
                                            Navigator.pop(context);
                                            quantityController.clear();
                                          },
                                          child: Text('Update'),
                                        ),
                                      ],
                                    ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, size: 20),
                            onPressed:
                                () => billItemsNotifier.removeItem(
                                  billItems[index].product,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ₹${total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 8),
            ],

            // Generate PDF Button
            ElevatedButton.icon(
              icon: Icon(Icons.picture_as_pdf),
              label: Text('Generate Bill & PDF'),
              onPressed: () async {
                // Show preview first
                showDialog(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: Text('Preview Bill'),
                        content: SizedBox(
                          height: 300,
                          width: double.maxFinite,
                          child: ListView(
                            children: [
                              Text('Bill No: (To be generated)'),
                              Text('Customer: ${mobileController.text}'),
                              Divider(),
                              ...billItems.map(
                                (item) => Text(
                                  '${item.product} x${item.qty} = ₹${(item.qty * item.price).toStringAsFixed(2)}',
                                ),
                              ),
                              Divider(),
                              Text(
                                'Total: ₹${total.toStringAsFixed(2)}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          ElevatedButton(
                            child: Text('Confirm & Print'),
                            onPressed: () async {
                              Navigator.pop(context); // Close preview

                              final service = ref.read(
                                firestoreServiceProvider,
                              );
                              final billNo = await service.generateBillNumber();
                              final customerMobile = ref.read(
                                customerMobileProvider,
                              );
                              final bill = Bill(
                                id: '',
                                billNo: billNo,
                                customerMobile: customerMobile,
                                items: billItems,
                                totalAmount: total,
                                date: DateTime.now(),
                              );

                              await service.saveBill(bill);

                              final pdf = pw.Document();
                              pdf.addPage(
                                pw.Page(
                                  build:
                                      (pw.Context context) => pw.Column(
                                        crossAxisAlignment:
                                            pw.CrossAxisAlignment.start,
                                        children: [
                                          pw.Text(
                                            'Shop Invoice',
                                            style: pw.TextStyle(fontSize: 24),
                                          ),
                                          pw.SizedBox(height: 10),
                                          pw.Text('Bill No: ${bill.billNo}'),
                                          pw.Text(
                                            'Customer: ${bill.customerMobile}',
                                          ),
                                          pw.Text(
                                            'Date: ${bill.date.toString()}',
                                          ),
                                          pw.Divider(),
                                          ...bill.items.map(
                                            (item) => pw.Text(
                                              '${item.product} x${item.qty} - ₹${(item.qty * item.price).toStringAsFixed(2)}',
                                            ),
                                          ),
                                          pw.Divider(),
                                          pw.Text(
                                            'Total: ₹${bill.totalAmount.toStringAsFixed(2)}',
                                            style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                ),
                              );

                              await Printing.layoutPdf(
                                onLayout: (format) async => pdf.save(),
                              );

                              ref.read(billItemsProvider.notifier).clear();
                              mobileController.clear();

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Bill Saved & PDF Generated'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                );
              },
            ),

            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
