import 'package:flutter/material.dart';
import 'app_sizing.dart';

@immutable
class TrexvenColors extends ThemeExtension<TrexvenColors> {
  final Color? brandBlue;
  final Color? brandDark;
  final Color? success;
  final Color? warning;
  final Color? error;
  final Color? border;
  final Color? muted;
  final Color? cardBackground;

  const TrexvenColors({
    required this.brandBlue,
    required this.brandDark,
    required this.success,
    required this.warning,
    required this.error,
    required this.border,
    required this.muted,
    required this.cardBackground,
  });

  @override
  TrexvenColors copyWith({
    Color? brandBlue,
    Color? brandDark,
    Color? success,
    Color? warning,
    Color? error,
    Color? border,
    Color? muted,
    Color? cardBackground,
  }) {
    return TrexvenColors(
      brandBlue: brandBlue ?? this.brandBlue,
      brandDark: brandDark ?? this.brandDark,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      cardBackground: cardBackground ?? this.cardBackground,
    );
  }

  @override
  TrexvenColors lerp(ThemeExtension<TrexvenColors>? other, double t) {
    if (other is! TrexvenColors) return this;
    return TrexvenColors(
      brandBlue: Color.lerp(brandBlue, other.brandBlue, t),
      brandDark: Color.lerp(brandDark, other.brandDark, t),
      success: Color.lerp(success, other.success, t),
      warning: Color.lerp(warning, other.warning, t),
      error: Color.lerp(error, other.error, t),
      border: Color.lerp(border, other.border, t),
      muted: Color.lerp(muted, other.muted, t),
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t),
    );
  }
}

extension TrexvenTheme on ThemeData {
  TrexvenColors get trexvenColors => extension<TrexvenColors>()!;
}

class AppTheme {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF0F172A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        surface: Colors.white,
        onSurface: primaryDark,
        outline: const Color(0xFFE2E8F0),
      ),
      fontFamily: 'Roboto',
      extensions: [
        const TrexvenColors(
          brandBlue: primaryBlue,
          brandDark: primaryDark,
          success: Color(0xFF22C55E),
          warning: Color(0xFFF59E0B),
          error: Color(0xFFEF4444),
          border: Color(0xFFE2E8F0),
          muted: Color(0xFF64748B),
          cardBackground: Colors.white,
        ),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: primaryDark),
        titleTextStyle: TextStyle(
          color: primaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: AppSizing.fieldPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, AppSizing.buttonHeight),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: primaryDark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: primaryBlue,
        primary: primaryBlue,
        surface: const Color(0xFF1E293B),
        onSurface: Colors.white,
        outline: const Color(0xFF334155),
      ),
      fontFamily: 'Roboto',
      extensions: [
        const TrexvenColors(
          brandBlue: primaryBlue,
          brandDark: primaryDark,
          success: Color(0xFF22C55E),
          warning: Color(0xFFF59E0B),
          error: Color(0xFFEF4444),
          border: Color(0xFF334155),
          muted: Color(0xFF94A3B8),
          cardBackground: Color(0xFF1E293B),
        ),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: AppSizing.fieldPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, AppSizing.buttonHeight),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
