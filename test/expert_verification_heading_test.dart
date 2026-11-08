import 'package:cots_monitor/features/admin/models/admin_record_table_row.dart';
import 'package:cots_monitor/features/admin/screens/admin_record_details_screen.dart';
import 'package:cots_monitor/models/cots_confidence_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final layout in [(320.0, 1.0), (390.0, 1.5), (1200.0, 1.0)]) {
    testWidgets('completed expert review heading fits at $layout',
        (tester) async {
      tester.view.physicalSize = Size(layout.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(layout.$2)),
          child: child!,
        ),
        home: const AdminRecordDetailsScreen(
          expertContext: true,
          row: AdminRecordTableRow(
              1, 'REC-test', 'Test site', '', 1, null, 'Low', 'Diver', 78,
              adminConfirmed: true,
              adminCotsDecisions: [PerCotsAdminDecision.confirmed]),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.text('Per-COTS Verification · Review complete'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(
          find.text('Per-COTS Verification · Review complete'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
