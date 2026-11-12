import 'dart:async';
import 'dart:typed_data';

import 'package:cots_monitor/features/admin/layout/admin_nav_entries.dart';
import 'package:cots_monitor/features/admin/models/admin_nav_models.dart';
import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/features/admin/screens/admin_reports_screen.dart';
import 'package:cots_monitor/features/admin/screens/monthly_report_screen.dart';
import 'package:cots_monitor/features/expert/screens/expert_shell_screen.dart';
import 'package:cots_monitor/models/cots_tally.dart';
import 'package:cots_monitor/models/monthly_report.dart';
import 'package:cots_monitor/models/record_collection.dart';
import 'package:cots_monitor/services/monthly_report_pdf_service.dart';
import 'package:cots_monitor/services/monthly_report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({int photosAt80 = 0, int records = 5}) => {
      'month': '2026-11-01',
      'area_code': null,
      'area_name': null,
      'generated_at': '2026-11-09T14:09:00Z',
      'confirmed_cots': 154,
      'waiting_cots': 9,
      'not_accepted_cots': 4,
      'records': records,
      'photos_at_80': photosAt80,
      'sites': [
        {
          'area_code': 'S3',
          'area_name': 'Site 3 · Tambo',
          'level': 'High',
          'records': 3,
          'confirmed_cots': 101,
          'waiting_cots': 6,
          'main_diver': 'Diver B',
          'last_visit': '2026-11-08',
          'visits': 5,
          'missed_months': 0,
        },
        {
          'area_code': 'S4',
          'area_name': 'Site 4 · Balet',
          'level': 'Moderate',
          'records': 2,
          'confirmed_cots': 31,
          'waiting_cots': 3,
          'main_diver': null,
          'last_visit': null,
          'visits': 0,
          'missed_months': null,
        },
      ],
      'methods': [
        {'method': 'Vinegar injection', 'cots': 71, 'removals': 14},
        {'method': 'Ox bile injection', 'cots': 45, 'removals': 9},
        {'method': 'Manual removal', 'cots': 38, 'removals': 11},
      ],
      'expert_review': {
        'reviewed': 47,
        'approved': 42,
        'rejected': 5,
        'still_waiting': 9,
        'avg_wait_days': 1.8,
        'oldest_waiting_days': 4.0,
      },
    };

AdminRecordTableRow _row(
  String id,
  String site,
  DateTime taken, {
  String collection = RecordCollection.captures,
  String serverStatus = 'finalized',
  int confirmed = 4,
}) =>
    AdminRecordTableRow(
      1,
      id,
      site,
      'Nov 3, 2026',
      3,
      0.2,
      'Low',
      'Diver, One',
      85,
      adminConfirmed: true,
      activityType: 'COTS Detection',
      recordCollection: collection,
      serverStatus: serverStatus,
      capturedAt: taken,
      encounterId: 'abcdef12-3456-7890',
      locationSource: 'exif',
      cotsTally: CotsTally(confirmed: confirmed, waiting: 0, notAccepted: 0),
    );

class _FakeApi extends MonthlyReportApi {
  _FakeApi({this.result, this.error});

  final MonthlyReport? result;
  final Object? error;
  int calls = 0;
  DateTime? askedMonth;
  String? askedCode;
  int recordCalls = 0;
  MonthlyReport? recordsReport;
  List<AdminRecordTableRow> recordRows = const [];
  Completer<List<AdminRecordTableRow>>? pendingRecords;

  @override
  Future<List<AdminRecordTableRow>> records(MonthlyReport report) {
    recordCalls++;
    recordsReport = report;
    return pendingRecords?.future ?? Future.value(recordRows);
  }

