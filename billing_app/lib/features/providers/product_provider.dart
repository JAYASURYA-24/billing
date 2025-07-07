import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/firestore_services.dart';

final productProvider = StateNotifierProvider<ProductNotifier, List<Product>>((
  ref,
) {
  return ProductNotifier(ref.read(firestoreServiceProvider));
});

class ProductNotifier extends StateNotifier<List<Product>> {
  final FirestoreService _service;
  ProductNotifier(this._service) : super([]) {
    _listenToProducts();
  }

  void _listenToProducts() {
    _service.productsStream().listen((products) {
      state = products;
    });
  }

  Future<void> addProduct(Product product) => _service.addProduct(product);
  Future<void> updateProduct(Product product) =>
      _service.updateProduct(product);
  Future<void> deleteProduct(String id) => _service.deleteProduct(id);
}
