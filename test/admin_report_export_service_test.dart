import 'dart:convert';

import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/models/cots_tally.dart';
import 'package:cots_monitor/services/admin_report_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = AdminReportExportService();
  const records = <AdminRecordTableRow>[
    AdminRecordTableRow(
      1,
      'COTS-001',
      'Zone A',
      'Oct 28, 2026',
      3,
      0.2,
      'Low',
      'Diver, One',
      85,
      adminConfirmed: true,
      activityType: 'COTS Detection',
      dateUploaded: 'Oct 28, 2026 10:00 AM',
      cotsTally: CotsTally(confirmed: 2, waiting: 1, notAccepted: 0),
    ),
  ];

  test('CSV export contains real report fields and escapes commas', () {
    final csv = utf8.decode(service.buildCsv(records), allowMalformed: false);

    expect(csv, contains('"Report ID"'));
    expect(csv, contains('"COTS-001"'));
    expect(csv, contains('"Diver, One"'));
    expect(csv, contains('"85%"'));
    expect(csv, contains('"Accepted"'));
    // Stage 3: honest counts instead of the raw AI count.
    expect(csv, contains('"COTS confirmed","COTS waiting","COTS not accepted"'));
    expect(csv, contains('"2","1","0"'));
    expect(csv, isNot(contains('COTS Count')));
  });

  test('PDF export creates a valid PDF document', () async {
    final bytes = await service.buildPdf(records);

    expect(bytes.length, greaterThan(500));
    expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
  });
}
