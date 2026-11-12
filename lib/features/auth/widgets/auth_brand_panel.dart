import 'package:flutter/material.dart';

import 'auth_layout.dart';
import '../../../widgets/cots_logo.dart';

/// Left brand column for desktop auth (40% width).
class AuthBrandPanel extends StatelessWidget {
  const AuthBrandPanel({super.key});

  static const _features = [
    'Machine Learning',
    'GIS Mapping',
    'Expert Validation',
    'Reef Conservation',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BrandLogo(size: 56),
          const SizedBox(height: 28),
          const Text(
            'COTS Monitor',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AuthTokens.titleNavy,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Machine Learning-Based Crown-of-Thorns Starfish Monitoring Platform',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AuthTokens.subtitleGray.withValues(alpha: 0.95),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 32),
          for (final f in _features) ...[
            _FeatureRow(label: f),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AuthTokens.focusTeal.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 14,
            color: AuthTokens.focusTeal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AuthTokens.titleNavy,
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AuthTokens.focusTeal.withValues(alpha: 0.25)),
        boxShadow: AuthTokens.cardShadow,
      ),
      child: ClipOval(
        child: CotsLogo(size: size),
      ),
    );
  }
}
