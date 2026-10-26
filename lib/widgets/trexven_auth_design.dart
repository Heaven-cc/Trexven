import 'dart:ui' as ui;

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trexven_design_system/trexven_design_system.dart';
import '../core/trexven_motion.dart';

/// Dynamic authentication colors supporting light & dark themes.
class TrexvenAuthColors {
  const TrexvenAuthColors._();

  static Color navy(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFF8FAFC)
          : const Color(0xFF0F172A);

  static const blue = Color(0xFF2864F0);

  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF94A3B8)
          : const Color(0xFF475569);

  static Color border(BuildContext context) => Theme.of(context).colorScheme.outlineVariant;

  static Color fieldFill(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHighest;

  static Color cardBg(BuildContext context) => Theme.of(context).colorScheme.surface;
}

/// Dynamic, responsive shell with 3D frosted T backdrop.
class TrexvenAuthShell extends StatelessWidget {
  final Widget child;
  const TrexvenAuthShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? (theme.scaffoldBackgroundColor == Colors.black
                          ? const [Color(0xFF000000), Color(0xFF101010), Color(0xFF000000), Color(0xFF080808)]
                          : const [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0B0F19), Color(0xFF111827)])
                      : const [
                          Color(0xFFDFEDFF),
                          Color(0xFFF9FBFF),
                          Colors.white,
                          Color(0xFFE9F1FF),
                        ],
                  stops: const [0, .36, .66, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _FrostedTPainter(isDark: isDark)),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _FrostedTPainter extends CustomPainter {
  final bool isDark;
  const _FrostedTPainter({this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final top = Path()
      ..moveTo(-.28 * w, -.03 * h)
      ..lineTo(1.04 * w, .16 * h)
      ..quadraticBezierTo(1.10 * w, .18 * h, 1.02 * w, .26 * h)
      ..lineTo(.81 * w, .46 * h)
      ..lineTo(.08 * w, .28 * h)
      ..quadraticBezierTo(.03 * w, .27 * h, -.01 * w, .22 * h)
      ..close();

    final middle = Path()
      ..moveTo(.18 * w, .27 * h)
      ..lineTo(.52 * w, .35 * h)
      ..lineTo(.52 * w, .82 * h)
      ..quadraticBezierTo(.52 * w, .85 * h, .49 * w, .84 * h)
      ..lineTo(.18 * w, .72 * h)
      ..close();

    final right = Path()
      ..moveTo(.52 * w, .35 * h)
      ..lineTo(.82 * w, .45 * h)
      ..lineTo(.52 * w, .79 * h)
      ..close();

    void drawGlass(Path path, List<Color> colors) {
      final bounds = path.getBounds();
      final stops = List.generate(
        colors.length,
        (i) => i / (colors.length - 1),
      );
      final fill = Paint()
        ..shader = ui.Gradient.linear(
          bounds.topLeft,
          bounds.bottomRight,
          colors,
          stops,
        );
      canvas.drawPath(path, fill);
      final edgeGlow = Paint()
        ..color = (isDark ? Colors.blue.shade300 : Colors.white).withValues(alpha: isDark ? .18 : .58)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5);
      canvas.drawPath(path, edgeGlow);
      final edge = Paint()
        ..color = (isDark ? Colors.blue.shade200 : Colors.white).withValues(alpha: isDark ? .25 : .65)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, edge);
    }

    drawGlass(top, [
      const Color(0xFFB5DCFF).withValues(alpha: isDark ? .15 : .53),
      const Color(0xFFC1D9FF).withValues(alpha: isDark ? .10 : .35),
      const Color(0xFF8CBAFF).withValues(alpha: isDark ? .08 : .27),
    ]);
    drawGlass(middle, [
      const Color(0xFFB4D8FF).withValues(alpha: isDark ? .10 : .32),
      const Color(0xFF8EBBFF).withValues(alpha: isDark ? .05 : .19),
    ]);
    drawGlass(right, [
      const Color(0xFFB5E4FF).withValues(alpha: isDark ? .12 : .42),
      const Color(0xFFB5D1FF).withValues(alpha: isDark ? .05 : .17),
    ]);
  }

  @override
  bool shouldRepaint(covariant _FrostedTPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class TrexvenAuthBrand extends StatelessWidget {
  final double size;
  const TrexvenAuthBrand({super.key, this.size = 82});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/trexven_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            Icons.storefront_rounded,
            size: size * .7,
            color: TrexvenAuthColors.blue,
          ),
        ),
        const SizedBox(height: 11),
        Text(
          'TREXVEN',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: TrexvenAuthColors.navy(context),
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

class TrexvenAuthCard extends StatelessWidget {
  final Widget child;
  const TrexvenAuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: TrexvenAuthColors.cardBg(context).withValues(alpha: isDark ? .92 : .88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : Colors.white.withValues(alpha: .88),
              width: 1.2,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// High-contrast, dynamic-theme auth input field.
class TrexvenAuthField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final Widget prefixIcon;
  final Widget? suffixIcon;
  final BoxConstraints? prefixIconConstraints;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const TrexvenAuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    required this.prefixIcon,
    this.suffixIcon,
    this.prefixIconConstraints,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {

    OutlineInputBorder fieldBorder(Color color, double width) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TrexvenTextFormField(
      controller: controller,
      label: label,
      showLabel: true,
      gap: 0,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      autocorrect: !obscureText,
      enableSuggestions: !obscureText,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: TrexvenAuthColors.muted(context),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: prefixIcon,
        prefixIconConstraints: prefixIconConstraints,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: TrexvenAuthColors.fieldFill(context),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 17,
        ),
        border: fieldBorder(TrexvenAuthColors.border(context), 1),
        enabledBorder: fieldBorder(TrexvenAuthColors.border(context), 1),
        focusedBorder: fieldBorder(TrexvenAuthColors.blue, 1.6),
        errorBorder: fieldBorder(const Color(0xFFD64545), 1),
        focusedErrorBorder: fieldBorder(const Color(0xFFD64545), 1.6),
      ),
    );
  }
}

