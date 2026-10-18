import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:file_selector/file_selector.dart';
import '../../services/catalog_import.dart';
import '../../services/database_service.dart';

class CatalogImportScreen extends StatefulWidget {
  const CatalogImportScreen({super.key, required this.database});
  final DatabaseService database;
  @override
  State<CatalogImportScreen> createState() => _CatalogImportScreenState();
}

class _CatalogImportScreenState extends State<CatalogImportScreen> {
  final _text = TextEditingController();
  final _request = const Uuid().v4();
  List<Map<String, dynamic>>? _rows;
  String? _error;
  bool _busy = false;
  bool _submitted = false;
  bool _updateExisting = false;
  List<Map<String, dynamic>>? _fileRows;
  String? _fileName;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    try {
      final rows = (_fileRows ?? CatalogImport.parse(_text.text))
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      final products = await widget.database.getProducts();
      for (final row in rows) {
        final matches = products
            .where(
              (p) =>
                  (row['barcode'] != null &&
                      p.barcode?.trim() == row['barcode']) ||
                  (row['sku'] != null && p.sku?.trim() == row['sku']),
            )
            .toList();
        if (matches.length > 1) {
          throw FormatException('Ambiguous barcode/SKU for ${row['name']}.');
        }
        if (matches.isNotEmpty) {
          if (!_updateExisting) {
            throw FormatException(
              'Existing barcode/SKU for ${row['name']}. Enable reviewed updates or edit separately.',
            );
          }
          if (row.containsKey('initial_quantity')) {
            throw FormatException(
              'Use stock_delta and stock_reason when updating ${row['name']}.',
            );
          }
          row['product_id'] = matches.single.id;
        } else if (row.containsKey('stock_delta')) {
          throw FormatException(
            'Use initial_quantity for new product ${row['name']}.',
          );
        }
      }
      if (mounted) {
        setState(() {
          _rows = rows;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _rows = null;
        });
      }
    }
  }

  Future<void> _chooseFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Product CSV or Excel',
            extensions: ['csv', 'xlsx'],
            mimeTypes: [
              'text/csv',
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ],
            uniformTypeIdentifiers: [
              'public.comma-separated-values-text',
              'org.openxmlformats.spreadsheetml.sheet',
            ],
          ),
        ],
      );
      if (file == null) return;
      if (file.name.toLowerCase().endsWith('.xlsx')) {
        _fileRows = CatalogImport.parseExcel(await file.readAsBytes());
        _text.clear();
      } else {
        _fileRows = null;
        _text.text = await file.readAsString();
      }
      if (mounted) {
        setState(() {
          _fileName = file.name;
          _rows = null;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Unable to read import: $e');
    }
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _submitted = true;
    });
    try {
      await widget.database.importCatalog(_rows!, _request);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Import failed: $e. Retry preserves this request.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Import products')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton(
          onPressed: _busy || _submitted ? null : _chooseFile,
          child: const Text('Choose CSV or Excel file'),
        ),
        if (_fileName != null) Text(_fileName!),
        const Text(
          'Paste CSV with a name header. Optional headers: barcode, sku, category, description, image_url, unit, selling_price, low_stock_threshold, initial_quantity (new), stock_delta and stock_reason (updates), active, group_name, size, color, material. Blank prices remain pending. Updates require explicit review. Blank price cells preserve existing prices and leave new products pending.',
        ),
        CheckboxListTile(
          title: const Text('Update products matched by barcode or SKU'),
          value: _updateExisting,
          onChanged: _busy || _submitted
              ? null
              : (v) => setState(() {
                  _updateExisting = v ?? false;
                  _rows = null;
                }),
        ),
        TextField(
          controller: _text,
          minLines: 5,
          maxLines: 12,
          enabled: !_busy && !_submitted,
          onChanged: (_) => setState(() {
            _rows = null;
            _fileRows = null;
            _fileName = null;
          }),
          decoration: const InputDecoration(labelText: 'CSV products'),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        OutlinedButton(
          onPressed: _busy || _submitted ? null : _review,
          child: const Text('Review import'),
        ),
        if (_rows != null) ...[
          Text('${_rows!.length} products ready for review'),
          for (final r in _rows!)
            ListTile(
              title: Text(
                '${r['product_id'] == null ? 'Create' : 'Update'}: ${r['name']}',
              ),
              subtitle: Text(
                '${r['barcode'] ?? 'No barcode'} • ${r['selling_price'] ?? 'Pending price'} • ${r['initial_quantity'] ?? 0} ${r['unit'] ?? 'piece'}',
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _import,
            child: Text(_submitted ? 'Retry same import' : 'Confirm import'),
          ),
        ],
      ],
    ),
  );
}
