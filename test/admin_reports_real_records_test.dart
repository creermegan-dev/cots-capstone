import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/features/admin/screens/admin_reports_screen.dart';
import 'package:cots_monitor/features/admin/widgets/admin_data_table.dart';
import 'package:cots_monitor/models/cots_tally.dart';

void main() {
  testWidgets('report search button and keyboard search use saved rows',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final rows = List.generate(
      12,
      (index) => AdminRecordTableRow(
        index + 1,
        'CAP-REAL-${index.toString().padLeft(3, '0')}',
        'Test Reef',
        'Oct 25, 2026 08:30 PM',
        1,
        null,
        'Low',
        'Diver $index',
        90,
        documentId: 'capture-$index',
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AdminReportsScreen(recordsStream: Stream.value(rows)),
      ),
    ));
    await tester.pumpAndSettle();

    AdminDataTablePaginationBar pagination() =>
        tester.widget(find.byType(AdminDataTablePaginationBar));
    pagination().onPageSelected(1);
    await tester.pumpAndSettle();
    expect(pagination().pageIndex, 1);

    final field = find.byType(TextField);
    await tester.ensureVisible(field);
    await tester.tap(field);
    // Programmatic text does not invoke onChanged: the button must apply it.
    tester.widget<TextField>(field).controller!.text = ' cap-real-001 ';
    await tester.pump();
    await tester.tap(find.byTooltip('Search reports'));
    await tester.pumpAndSettle();
    expect(find.text('CAP-REAL-001'), findsOneWidget);
    expect(find.text('CAP-REAL-010'), findsNothing);
    expect(pagination().pageIndex, 0);
    expect(pagination().summaryText, 'Showing 1 to 1 of 1 reports');
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse);

    await tester.tap(field);
    await tester.enterText(field, 'does not exist');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No reports match your filters.'), findsOneWidget);

    await tester.tap(field);
    tester.widget<TextField>(field).controller!.clear();
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(pagination().summaryText, 'Showing 1 to 10 of 12 reports');
    expect(tester.takeException(), isNull);
  });

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
      cotsTally: CotsTally(confirmed: 5, waiting: 1, notAccepted: 0),
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
    // Stage 3: the total shows confirmed COTS, with the rest beside it.
    expect(find.text('COTS found and removed (confirmed)'), findsWidgets);
    expect(find.text('5'), findsWidgets);
    expect(find.text('1 waiting · 0 not accepted'), findsOneWidget);
  });
}
