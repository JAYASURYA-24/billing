import 'package:billing/features/models/bill.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // 🔸 Stream of all products
  Stream<List<Product>> productsStream() {
    return _db.collection('products').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addProduct(Product product) async {
    await _db.collection('products').add(product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    await _db.collection('products').doc(product.id).update(product.toMap());
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
  }

  Future<void> saveBill(Bill bill) async {
    await _db.collection('bills').doc(bill.id).set(bill.toMap());
  }

  // STREAM of Shops
  Stream<List<Shop>> shopsStream() {
    return _db.collection('shops').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Shop.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Add shop
  Future<void> addShop(Shop shop) async {
    await _db.collection('shops').add(shop.toMap());
  }

  // Update shop
  Future<void> updateShop(Shop shop) async {
    await _db.collection('shops').doc(shop.id).update(shop.toMap());
  }

  // Delete shop
  Future<void> deleteShop(String id) async {
    await _db.collection('shops').doc(id).delete();
  }

  // 🔸 Fetch all unique shop names
  Future<List<String>> fetchAllShopNames() async {
    final snapshot = await _db.collection('bills').get();
    final names =
        snapshot.docs.map((doc) => doc['shopName'] as String).toSet().toList();
    return names;
  }

  // 🔸 Fetch bills by payment status
  Future<List<Bill>> fetchBillsByStatus(bool isPaid) async {
    final snapshot =
        await _db
            .collection('bills')
            .where('isPaid', isEqualTo: isPaid)
            .orderBy('createdAt', descending: true)
            .get();

    return snapshot.docs
        .map((doc) => Bill.fromMap(doc.data(), doc.id)) // ✅ FIXED
        .toList();
  }

  // 🔸 Fetch all products
  Future<List<Product>> fetchProducts() async {
    final snapshot = await _db.collection('products').get();
    return snapshot.docs
        .map((doc) => Product.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> generateBillNumber() async {
    final now = DateTime.now();
    final datePart = DateFormat('yyyyMMdd').format(now);

    final todayStart = DateTime(now.year, now.month, now.day);
    final snapshot =
        await _db
            .collection('bills')
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
            )
            .get();

    final count = snapshot.docs.length + 1;
    final paddedCount = count.toString().padLeft(3, '0');

    return 'RJ-$datePart$paddedCount';
  }

  // 🔸 Fetch all unpaid bills for a shop
  Future<List<Bill>> fetchUnpaidBillsForShop(String shopName) async {
    final snapshot =
        await _db
            .collection('bills')
            .where('shopName', isEqualTo: shopName)
            .where('isPaid', isEqualTo: false)
            .get();

    return snapshot.docs
        .map((doc) => Bill.fromMap(doc.data(), doc.id)) // ✅ FIXED
        .toList();
  }

  // 🔸 Update payment status
  // Future<void> updateBillPaymentStatus(String billId, bool isPaid) async {
  //   if (billId.isEmpty) throw Exception('Cannot update: Bill ID is empty');

  //   final docRef = _db.collection('bills').doc(billId);
  //   await docRef.update({'isPaid': isPaid});

  //   final updatedDoc = await docRef.get();
  //   if ((updatedDoc.data()?['isPaid'] ?? false) == true) {
  //     print("✔️ Status updated confirmed for bill $billId");
  //   }
  // }

  // Future<void> updateBillPaymentStatus(String billId, bool isPaid) async {
  //   if (billId.isEmpty) throw Exception('Cannot update: Bill ID is empty');

  //   final docRef = _db.collection('bills').doc(billId);
  //   await docRef.update({'isPaid': isPaid});

  //   print("✔️ Bill $billId marked as paid.");
  // }

  // Future<void> markAllUnpaidBillsAsPaid(String shopName) async {
  //   final querySnapshot =
  //       await _db
  //           .collection('bills')
  //           .where('shopName', isEqualTo: shopName)
  //           .where('isPaid', isEqualTo: false)
  //           .get();

  //   final unpaidBills = querySnapshot.docs;

  //   for (final doc in unpaidBills) {
  //     await updateBillPaymentStatus(doc.id, true);
  //   }

  //   print("✅ All unpaid bills for shop '$shopName' have been marked as paid.");
  // }

  // Future<void> markUnpaidBillsAsPaidAndmakelastestasunpiad(
  //   String shopName,
  //   double newTotal,
  // ) async {
  //   final querySnapshot =
  //       await _db
  //           .collection('bills')
  //           .where('shopName', isEqualTo: shopName)
  //           .where('isPaid', isEqualTo: false)
  //           .get();

  //   final unpaidBills = querySnapshot.docs;

  //   for (final doc in unpaidBills) {
  //     await updateBillPartialTotal(doc.id, newTotal);
  //   }

  //   print("✅ All unpaid bills for shop '$shopName' have been marked as paid.");
  // }

  // Future<void> updateBillPartialTotal(String billId, double newTotal) async {
  //   if (billId.isEmpty) throw Exception('Bill ID is empty');

  //   final docRef = _db.collection('bills').doc(billId);
  //   await docRef.update({'total': newTotal, 'isPaid': false});

  //   print(
  //     "⚠️ Bill $billId updated with remaining unpaid: \$${newTotal.toStringAsFixed(2)}",
  //   );
  // }

  Future<void> updateBillPaymentStatus(String billId, bool isPaid) async {
    if (billId.isEmpty) throw Exception('Cannot update: Bill ID is empty');

    final docRef = _db.collection('bills').doc(billId);
    await docRef.update({'isPaid': isPaid});

    print("✔️ Bill $billId marked as paid.");
  }

  Future<void> updateBillPartialTotal(String billId, double newTotal) async {
    if (billId.isEmpty) throw Exception('Bill ID is empty');

    final docRef = _db.collection('bills').doc(billId);
    await docRef.update({'total': newTotal, 'isPaid': false});

    print(
      "⚠️ Bill $billId updated with remaining unpaid: \$${newTotal.toStringAsFixed(2)}",
    );
  }

  Future<void> markAllUnpaidBillsAsPaid(String shopName) async {
    final querySnapshot =
        await _db
            .collection('bills')
            .where('shopName', isEqualTo: shopName)
            .where('isPaid', isEqualTo: false)
            .get();

    final unpaidBills = querySnapshot.docs;

    for (final doc in unpaidBills) {
      await updateBillPaymentStatus(doc.id, true);
    }

    print("✅ All unpaid bills for shop '$shopName' have been marked as paid.");
  }

  Future<void> markUnpaidBillsAsPaidAndMakeLatestAsUnpaid(
    String shopName,
    double newTotal,
  ) async {
    final querySnapshot =
        await _db
            .collection('bills')
            .where('shopName', isEqualTo: shopName)
            .where('isPaid', isEqualTo: false)
            .orderBy('createdAt') // oldest to latest
            .get();

    final unpaidBills = querySnapshot.docs;

    if (unpaidBills.isEmpty) {
      print("ℹ️ No unpaid bills found for shop '$shopName'.");
      return;
    }

    final latestBillDoc = unpaidBills.last;
    final otherBills = unpaidBills.sublist(0, unpaidBills.length - 1);

    // Mark all other unpaid bills as paid
    for (final doc in otherBills) {
      await updateBillPaymentStatus(doc.id, true);
    }

    // Update latest bill with remaining unpaid amount
    await updateBillPartialTotal(latestBillDoc.id, newTotal);

    print(
      "✅ All unpaid bills except the latest have been marked as paid. "
      "Latest bill updated with remaining amount: \$${newTotal.toStringAsFixed(2)}",
    );
  }

  // 🔸 Fetch latest unpaid bill (not used anymore if you use all)
  Future<Bill?> fetchLatestUnpaidBillForShop(String shopName) async {
    final querySnapshot =
        await _db
            .collection('bills')
            .where('shopName', isEqualTo: shopName)
            .where('isPaid', isEqualTo: false)
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();

    if (querySnapshot.docs.isEmpty) return null;

    final doc = querySnapshot.docs.first;
    return Bill.fromMap(doc.data(), doc.id); // ✅ FIXED
  }

  // 🔸 Fetch all shops with unpaid bills
  Future<List<String>> fetchShopsWithUnpaidBills() async {
    final snapshot =
        await _db.collection('bills').where('isPaid', isEqualTo: false).get();

    final shopNames =
        snapshot.docs.map((doc) => doc['shopName'] as String).toSet().toList();
    return shopNames;
  }

  Future<List<String>> fetchShopsWithpaidBills() async {
    final snapshot =
        await _db.collection('bills').where('isPaid', isEqualTo: true).get();

    final shopNames =
        snapshot.docs.map((doc) => doc['shopName'] as String).toSet().toList();
    return shopNames;
  }

  Future<Bill?> fetchLatestpaidBillForShop(String shopName) async {
    final querySnapshot =
        await _db
            .collection('bills')
            .where('shopName', isEqualTo: shopName)
            .where('isPaid', isEqualTo: true)
            .limit(1)
            .get();

    if (querySnapshot.docs.isEmpty) return null;

    final doc = querySnapshot.docs.first;
    return Bill.fromMap(doc.data(), doc.id); // ✅ FIXED
  }

  // 🔸 Get bill by bill number
  Future<Bill?> fetchBillByNumber(String billNumber) async {
    final snapshot =
        await _db
            .collection('bills')
            .where('billNumber', isEqualTo: billNumber)
            .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    return Bill.fromMap(doc.data(), doc.id); // ✅ FIXED
  }

  Future<void> deleteBill(String billId) async {
    if (billId.isEmpty) throw Exception('Bill ID is empty');
    await _db.collection('bills').doc(billId).delete();
  }
}
