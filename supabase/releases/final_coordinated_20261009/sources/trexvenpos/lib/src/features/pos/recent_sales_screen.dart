import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/sale.dart';
import '../auth/auth_provider.dart';
import 'sales_provider.dart';

class RecentSalesScreen extends ConsumerWidget {
  const RecentSalesScreen({super.key});

  static const Color _primaryBlue = Color(0xFF2F66B0);
  static const Color _lightBlue = Color(0xFFEAF1FB);

  static const Color _background = Color(0xFFF2F2F7);
  static const Color _cardBackground = Colors.white;

  static const Color _primaryText = Color(0xFF1C1C1E);
  static const Color _secondaryText = Color(0xFF6B6B70);
  static const Color _tertiaryText = Color(0xFF8E8E93);

  static const Color _separator = Color(0xFFE5E5EA);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId =
        ref.watch(authStateProvider).employee?.membershipId ?? '';

    if (employeeId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: _background,
        appBar: _buildAppBar(),
        body: _buildNoEmployeeState(),
      );
    }

    final salesAsync = ref.watch(
      recentSalesProvider(employeeId),
    );

    return Scaffold(
      backgroundColor: _background,
      appBar: _buildAppBar(),
      body: salesAsync.when(
        data: (sales) => _buildSalesList(
          context,
          ref,
          employeeId,
          sales,
        ),
        loading: _buildLoadingState,
        error: (error, stackTrace) => _buildErrorState(
          ref,
          employeeId,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: _background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 0,
      iconTheme: const IconThemeData(
        color: _primaryText,
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sale History',
            style: TextStyle(
              color: _primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Authorized business transactions',
            style: TextStyle(
              color: _secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesList(
      BuildContext context,
      WidgetRef ref,
      String employeeId,
      List<Sale> sales,
      ) {
    if (sales.isEmpty) {
      return RefreshIndicator(
        color: _primaryBlue,
        onRefresh: () async {
          ref.invalidate(
            recentSalesProvider(employeeId),
          );

          await ref.read(
            recentSalesProvider(employeeId).future,
          );
        },
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: 500,
              child: _buildEmptyState(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _primaryBlue,
      onRefresh: () async {
        ref.invalidate(
          recentSalesProvider(employeeId),
        );

        await ref.read(
          recentSalesProvider(employeeId).future,
        );
      },
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          32,
        ),
        children: [
          _buildSummaryCard(sales),

          const SizedBox(height: 24),

          const Text(
            'Recent Transactions',
            style: TextStyle(
              color: _primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 12),

          ...sales.map(
                (sale) => _buildSaleCard(
              context: context,
              sale: sale,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      List<Sale> sales,
      ) {
    final totalSales = sales.fold<double>(
      0.0,
          (sum, sale) => sum + sale.total,
    );

    final transactionCount = sales.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              borderRadius:
              BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent sales total',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(totalSales),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$transactionCount transaction${transactionCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaleCard({
    required BuildContext context,
    required Sale sale,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _separator,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius:
          BorderRadius.circular(20),
          onTap: () => _showDetails(
            context,
            sale,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _lightBlue,
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_outlined,
                    color: _primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(sale.timestamp),
                        style: const TextStyle(
                          color: _primaryText,
                          fontSize: 15,
                          fontWeight:
                          FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatTime(sale.timestamp),
                            style: const TextStyle(
                              color: _secondaryText,
                              fontSize: 12,
                            ),
                          ),
                          const Padding(
                            padding:
                            EdgeInsets.symmetric(
                              horizontal: 6,
                            ),
                            child: Text(
                              '•',
                              style: TextStyle(
                                color: _tertiaryText,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _formatPaymentMethod(
                                sale.paymentMethod,
                              ),
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(sale.total),
                      style: const TextStyle(
                        color: _primaryText,
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: _tertiaryText,
                      size: 20,
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: _primaryBlue,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _lightBlue,
                borderRadius:
                BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: _primaryBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No sales yet',
              style: TextStyle(
                color: _primaryText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Completed sales will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoEmployeeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _lightBlue,
                borderRadius:
                BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.person_off_outlined,
                color: _primaryBlue,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Employee not available',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Please sign in again to view your sale history.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
      WidgetRef ref,
      String employeeId,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius:
                BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFB42318),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to load sales',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _primaryText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(
                  recentSalesProvider(employeeId),
                );
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(
      BuildContext context,
      Sale sale,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: _background,
                borderRadius:
                BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _separator,
                      borderRadius:
                      BorderRadius.circular(20),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding:
                      const EdgeInsets.fromLTRB(
                        20,
                        20,
                        20,
                        32,
                      ),
                      children: [
                        const Text(
                          'Sale Details',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 24,
                            fontWeight:
                            FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat(
                            'MMMM dd, yyyy • HH:mm',
                          ).format(sale.timestamp),
                          style: const TextStyle(
                            color: _secondaryText,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailsSummary(sale),
                        const SizedBox(height: 24),
                        const Text(
                          'Items Sold',
                          style: TextStyle(
                            color: _primaryText,
                            fontSize: 18,
                            fontWeight:
                            FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...sale.items
                            .asMap()
                            .entries
                            .map(
                              (entry) =>
                              _buildSaleItemCard(
                                entry.key,
                                entry.value,
                              ),
                        ),
                        const SizedBox(height: 12),
                        _buildTotalCard(sale),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsSummary(
      Sale sale,
      ) {
    final totalQuantity = sale.items.fold<num>(
      0,
          (sum, item) => sum + item.quantity,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _separator,
        ),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            icon: Icons.payments_outlined,
            label: 'Payment Method',
            value: _formatPaymentMethod(
              sale.paymentMethod,
            ),
          ),
          const Divider(
            height: 24,
            color: _separator,
          ),
          _buildSummaryRow(
            icon: Icons.shopping_bag_outlined,
            label: 'Items',
            value: '$totalQuantity item${totalQuantity == 1 ? '' : 's'}',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _lightBlue,
            borderRadius:
            BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: _primaryBlue,
            size: 19,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _secondaryText,
              fontSize: 14,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _primaryText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleItemCard(
      int index,
      SaleItem item,
      ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _separator,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _lightBlue,
              borderRadius:
              BorderRadius.circular(13),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: _primaryBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  _formatPriceLevel(
                    item.priceLevel,
                  ),
                  style: const TextStyle(
                    color: _primaryText,
                    fontSize: 14,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} × ${_formatCurrency(item.unitPrice)}',
                  style: const TextStyle(
                    color: _secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(item.total),
            style: const TextStyle(
              color: _primaryText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(
      Sale sale,
      ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _primaryBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Amount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _formatCurrency(sale.total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: 2,
    ).format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat(
      'MMM dd, yyyy',
    ).format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat(
      'HH:mm',
    ).format(date);
  }

  String _formatPaymentMethod(
      String method,
      ) {
    if (method.trim().isEmpty) {
      return 'Unknown';
    }

    return method
        .split('_')
        .map(
          (word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
        .join(' ');
  }

  String _formatPriceLevel(
      String level,
      ) {
    if (level.trim().isEmpty) {
      return 'Standard';
    }

    return level
        .split('_')
        .map(
          (word) => word.isEmpty
          ? ''
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
        .join(' ');
  }
}
