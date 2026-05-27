import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';

/// Circular logo placeholder — replace with [Image.asset] when assets are ready.
class CotsAuthLogoBadge extends StatelessWidget {
  const CotsAuthLogoBadge({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F7FA), Colors.white],
          ),
          boxShadow: kSoftCardShadow,
          border: Border.all(color: const Color(0x331F7A7A)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.waves_rounded, size: size * 0.4, color: kOceanCyan),
            Positioned(
              top: size * 0.23,
              child: Icon(Icons.star_border_rounded, size: size * 0.35, color: kPrimaryTeal),
            ),
          ],
        ),
      ),
    );
  }
}
