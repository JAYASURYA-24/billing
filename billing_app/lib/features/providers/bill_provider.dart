import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../models/bill.dart';
import '../services/firestore_services.dart';

final isRefreshProvider = StateProvider<bool>((ref) => false);

final billingProvider = StateNotifierProvider<BillingNotifier, Bill>((ref) {
  return BillingNotifier(ref);
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.productsStream();
});

final unpaidBillsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.streamShopsWithUnPaidBills();
});

final paidBillsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.streamShopsWithPaidBills();
});

class BillingNotifier extends StateNotifier<Bill> {
  final Ref ref;

  BillingNotifier(this.ref)
    : super(
        Bill(
          id: const Uuid().v4(),
          billNumber: '',
          shopName: '',
          items: [],
          isPaid: true,
          createdAt: Timestamp.now(),

          currentPurchaseTotal: 0.0,
          previousUnpaid: 0.0,
          paidAmount: 0.0,
          balance: 0.0,
        ),
      );

  void addItem(Product product, int quantity, double price) {
    final existing = state.items.firstWhere(
      (item) => item.productId == product.id,
      orElse: () => BillItem(productId: '', name: '', price: 0, quantity: 0),
    );

    final updatedItems =
        existing.productId.isNotEmpty
            ? state.items.map((item) {
              return item.productId == product.id
                  ? BillItem(
                    productId: item.productId,
                    name: item.name,
                    price: item.price,
                    quantity: item.quantity + quantity,
                  )
                  : item;
            }).toList()
            : [
              ...state.items,
              BillItem(
                productId: product.id,
                name: product.name,
                price: price,
                quantity: quantity,
              ),
            ];

    final updatedTotal = updatedItems.fold(
      0.0,
      (sum, item) => sum + item.price * item.quantity,
    );

    state = state.copyWith(items: updatedItems, total: updatedTotal);
  }

  void removeItem(BillItem itemToRemove) {
    final updatedItems =
        state.items
            .where((i) => i.productId != itemToRemove.productId)
            .toList();

    final updatedTotal = updatedItems.fold(
      0.0,
      (sum, i) => sum + i.price * i.quantity,
    );

    state = state.copyWith(items: updatedItems, total: updatedTotal);
  }

  // Future<String> _generateBillNumber() async {
  //   final now = DateTime.now();
  //   final datePart = DateFormat('yyMMdd').format(now);

  //   final todayStart = DateTime(now.year, now.month, now.day);
  //   final snapshot =
  //       await FirebaseFirestore.instance
  //           .collection('bills')
  //           .where(
  //             'createdAt',
  //             isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
  //           )
  //           .get();

  //   final count = snapshot.docs.length + 1;
  //   final paddedCount = count.toString().padLeft(3, '0');

  //   return 'RJ-$datePart$paddedCount';
  // }

  // Future<String> _generateBillNumber() async {
  //   final now = DateTime.now();
  //   final monthKey = DateFormat('yyMM').format(now); // e.g. 2509 for Sept 2025

  //   final counterRef = FirebaseFirestore.instance
  //       .collection('counters')
  //       .doc(monthKey); // one counter per month

  //   return FirebaseFirestore.instance.runTransaction((transaction) async {
  //     final snapshot = await transaction.get(counterRef);

  //     int newCount = 1;
  //     if (snapshot.exists) {
  //       final current = snapshot.get('lastNumber') as int;
  //       newCount = current + 1;
  //       transaction.update(counterRef, {'lastNumber': newCount});
  //     } else {
  //       transaction.set(counterRef, {'lastNumber': newCount});
  //     }

  //     final padded = newCount.toString().padLeft(4, '0'); // 🔹 4-digit padding
  //     return 'RJ-$monthKey$padded';
  //     // Example: RJ-25090001, RJ-25090002... RJ-25091234
  //   });
  // }

  // Future<(Bill, List<Bill>)> generateBill(
  //   String shopName,
  //   bool isPaid, {
  //   bool isPreview = false,
  //   double paidAmount = 0.0,

  //   double discountAmount = 0.0,
  //   double discountedTotal = 0.0,
  // }) async {
  //   final firestore = ref.read(firestoreServiceProvider);
  //   final createdAt = Timestamp.now();
  //   final billNumber = await _generateBillNumber();

