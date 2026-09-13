import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/firebase_bootstrap.dart';
import '../features/admin/models/admin_record_table_row.dart';
import '../models/record_collection.dart';
import '../models/removal_record_model.dart';
import '../models/scan_record_model.dart';
import 'capture_repository.dart';
import 'removal_record_repository.dart';
import 'windows_capture_rest_service.dart';
import 'windows_removal_record_rest_service.dart';
import 'windows_scan_record_rest_service.dart';

/// Reads citizen science submissions from captures, removal_records, and legacy scan_records.
abstract final class ScanRecordRepository {
  static String? _windowsIdToken;
  static final WindowsScanRecordRestService _windowsLegacyRest =
      WindowsScanRecordRestService();
  static final WindowsCaptureRestService _windowsCaptureRest =
      WindowsCaptureRestService();
  static final WindowsRemovalRecordRestService _windowsRemovalRest =
      WindowsRemovalRecordRestService();

  static void setWindowsIdToken(String? idToken) {
    _windowsIdToken = idToken;
  }

  static String? get windowsIdToken => _windowsIdToken;

  static CollectionReference<Map<String, dynamic>> get _legacyCollection =>
      FirebaseFirestore.instance.collection(RecordCollection.legacyScanRecords);

  static Stream<List<ScanRecordModel>> watchAll() {
    if (deferFirebaseUntilFirstUse) {
      final token = _windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load scan records.'),
        );
      }
      return _pollWindows(token, uid: null);
    }

    return _mergeRecordStreams(
      legacy: _legacyCollection
          .orderBy('submitted_at', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs.map(ScanRecordModel.fromFirestore).toList(),
          ),
      captures: CaptureRepository.watchAll().map(
        (list) => list.map(ScanRecordModel.fromCapture).toList(),
      ),
      removals: RemovalRecordRepository.watchAll().map(
        (list) => list.map(ScanRecordModel.fromRemovalRecord).toList(),
      ),
    );
  }

  static Stream<List<ScanRecordModel>> watchForUser(String uid) {
    if (deferFirebaseUntilFirstUse) {
      final token = _windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load scan records.'),
        );
      }
      return _pollWindows(token, uid: uid);
    }

    return _mergeRecordStreams(
      legacy: _legacyCollection.where('uid', isEqualTo: uid).snapshots().map(
        (snap) {
          final records = snap.docs.map(ScanRecordModel.fromFirestore).toList();
          records.sort(_submittedDesc);
          return records;
        },
      ),
      captures: CaptureRepository.watchForUser(uid).map(
        (list) => list.map(ScanRecordModel.fromCapture).toList(),
      ),
      removals: RemovalRecordRepository.watchForUser(uid).map(
        (list) => list.map(ScanRecordModel.fromRemovalRecord).toList(),
      ),
    );
  }

  static Stream<List<ScanRecordModel>> watchRecent({int limit = 5}) {
    return watchAll().map((records) => records.take(limit).toList());
  }

  static Stream<List<AdminRecordTableRow>> watchAdminTableRows() {
    return watchAll().map(
      (records) => [
        for (var i = 0; i < records.length; i++)
          records[i].toAdminTableRow(i + 1),
      ],
    );
  }

  static Stream<List<ScanRecordModel>> _pollWindows(
    String token, {
    required String? uid,
  }) async* {
    yield await _fetchWindows(token, uid: uid);
    yield* Stream.periodic(
      const Duration(seconds: 15),
      (_) => null,
    ).asyncMap((_) => _fetchWindows(token, uid: uid));
  }

  static Future<List<ScanRecordModel>> _fetchWindows(
    String token, {
    required String? uid,
  }) async {
    final legacy = uid == null
        ? await _windowsLegacyRest.queryAll(idToken: token)
        : await _windowsLegacyRest.queryForUser(idToken: token, uid: uid);
    final captures = uid == null
        ? await _windowsCaptureRest.queryAll(idToken: token)
        : await _windowsCaptureRest.queryForUser(idToken: token, uid: uid);
    final captureLinks = {
      for (final c in captures)
        c.id: CaptureLink(
          id: c.id,
          displayId: c.displayRecordId,
          aiCount: c.aiDetectedCount,
          zone: c.zone,
        ),
    };
    final removals = uid == null
        ? await _windowsRemovalRest.queryAll(
            idToken: token,
            captureLinks: captureLinks,
          )
        : await _windowsRemovalRest.queryForUser(
            idToken: token,
            uid: uid,
            captureLinks: captureLinks,
          );

    return _mergeLists(
      legacy: legacy,
      captures: captures.map(ScanRecordModel.fromCapture).toList(),
      removals: removals.map(ScanRecordModel.fromRemovalRecord).toList(),
    );
  }

  static Stream<List<ScanRecordModel>> _mergeRecordStreams({
    required Stream<List<ScanRecordModel>> legacy,
    required Stream<List<ScanRecordModel>> captures,
    required Stream<List<ScanRecordModel>> removals,
  }) {
    final controller = StreamController<List<ScanRecordModel>>();
    List<ScanRecordModel> legacyList = const [];
    List<ScanRecordModel> captureList = const [];
    List<ScanRecordModel> removalList = const [];

    void emit() {
      controller.add(
        _mergeLists(
          legacy: legacyList,
          captures: captureList,
          removals: removalList,
        ),
      );
    }

    final legacySub = legacy.listen((value) {
      legacyList = value;
      emit();
    });
    final captureSub = captures.listen((value) {
      captureList = value;
      emit();
    });
    final removalSub = removals.listen((value) {
      removalList = value;
      emit();
    });

    controller.onCancel = () async {
      await legacySub.cancel();
      await captureSub.cancel();
      await removalSub.cancel();
    };

    return controller.stream;
  }

  static List<ScanRecordModel> _mergeLists({
    required List<ScanRecordModel> legacy,
    required List<ScanRecordModel> captures,
    required List<ScanRecordModel> removals,
  }) {
    final merged = <ScanRecordModel>[
      ...captures,
      ...removals,
      ...legacy,
    ];
    merged.sort(_submittedDesc);
    return merged;
  }

  static int _submittedDesc(ScanRecordModel a, ScanRecordModel b) {
    return (b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
  }
}
