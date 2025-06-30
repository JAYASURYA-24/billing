class Product {
  final String id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});

  factory Product.fromMap(Map<String, dynamic> data, String documentId) {
    return Product(
      id: documentId,
      name: data['name'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'price': price};
  }
}