  //   double previousUnpaid = 0.0;
  //   List<Bill> displayUnpaidBills = [];

  //   final unpaidBills = await firestore.fetchUnpaidBillsForShop(shopName);
  //   unpaidBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  //   // Calculate previous unpaid (these remain unpaid)
  //   previousUnpaid = unpaidBills.fold(0.0, (sum, bill) {
  //     final billTotal =
  //         bill.discountedTotal > 0
  //             ? bill.discountedTotal
  //             : bill.currentPurchaseTotal;
  //     return sum + (billTotal - bill.paidAmount);
  //   });

  //   displayUnpaidBills = unpaidBills;

  //   // Calculate current purchase total
  //   final currentTotal = state.items.fold(
  //     0.0,
  //     (sum, item) => sum + item.price * item.quantity,
  //   );

  //   // Current bill calculations
  //   final finalDiscountedTotal =
  //       discountedTotal > 0 ? discountedTotal : currentTotal;
  //   final finalDiscountAmount = discountAmount > 0 ? discountAmount : 0.0;

  //   // Current bill balance (what remains unpaid for current bill only)
  //   final currentBillBalance = finalDiscountedTotal - paidAmount;

  //   // Total balance that will remain unpaid (previous + current bill balance)
  //   final totalBalance =
  //       previousUnpaid + (currentBillBalance > 0 ? currentBillBalance : 0);

  //   final bill = Bill(
  //     id: const Uuid().v4(),
  //     shopName: shopName,
  //     items: state.items,
  //     isPaid: isPaid, // This indicates if CURRENT BILL is paid
  //     createdAt: createdAt,
  //     billNumber: billNumber,
  //     currentPurchaseTotal: currentTotal,
  //     previousUnpaid: previousUnpaid, // Previous bills remain as unpaid
  //     paidAmount: paidAmount, // Amount paid for current bill only
  //     balance: totalBalance, // Total amount that will remain unpaid

  //     discountAmount: finalDiscountAmount,
  //     discountedTotal: finalDiscountedTotal, // Current bill after discount
  //   );

  //   // Save bill if not a preview
  //   if (!isPreview) {
  //     await firestore.saveBill(bill);

  //     // Reset state
  //     state = Bill(
  //       id: const Uuid().v4(),
  //       shopName: '',
  //       items: [],
  //       isPaid: true,
  //       createdAt: Timestamp.now(),
  //       billNumber: '',
  //       currentPurchaseTotal: 0.0,
  //       previousUnpaid: 0.0,
  //       paidAmount: 0.0,
  //       balance: 0.0,
  //     );
  //   }

  //   return (bill, displayUnpaidBills);
  // }

  // Assuming you already have your Bill model defined

