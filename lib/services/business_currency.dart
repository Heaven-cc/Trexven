import 'package:trexven_operations/trexven_operations.dart';

/// Display only. Always uses the saved business or billing currency.
abstract final class BusinessCurrency {
  static BusinessMoneyFormatter formatter(String? currency) =>
      BusinessMoneyFormatter(currency);
}

class BusinessMoneyFormatter {
  final String? currency;
  const BusinessMoneyFormatter(this.currency);
  String format(num amount) => CustomerPresentation.money(amount, currency: currency);
}