  @override
  Future<MonthlyReport> report(DateTime month, {String? areaCode}) async {
    calls++;
    askedMonth = month;
    askedCode = areaCode;
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<List<MonthlyReportSiteOption>> sites() async => const [
        MonthlyReportSiteOption(code: 'S3', name: 'Site 3 · Tambo'),
        MonthlyReportSiteOption(code: 'S4', name: 'Site 4 · Balet'),
      ];
}

Future<void> _open(
  WidgetTester tester,
  _FakeApi api, {
  List<AdminRecordTableRow> rows = const [],
  Future<String?> Function(Uint8List, String)? save,
  bool useDefaultRecords = false,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: MonthlyReportScreen(
        showBack: false,
        api: api,
        loadRecords: useDefaultRecords ? null : () async => rows,
        save: save,
        now: () => DateTime(2026, 11, 9, 12),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('report model', () {
    test('reads the database numbers and formats the labels', () {
      final report = MonthlyReport.fromJson(_json());
      expect(report.monthLabel, 'November 2026');
      expect(report.scopeLabel, 'All sites');
      expect(report.confirmedCots, 154);
      expect(report.waitingCots, 9);
      expect(report.notAcceptedCots, 4);
      expect(report.generatedLabel, '9 Nov 2026, 10:09 PM (Manila)');
      expect(report.fileName, 'cots_report_2026-11_all_sites');
      expect(report.sites.first.levelLabel, 'High');
      expect(report.sites.first.lastVisitLabel, '2026-11-08');
      expect(report.sites.last.mainDiverLabel, 'Not assigned');
      expect(report.sites.last.lastVisitLabel, 'No visit yet');
      expect(report.sites.last.missedLabel, '-');
      expect(report.methods.map((m) => m.shareOf(154)).toList(),
          ['46%', '29%', '25%']);
      expect(report.review.avgWaitLabel, '1.8 d');
      expect(report.review.summary,
          contains('47 records reviewed: 42 approved, 5 rejected.'));
      expect(report.review.summary,
          contains('9 still waiting (oldest: 4.0 days)'));
    });

    test('a chosen site shows in the file name and scope', () {
      final report = MonthlyReport.fromJson({
        ..._json(),
        'area_code': 'S4',
        'area_name': 'Site 4 · Balet',
      });
      expect(report.scopeLabel, 'Site 4 · Balet');
      expect(report.fileName, 'cots_report_2026-11_s4');
    });

    test('the footer uses the 85% rule and mentions older photos only if any',
        () {
      final now = MonthlyReport.fromJson(_json());
      expect(now.footnote,
          contains('accepted automatically at 85% or higher plus approved'));
      expect(now.footnote, isNot(contains('used 80%')));
      expect(now.footnote, contains('0-15 Low, 16-100 Moderate, 101+ High'));
      final older = MonthlyReport.fromJson(_json(photosAt80: 3));
      expect(older.footnote, contains('before that rule used 80%'));
    });

    test('an empty month is reported as empty', () {
      final report = MonthlyReport.fromJson({
        'month': '2026-10-01',
        'generated_at': '2026-11-09T14:09:00Z',
      });
      expect(report.isEmpty, isTrue);
      expect(report.review.avgWaitLabel, '-');
      expect(report.review.summary, contains('Nothing is waiting'));
    });
  });

  group('appendix rows', () {
    test('only finalized photo records of the month and the listed sites', () {
      final report = MonthlyReport.fromJson(_json());
      final rows = [
        _row('CAP-3', 'Site 3 · Tambo', DateTime.utc(2026, 11, 3, 2)),
        _row('CAP-2', 'Site 4 · Balet', DateTime.utc(2026, 11, 2, 2)),
        // 1 Nov 01:00 in Manila is still 31 Oct in UTC.
        _row('CAP-1', 'Site 3 · Tambo', DateTime.utc(2026, 10, 31, 17)),
        // 1 Dec 01:00 in Manila belongs to December.
        _row('CAP-X1', 'Site 3 · Tambo', DateTime.utc(2026, 11, 30, 17)),
        _row('CAP-X2', 'Site 3 · Tambo', DateTime.utc(2026, 10, 30, 2)),
        _row('CAP-X3', 'Some Other Reef', DateTime.utc(2026, 11, 5, 2)),
        _row('REM-1', 'Site 3 · Tambo', DateTime.utc(2026, 11, 4, 2),
            collection: RecordCollection.removalRecords),
        _row('CAP-X4', 'Site 3 · Tambo', DateTime.utc(2026, 11, 4, 2),
            serverStatus: 'pending'),
      ];
      final records = MonthlyReportRecord.forReport(report, rows);
      expect(
          records.map((r) => r.recordId).toList(), ['CAP-1', 'CAP-2', 'CAP-3']);
      expect(records.first.dateTaken, '2026-11-01');
      expect(records.first.encounter, 'abcdef12');
      expect(records.first.locationFrom, 'Photo GPS');
      expect(records.first.confirmed, 4);
      expect(records.first.status, isNotEmpty);
    });
  });

  group('PDF', () {
    test('builds one PDF file with every section', () async {
      final report = MonthlyReport.fromJson(_json());
      final bytes = await const MonthlyReportPdfService().build(report, [
        for (var i = 0; i < 150; i++)
          MonthlyReportRecord(
            recordId: 'CAP-$i',
            encounter: 'abcdef12',
            site: 'Site 3 · Tambo',
            dateTaken: '2026-11-03',
            locationFrom: 'Photo GPS',
            confirmed: i % 5,
            status: 'Accepted',
          ),
      ]);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(bytes.length, greaterThan(2000));
    });

    test('builds for an empty list of records', () async {
      final report = MonthlyReport.fromJson(_json());
      final bytes = await const MonthlyReportPdfService().build(report, []);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('Create report screen', () {
    testWidgets(
        'default loader reads report-scoped rows instead of a live feed',
        (tester) async {
      final api = _FakeApi(result: MonthlyReport.fromJson(_json()))
        ..recordRows = [
          _row('CAP-3', 'Site 3 · Tambo', DateTime.utc(2026, 11, 3))
        ];
      await _open(tester, api, useDefaultRecords: true);
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pumpAndSettle();
      expect(api.recordCalls, 1);
      expect(api.recordsReport!.month, DateTime(2026, 11));
      expect(
          api.recordsReport!.sites.map((site) => site.areaCode), ['S3', 'S4']);
      expect(find.text('Appendix: records (1)'), findsOneWidget);
      expect(find.byKey(const Key('export-pdf')), findsOneWidget);
    });

    testWidgets(
        'slow record request explains the stage and can retry without exporting partial data',
        (tester) async {
      final api = _FakeApi(result: MonthlyReport.fromJson(_json()))
        ..pendingRecords = Completer<List<AdminRecordTableRow>>();
      await _open(tester, api, useDefaultRecords: true);
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(find.textContaining('report records did not finish loading'),
          findsOneWidget);
      expect(find.byKey(const Key('export-pdf')), findsNothing);
      api.pendingRecords!.complete([]);
      api.pendingRecords = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(api.recordCalls, 2);
      expect(find.text('Report preview'), findsOneWidget);
    });

    testWidgets('opens on this month and all sites with no report yet',
        (tester) async {
      await _open(tester, _FakeApi(result: MonthlyReport.fromJson(_json())));
      expect(find.text('Create report'), findsWidgets);
      expect(find.text('November 2026 (this month)'), findsOneWidget);
      expect(find.text('All sites'), findsOneWidget);
      expect(find.text('No report yet'), findsOneWidget);
      expect(find.text('Export PDF'), findsNothing);
    });

    testWidgets('Create report shows the preview with an Export PDF button',
        (tester) async {
      final api = _FakeApi(result: MonthlyReport.fromJson(_json()));
      await _open(tester, api, rows: [
        _row('CAP-3', 'Site 3 · Tambo', DateTime.utc(2026, 11, 3, 2)),
      ]);
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pumpAndSettle();
      expect(api.calls, 1);
      expect(api.askedMonth, DateTime(2026, 11));
      expect(api.askedCode, isNull);
      expect(find.text('Report preview'), findsOneWidget);
      expect(find.text('COTS Monitor report'), findsOneWidget);
      expect(find.text('Found and removed (confirmed)'), findsOneWidget);
      expect(find.text('154'), findsOneWidget);
      expect(find.text('1. Sites'), findsOneWidget);
      expect(find.text('2. Removal methods'), findsOneWidget);
      expect(find.text('3. Expert review'), findsOneWidget);
      expect(find.text('Appendix: records (1)'), findsOneWidget);
      expect(find.text('Site 3 · Tambo'), findsWidgets);
      expect(find.byKey(const Key('export-pdf')), findsOneWidget);
      expect(find.textContaining('85% or higher'), findsOneWidget);
    });

    testWidgets('the chosen site is sent to the report', (tester) async {
      final api = _FakeApi(result: MonthlyReport.fromJson(_json()));
      await _open(tester, api);
      await tester.tap(find.byKey(const Key('site-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Site 4 · Balet').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pumpAndSettle();
      expect(api.askedCode, 'S4');
    });

    testWidgets('Export PDF saves one PDF with the report file name',
        (tester) async {
      final api = _FakeApi(result: MonthlyReport.fromJson(_json()));
      Uint8List? saved;
      String? savedName;
      await _open(tester, api, save: (bytes, name) async {
        saved = bytes;
        savedName = name;
        return 'C:/reports/$name.pdf';
      });
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('export-pdf')));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();
      expect(savedName, 'cots_report_2026-11_all_sites');
      expect(String.fromCharCodes(saved!.take(5)), '%PDF-');
      expect(find.textContaining('PDF report saved to'), findsOneWidget);
    });

    testWidgets('cancelled PDF save does not claim success and can retry',
        (tester) async {
      var saves = 0;
      await _open(tester, _FakeApi(result: MonthlyReport.fromJson(_json())),
          save: (_, __) async {
        saves++;
        return null;
      });
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.runAsync(() async {
          await tester.tap(find.byKey(const Key('export-pdf')));
          await Future<void>.delayed(const Duration(milliseconds: 500));
        });
        await tester.pumpAndSettle();
      }
      expect(saves, 2);
      expect(find.textContaining('PDF report saved'), findsNothing);
      expect(find.text('Report preview'), findsOneWidget);
    });

    testWidgets('a month with no records says so and offers no export',
        (tester) async {
      final api = _FakeApi(
          result: MonthlyReport.fromJson({
        'month': '2026-11-01',
        'generated_at': '2026-11-09T14:09:00Z',
      }));
      await _open(tester, api, useDefaultRecords: true);
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pumpAndSettle();
      expect(find.text('No records for this month'), findsOneWidget);
      expect(find.byKey(const Key('export-pdf')), findsNothing);
      expect(api.recordCalls, 0);
    });

    testWidgets('a failed report shows the error and can retry',
        (tester) async {
      final api = _FakeApi(error: 'Offline');
      await _open(tester, api);
      await tester.tap(find.byKey(const Key('create-report')));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Could not create the report'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byKey(const Key('export-pdf')), findsNothing);
    });
  });

  group('Admin and Expert entry points', () {
    testWidgets('Admin Reports has Create report and no old export buttons',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdminReportsScreen(recordsStream: Stream.value(const [])),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('create-report-button')), findsOneWidget);
      expect(find.text('Create report'), findsOneWidget);
      expect(find.text('Export CSV'), findsNothing);
      expect(find.text('Export PDF'), findsNothing);

      await tester.tap(find.byKey(const Key('create-report-button')));
      await tester.pumpAndSettle();
      expect(find.byType(MonthlyReportScreen), findsOneWidget);
    });

    test('the Expert Workspace has a Reports tab', () {
      expect(ExpertShellScreen.tabLabels[7], 'Reports');
      expect(
        kExpertNavEntries
            .whereType<AdminNavItemData>()
            .any((e) => e.label == 'Reports' && e.index == 7),
        isTrue,
      );
    });
  });
}
