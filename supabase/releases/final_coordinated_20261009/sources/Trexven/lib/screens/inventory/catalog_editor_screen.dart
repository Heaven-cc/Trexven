import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../models/product.dart';
import '../../services/database_service.dart';

class CatalogEditorScreen extends StatefulWidget {
  const CatalogEditorScreen({super.key, required this.database, this.product});
  final DatabaseService database;
  final Product? product;
  @override
  State<CatalogEditorScreen> createState() => _CatalogEditorScreenState();
}

class _CatalogEditorScreenState extends State<CatalogEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _request = const Uuid().v4();
  final _stockRequest = const Uuid().v4();
  late final Map<String, TextEditingController> _fields;
  final Map<String, TextEditingController> _attributes = {};
  Map<String, dynamic>? _stockIntent;
  bool _busy = false;
  late bool _active;
  String? _group;
  List<Map<String, dynamic>> _groups = [];
  String? _error;
  Map<String, dynamic>? _intent;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _active = p?.active ?? true;
    _group = p?.catalogGroupId;
    final values = {
      'name': p?.name ?? '',
      'barcode': p?.barcode ?? '',
      'sku': p?.sku ?? '',
      'category': p?.category ?? '',
      'description': p?.description ?? '',
      'image_url': p?.imageUrl ?? '',
      'unit': p?.unit ?? 'piece',
      'selling_price': p == null || p.isPricePending ? '' : p.price.toString(),
      'low_stock_threshold': (p?.lowStockThreshold ?? 5).toString(),
      'delta': '',
      'reason': '',
    };
    _fields = values.map((k, v) => MapEntry(k, TextEditingController(text: v)));
    for (final e in {
      'size': '',
      'color': '',
      ...p?.variantAttributes ?? {},
    }.entries) {
      _attributes[e.key] = TextEditingController(text: e.value.toString());
    }
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await widget.database.getProductGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Catalog changes require the approved backend update.',
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [..._fields.values, ..._attributes.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_intent == null) {
        final attrs = {
          for (final e in _attributes.entries)
            if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
        };

        _intent = {
          for (final key in [
            'name',
            'barcode',
            'sku',
            'category',
            'description',
            'image_url',
            'unit',
          ])
            key: _fields[key]!.text.trim(),
          'selling_price': _fields['selling_price']!.text.trim().isEmpty
              ? null
              : num.parse(_fields['selling_price']!.text),
          'low_stock_threshold': num.parse(
            _fields['low_stock_threshold']!.text,
          ),
          'active': _active,
          'catalog_group_id': _group,
          'variant_attributes': attrs,
        };
      }
      await widget.database.saveCatalogProduct(
        widget.product?.id,
        _intent!,
        _request,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Save failed: $e. Retry sends the same request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _adjust() async {
    final delta = num.tryParse(_fields['delta']!.text);
    final reason = _fields['reason']!.text.trim();
    if (delta == null || !delta.isFinite || delta == 0 || reason.isEmpty) {
      setState(() => _error = 'Enter a nonzero stock change and a reason.');
      return;
    }
    setState(() => _busy = true);
    try {
      _stockIntent ??= {'delta': delta, 'reason': reason};
      await widget.database.adjustProductStock(
        widget.product!.id!,
        _stockIntent!['delta'] as num,
        _stockIntent!['reason'] as String,
        _stockRequest,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Stock change failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Variant group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Group name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final id = const Uuid().v4();
    try {
      final group = await widget.database.saveProductGroup(name, id: id);
      await _loadGroups();
      if (mounted) setState(() => _group = group);
    } catch (e) {
      if (mounted) setState(() => _error = 'Group creation failed: $e');
    }
  }

  Future<void> _movements() async {
    try {
      final rows = await widget.database.productMovements(widget.product!.id!);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stock movements'),
          content: SizedBox(
            width: 400,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (rows.isEmpty) const Text('No recorded movements.'),
                for (final r in rows)
                  ListTile(
                    title: Text('${r['movement_type']}: ${r['quantity']}'),
                    subtitle: Text(
                      '${r['previous_quantity']} → ${r['new_quantity']}\n${r['reason'] ?? ''}\n${r['created_at']}',
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Unable to load movements: $e');
    }
  }

  Widget _field(
    String key,
    String label, {
    bool number = false,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      enabled: !_busy && _intent == null && _stockIntent == null,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (text) {
        if (required && (text ?? '').trim().isEmpty) return 'Required';
        if (number && (text ?? '').isNotEmpty) {
          final n = num.tryParse(text!);
          if (n == null || !n.isFinite || n < 0) {
            return 'Enter a valid nonnegative number';
          }
          final precision = key == 'selling_price' ? 100 : 1000;
          if ((n * precision - (n * precision).round()).abs() > 0.0000001) {
            return 'Too many decimal places';
          }
        }
        return null;
      },
    ),
  );
  Future<void> _addAttribute() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Variation attribute'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Attribute name, e.g. material',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    if (name.length > 40 || _attributes.containsKey(name)) {
      setState(
        () => _error = 'Use a unique attribute name with up to 40 characters.',
      );
      return;
    }
    setState(() => _attributes[name] = TextEditingController());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.product == null ? 'Add product' : 'Edit product'),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          _field('name', 'Product name', required: true),
          _field('barcode', 'Manufacturer barcode (optional)'),
          _field('sku', 'SKU (optional)'),
          _field('category', 'Category'),
          _field('description', 'Description'),
          _field('image_url', 'Image URL (optional)'),
          DropdownButtonFormField<String>(
            initialValue: _fields['unit']!.text,
            decoration: const InputDecoration(labelText: 'Unit'),
            items: [
              for (final unit in {
                'piece',
                'kg',
                'g',
                'litre',
                'ml',
                'metre',
                'cm',
                _fields['unit']!.text,
              })
                DropdownMenuItem(value: unit, child: Text(unit)),
            ],
            onChanged: _busy || _intent != null
                ? null
                : (v) => setState(() => _fields['unit']!.text = v ?? 'piece'),
          ),
          _field(
            'selling_price',
            'Selling price (blank means pending)',
            number: true,
          ),
          _field(
            'low_stock_threshold',
            'Low-stock threshold',
            number: true,
            required: true,
          ),
          DropdownButtonFormField<String>(
            initialValue: _groups.any((g) => g['id'] == _group) ? _group : null,
            decoration: const InputDecoration(labelText: 'Variant group'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Standalone product'),
              ),
              for (final g in _groups)
                DropdownMenuItem(
                  value: g['id'] as String,
                  child: Text(g['name'].toString()),
                ),
            ],
            onChanged: _busy || _intent != null
                ? null
                : (v) => setState(() => _group = v),
          ),
          TextButton(
            onPressed: _busy || _intent != null ? null : _createGroup,
            child: const Text('Create variant group'),
          ),
          for (final e in _attributes.entries)
            TextField(
              controller: e.value,
              enabled: !_busy && _intent == null && _stockIntent == null,
              decoration: InputDecoration(labelText: e.key),
            ),
          TextButton(
            onPressed: _busy || _intent != null ? null : _addAttribute,
            child: const Text('Add variation attribute'),
          ),
          SwitchListTile(
            title: const Text('Active'),
            value: _active,
            onChanged: _busy || _intent != null
                ? null
                : (v) => setState(() => _active = v),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              _intent == null ? 'Save product' : 'Retry saved request',
            ),
          ),
          if (widget.product != null) ...[
            const Divider(),
            Text(
              'Recorded stock: ${widget.product!.stock} ${widget.product!.unit}',
            ),
            _field('delta', 'Stock change (+ received / − correction)'),
            _field('reason', 'Stock change reason'),
            OutlinedButton(
              onPressed: _busy ? null : _adjust,
              child: Text(
                _stockIntent == null
                    ? 'Apply stock change'
                    : 'Retry saved stock change',
              ),
            ),
            TextButton(
              onPressed: _busy ? null : _movements,
              child: const Text('View stock movements'),
            ),
          ],
        ],
      ),
    ),
  );
}
