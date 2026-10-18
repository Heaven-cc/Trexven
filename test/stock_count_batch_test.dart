import 'package:flutter_test/flutter_test.dart';
import 'package:trexven_operations/src/stock_count_batch.dart';

void main() {
  final products = [
    {'id': 'p', 'barcode': 'rice', 'name': 'Rice'},
    {'id': 'q', 'barcode': 'milk', 'name': 'Milk'},
  ];
  final counts = [
    {'product_id': 'p', 'version': 7},
    {'product_id': 'q', 'version': 9},
  ];
  test('Camera batch accumulates lines and preserves captured versions', () {
    final batch = StockCountBatch();
    final rice = batch.resolve('rice', products, counts);
    batch.set(rice, '0.1', add: true);
    batch.set(rice, '0.2', add: true);
    batch.set(batch.resolve('milk', products, counts), '4');
    expect(batch.lines['p'], {
      'product_id': 'p',
      'version': 7,
      'quantity': 0.3,
    });
    expect(batch.lines['q']!['version'], 9);
    batch.set(rice, '2.5');
    expect(batch.lines['p']!['quantity'], 2.5);
  });
  test(
    'Missing, ambiguous or out-of-session barcode and invalid quantity rejected',
    () {
      final batch = StockCountBatch();
      expect(
        () => batch.resolve('missing', products, counts),
        throwsStateError,
      );
      expect(
        () => batch.resolve('rice', [...products, products.first], counts),
        throwsStateError,
      );
      expect(() => batch.resolve('rice', products, []), throwsStateError);
      expect(() => batch.set(counts.first, '2.0001'), throwsFormatException);
      expect(() => batch.set(counts.first, '-1'), throwsFormatException);
      expect(batch.lines, isEmpty);
    },
  );
}
