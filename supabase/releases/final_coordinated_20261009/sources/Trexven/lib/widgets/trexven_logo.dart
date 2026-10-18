import 'package:flutter/material.dart';

class TrexvenLogo extends StatelessWidget {
  final double size;

  const TrexvenLogo({
    super.key,
    this.size = 58,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(size * .27),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .27),
        child: Image.asset(
          'assets/images/trexven_logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Icon(
                Icons.storefront_rounded,
                size: size * 0.6,
                color: Colors.white,
              ),
            );
          },
        ),
      ),
    );
  }
}
