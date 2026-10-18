import 'package:flutter_test/flutter_test.dart';
import 'package:odt/models/sale.dart';

void main() {
  test(
    'historical sale quantities preserve fractional numbers and numeric strings',
    () {
      for (final value in [2.5, '2.5', 0.125, '0.125', 2]) {
        final sale = Sale.fromMap({'quantity': value});
        expect(sale.quantity, num.parse(value.toString()));
        expect(sale.toMap()['quantity'], num.parse(value.toString()));
      }
    },
  );

  test('invalid historical quantities never display NaN or infinity', () {
    for (final value in [null, 'invalid', 'NaN', 'Infinity', double.infinity]) {
      expect(Sale.fromMap({'quantity': value}).quantity, 0);
    }
  });
}
