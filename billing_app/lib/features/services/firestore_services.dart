import 'dart:typed_data';

import 'package:billing/features/models/bill.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/product.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/shop.dart';

import 'package:http/http.dart' as http;

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

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

    // print("✔️ Bill $billId marked as paid.");
  }

  Future<void> updateBillPartialTotal(String billId, double newTotal) async {
    if (billId.isEmpty) throw Exception('Bill ID is empty');

    final docRef = _db.collection('bills').doc(billId);
    await docRef.update({'total': newTotal, 'isPaid': false});

    // print(
    //   "⚠️ Bill $billId updated with remaining unpaid: \$${newTotal.toStringAsFixed(2)}",
    // );
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
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _db
        .collection('bills')
        .where('isPaid', isEqualTo: true)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
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
    final firestore = FirebaseFirestore.instance;

    final billRef = firestore.collection('bills').doc(billId);
    final deletedRef = firestore.collection('deleted_bills').doc(billId);

    await firestore.runTransaction((transaction) async {
      // 1️⃣ READ BILL (FIRST READ)
      final billSnap = await transaction.get(billRef);
      if (!billSnap.exists) return;

      final billData = billSnap.data() ?? {};

      // 2️⃣ READ ITEMS LIST
      final items = List<Map<String, dynamic>>.from(billData['items'] ?? []);

      // 3️⃣ READ ALL PRODUCTS FIRST (NO WRITES)
      final productDataMap = <String, Map<String, dynamic>>{};
      for (final item in items) {
        final productId = item['productId'];
        if (productId == null) continue;

        final productRef = firestore.collection('products').doc(productId);

        final snap = await transaction.get(productRef); // READ ONLY
        if (!snap.exists) continue;

        productDataMap[productId] = {'ref': productRef, 'data': snap.data()};
      }

      // 4️⃣ NOW PERFORM ALL WRITES (NO MORE READS!)

      // Restore stock quantities
      for (final item in items) {
        final productId = item['productId'];
        final qty = item['quantity'] ?? 0;
        if (productId == null) continue;

        final productEntry = productDataMap[productId];
        if (productEntry == null) continue;

        final productRef = productEntry['ref'] as DocumentReference;
        final currentQty = productEntry['data']['quantity'] ?? 0;

        transaction.update(productRef, {'quantity': currentQty + qty});
      }

      // Move bill → deleted_bills
      final dataWithDeleteTime = Map<String, dynamic>.from(billData);
      dataWithDeleteTime['deletedAt'] = FieldValue.serverTimestamp();

      transaction.set(deletedRef, dataWithDeleteTime);

      // Delete from bills
      transaction.delete(billRef);
    });
  }

  Future<List<Bill>> fetchDeletedBills() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection('deleted_bills')
            .orderBy('deletedAt', descending: true)
            .get();

    return snapshot.docs.map((doc) => Bill.fromFirestore(doc)).toList();
  }

  Future<void> deleteAllBills() async {
    final batch = _db.batch();
    final snapshot = await _db.collection('bills').get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // Future<void> markBillsAsPaid(
  //   List<Bill> bills,
  //   double paidAmount,
  //   bool upiPayment,
  // ) async {
  //   final batch = _db.batch();
  //   double remainingPayment = paidAmount;

  //   final sortedBills = [...bills]
  //     ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  //   for (int i = 0; i < sortedBills.length; i++) {
  //     final bill = sortedBills[i];
  //     final docRef = _db.collection('bills').doc(bill.id);

  //     final originalBalance = bill.balance;
  //     final alreadyPaid = bill.paidAmount;

  //     if (remainingPayment >= originalBalance) {
  //       batch.update(docRef, {
  //         'isPaid': true,
  //         'paidAmount': alreadyPaid + originalBalance,
  //         'balance': 0.0,
  //         'markedAsPaidAt': Timestamp.now(),
  //         'upiPayment': upiPayment,
  //       });
  //       remainingPayment -= originalBalance;
  //     } else {
  //       final newPaidAmount = alreadyPaid + remainingPayment;
  //       final newBalance = originalBalance - remainingPayment;

  //       batch.update(docRef, {
  //         'isPaid': newBalance == 0.0,
  //         'paidAmount': newPaidAmount,
  //         'balance': newBalance,
  //         // 'markedAsPaidAt': Timestamp.now(),
  //       });

  //       remainingPayment = 0.0;

  //       for (int j = i + 1; j < sortedBills.length; j++) {
  //         final remainingBill = sortedBills[j];
  //         final docRef = _db.collection('bills').doc(remainingBill.id);

  //         batch.update(docRef, {
  //           'isPaid': false,
  //           'paidAmount': remainingBill.paidAmount,
  //           'balance': remainingBill.balance,
  //           // 'markedAsPaidAt': Timestamp.now(),
  //         });
  //       }

  //       break;
  //     }
  //   }

  //   await batch.commit();
  // }

  // Future<void> markBillsAsPaid(
  //   List<Bill> bills,
  //   double paidAmount,
  //   bool upiPayment,
  // ) async {
  //   final batch = _db.batch();
  //   double remainingPayment = paidAmount;

  //   final sortedBills = [...bills]
  //     ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  //   for (int i = 0; i < sortedBills.length; i++) {
  //     final bill = sortedBills[i];
  //     final docRef = _db.collection('bills').doc(bill.id);

  //     final originalBalance = bill.balance ?? 0.0;
  //     final alreadyPaid = bill.paidAmount ?? 0.0;

  //     // 💰 How much we pay to THIS bill in this transaction
  //     double paidToThisBill = 0.0;

  //     if (remainingPayment >= originalBalance) {
  //       paidToThisBill = originalBalance;

  //       batch.update(docRef, {
  //         'isPaid': true,
  //         'paidAmount': alreadyPaid + originalBalance,
  //         'balance': 0.0,
  //         'markedAsPaidAt': Timestamp.now(),
  //         'upiPayment': upiPayment,

  //         // 🟢 NEW FIELD → Amount paid now
  //         'paidToday': paidToThisBill,
  //       });

  //       remainingPayment -= originalBalance;
  //     } else {
  //       paidToThisBill = remainingPayment;

  //       final newPaidAmount = alreadyPaid + remainingPayment;
  //       final newBalance = originalBalance - remainingPayment;

  //       batch.update(docRef, {
  //         'isPaid': newBalance == 0.0,
  //         'paidAmount': newPaidAmount,
  //         'balance': newBalance,

  //         // 🟢 Only set timestamp when bill becomes paid
  //         if (newBalance == 0.0) 'markedAsPaidAt': Timestamp.now(),

  //         // 🟢 NEW FIELD
  //         'paidToday': paidToThisBill,
  //       });

  //       remainingPayment = 0.0;

  //       // All next bills remain untouched
  //       for (int j = i + 1; j < sortedBills.length; j++) {
  //         final rest = sortedBills[j];
  //         final doc2 = _db.collection('bills').doc(rest.id);

  //         batch.update(doc2, {
  //           'isPaid': rest.isPaid,
  //           'paidAmount': rest.paidAmount,
  //           'balance': rest.balance,

  //           // 🟡 VERY IMPORTANT → Not paid today
  //           'paidToday': 0.0,
  //         });
  //       }

  //       break;
  //     }
  //   }

  //   await batch.commit();
  // }

  // Future<void> markBillsAsPaid(
  //   List<Bill> bills,
  //   double paidAmount,
  //   bool upiPayment,
  // ) async {
  //   final batch = _db.batch();
  //   double remainingPayment = paidAmount;

  //   final sortedBills = [...bills]
  //     ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  //   for (int i = 0; i < sortedBills.length; i++) {
  //     final bill = sortedBills[i];
  //     final docRef = _db.collection('bills').doc(bill.id);

  //     final originalBalance = bill.balance;
  //     final alreadyPaid = bill.paidAmount;

  //     double paidToThisBill = 0.0;

  //     // --------------------------
  //     // FULL PAYMENT CASE
  //     // --------------------------
  //     if (remainingPayment >= originalBalance) {
  //       paidToThisBill = originalBalance;

  //       batch.update(docRef, {
  //         'isPaid': true,
  //         'paidAmount': alreadyPaid + originalBalance,
  //         'balance': 0.0,
  //         'markedAsPaidAt': Timestamp.now(),
  //         'upiPayment': upiPayment,

  //         'paidToday': paidToThisBill,
  //         'paidTodayAt': Timestamp.now(), // NEW
  //       });

  //       remainingPayment -= originalBalance;
  //     }
  //     // --------------------------
  //     // PARTIAL PAYMENT CASE
  //     // --------------------------
  //     else {
  //       paidToThisBill = remainingPayment;

  //       final newPaidAmount = alreadyPaid + remainingPayment;
  //       final newBalance = originalBalance - remainingPayment;

  //       batch.update(docRef, {
  //         'isPaid': newBalance == 0.0,
  //         'paidAmount': newPaidAmount,
  //         'balance': newBalance,

  //         if (newBalance == 0.0) 'markedAsPaidAt': Timestamp.now(),
  //         'upiPayment': upiPayment,

  //         'paidToday': paidToThisBill,
  //         'paidTodayAt': Timestamp.now(), // NEW
  //       });

  //       remainingPayment = 0.0;

  //       // All next bills — untouched today
  //       for (int j = i + 1; j < sortedBills.length; j++) {
  //         final rest = sortedBills[j];
  //         final doc2 = _db.collection('bills').doc(rest.id);

  //         batch.update(doc2, {
  //           'isPaid': rest.isPaid,
  //           'paidAmount': rest.paidAmount,
  //           'balance': rest.balance,
  //           'paidToday': 0.0,
  //         });
  //       }

  //       break;
  //     }
  //   }

  //   await batch.commit();
  // }
  Future<void> markBillsAsPaid(
    List<Bill> bills,
    double paidAmount,
    bool upiPayment,
  ) async {
    final batch = _db.batch();
    double remainingPayment = paidAmount;

    // Helper to fix floating-point issues
    double fix(double v) => double.parse(v.toStringAsFixed(2));

    // Sort bills oldest first
    final sortedBills = [...bills]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (int i = 0; i < sortedBills.length; i++) {
      final bill = sortedBills[i];
      final docRef = _db.collection('bills').doc(bill.id);

      final originalBalance = fix(bill.balance);
      final alreadyPaid = fix(bill.paidAmount);

      double paidToThisBill = 0.0;

      // ===========================================================
      // FULL PAYMENT CASE
      // ===========================================================
      if (remainingPayment >= originalBalance) {
        paidToThisBill = originalBalance;

        batch.update(docRef, {
          'isPaid': true,
          'paidAmount': fix(alreadyPaid + originalBalance),
          'balance': 0.0,

          'markedAsPaidAt': Timestamp.now(),
          'upiPayment': upiPayment,

          'paidToday': fix(paidToThisBill),
          'paidTodayAt': Timestamp.now(),
        });

        remainingPayment = fix(remainingPayment - originalBalance);
      }
      // ===========================================================
      // PARTIAL PAYMENT CASE
      // ===========================================================
      else {
        paidToThisBill = fix(remainingPayment);

        final newPaidAmount = fix(alreadyPaid + paidToThisBill);
        final newBalance = fix(originalBalance - paidToThisBill);

        batch.update(docRef, {
          'isPaid': newBalance == 0.0,
          'paidAmount': newPaidAmount,
          'balance': newBalance,

          if (newBalance == 0.0) 'markedAsPaidAt': Timestamp.now(),

          'upiPayment': upiPayment,

          'paidToday': paidToThisBill,
          'paidTodayAt': Timestamp.now(),
        });

        remainingPayment = 0.0;

        // ===========================================================
        // REMAINING BILLS → NOT TOUCHED TODAY
        // ===========================================================
        for (int j = i + 1; j < sortedBills.length; j++) {
          final rest = sortedBills[j];
          final doc2 = _db.collection('bills').doc(rest.id);

          batch.update(doc2, {
            'isPaid': rest.isPaid,
            'paidAmount': fix(rest.paidAmount),
            'balance': fix(rest.balance),
            'paidToday': 0.0,
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

  // Future<Map<String, Map<String, List<Bill>>>> fetchBillsByDate(
  //   DateTime date,
  // ) async {
  //   final start = DateTime(date.year, date.month, date.day);
  //   final end = start.add(const Duration(days: 1));

  //   final billsCollection = FirebaseFirestore.instance.collection('bills');

  //   // Fetch bills created today
  //   final createdSnap =
  //       await billsCollection
  //           .where(
  //             'createdAt',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(start),
  //           )
  //           .where('createdAt', isLessThan: Timestamp.fromDate(end))
  //           .get();

  //   // Fetch bills marked paid today
  //   final paidSnap =
  //       await billsCollection
  //           .where(
  //             'markedAsPaidAt',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(start),
  //           )
  //           .where('markedAsPaidAt', isLessThan: Timestamp.fromDate(end))
  //           .get();

  //   final createdBills =
  //       createdSnap.docs.map((d) => Bill.fromFirestore(d)).toList();
  //   final paidBills = paidSnap.docs.map((d) => Bill.fromFirestore(d)).toList();

  //   // -------------------
  //   // 🔹 Split created bills into categories
  //   // -------------------

  //   // final createdUpi = createdBills.where((b) => b.upiPayment == true).toList();
  //   // final createdCash =
  //   //     createdBills
  //   //         .where((b) => b.upiPayment != true && b.isPaid == true)
  //   //         .toList(); // Paid cash bills
  //   // final createdUnpaid = createdBills.where((b) => b.isPaid == false).toList();

  //   final createdUpi = createdBills.where((b) => b.upiPayment == true).toList();

  //   final createdUnpaid = createdBills.where((b) => b.isPaid == false).toList();

  //   final createdCash =
  //       createdBills.where((b) {
  //         // If unpaid, skip (already in unpaid)
  //         if (b.isPaid == false) return false;

  //         // If explicitly UPI, skip
  //         if (b.upiPayment == true) return false;

  //         // Cash = upiPayment == false or null
  //         return true;
  //       }).toList();

  //   // -------------------
  //   // 🔹 Split paid today bills
  //   // Remove bills that were also created today
  //   // -------------------
  //   final createdIds = createdBills.map((b) => b.id).toSet();
  //   final paidTodayFiltered =
  //       paidBills.where((b) => !createdIds.contains(b.id)).toList();

  //   final paidTodayUpi =
  //       paidTodayFiltered.where((b) => b.upiPayment == true).toList();
  //   final paidTodayCash =
  //       paidTodayFiltered.where((b) => b.upiPayment != true).toList();

  //   return {
  //     "created": {
  //       "upi": createdUpi,
  //       "cash": createdCash,
  //       "unpaid": createdUnpaid,
  //     },
  //     "paidToday": {"upi": paidTodayUpi, "cash": paidTodayCash},
  //   };
  // }

  // Future<Map<String, List<Bill>>> fetchBillsByDate(DateTime date) async {
  //   final start = DateTime(date.year, date.month, date.day);
  //   final end = start.add(const Duration(days: 1));

  //   final billsCollection = FirebaseFirestore.instance.collection('bills');

  //   // 1️⃣ Created bills today
  //   final createdSnap =
  //       await billsCollection
  //           .where(
  //             'createdAt',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(start),
  //           )
  //           .where('createdAt', isLessThan: Timestamp.fromDate(end))
  //           .get();

  //   final createdBills =
  //       createdSnap.docs.map((d) => Bill.fromFirestore(d)).toList();

  //   // 2️⃣ Paid Today = ONLY FULL PAID bills
  //   final paidSnap =
  //       await billsCollection
  //           .where('isPaid', isEqualTo: true)
  //           .where(
  //             'markedAsPaidAt',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(start),
  //           )
  //           .where('markedAsPaidAt', isLessThan: Timestamp.fromDate(end))
  //           .get();

  //   final paidBills = paidSnap.docs.map((d) => Bill.fromFirestore(d)).toList();

  //   // Remove bills created today from paidToday
  //   final createdIds = createdBills.map((b) => b.id).toSet();
  //   final paidToday =
  //       paidBills.where((b) => !createdIds.contains(b.id)).toList();

  //   return {'created': createdBills, 'paidToday': paidToday};
  // }
  Future<Map<String, List<Bill>>> fetchBillsByDate(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final billsCollection = FirebaseFirestore.instance.collection('bills');

    // ----------------------------------------
    // 1️⃣ BILLS CREATED TODAY
    // ----------------------------------------
    final createdSnap =
        await billsCollection
            .where(
              'createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('createdAt', isLessThan: Timestamp.fromDate(end))
            .get();

    final createdBills =
        createdSnap.docs.map((d) => Bill.fromFirestore(d)).toList();

    // ----------------------------------------
    // 2️⃣ ALL payments made today (full or partial)
    // ----------------------------------------
    final paidSnap =
        await billsCollection
            .where(
              'paidTodayAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            )
            .where('paidTodayAt', isLessThan: Timestamp.fromDate(end))
            .get();

    final paidBills = paidSnap.docs.map((d) => Bill.fromFirestore(d)).toList();

    // Remove bills created today from "paidToday"
    final createdIds = createdBills.map((b) => b.id).toSet();
    final paidToday =
        paidBills.where((b) => !createdIds.contains(b.id)).toList();

    return {'created': createdBills, 'paidToday': paidToday};
  }

  // Future<Map<String, Map<String, List<Bill>>>> fetchBillsByDate(
  //   DateTime date,
  // ) async {
  //   final start = DateTime(date.year, date.month, date.day);
  //   final end = start.add(const Duration(days: 1));

  //   final bills = FirebaseFirestore.instance.collection('bills');

  //   final createdSnap =
  //       await bills
  //           .where(
  //             'createdAt',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(start),
  //           )
  //           .where('createdAt', isLessThan: Timestamp.fromDate(end))
  //           .get();

  //   final paidSnap =
  //       await bills
  //           .where(
  //             'markedAsPaidAt',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(start),
  //           )
  //           .where('markedAsPaidAt', isLessThan: Timestamp.fromDate(end))
  //           .get();

  //   final createdBills =
  //       createdSnap.docs.map((d) => Bill.fromFirestore(d)).toList();
  //   final paidBills = paidSnap.docs.map((d) => Bill.fromFirestore(d)).toList();

  //   // 🟢 Corrected logic

  //   // UPI = true
  //   final createdUpi =
  //       createdBills.where((bill) => bill.upiPayment == true).toList();

  //   // Cash = false OR null
  //   final createdCash =
  //       createdBills.where((bill) => bill.upiPayment != true).toList();

  //   // Unpaid = isPaid false
  //   final createdUnpaid =
  //       createdBills.where((bill) => bill.isPaid == false).toList();

  //   // Paid today categories
  //   final paidUpi = paidBills.where((bill) => bill.upiPayment == true).toList();
  //   final paidCash =
  //       paidBills.where((bill) => bill.upiPayment != true).toList();

  //   // Remove duplicate
  //   final filteredPaidUpi =
  //       paidUpi.where((p) => !createdUpi.any((c) => c.id == p.id)).toList();

  //   final filteredPaidCash =
  //       paidCash.where((p) => !createdCash.any((c) => c.id == p.id)).toList();

  //   return {
  //     "created": {
  //       "cash": createdCash,
  //       "upi": createdUpi,
  //       "unpaid": createdUnpaid,
  //     },
  //     "paidToday": {"cash": filteredPaidCash, "upi": filteredPaidUpi},
  //   };
  // }

  Future<void> updateProductQuantity(String productId, int changeBy) async {
    final docRef = FirebaseFirestore.instance
        .collection('products')
        .doc(productId);

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;

      final currentQty = (snapshot['quantity'] ?? 0) as int;
      int updatedQty = currentQty + changeBy;

      // ✅ Prevent negative quantity
      if (updatedQty < 0) updatedQty = 0;

      transaction.update(docRef, {'quantity': updatedQty});
    });
  }

  Future<void> decreaseProductQuantity(String productId, int decreaseBy) async {
    final docRef = FirebaseFirestore.instance
        .collection('products')
        .doc(productId);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      final currentQty = snapshot['quantity'] ?? 0;
      final updatedQty =
          (currentQty - decreaseBy).clamp(0, double.infinity).toInt();
      transaction.update(docRef, {'quantity': updatedQty});
    });
  }

  Future<String?> uploadSignature(
    Uint8List signBytes,
    String shopName,
    String billId,
  ) async {
    try {
      final ref = _storage.ref().child('signatures/$shopName/$billId.png');

      await ref.putData(signBytes, SettableMetadata(contentType: 'image/png'));

      return await ref.getDownloadURL();
    } catch (e) {
      print("Signature upload error: $e");
      return null;
    }
  }

  Future<Uint8List?> getSignatureBytes(String billId) async {
    try {
      // Use FirebaseFirestore.instance directly
      final doc =
          await FirebaseFirestore.instance
              .collection("bills")
              .doc(billId)
              .get();

      if (!doc.exists) return null;

      final signatureUrl = doc.data()?["signatureUrl"];
      if (signatureUrl == null) return null;

      final response = await http.get(Uri.parse(signatureUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      print("Signature download error: $e");
      return null;
    }
  }
}
