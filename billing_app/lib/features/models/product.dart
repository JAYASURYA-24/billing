class Product {
  final String id;
  final String name;

  Product({required this.id, required this.name});

  factory Product.fromMap(Map<String, dynamic> map, String docId) {
    return Product(id: docId, name: map['name'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {'name': name};
  }
}
