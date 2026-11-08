import 'package:cots_monitor/features/user/user_bottom_nav.dart';
import 'package:cots_monitor/features/user/widgets/records_section_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-11-06: Follow-up is no longer a bottom tab; it is the "Monthly visits"
// tab inside Records.
void main() {
  for (final width in [320.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('diver navigation at width $width and text scale $scale',
          (tester) async {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
              bottomNavigationBar: UserBottomNavBar(
            active: UserNavDestination.dashboard,
            mapPageBuilder: () => const Scaffold(),
            recordsPageBuilder: () =>
                const Scaffold(body: Text('Records page')),
            profilePageBuilder: () => const Scaffold(),
          )),
        ));
        expect(tester.takeException(), isNull);
        for (final label in ['Dashboard', 'Map', 'Detect', 'Records', 'Profile']) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text('Follow-up'), findsNothing);
        await tester.tap(find.text('Records'));
        await tester.pumpAndSettle();
        expect(find.text('Records page'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Records has "My records" and "Monthly visits" tabs that switch',
      (tester) async {
    Widget page(RecordsSection active, String body) => Scaffold(
          appBar: AppBar(
            title: const Text('Records'),
            bottom: RecordsSectionTabs(
              active: active,
              onOpen: (context, section) => Navigator.of(context)
                  .pushReplacement(recordsSectionRoute((_) => section ==
                          RecordsSection.visits
                      ? page(RecordsSection.visits, 'Visits body')
                      : page(RecordsSection.records, 'Records body'))),
            ),
          ),
          body: Text(body),
        );
    await tester.pumpWidget(
        MaterialApp(home: page(RecordsSection.records, 'Records body')));
    expect(find.text('My records'), findsOneWidget);
    expect(find.text('Monthly visits'), findsOneWidget);
    await tester.tap(find.text('Monthly visits'));
    await tester.pumpAndSettle();
    expect(find.text('Visits body'), findsOneWidget);
    await tester.tap(find.text('My records'));
    await tester.pumpAndSettle();
    expect(find.text('Records body'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
