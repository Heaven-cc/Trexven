import 'package:intl/intl.dart';

/// Display formatting only; amounts are never converted between currencies.
abstract final class BusinessCurrency {
  static String symbol(String? currency) {
    final code = (currency ?? 'NGN').trim().toUpperCase();
    return switch (code) {
      'NGN' => '₦',
      'GHS' => '₵',
      'XOF' => 'CFA',
      'USD' || 'CAD' || 'AUD' => String.fromCharCode(36),
      'EUR' => '€',
      'GBP' => '£',
      'KES' => 'KSh',
      'ZAR' => 'R',
      'INR' => '₹',
      'JPY' || 'CNY' => '¥',
      _ => code,
    };
  }
  static NumberFormat formatter(String? currency) {
    final code = (currency == null || currency.trim().isEmpty)
        ? 'NGN'
        : currency.trim().toUpperCase();
    final symbol = switch (code) {
      'NGN' => '₦',
      'GHS' => '₵',
      'XOF' => 'CFA ',
      'USD' => '\$',
      'CAD' => String.fromCharCode(36),
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
