import 'package:intl/intl.dart';

/// Display formatting only; amounts are never converted between currencies.
abstract final class BusinessCurrency {
  static NumberFormat formatter(String? currency) {
    final code = (currency == null || currency.trim().isEmpty)
        ? 'NGN'
        : currency.trim().toUpperCase();
    final symbol = switch (code) {
      'NGN' => '₦',
      'GHS' => 'GH₵',
      'XOF' => 'CFA ',
      'USD' => '\$',
      'CAD' => 'CA\$',
      'AUD' => 'A\$',
      'EUR' => '€',
      'GBP' => '£',
      'KES' => 'KSh ',
      'ZAR' => 'R ',
      'INR' => '₹',
      'JPY' || 'CNY' => '¥',
      _ => '$code ',
    };
    return NumberFormat.currency(
      locale: 'en',
      name: code,
      symbol: symbol,
      decimalDigits: code == 'XOF' || code == 'JPY' ? 0 : 2,
    );
  }
}
