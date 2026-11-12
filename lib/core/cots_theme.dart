import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'cots_colors.dart';

/// Shared presentation tokens for the COTS marine identity.
abstract final class CotsUi {
  static const primary = kPrimaryTeal;
  static const background = Color(0xFFF4F6F8);
  static const surface = Colors.white;
  static const secondarySurface = Color(0xFFF7F9FA);
  static const divider = Color(0xFFE5E9ED);
  static const text = Color(0xFF172B3A);
  static const secondaryText = Color(0xFF647580);
  static const primaryTint = Color(0xFFEAF4F3);
  static const double cardRadius = 16;
  static const double controlRadius = 12;
  static const double controlHeight = 48;
  static const double pageInset = 20;
  static const double sectionGap = 24;

  static BoxDecoration cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: divider, width: 0.75),
      );
}

/// iOS-inspired hierarchy and controls, retaining existing Material behavior.
ThemeData cotsTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'CupertinoSystemText',
      TargetPlatform.windows => 'Segoe UI',
      _ => 'Roboto',
    },
    colorScheme: ColorScheme.fromSeed(
      seedColor: CotsUi.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: CotsUi.primary,
      onPrimary: Colors.white,
      surface: CotsUi.surface,
      onSurface: CotsUi.text,
      surfaceContainerLowest: CotsUi.surface,
      surfaceContainerLow: CotsUi.secondarySurface,
      outline: const Color(0xFFCBD4DC),
      outlineVariant: CotsUi.divider,
    ),
  );
  final inter =
      base.textTheme.apply(bodyColor: CotsUi.text, displayColor: CotsUi.text);
  final text = inter.copyWith(
    headlineLarge: inter.headlineLarge?.copyWith(
        fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8),
    headlineMedium: inter.headlineMedium?.copyWith(
        fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6),
    headlineSmall: inter.headlineSmall?.copyWith(
        fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4),
    titleLarge: inter.titleLarge?.copyWith(
        fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3),
    titleMedium: inter.titleMedium
        ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35),
    titleSmall: inter.titleSmall
        ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35),
    bodyLarge: inter.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: inter.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
    bodySmall: inter.bodySmall
        ?.copyWith(fontSize: 12, height: 1.4, color: CotsUi.secondaryText),
    labelLarge: inter.labelLarge
        ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0),
  );
  final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(CotsUi.controlRadius));
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(CotsUi.controlRadius),
    borderSide: const BorderSide(color: CotsUi.divider),
  );
  return base.copyWith(
    textTheme: text,
    primaryTextTheme: base.primaryTextTheme,
    scaffoldBackgroundColor: CotsUi.background,
    appBarTheme: AppBarTheme(
      backgroundColor: CotsUi.background,
      foregroundColor: CotsUi.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge,
      iconTheme: const IconThemeData(color: CotsUi.text, size: 22),
    ),
    cardTheme: CardThemeData(
      color: CotsUi.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CotsUi.cardRadius),
        side: const BorderSide(color: CotsUi.divider, width: 0.75),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, CotsUi.controlHeight),
        backgroundColor: CotsUi.primary,
        foregroundColor: Colors.white,
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: shape,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(48, CotsUi.controlHeight),
        backgroundColor: CotsUi.primary,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, CotsUi.controlHeight),
        foregroundColor: CotsUi.primary,
        backgroundColor: CotsUi.surface,
        side: const BorderSide(color: CotsUi.divider),
        textStyle: text.labelLarge,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CotsUi.primary,
        minimumSize: const Size(48, 44),
        textStyle: text.labelLarge,
        shape: shape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CotsUi.secondarySurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(
          borderSide: const BorderSide(color: CotsUi.primary, width: 1.5)),
      errorBorder:
          fieldBorder.copyWith(borderSide: const BorderSide(color: kDangerRed)),
      hintStyle: text.bodyMedium?.copyWith(color: CotsUi.secondaryText),
      labelStyle: text.bodyMedium?.copyWith(color: CotsUi.secondaryText),
      errorMaxLines: 3,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: CotsUi.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: CotsUi.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    dividerTheme: const DividerThemeData(
        color: CotsUi.divider, thickness: 0.75, space: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: CotsUi.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shape: shape,
      textStyle: text.bodyMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: CotsUi.text,
      elevation: 0,
      shape: shape,
      contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: CotsUi.primary,
      foregroundColor: Colors.white,
      elevation: 1,
      highlightElevation: 2,
      shape: shape,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: CotsUi.primary),
    tabBarTheme: TabBarThemeData(
      labelColor: CotsUi.primary,
      unselectedLabelColor: CotsUi.secondaryText,
      labelStyle: text.labelLarge,
      unselectedLabelStyle: text.labelLarge,
      indicatorColor: CotsUi.primary,
      dividerColor: CotsUi.divider,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
          color: CotsUi.text, borderRadius: BorderRadius.circular(8)),
      textStyle: text.bodySmall?.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
}
