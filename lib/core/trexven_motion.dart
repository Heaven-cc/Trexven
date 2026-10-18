import 'package:flutter/material.dart';

/// Centralized motion tokens and animation system for TREXVEN.
abstract final class TrexvenMotion {
  /// Fast interactions (button presses, toggles, small state changes)
  static const Duration durationFast = Duration(milliseconds: 140);

  /// Standard transitions (card expansion, tab switches, dialogs)
  static const Duration durationStandard = Duration(milliseconds: 220);

  /// Entrance transitions (screen transitions, modal bottom sheets)
  static const Duration durationEntrance = Duration(milliseconds: 320);

  /// Curves
  static const Curve curveStandard = Curves.easeInOutCubic;
  static const Curve curveEmphasized = Curves.fastOutSlowIn;
  static const Curve curveDecelerate = Curves.easeOutCubic;
}

/// A wrapper widget that provides interactive press scale feedback for buttons and cards.
class TrexvenAnimatedPress extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const TrexvenAnimatedPress({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.97,
  });

  @override
  State<TrexvenAnimatedPress> createState() => _TrexvenAnimatedPressState();
}

class _TrexvenAnimatedPressState extends State<TrexvenAnimatedPress> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: TrexvenMotion.durationFast,
        curve: TrexvenMotion.curveStandard,
        child: widget.child,
      ),
    );
  }
}

/// Custom page route transition providing smooth fade and subtle slide.
class TrexvenPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  TrexvenPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: TrexvenMotion.durationEntrance,
          reverseTransitionDuration: TrexvenMotion.durationStandard,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: TrexvenMotion.curveDecelerate,
            );
            final slideAnimation = Tween<Offset>(
              begin: const Offset(0.04, 0.0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: TrexvenMotion.curveEmphasized,
              ),
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: SlideTransition(
                position: slideAnimation,
                child: child,
              ),
            );
          },
        );
}
