import 'package:intl/intl.dart';

/// Display formatting only; amounts are never converted between currencies.
abstract final class BusinessCurrency {
  static String symbol(String? currency) {
    final code = (currency ?? 'NGN').trim().toUpperCase();
    return switch (code) {
      'NGN' => '₦',
      'GHS' => '₵',
      'XOF' => 'CFA',
      'USD' || 'CAD' || 'AUD' => '\
    final code = (currency == null || currency.trim().isEmpty)
        ? 'NGN'
        : currency.trim().toUpperCase();
    final displaySymbol = switch (code) {
      'NGN' => '₦',
      'GHS' => '₵',
      'XOF' => 'CFA ',
      'USD' => '\$',
      'CAD' => '\,
      'AUD' => '\,
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
      symbol: displaySymbol,
      decimalDigits: code == 'XOF' || code == 'JPY' ? 0 : 2,
    );
  }
}
,
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
,
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
,
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
,
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
,
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
,
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
,
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
