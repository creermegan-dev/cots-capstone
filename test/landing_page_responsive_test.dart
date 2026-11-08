import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/features/landing/landing_page.dart';

void main() {
  const viewports = <(String, Size, double)>[
    ('Small Mobile (320x568)', Size(320, 568), 1.0),
    ('Small Mobile High Scale (320x568, scale 1.5)', Size(320, 568), 1.5),
    ('Standard Mobile (390x844)', Size(390, 844), 1.0),
    ('Tablet Portrait (768x1024)', Size(768, 1024), 1.0),
    ('Tablet Landscape / Small Laptop (1024x768)', Size(1024, 768), 1.0),
    ('Short Laptop Viewport (1024x500)', Size(1024, 500), 1.0),
    ('Desktop (1440x900)', Size(1440, 900), 1.0),
    ('Wide Desktop (1920x1080)', Size(1920, 1080), 1.0),
  ];

  for (final vp in viewports) {
    testWidgets('LandingPage renders without overflow on ${vp.$1}',
        (tester) async {
      tester.view.physicalSize = vp.$2;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(vp.$3),
            ),
            child: child!,
          ),
          home: const LandingPage(),
        ),
      );

      await tester.pumpAndSettle();

      // Check essential elements are present
      expect(find.text('COTS Monitor'), findsOneWidget);
      expect(find.text('Start monitoring'), findsOneWidget);
      expect(find.byType(LandingPage), findsOneWidget);

      // Verify no exceptions or overflows were thrown
      expect(tester.takeException(), isNull);
    });
  }
}
