import 'package:cots_monitor/services/site_levels_service.dart';
import 'package:cots_monitor/widgets/site_levels_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SiteLevel _site(String code, String name,
        {String? level, int cots = 0, String? zone = 'Samal'}) =>
    SiteLevel.fromJson({
      'area_code': code,
      'area_name': name,
      'map_zone': zone,
      'level': level,
      'month': level == null ? null : '2026-11-01',
      'confirmed_cots': cots,
    });

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('site levels row: High first, practice hidden at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      DateTime? asked;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: SiteLevelsRow(
        now: DateTime(2026, 11, 8, 12),
        levels: (month) async {
          asked = month;
          return [
            _site('S1', 'Site 1 · Tambo'),
            _site('S2', 'Site 2 · Adecor', level: 'Low', cots: 5),
            _site('S3', 'Site 3 · Linosutan', level: 'Moderate', cots: 42),
            _site('S4', 'Site 4 · Balet', level: 'High', cots: 120),
            _site('P1', 'Practice · Home',
                level: 'Moderate', cots: 32, zone: 'Practice'),
          ];
        },
      )))));
      await tester.pumpAndSettle();
      expect(asked, DateTime(2026, 11));
      expect(find.text('Site levels · November 2026'), findsOneWidget);
      expect(find.text('Practice · Home'), findsNothing);
      expect(find.text('No records'), findsOneWidget);
      final names = [
        'Site 4 · Balet',
        'Site 3 · Linosutan',
        'Site 2 · Adecor',
        'Site 1 · Tambo'
      ];
      final tops = [for (final n in names) tester.getTopLeft(find.text(n))];
      for (var i = 1; i < tops.length; i++) {
        final before = tops[i - 1];
        final after = tops[i];
        expect(
            after.dy > before.dy ||
                (after.dy == before.dy && after.dx > before.dx),
            isTrue,
            reason: '${names[i - 1]} comes before ${names[i]}');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
