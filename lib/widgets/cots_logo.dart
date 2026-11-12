import 'package:flutter/material.dart';

/// The shared COTS Monitor brand mark used throughout the app.
class CotsLogo extends StatelessWidget {
  const CotsLogo({super.key, this.size = 40});

  static const String assetPath = 'assets/images/cots_logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        semanticLabel: 'COTS Monitor logo',
      ),
    );
  }
}
