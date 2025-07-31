import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../models/product.dart';
import '../models/bill.dart';
import '../services/firestore_services.dart';

final billingProvider = StateNotifierProvider<BillingNotifier, Bill>((ref) {
  return BillingNotifier(ref);
});
final unpaidBillsFutureProvider = FutureProvider.family<List<Bill>, String>((
  ref,
  shopName,
) {
  final firestore = ref.read(firestoreServiceProvider);
  return firestore.fetchUnpaidBillsForShop(shopName);
});

final productsProvider = StreamProvider<List<Product>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.productsStream();
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
          total: 0.0,
          currentPurchaseTotal: 0.0,
          previousUnpaid: 0.0,
          paidAmount: 0.0,
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

  Future<String> _generateBillNumber() async {
    final now = DateTime.now();
    final datePart = DateFormat('yyMMdd').format(now);

    final todayStart = DateTime(now.year, now.month, now.day);
    final snapshot =
        await FirebaseFirestore.instance
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

  Future<(Bill, List<Bill>)> generateBill(
    String shopName,
    bool isPaid, {
    bool isPreview = false,
    double paidAmount = 0.0, // ✅ Optional: paid at time of billing
  }) async {
    final firestore = ref.read(firestoreServiceProvider);
    final createdAt = Timestamp.now();
    final billNumber = await _generateBillNumber();

    double previousUnpaid = 0.0;
    List<Bill> displayUnpaidBills = [];

    if (!isPreview) {
      if (isPaid) {
        final unpaidBills = await firestore.fetchUnpaidBillsForShop(shopName);

        previousUnpaid = unpaidBills.fold(
          0.0,
          (sum, bill) => sum + bill.currentPurchaseTotal - bill.paidAmount,
        );

        for (final bill in unpaidBills) {
          await firestore.updateBillPaymentStatus(bill.id, true);
        }
      } else {
        final unpaidBills = await firestore.fetchUnpaidBillsForShop(shopName);
        unpaidBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        previousUnpaid = unpaidBills.fold(
          0.0,
          (sum, bill) => sum + bill.currentPurchaseTotal - bill.paidAmount,
        );

        displayUnpaidBills = unpaidBills;
      }
    } else {
      final unpaidBills = await firestore.fetchUnpaidBillsForShop(shopName);
      unpaidBills.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      previousUnpaid = unpaidBills.fold(0.0, (sum, bill) {
        return sum + (bill.currentPurchaseTotal - bill.paidAmount).abs();
      });

      displayUnpaidBills = unpaidBills;
    }

    // ✅ Calculate current purchase total
    final currentTotal = state.items.fold(
      0.0,
      (sum, item) => sum + item.price * item.quantity,
    );

    // ✅ Calculate total before payment
    double baseTotal = currentTotal + previousUnpaid;

    // ✅ Calculate remaining unpaid
    double remainingUnpaid = 0.0;
    if (!isPaid) {
      remainingUnpaid = (baseTotal - paidAmount).abs();

      if (remainingUnpaid < 0.0) remainingUnpaid = 0.0;
    }

    // ✅ Final total to store
    final double finalTotal = isPaid ? baseTotal : remainingUnpaid;
    print("unpaiddddddddddddddddddddddddddddddddddd$remainingUnpaid");
    print("finaltotallllllllllllllllllll$finalTotal");

    // ✅ Create Bill object
    final bill = Bill(
      id: const Uuid().v4(),
      shopName: shopName,
      items: state.items,
      isPaid: isPaid || remainingUnpaid == 0.0,
      createdAt: createdAt,
      billNumber: billNumber,
      total: finalTotal,
      currentPurchaseTotal: currentTotal,
      previousUnpaid: previousUnpaid,
      paidAmount: paidAmount,
    );

    // ✅ Save bill if not a preview
    if (!isPreview) {
      await firestore.saveBill(bill);

      // ✅ Reset state
      state = Bill(
        id: const Uuid().v4(),
        shopName: '',
        items: [],
        isPaid: true,
        createdAt: Timestamp.now(),
        billNumber: '',
        total: 0.0,
        currentPurchaseTotal: 0.0,
        previousUnpaid: 0.0,
        paidAmount: 0.0,
      );
    }

    return (bill, displayUnpaidBills);
  }

  void updateItemQuantity(BillItem item, int newQuantity) {
    final updatedItems =
        state.items.map((item) {
          if (item.productId == item.productId) {
            return item.copyWith(quantity: newQuantity);
          }
          return item;
        }).toList();

    final updatedTotal = updatedItems.fold(
      0.0,
      (sum, item) => sum + item.price * item.quantity,
    );

    state = state.copyWith(items: updatedItems, total: updatedTotal);
  }
}
