import 'package:billing/features/services/firestore_services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';

final firestoreServiceProvider = Provider((ref) => FirestoreService());

final productsStreamProvider = StreamProvider<List<Product>>((ref) {
  final service = ref.read(firestoreServiceProvider);
  return service.getProductsStream();
});

final selectedProductProvider = StateProvider<Product?>((ref) => null);
