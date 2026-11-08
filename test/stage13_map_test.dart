import 'dart:async';

import 'package:cots_monitor/features/user/cots_map_page.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/services/site_levels_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/map_test_data.dart';

// Stage 13: real data on the map.

ScanRecordModel _record(String id,
        {required int detected,
        required int confirmed,
        int waiting = 0,
        double? lat = 7.0123935,
        double? lng = 125.7183122}) =>
    ScanRecordModel.fromCapture(CaptureModel(
      id: id,
      uid: 'diver',
      submittedBy: 'Diver',
      imageName: '',
      aiDetectedCount: detected,
      confidence: 0.9,
      captureSource: 'camera',
      zone: 'Site 2 · Adecor',
      notes: '',
      submittedAt: DateTime(2026, 11, 6, 9),
      latitude: lat,
      longitude: lng,
      confirmedCount: confirmed,
      waitingCount: waiting,
    ));

void main() {
  setUpAll(loadTestMap);

  test('only records with a valid location become dots', () {
    final records = mappableRecords([
      _record('a', detected: 3, confirmed: 3),
      _record('b', detected: 1, confirmed: 0, waiting: 1, lat: null, lng: null),
      _record('c', detected: 1, confirmed: 1, lat: 95),
    ]);
    expect(records.map((r) => r.id), ['a']);
  });

  test('a dot shows confirmed COTS in red, waiting ones in orange', () {
    final confirmed = recordDotMarker(_record('a', detected: 3, confirmed: 3));
    final waiting =
        recordDotMarker(_record('b', detected: 2, confirmed: 0, waiting: 2));
    expect(confirmed.point.latitude, 7.0123935);
    Color colorOf(Marker m) =>
        ((((m.child as GestureDetector).child as Tooltip).child as Container)
                .decoration as BoxDecoration)
            .color!;
    expect(colorOf(confirmed), const Color(0xFFDC2626));
    expect(colorOf(waiting), const Color(0xFFF59E0B));
  });

  testWidgets('sites show their real level, my site, and my record dots',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = StreamController<List<ScanRecordModel>>();
    addTearDown(records.close);
    await tester.pumpWidget(MaterialApp(
      home: CotsMapPage(
        siteLevels: () async => [
          SiteLevel.fromJson({
            'area_code': 'S1',
            'area_name': 'Site 1 · Tambo',
            'level': 'High',
            'density_per_ha': 150.0,
            'records': 4,
            'confirmed_cots': 12,
          }),
          SiteLevel.fromJson(
              {'area_code': 'S2', 'area_name': 'Site 2 · Adecor'}),
        ],
        ownRecords: records.stream,
        mySites: () async => {'S2'},
      ),
    ));
    records.add([
      _record('a', detected: 3, confirmed: 3),
      _record('b', detected: 2, confirmed: 0, waiting: 2, lat: 7.0130),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('High · 150 COTS/ha'), findsOneWidget);
    expect(find.text('No data yet'), findsWidgets);
    expect(find.text('Your site'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Low ≤15'), findsOneWidget);
    expect(find.text('Moderate 16–100'), findsOneWidget);
    expect(find.text('High >100'), findsOneWidget);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final before = map.mapController!.camera.zoom;
    await tester.tap(find.text('Site 1 · Tambo'));
    await tester.pump();
    final camera = map.mapController!.camera;
    expect(camera.zoom, greaterThan(before));
    expect(camera.zoom, lessThanOrEqualTo(17));
    final site = DavaoGulfGeography.municipalities
        .expand((zone) => zone.areas)
        .firstWhere((area) => area.code == 'S1');
    for (final point in site.rings.expand((ring) => ring)) {
      expect(camera.visibleBounds.contains(point), isTrue);
    }
    expect(
        find.textContaining('Records: 4 · Confirmed COTS: 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
