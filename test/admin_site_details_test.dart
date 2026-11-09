import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/features/admin/screens/admin_site_details_screen.dart';
import 'package:cots_monitor/models/davao_gulf_geography.dart';
import 'package:cots_monitor/services/site_levels_service.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/features/user/cots_map_page.dart';
import 'submission_group_test.dart' as fixtures;
import 'support/map_test_data.dart';

class _Levels extends SiteLevelsApi {
  @override
  Future<List<SiteLevel>> history({int months = 12}) async => [
        SiteLevel(
            areaCode: 'S1',
            areaName: 'Tambo',
            level: 'Low',
            confirmedCots: 1,
            month: DateTime(2026, 11)),
      ];
}

void main() {
  setUpAll(loadTestMap);
  for (final size in [(360.0, 1.0), (1400.0, 1.0), (360.0, 2.0)]) {
    testWidgets('site details uses real site records at $size', (tester) async {
      tester.view.physicalSize = Size(size.$1, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final records = [
        fixtures.photo('tambo'),
        fixtures.photo('other', site: 'S2')
      ];
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(size.$2)),
              child: child!),
          home: AdminSiteDetailsScreen(
              site: DavaoGulfGeography.barangayById('S1')!,
              recordsStream: Stream<List<ScanRecordModel>>.value(records),
              levelsApi: _Levels())));
      await tester.pumpAndSettle();
      expect(find.text('Site Details'), findsOneWidget);
      final map = tester.widget<CotsMapPage>(find.byType(CotsMapPage));
      expect(map.records!.map((r) => r.id), ['tambo']);
      expect(map.diverStyle, isTrue);
      expect(find.text('Confirmed COTS (all time)'), findsOneWidget);
      await tester.ensureVisible(find.text('Monthly confirmed-COTS trend'));
      await tester.pumpAndSettle();
      expect(find.text('Low · 1 confirmed COTS · Nov 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
