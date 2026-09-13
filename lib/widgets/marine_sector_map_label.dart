import 'package:flutter/material.dart';

import '../models/cots_marine_sector_palette.dart';

/// Centered sector code label (A-01 … A-04) on marine monitoring polygons.
class MarineSectorMapLabel extends StatelessWidget {
  const MarineSectorMapLabel({
    super.key,
    required this.siteCode,
  });

  final String siteCode;

  static const _shadows = [
    Shadow(color: Color(0xCC000000), blurRadius: 8),
    Shadow(color: Color(0x99000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Text(
      siteCode,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: marineSectorColor(siteCode),
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
        shadows: _shadows,
      ),
    );
  }
}
