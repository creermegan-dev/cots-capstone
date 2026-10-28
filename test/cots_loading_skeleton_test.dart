import 'package:cots_monitor/widgets/cots_loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final layout in CotsSkeletonLayout.values) {
    testWidgets('$layout respects reduced motion and disposes its animation',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      try {
        Widget page(bool reducedMotion) => MaterialApp(
              home: MediaQuery(
                  data: MediaQueryData(
                      size: const Size(320, 900),
                      disableAnimations: reducedMotion,
                      textScaler: const TextScaler.linear(2)),
                  child: Scaffold(
                      body: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: CotsLoadingSkeleton(layout: layout)))),
            );
        await tester.pumpWidget(page(false));
        final fade = find.descendant(
            of: find.byType(CotsLoadingSkeleton),
            matching: find.byType(FadeTransition));
        expect(fade, findsOneWidget);
        final initial = tester.widget<FadeTransition>(fade).opacity.value;
        await tester.pump(const Duration(milliseconds: 550));
        expect(tester.widget<FadeTransition>(fade).opacity.value,
            greaterThan(initial));
        expect(find.bySemanticsLabel(RegExp('Loading')), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(page(true));
        expect(fade, findsNothing);
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
}
