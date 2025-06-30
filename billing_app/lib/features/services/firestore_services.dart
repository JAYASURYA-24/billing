import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/bill.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ------------------ PRODUCTS ------------------

  Stream<List<Product>> getProductsStream() {
    return _firestore.collection('products').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addProduct(Product product) async {
    await _firestore.collection('products').add(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await _firestore
        .collection('products')
        .doc(product.id)
        .update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _firestore.collection('products').doc(id).delete();
  }

  // ------------------ BILLS ------------------

  Future<String> generateBillNumber() async {
    final snapshot =
        await _firestore
            .collection('bills')
            .orderBy('date', descending: true)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) return 'BILL0001';

    final lastBillNo = snapshot.docs.first['bill_no'] as String;
    final number = int.tryParse(lastBillNo.replaceAll(RegExp(r'\D'), '')) ?? 0;
    return 'BILL${(number + 1).toString().padLeft(4, '0')}';
  }

  Future<void> saveBill(Bill bill) async {
    final data = bill.toMap();

    // Ensure 'date' is stored as a Timestamp
    if (data['date'] is DateTime) {
      data['date'] = Timestamp.fromDate(data['date']);
    }

    await _firestore.collection('bills').add(data);
  }

  Stream<List<Bill>> getAllBillsStream() {
    return _firestore
        .collection('bills')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Bill.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  Future<List<Bill>> getBillsByMobileAndDate(
    String mobile,
    DateTime? start,
    DateTime? end,
  ) async {
    try {
      Query query = _firestore
          .collection('bills')
          .where('customer_mobile', isEqualTo: mobile);

      if (start != null) {
        query = query.where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        );
      }

      if (end != null) {
        query = query.where(
          'date',
          isLessThanOrEqualTo: Timestamp.fromDate(end),
        );
      }

      final snapshot = await query.orderBy('date', descending: true).get();

      return snapshot.docs
          .map(
            (doc) => Bill.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList();
    } catch (e) {
      print('Error fetching bills: $e');
      return [];
    }
  }

  Future<List<Bill>> getBills({
    String? mobile,
    String? billNo,
    DateTime? start,
    DateTime? end,
  }) async {
    Query query = FirebaseFirestore.instance.collection('bills');

    if (mobile != null && mobile.isNotEmpty) {
      query = query.where('customer_mobile', isEqualTo: mobile);
    }

    if (billNo != null && billNo.isNotEmpty) {
      query = query.where('bill_no', isEqualTo: billNo);
    }

    if (start != null && end != null) {
      query = query
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }

    final snapshot = await query.orderBy('date', descending: true).get();

    return snapshot.docs
        .map((doc) => Bill.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }
}
