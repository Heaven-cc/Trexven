import 'package:flutter/material.dart';
import 'tokens.dart';

abstract final class TrexvenTheme {
  static const primaryBlue = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF0F172A);
  static ThemeData get lightTheme => build(Brightness.light);
  static ThemeData get signatureTheme => build(Brightness.dark);
  static ThemeData get darkTheme => build(Brightness.dark, pureBlack: true);

  static ThemeData build(Brightness brightness, {bool pureBlack = false}) {
    final dark = brightness == Brightness.dark;
    final surface = pureBlack && dark
        ? const Color(0xFF141414)
        : dark ? const Color(0xFF1E293B) : Colors.white;
    final background = pureBlack && dark
        ? Colors.black
        : dark ? primaryDark : const Color(0xFFF5F7FC);
    final ink = dark ? const Color(0xFFF1F5F9) : primaryDark;
    final muted = dark ? const Color(0xFFB0BED0) : const Color(0xFF526179);
    final outline = pureBlack && dark
        ? const Color(0xFF383838)
        : dark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
    final error = dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFF8EB5FF) : primaryBlue,
          onPrimary: dark ? primaryDark : Colors.white,
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: muted,
          surfaceContainerHighest: pureBlack && dark
              ? const Color(0xFF242424)
              : dark ? const Color(0xFF29384F) : const Color(0xFFF1F5F9),
          outline: outline,
          outlineVariant: outline,
          error: error,
          onError: dark ? primaryDark : Colors.white,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TrexvenRadii.field),
    );
    // All Owner App inputs, including popups and mini forms, retain a visible
    // boundary before focus. Avoid white-on-white fields in light dialogs.
    final fieldFill = dark ? scheme.surfaceContainerHighest : const Color(0xFFF1F5F9);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TrexvenRadii.field),
      borderSide: BorderSide(color: outline.withValues(alpha: .7)),
    );
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(48, TrexvenSpacing.buttonHeight),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(shape),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      elevation: const WidgetStatePropertyAll(0),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      extensions: [
        TrexvenColors(
          brandBlue: scheme.primary,
          brandDark: ink,
          success: dark ? const Color(0xFF86EFAC) : const Color(0xFF16834A),
          warning: dark ? const Color(0xFFFCD34D) : const Color(0xFFB76A0A),
          error: error,
          border: outline,
          muted: muted,
          cardBackground: surface,
        ),
      ],
      textTheme: base.textTheme.copyWith(
        headlineLarge: TrexvenTypography.display.copyWith(color: ink),
        headlineSmall: TrexvenTypography.title.copyWith(color: ink),
        titleLarge: TrexvenTypography.section.copyWith(color: ink),
        titleMedium: TrexvenTypography.label.copyWith(color: ink),
        bodyLarge: TrexvenTypography.input.copyWith(color: ink),
        bodyMedium: TrexvenTypography.body.copyWith(color: ink),
        bodySmall: TrexvenTypography.caption.copyWith(color: muted),
        labelLarge: TrexvenTypography.label.copyWith(color: ink),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TrexvenTypography.section.copyWith(color: ink),
        iconTheme: IconThemeData(color: ink, size: 22),
      ),
      iconTheme: IconThemeData(color: muted, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        isDense: true,
        contentPadding: TrexvenSpacing.fieldPadding,
        border: fieldBorder,
        enabledBorder: fieldBorder,
        disabledBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: outline.withValues(alpha: .45)),
        ),
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        errorBorder: fieldBorder.copyWith(borderSide: BorderSide(color: error)),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: error, width: 1.2),
        ),
        labelStyle: TrexvenTypography.label.copyWith(color: ink),
        floatingLabelStyle: TrexvenTypography.label.copyWith(color: scheme.primary),
        hintStyle: TrexvenTypography.input.copyWith(color: muted),
        errorStyle: TrexvenTypography.caption.copyWith(color: error),
        errorMaxLines: 12,
        helperStyle: TrexvenTypography.caption.copyWith(color: muted),
        helperMaxLines: 12,
        prefixIconColor: muted,
        suffixIconColor: muted,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: .22),
        selectionHandleColor: scheme.primary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: button.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: .12)
                : scheme.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: .38)
                : scheme.onPrimary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: button),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.copyWith(
          side: const WidgetStatePropertyAll(BorderSide.none),
          backgroundColor: WidgetStatePropertyAll(
            scheme.primary.withValues(alpha: .08),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: button),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
          shape: WidgetStatePropertyAll(shape),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: shape,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
      ),
      // Unified Owner App overlays, including legacy Material dialogs.
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.dialog),
          side: BorderSide(color: outline.withValues(alpha: .28)),
        ),
        titleTextStyle: TrexvenTypography.section.copyWith(
          color: ink,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TrexvenTypography.body.copyWith(color: muted),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        elevation: 0,
        dragHandleColor: muted.withValues(alpha: .45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TrexvenRadii.dialog + 2),
          ),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.dialog),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        dialBackgroundColor: scheme.surfaceContainerHighest,
        dialHandColor: scheme.primary,
        hourMinuteColor: scheme.surfaceContainerHighest,
        hourMinuteTextColor: ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.dialog),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TrexvenRadii.field),
              side: BorderSide(color: outline.withValues(alpha: .28)),
            ),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: muted,
        labelStyle: TrexvenTypography.label,
        unselectedLabelStyle: TrexvenTypography.label,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        indicatorColor: scheme.primary.withValues(alpha: .10),
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TrexvenTypography.caption.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.card),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: outline.withValues(alpha: .4),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: TrexvenTypography.caption.copyWith(color: ink),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF29384F) : primaryDark,
        contentTextStyle: TrexvenTypography.body.copyWith(color: Colors.white),
        insetPadding: const EdgeInsets.all(16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.field),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        textStyle: TrexvenTypography.body.copyWith(color: ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TrexvenRadii.field),
          side: BorderSide(color: outline.withValues(alpha: .28)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TrexvenTypography.input.copyWith(color: ink),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF29384F) : primaryDark,
          borderRadius: BorderRadius.circular(TrexvenRadii.status),
        ),
        textStyle: TrexvenTypography.caption.copyWith(color: Colors.white),
      ),
    );
  }
}
