import 'package:trexven_design_system/trexven_design_system.dart';
import '../../services/initial_load_timeout.dart';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';
import 'package:uuid/uuid.dart';
import '../../services/sale_errors.dart';
import 'package:trexven_operations/trexven_operations.dart';
import '../inventory/scanner_screen.dart';

/// One confirmed cart uses the existing atomic transaction RPC.
typedef SubmitCartSale =
    Future<String> Function({
      required String requestId,
      required List<Map<String, dynamic>> items,
      required List<Map<String, dynamic>> payments,
      required double total,
      Map<String, dynamic>? credit,
      String? shiftId,
    });

class RecordSaleScreen extends StatefulWidget {
  const RecordSaleScreen({
    super.key,
    this.suggestedProductId,
    this.suggestedQuantity = 1,
    this.database,
    this.submitCartSale,
  });
  final String? suggestedProductId;
  final int suggestedQuantity;
  final DatabaseService? database;
  final SubmitCartSale? submitCartSale;

  @override
  State<RecordSaleScreen> createState() => _RecordSaleScreenState();
}

class _RecordSaleScreenState extends State<RecordSaleScreen> {
  late final DatabaseService _db;
  late Stream<List<Product>> _products;
  String? _requestId;
  String _paymentMethod = 'cash';

  Product? _selectedProduct;
  final Map<String, _CartLine> _cart = {};
  final Set<String> _unavailableProducts = {};
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
          SnackBar(
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
        if (candidates.first.id != null) {
          _cart[candidates.first.id!] = _CartLine(candidates.first, _quantity);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Suggested from event evidence. Record only a sale you can confirm.',
          ),
        ),
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load the suggested product.')),
        );
    }
  }

  double get _singleTotal {
    if (_selectedProduct == null) return 0;
    // Match PostgreSQL's positive-money rounding using the existing two-place
    // price and three-place quantity precision, without a binary half-cent tie.
    final priceCents = (_selectedProduct!.price * 100).round();
    final milliUnits = (_quantity * 1000).round();
    return ((priceCents * milliUnits + 500) ~/ 1000) / 100;
  }

  double get _total {
    if (_cart.isEmpty) return _singleTotal;
    var cents = 0;
    for (final line in _cart.values) {
      final priceCents = (line.product.price * 100).round();
      final milliUnits = (line.quantity * 1000).round();
      cents += (priceCents * milliUnits + 500) ~/ 1000;
    }
    return cents / 100;
  }

  void _addProduct(Product product) {
    if (_isLoading || _hasUnconfirmedSale) return;
    if (product.id == null ||
        product.stock <= 0 ||
        !product.active ||
        product.isPricePending)
      return;
    setState(() {
      final existing = _cart[product.id];
      if (existing == null) {
        _cart[product.id!] = _CartLine(
          product,
          product.supportsFractionalQuantity && product.stock < 1
              ? product.stock
              : 1,
        );
      } else if (existing.quantity + 1 <= product.stock) {
        existing.quantity += 1;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum available stock reached')),
        );
      }
      _selectedProduct = _cart.values.first.product;
      _quantity = _cart.values.first.quantity;
      _requestId = null;
      _confirmedPayment = null;
      _shiftId = null;
    });
  }

  void _changeCartQuantity(String id, num delta) {
    final line = _cart[id];
    if (line == null || _isLoading || _hasUnconfirmedSale) return;
    final next = line.quantity + delta;
    if (next < 1 || next > line.product.stock) return;
    setState(() {
      line.quantity = next;
      _selectedProduct = _cart.values.first.product;
      _quantity = _cart.values.first.quantity;
      _requestId = null;
      _confirmedPayment = null;
      _shiftId = null;
    });
  }

  void _removeCartProduct(String id) {
    if (_isLoading || _hasUnconfirmedSale) return;
    setState(() {
      _cart.remove(id);
      _selectedProduct = _cart.isEmpty ? null : _cart.values.first.product;
      _quantity = _cart.isEmpty ? 1 : _cart.values.first.quantity;
      _requestId = null;
      _confirmedPayment = null;
      _shiftId = null;
    });
  }

  Future<void> _selectProduct(List<Product> products) async {
    if (_isLoading || _hasUnconfirmedSale) return;
    final chosen = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SearchProductSheet(products: products),
    );
    if (chosen != null && mounted) _addProduct(chosen);
  }

  void _increaseQuantity() {
    if (_selectedProduct == null) return;

    if (_quantity + 1 > _selectedProduct!.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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

  Future<void> _editQuantity(String id) async {
    final line = _cart[id];
    if (line == null || _isLoading || _hasUnconfirmedSale) return;
    final quantity = await showDialog<num>(
      context: context,
      builder: (_) =>
          _SaleQuantityDialog(product: line.product, quantity: line.quantity),
    );
    if (!mounted || quantity == null) return;
    setState(() {
      line.quantity = quantity;
      _quantity = _cart.values.first.quantity;
      _requestId = null;
      _confirmedPayment = null;
    });
  }

  Future<void> _recordSale() async {
    if (_isLoading) return;
    final product = _selectedProduct;

    if (product == null || _cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select a product first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    for (final line in _cart.values) {
      if (!_hasUnconfirmedSale &&
          (line.quantity <= 0 ||
              line.quantity > line.product.stock ||
              !line.product.active ||
              line.product.isPricePending ||
              _unavailableProducts.contains(line.product.id))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check the quantity and available stock for every product.',
            ),
          ),
        );
        return;
      }
    }
    if (!_hasUnconfirmedSale && product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
        final cash = await _db.saleCashContext().timeout(
          const Duration(seconds: 20),
        );
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
              title: Text('Select your shared register'),
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
          businessDate: cash['local_date'] == null
              ? null
              : DateTime.parse(cash['local_date'] as String),
        );
        if (_confirmedPayment == null) return;
      }
      _requestId ??= const Uuid().v4();
      final submit = widget.submitCartSale ?? _db.recordCartSale;
      Future<String> send() => submit(
        requestId: _requestId!,
        items: _cart.values
            .map(
              (line) => <String, dynamic>{
                'product_id': line.product.id,
                'quantity': line.quantity,
                'unit_price': line.product.price,
                'discount': 0,
              },
            )
            .toList(),
        payments: _confirmedPayment!.payments,
        credit: _confirmedPayment!.credit,
        total: _total,
        shiftId: _shiftId,
      );
      String receiptNumber;
      try {
        receiptNumber = await send();
      } on CreditApprovalRequired catch (approval) {
        if (!mounted) rethrow;
        final approved = await _reviewCredit(approval.approvalId);
        if (!approved) rethrow;
        receiptNumber = await send();
      }

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
      // Once confirmation has been collected, keep the original cart/payment
      // intent even after a server rejection. The durable journal controls recovery.
      final unconfirmed = _requestId != null && _confirmedPayment != null;
      if (!unconfirmed) {
        _confirmedPayment = null;
      }
      setState(() => _hasUnconfirmedSale = unconfirmed);

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

  Future<bool> _reviewCredit(String approvalId) async {
    final debtor = _confirmedPayment?.credit;
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => TextControllerScope(
        controllers: [reason],
        child: AlertDialog(
          title: const Text('Review credit approval'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${debtor?['debtor_name']} · ${debtor?['contact']}\nDue: ${debtor?['due_date']}',
                ),
                Text(
                  'Sale: ${_money(_total)}\nPaid now: ${_money(_confirmedPayment!.payments.fold<double>(0, (sum, p) => sum + (p['amount'] as num).toDouble()))}',
                ),
                for (final line in _cart.values)
                  Text(
                    '${line.product.name}: ${line.quantity} × ${_money(line.product.price)}',
                  ),
                const Text(
                  'Approve this exact cart and its unpaid balance. Credit limits remain enforced.',
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(
                    labelText: 'Optional owner over-limit exception reason',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Leave pending'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, reason.text.trim()),
              child: const Text('Approve credit'),
            ),
          ],
        ),
      ),
    );
    if (value == null) return false;
    await _db.approveCartCredit(
      approvalId,
      overLimitReason: value.isEmpty ? null : value,
    );
    return true;
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

  Color get _background => Theme.of(context).scaffoldBackgroundColor;
  Color get _navy => Theme.of(context).colorScheme.onSurface;
  Color get _blue => Theme.of(context).colorScheme.primary;
  Color get _muted => Theme.of(context).trexvenColors.muted ?? Theme.of(context).colorScheme.onSurfaceVariant;
  Color get _softBlue => Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      label,
      style: TextStyle(
        color: _navy,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _surface({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = Theme.of(context).trexvenColors.border ?? Theme.of(context).colorScheme.outlineVariant;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }

  Widget _detailRow(String label, String value, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: strong ? _navy : _muted,
                  fontSize: strong ? 15 : 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: strong ? _blue : _navy,
                  fontSize: strong ? 20 : 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLoading && !_hasUnconfirmedSale,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: _isLoading || _hasUnconfirmedSale
                ? null
                : () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: _navy),
          ),
          title: Text(
            'Record sale',
            style: TextStyle(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: StreamBuilder<List<Product>>(
          stream: _products,
          builder: (context, snapshot) {
            final retainsSale =
                _selectedProduct != null &&
                (_isLoading ||
                    _hasUnconfirmedSale ||
                    _confirmedPayment != null);
            if (!snapshot.hasData &&
                snapshot.connectionState == ConnectionState.waiting &&
                !retainsSale) {
              return const TrexvenSkeleton(kind: TrexvenSkeletonKind.checkout);
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
            if (retainsSale) {
              products.removeWhere((p) => p.id == _selectedProduct!.id);
              products.insert(0, _selectedProduct!);
            }
            if (_cart.isNotEmpty &&
                !_isLoading &&
                !_hasUnconfirmedSale &&
                _confirmedPayment == null) {
              for (final entry in _cart.entries.toList()) {
                final current = products
                    .where((p) => p.id == entry.key)
                    .firstOrNull;
                if (current != null) {
                  _cart[entry.key] = _CartLine(current, entry.value.quantity);
                  _unavailableProducts.remove(entry.key);
                } else {
                  _unavailableProducts.add(entry.key);
                }
              }
              _selectedProduct = _cart.values.first.product;
            }
            if (products.isEmpty) return const _EmptyProductsState();

            final locked = _isLoading || _hasUnconfirmedSale;
            final product = _selectedProduct;
            return SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Column(
                      key: const ValueKey('record-sale-form'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Products'),
                              InkWell(
                                onTap: locked
                                    ? null
                                    : () => _selectProduct(products),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.search, color: _muted),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Search or select products',
                                          style: TextStyle(color: _muted),
                                        ),
                                      ),
                                      Icon(
                                        Icons.add_circle_outline,
                                        color: _blue,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (final entry in _cart.entries) ...[
                                const Divider(color: Color(0xFFE9EDF4)),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        entry.value.product.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _navy,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: locked
                                          ? null
                                          : () => _removeCartProduct(entry.key),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Color(0xFFB65A5A),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  _money(entry.value.product.price),
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                                Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: locked
                                              ? null
                                              : () => _changeCartQuantity(
                                                  entry.key,
                                                  -1,
                                                ),
                                          icon: const Icon(Icons.remove),
                                        ),
                                        TextButton(
                                          key: ValueKey(
                                            'quantity-${entry.key}',
                                          ),
                                          onPressed: locked
                                              ? null
                                              : () => _editQuantity(entry.key),
                                          child: Text(
                                            '${entry.value.quantity}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: locked
                                              ? null
                                              : () => _changeCartQuantity(
                                                  entry.key,
                                                  1,
                                                ),
                                          icon: Icon(
                                            Icons.add,
                                            color: _blue,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      _money(
                                        (((entry.value.product.price * 100)
                                                            .round() *
                                                        (entry.value.quantity *
                                                                1000)
                                                            .round() +
                                                    500) ~/
                                                1000) /
                                            100,
                                      ),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _navy,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              TextButton.icon(
                                onPressed: locked
                                    ? null
                                    : () => _selectProduct(products),
                                icon: const Icon(Icons.add_circle_outline),
                                label: const Text('Add another product'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 13),
                        _surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Sale summary'),
                              _detailRow('Products', '${_cart.length}'),
                              _detailRow(
                                'Total quantity',
                                '${_cart.values.fold<num>(0, (sum, line) => sum + line.quantity)}',
                              ),
                              const Divider(color: Color(0xFFE9EDF4)),
                              _detailRow(
                                'Grand Total',
                                _money(_total),
                                strong: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 13),
                        _surface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel('Payment method'),
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                mainAxisExtent:
                                    70 *
                                    MediaQuery.textScalerOf(
                                      context,
                                    ).scale(1).clamp(1, 2),
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                children: [
                                  for (final method in const [
                                    ('cash', 'Cash', Icons.payments_outlined),
                                    ('card', 'Terminal', Icons.credit_card),
                                    (
                                      'bank_transfer',
                                      'Transfer',
                                      Icons.account_balance,
                                    ),
                                    (
                                      'credit',
                                      'Credit',
                                      Icons.handshake_outlined,
                                    ),
                                  ])
                                    InkWell(
                                      onTap: locked
                                          ? null
                                          : () => setState(() {
                                              _paymentMethod = method.$1;
                                              _requestId = null;
                                              _confirmedPayment = null;
                                              _shiftId = null;
                                            }),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _paymentMethod == method.$1
                                              ? _softBlue
                                              : _background,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: _paymentMethod == method.$1
                                                ? _blue
                                                : Colors.transparent,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              method.$3,
                                              color: _paymentMethod == method.$1
                                                  ? _blue
                                                  : _muted,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              method.$2,
                                              style: TextStyle(
                                                color:
                                                    _paymentMethod == method.$1
                                                    ? _blue
                                                    : _navy,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (_paymentMethod == 'credit')
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Credit requires customer details, due date and approval. '
                                    'Enter full or partial payment details on the next step.',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_hasUnconfirmedSale) ...[
                          const SizedBox(height: 14),
                          _surface(
                            child: const Text(
                              'The sale outcome is unconfirmed. Retry the original sale '
                              'to retrieve its receipt before starting another.',
                              style: TextStyle(
                                color: Color(0xFFB65A1C),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        if (_pendingRecoveryAvailable) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : _recoverPreviousOperation,
                              child: const Text(
                                'Recover interrupted operation',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            key: const ValueKey('record-sale-submit'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed:
                                product == null ||
                                    (!_hasUnconfirmedSale &&
                                        product.stock <= 0) ||
                                    _isLoading
                                ? null
                                : _recordSale,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Icon(Icons.more_horiz_rounded, size: 16),
                                  )
                                : Text(
                                    product == null
                                        ? 'Select an item'
                                        : _hasUnconfirmedSale
                                        ? 'Recover original sale'
                                        : 'Continue to Payment',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ],
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
    scrollable: true,
    title: Text('Quantity in ${widget.product.unit}'),
    content: SingleChildScrollView(
      child: TrexvenTextField(
        key: ValueKey('record-sale-quantity-input'),
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(
          decimal: widget.product.supportsFractionalQuantity,
        ),
        decoration: TrexvenInputDecoration(
          labelText: 'Quantity',
          errorText: error,
        ),
        onSubmitted: (_) => apply(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancel'),
      ),
      FilledButton(onPressed: apply, child: Text('Apply')),
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

    return TrexvenDropdown<String>(
      rich: true,
      key: ValueKey(selectedProduct?.id),
      initialValue: selectedProduct?.id,
      decoration: TrexvenInputDecoration(labelText: 'Product'),
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
            padding: EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                _ProductSwatch(product: product),
                SizedBox(width: 12),
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
                          fontSize: TrexvenFontSize.input,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '₦${product.price.toStringAsFixed(2)} · ${product.stock} in stock',
                        style: TextStyle(
                          fontSize: TrexvenFontSize.caption,
                          color: muted,
                        ),
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
        SizedBox(width: 12),
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
                  fontSize: TrexvenFontSize.input,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '₦${product.price.toStringAsFixed(2)} · ${product.stock} in stock',
                style: TextStyle(
                  color: muted,
                  fontSize: TrexvenFontSize.caption,
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
        color: primary.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
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
      width: TrexvenSpacing.quantityTarget,
      height: TrexvenSpacing.quantityTarget,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
              color: enabled
                  ? colors.surface.withValues(alpha: .20)
                  : colors.surface.withValues(alpha: .06),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 24,
              color: enabled
                  ? colors.onSurface
                  : colors.onSurface.withValues(alpha: .25),
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
              fontSize: TrexvenFontSize.input,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: TrexvenFontSize.input,
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
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 52,
              color: colors.onSurface.withValues(alpha: .30),
            ),
            SizedBox(height: TrexvenSpacing.fieldGap),
            Text(
              'No products available',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: TrexvenFontSize.section,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Add products to your inventory before recording a sale.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: .55),
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
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: colors.error),
            SizedBox(height: TrexvenSpacing.fieldGap),
            Text(
              message,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: TrexvenFontSize.section,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: TrexvenSpacing.fieldGap),
            OutlinedButton(onPressed: onRetry, child: Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _CartLine {
  _CartLine(this.product, this.quantity);
  final Product product;
  num quantity;
}

class _SearchProductSheet extends StatefulWidget {
  const _SearchProductSheet({required this.products});
  final List<Product> products;
  @override
  State<_SearchProductSheet> createState() => _SearchProductSheetState();
}

class _SearchProductSheetState extends State<_SearchProductSheet> {
  String query = '';
  final controller = TextEditingController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (!mounted || code == null) return;
    controller.text = code;
    setState(() => query = code);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products
        .where(
          (product) =>
              product.active &&
              !product.isPricePending &&
              (product.name.toLowerCase().contains(query.toLowerCase()) ||
                  (product.barcode ?? '').contains(query) ||
                  (product.sku ?? '').toLowerCase().contains(
                    query.toLowerCase(),
                  )),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Select a product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  controller: controller,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search product name',
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Scan barcode',
                  onPressed: scan,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    return ListTile(
                      enabled: product.stock > 0,
                      title: Text(product.name),
                      subtitle: Text(
                        '₦${product.price.toStringAsFixed(2)} · ${product.stock} in stock',
                      ),
                      trailing: const Icon(Icons.add_circle_outline),
                      onTap: product.stock > 0
                          ? () => Navigator.pop(context, product)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
