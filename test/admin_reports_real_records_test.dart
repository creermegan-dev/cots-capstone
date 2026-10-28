import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/features/admin/screens/admin_reports_screen.dart';

void main() {
  testWidgets('reports render records supplied by the real-record stream',
      (tester) async {
    const row = AdminRecordTableRow(
      1,
      'CAP-REAL-001',
      'Barangay Test Reef',
      'Oct 25, 2026 08:30 PM',
      6,
      null,
      'Moderate',
      'Real Field Diver',
      74,
      activityType: 'New Detection and Removal',
      aiCount: 6,
      removedQuantity: 5,
      documentId: 'capture-real-001',
      dateUploaded: 'Oct 25, 2026 08:30 PM',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminReportsScreen(recordsStream: Stream.value([row])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CAP-REAL-001'), findsOneWidget);
    expect(find.text('Real Field Diver'), findsOneWidget);
    expect(find.text('Barangay Test Reef'), findsWidgets);
    expect(find.text('RPT-00024'), findsNothing);
    expect(find.text('6'), findsWidgets);
  });
}
