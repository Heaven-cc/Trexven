import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'product_provider.dart';
import 'catalog_edit_screen.dart';
import '../auth/permission_service.dart';
import '../auth/auth_provider.dart';
import '../pos/cart_provider.dart';
import '../../models/product.dart';
import '../../models/price_levels.dart';

class ProductDetailScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  static const Color _primaryBlue =
  Color(0xFF2F66B0);

  static const Color _lightBlue =
  Color(0xFFEAF1FB);

  static const Color _background =
  Color(0xFFF2F2F7);

  static const Color _cardBackground =
      Colors.white;

  static const Color _primaryText =
  Color(0xFF1C1C1E);

  static const Color _secondaryText =
  Color(0xFF6B6B70);

  static const Color _tertiaryText =
  Color(0xFF8E8E93);

  static const Color _separator =
  Color(0xFFE5E5EA);

  @override
  Widget build(
      BuildContext context,
      WidgetRef ref,
      ) {
    final priceLevelsAsync =
    ref.watch(
      productPriceLevelsProvider(
        product.id,
      ),
    );

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        actions:[if(ref.watch(permissionServiceProvider).canManageInventory)
          IconButton(tooltip:'Edit product',icon:const Icon(Icons.edit),onPressed:() =>
            _editProduct(context,ref))],
        elevation: 0,
        backgroundColor: _background,
        surfaceTintColor:
        Colors.transparent,
        centerTitle: false,
        titleSpacing: 0,
        iconTheme:
        const IconThemeData(
          color: _primaryText,
        ),
        title: const Text(
          'Product',
          style: TextStyle(
            color: _primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: priceLevelsAsync.when(
        data: (levels) =>
            _buildContent(
              context,
              ref,
              levels,
            ),
        loading: () =>
        const Center(
          child: CircularProgressIndicator(
            color: _primaryBlue,
          ),
        ),
        error: (error, stackTrace) =>
            _buildErrorState(
              context,
              error,
            ),
      ),
    );
  }

  Future<void> _editProduct(BuildContext context,WidgetRef ref) async {
    final changed = await Navigator.push<bool>(context,MaterialPageRoute(builder:(_) => CatalogEditScreen(product:product)));
    if(changed != true || !context.mounted) return;
    ref.invalidate(productSearchProvider);
    ref.invalidate(productPriceLevelsProvider(product.id));
    Navigator.pop(context);
  }
  Widget _buildContent(
      BuildContext context,
      WidgetRef ref,
      PriceLevels? levels,
      ) {
    return SafeArea(
      top: false,
      child: ListView(
        padding:
        const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          32,
        ),
        children: [
          _buildProductHeader(),

          const SizedBox(height: 24),

          _buildProductInformation(),

          const SizedBox(height: 28),

          _buildPriceSection(
            context,
            ref,
            levels,
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius:
        BorderRadius.circular(24),
        border: Border.all(
          color: _separator,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildProductImage(),

          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20,
            ),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                if (product.brand != null &&
                    product.brand!
                        .trim()
                        .isNotEmpty)
                  Text(
                    product.brand!
                        .trim()
                        .toUpperCase(),
                    style:
                    const TextStyle(
                      color: _primaryBlue,
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),

                const SizedBox(height: 6),

                Text(
                  product.name,
                  style:
                  const TextStyle(
                    color: _primaryText,
                    fontSize: 24,
                    fontWeight:
                    FontWeight.w700,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),

                const SizedBox(height: 12),

                _buildStatusBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage() {
    if (product.imageUrl == null ||
        product.imageUrl!
            .trim()
            .isEmpty) {
      return Container(
        height: 210,
        width: double.infinity,
        color: _background,
        child: const Center(
          child: Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: _tertiaryText,
          ),
        ),
      );
    }

    return SizedBox(
      height: 210,
      width: double.infinity,
      child: Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) {
          return Container(
            color: _background,
            child: const Center(
              child: Icon(
                Icons
                    .image_not_supported_outlined,
                size: 52,
                color:
                _tertiaryText,
              ),
            ),
          );
        },
        loadingBuilder:
            (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return Container(
            color: _background,
            child: const Center(
              child:
              CircularProgressIndicator(
                color: _primaryBlue,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge() {
    final isPending =
        product.status ==
            ProductStatus.pending;

    final backgroundColor =
    isPending
        ? const Color(0xFFFFF4E5)
        : const Color(0xFFEAF7EF);

    final foregroundColor =
    isPending
        ? const Color(0xFF9A6700)
        : const Color(0xFF16794C);

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 7,
      ),
      decoration:
      BoxDecoration(
        color: backgroundColor,
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            isPending
                ? Icons.pending_outlined
                : Icons.check_circle_outline,
            size: 15,
            color:
            foregroundColor,
          ),
          const SizedBox(width: 6),
          Text(
            isPending
                ? 'Pending price'
                : product.isInactive ? 'Archived' : 'Active',
            style: TextStyle(
              color:
              foregroundColor,
              fontSize: 12,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInformation() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Information',
          style: TextStyle(
            color: _primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),

        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: _cardBackground,
            borderRadius:
            BorderRadius.circular(20),
            border: Border.all(
              color: _separator,
            ),
          ),
          child: Column(
            children: [
              if (product.barcode != null)
                _buildInfoRow(
                  icon:
                  Icons.qr_code_2_outlined,
                  label: 'Barcode',
                  value:
                  product.barcode!,
                ),

              _buildDivider(),

              _buildInfoRow(
                icon:
                Icons.tag_outlined,
                label: 'Part Number',
                value:
                product.partNumber
                    ?.trim()
                    .isNotEmpty ==
                    true
                    ? product.partNumber!
                    : 'Not specified',
              ),

              _buildDivider(),

              _buildInfoRow(
                icon:
                Icons.workspace_premium_outlined,
                label: 'Brand',
                value:
                product.brand
                    ?.trim()
                    .isNotEmpty ==
                    true
                    ? product.brand!
                    : 'Not specified',
              ),

              if (product.category != null &&
                  product.category!
                      .trim()
                      .isNotEmpty) ...[
                _buildDivider(),
                _buildInfoRow(
                  icon:
                  Icons.category_outlined,
                  label: 'Category',
                  value:
                  product.category!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
            BoxDecoration(
              color: _lightBlue,
              borderRadius:
              BorderRadius.circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: _primaryBlue,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                  const TextStyle(
                    color:
                    _tertiaryText,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  overflow:
                  TextOverflow.ellipsis,
                  style:
                  const TextStyle(
                    color:
                    _primaryText,
                    fontSize: 15,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 66,
      endIndent: 16,
      color: _separator,
    );
  }

  Widget _buildPriceSection(
      BuildContext context,
      WidgetRef ref,
      PriceLevels? levels,
      ) {
    if (!ref.watch(permissionServiceProvider).canCompleteSales) {
      return const Text('Product information only. You do not have permission to create sales.');
    }
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Price',
          style: TextStyle(
            color: _primaryText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),

        const SizedBox(height: 5),

        const Text(
          'Choose the price to use for this sale.',
          style: TextStyle(
            color: _secondaryText,
            fontSize: 13,
          ),
        ),

        const SizedBox(height: 14),

        if (levels == null)
          _buildNoPricesState()
        else ...[
          _buildPriceCard(
            context: context,
            ref: ref,
            label: 'Standard',
            price: levels.standard,
            icon:
            Icons.sell_outlined,
            isRecommended: true,
          ),

        ],
      ],
    );
  }

  Widget _buildNoPricesState() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: _separator,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration:
            BoxDecoration(
              color: _background,
              borderRadius:
              BorderRadius.circular(
                17,
              ),
            ),
            child: const Icon(
              Icons
                  .price_change_outlined,
              color: _tertiaryText,
              size: 28,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'No price information',
            style: TextStyle(
              color: _primaryText,
              fontSize: 16,
              fontWeight:
              FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Price levels have not been configured for this product yet.',
            textAlign:
            TextAlign.center,
            style: TextStyle(
              color: _secondaryText,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard({
    required BuildContext context,
    required WidgetRef ref,
    required String label,
    required double price,
    required IconData icon,
    String? subtitle,
    bool isRecommended = false,
  }) {
    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended
              ? _primaryBlue
              .withValues(
            alpha: 0.35,
          )
              : _separator,
          width:
          isRecommended ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
          BorderRadius.circular(
            20,
          ),
          onTap: () =>
              _addToCart(
                context,
                ref,
                label,
                price,
              ),
          child: Padding(
            padding:
            const EdgeInsets.all(
              16,
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                  BoxDecoration(
                    color: _lightBlue,
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color:
                    _primaryBlue,
                    size: 22,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Row(
                        children: [
                          Text(
                            label,
                            style:
                            const TextStyle(
                              color:
                              _primaryText,
                              fontSize:
                              15,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),

                          if (isRecommended) ...[
                            const SizedBox(
                              width: 7,
                            ),
                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration:
                              BoxDecoration(
                                color:
                                _lightBlue,
                                borderRadius:
                                BorderRadius
                                    .circular(
                                  8,
                                ),
                              ),
                              child:
                              const Text(
                                'DEFAULT',
                                style:
                                TextStyle(
                                  color:
                                  _primaryBlue,
                                  fontSize:
                                  9,
                                  fontWeight:
                                  FontWeight
                                      .w800,
                                  letterSpacing:
                                  0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      if (subtitle != null &&
                          subtitle
                              .trim()
                              .isNotEmpty) ...[
                        const SizedBox(
                          height: 4,
                        ),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            color:
                            _secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .end,
                  children: [
                    Text(
                      _formatPrice(
                        price,
                      ),
                      style:
                      const TextStyle(
                        color:
                        _primaryText,
                        fontSize: 17,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    const Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        Text(
                          'Add',
                          style:
                          TextStyle(
                            color:
                            _primaryBlue,
                            fontSize:
                            12,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                        SizedBox(
                          width: 3,
                        ),
                        Icon(
                          Icons
                              .chevron_right_rounded,
                          color:
                          _primaryBlue,
                          size: 17,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatPrice(
      double price,
      ) {
    return '₦${price.toStringAsFixed(2)}';
  }

  void _addToCart(
      BuildContext context,
      WidgetRef ref,
      String label,
      double price,
      ) {
    final auth = ref.read(authStateProvider);
    if (!ref.read(permissionServiceProvider).canCompleteSales ||
        product.businessId != auth.activeBusiness?.id ||
        auth.employee?.businessId != auth.activeBusiness?.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot create a sale for this product.')),
      );
      return;
    }
    ref
        .read(cartProvider.notifier)
        .addProduct(
      product,
      price,
      label.toLowerCase(),
    );

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
        SnackBarBehavior.floating,
        backgroundColor:
        _primaryText,
        shape:
        RoundedRectangleBorder(
          borderRadius:
          BorderRadius.circular(
            14,
          ),
        ),
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label price added to cart',
                style:
                const TextStyle(
                  color: Colors.white,
                  fontWeight:
                  FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Navigator.pop(context);
  }

  Widget _buildErrorState(
      BuildContext context,
      Object error,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(30),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration:
              BoxDecoration(
                color:
                const Color(
                  0xFFFFEBEB,
                ),
                borderRadius:
                BorderRadius.circular(
                  20,
                ),
              ),
              child: const Icon(
                Icons
                    .error_outline_rounded,
                color:
                Color(0xFFB42318),
                size: 32,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Unable to load prices',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: _primaryText,
                fontSize: 18,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'There was a problem loading the price information for this product.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                _secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                // Riverpod will rebuild this
                // screen when the provider
                // is refreshed externally.
                Navigator.pop(context);
              },
              style:
              ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                _primaryBlue,
                foregroundColor:
                Colors.white,
                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    14,
                  ),
                ),
              ),
              child: const Text(
                'Go Back',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
