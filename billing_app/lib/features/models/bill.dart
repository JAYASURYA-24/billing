import 'package:cloud_firestore/cloud_firestore.dart';

class BillItem {
  final String productId;
  final String name;
  final double price;
  final int quantity;

  BillItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });
  BillItem copyWith({
    String? productId,
    String? name,
    double? price,
    int? quantity,
  }) {
    return BillItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
    );
  }

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  factory BillItem.fromMap(Map<String, dynamic> map) {
    return BillItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] ?? 0,
    );
  }
}

class Bill {
  final String id;
  final String billNumber;
  final String shopName;
  final List<BillItem> items;
  final bool isPaid;
  final Timestamp createdAt;

  final double currentPurchaseTotal;
  final double previousUnpaid;
  final double paidAmount;
  final double balance;

  final double discountAmount;
  final double discountedTotal;

  Bill({
    required this.id,
    required this.billNumber,
    required this.shopName,
    required this.items,
    required this.isPaid,
    required this.createdAt,

    required this.currentPurchaseTotal,
    required this.previousUnpaid,
    required this.paidAmount,
    this.balance = 0.0,
    this.discountAmount = 0.0,

    this.discountedTotal = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'billNumber': billNumber,
      'shopName': shopName,
      'isPaid': isPaid,
      'createdAt': createdAt,

      'currentPurchaseTotal': currentPurchaseTotal,
      'previousUnpaid': previousUnpaid,
      'paidAmount': paidAmount,
      'balance': balance,
      'discountAmount': discountAmount,

      'discountedTotal': discountedTotal,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  factory Bill.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Bill.fromMap(map, doc.id);
  }

  factory Bill.fromMap(Map<String, dynamic> map, [String id = '']) {
    return Bill(
      id: id,
      billNumber: map['billNumber'] ?? '',
      shopName: map['shopName'] ?? '',
      isPaid: map['isPaid'] is bool ? map['isPaid'] : false,
      createdAt: map['createdAt'] ?? Timestamp.now(),

      currentPurchaseTotal:
          (map['currentPurchaseTotal'] as num?)?.toDouble() ?? 0.0,
      previousUnpaid: (map['previousUnpaid'] as num?)?.toDouble() ?? 0.0,
      items:
          (map['items'] as List<dynamic>)
              .map((e) => BillItem.fromMap(Map<String, dynamic>.from(e)))
              .toList(),
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0.0,

      discountedTotal: (map['discountedTotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// ✅ Copy method for immutability
  Bill copyWith({
    String? id,
    String? billNumber,
    String? shopName,
    List<BillItem>? items,
    bool? isPaid,
    Timestamp? createdAt,
    double? total,
    double? currentPurchaseTotal,
    double? previousUnpaid,
    double? paidAmount,
    double? balance,

    double? discountAmount,
    double? discountedTotal,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      shopName: shopName ?? this.shopName,
      items: items ?? this.items,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,

      currentPurchaseTotal: currentPurchaseTotal ?? this.currentPurchaseTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      previousUnpaid: previousUnpaid ?? this.previousUnpaid,
      balance: balance ?? this.balance,

      discountAmount: discountAmount ?? this.discountAmount,
      discountedTotal: discountedTotal ?? this.discountedTotal,
    );
  }
}
