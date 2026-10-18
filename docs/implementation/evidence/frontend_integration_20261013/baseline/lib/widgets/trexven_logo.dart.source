
import 'package:flutter/material.dart';

class TrexvenLogo extends StatelessWidget {
  final double size;
  final double opacity;

  const TrexvenLogo({
    super.key,
    this.size = 58,
    this.opacity = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Image.asset(
        'assets/images/trexven_logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.storefront_rounded,
            size: size * 0.6,
            color: const Color(0xFF2864F0),
          );
        },
      ),
    );
  }
}
