import 'package:cots_monitor/features/user/cots_map_page.dart';
import 'package:cots_monitor/features/user/photo_location_review_page.dart';
import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'support/map_test_data.dart';

void main() {
  setUpAll(loadTestMap);
  for (final width in [360.0, 1200.0]) {
    testWidgets(
        'photo overview keeps a fixed pin and has no correction controls at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const point = LatLng(7.291444, 125.711417);
      await tester.pumpWidget(const MaterialApp(
          home: PhotoLocationReviewPage(
              fileName: 'original.jpg',
              originalSource: 'exif',
              original: point)));
      await tester.pumpAndSettle();
      CotsMapPage map() => tester.widget<CotsMapPage>(find.byType(CotsMapPage));
      expect(map().initialCenter, point);
      expect(map().recordMarkers.single.point, point);
      expect(map().showMyLocation, isFalse);
      expect(find.text('Location source: Photo GPS'), findsOneWidget);
      expect(find.text('This point is outside every dive site.'),
          findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.textContaining('Send proposal'), findsNothing);
      final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(flutterMap.options.onTap, isNull);
      flutterMap.mapController!.move(const LatLng(7.288623, 125.705663), 13);
      await tester.pumpAndSettle();
      expect(map().recordMarkers.single.point, point);
      expect(find.text('Coordinates: 7.291444, 125.711417'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('a matched photo shows its dive site',
      (tester) async {
    final part = DavaoGulfGeography.barangayById('S2')!;
    final point = DavaoGulfGeography.pointInside(part)!;
    await tester.pumpWidget(MaterialApp(
        home: PhotoLocationReviewPage(
            fileName: 'matched.jpg', originalSource: 'exif', original: point)));
    await tester.pumpAndSettle();
    // Once on the map's site badge and once in the line under the map.
    expect(find.text('Site 2 · Adecor'), findsNWidgets(2));
    expect(
        tester
            .widget<CotsMapPage>(find.byType(CotsMapPage))
            .recordMarkers
            .single
            .point,
        point);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('phone fallback is clearly distinguished from embedded photo GPS',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: PhotoLocationReviewPage(
            fileName: 'fallback.jpg',
            originalSource: 'device_surface',
            original: LatLng(7.291444, 125.711417))));
    await tester.pumpAndSettle();
    expect(find.text('Location source: Phone GPS (at the surface)'),
        findsOneWidget);
    expect(
        find.textContaining('not GPS embedded in the photo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('missing or invalid GPS never fabricates a pin', (tester) async {
    for (final point in [
      null,
      const LatLng(91, 125),
      const LatLng(double.nan, 125)
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: PhotoLocationReviewPage(
              fileName: 'no-gps.jpg',
              originalSource: 'unavailable',
              original: point)));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsNothing);
      expect(
          find.text(
              'No coordinates are available for this photo. A location cannot be shown.'),
          findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
