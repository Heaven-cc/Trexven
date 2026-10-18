import 'package:uuid/uuid.dart';
import '../../services/initial_load_timeout.dart';
import '../../core/app_sizing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/database_service.dart';
import '../../models/product.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key, this.database});
  final DatabaseService? database;

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final String _restockRequestId = const Uuid().v4();
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  final _restockQuantityController = TextEditingController();

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
    _db = widget.database ?? DatabaseService();
    _products = withInitialLoadTimeout(_db.getProductsStream());

    _nameController.addListener(_refresh);
    _priceController.addListener(_refresh);
    _stockController.addListener(_refresh);
    _restockQuantityController.addListener(_refresh);
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
    super.dispose();
  }

  void _switchMode(bool newProduct) {
    if (_isLoading) return;
    setState(() {
      _isNewProduct = newProduct;

      if (newProduct) {
        _selectedProduct = null;
        _restockQuantityController.clear();
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
      final product = Product(id: _restockRequestId, name: name, price: price, stock: stock);

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
          content: Text('Unable to save product: $e'),
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
    if (_selectedProduct == null) {
      _showMessage('Select a product first');
      return;
    }

    if (_restockQuantity <= 0) {
      _showMessage('Enter the quantity received');
      return;
    }

    final product = _selectedProduct!;
    final delta = _restockQuantity;
    setState(() => _isLoading = true);

    try {
      await _db.adjustProductStock(product.id!, delta, 'Owner restock', _restockRequestId);

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update stock: $e'),
          behavior: SnackBarBehavior.floating,
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

    final cardColor = theme.trexvenColors.cardBackground;
    final borderColor =
        theme.trexvenColors.border ?? colors.outline.withOpacity(.18);
    final muted =
        theme.trexvenColors.muted ?? colors.onSurface.withOpacity(.60);

    return Scaffold(
      backgroundColor: colors.surface,

      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded),
        ),

        titleSpacing: 4,

        title: Text(
          _isNewProduct ? 'New product' : 'Restock product',
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
          final products = snapshot.hasError
              ? <Product>[]
              : snapshot.data ?? [];
          if (_selectedProduct != null) {
            final matches = products.where(
              (product) => product.id == _selectedProduct!.id,
            );
            _selectedProduct = matches.isEmpty ? null : matches.first;
          }

          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: AppSizing.pagePadding,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Container(
                    padding: AppSizing.cardPadding,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: borderColor),
                    ),
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

                          const SizedBox(height: AppSizing.fieldGap),

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
        _FieldLabel(text: 'Product name', color: muted),

        const SizedBox(height: 10),

        _TrexvenField(
          controller: _nameController,
          hintText: 'e.g. Brake pad, Toyota Corolla',
          icon: Icons.inventory_2_outlined,
          theme: theme,
          borderColor: borderColor,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Enter a product name';
            }

            return null;
          },
        ),

        const SizedBox(height: AppSizing.fieldGap),

        _FieldLabel(text: 'Selling price', color: muted),

        const SizedBox(height: 10),

        _TrexvenField(
          controller: _priceController,
          hintText: '0.00',
          icon: Icons.payments_outlined,
          theme: theme,
          borderColor: borderColor,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          prefixText: '₦ ',
          validator: (value) {
            final price = double.tryParse(value?.trim() ?? '');

            if (price == null || price <= 0) {
              return 'Enter a valid price';
            }

            return null;
          },
        ),

        const SizedBox(height: AppSizing.fieldGap),

        _FieldLabel(text: 'Initial stock', color: muted),

        const SizedBox(height: 10),

        _TrexvenField(
          controller: _stockController,
          hintText: '0',
          icon: Icons.numbers_rounded,
          theme: theme,
          borderColor: borderColor,
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

        const SizedBox(height: AppSizing.fieldGap),

        Divider(height: 1, color: borderColor),

        const SizedBox(height: AppSizing.fieldGap),

        _FieldLabel(text: 'Preview', color: muted),

        const SizedBox(height: 12),

        _ProductPreview(
          name: _nameController.text.trim().isEmpty
              ? 'New product'
              : _nameController.text.trim(),
          price: double.tryParse(_priceController.text) ?? 0,
          stock: _initialStock,
          theme: theme,
          muted: muted,
        ),

        const SizedBox(height: AppSizing.fieldGap),

        _PrimaryButton(
          text: 'Save product',
          isLoading: _isLoading,
          enabled: !_isLoading,
          onPressed: _saveProduct,
        ),

        const SizedBox(height: 4),
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
        _FieldLabel(text: 'Product', color: muted),

        const SizedBox(height: 10),

        if (snapshot.hasError)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unable to load products. Check your connection and retry.',
              ),
              TextButton(
                onPressed: () => setState(
                  () => _products = withInitialLoadTimeout(
                    _db.getProductsStream(),
                  ),
                ),
                child: const Text('Retry'),
              ),
            ],
          )
        else if (!snapshot.hasData)
          const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Flexible(child: Text('Loading products…')),
            ],
          )
        else if (products.isEmpty)
          const Text('No products available. Add a product before restocking.')
        else
          _ProductDropdown(
            products: products,
            selectedProduct: _selectedProduct,
            theme: theme,
            muted: muted,
            borderColor: borderColor,
            onChanged: _isLoading
                ? null
                : (product) {
                    setState(() {
                      _selectedProduct = product;
                      _restockQuantityController.clear();
                    });
                  },
          ),

        const SizedBox(height: AppSizing.fieldGap),

        _FieldLabel(text: 'Quantity received', color: muted),

        const SizedBox(height: 10),

        _TrexvenField(
          controller: _restockQuantityController,
          hintText: '0',
          icon: Icons.add_rounded,
          theme: theme,
          borderColor: borderColor,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),

        const SizedBox(height: AppSizing.fieldGap),

        Divider(height: 1, color: borderColor),

        const SizedBox(height: AppSizing.fieldGap),

        _FieldLabel(text: 'Preview', color: muted),

        const SizedBox(height: 18),

        _StockPreview(
          product: _selectedProduct,
          received: _restockQuantity,
          newStock: _newStock,
          theme: theme,
          muted: muted,
          borderColor: borderColor,
        ),

        const SizedBox(height: AppSizing.fieldGap),

        _PrimaryButton(
          text: 'Update stock',
          isLoading: _isLoading,
          enabled:
              !_isLoading && _selectedProduct != null && _restockQuantity > 0,
          onPressed: _updateStock,
        ),

        const SizedBox(height: 4),
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(.40),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
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
      color: selected ? colors.onSurface.withOpacity(.07) : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? colors.onSurface
                  : colors.onSurface.withOpacity(.62),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _FieldLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
    );
  }
}

