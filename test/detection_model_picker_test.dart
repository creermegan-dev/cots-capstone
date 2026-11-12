import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cots_monitor/models/detection_model.dart';
import 'package:cots_monitor/features/user/widgets/detection_model_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all three selected assets match their recorded version fingerprints',
      () async {
    for (final model in DetectionModel.values) {
      expect(
          sha256.convert(await File(model.assetPath).readAsBytes()).toString(),
          model.sha256);
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('picker selects each model on a narrow screen at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = DetectionModel.yolo11;
      var enabled = true;
      late StateSetter update;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: StatefulBuilder(builder: (context, setState) {
          update = setState;
          return Padding(
              padding: const EdgeInsets.all(16),
              child: DetectionModelPicker(
                value: selected,
                enabled: enabled,
                onChanged: (model) => setState(() => selected = model),
              ));
        }),
      ))));
      for (final model in DetectionModel.values) {
        await tester.tap(find.byType(DropdownButtonFormField<DetectionModel>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(model.label).last);
        await tester.pumpAndSettle();
        expect(selected, model);
      }
      update(() => enabled = false);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<DropdownButtonFormField<DetectionModel>>(
                  find.byType(DropdownButtonFormField<DetectionModel>))
              .onChanged,
          isNull);
      expect(tester.takeException(), isNull);
    });
  }
}
