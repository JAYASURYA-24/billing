import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop.dart';
import '../services/firestore_services.dart';

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

final shopProvider = Provider<List<Shop>>((ref) {
  return ref.watch(shopNamesProvider).value ?? [];
});
