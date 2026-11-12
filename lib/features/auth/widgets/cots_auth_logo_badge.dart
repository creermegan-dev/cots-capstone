import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';
import '../../../widgets/cots_logo.dart';

/// Circular COTS logo badge used across auth pages.
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
          color: Colors.white,
          boxShadow: kSoftCardShadow,
          border: Border.all(color: const Color(0x331F7A7A)),
        ),
        child: ClipOval(
          child: CotsLogo(size: size),
        ),
      ),
    );
  }
}
