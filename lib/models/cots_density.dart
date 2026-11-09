/// COTS infestation level from density, adapted from Dumas et al. (2020):
/// Low up to and including 15 COTS/ha, Moderate above 15 up to 100, High above
/// 100 (user rule, 2026-11-05).
///
/// density (COTS/ha) = field-observed COTS / (surveyed reef area m² / 10,000)
///
/// These thresholds are research guidance. Keep them identical to
/// `cots_private.density_level` in
/// supabase/migrations/20261030000600_infestation_density.sql.
abstract final class CotsDensity {
  /// Up to and including this is Low (non-outbreak).
  static const lowUpTo = 15.0;

  /// Above this is High (confirmed outbreak); up to and including it is Moderate.
  static const highAbove = 100.0;

  static const levels = ['Low', 'Moderate', 'High'];

  /// COTS per hectare, rounded to 2 decimals; null without a valid area.
  static double? perHectare(int observed, double? areaSquareMeters) {
    if (areaSquareMeters == null ||
        !areaSquareMeters.isFinite ||
        areaSquareMeters <= 0 ||
        observed < 0) {
      return null;
    }
    final value = observed / (areaSquareMeters / 10000);
    return (value * 100).round() / 100;
  }

  static String? level(double? perHectare) {
    if (perHectare == null) return null;
    if (perHectare <= lowUpTo) return 'Low';
    if (perHectare <= highAbove) return 'Moderate';
    return 'High';
  }

  static String outbreakLabel(String level) => switch (level) {
        'Low' => 'Low · non-outbreak',
        'Moderate' => 'Moderate · potential outbreak',
        'High' => 'High · confirmed outbreak',
        _ => level,
      };

  /// e.g. "48.00 COTS/ha · Moderate"
  static String describe(double? perHectare, String? level) {
    if (perHectare == null || level == null) {
      return 'Density not available (no surveyed area)';
    }
    return '${perHectare.toStringAsFixed(2)} COTS/ha · $level';
  }
}
