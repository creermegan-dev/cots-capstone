import 'package:cots_monitor/features/admin/widgets/map_monitoring/admin_zone_monitoring_map.dart';
import 'package:cots_monitor/features/user/cots_map_page.dart';
import 'package:cots_monitor/features/user/user_bottom_nav.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/map_test_data.dart';

ScanRecordModel capture(String id, double latitude) => ScanRecordModel(
      id: id,
      uid: 'fixture',
      submittedBy: 'Diver',
      imageName: '',
      imagePath: '',
      activityType: 'Capture',
      aiDetectedCount: 0,
      confidence: 0,
      captureSource: 'camera',
      zone: 'Site 2 · Adecor',
      notes: '',
      submittedAt: null,
      latitude: latitude,
      longitude: 125.62,
    );

void main() {
  setUpAll(loadTestMap);
  testWidgets('standalone diver map keeps its navigation and layer choices',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CotsMapPage()));
    await tester.pump();
    expect(find.byType(UserBottomNavBar), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('map-view-picker')));
    await tester.pumpAndSettle();
    expect(find.text('Heatmap'), findsOneWidget);
    expect(find.text('Density Layer'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final width in [360.0, 1400.0]) {
    testWidgets('admin keeps the sites visible without captures at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: AdminZoneMonitoringMap(records: [])))));
      await tester.pump();
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(UserBottomNavBar), findsNothing);
      expect(find.textContaining('No saved detections yet'), findsOneWidget);
      final map = tester.widget<CotsMapPage>(find.byType(CotsMapPage));
      expect(map.embedded, isTrue);
      expect(map.diverStyle, isTrue);
      expect(
          find.text('SITE LEVEL (confirmed COTS per month)'), findsOneWidget);
      final viewRect =
          tester.getRect(find.byKey(const ValueKey('map-view-picker')));
      final monthRect =
          tester.getRect(find.byKey(const ValueKey('map-month-picker')));
      expect(viewRect.top, monthRect.top);
      expect(monthRect.left, greaterThan(viewRect.left));
      await tester.tap(find.byKey(const ValueKey('map-month-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Show month'), findsOneWidget);
      await tester.tap(find.byType(RadioListTile<DateTime?>).at(1));
      await tester.pumpAndSettle();
      expect(map.recordMarkers, isEmpty);
      expect(
          tester.widget<PolygonLayer>(find.byType(PolygonLayer).first).polygons,
          isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('map-view-picker')));
      await tester.pumpAndSettle();
      expect(find.text('Heatmap'), findsOneWidget);
      expect(find.text('Density Layer'), findsOneWidget);
      await tester.tap(find.text('Sites').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satellite'));
      await tester.pump();
      expect(tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
          contains('World_Imagery'));
      await tester.tap(find.text('Map'));
      await tester.pump();
      expect(tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
          contains('openstreetmap'));
      expect(find.text('Site 1 · Tambo'), findsOneWidget);
      expect(find.text('Site 2 · Adecor'), findsOneWidget);
      expect(find.text('Site 3 · Linosutan'), findsOneWidget);
      await tester.tap(find.text('Site 2 · Adecor'));
      await tester.pump();
      expect(find.textContaining('Barangay Adecor, Samal'), findsOneWidget);
      expect(find.textContaining('Size: 340 ha'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('only valid saved captures become admin pins', (tester) async {
    final records = [
      capture('valid', 7.05),
      capture('invalid', double.nan),
      capture('out-of-range', 91)
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AdminZoneMonitoringMap(records: records)))));
    await tester.pump();
    final map = tester.widget<CotsMapPage>(find.byType(CotsMapPage));
    // The map draws the dots itself, following its month picker.
    final pins = mappableRecords(map.records!);
    expect(pins, hasLength(1));
    expect(pins.single.latitude, 7.05);
    expect(find.textContaining('No saved detections yet'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
