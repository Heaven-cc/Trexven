import 'package:flutter_test/flutter_test.dart';
import 'package:odt/models/product.dart';

void main() {
  test(
    'active product contract excludes deferred cost and preserves zero selling price',
    () {
      final product = Product.fromMap({
        'id': 'p',
        'name': 'Free',
        'selling_price': 0,
        'quantity': 4,
        'cost_price': 83,
      });
      expect(product.price, 0);
      expect(product.stock, 4);
      expect(product.toMap().containsKey('cost_price'), isFalse);
      expect(product.isPricePending, isFalse);
    },
  );
  test(
    'unpriced product round trip preserves null rather than assigning a free selling price',
    () {
      final pending = Product.fromMap({
        'name': 'Pending',
        'selling_price': null,
        'quantity': 0,
      });
      expect(pending.isPricePending, isTrue);
      expect(pending.toMap()['selling_price'], isNull);
    },
  );
}
