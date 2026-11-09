import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/submission_group.dart';
import 'package:cots_monitor/models/record_collection.dart';
import 'package:flutter_test/flutter_test.dart';

ScanRecordModel photo(String id,
        {String owner = 'diver',
        String batch = 'batch',
        String site = 'S1',
        double confidence = .9,
        bool accepted = false,
        bool rejected = false,
        int count = 1,
        String followUp = '',
        String serverStatus = '',
        String assignedTo = ''}) =>
    ScanRecordModel.fromCapture(CaptureModel(
      id: id,
      uid: owner,
      submittedBy: 'Diver',
      imageName: '$id.jpg',
      aiDetectedCount: count,
      confidence: confidence,
      captureSource: 'camera',
      zone: 'Site',
      notes: '',
      submittedAt: DateTime.utc(2026, 11, 5),
      encounterId: batch,
      monitoringAreaId: site,
      latitude: 7.0,
      longitude: 125.0,
      adminConfirmed: accepted,
      adminRejected: rejected,
      followUpSurveyId: followUp,
      zoneAssignedTo: assignedTo,
      serverStatus: serverStatus,
    ));

void main() {
  test('legacy, removal and survey rows remain standalone', () {
    final records = [
      for (final collection in [
        RecordCollection.legacyScanRecords,
        RecordCollection.removalRecords,
        RecordCollection.followUpSurveys
      ])
        for (final id in ['a', 'b'])
          ScanRecordModel(
            id: id,
            uid: 'diver',
            submittedBy: 'Diver',
            imageName: '',
            imagePath: '',
            activityType: 'detection_only',
            aiDetectedCount: 1,
            confidence: .9,
            captureSource: 'camera',
            zone: 'Site',
            notes: '',
            submittedAt: DateTime(2026),
            recordCollection: collection,
          ),
    ];
    final groups = SubmissionGroup.fromRecords(records);
    expect(groups.length, 6);
    expect(groups.every((group) => group.records.length == 1), isTrue);
    expect(
        groups
            .where((group) =>
                group.records.first.recordCollection ==
                RecordCollection.removalRecords)
            .every(
                (g) => g.reviewStatus == SubmissionReviewStatus.notApplicable),
        isTrue);
  });

  test(
      'same batch, owner and site form one immutable group with original photos',
      () {
    final a = photo('a', count: 2), b = photo('b');
    final group = SubmissionGroup.fromRecords([b, a]).single;
    expect(group.photoCount, 2);
    expect(group.detectedCount, 3);
    expect(group.cotsTally.confirmed, 3);
    expect(group.records, [a, b]);
    expect(identical(group.records.first, a), isTrue);
    expect(group.records.first.latitude, 7.0);
    expect(group.encounterId, 'batch');
    expect(group.siteId, 'S1');
    expect(group.reviewStatus, SubmissionReviewStatus.accepted);
    expect(() => group.records.clear(), throwsUnsupportedError);
    expect(SubmissionGroup.fromRecords([a, b]).single.key, group.key);
  });

  test('different owners, sites and batches never merge', () {
    final groups = SubmissionGroup.fromRecords([
      photo('a'),
      photo('b', site: 'S2'),
      photo('c', owner: 'other'),
      photo('d', batch: 'other'),
    ]);
    expect(groups.length, 4);
    expect(groups.where((g) => g.hasCrossSiteEncounter).length, 2);
  });

  test(
      'missing metadata and follow-up captures remain separate despite identical GPS/time',
      () {
    for (final records in [
      [photo('a', batch: ''), photo('b', batch: '')],
      [photo('a', site: ''), photo('b', site: '')],
      [photo('a', owner: ''), photo('b', owner: '')],
      [photo('a', followUp: 'visit'), photo('b', followUp: 'visit')],
    ]) {
      expect(SubmissionGroup.fromRecords(records).length, 2);
    }
  });

  test('duplicate snapshots do not double count photos', () {
    final a = photo('a');
    final group = SubmissionGroup.fromRecords([a, a, photo('b')]).single;
    expect(group.photoCount, 2);
    expect(group.detectedCount, 2);
  });

  test(
      'pending review dominates accepted and retake photos until decisions finish',
      () {
    final group = SubmissionGroup.fromRecords([
      photo('a'),
      photo('b', confidence: .6),
      photo('c', rejected: true),
    ]).single;
    expect(group.reviewStatus, SubmissionReviewStatus.pendingReview);
    expect(group.cotsTally.confirmed, 1);
    expect(group.cotsTally.waiting, 1);
    expect(group.cotsTally.notAccepted, 1);
    final finished = SubmissionGroup.fromRecords([
      photo('a'),
      photo('b', confidence: .6, accepted: true),
      photo('c', rejected: true),
    ]).single;
    expect(finished.reviewStatus, SubmissionReviewStatus.partiallyAccepted);
  });

  test(
      'zone approval and evidence processing are not presented as completed review',
      () {
    expect(
        SubmissionGroup.fromRecords([photo('a', assignedTo: 'another diver')])
            .single
            .reviewStatus,
        SubmissionReviewStatus.pendingReview);
    expect(
        SubmissionGroup.fromRecords([photo('a', serverStatus: 'pending')])
            .single
            .reviewStatus,
        SubmissionReviewStatus.processing);
    expect(
        SubmissionGroup.fromRecords([photo('a', rejected: true)])
            .single
            .reviewStatus,
        SubmissionReviewStatus.retakeRequired);
    expect(
        SubmissionGroup.fromRecords([photo('a'), photo('b', count: 0)])
            .single
            .reviewStatus,
        SubmissionReviewStatus.partiallyAccepted);
  });

  test(
      'historical capture REST metadata retains the batch through ScanRecordModel',
      () {
    final capture = CaptureModel.fromRestFields({
      'uid': {'stringValue': 'diver'},
      'encounter_id': {'stringValue': 'historic-batch'},
      'monitoring_area_id': {'stringValue': 'S2'},
    }, id: 'historic');
    final record = ScanRecordModel.fromCapture(capture);
    expect(record.encounterId, 'historic-batch');
    expect(record.monitoringAreaId, 'S2');
  });
}
