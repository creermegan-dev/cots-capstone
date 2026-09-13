import 'package:flutter/material.dart';

/// Panabo marine monitoring sector colors (Option 2).
const Map<String, Color> kMarineSectorColors = {
  'A-01': Color(0xFFFFEB3B),
  'A-02': Color(0xFFFF9800),
  'A-03': Color(0xFFE53935),
  'A-04': Color(0xFF1E88E5),
};

Color marineSectorColor(String siteCode) {
  return kMarineSectorColors[siteCode] ?? const Color(0xFF78909C);
}
