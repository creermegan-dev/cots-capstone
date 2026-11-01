import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:cots_monitor/services/zone_assignment_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/map_test_data.dart';

String? codeAt(double lat, double lon) =>
    DavaoGulfGeography.partAt(lat, lon)?.id;

void main() {
  setUpAll(loadTestMap);

  test('the map has 22 zones, 196 areas and 17,841 parts', () {
    expect(DavaoGulfGeography.municipalities, hasLength(22));
    expect(DavaoGulfGeography.municipalities.first.name, 'Panabo City');
    expect(DavaoGulfGeography.municipalities.last.zoneCode, 'V');
    expect(
      DavaoGulfGeography.municipalities
          .fold<int>(0, (n, z) => n + z.areas.length),
      196,
    );
    expect(DavaoGulfGeography.allBarangays, hasLength(17841));
    expect(DavaoGulfGeography.areaRepresentatives, hasLength(196));
  });

  test('parts are named like the database', () {
    final part = DavaoGulfGeography.barangayById('V3-12')!;
    expect(part.displayName, 'V3-12 · Balet Part 12');
    expect(part.areaCode, 'V3');
    expect(part.zoneLabel, 'Zone V');
    expect(DavaoGulfGeography.barangayById('K10')!.displayName, 'K10 · Kalbay');
  });

  // Same locations as supabase/tests/database/step17_area_parts.test.sql,
  // so the phone and the database agree.
  test('location lookup matches the database rule', () {
    expect(codeAt(6.8924738, 125.7075962), 'V28-67');
    expect(codeAt(6.8924738, 125.7078222), 'V28-67');
    expect(codeAt(6.8924738, 125.7080935), isNull);
    expect(codeAt(6.8908459, 125.7046120), 'V28-85');
    expect(codeAt(6.8908459, 125.7048832), 'V28-86');
    expect(codeAt(7.0800000, 125.7200000), isNull);
    expect(codeAt(6.8000000, 125.8500000), isNull);
  });

  test('every 25th part is found at a point inside it', () {
    final parts = DavaoGulfGeography.allBarangays;
    for (var i = 0; i < parts.length; i += 25) {
      final p = DavaoGulfGeography.pointInside(parts[i])!;
      expect(codeAt(p.latitude, p.longitude), parts[i].id);
    }
  });

  test('the app service returns the part and its zone', () {
    final a = ZoneAssignmentService.resolveMonitoringArea(
      latitude: 6.8924738,
      longitude: 125.7075962,
    )!;
    expect(a.barangay.id, 'V28-67');
    expect(a.municipality.zoneCode, 'V');
    expect(a.zoneLabel, 'Zone V · V28-67');
  });

  test('outlines are available for drawing', () {
    final part = DavaoGulfGeography.barangayById('V3-12')!;
    expect(part.polygon.length, greaterThan(3));
    final zone = DavaoGulfGeography.municipalityByZoneCode('A')!;
    expect(zone.boundary.length, greaterThan(3));
    expect(zone.areas.first.rings.first.length, greaterThan(3));
  });
}
