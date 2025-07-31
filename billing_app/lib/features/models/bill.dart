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
  final double total;
  final double currentPurchaseTotal;
  final double previousUnpaid;
  final double paidAmount;

  Bill({
    required this.id,
    required this.billNumber,
    required this.shopName,
    required this.items,
    required this.isPaid,
    required this.createdAt,
    required this.total,
    required this.currentPurchaseTotal,
    required this.previousUnpaid,
    required this.paidAmount,
  });

  /// ✅ Convert model to Firestore Map (excluding `id`)
  Map<String, dynamic> toMap() {
    return {
      'billNumber': billNumber,
      'shopName': shopName,
      'isPaid': isPaid,
      'createdAt': createdAt,
      'total': total,
      'currentPurchaseTotal': currentPurchaseTotal,
      'previousUnpaid': previousUnpaid,
      'paidAmount': paidAmount,

      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  /// ✅ Create a Bill from a Firestore document
  factory Bill.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return Bill.fromMap(map, doc.id);
  }

  /// ✅ Main fromMap with optional ID (recommended to always pass ID)
  factory Bill.fromMap(Map<String, dynamic> map, [String id = '']) {
    return Bill(
      id: id,
      billNumber: map['billNumber'] ?? '',
      shopName: map['shopName'] ?? '',
      isPaid: map['isPaid'] is bool ? map['isPaid'] : false,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      currentPurchaseTotal:
          (map['currentPurchaseTotal'] as num?)?.toDouble() ?? 0.0,
      previousUnpaid: (map['previousUnpaid'] as num?)?.toDouble() ?? 0.0,
      items:
          (map['items'] as List<dynamic>)
              .map((e) => BillItem.fromMap(Map<String, dynamic>.from(e)))
              .toList(),

      paidAmount: map['paidAmount'] ?? 0.0,
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
    double? remainingUnpaid,
  }) {
    return Bill(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      shopName: shopName ?? this.shopName,
      items: items ?? this.items,
      isPaid: isPaid ?? this.isPaid,
      createdAt: createdAt ?? this.createdAt,
      total: total ?? this.total,
      currentPurchaseTotal: currentPurchaseTotal ?? this.currentPurchaseTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      previousUnpaid: previousUnpaid ?? this.previousUnpaid,
    );
  }
}
