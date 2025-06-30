import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bill.dart';

final billItemsProvider =
    StateNotifierProvider<BillItemsNotifier, List<BillItem>>((ref) {
      return BillItemsNotifier();
    });

class BillItemsNotifier extends StateNotifier<List<BillItem>> {
  BillItemsNotifier() : super([]);

  void addItem(BillItem item) {
    final index = state.indexWhere((e) => e.product == item.product);
    if (index >= 0) {
      final updated = [...state];
      updated[index] = BillItem(
        product: item.product,
        qty: updated[index].qty + item.qty,
        price: item.price,
      );
      state = updated;
    } else {
      state = [...state, item];
    }
  }

  void removeItem(String productName) {
    state = state.where((item) => item.product != productName).toList();
  }

  void clear() {
    state = [];
  }

  void updateItemQty(int index, int newQty) {
    if (index >= 0 && index < state.length && newQty > 0) {
      final item = state[index];
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index)
            BillItem(product: item.product, qty: newQty, price: item.price)
          else
            state[i],
      ];
    }
  }

  double get total =>
      state.fold(0, (sum, item) => sum + (item.price * item.qty));
}

final customerMobileProvider = StateProvider<String>((ref) => '');
