import 'package:flutter/material.dart';

/// Shared spacing and minimum sizes; content may grow with system text size.
abstract final class AppSizing {
  static const pagePadding = EdgeInsets.fromLTRB(16, 16, 16, 24);
  static const cardPadding = EdgeInsets.all(16);
  static const fieldPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );
  static const double pageTitle = 24;
  static const double sectionGap = 16;
  static const double fieldGap = 16;
  static const double buttonHeight = 56;
  static const double quantityTarget = 56;
}
