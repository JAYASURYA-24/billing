import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../services/firestore_services.dart';

final productsProvider = StreamProvider<List<Product>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.productsStream();
});

final productProvider = Provider<List<Product>>((ref) {
  return ref.watch(productsProvider).value ?? [];
});
