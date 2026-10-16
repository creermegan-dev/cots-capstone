import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/activity_type.dart';
import '../models/cots_detection_result.dart';
import '../models/cots_confidence_policy.dart';
import '../models/scan_record_model.dart';
import 'cots_size_estimator.dart';
import 'scan_record_service.dart';
import 'windows_auth_rest_service.dart';

/// Firestore `scan_records` over HTTPS for Windows desktop.
class WindowsScanRecordRestService {
  WindowsScanRecordRestService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _options = DefaultFirebaseOptions.windows;

  static const _pollInterval = Duration(seconds: 15);

  Stream<List<ScanRecordModel>> watchAll({required String idToken}) {
    return _poll(() => queryAll(idToken: idToken));
  }

  Stream<List<ScanRecordModel>> watchForUser({
    required String idToken,
    required String uid,
  }) {
    return _poll(() => queryForUser(idToken: idToken, uid: uid));
  }

  Stream<List<ScanRecordModel>> _poll(
    Future<List<ScanRecordModel>> Function() fetch,
  ) async* {
    yield await fetch();
    yield* Stream.periodic(_pollInterval, (_) => null).asyncMap((_) => fetch());
  }

  Future<List<ScanRecordModel>> queryAll({required String idToken}) async {
    final body = await _runQuery(
      idToken: idToken,
      structuredQuery: {
        'from': [
          {'collectionId': 'scan_records'},
        ],
      },
    );
    final records = _parseQueryResults(body);
    records.sort((a, b) => (b.submittedAt ?? DateTime(1970))
        .compareTo(a.submittedAt ?? DateTime(1970)));
    return records;
  }

