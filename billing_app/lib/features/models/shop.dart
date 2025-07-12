import 'package:cloud_firestore/cloud_firestore.dart';

class Shop {
  final String id;
  final String name;

  Shop({required this.id, required this.name});

  factory Shop.fromMap(Map<String, dynamic> data, String documentId) {
    return Shop(id: documentId, name: data['name'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {'name': name};
  }

  factory Shop.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Shop(id: doc.id, name: data['name'] ?? '');
  }
}
