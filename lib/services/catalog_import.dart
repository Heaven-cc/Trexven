import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

/// A reviewed CSV import. Barcodes remain text, including leading zeroes.
class CatalogImport {
  static String _header(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
    return normalized == 'product_name' ? 'name' : normalized;
  }

  static List<Map<String, dynamic>> parseExcel(
    List<int> bytes, {
    String? sheetName,
  }) {
    final workbook = Excel.decodeBytes(bytes);
    final sheets = workbook.tables.values
        .where(
          (s) => s.rows.any((row) => row.any((cell) => cell?.value != null)),
        )
        .toList();
    if (sheets.isEmpty) {
      throw const FormatException('No product worksheet found.');
    }
    if (sheetName == null && sheets.length != 1) {
      throw const FormatException('Use one product worksheet per import.');
    }
    final sheet = sheetName == null
        ? sheets.single
        : workbook.tables[sheetName];
    if (sheet == null) throw const FormatException('Worksheet not found.');
    final grid = <List<String>>[];
    List<String>? headers;
    for (final source in sheet.rows) {
      if (source.every((cell) => cell?.value == null)) continue;
      final row = <String>[];
      for (var i = 0; i < source.length; i++) {
        final value = source[i]?.value;
        if (headers != null &&
            i < headers.length &&
            ['barcode', 'sku'].contains(headers[i]) &&
            value != null &&
            value is! TextCellValue) {
          throw const FormatException(
            'Barcode and SKU cells must be text to preserve leading zeroes.',
          );
        }
        row.add(switch (value) {
          null => '',
          TextCellValue() => value.value.toString(),
          IntCellValue() => value.value.toString(),
          DoubleCellValue() => value.value.toString(),
          BoolCellValue() => value.value.toString(),
          _ => throw const FormatException(
            'Formulas and date cells are not product values.',
          ),
        });
      }
      if (headers == null) {
        headers = row.map(_header).toList();
      } else {
        while (row.length < headers.length) {
          row.add('');
        }
      }
      grid.add(row);
    }
    return parse(const ListToCsvConverter().convert(grid));
  }

  static const columns = {
    'name',
    'barcode',
    'sku',
    'category',
    'description',
    'image_url',
    'unit',
    'selling_price',
    'low_stock_threshold',
    'initial_quantity',
    'active',
    'group_name',
    'size',
    'color',
    'material',
    'stock_delta',
    'stock_reason',
  };

  static List<Map<String, dynamic>> parse(String text) {
    if (text.startsWith('\ufeff')) text = text.substring(1);
    final cells = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(text.replaceAll('\r\n', '\n'), eol: '\n');
    if (cells.length < 2) {
      throw const FormatException('Include a header and at least one product.');
    }
    final headers = cells.first.map((v) => _header(v.toString())).toList();
    if (headers.toSet().length != headers.length ||
        !headers.contains('name') ||
        headers.any((h) => !columns.contains(h))) {
      throw const FormatException(
        'Use unique supported headers, including name.',
      );
    }
    final rows = <Map<String, dynamic>>[];
    final barcodes = <String>{};
    final skus = <String>{};
    for (var i = 1; i < cells.length; i++) {
      if (cells[i].every((v) => v.toString().trim().isEmpty)) continue;
      if (cells[i].length != headers.length) {
        throw FormatException('Row ${i + 1}: column count differs.');
      }
      final row = <String, dynamic>{};
      for (var c = 0; c < headers.length; c++) {
        final key = headers[c];
        final value = cells[i][c].toString().trim();
        if (value.isEmpty) continue;
        if ([
          'selling_price',
          'low_stock_threshold',
          'initial_quantity',
          'stock_delta',
        ].contains(key)) {
          final number = num.tryParse(value);
          if (number == null ||
              !number.isFinite ||
              (number < 0 && key != 'stock_delta') ||
              (number * 1000 - (number * 1000).round()).abs() > 0.0000001) {
            throw FormatException('Row ${i + 1}: invalid $key.');
          }
          if (key == 'selling_price' &&
              (number * 100 - (number * 100).round()).abs() > 0.0000001) {
            throw FormatException(
              'Row ${i + 1}: price supports two decimal places.',
            );
          }
          row[key] = number;
        } else if (key == 'active') {
          if (!['true', 'false'].contains(value.toLowerCase())) {
            throw FormatException(
              'Row ${i + 1}: active must be true or false.',
            );
          }
          row[key] = value.toLowerCase() == 'true';
        } else {
          row[key] = value;
        }
      }
      if ((row['name'] ?? '').toString().isEmpty) {
        throw FormatException('Row ${i + 1}: name is required.');
      }
      for (final key in ['barcode', 'sku']) {
        final value = row[key] as String?;
        if (value != null && !(key == 'barcode' ? barcodes : skus).add(value)) {
          throw FormatException('Row ${i + 1}: duplicate $key.');
        }
      }
      if (!const {
        'piece',
        'kg',
        'g',
        'litre',
        'ml',
        'metre',
        'cm',
      }.contains(row['unit'] ?? 'piece')) {
        throw FormatException('Row ${i + 1}: unsupported unit.');
      }
      if (!const {
            'kg',
            'g',
            'litre',
            'ml',
            'metre',
            'cm',
          }.contains(row['unit'] ?? 'piece') &&
          (row['initial_quantity'] as num? ?? 0) % 1 != 0) {
        throw FormatException('Row ${i + 1}: pieces require whole quantities.');
      }
      if (row.containsKey('stock_delta') &&
          row['stock_delta'] != 0 &&
          (row['stock_reason'] ?? '').toString().trim().isEmpty) {
        throw FormatException('Row ${i + 1}: stock change requires a reason.');
      }
      rows.add(row);
    }
    if (rows.isEmpty) throw const FormatException('No product rows found.');
    return rows;
  }
}
