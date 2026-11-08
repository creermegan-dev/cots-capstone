import 'package:cots_monitor/models/cots_density.dart';
import 'package:cots_monitor/models/follow_up_monitoring_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('density is COTS per hectare from square meters', () {
    expect(CotsDensity.perHectare(12, 2500), 48.0);
    expect(CotsDensity.perHectare(120, 10000), 120.0);
    expect(CotsDensity.perHectare(1, 3), 3333.33);
  });

  test('no density without a valid surveyed area', () {
    expect(CotsDensity.perHectare(5, null), isNull);
    expect(CotsDensity.perHectare(5, 0), isNull);
    expect(CotsDensity.perHectare(5, -10), isNull);
  });

  test('levels: Low up to 15, Moderate 16-100, High above 100', () {
    expect(CotsDensity.level(0), 'Low');
    expect(CotsDensity.level(14.99), 'Low');
    expect(CotsDensity.level(15), 'Low');
    expect(CotsDensity.level(15.01), 'Moderate');
    expect(CotsDensity.level(16), 'Moderate');
    expect(CotsDensity.level(100), 'Moderate');
    expect(CotsDensity.level(100.01), 'High');
    expect(CotsDensity.level(null), isNull);
  });

  test('descriptions are readable', () {
    expect(CotsDensity.describe(48, 'Moderate'), '48.00 COTS/ha · Moderate');
    expect(CotsDensity.describe(null, null),
        'Density not available (no surveyed area)');
    expect(CotsDensity.outbreakLabel('High'), 'High · confirmed outbreak');
  });

  test('visits read the calculated and confirmed levels', () {
    final visit = FollowUpSurveyModel.fromMap({
      'density_per_ha': 48.0,
      'calculated_level': 'Moderate',
      'assessed_level': 'High',
    }, id: 'v1');
    expect(visit.densityPerHectare, 48.0);
    expect(visit.calculatedLevel, 'Moderate');
    expect(visit.assessedLevel, 'High');
  });
}
