import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/activity_type.dart';
import '../models/capture_model.dart';
import '../models/cots_confidence_policy.dart';
import '../models/cots_detection_result.dart';
import '../models/record_collection.dart';
import 'processed_detection_payload.dart';
import 'windows_auth_rest_service.dart';

/// Firestore `captures` over HTTPS for Windows desktop.
class WindowsCaptureRestService {
  WindowsCaptureRestService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _options = DefaultFirebaseOptions.windows;

  Future<String> createCapture({
    required String idToken,
    required String uid,
    required String submittedBy,
    required String imageName,
    required CotsDetectionResult detection,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required int? imageWidth,
    required int? imageHeight,
    required String notes,
    required double? depth,
    required String zone,
    String municipality = '',
    String barangay = '',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final documentId = CaptureModel.newDocumentId();
    final fields = <String, dynamic>{
      'uid': _string(uid),
      'submitted_by': _string(submittedBy),
      'image_name': _string(imageName),
      'has_processed_image': _bool(true),
      'ai_detected_count': _int(detection.count),
      'cots_count': _int(detection.count),
      'confidence': _double(detection.confidence),
      'capture_source': _string(CaptureSource.goProUnderwaterImage),
      'citizen_contribution': _bool(true),
      'notes': _string(notes),
      'zone': _string(zone),
      'municipality': _string(municipality),
      'barangay': _string(barangay),
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
      'display_record_id':
          _string(CaptureModel.formatDisplayRecordId(documentId)),
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

    final detectionBoxes = ProcessedDetectionPayload.detectionBoxesForStorage(
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

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/${RecordCollection.captures}'
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
        'Could not submit capture (${response.statusCode}).',
      );
    }
    return documentId;
  }

  Future<List<CaptureModel>> queryAll({required String idToken}) async {
    final body = await _runQuery(
      idToken: idToken,
      structuredQuery: {
        'from': [
          {'collectionId': RecordCollection.captures},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'submitted_at'},
            'direction': 'DESCENDING',
          },
        ],
      },
    );
    return _parseQueryResults(body);
  }

  Future<List<CaptureModel>> queryForUser({
    required String idToken,
    required String uid,
  }) async {
    final body = await _runQuery(
      idToken: idToken,
      structuredQuery: {
        'from': [
          {'collectionId': RecordCollection.captures},
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

  Stream<List<CaptureModel>> watchAll({required String idToken}) {
    return _poll(() => queryAll(idToken: idToken));
  }

  Stream<List<CaptureModel>> watchForUser({
    required String idToken,
    required String uid,
  }) {
    return _poll(() => queryForUser(idToken: idToken, uid: uid));
  }

  Stream<List<CaptureModel>> _poll(
    Future<List<CaptureModel>> Function() fetch,
  ) async* {
    yield await fetch();
    yield* Stream.periodic(
      const Duration(seconds: 15),
      (_) => null,
    ).asyncMap((_) => fetch());
  }

  Future<void> updateAdminVerification({
    required String idToken,
    required String captureId,
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
      '/databases/(default)/documents/${RecordCollection.captures}/$captureId?$maskQuery',
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
          'admin_reviewed_at': _timestamp(DateTime.now().toUtc().toIso8601String()),
          'admin_cots_decisions': {
            'arrayValue': {
              'values': [
                for (final d in PerCotsAdminDecisionX.listToStorage(cotsDecisions))
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
        'Could not load captures (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded;
  }

  List<CaptureModel> _parseQueryResults(List<dynamic> rows) {
    final records = <CaptureModel>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final doc = row['document'];
      if (doc is! Map<String, dynamic>) continue;
      records.add(CaptureModel.fromRestDocument(doc));
    }
    return records;
  }

  Map<String, dynamic> _string(String value) => {'stringValue': value};
  Map<String, dynamic> _int(int value) => {'integerValue': '$value'};
  Map<String, dynamic> _double(num? value) =>
      {'doubleValue': value?.toDouble() ?? 0.0};
  Map<String, dynamic> _bool(bool value) => {'booleanValue': value};
  Map<String, dynamic> _timestamp(String iso) => {'timestampValue': iso};
}