  Future<List<ScanRecordModel>> queryForUser({
    required String idToken,
    required String uid,
  }) async {
    final body = await _runQuery(
      idToken: idToken,
      structuredQuery: {
        'from': [
          {'collectionId': 'scan_records'},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'uid'},
            'op': 'EQUAL',
            'value': {'stringValue': uid},
          },
        },
      },
    );
    final records = _parseQueryResults(body);
    records.sort(
      (a, b) => (b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return records;
  }

  Future<String> createRecord({
    required String idToken,
    required String uid,
    required String submittedBy,
    required String imageName,
    required String imagePath,
    required String activityType,
    required CotsDetectionResult detection,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required int? imageWidth,
    required int? imageHeight,
    required String notes,
    required double? depth,
    required int? confirmedRemovedQuantity,
    required bool? measurementReferenceVisible,
    required String? removalMethod,
    required CotsSizeEstimate? sizeEstimate,
    required String zone,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final fields = <String, dynamic>{
      'uid': _string(uid),
      'submitted_by': _string(submittedBy),
      'image_name': _string(imageName),
      'image_path': _string(imagePath),
      'image_url': _string(''),
      'has_firestore_image': _bool(true),
      'activity_type': _string(activityType),
      'ai_detected_count': _int(detection.count),
      'cots_count': _int(detection.count),
      'confidence': _double(detection.confidence),
      'capture_source': _string(CaptureSource.goProUnderwaterImage),
      'citizen_contribution': _bool(true),
      'notes': _string(notes),
      'zone': _string(zone),
      'gps': {
        'mapValue': {
          'fields': {
            'latitude': _double(latitude),
            'longitude': _double(longitude),
          },
        },
      },
      'processed_at': _timestamp(now),
      'submitted_at': _timestamp(now),
    };

    if (dateTaken != null) {
      fields['date_taken'] = _timestamp(dateTaken.toUtc().toIso8601String());
    }
    if (imageWidth != null && imageHeight != null) {
      fields['resolution'] = {
        'mapValue': {
          'fields': {
            'width': _int(imageWidth),
            'height': _int(imageHeight),
          },
        },
      };
    }
    if (depth != null) {
      fields['depth'] = _double(depth);
      fields['capture_depth'] = _double(depth);
      fields['capture_depth_unit'] = _string('meters');
    }
    if (CotsActivityType.isRemoval(activityType) &&
        confirmedRemovedQuantity != null) {
      fields['confirmed_removed_quantity'] = _int(confirmedRemovedQuantity);
    }
    if (measurementReferenceVisible != null) {
      fields['measurement_reference_visible'] =
          _bool(measurementReferenceVisible);
    }
    if (removalMethod != null && removalMethod.isNotEmpty) {
      fields['removal_method'] = _string(removalMethod);
    }
    if (sizeEstimate != null) {
      fields['average_size_cm'] = _double(sizeEstimate.averageCm);
      fields['minimum_size_cm'] = _double(sizeEstimate.minimumCm);
      fields['maximum_size_cm'] = _double(sizeEstimate.maximumCm);
      fields['size_confidence_score'] = _double(sizeEstimate.confidenceScore);
      fields['estimated_sizes_cm'] = {
        'arrayValue': {
          'values': [
            for (final cm in sizeEstimate.perCotsCm) _double(cm),
          ],
        },
      };
    }
    final detectionBoxes = ScanRecordService.detectionBoxesForStorage(
      detection: detection,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
    if (detectionBoxes.isNotEmpty) {
      fields['detections'] = {
        'arrayValue': {
          'values': [
            for (final box in detectionBoxes)
              {
                'mapValue': {
                  'fields': {
                    'x1': _double(box.x1),
                    'y1': _double(box.y1),
                    'x2': _double(box.x2),
                    'y2': _double(box.y2),
                    'score': _double(box.score),
                  },
                },
              },
          ],
        },
      };
    }

    final documentId = ScanRecordModel.newDocumentId();
    fields['display_record_id'] =
        _string(ScanRecordModel.formatDisplayRecordId(documentId));

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/scan_records'
      '?documentId=${Uri.encodeQueryComponent(documentId)}',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not submit scan record (${response.statusCode}).',
      );
    }

    return documentId;
  }

  Future<List<dynamic>> _runQuery({
    required String idToken,
    required Map<String, dynamic> structuredQuery,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents:runQuery',
    );
    final response = await _client.post(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'structuredQuery': structuredQuery}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not load scan records (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded;
  }

  List<ScanRecordModel> _parseQueryResults(List<dynamic> rows) {
    final records = <ScanRecordModel>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final doc = row['document'];
      if (doc is! Map<String, dynamic>) continue;
      records.add(ScanRecordModel.fromRestDocument(doc));
    }
    return records;
  }

  Future<void> updateAdminVerification({
    required String idToken,
    required String recordId,
    required bool adminConfirmed,
    required bool adminRejected,
    required String reviewedBy,
    required List<PerCotsAdminDecision> cotsDecisions,
  }) async {
    const maskFields = [
      'admin_confirmed',
      'admin_rejected',
      'admin_reviewed_by',
      'admin_reviewed_at',
      'admin_cots_decisions',
    ];
    final maskQuery = maskFields
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}')
        .join('&');
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/scan_records/$recordId?$maskQuery',
    );

    final response = await _client.patch(
      uri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fields': {
          'admin_confirmed': _bool(adminConfirmed),
          'admin_rejected': _bool(adminRejected),
          'admin_reviewed_by': _string(reviewedBy),
          'admin_reviewed_at':
              _timestamp(DateTime.now().toUtc().toIso8601String()),
          'admin_cots_decisions': {
            'arrayValue': {
              'values': [
                for (final d
                    in PerCotsAdminDecisionX.listToStorage(cotsDecisions))
                  _string(d),
              ],
            },
          },
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not save admin review (${response.statusCode}).',
      );
    }
  }

  Map<String, dynamic> _string(String value) => {'stringValue': value};
  Map<String, dynamic> _int(int value) => {'integerValue': '$value'};
  Map<String, dynamic> _double(num? value) =>
      {'doubleValue': value?.toDouble() ?? 0.0};
  Map<String, dynamic> _bool(bool value) => {'booleanValue': value};
  Map<String, dynamic> _timestamp(String iso) => {'timestampValue': iso};
}