/// Specialized phone input field with country flag picker.
class TrexvenAuthPhoneField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final ValueChanged<Country>? onCountryChanged;

  const TrexvenAuthPhoneField({
    super.key,
    this.label = 'Phone number',
    this.hint = 'Enter your phone number',
    required this.controller,
    this.enabled = true,
    this.validator,
    this.onCountryChanged,
  });

  @override
  State<TrexvenAuthPhoneField> createState() => _TrexvenAuthPhoneFieldState();
}

class _TrexvenAuthPhoneFieldState extends State<TrexvenAuthPhoneField> {
  Country _selectedCountry = Country.parse('NG');

  void _selectCountry() {
    if (!widget.enabled) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        textStyle: TextStyle(color: isDark ? Colors.white : Colors.black87),
        borderRadius: BorderRadius.circular(20),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          prefixIcon: const Icon(Icons.search_rounded),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      onSelect: (Country country) {
        setState(() {
          _selectedCountry = country;
        });
        widget.onCountryChanged?.call(country);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return TrexvenAuthField(
      label: widget.label,
      hint: widget.hint,
      controller: widget.controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.phone,
      prefixIconConstraints: const BoxConstraints(minWidth: 100, minHeight: 48),
      prefixIcon: InkWell(
        onTap: _selectCountry,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.phone_outlined,
                color: TrexvenAuthColors.muted(context),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _selectedCountry.flagEmoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: TrexvenAuthColors.muted(context),
                size: 18,
              ),
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 20,
                color: TrexvenAuthColors.border(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      validator: widget.validator,
    );
  }
}

class TrexvenAuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showArrow;

  const TrexvenAuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return TrexvenAnimatedPress(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled || loading ? 1 : .55,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFF2168F4), Color(0xFF257FFF)],
              ),
              borderRadius: BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: TrexvenAuthColors.blue.withValues(alpha: .17),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: Icon(Icons.more_horiz_rounded, size: 16),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (showArrow) ...[
                          const SizedBox(width: 13),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 21,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class TrexvenAuthSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const TrexvenAuthSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TrexvenAnimatedPress(
      onTap: onPressed,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: isDark
                ? const Color(0xFF334155).withValues(alpha: .9)
                : const Color(0xFFE4ECFC).withValues(alpha: .9),
            foregroundColor: TrexvenAuthColors.navy(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(23),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: TrexvenAuthColors.navy(context),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class TrexvenAuthBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const TrexvenAuthBackButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 5, 0, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: .45),
          shape: CircleBorder(
            side: BorderSide(
              color: (isDark ? const Color(0xFF475569) : Colors.white).withValues(alpha: .85),
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: TrexvenAuthColors.navy(context),
              size: 19,
            ),
            onPressed: onPressed ?? () => Navigator.maybePop(context),
          ),
        ),
      ),
    );
  }
}

class TrexvenAuthOrDivider extends StatelessWidget {
  const TrexvenAuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFD9E2F0))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: TrexvenAuthColors.muted(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFD9E2F0))),
      ],
    );
  }
}
