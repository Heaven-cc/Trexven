
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:file_selector/file_selector.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import 'package:trexven_operations/trexven_operations.dart';

import '../../services/catalog_import.dart';
import '../../services/database_service.dart';

class CatalogImportScreen extends StatefulWidget {
  const CatalogImportScreen({
    super.key,
    required this.database,
  });

  final DatabaseService database;

  @override
  State<CatalogImportScreen> createState() =>
      _CatalogImportScreenState();
}

class _CatalogImportScreenState
    extends State<CatalogImportScreen> {
  final _text = TextEditingController();

  // Keep the same request ID for retries of a submitted import.
  String _request = const Uuid().v4();

  List<Map<String, dynamic>>? _rows;
  List<Map<String, dynamic>>? _fileRows;

  String? _fileName;
  String? _error;

  bool _busy = false;
  bool _submitted = false;
  bool _updateExisting = false;
  bool _showCsvEditor = false;
  bool _showInstructions = false;

  static const Color _background = Color(0xFFF5F7FC);
  static const Color _white = Colors.white;
  static const Color _navy = Color(0xFF14213D);
  static const Color _blue = Color(0xFF2864F0);
  static const Color _muted = Color(0xFF71809A);
  static const Color _softBlue = Color(0xFFE8EFFF);
  static const Color _border = Color(0xFFE6EAF2);
  static const Color _green = Color(0xFF16845A);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _importValidation(String message) {
    const labels = {
      'stock_delta': 'stock change',
      'stock_reason': 'stock change reason',
      'initial_quantity': 'opening quantity',
      'selling_price': 'selling price',
      'low_stock_threshold': 'low-stock threshold',
      'image_url': 'image link',
      'group_name': 'product group',
    };

    for (final entry in labels.entries) {
      message = message.replaceAll(
        entry.key,
        entry.value,
      );
    }

    return message;
  }

  void _clearReview() {
    _rows = null;
    _error = null;
  }

  Future<void> _chooseFile() async {
    if (_busy || _submitted) return;

    try {
      final file = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
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

      final isExcel =
      file.name.toLowerCase().endsWith('.xlsx');

      // Parse before updating the visible state so a failed file
      // read does not replace the previous valid import.
      List<Map<String, dynamic>>? excelRows;
      String? csvContent;

      if (isExcel) {
        excelRows = CatalogImport.parseExcel(
          await file.readAsBytes(),
        );
      } else {
        csvContent = await file.readAsString();
      }

      if (!mounted) return;

      setState(() {
        _fileRows = excelRows;

        if (isExcel) {
          _text.clear();
        } else {
          _text.text = csvContent ?? '';
        }

        _fileName = file.name;
        _showCsvEditor = false;
        _clearReview();
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e is FormatException
            ? _importValidation(e.message)
            : CustomerPresentation.error(
                e,
                fallback: 'Unable to read import. Please try again.',
              );
      });
    }
  }

  Future<void> _review() async {
    if (_busy || _submitted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final rows = (
          _fileRows ??
              CatalogImport.parse(_text.text)
      ).map(
            (row) => Map<String, dynamic>.from(row),
      ).toList();

      final products = await widget.database.getProducts();

      for (final row in rows) {
        final matches = products.where(
              (product) =>
          (row['barcode'] != null &&
              product.barcode?.trim() ==
                  row['barcode']) ||
              (row['sku'] != null &&
                  product.sku?.trim() ==
                      row['sku']),
        ).toList();

        if (matches.length > 1) {
          throw FormatException(
            'Ambiguous barcode/SKU for ${row['name']}.',
          );
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

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e is FormatException
            ? _importValidation(e.message)
            : CustomerPresentation.error(
          e,
          fallback:
          'We could not review this import. Please try again.',
        );
        _rows = null;
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _import() async {
    if (_busy || _rows == null || _rows!.isEmpty) {
      return;
    }

    setState(() {
      _busy = true;
      _submitted = true;
      _error = null;
    });

    try {
      await widget.database.importCatalog(
        _rows!,
        _request,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = CustomerPresentation.error(
          e,
          fallback:
          'Import failed. Retry preserves this request.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSource =
        _fileRows != null || _text.text.trim().isNotEmpty;

    return PopScope(
      canPop: !_busy && !_submitted,
      child: Scaffold(
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: _background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _navy,
            ),
            onPressed: _busy || _submitted
                ? null
                : () => Navigator.pop(context),
          ),
          title: const Text(
            'Import products',
            style: TextStyle(
              color: _navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              16, 18, 16, 32,
            ),
            children: [
              const SizedBox(height: 6),

              _buildFilePicker(),

              if (_fileName != null) ...[
                const SizedBox(height: 10),
                _buildSelectedFile(),
              ],

              const SizedBox(height: 12),

              _buildInstructions(),

              const SizedBox(height: 16),

              _buildUpdateOption(),

              const SizedBox(height: 16),

              _buildCsvSection(),

              if (_error != null) ...[
                const SizedBox(height: 14),
                _buildError(),
              ],

              const SizedBox(height: 18),

              _primaryButton(
                title: _busy && !_submitted
                    ? 'Reviewing...'
                    : 'Review import',
                icon: Icons.fact_check_outlined,
                onPressed:
                _busy || _submitted || !hasSource
                    ? null
                    : _review,
              ),

              if (_rows != null) ...[
                const SizedBox(height: 22),
                _buildReview(),
              ],

              if (_submitted && _error != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'The previous import result is not confirmed. Retry the same request; do not create a new import.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bulk product import',
          style: TextStyle(
            color: _navy,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Add or update multiple products using a spreadsheet.',
          style: TextStyle(
            color: _muted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFilePicker() {
    return Material(
      color: _white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _busy || _submitted ? null : _chooseFile,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 17,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.upload_file_outlined,
                  color: _blue,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose CSV or Excel file',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Supported formats: .csv, .xlsx',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFile() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F7EF),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: _green,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _fileName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (!_busy && !_submitted)
            IconButton(
              tooltip: 'Remove selected file',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() {
                  _fileName = null;
                  _fileRows = null;
                  _text.clear();
                  _clearReview();
                });
              },
              icon: const Icon(
                Icons.close_rounded,
                color: _green,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            leading: const Icon(
              Icons.info_outline_rounded,
              color: _blue,
              size: 20,
            ),
            title: const Text(
              'Spreadsheet requirements',
              style: TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            trailing: Icon(
              _showInstructions
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: _muted,
            ),
            onTap: () {
              setState(() {
                _showInstructions = !_showInstructions;
              });
            },
          ),
          if (_showInstructions)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                15, 0, 15, 16,
              ),
              child: Text(
                'Required: Name, Product name, or Names.\n\n'
                    'Optional: Barcode, SKU, Category, Brand, Description, '
                    'Image URL, Unit, Selling price, Low stock threshold, '
                    'Initial quantity, Stock delta, Stock reason, Active, '
                    'Group name, Size, Color and Material.\n\n'
                    'Use Initial quantity for new products. Use Stock delta '
                    'and Stock reason for updates.\n\n'
                    'Blank prices preserve existing prices. New products '
                    'without prices remain pending until priced.\n\n'
                    'Common headings such as Price, Quantity, Stock, Part number and '
                    'Product code are accepted automatically. Each field may appear '
                    'only once. For Excel, format barcode and SKU columns as Text '
                    'before entering values with leading zeroes.\n\n'
                    'Every import must be reviewed before confirmation.',
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpdateOption() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.trailing,
        activeColor: _blue,
        title: const Text(
          'Update existing products',
          style: TextStyle(
            color: _navy,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Match products by barcode or SKU',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
          ),
        ),
        value: _updateExisting,
        onChanged: _busy || _submitted
            ? null
            : (value) {
          setState(() {
            _updateExisting = value ?? false;
            _rows = null;
          });
        },
      ),
    );
  }

  Widget _buildCsvSection() {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
            ),
            leading: const Icon(
              Icons.edit_note_rounded,
              color: _blue,
            ),
            title: const Text(
              'Paste CSV manually',
              style: TextStyle(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: const Text(
              'Optional alternative to uploading a file',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
            trailing: Icon(
              _showCsvEditor
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: _muted,
            ),
            onTap: _busy || _submitted
                ? null
                : () {
              setState(() {
                _showCsvEditor = !_showCsvEditor;
              });
            },
          ),
          if (_showCsvEditor)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                13, 0, 13, 14,
              ),
              child: TrexvenTextField(
                controller: _text,
                minLines: 4,
                maxLines: 9,
                enabled: !_busy && !_submitted,
                onChanged: (_) {
                  setState(() {
                    _rows = null;
                    _fileRows = null;
                    _fileName = null;
                    _error = null;
                  });
                },
                decoration: const TrexvenInputDecoration(
                  labelText: 'CSV products',
                  hintText:
                  'Product name,Barcode,Selling price,Initial quantity',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEDEF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFD44B52),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(
                color: Color(0xFFD44B52),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 49,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _blue,
          disabledBackgroundColor: _softBlue,
          disabledForegroundColor: _blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
        icon: _busy
            ? const SizedBox(
          width: 17,
          height: 17,
          child: Icon(Icons.more_horiz_rounded, size: 16),
        )
            : Icon(icon, size: 19),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildReview() {
    final rows = _rows!;

    final createCount = rows
        .where((row) => row['product_id'] == null)
        .length;

    final updateCount = rows.length - createCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Import review',
          style: TextStyle(
            color: _navy,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _reviewMetric(
                '${rows.length}',
                'Products',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _reviewMetric(
                '$createCount',
                'New',
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _reviewMetric(
                '$updateCount',
                'Updates',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _reviewProduct(rows[i]),
                if (i != rows.length - 1)
                  const Divider(
                    height: 1,
                    color: _border,
                    indent: 13,
                    endIndent: 13,
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _primaryButton(
          title: _submitted
              ? 'Retry same import'
              : 'Confirm import',
          icon: Icons.check_circle_outline_rounded,
          onPressed: _busy ? null : _import,
        ),
      ],
    );
  }

  Widget _reviewMetric(
      String value,
      String label,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _navy,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewProduct(
      Map<String, dynamic> row,
      ) {
    final isUpdate = row['product_id'] != null;

    final price = row['selling_price'] == null
        ? isUpdate
        ? 'Keep existing price'
        : 'Awaiting price'
        : CustomerPresentation.amount(
      row['selling_price'],
    );

    final stock = isUpdate
        ? 'Stock change: ${row['stock_delta'] ?? 0}'
        : 'Opening qty: ${row['initial_quantity'] ?? 0}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _blue,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['name']?.toString() ?? 'Product',
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${row['barcode'] ?? 'No barcode'} • $price',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$stock ${row['unit'] ?? 'piece'}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: isUpdate
                  ? const Color(0xFFFFF2DF)
                  : const Color(0xFFE6F7EF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isUpdate ? 'Update' : 'New',
              style: TextStyle(
                color: isUpdate
                    ? const Color(0xFFB86B13)
                    : _green,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
