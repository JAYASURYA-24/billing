class Product {
  final String id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});

  // ✅ Use this method for reading from Firestore
  factory Product.fromMap(Map<String, dynamic> map, String docId) {
    return Product(
      id: docId,
      name: map['name'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
    );
  }

  // ✅ Use this method for saving to Firestore
  Map<String, dynamic> toMap() {
    return {'name': name, 'price': price};
  }
}
