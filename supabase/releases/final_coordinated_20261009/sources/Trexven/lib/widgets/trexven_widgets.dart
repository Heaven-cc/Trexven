import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../core/app_sizing.dart';

class TrexvenPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;
  final BorderRadius? borderRadius;
  final Color? rippleColor;

  const TrexvenPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleAmount = 0.98,
    this.borderRadius,
    this.rippleColor,
  });

  @override
  State<TrexvenPressable> createState() => _TrexvenPressableState();
}

class _TrexvenPressableState extends State<TrexvenPressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleAmount,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandBlue = theme.trexvenColors.brandBlue ?? const Color(0xFF2563EB);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          fit: StackFit.passthrough, // Let the children determine the size
          children: [
            widget.child,
            if (widget.onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: widget.borderRadius ?? BorderRadius.zero,
                    highlightColor: (widget.rippleColor ?? brandBlue)
                        .withOpacity(0.05),
                    splashColor: (widget.rippleColor ?? brandBlue).withOpacity(
                      0.1,
                    ),
                    onTap: widget.onTap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TrexvenTapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final bool hasBorder;
  final double? width;
  final double? height;

  const TrexvenTapCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius = 20,
    this.backgroundColor,
    this.hasBorder = true,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.trexvenColors.border ?? const Color(0xFFE2E8F0);
    final bgColor =
        backgroundColor ?? theme.trexvenColors.cardBackground ?? Colors.white;

    return TrexvenPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: hasBorder ? Border.all(color: borderColor) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.2 : 0.02,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class TrexvenSettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color iconColor;

  const TrexvenSettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor = const Color(0xFF2563EB),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconBgColor = iconColor.withOpacity(0.1);
    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.trexvenColors.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.trexvenColors.muted?.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrexvenButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;

  const TrexvenButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                foregroundColor ?? Colors.white,
              ),
            ),
          )
        else ...[
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Flexible(child: Text(text, textAlign: TextAlign.center)),
        ],
      ],
    );

    return SizedBox(
      width: width ?? double.infinity,
      child: TrexvenPressable(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(14),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, AppSizing.buttonHeight),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            backgroundColor: backgroundColor ?? theme.colorScheme.primary,
            foregroundColor: foregroundColor ?? Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: content,
        ),
      ),
    );
  }
}
