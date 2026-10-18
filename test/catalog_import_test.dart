import 'package:flutter_test/flutter_test.dart';
import 'package:odt/services/catalog_import.dart';
import 'package:odt/models/product.dart';
import 'package:excel/excel.dart';

void main() {
  test(
    'Friendly import headers preserve the legacy payload, zero prices and barcode text',
    () {
      final rows = CatalogImport.parse(
        'Product name,Barcode,Selling price,Initial quantity,Unit\nSample,00123,0,1.125,litre',
      );
      expect(rows.single, {
        'name': 'Sample',
        'barcode': '00123',
        'selling_price': 0,
        'initial_quantity': 1.125,
        'unit': 'litre',
      });
    },
  );
  test('Excel import preserves text barcodes and precise prices', () {
    final book = Excel.createExcel();
    final sheet = book[book.getDefaultSheet()!];
    sheet.appendRow([
      TextCellValue('name'),
      TextCellValue('barcode'),
      TextCellValue('unit'),
      TextCellValue('initial_quantity'),
      TextCellValue('selling_price'),
    ]);
    sheet.appendRow([
      TextCellValue('Oil'),
      TextCellValue('00123'),
      TextCellValue('litre'),
      DoubleCellValue(1.125),
      DoubleCellValue(12.5),
    ]);
    final rows = CatalogImport.parseExcel(book.encode()!);
    expect(rows.single['barcode'], '00123');
    expect(rows.single['initial_quantity'], 1.125);
  });
  test('Excel numeric barcode rejects potentially lost leading zeroes', () {
    final book = Excel.createExcel();
    final sheet = book[book.getDefaultSheet()!];
    sheet.appendRow([TextCellValue('name'), TextCellValue('barcode')]);
    sheet.appendRow([TextCellValue('Oil'), IntCellValue(123)]);
    expect(
      () => CatalogImport.parseExcel(book.encode()!),
      throwsFormatException,
    );
  });
  test(
    'quoted CSV preserves manufacturer leading zeroes and measurable stock',
    () {
      final rows = CatalogImport.parse(
        'name,barcode,unit,initial_quantity,selling_price\r\n"Oil, blue",00123,litre,1.125,12.50',
      );
      expect(rows.single['name'], 'Oil, blue');
      expect(rows.single['barcode'], '00123');
      expect(rows.single['initial_quantity'], 1.125);
      expect(rows.single['selling_price'], 12.5);
    },
  );
  test(
    'blank import prices remain absent and explicit free price remains zero',
    () {
      final rows = CatalogImport.parse('name,selling_price\nPending,\nFree,0');
      expect(rows.first.containsKey('selling_price'), false);
      expect(rows.last['selling_price'], 0);
    },
  );
  test('duplicate barcodes and SKUs reject before mutation', () {
    expect(
      () => CatalogImport.parse('name,barcode\nA,123\nB,123'),
      throwsFormatException,
    );
    expect(
      () => CatalogImport.parse('name,sku\nA,S\nB,S'),
      throwsFormatException,
    );
  });
  test(
    'cost, malformed headers, quantity precision and fractional pieces reject',
    () {
      for (final text in [
        'name,cost_price\nA,1',
        'name,name\nA,B',
        'name,initial_quantity\nA,0.25',
        'name,unit,initial_quantity\nA,kg,0.0001',
        'name,selling_price\nA,NaN',
        'name,selling_price\nA,1.001',
      ]) {
        expect(
          () => CatalogImport.parse(text),
          throwsFormatException,
          reason: text,
        );
      }
    },
  );
  test(
    'grouped product preserves precise quantity and low stock includes zero',
    () {
      final p = Product.fromMap({
        'id': 'variant',
        'name': 'Oil',
        'unit': 'litre',
        'quantity': 0.125,
        'selling_price': 3,
        'catalog_group_id': 'parent',
        'variant_attributes': {'size': 'Large'},
        'low_stock_threshold': 0.5,
      });
      expect(p.stock, 0.125);
      expect(p.catalogGroupId, 'parent');
      expect(p.toMap()['variant_attributes'], {'size': 'Large'});
      expect(p.isLowStock, true);
      expect(Product(name: 'Zero', price: 0, stock: 0).isLowStock, true);
      expect(
        Product(
          name: 'Pending',
          price: 0,
          stock: 0,
          isPricePending: true,
        ).isLowStock,
        false,
      );
      expect(
        Product(name: 'Archived', price: 2, stock: 0, active: false).isLowStock,
        false,
      );
    },
  );
}
