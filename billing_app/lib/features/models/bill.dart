import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  final String product;
  final int qty;
  final double price;

  BillItem({required this.product, required this.qty, required this.price});

  Map<String, dynamic> toMap() => {
    'product': product,
    'qty': qty,
    'price': price,
  };
}

class Bill {
  final String id;
  final String billNo;
  final String customerMobile;
  final List<BillItem> items;
  final double totalAmount;
  final DateTime date;

  Bill({
    required this.id,
    required this.billNo,
    required this.customerMobile,
    required this.items,
    required this.totalAmount,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'bill_no': billNo,
    'customer_mobile': customerMobile,
    'items': items.map((e) => e.toMap()).toList(),
    'total_amount': totalAmount,
    'date': date.toIso8601String(),
    'created_at': DateTime.now().toIso8601String(),
  };

  factory Bill.fromMap(Map<String, dynamic> data, String id) {
    final itemsData = data['items'] as List<dynamic>;

    final items =
        itemsData
            .map(
              (e) => BillItem(
                product: e['product'],
                qty: e['qty'],
                price: (e['price'] as num).toDouble(),
              ),
            )
            .toList();

    // 👇 Handle both Timestamp and String
    final dynamic rawDate = data['date'];
    final DateTime parsedDate =
        rawDate is Timestamp
            ? rawDate.toDate()
            : DateTime.parse(rawDate.toString());

    return Bill(
      id: id,
      billNo: data['bill_no'],
      customerMobile: data['customer_mobile'],
      items: items,
      totalAmount: (data['total_amount'] as num).toDouble(),
      date: parsedDate,
    );
  }
}