class _TrexvenField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final ThemeData theme;
  final Color borderColor;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final String? Function(String?)? validator;

  const _TrexvenField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.theme,
    required this.borderColor,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colors = theme.colorScheme;
    final muted =
        theme.trexvenColors.muted ?? colors.onSurface.withOpacity(.55);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        color: colors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: muted.withOpacity(.72),
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: Icon(icon, size: 21, color: muted),
        prefixText: prefixText,
        prefixStyle: TextStyle(
          color: muted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: colors.surface.withOpacity(.40),
        contentPadding: AppSizing.fieldPadding,
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
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: colors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: colors.error, width: 1.4),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(.38),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: colors.primary,
              size: 23,
            ),
          ),

          const SizedBox(width: 14),

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
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₦${price.toStringAsFixed(2)} · $stock in stock',
                  style: TextStyle(
                    color: muted,
                    fontSize: 13,
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

    return DropdownButtonFormField<String>(
      key: ValueKey(selectedProduct?.id),
      initialValue: selectedProduct?.id,
      isExpanded: true,
      isDense: false,
      itemHeight: null,
      borderRadius: BorderRadius.circular(18),
      dropdownColor: theme.trexvenColors.cardBackground,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: muted),
      style: TextStyle(color: colors.onSurface, fontSize: 15),
      decoration: InputDecoration(
        filled: true,
        fillColor: colors.surface.withOpacity(.40),
        contentPadding: AppSizing.fieldPadding,
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
          borderSide: BorderSide(color: colors.primary, width: 1.4),
        ),
      ),
      hint: Text('Choose a product', style: TextStyle(color: muted)),
      items: products.map((product) {
        return DropdownMenuItem<String>(
          value: product.id,
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: colors.primary),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 3),
                    Text(
                      '${product.stock} currently in stock',
                      style: TextStyle(color: muted, fontSize: 12),
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
      children: [
        _StockRow(
          label: 'Current stock',
          value: product == null ? '—' : '${product!.stock}',
          color: colors.onSurface,
          muted: muted,
        ),
        const SizedBox(height: 14),
        _StockRow(
          label: 'Received',
          value: product == null ? '+ 0' : '+ $received',
          color: colors.onSurface,
          muted: muted,
        ),
        const SizedBox(height: 16),
        Divider(height: 1, color: borderColor),
        const SizedBox(height: 16),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasized ? color : muted,
            fontSize: emphasized ? 16 : 15,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: emphasized ? 22 : 15,
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
      constraints: const BoxConstraints(
        minWidth: double.infinity,
        minHeight: AppSizing.buttonHeight,
      ),
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: colors.onPrimary,
                ),
              )
            : Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
