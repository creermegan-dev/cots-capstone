import 'package:flutter/material.dart';

// COTS Monitor palette (shared across screens)
const Color kPrimaryTeal = Color(0xFF1F7A7A);
const Color kDarkTeal = Color(0xFF174F57);
const Color kWarningOrange = Color(0xFFF6A623);
const Color kDangerRed = Color(0xFFE74C3C);
const Color kSuccessGreen = Color(0xFF3FA34D);
const Color kTextNavy = Color(0xFF111827);
const Color kMutedGray = Color(0xFF6B7280);
const Color kBorderGray = Color(0xFFE5E7EB);
const Color kInfoBlue = Color(0xFF2563EB);
const Color kAccentPurple = Color(0xFF7C3AED);

// Auth / ocean UI accents (signup gradient highlights)
const Color kOceanCyan = Color(0xFF2EC4C4);

/// Soft card shadow (~4% black) usable in const `BoxDecoration`s.
const List<BoxShadow> kSoftCardShadow = [
  BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 10,
    offset: Offset(0, 3),
  ),
];
