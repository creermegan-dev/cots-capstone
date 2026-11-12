import 'dart:io';

import 'package:cots_monitor/features/user/scan_detection_page.dart';
import 'package:cots_monitor/models/activity_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stage 1 (claude/agreed_workflow_decisions.md): the removed count comes
/// from the photos, problem photos must be fixed, and the Diver confirms.
void main() {
  test('agreed wording is used exactly', () {
    expect(scanPhotoRuleNote,
        "A photo can show many COTS, but don't photograph the same COTS twice.");
    expect(scanRemovalConfirmationText,
        'I confirm that all COTS in these photos were removed, and each one appears in only one photo.');
    expect(scanNoCotsMessage,
        'No COTS detected. Please upload another photo where COTS are clearly visible.');
    expect(scanAnalysisFailedMessage, contains('Retry'));
  });

  test('photo limits are 15 per first encounter and 10 per monthly visit', () {
    expect(scanMaxEncounterPhotos, 15);
    expect(scanMaxFollowUpPhotos, 10);
  });

  test(
      'zero-COTS photos block both photo flows; absence uses a separate survey',
      () {
    expect(
        scanPhotoNeedsAttention(
            isFollowUp: false, analysisFailed: false, detectedCount: 0),
        isTrue);
    expect(
        scanPhotoNeedsAttention(
            isFollowUp: true, analysisFailed: false, detectedCount: 0),
        isTrue);
    expect(
        scanPhotoNeedsAttention(
            isFollowUp: false, analysisFailed: false, detectedCount: 3),
        isFalse);
  });

  test('a photo the AI could not process must be retried in both forms', () {
    for (final isFollowUp in [false, true]) {
      expect(
          scanPhotoNeedsAttention(isFollowUp: isFollowUp, analysisFailed: true),
          isTrue);
    }
  });

  test('removal methods offered: Manual, Vinegar and Ox bile injections', () {
    expect(RemovalMethod.options.take(3), [
      RemovalMethod.manual,
      RemovalMethod.vinegar,
      RemovalMethod.oxBile,
    ]);
    expect(RemovalMethod.options, isNot(contains(RemovalMethod.injection)));
    expect(RemovalMethod.isInjection(RemovalMethod.vinegar), isTrue);
    expect(RemovalMethod.isInjection(RemovalMethod.oxBile), isTrue);
    expect(RemovalMethod.isInjection(RemovalMethod.manual), isFalse);
  });

  testWidgets('upload step shows the photo note and has no typed COTS count',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: ScanDetectionPage()));
    expect(find.text(scanPhotoRuleNote), findsOneWidget);
    expect(find.textContaining('up to 15 photos'), findsOneWidget);
    expect(find.textContaining('Quantity'), findsNothing);
    expect(find.textContaining('COTS removed'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink()); // dispose live clock
  });

  test('the page no longer has typed removed or observed count fields', () {
    final page =
        File('lib/features/user/scan_detection_page.dart').readAsStringSync();
    expect(page, isNot(contains('_removedQtyController')));
    expect(page, isNot(contains('_fieldObservedController')));
    expect(page, isNot(contains('_fieldEliminatedController')));
    expect(page, contains('!_removalConfirmed'));
  });

  test('Stage 1 migration takes visit counts from the photos', () {
    final sql = File(
      'supabase/migrations/20261031000100_encounters_photo_counts.sql',
    ).readAsStringSync();
    expect(sql, contains('create table public.encounters'));
    expect(sql, contains('removed_count >= 1'));
    expect(sql, contains('photo_cots'));
  });
}
