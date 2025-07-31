import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billing/features/models/shop.dart';
import 'package:billing/features/providers/shop_provider.dart';

class ShopDropdown extends ConsumerStatefulWidget {
  final Function(Shop) onSelected;
  final TextEditingController controller;

  const ShopDropdown({
    super.key,
    required this.onSelected,
    required this.controller,
  });

  @override
  ConsumerState<ShopDropdown> createState() => _ShopDropdownState();
}

class _ShopDropdownState extends ConsumerState<ShopDropdown> {
  final TextEditingController _searchController = TextEditingController();
  bool _dropdownOpen = false;
  List<Shop> _filteredShops = [];

  void _filterShops(List<Shop> shopList) {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredShops =
          query.isEmpty
              ? shopList
              : shopList
                  .where((shop) => shop.name.toLowerCase().contains(query))
                  .toList();
    });
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      final shops = ref.read(shopNamesProvider).value;
      if (shops != null) {
        _filterShops(shops);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(shopNamesProvider);
    final selectedShop = ref.watch(selectedShopProvider);

    return shopAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (err, stack) => Text('Error: $err'),
      data: (shopList) {
        // Initial population
        if (_filteredShops.isEmpty) {
          _filteredShops = shopList;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _dropdownOpen = !_dropdownOpen),
              child: AbsorbPointer(
                child: TextField(
                  controller:
                      widget.controller..text = selectedShop?.name ?? '',

                  decoration: InputDecoration(
                    labelText: 'Select Shop',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    suffixIcon: RotatedBox(
                      quarterTurns: 3,
                      child: Icon(Icons.arrow_back_ios_rounded, size: 16),
                    ),
                  ),
                ),
              ),
            ),
            if (_dropdownOpen)
              Container(
                height: MediaQuery.of(context).size.height * 0.4,
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      cursorColor: const Color.fromARGB(255, 2, 113, 192),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search shop...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                          borderSide: BorderSide(
                            color: Color.fromARGB(255, 2, 113, 192),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child:
                          _filteredShops.isEmpty
                              ? const Center(child: Text('No shops found'))
                              : ListView.separated(
                                separatorBuilder:
                                    (_, __) => const Divider(
                                      color: Color.fromARGB(255, 207, 207, 207),
                                    ),
                                itemCount: _filteredShops.length,
                                itemBuilder: (_, index) {
                                  final shop = _filteredShops[index];
                                  return ListTile(
                                    visualDensity: const VisualDensity(
                                      vertical: -4,
                                    ),
                                    title: Text(shop.name),
                                    onTap: () {
                                      widget.controller.text = shop.name;
                                      _dropdownOpen = false;
                                      _searchController.clear();
                                      ref
                                          .read(selectedShopProvider.notifier)
                                          .state = shop;
                                      widget.onSelected(shop);
                                      setState(() {});
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
