import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/services/monthly_report_service.dart';
import 'package:cots_monitor/features/admin/screens/monthly_report_screen.dart';
import 'dart:convert';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/model_comparison.dart';
import 'package:cots_monitor/models/monthly_report.dart';
import 'package:cots_monitor/models/monitoring_analytics.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/services/model_comparison_export.dart';
import 'package:cots_monitor/services/monthly_report_pdf_service.dart';
import 'package:cots_monitor/services/supabase_record_service.dart';
import 'package:cots_monitor/features/admin/widgets/admin_model_comparison_card.dart';
import 'package:cots_monitor/widgets/monitoring_analytics_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ScanRecordModel photo(String id, String model,
        {int expert = 0, String site = 'Balet', DateTime? date}) =>
    ScanRecordModel.fromCapture(CaptureModel(
        id: id,
        uid: 'diver',
        submittedBy: 'Diver',
        imageName: '$id.jpg',
        aiDetectedCount: 1,
        confidence: .9,
        captureSource: 'photo',
        zone: site,
        notes: '',
        submittedAt: date ?? DateTime(2026, 11, 10),
        dateTaken: date ?? DateTime(2026, 11, 10),
        modelName: model,
        expertConfirmedCount: expert));

class _RoleAuth extends AuthProvider {
  _RoleAuth(this.role);
  final String role;
  @override
  UserModel get userModel => UserModel.fromSupabaseProfile(
      {'id': 'viewer', 'full_name': 'Viewer', 'active': true},
      email: '', privilegedRole: role == 'admin' ? 'administrator' : role);
}

class _ReportApi extends MonthlyReportApi {
  @override
  Future<List<MonthlyReportSiteOption>> sites() async => [];
  @override
  Future<MonthlyReport> report(DateTime month, {String? areaCode}) async =>
      MonthlyReport(
          month: month,
          generatedAt: DateTime.utc(2026, 11, 10),
          records: 1,
          sites: const [
            MonthlyReportSite(areaCode: 'S4', areaName: 'Balet', records: 1)
          ]);
}

void main() {
  testWidgets(
      'Admin monthly export includes comparison while Expert export does not',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lengths = <String, int>{};
    for (final role in ['admin', 'expert']) {
      final auth = _RoleAuth(role);
      Uint8List? saved;
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              home: Scaffold(
                  body: MonthlyReportScreen(
            api: _ReportApi(),
            now: () => DateTime(2026, 11, 10),
            loadRecords: () async => [photo('a', 'yolo11').toAdminTableRow(1)],
            save: (bytes, name) async {
              saved = bytes;
              return 'saved.pdf';
            },
          )))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pumpAndSettle();
      expect(find.text('Model comparison'),
          role == 'admin' ? findsOneWidget : findsNothing);
      final preview =
          tester.widget<MonthlyReportView>(find.byType(MonthlyReportView));
      if (role == 'admin') {
        final comparison = preview.modelComparison!;
        expect(
            comparison.map((row) => row.model), ['YOLOv8', 'YOLO11', 'YOLO26']);
        expect(
            comparison.singleWhere((row) => row.model == 'YOLO11').photos, 1);
      } else {
        expect(preview.modelComparison, isNull);
      }
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('export-pdf')));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      expect(saved, isNotNull);
      lengths[role] = saved!.length;
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    }
    expect(lengths['admin'], greaterThan(lengths['expert']!));
    expect(tester.takeException(), isNull);
  });

  test(
      'explicit approvals exclude automatic, implicit, foreign and superseded decisions',
      () {
    final ids = {'a', 'b'};
    expect(SupabaseRecordService.explicitExpertConfirmed(ids, []), 0);
    expect(
        SupabaseRecordService.explicitExpertConfirmed(ids, [
          {
            'decision_sequence': 1,
            'decision': 'approve',
            'item_decisions': [
              {'item_id': 'a', 'decision': 'approve'},
              {'item_id': 'foreign', 'decision': 'approve'}
            ]
          },
          {
            'decision_sequence': 2,
            'decision': 'approve',
            'item_decisions': [
              {'item_id': 'b', 'decision': 'approve'},
              {'item_id': 'b', 'decision': 'approve'}
            ]
          },
        ]),
        1);
    expect(
        SupabaseRecordService.explicitExpertConfirmed(ids, [
          {
            'decision_sequence': 3,
            'decision': 'reject',
            'item_decisions': [
              {'item_id': 'a', 'decision': 'approve'}
            ]
          }
        ]),
        0);
  });

  test('comparison deduplicates photos and uses filtered data and stored model',
      () {
    final a = photo('a', 'yolo11', expert: 1);
    final records = [
      a,
      a,
      photo('b', 'yolo26'),
      photo('c', ''),
      photo('d', 'yolo8', site: 'Tambo'),
      photo('e', 'yolo8', date: DateTime(2025))
    ];
    final filtered = MonitoringAnalytics.fromRecords(records,
            zone: 'Balet',
            from: DateTime(2026, 11, 1),
            to: DateTime(2026, 11, 30))
        .captures;
    final result = ModelComparison.fromRecords(filtered);
    expect(result.first.photos, 0);
    expect(result[1].cells, ['YOLO11', '1', '90.0%', '1']);
    expect(result[2].expertConfirmed, 0);
    expect(result.last.model, 'Model not recorded');
    final csv = utf8.decode(ModelComparisonExport.csv(result));
    expect(csv, contains('"YOLO11","1","90.0%","1"'));
    expect(csv, contains('Expert-confirmed COTS'));
  });

  test('monthly PDF comparison is opt-in; ordinary export retains its format',
      () async {
    final report = MonthlyReport(
        month: DateTime(2026, 11), generatedAt: DateTime.utc(2026, 11, 10));
    final plain = await const MonthlyReportPdfService().build(report, []);
    final admin = await const MonthlyReportPdfService().build(report, [],
        modelComparison: ModelComparison.fromRecords([photo('a', 'yolo26')]));
    expect(String.fromCharCodes(admin.take(5)), '%PDF-');
    expect(admin.length, greaterThan(plain.length));
  });

  testWidgets('Admin comparison follows site filter and fits a phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final records = [
      photo('a', 'yolo11', site: 'Balet'),
      photo('b', 'yolo26', site: 'Tambo')
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
      child: MonitoringAnalyticsPanel(
          recordsStream: Stream.value(records),
          now: DateTime(2026, 11, 10),
          trailingBuilder: (context, rows) =>
              AdminModelComparisonCard(records: rows)),
    ))));
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>))
        .onChanged!('Balet');
    await tester.pumpAndSettle();
    final card = tester.widget<AdminModelComparisonCard>(
        find.byType(AdminModelComparisonCard));
    expect(card.records.map((r) => r.id), ['a']);
    expect(tester.takeException(), isNull);
  });
  for (final width in [360.0, 1400.0]) {
    testWidgets('report comparison preview fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
        child: MonthlyReportView(
            report: MonthlyReport(
                month: DateTime(2026, 11),
                generatedAt: DateTime.utc(2026, 11, 11)),
            records: const [],
            modelComparison:
                ModelComparison.fromRecords([photo('a', 'yolo26')])),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Model comparison'), findsOneWidget);
      expect(find.text('YOLO26'), findsOneWidget);
      expect(find.text(ModelComparison.note), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
