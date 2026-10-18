import '../../services/initial_load_timeout.dart';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/app_sizing.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import 'package:uuid/uuid.dart';
import '../../services/sale_errors.dart';
import 'package:trexven_operations/trexven_operations.dart';

class RecordSaleScreen extends StatefulWidget {
  const RecordSaleScreen({
    super.key,
    this.suggestedProductId,
    this.suggestedQuantity = 1,
    this.database,
  });
  final String? suggestedProductId;
  final int suggestedQuantity;
  final DatabaseService? database;

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen> {
  late final DatabaseService _db;
  late Stream<List<Product>> _products;
  String? _requestId;
  String _paymentMethod = 'cash';

  Product? _selectedProduct;
  num _quantity = 1;
  bool _isLoading = false;
  bool _hasUnconfirmedSale = false;
  bool _pendingRecoveryAvailable = false;
  PaymentDraft? _confirmedPayment;
  String? _shiftId;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? DatabaseService();
    _products = withInitialLoadTimeout(_db.getProductsStream());
    if (widget.suggestedProductId != null) _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    try {
      final products = await _db.getProducts();
      final candidates = products.where(
        (product) => product.id == widget.suggestedProductId,
      );
      if (!mounted) return;
      if (candidates.isEmpty ||
          candidates.first.stock < widget.suggestedQuantity ||
          widget.suggestedQuantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The suggested product or quantity is unavailable. Review current stock.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _selectedProduct = candidates.first;
        _quantity = widget.suggestedQuantity;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Suggested from event evidence. Record only a sale you can confirm.',
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to load the suggested product.'),
          ),
        );
    }
  }

  double get _total {
    if (_selectedProduct == null) return 0;
    // Match PostgreSQL's positive-money rounding using the existing two-place
    // price and three-place quantity precision, without a binary half-cent tie.
    final priceCents = (_selectedProduct!.price * 100).round();
    final milliUnits = (_quantity * 1000).round();
    return ((priceCents * milliUnits + 500) ~/ 1000) / 100;
  }

  void _increaseQuantity() {
    if (_selectedProduct == null) return;

    if (_quantity + 1 > _selectedProduct!.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum available stock reached'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _quantity++;
      _requestId = null;
    });
  }

  void _decreaseQuantity() {
    if (_quantity <= 1) return;

    setState(() {
      _quantity--;
      _requestId = null;
    });
  }

  Future<void> _editQuantity() async {
    final product = _selectedProduct;
    if (product == null || _isLoading || _hasUnconfirmedSale) return;
    final quantity = await showDialog<num>(
      context: context,
      builder: (_) =>
          _SaleQuantityDialog(product: product, quantity: _quantity),
    );
    if (!mounted || quantity == null) return;
    setState(() {
      _quantity = quantity;
      _requestId = null;
    });
  }

  Future<void> _recordSale() async {
    if (_isLoading) return;
    final product = _selectedProduct;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a product first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_hasUnconfirmedSale && product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product is out of stock'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!_hasUnconfirmedSale && _quantity > product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only ${product.stock} ${product.stock == 1 ? 'item' : 'items'} available',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_confirmedPayment == null) {
        _shiftId = null;
        final cash = await _db.saleCashContext();
        final shifts = (cash['shifts'] as List? ?? [])
            .where(
              (row) =>
                  row['status'] == 'open' &&
                  row['joined'] == true &&
                  row['register_active'] == true,
            )
            .toList();
        final cashAllowed = cash['configured'] != true || shifts.isNotEmpty;
        if (cash['configured'] == true && shifts.length == 1) {
          _shiftId = shifts.single['id'] as String;
        } else if (shifts.length > 1) {
          if (!mounted) return;
          _shiftId = await showDialog<String>(
            context: context,
            builder: (context) => SimpleDialog(
              title: const Text('Select your shared register'),
              children: [
                for (final shift in shifts)
                  SimpleDialogOption(
                    onPressed: () =>
                        Navigator.pop(context, shift['id'] as String),
                    child: Text(
                      shift['register_name'] as String? ?? 'Register',
                    ),
                  ),
              ],
            ),
          );
          if (_shiftId == null) return;
        }
        if (!mounted) return;
        _confirmedPayment = await confirmPayment(
          context,
          _total,
          _paymentMethod,
          cashAllowed: cashAllowed,
          allowCredit: false,
        );
        if (_confirmedPayment == null) return;
      }
      final sale = Sale(
        productId: product.id!,
        productName: product.name,
        quantity: _quantity,
        unitPrice: product.price,
        totalPrice: _total,
      );

      _requestId ??= const Uuid().v4();
      final receiptNumber = await _db.recordSale(
        sale,
        requestId: _requestId!,
        paymentMethod: _paymentMethod,
        payments: _confirmedPayment!.payments,
        shiftId: _shiftId,
      );

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      setState(() => _hasUnconfirmedSale = false);
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} sale recorded successfully. Receipt: $receiptNumber',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (e is OwnerOperationRecoveryRequired) {
        _pendingRecoveryAvailable = e.canRecoverHere;
      }
      // A rejection cannot prove that already confirmed money did not move.
      setState(
        () => _hasUnconfirmedSale =
            _confirmedPayment != null ||
            (_requestId != null && saleOutcomeIsUnconfirmed(e)),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saleErrorMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _recoverPreviousOperation() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final receipt = await _db.recoverPendingOperation();
      if (!mounted) return;
      setState(() => _pendingRecoveryAvailable = false);
      final number = receipt is Map ? receipt['sale_number'] : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            number != null
                ? 'Original sale recovered. Receipt: $number'
                : receipt == null
                ? 'No interrupted operation remains.'
                : 'Original operation recovered.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(saleErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _money(double amount) {
    return '₦${amount.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final cardColor = theme.trexvenColors.cardBackground ?? Colors.white;
    final borderColor =
        theme.trexvenColors.border ?? colors.outline.withOpacity(.18);
    final muted =
        theme.trexvenColors.muted ?? colors.onSurface.withOpacity(.60);

    return PopScope(
      canPop: !_isLoading && !_hasUnconfirmedSale,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            onPressed: _isLoading || _hasUnconfirmedSale
                ? null
                : () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 4,
          title: Text(
            'Record sale',
            style: TextStyle(
              fontSize: AppSizing.pageTitle,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: colors.onSurface,
            ),
          ),
        ),
        body: StreamBuilder<List<Product>>(
          stream: _products,
          builder: (context, snapshot) {
            final retainsSale =
                _selectedProduct != null && (_isLoading || _hasUnconfirmedSale);
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData &&
                !retainsSale) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError && !retainsSale) {
              return _ErrorState(
                message: 'Unable to load your products.',
                onRetry: () => setState(
                  () => _products = withInitialLoadTimeout(
                    _db.getProductsStream(),
                  ),
                ),
              );
            }

            final products = List<Product>.of(snapshot.data ?? []);
            // Receipt recovery uses the original confirmed sale even when the
            // live catalogue changes, disappears or is temporarily unavailable.
            if (retainsSale) {
              products.removeWhere((p) => p.id == _selectedProduct!.id);
              products.insert(0, _selectedProduct!);
            }
            // Stream emissions create fresh objects; resolve selection by its ID.
            if (_selectedProduct != null &&
                !_isLoading &&
                !_hasUnconfirmedSale) {
              final matches = products.where(
                (p) => p.id == _selectedProduct!.id,
              );
              _selectedProduct = matches.isEmpty ? null : matches.first;
            }

            if (products.isEmpty) {
              return const _EmptyProductsState();
            }

            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: AppSizing.pagePadding,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Container(
                      key: const ValueKey('record-sale-form'),
                      padding: AppSizing.cardPadding,
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Item',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),

                          const SizedBox(height: 8),

                          _ProductSelector(
                            products: products,
                            selectedProduct: _selectedProduct,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            muted: muted,
                            onChanged: _isLoading || _hasUnconfirmedSale
                                ? null
                                : (product) {
                                    setState(() {
                                      _requestId = null;
                                      _selectedProduct = product;
                                      _quantity = 1;
                                    });
                                  },
                          ),

                          const SizedBox(height: AppSizing.sectionGap),

                          Text(
                            'Quantity',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              _QuantityButton(
                                icon: Icons.remove_rounded,
                                enabled:
                                    !_isLoading &&
                                    !_hasUnconfirmedSale &&
                                    _selectedProduct != null &&
                                    _quantity > 1,
                                borderColor: borderColor,
                                onPressed: _decreaseQuantity,
                              ),

                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    );
                                  },
                                  child: Text(
                                    '$_quantity',
                                    key: ValueKey(_quantity),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 30,
                                      height: 1,
                                      fontWeight: FontWeight.w500,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),

                              _QuantityButton(
                                icon: Icons.add_rounded,
                                enabled:
                                    !_isLoading &&
                                    !_hasUnconfirmedSale &&
                                    _selectedProduct != null &&
                                    _quantity < (_selectedProduct?.stock ?? 0),
                                borderColor: borderColor,
                                onPressed: _increaseQuantity,
                              ),
                            ],
                          ),

                          if (_selectedProduct != null) ...[
                            if (_selectedProduct!.supportsFractionalQuantity)
                              Center(
                                child: TextButton(
                                  onPressed: _isLoading || _hasUnconfirmedSale
                                      ? null
                                      : _editQuantity,
                                  child: Text(
                                    'Enter quantity (${_selectedProduct!.unit})',
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),

                            Center(
                              child: Text(
                                _selectedProduct!.stock > 0
                                    ? '${_selectedProduct!.stock} in stock'
                                    : 'Out of stock',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _selectedProduct!.stock > 0
                                      ? muted
                                      : colors.error,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSizing.sectionGap),

                          Divider(height: 1, color: borderColor),

                          const SizedBox(height: 12),

                          _SummaryRow(
                            label: 'Unit price',
                            value: _selectedProduct == null
                                ? '—'
                                : _money(_selectedProduct!.price),
                            muted: muted,
                            valueColor: colors.onSurface,
                          ),

                          const SizedBox(height: 8),

                          _SummaryRow(
                            label: 'Quantity',
                            value: _selectedProduct == null
                                ? '—'
                                : '× $_quantity',
                            muted: muted,
                            valueColor: colors.onSurface,
                          ),

                          const SizedBox(height: 12),

                          Divider(height: 1, color: borderColor),

                          const SizedBox(height: 12),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                              Flexible(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    _selectedProduct == null
                                        ? '₦0.00'
                                        : _money(_total),
                                    key: ValueKey(_total),
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.7,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSizing.sectionGap),

                          DropdownButtonFormField<String>(
                            initialValue: _paymentMethod,
                            isExpanded: true,
                            itemHeight: null,
                            isDense: false,
                            decoration: const InputDecoration(
                              labelText: 'Payment received by',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'cash',
                                child: Text('Cash'),
                              ),
                              DropdownMenuItem(
                                value: 'card',
                                child: Text('POS Terminal'),
                              ),
                              DropdownMenuItem(
                                value: 'bank_transfer',
                                child: Text('Transfer'),
                              ),
                            ],
                            onChanged: _isLoading || _hasUnconfirmedSale
                                ? null
                                : (value) => setState(() {
                                    _paymentMethod = value!;
                                    _requestId = null;
                                  }),
                          ),
                          const SizedBox(height: AppSizing.sectionGap),

                          if (_hasUnconfirmedSale)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 16),
                              child: Text(
                                'The sale outcome is unconfirmed. Retry the original sale to retrieve its receipt before starting another.',
                              ),
                            ),
                          if (_pendingRecoveryAvailable)
                            OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _recoverPreviousOperation,
                              child: const Text(
                                'Recover interrupted operation',
                              ),
                            ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppSizing.buttonHeight,
                              minWidth: double.infinity,
                            ),
                            child: FilledButton(
                              key: const ValueKey('record-sale-submit'),
                              onPressed:
                                  _selectedProduct == null ||
                                      (!_hasUnconfirmedSale &&
                                          _selectedProduct!.stock <= 0) ||
                                      _isLoading
                                  ? null
                                  : _recordSale,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: colors.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      textAlign: TextAlign.center,
                                      _selectedProduct == null
                                          ? 'Select an item'
                                          : 'Complete sale · ${_money(_total)}',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SaleQuantityDialog extends StatefulWidget {
  final Product product;
  final num quantity;
  const _SaleQuantityDialog({required this.product, required this.quantity});

  @override
  State<_SaleQuantityDialog> createState() => _SaleQuantityDialogState();
}

class _SaleQuantityDialogState extends State<_SaleQuantityDialog> {
  late final controller = TextEditingController(
    text: widget.quantity.toString(),
  );
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void apply() {
    final quantity = num.tryParse(controller.text.trim());
    String? invalid;
    if (quantity == null || !quantity.isFinite || quantity <= 0) {
      invalid = 'Enter a positive quantity.';
    } else if ((quantity * 1000 - (quantity * 1000).round()).abs() >
            0.0000001 ||
        (!widget.product.supportsFractionalQuantity &&
            quantity != quantity.truncate())) {
      invalid =
          'Use whole pieces or up to three decimal places for measurable units.';
    } else if (quantity > widget.product.stock) {
      invalid =
          'Only ${widget.product.stock} ${widget.product.unit} available.';
    }
    if (invalid != null) {
      setState(() => error = invalid);
    } else {
      Navigator.pop(context, quantity);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Quantity in ${widget.product.unit}'),
    content: SingleChildScrollView(
      child: TextField(
        key: const ValueKey('record-sale-quantity-input'),
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.product.supportsFractionalQuantity,
        ),
        decoration: InputDecoration(labelText: 'Quantity', errorText: error),
        onSubmitted: (_) => apply(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: apply, child: const Text('Apply')),
    ],
  );
}

class _ProductSelector extends StatelessWidget {
  final List<Product> products;
  final Product? selectedProduct;
  final Color cardColor;
  final Color borderColor;
  final Color muted;
  final ValueChanged<Product?>? onChanged;

  const _ProductSelector({
    required this.products,
    required this.selectedProduct,
    required this.cardColor,
    required this.borderColor,
    required this.muted,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DropdownButtonFormField<String>(
      key: ValueKey(selectedProduct?.id),
      itemHeight: null,
      isDense: false,
      initialValue: selectedProduct?.id,
      isExpanded: true,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: muted),
      dropdownColor: cardColor,
      borderRadius: BorderRadius.circular(18),
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.colorScheme.surface.withOpacity(.45),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
        ),
      ),
      hint: Text(
        'Choose a product',
        style: TextStyle(color: muted, fontWeight: FontWeight.w500),
      ),
      selectedItemBuilder: (context) {
        return products.map((product) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Tooltip(
              message: product.name,
              child: _SelectedProductContent(product: product, muted: muted),
            ),
          );
        }).toList();
      },
      items: products.map((product) {
        return DropdownMenuItem<String>(
          value: product.id,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                _ProductSwatch(product: product),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '₦${product.price.toStringAsFixed(2)} · ${product.stock} in stock',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: onChanged == null
          ? null
          : (id) => onChanged!(products.firstWhere((p) => p.id == id)),
    );
  }
}

class _SelectedProductContent extends StatelessWidget {
  final Product product;
  final Color muted;

  const _SelectedProductContent({required this.product, required this.muted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ProductSwatch(product: product),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₦${product.price.toStringAsFixed(2)} · ${product.stock} in stock',
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductSwatch extends StatelessWidget {
  final Product product;

  const _ProductSwatch({required this.product});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: primary.withOpacity(.10),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(Icons.inventory_2_outlined, size: 19, color: primary),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color borderColor;
  final VoidCallback onPressed;

  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: AppSizing.quantityTarget,
      height: AppSizing.quantityTarget,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              color: enabled
                  ? colors.surface.withOpacity(.20)
                  : colors.surface.withOpacity(.06),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: enabled
                  ? colors.onSurface
                  : colors.onSurface.withOpacity(.25),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color muted;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.muted,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: muted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: colors.onSurface.withOpacity(.30),
            ),
            const SizedBox(height: 18),
            Text(
              'No products available',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add products to your inventory before recording a sale.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withOpacity(.55),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
