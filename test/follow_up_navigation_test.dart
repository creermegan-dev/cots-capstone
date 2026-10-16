import 'package:cots_monitor/features/user/user_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
          routes: {
            userFollowUpRoute: (_) =>
                const Scaffold(body: Text('Assigned monitoring zones'))
          },
          home: Scaffold(
              bottomNavigationBar: UserBottomNavBar(
            active: UserNavDestination.dashboard,
            mapPageBuilder: () => const Scaffold(),
            recordsPageBuilder: () => const Scaffold(),
            profilePageBuilder: () => const Scaffold(),
          )),
        ));
        expect(tester.takeException(), isNull);
        for (final label in [
          'Dashboard',
          'Map',
          'Detect',
          'Follow-up',
          'Records',
          'Profile'
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        await tester.tap(find.text('Follow-up'));
        await tester.pumpAndSettle();
        expect(find.text('Assigned monitoring zones'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