  Future<(Bill, List<Bill>)> generateBill(
    String shopName,
    bool isPaid, {
    bool isPreview = false,
    double paidAmount = 0.0,
    double discountAmount = 0.0,
    double discountedTotal = 0.0,
  }) async {
    final firestore = ref.read(firestoreServiceProvider);
    final createdAt = Timestamp.now();

    // 🔹 Step 1: Calculate unpaid bills before creating new one
    final unpaidBills = await firestore.fetchUnpaidBillsForShop(shopName);
    unpaidBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final previousUnpaid = unpaidBills.fold(0.0, (sum, bill) {
      final billTotal =
          bill.discountedTotal > 0
              ? bill.discountedTotal
              : bill.currentPurchaseTotal;
      return sum + (billTotal - bill.paidAmount);
    });

    // 🔹 Step 2: Calculate current totals
    final currentTotal = state.items.fold(
      0.0,
      (sum, item) => sum + item.price * item.quantity,
    );

    final finalDiscountedTotal =
        discountedTotal > 0 ? discountedTotal : currentTotal;
    final finalDiscountAmount = discountAmount > 0 ? discountAmount : 0.0;

    final currentBillBalance = finalDiscountedTotal - paidAmount;
    // final totalBalance =
    //     previousUnpaid + (currentBillBalance > 0 ? currentBillBalance : 0);
    final totalBalance = currentBillBalance;

    if (isPreview) {
      // 🔹 Return a preview bill without saving
      final previewBill = Bill(
        id: const Uuid().v4(),
        shopName: shopName,
        items: state.items,
        isPaid: isPaid,
        createdAt: createdAt,
        billNumber: "PREVIEW",
        currentPurchaseTotal: currentTotal,
        previousUnpaid: previousUnpaid,
        paidAmount: paidAmount,
        balance: totalBalance,
        discountAmount: finalDiscountAmount,
        discountedTotal: finalDiscountedTotal,
      );

      return (previewBill, unpaidBills);
    }

    // 🔹 Step 3: Transaction (counter + bill save together)
    final monthKey = DateFormat('yyMM').format(DateTime.now());
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc(monthKey);

    late Bill newBill;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final counterSnap = await transaction.get(counterRef);

      int newCount = 1;
      if (counterSnap.exists) {
        final current = counterSnap.get('lastNumber') as int;
        newCount = current + 1;
        transaction.update(counterRef, {'lastNumber': newCount});
      } else {
        transaction.set(counterRef, {'lastNumber': newCount});
      }

      final padded = newCount.toString().padLeft(4, '0');
      final billNumber = 'RJ-$monthKey$padded';

      newBill = Bill(
        id: const Uuid().v4(),
        shopName: shopName,
        items: state.items,
        isPaid: isPaid,
        createdAt: createdAt,
        billNumber: billNumber,
        currentPurchaseTotal: currentTotal,
        previousUnpaid: previousUnpaid,
        paidAmount: paidAmount,
        balance: totalBalance,
        discountAmount: finalDiscountAmount,
        discountedTotal: finalDiscountedTotal,
      );

      // Save bill inside the same transaction
      final billRef = FirebaseFirestore.instance
          .collection('bills')
          .doc(newBill.id);
      transaction.set(billRef, newBill.toMap()); // ✅ works with your model
    });

    // 🔹 Step 4: Reset state after saving
    state = Bill(
      id: const Uuid().v4(),
      shopName: '',
      items: [],
      isPaid: true,
      createdAt: Timestamp.now(),
      billNumber: '',
      currentPurchaseTotal: 0.0,
      previousUnpaid: 0.0,
      paidAmount: 0.0,
      balance: 0.0,
    );

    return (newBill, unpaidBills);
  }

  void updateItemQuantity(BillItem item, int newQty) {
    state = state.copyWith(
      items:
          state.items.map((e) {
            if (e.productId == item.productId) {
              return e.copyWith(quantity: newQty);
            }
            return e;
          }).toList(),
    );
  }

  // ✅ All shops unpaid by date
  final allShopsUnPaidByDateProvider =
      StreamProvider.family<List<Map<String, dynamic>>, (DateTime, DateTime)>((
        ref,
        tuple,
      ) {
        final firestore = ref.watch(firestoreServiceProvider);
        final (start, end) = tuple;
        return firestore.streamAllShopsUnPaidByDateRange(start, end);
      });

  // ✅ All shops paid by date
  final allShopsPaidByDateProvider =
      StreamProvider.family<List<Map<String, dynamic>>, (DateTime, DateTime)>((
        ref,
        tuple,
      ) {
        final firestore = ref.watch(firestoreServiceProvider);
        final (start, end) = tuple;
        return firestore.streamAllShopsPaidByDateRange(start, end);
      });

  // ✅ All shops unpaid by month
  final allShopsUnPaidByMonthProvider =
      StreamProvider.family<List<Map<String, dynamic>>, (int, int)>((
        ref,
        tuple,
      ) {
        final firestore = ref.watch(firestoreServiceProvider);
        final (year, month) = tuple;
        return firestore.streamAllShopsUnPaidByMonth(year, month);
      });

  // ✅ All shops paid by month
  final allShopsPaidByMonthProvider =
      StreamProvider.family<List<Map<String, dynamic>>, (int, int)>((
        ref,
        tuple,
      ) {
        final firestore = ref.watch(firestoreServiceProvider);
        final (year, month) = tuple;
        return firestore.streamAllShopsPaidByMonth(year, month);
      });
}
