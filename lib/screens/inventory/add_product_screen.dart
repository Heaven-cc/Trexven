import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';
import 'package:uuid/uuid.dart';
import '../../services/initial_load_timeout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({
    super.key,
    this.database,
    this.startInRestock = false,
  });
  final DatabaseService? database;
  final bool startInRestock;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final String _restockRequestId = Uuid().v4();
  final String _restockPriceRequestId = Uuid().v4();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  final _restockQuantityController = TextEditingController();
  final _restockPriceController = TextEditingController();
  ({Product product, int quantity, double? price, bool updatePrice})?
  _restockIntent;
  bool _restockPriceSaved = false;
  String? _restockError;

  late final DatabaseService _db;
  late Stream<List<Product>> _products;

  bool _isLoading = false;
  bool _isNewProduct = true;

  Product? _selectedProduct;

  int get _initialStock {
    return int.tryParse(_stockController.text) ?? 0;
  }

  int get _restockQuantity {
    return int.tryParse(_restockQuantityController.text) ?? 0;
  }

  num get _newStock {
    if (_selectedProduct == null) return 0;
    return _selectedProduct!.stock + _restockQuantity;
  }

  @override
  void initState() {
    super.initState();
    _isNewProduct = !widget.startInRestock;
    _db = widget.database ?? DatabaseService();
    _products = withInitialLoadTimeout(_db.getProductsStream());

    _nameController.addListener(_refresh);
    _priceController.addListener(_refresh);
    _stockController.addListener(_refresh);
    _restockQuantityController.addListener(_refresh);
    _restockPriceController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _restockQuantityController.dispose();
    _restockPriceController.dispose();
    super.dispose();
  }

  void _switchMode(bool newProduct) {
    if (_isLoading || _restockIntent != null) return;
    setState(() {
      _isNewProduct = newProduct;

      if (newProduct) {
        _selectedProduct = null;
        _restockQuantityController.clear();
        _restockPriceController.clear();
      } else {
        _nameController.clear();
        _priceController.clear();
        _stockController.clear();
      }
    });
  }

  Future<void> _saveProduct() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    if (price == null || stock == null) return;

    setState(() => _isLoading = true);

    try {
      final product = Product(
        id: _restockRequestId,
        name: name,
        price: price,
        stock: stock,
      );

      await _db.addProduct(product);

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name added to inventory'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            CustomerPresentation.error(
              e,
              fallback: 'Unable to save product. Please try again.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStock() async {
    if (_isLoading) return;
    if (_restockIntent == null && _selectedProduct == null) {
      _showMessage('Select a product first');
      return;
    }

    if (_restockIntent == null && _restockQuantity <= 0) {
      _showMessage('Enter the quantity received');
      return;
    }

    if (_restockIntent == null) {
      if (!_formKey.currentState!.validate()) return;
      final price = double.tryParse(_restockPriceController.text.trim());
      final selected = _selectedProduct!;
      _restockIntent = (
        product: selected,
        quantity: _restockQuantity,
        price: price,
        updatePrice: selected.isPricePending
            ? price != null
            : price != selected.price,
      );
    }
    final intent = _restockIntent!;
    final product = intent.product;
    final delta = intent.quantity;
    setState(() {
      _isLoading = true;
      _restockError = null;
    });

    try {
      // Reuse the catalog's partial update and retry identity. Price is saved
      // before stock, so a rejected price cannot silently restock the product.
      if (intent.updatePrice && !_restockPriceSaved) {
        await _db.saveCatalogProduct(product.id, {
          'selling_price': intent.price,
        }, _restockPriceRequestId);
        _restockPriceSaved = true;
      }
      await _db.adjustProductStock(
        product.id!,
        delta,
        'Owner restock',
        _restockRequestId,
      );

      if (!mounted) return;

      final name = product.name;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name stock updated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(
        () => _restockError =
            (_restockPriceSaved
                ? 'Selling price updated; stock update is unconfirmed. Retry to confirm the original restock. '
                : '') +
            CustomerPresentation.error(
              e,
              fallback: 'Unable to update stock. Please try again.',
            ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final borderColor =
        theme.trexvenColors.border ?? colors.outline.withValues(alpha: .18);
    final muted =
        theme.trexvenColors.muted ?? colors.onSurface.withValues(alpha: .60);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded),
        ),

        titleSpacing: 4,

        title: Text(
          _isNewProduct ? 'New product' : 'Restock product',
          style: TextStyle(
            fontSize: TrexvenSpacing.pageTitle,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: colors.onSurface,
          ),
        ),
      ),

      body: StreamBuilder<List<Product>>(
        stream: _products,
        builder: (context, snapshot) {
          final products = snapshot.hasError
              ? <Product>[]
              : snapshot.data ?? [];
          if (_selectedProduct != null && _restockIntent == null) {
            final matches = products.where(
              (product) => product.id == _selectedProduct!.id,
            );
            _selectedProduct = matches.isEmpty ? null : matches.first;
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: TrexvenSpacing.pagePadding,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 620),
                  child: Container(
                    padding: EdgeInsets.zero,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ModeSelector(
                            isNewProduct: _isNewProduct,
                            borderColor: borderColor,
                            onChanged: _switchMode,
                          ),

                          SizedBox(height: TrexvenSpacing.fieldGap),

                          if (_isNewProduct)
                            _buildNewProduct(theme, muted, borderColor)
                          else
                            _buildRestock(
                              theme,
                              products,
                              muted,
                              borderColor,
                              snapshot,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNewProduct(ThemeData theme, Color muted, Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrexvenFieldLabel(text: 'Product name'),

        SizedBox(height: TrexvenSpacing.labelGap),

        TrexvenTextFormField(
          showLabel: false,
          gap: 0,
          decoration: TrexvenInputDecoration(
            hintText: 'e.g. Brake pad, Toyota Corolla',
            prefixIcon: Icon(Icons.inventory_2_outlined),
          ),
          controller: _nameController,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter a product name';
            }

            return null;
          },
        ),

        SizedBox(height: TrexvenSpacing.fieldGap),

        TrexvenFieldLabel(text: 'Selling price'),

        SizedBox(height: TrexvenSpacing.labelGap),

        TrexvenTextFormField(
          showLabel: false,
          gap: 0,
          decoration: TrexvenInputDecoration(
            hintText: '0.00',
            prefixIcon: Icon(Icons.payments_outlined),
            prefixText: '₦ ',
          ),
          controller: _priceController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          validator: (value) {
            final price = double.tryParse(value?.trim() ?? '');

            if (price == null || price <= 0) {
              return 'Enter a valid price';
            }

            return null;
          },
        ),

        SizedBox(height: TrexvenSpacing.fieldGap),

        TrexvenFieldLabel(text: 'Initial stock'),

        SizedBox(height: TrexvenSpacing.labelGap),

        TrexvenTextFormField(
          showLabel: false,
          gap: 0,
          decoration: TrexvenInputDecoration(
            hintText: '0',
            prefixIcon: Icon(Icons.numbers_rounded),
          ),
          controller: _stockController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            final stock = int.tryParse(value?.trim() ?? '');

            if (stock == null || stock < 0) {
              return 'Enter a valid stock quantity';
            }

            return null;
          },
        ),

        SizedBox(height: TrexvenSpacing.fieldGap),

        SizedBox(height: TrexvenSpacing.fieldGap),

        Text('Stock preview', style: theme.textTheme.titleLarge),

        SizedBox(height: 12),

        _ProductPreview(
          name: _nameController.text.trim().isEmpty
              ? 'New product'
              : _nameController.text.trim(),
          price: double.tryParse(_priceController.text) ?? 0,
          stock: _initialStock,
          theme: theme,
          muted: muted,
        ),

        SizedBox(height: TrexvenSpacing.fieldGap),

        _PrimaryButton(
          text: 'Save product',
          isLoading: _isLoading,
          enabled: !_isLoading,
          onPressed: _saveProduct,
        ),

        SizedBox(height: 4),
      ],
    );
  }

  Widget _buildRestock(
    ThemeData theme,
    List<Product> products,
    Color muted,
    Color borderColor,
    AsyncSnapshot<List<Product>> snapshot,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrexvenFieldLabel(text: 'Product'),

        SizedBox(height: TrexvenSpacing.labelGap),

        if (snapshot.hasError)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Unable to load products. Check your connection and retry.'),
              TextButton(
                onPressed: () => setState(
                  () => _products = withInitialLoadTimeout(
                    _db.getProductsStream(),
                  ),
                ),
                child: Text('Retry'),
              ),
            ],
          )
        else if (!snapshot.hasData)
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Text('Please wait…'),
              ),
              SizedBox(width: 12),
              Flexible(child: Text('Loading products…')),
            ],
          )
        else if (products.isEmpty)
          Text('No products available. Add a product before restocking.')
        else
          _ProductDropdown(
            products: products,
            selectedProduct: _selectedProduct,
            theme: theme,
            muted: muted,
            borderColor: borderColor,
            onChanged: _isLoading || _restockIntent != null
                ? null
                : (product) {
                    setState(() {
                      _selectedProduct = product;
                      _restockQuantityController.clear();
                      _restockPriceController.text =
                          product == null || product.isPricePending
                          ? ''
                          : product.price.toStringAsFixed(2);
                    });
                  },
          ),

        SizedBox(height: TrexvenSpacing.fieldGap),

        TrexvenFieldLabel(text: 'Quantity received'),

        SizedBox(height: TrexvenSpacing.labelGap),

        TrexvenTextFormField(
          showLabel: false,
          gap: 0,
          decoration: TrexvenInputDecoration(
            hintText: '0',
            prefixIcon: Icon(Icons.add_rounded),
          ),
          controller: _restockQuantityController,
          enabled: !_isLoading && _restockIntent == null,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),

        SizedBox(height: TrexvenSpacing.fieldGap),

        TrexvenTextFormField(
          label: 'Selling price',
          controller: _restockPriceController,
          enabled:
              !_isLoading && _restockIntent == null && _selectedProduct != null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const TrexvenInputDecoration(
            hintText: '0.00',
            helperText:
                'Current price is prefilled; edit only when needed. Leave blank to keep a pending price.',
          ),
          validator: (value) {
            final text = (value ?? '').trim();
            if (text.isEmpty) return null;
            final price = double.tryParse(text);
            return price == null ||
                    !price.isFinite ||
                    price < 0 ||
                    !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(text)
                ? 'Enter a non-negative price with up to two decimal places.'
                : null;
          },
        ),
        if (_restockIntent != null && !_isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: TrexvenSpacing.fieldGap),
            child: Text(
              'Retry keeps the selected product, quantity and price to prevent duplicate updates.',
            ),
          ),
        if (_restockError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: TrexvenSpacing.fieldGap),
            child: Text(
              _restockError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),

        SizedBox(height: TrexvenSpacing.fieldGap),

        Text('Stock preview', style: theme.textTheme.titleLarge),

        SizedBox(height: TrexvenSpacing.fieldGap),

        _StockPreview(
          product: _selectedProduct,
          received: _restockQuantity,
          newStock: _newStock,
          theme: theme,
          muted: muted,
          borderColor: borderColor,
        ),

        SizedBox(height: TrexvenSpacing.fieldGap),

        _PrimaryButton(
          text: 'Update stock',
          isLoading: _isLoading,
          enabled:
              !_isLoading &&
              (_restockIntent != null ||
                  (_selectedProduct != null && _restockQuantity > 0)),
          onPressed: _updateStock,
        ),

        SizedBox(height: 4),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final bool isNewProduct;
  final Color borderColor;
  final ValueChanged<bool> onChanged;

  const _ModeSelector({
    required this.isNewProduct,
    required this.borderColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 56),
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeOption(
              text: 'New product',
              selected: isNewProduct,
              onTap: () => onChanged(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeOption(
              text: 'Restock existing',
              selected: !isNewProduct,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _ModeOption({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: selected ? colors.primary.withValues(alpha: .08) : colors.surface,
      borderRadius: BorderRadius.circular(TrexvenRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: TrexvenFontSize.input,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.primary : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductPreview extends StatelessWidget {
  final String name;
  final double price;
  final num stock;
  final ThemeData theme;
  final Color muted;

  const _ProductPreview({
    required this.name,
    required this.price,
    required this.stock,
    required this.theme,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 19),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: .38),
        borderRadius: BorderRadius.circular(TrexvenRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(TrexvenRadii.card),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: colors.primary,
              size: 23,
            ),
          ),

          SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: TrexvenFontSize.input,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '₦${price.toStringAsFixed(2)} · $stock in stock',
                  style: TextStyle(
                    color: muted,
                    fontSize: TrexvenFontSize.body,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDropdown extends StatelessWidget {
  final List<Product> products;
  final Product? selectedProduct;
  final ThemeData theme;
  final Color muted;
  final Color borderColor;
  final ValueChanged<Product?>? onChanged;

  const _ProductDropdown({
    required this.products,
    required this.selectedProduct,
    required this.theme,
    required this.muted,
    required this.borderColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;

    return TrexvenDropdown<String>(
      rich: true,
      showLabel: false,
      gap: 0,
      key: ValueKey(selectedProduct?.id),
      initialValue: selectedProduct?.id,
      decoration: TrexvenInputDecoration(),
      hint: Text('Choose a product', style: TextStyle(color: muted)),
      items: products.map((product) {
        return DropdownMenuItem<String>(
          value: product.id,
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: colors.primary),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${product.stock} currently in stock',
                      style: TextStyle(
                        color: muted,
                        fontSize: TrexvenFontSize.caption,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged == null
          ? null
          : (id) =>
                onChanged!(products.firstWhere((product) => product.id == id)),
    );
  }
}

class _StockPreview extends StatelessWidget {
  final Product? product;
  final int received;
  final num newStock;
  final ThemeData theme;
  final Color muted;
  final Color borderColor;

  const _StockPreview({
    required this.product,
    required this.received,
    required this.newStock,
    required this.theme,
    required this.muted,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StockRow(
          label: 'Current stock',
          value: product == null ? '—' : '${product!.stock}',
          color: colors.onSurface,
          muted: muted,
        ),
        SizedBox(height: 14),
        _StockRow(
          label: 'Received',
          value: product == null ? '+ 0' : '+ $received',
          color: colors.onSurface,
          muted: muted,
        ),
        SizedBox(height: TrexvenSpacing.fieldGap),
        SizedBox(height: TrexvenSpacing.fieldGap),
        _StockRow(
          label: 'New stock',
          value: product == null ? '—' : '$newStock',
          color: colors.onSurface,
          muted: muted,
          emphasized: true,
        ),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color muted;
  final bool emphasized;

  const _StockRow({
    required this.label,
    required this.value,
    required this.color,
    required this.muted,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: TrexvenSpacing.labelGap,
      runSpacing: TrexvenSpacing.labelGap,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasized ? color : muted,
            fontSize: emphasized ? TrexvenFontSize.input : TrexvenFontSize.body,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: TrexvenFontSize.input,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.text,
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: double.infinity,
        minHeight: TrexvenSpacing.buttonHeight,
      ),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: Text('Please wait…'),
              )
            : Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
