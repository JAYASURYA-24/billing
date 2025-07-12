import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop.dart';
import '../services/firestore_services.dart';

// ✅ This is your main shop list provider (with live updates)
final shopProvider = StateNotifierProvider<ShopNotifier, List<Shop>>((ref) {
  return ShopNotifier(ref.read(firestoreServiceProvider));
});

// ✅ Optional: For a one-time fetch (e.g. dropdown)
final shopNamesProvider = StreamProvider<List<Shop>>((ref) {
  return FirebaseFirestore.instance
      .collection('shops')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Shop.fromFirestore(doc)).toList(),
      );
});

final selectedShopProvider = StateProvider<Shop?>((ref) => null);

class ShopNotifier extends StateNotifier<List<Shop>> {
  final FirestoreService _service;
  ShopNotifier(this._service) : super([]) {
    _listenToShops();
  }

  void _listenToShops() {
    _service.shopsStream().listen((shops) {
      state = shops;
    });
  }

  Future<void> addShop(Shop shop) => _service.addShop(shop);
  Future<void> updateShop(Shop shop) => _service.updateShop(shop);
  Future<void> deleteShop(String id) => _service.deleteShop(id);
}
