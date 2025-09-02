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

  Stream<List<Map<String, dynamic>>> streamShopsWithUnPaidBills() {
    return _db
        .collection('bills')
        .where('isPaid', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};

          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final balance = data['balance'] as num;
            if (balance == 0) continue;

            final shopName = data['shopName'] as String;
            grouped.putIfAbsent(shopName, () => []).add(doc);
          }

          return grouped.entries.map((entry) {
            final unpaidBills =
                entry.value
                    .map(
                      (doc) => Bill.fromMap(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList();

            final totalUnPaid = unpaidBills.fold<double>(
              0,
              (sum, bill) => sum + bill.balance.toDouble(),
            );

            return {
              'shopName': entry.key,
              'bills': unpaidBills,
              'count': unpaidBills.length,
              'totalUnPaid': totalUnPaid,
            };
          }).toList();
        });
  }

  Stream<List<Map<String, dynamic>>> streamShopsWithPaidBills() {
    return _db
        .collection('bills')
        .where('isPaid', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final Map<String, List<QueryDocumentSnapshot>> grouped = {};

          for (final doc in snapshot.docs) {
            final shopName = doc['shopName'] as String;
            grouped.putIfAbsent(shopName, () => []).add(doc);
          }

          return grouped.entries.map((entry) {
            final paidBills =
                entry.value
                    .map(
                      (doc) => Bill.fromMap(
                        doc.data() as Map<String, dynamic>,
                        doc.id,
                      ),
                    )
                    .toList();

            final totalPaid = paidBills.fold<double>(
              0,
              (sum, bill) => sum + bill.currentPurchaseTotal.toDouble(),
            );

            return {
              'shopName': entry.key,
              'bills': paidBills,
              'count': paidBills.length,
              'totalPaid': totalPaid,
            };
          }).toList();
        });
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

  Future<void> deleteAllBills() async {
    final batch = _db.batch();
    final snapshot = await _db.collection('bills').get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> markBillsAsPaid(List<Bill> bills, double paidAmount) async {
    final batch = _db.batch();
    double remainingPayment = paidAmount;

    final sortedBills = [...bills]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (int i = 0; i < sortedBills.length; i++) {
      final bill = sortedBills[i];
      final docRef = _db.collection('bills').doc(bill.id);

      final originalBalance = bill.balance;
      final alreadyPaid = bill.paidAmount;

      if (remainingPayment >= originalBalance) {
        batch.update(docRef, {
          'isPaid': true,
          'paidAmount': alreadyPaid + originalBalance,
          'balance': 0.0,
        });
        remainingPayment -= originalBalance;
      } else {
        final newPaidAmount = alreadyPaid + remainingPayment;
        final newBalance = originalBalance - remainingPayment;

        batch.update(docRef, {
          'isPaid': newBalance == 0.0,
          'paidAmount': newPaidAmount,
          'balance': newBalance,
        });

        remainingPayment = 0.0;

        for (int j = i + 1; j < sortedBills.length; j++) {
          final remainingBill = sortedBills[j];
          final docRef = _db.collection('bills').doc(remainingBill.id);

          batch.update(docRef, {
            'isPaid': false,
            'paidAmount': remainingBill.paidAmount,
            'balance': remainingBill.balance,
          });
        }

        break;
      }
    }

    await batch.commit();
  }

  Future<List<Bill>> fetchBillsByIds(List<String> billIds) async {
    final firestore = FirebaseFirestore.instance;
    final List<Bill> bills = [];

    for (final id in billIds) {
      final doc = await firestore.collection('bills').doc(id).get();
      if (doc.exists) {
        bills.add(Bill.fromFirestore(doc));
      }
    }

    return bills;
  }

  Future<List<Bill>> fetchAllBills() async {
    final snapshot = await _db.collection('bills').get();

    return snapshot.docs.map((doc) => Bill.fromMap(doc.data())).toList();
  }

  // 🔸 Unpaid bills of ALL shops (by date range)
  Stream<List<Map<String, dynamic>>> streamAllShopsUnPaidByDateRange(
    DateTime start,
    DateTime end,
  ) {
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));

    return _db
        .collection('bills')
        .where('isPaid', isEqualTo: false)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
          final bills =
              snapshot.docs
                  .map((doc) => Bill.fromMap(doc.data(), doc.id))
                  .toList();

          // 🔹 Group by shopName
          final Map<String, List<Bill>> grouped = {};
          for (final bill in bills) {
            grouped.putIfAbsent(bill.shopName, () => []).add(bill);
          }

          final List<Map<String, dynamic>> result = [];
          double grandTotal = 0;
          int grandCount = 0;

          grouped.forEach((shop, shopBills) {
            final totalUnPaid = shopBills.fold<double>(
              0,
              (sum, b) => sum + b.balance.toDouble(),
            );
            result.add({
              'shopName': shop,
              'bills': shopBills,
              'count': shopBills.length,
              'totalUnPaid': totalUnPaid,
            });

            grandTotal += totalUnPaid;
            grandCount += shopBills.length;
          });

          // 🔹 Add grand total
          result.add({
            'shopName': 'ALL_SHOPS',
            'bills': bills,
            'count': grandCount,
            'totalUnPaid': grandTotal,
          });

          return result;
        });
  }

  // 🔸 Paid bills of ALL shops (by date range)
  Stream<List<Map<String, dynamic>>> streamAllShopsPaidByDateRange(
    DateTime start,
    DateTime end,
  ) {
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));

    return _db
        .collection('bills')
        .where('isPaid', isEqualTo: true)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snapshot) {
          final bills =
              snapshot.docs
                  .map((doc) => Bill.fromMap(doc.data(), doc.id))
                  .toList();

          // 🔹 Group by shopName
          final Map<String, List<Bill>> grouped = {};
          for (final bill in bills) {
            grouped.putIfAbsent(bill.shopName, () => []).add(bill);
          }

          final List<Map<String, dynamic>> result = [];
          double grandTotal = 0;
          int grandCount = 0;

          grouped.forEach((shop, shopBills) {
            final totalPaid = shopBills.fold<double>(
              0,
              (sum, b) => sum + b.currentPurchaseTotal.toDouble(),
            );
            result.add({
              'shopName': shop,
              'bills': shopBills,
              'count': shopBills.length,
              'totalPaid': totalPaid,
            });

            grandTotal += totalPaid;
            grandCount += shopBills.length;
          });

          // 🔹 Add grand total
          result.add({
            'shopName': 'ALL_SHOPS',
            'bills': bills,
            'count': grandCount,
            'totalPaid': grandTotal,
          });

          return result;
        });
  }

  // 🔸 Unpaid bills of ALL shops (by month)
  Stream<List<Map<String, dynamic>>> streamAllShopsUnPaidByMonth(
    int year,
    int month,
  ) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    return _db
        .collection('bills')
        .where('isPaid', isEqualTo: false)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
          final bills =
              snapshot.docs
                  .map((doc) => Bill.fromMap(doc.data(), doc.id))
                  .toList();

          final Map<String, List<Bill>> grouped = {};
          for (final bill in bills) {
            grouped.putIfAbsent(bill.shopName, () => []).add(bill);
          }

          final List<Map<String, dynamic>> result = [];
          double grandTotal = 0;
          int grandCount = 0;

          grouped.forEach((shop, shopBills) {
            final totalUnPaid = shopBills.fold<double>(
              0,
              (sum, b) => sum + b.balance.toDouble(),
            );
            result.add({
              'shopName': shop,
              'bills': shopBills,
              'count': shopBills.length,
              'totalUnPaid': totalUnPaid,
            });

            grandTotal += totalUnPaid;
            grandCount += shopBills.length;
          });

          result.add({
            'shopName': 'ALL_SHOPS',
            'bills': bills,
            'count': grandCount,
            'totalUnPaid': grandTotal,
          });

          return result;
        });
  }

  // 🔸 Paid bills of ALL shops (by month)
  Stream<List<Map<String, dynamic>>> streamAllShopsPaidByMonth(
    int year,
    int month,
  ) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);

    return _db
        .collection('bills')
        .where('isPaid', isEqualTo: true)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
          final bills =
              snapshot.docs
                  .map((doc) => Bill.fromMap(doc.data(), doc.id))
                  .toList();

          final Map<String, List<Bill>> grouped = {};
          for (final bill in bills) {
            grouped.putIfAbsent(bill.shopName, () => []).add(bill);
          }

          final List<Map<String, dynamic>> result = [];
          double grandTotal = 0;
          int grandCount = 0;

          grouped.forEach((shop, shopBills) {
            final totalPaid = shopBills.fold<double>(
              0,
              (sum, b) => sum + b.currentPurchaseTotal.toDouble(),
            );
            result.add({
              'shopName': shop,
              'bills': shopBills,
              'count': shopBills.length,
              'totalPaid': totalPaid,
            });

            grandTotal += totalPaid;
            grandCount += shopBills.length;
          });

          result.add({
            'shopName': 'ALL_SHOPS',
            'bills': bills,
            'count': grandCount,
            'totalPaid': grandTotal,
          });

          return result;
        });
  }
}
