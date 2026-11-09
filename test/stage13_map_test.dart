import 'dart:async';

import 'package:cots_monitor/features/user/cots_map_page.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/services/site_levels_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

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

  for (final width in [320.0, 390.0, 1200.0]) {
    testWidgets(
        'diver map selectors share a row without information clutter at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: CotsMapPage(
        siteLevels: (_) async => const [],
        ownRecords: Stream.value(const []),
        mySites: () async => <String>{},
      )));
      await tester.pumpAndSettle();
      final view = find.byKey(const ValueKey('map-view-picker'));
      final month = find.byKey(const ValueKey('map-month-picker'));
      expect(tester.getTopLeft(view).dy, tester.getTopLeft(month).dy);
      expect(tester.getTopLeft(month).dx,
          greaterThanOrEqualTo(tester.getBottomRight(view).dx));
      expect(find.textContaining('Sites are coloured'), findsNothing);
      expect(find.text('Tap a site or a record to view more details.'),
          findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(view);
      await tester.pumpAndSettle();
      expect(find.text('Select Map View'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

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
        siteLevels: (month) async => [
          SiteLevel.fromJson({
            'area_code': 'S1',
            'area_name': 'Site 1 · Tambo',
            'level': 'Moderate',
            'month': '2026-11-01',
            'records': 4,
            'confirmed_cots': 23,
            'waiting_cots': 2,
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
    expect(find.text('Moderate · 23 COTS · Nov 2026'), findsOneWidget);
    expect(find.text('No records'), findsWidgets);
    expect(find.text('Month: Latest'), findsOneWidget);
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
    expect(find.textContaining('Records: 4 · Confirmed COTS: 23 · Waiting: 2'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('monthly level boundaries: 0-15 Low, 16-100 Moderate, 101+ High', () {
    expect(MonthlySiteLevel.levelFor(0), 'Low');
    expect(MonthlySiteLevel.levelFor(15), 'Low');
    expect(MonthlySiteLevel.levelFor(16), 'Moderate');
    expect(MonthlySiteLevel.levelFor(100), 'Moderate');
    expect(MonthlySiteLevel.levelFor(101), 'High');
    // Philippine month: 2026-10-31 20:00 UTC is already November in Manila.
    expect(MonthlySiteLevel.monthOf(DateTime.utc(2026, 10, 31, 20)),
        DateTime(2026, 11));
  });

  testWidgets('choosing a month asks for that month and filters the dots',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final asked = <DateTime?>[];
    final records = StreamController<List<ScanRecordModel>>();
    addTearDown(records.close);
    await tester.pumpWidget(MaterialApp(
      home: CotsMapPage(
        siteLevels: (month) async {
          asked.add(month);
          return const [];
        },
        ownRecords: records.stream,
        mySites: () async => <String>{},
      ),
    ));
    records.add([_record('a', detected: 3, confirmed: 3)]); // Nov 6, 2026
    await tester.pumpAndSettle();
    expect(asked, [null]);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('map-month-picker')));
    await tester.pumpAndSettle();
    // Keep this valid as the clock advances: choose a month other than the
    // record's fixed November 2026 capture month.
    final now = MonthlySiteLevel.monthOf(DateTime.now());
    final other = [
      for (var i = 0; i < 12; i++) DateTime(now.year, now.month - i),
    ].lastWhere((month) => month != DateTime(2026, 11));
    final label = find.text(DateFormat('MMMM yyyy').format(other));
    await tester.ensureVisible(label.last);
    await tester.tap(label.last);
    await tester.pumpAndSettle();
    expect(asked.last, other);
    expect(find.text('3'), findsNothing,
        reason: 'the November record is not in another month');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
