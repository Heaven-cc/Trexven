import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/product.dart';
import 'product_detail_screen.dart';
import 'product_provider.dart';

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() =>
      _ProductSearchScreenState();
}

class _ProductSearchScreenState
    extends ConsumerState<ProductSearchScreen> {
  final _searchController = TextEditingController();

  String _query = '';
  Timer? _debounce;

  static const _primaryBlue = Color(0xFF2F66B0);
  static const _background = Color(0xFFF2F2F7);
  static const _primaryText = Color(0xFF1C1C1E);
  static const _secondaryText = Color(0xFF6B6B70);
  static const _separator = Color(0xFFE5E5EA);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Rebuild immediately so the clear button responds instantly.
    setState(() {});

    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 300),
          () {
        if (!mounted) return;

        setState(() {
          _query = value.trim();
        });
      },
    );
  }

  void _clearSearch() {
    _debounce?.cancel();

    setState(() {
      _searchController.clear();
      _query = '';
    });
  }

  Future<void> _refresh() async {
    if (_query.isEmpty) return;

    ref.invalidate(productSearchProvider(_query));
  }

  @override
  Widget build(BuildContext context) {
    final searchResult = ref.watch(productSearchProvider(_query));
    final isSearching = _query.isNotEmpty;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            // Apple-inspired large navigation title.
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Search',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    color: _primaryText,
                  ),
                ),
              ),
            ),

            // Search field.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E3E8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontSize: 16,
                    color: _primaryText,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Products, barcode, part number',
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF8E8E93),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: Color(0xFF8E8E93),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(
                        Icons.cancel_rounded,
                        size: 20,
                        color: Color(0xFF8E8E93),
                      ),
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 13,
                      horizontal: 4,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: !isSearching
                    ? _buildInitialState()
                    : searchResult.when(
                  loading: _buildLoadingState,
                  error: (error, stackTrace) =>
                      _buildErrorState(),
                  data: (products) {
                    if (products.isEmpty) {
                      return _buildNoResultsState();
                    }

                    return RefreshIndicator(
                      color: _primaryBlue,
                      onRefresh: _refresh,
                      child: ListView(
                        key: const ValueKey('search-results'),
                        physics:
                        const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          32,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              4,
                              8,
                              4,
                              10,
                            ),
                            child: Text(
                              '${products.length} ${products.length == 1 ? 'Result' : 'Results'}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _secondaryText,
                              ),
                            ),
                          ),

                          // Grouped results.
                          Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                for (
                                int index = 0;
                                index < products.length;
                                index++
                                ) ...[
                                  _buildProductRow(products[index]),

                                  if (index != products.length - 1)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 82,
                                      ),
                                      child: Divider(
                                        height: 1,
                                        thickness: 0.7,
                                        color: _separator,
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState() {
    return const Center(
      key: ValueKey('initial'),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 52,
              color: Color(0xFF8E8E93),
            ),
            SizedBox(height: 18),
            Text(
              'Search your inventory',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: _primaryText,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Find products by name, barcode, part number, or brand.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: _secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      key: ValueKey('loading'),
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: _primaryBlue,
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      key: const ValueKey('no-results'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: Color(0xFF8E8E93),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Results',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                color: _primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No products match "$_query".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: _secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: _clearSearch,
              child: const Text(
                'Clear Search',
                style: TextStyle(
                  fontSize: 16,
                  color: _primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Color(0xFF8E8E93),
            ),
            const SizedBox(height: 18),
            const Text(
              'Search Unavailable',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: _primaryText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: _secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                ref.invalidate(productSearchProvider(_query));
              },
              child: const Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 16,
                  color: _primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(Product product) {
    final brand = product.brand?.trim();
    final partNumber = product.partNumber?.trim();
    final barcode = product.barcode?.trim();

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ProductDetailScreen(product: product),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FB),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  size: 24,
                  color: _primaryBlue,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                        color: _primaryText,
                      ),
                    ),

                    const SizedBox(height: 4),

                    if (brand != null && brand.isNotEmpty)
                      Text(
                        brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: _secondaryText,
                        ),
                      ),

                    if (partNumber != null && partNumber.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Part #$partNumber',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      )
                    else if (barcode != null && barcode.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          barcode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFFC7C7CC),
              ),
            ],
          ),
        ),
      ),
    );
  }
}