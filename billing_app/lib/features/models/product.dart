class Product {
  final String id;
  final String name;
  final int quantity;

  Product({required this.id, required this.name, this.quantity = 0});

  factory Product.fromMap(Map<String, dynamic> map, String docId) {
    return Product(
      id: docId,
      name: map['name'] ?? '',
      quantity: map['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'quantity': quantity};
  }

  Product copyWith({String? id, String? name, double? price, int? quantity}) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
    );
  }
}
