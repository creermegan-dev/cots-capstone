import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:cots_monitor/services/area_messages.dart';
import 'package:cots_monitor/services/zone_assignment_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/map_test_data.dart';

String? codeAt(double lat, double lon) =>
    DavaoGulfGeography.partAt(lat, lon)?.id;

void main() {
  setUpAll(loadTestMap);

  test('the map is the 4 Samal dive sites plus 2 temporary practice sites', () {
    expect(DavaoGulfGeography.version, 'cots-samal-sites-v1');
    expect(DavaoGulfGeography.municipalities, hasLength(2));
    final samal = DavaoGulfGeography.municipalities.first;
    expect(samal.zoneLabel, 'Samal');
    expect(samal.areas, hasLength(4));
    final practice = DavaoGulfGeography.municipalities.last;
    expect(practice.zoneLabel, 'Practice');
    expect(practice.areas, hasLength(2));
    expect(DavaoGulfGeography.allBarangays, hasLength(6));
    expect(DavaoGulfGeography.areaRepresentatives, hasLength(6));
  });

  test('sites are named like the database', () {
    expect(
      [for (final s in DavaoGulfGeography.allBarangays) s.displayName],
      [
        'Site 1 · Tambo',
        'Site 2 · Adecor',
        'Site 3 · Linosutan',
        'Site 4 · Balet',
        'Practice · Home',
        'Practice · DNSC'
      ],
    );
    final adecor = DavaoGulfGeography.barangayById('S2')!;
    expect(adecor.name, 'Adecor');
    expect(adecor.zoneLabel, 'Samal');
    expect(adecor.reefHectares, closeTo(339.5, 0.1));
  });

  // Same locations as supabase/tests/database/step17_area_parts.test.sql,
  // so the phone and the database agree.
  test('location lookup matches the database rule', () {
    expect(codeAt(7.1616148, 125.6839938), 'S1');
    expect(codeAt(7.0123935, 125.7183122), 'S2');
    expect(codeAt(6.9198763, 125.6819591), 'S3');
    expect(codeAt(6.9198763, 125.6791558), 'S3'); // 10 m past the edge
    expect(codeAt(6.9198763, 125.6788845), isNull); // 40 m past the edge
    expect(codeAt(7.0800000, 125.7200000), isNull); // on land
    expect(codeAt(7.3000000, 125.7000000), isNull); // old Panabo zone
  });

  // Same points as supabase/tests/database/step22_site4_balet.test.sql.
  test('Site 4 · Balet is found on its reef and not in deep water', () {
    expect(codeAt(7.175877, 125.775144), 'S4');
    expect(codeAt(7.171475, 125.744961), 'S4');
    expect(codeAt(7.182, 125.755), isNull);
    expect(DavaoGulfGeography.barangayById('S4')!.zoneLabel, 'Samal');
  });

  // Same points as supabase/tests/database/step21_practice_sites.test.sql.
  test('practice sites are found at home and at DNSC', () {
    expect(codeAt(7.311361, 125.690736), 'P1');
    expect(codeAt(7.313715, 125.670413), 'P2');
    expect(codeAt(7.3115, 125.6830), isNull); // between them
  });

  test('every site is found at a point inside it', () {
    for (final site in DavaoGulfGeography.allBarangays) {
      final p = DavaoGulfGeography.pointInside(site)!;
      expect(codeAt(p.latitude, p.longitude), site.id);
    }
  });

  test('the app service returns the site', () {
    final a = ZoneAssignmentService.resolveMonitoringArea(
      latitude: 7.0123935,
      longitude: 125.7183122,
    )!;
    expect(a.barangay.id, 'S2');
    expect(a.municipality.zoneLabel, 'Samal');
    expect(a.zoneLabel, 'Site 2 · Adecor');
  });

  test('outlines are available for drawing', () {
    for (final site in DavaoGulfGeography.allBarangays) {
      expect(site.polygon.length, greaterThan(3), reason: site.id);
    }
    final samal = DavaoGulfGeography.municipalities.first;
    expect(samal.outlineRings, isNotEmpty);
    expect(samal.areas.first.rings.first.length, greaterThan(3));
  });

  test('a refusal for another site names that site', () {
    expect(
      AreaMessages.forError(StateError(
          'COTS_AREA_MISMATCH:S2: This photo was taken in Site 2 · Adecor, not Site 1 · Tambo.')),
      'Some photos were taken in Site 2 · Adecor. '
      'Please submit them as a separate record for Site 2 · Adecor.',
    );
    expect(
      AreaMessages.forError(StateError('COTS_AREA_OUTSIDE: ...')),
      AreaMessages.outside,
    );
  });
}
