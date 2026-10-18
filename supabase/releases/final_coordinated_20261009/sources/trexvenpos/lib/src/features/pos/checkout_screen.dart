import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../../services/sale_errors.dart';

import 'cart_provider.dart';
import 'payment_confirmation_dialog.dart';
import 'offline_cash_screen.dart';
import '../../services/offline_cash_queue.dart';
import 'sales_provider.dart';
import 'pending_sale_provider.dart';
import '../../services/pending_sale.dart';
import '../auth/auth_provider.dart';
import '../auth/branch_context.dart';
import '../auth/permission_service.dart';
import '../../models/sale.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final bool offlineCash;
  const CheckoutScreen({super.key, this.offlineCash = false});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const Color _primaryBlue = Color(0xFF2F66B0);

  static const Color _lightBlue = Color(0xFFEAF1FB);

  static const Color _background = Color(0xFFF2F2F7);

  static const Color _cardBackground = Colors.white;

  static const Color _primaryText = Color(0xFF1C1C1E);

  static const Color _secondaryText = Color(0xFF6B6B70);

  static const Color _tertiaryText = Color(0xFF8E8E93);

  static const Color _separator = Color(0xFFE5E5EA);

  static const Color _success = Color(0xFF16794C);

  String _paymentMethod = 'Cash';
  bool _isProcessing = false;
  bool _hasUnconfirmedSale = false;

  Future<void> _completeCheckout() async {
    if (_isProcessing) return;

    final cartItems = ref.read(cartProvider);

    if (cartItems.isEmpty) {
      _showError('Your cart is empty.');
      return;
    }

    final auth = ref.read(authStateProvider);
    if (auth.offlineCashOnly && !widget.offlineCash) {
      _showError('Reconnect and verify access for online checkout.');
      return;
    }

    final business = auth.activeBusiness;

    final employee = auth.employee;

    if (business == null) {
      _showError('No active business is selected.');
      return;
    }

    if (employee == null) {
      _showError('No employee account is currently signed in.');
      return;
    }

    if (!ref.read(permissionServiceProvider).canCompleteSales ||
        employee.businessId != business.id ||
        cartItems.any((item) => item.product.businessId != business.id)) {
      _showError('You do not have permission to complete this sale.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    Sale? recoverySale;
    if (_hasUnconfirmedSale) {
      try {
        final retained = await (await ref.read(
          pendingSaleStoreProvider.future,
        )).read();
        if (retained == null ||
            !retained.belongsTo(
              employee.userId,
              business.id,
              employee.membershipId,
            )) {
          throw StateError(
            'Original employee and retained sale are required for recovery.',
          );
        }
        recoverySale = retained.sale;
        final branch = ref.read(branchContextProvider);
        if (recoverySale.branchId != null &&
            branch?.id != recoverySale.branchId) {
          throw StateError(
            'Select the original authorized branch before recovery.',
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('Request retained: $e');
        }
        return;
      }
    }
    final Sale sale;
    if (recoverySale != null) {
      // Recovery submits the exact flushed payment and request, without asking
      // the cashier to confirm or collect another payment.
      sale = recoverySale;
    } else {
      final total = ref.read(cartProvider.notifier).total;
      String? shiftId;
      var cashAllowed = true;
      try {
        if (widget.offlineCash) {
          final ticket = await (await ref.read(
            offlineCashQueueProvider.future,
          )).ticket();
          shiftId = (ticket?['scope'] as Map?)?['shift_id'] as String?;
        } else {
          final access = await BusinessEntitlements.load(
            OperationsClient.pos(ref.read(supabaseProvider), business.id),
          );
          if (!access.allows('pos'))
            throw StateError(
              'Subscription access has expired. Pending requests and receipts are retained; ask the owner to review billing.',
            );
          final api = OperationsClient.pos(
            ref.read(supabaseProvider),
            business.id,
          );
          final cashContext = await api.cashContext();
          if (!mounted) return;
          shiftId = await chooseCashShift(
            context,
            api,
            allowNoDrawer: true,
            cashContext: cashContext,
          );
          cashAllowed = cashContext['configured'] != true || shiftId != null;
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('$e');
        }
        return;
      }
      if (!mounted) return;
      final draft = await confirmPayment(
        context,
        total,
        _paymentMethod,
        offline: widget.offlineCash,
        cashAllowed: cashAllowed,
      );
      if (draft == null || !mounted) {
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      final afterConfirm = ref.read(authStateProvider);
      if (afterConfirm.employee?.userId != employee.userId ||
          afterConfirm.activeBusiness?.id != business.id) {
        setState(() => _isProcessing = false);
        _showError('Original employee and business required.');
        return;
      }
      final branch = ref.read(branchContextProvider);
      if (business.branchesEnabled &&
          (branch == null || branch.businessId != business.id)) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select an authorized branch before checkout.'),
          ),
        );
        return;
      }
      sale = Sale(
        id: ref.read(cartProvider.notifier).checkoutRequestId,
        businessId: business.id,
        branchId: business.branchesEnabled ? branch!.id : null,
        employeeId: employee.membershipId,
        total: total,
        paymentMethod: widget.offlineCash ? "cash" : _paymentMethod,
        payments: widget.offlineCash ? null : draft.payments,
        credit: draft.credit,
        shiftId: shiftId,
        timestamp: DateTime.now(),
        items: cartItems
            .map(
              (item) => SaleItem(
                productId: item.product.id,
                productName: item.product.name,
                quantity: item.quantity,
                unitPrice: item.selectedPrice,
                discount: item.discount,
                total: item.total,
                priceLevel: item.priceLevel,
              ),
            )
            .toList(),
      );
    }

    PendingSaleStore? store;
    try {
      if (widget.offlineCash) {
        final queue = await ref.read(offlineCashQueueProvider.future);
        final ticket = await queue.ticket();
        if (ticket == null)
          throw StateError('Refresh a signed cash catalog online first.');
        final time = DateTime.now();
        await queue.enqueue(
          OfflineCashEntry(
            sale: sale,
            userId: employee.userId,
            ticket: ticket,
            occurredAt: time,
          ),
          time,
        );
        ref.read(cartProvider.notifier).clear();
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Cash receipt · Pending Sync'),
            content: SelectableText(
              'Request: ${sale.id}\nCash received: ${sale.total}\n' +
                  sale.items
                      .map((i) => '${i.productId} × ${i.quantity}: ${i.total}')
                      .join('\n'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Keep for synchronization'),
              ),
            ],
          ),
        );
        if (mounted) Navigator.pop(context);
        return;
      }
      final resolvedStore = await ref.read(pendingSaleStoreProvider.future);
      store = resolvedStore;
      final completed = await PendingSaleSubmission(resolvedStore).submit(
        userId: employee.userId,
        sale: sale,
        send: ref.read(salesRepositoryProvider).completeSale,
      );

      if (!mounted) return;
      final current = ref.read(authStateProvider);
      if (current.employee?.userId != employee.userId ||
          current.employee?.membershipId != employee.membershipId ||
          current.activeBusiness?.id != business.id) {
        ref.invalidate(pendingSaleProvider);
        throw StateError(
          'Sign in with the original employee and business to recover this sale.',
        );
      }
      setState(() => _hasUnconfirmedSale = false);

      ref.read(cartProvider.notifier).clear();
      ref.invalidate(recentSalesProvider(employee.membershipId));

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Sale receipt'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('Receipt: ${completed.id}'),
                Text('Payment: ${completed.paymentMethod}'),
                for (final item in completed.items)
                  Text(
                    '${item.productName} × ${item.quantity}: ${_formatPrice(item.total)}',
                  ),
                Text('Total: ${_formatPrice(completed.total)}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      final acknowledging = ref.read(authStateProvider);
      if (acknowledging.employee?.userId != employee.userId ||
          acknowledging.employee?.membershipId != employee.membershipId ||
          acknowledging.activeBusiness?.id != business.id) {
        ref.invalidate(pendingSaleProvider);
        throw StateError(
          'The original employee must acknowledge this receipt.',
        );
      }
      await resolvedStore.acknowledge(sale.id);
      ref.invalidate(pendingSaleProvider);
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _success,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Sale completed successfully.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      final pendingRemains = store != null && await store.read() != null;
      if (!mounted) return;
      setState(() => _hasUnconfirmedSale = pendingRemains);

      _showError(saleErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFB42318),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    return '₦${price.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    final cartNotifier = ref.read(cartProvider.notifier);

    final total = cartNotifier.total;

    final itemCount = cartNotifier.itemCount;

    return PopScope(
      canPop: !_isProcessing && !_hasUnconfirmedSale,
      child: Scaffold(
        backgroundColor: _background,

        appBar: AppBar(
          leading: IconButton(
            onPressed: _isProcessing || _hasUnconfirmedSale
                ? null
                : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          elevation: 0,
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          iconTheme: const IconThemeData(color: _primaryText),
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checkout',
                style: TextStyle(
                  color: _primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Review and complete sale',
                style: TextStyle(color: _secondaryText, fontSize: 12),
              ),
            ],
          ),
        ),

        body: SafeArea(
          top: false,
          child: cart.isEmpty
              ? _buildEmptyCart()
              : Column(
                  children: [
                    Expanded(child: _buildCartContent(cart, itemCount)),

                    if (_hasUnconfirmedSale)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'The sale outcome is unconfirmed. Retry the original sale to retrieve its receipt before starting another.',
                        ),
                      ),
                    _buildCheckoutBottom(total),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCartContent(List<CartItem> cart, num itemCount) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        _buildSummaryHeader(itemCount, cart.length),

        const SizedBox(height: 16),

        ...cart.map((item) => _buildCartItem(item)),
      ],
    );
  }

  Widget _buildSummaryHeader(num itemCount, int uniqueItems) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _lightBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: _primaryBlue),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    color: _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'} • $uniqueItems ${uniqueItems == 1 ? 'product' : 'products'}',
                  style: const TextStyle(color: _secondaryText, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _separator),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductThumbnail(item),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _priceLevelName(item.priceLevel),
                  style: const TextStyle(
                    color: _primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '${_formatPrice(item.selectedPrice)} each',
                  style: const TextStyle(color: _secondaryText, fontSize: 12),
                ),

                const SizedBox(height: 12),

                _buildQuantityControls(item),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatPrice(item.total),
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              IconButton(
                onPressed: _isProcessing || _hasUnconfirmedSale
                    ? null
                    : () {
                        ref
                            .read(cartProvider.notifier)
                            .removeProduct(item.product.id, item.priceLevel);
                      },
                tooltip: 'Remove item',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: _tertiaryText,
                  size: 21,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductThumbnail(CartItem item) {
    final imageUrl = item.product.imageUrl;

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: _tertiaryText,
          size: 27,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        imageUrl,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 58,
            height: 58,
            color: _background,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: _tertiaryText,
              size: 25,
            ),
          );
        },
      ),
    );
  }

  Future<void> _editQuantity(CartItem item) async {
    final controller = TextEditingController(text: item.quantity.toString());
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quantity in ${item.product.unit}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(
            decimal: item.product.supportsFractionalQuantity,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    try {
      final quantity = num.tryParse(result);
      if (quantity == null || quantity <= 0)
        throw const FormatException('Enter a positive quantity.');
      ref
          .read(cartProvider.notifier)
          .updateQuantity(item.product.id, item.priceLevel, quantity);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _editTerms(CartItem item) async {
    final access = ref.read(permissionServiceProvider);
    if (widget.offlineCash ||
        (!access.canOverridePrice && !access.canApplyDiscount))
      return;
    final price = TextEditingController(
      text: item.selectedPrice.toStringAsFixed(2),
    );
    final discount = TextEditingController(
      text: item.discount.toStringAsFixed(2),
    );
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Authorized sale terms'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: price,
              enabled: access.canOverridePrice,
              decoration: const InputDecoration(
                labelText: 'Selling-price override',
              ),
            ),
            TextField(
              controller: discount,
              enabled: access.canApplyDiscount,
              decoration: const InputDecoration(
                labelText: 'Total line discount',
              ),
            ),
            const Text(
              'Backend permissions and price/discount limits are checked again at checkout.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (applied == true && mounted) {
      try {
        ref
            .read(cartProvider.notifier)
            .updateTerms(
              item.product.id,
              item.priceLevel,
              double.parse(price.text),
              double.parse(discount.text),
            );
      } catch (e) {
        _showError(e.toString());
      }
    }
    price.dispose();
    discount.dispose();
  }

  Widget _buildQuantityControls(CartItem item) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.offlineCash &&
              (ref.watch(permissionServiceProvider).canApplyDiscount ||
                  ref.watch(permissionServiceProvider).canOverridePrice))
            _quantityButton(
              icon: Icons.percent,
              onPressed: _isProcessing || _hasUnconfirmedSale
                  ? null
                  : () => _editTerms(item),
            ),
          _quantityButton(
            icon: Icons.remove_rounded,
            onPressed: _isProcessing || _hasUnconfirmedSale
                ? null
                : () {
                    ref
                        .read(cartProvider.notifier)
                        .decrement(item.product.id, item.priceLevel);
                  },
          ),

          InkWell(
            onTap: _isProcessing || _hasUnconfirmedSale
                ? null
                : () => _editQuantity(item),
            child: SizedBox(
              width: 52,
              child: Center(
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    color: _primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          _quantityButton(
            icon: Icons.add_rounded,
            onPressed: _isProcessing || _hasUnconfirmedSale
                ? null
                : () {
                    ref
                        .read(cartProvider.notifier)
                        .increment(item.product.id, item.priceLevel);
                  },
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: _primaryText),
      ),
    );
  }

  String _priceLevelName(String level) {
    if (level.isEmpty) {
      return 'Price';
    }

    return level
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  Widget _buildCheckoutBottom(double total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: _cardBackground,
        border: const Border(top: BorderSide(color: _separator)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildPaymentMethod(),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: _secondaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatPrice(total),
                style: const TextStyle(
                  color: _primaryText,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _completeCheckout,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFB8C7DD),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 21),
                        SizedBox(width: 9),
                        Text(
                          'Complete Sale',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Method',
          style: TextStyle(
            color: _primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _paymentOption(
                label: 'Cash',
                icon: Icons.payments_outlined,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _paymentOption(
                label: 'POS Terminal',
                icon: Icons.point_of_sale_outlined,
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: _paymentOption(
                label: 'Transfer',
                icon: Icons.account_balance_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paymentOption({required String label, required IconData icon}) {
    if (widget.offlineCash && label != 'Cash') return const SizedBox.shrink();
    final selected = _paymentMethod == label;

    return GestureDetector(
      onTap: _isProcessing || _hasUnconfirmedSale
          ? null
          : () {
              setState(() {
                _paymentMethod = label;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _lightBlue : _background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _primaryBlue : _separator,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? _primaryBlue : _secondaryText,
            ),

            const SizedBox(height: 5),

            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? _primaryBlue : _secondaryText,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _lightBlue,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: _primaryBlue,
                size: 38,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Your cart is empty',
              style: TextStyle(
                color: _primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Scan a barcode or search for a product to start a sale.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Back to POS',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
