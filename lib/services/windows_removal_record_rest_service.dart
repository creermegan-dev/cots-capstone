import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/removal_record_model.dart';
import '../models/record_collection.dart';
import 'windows_auth_rest_service.dart';

/// Firestore `removal_records` over HTTPS for Windows desktop.
class WindowsRemovalRecordRestService {
  WindowsRemovalRecordRestService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _options = DefaultFirebaseOptions.windows;

  Future<String> createRemovalRecord({
    required String idToken,
    required String captureId,
    required String uid,
    required String submittedBy,
    required String imageName,
    required int? removedQuantity,
    required String? removalMethod,
    required String notes,
    required double? depth,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required String zone,
    String municipality = '',
    String barangay = '',
    String? submissionId,
    int? aiVerifiedCount,
    double? aiConfidence,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final documentId = submissionId ?? RemovalRecordModel.newDocumentId();
    final fields = <String, dynamic>{
      'capture_id': _string(captureId),
      'uid': _string(uid),
      'submitted_by': _string(submittedBy),
      'image_name': _string(imageName),
      'has_processed_image': _bool(true),
      'removed_quantity':
          removedQuantity == null ? {'nullValue': null} : _int(removedQuantity),
      'removal_method': _string(removalMethod ?? ''),
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
          _string(RemovalRecordModel.formatDisplayRecordId(documentId)),
    };

    if (dateTaken != null) {
      fields['date_taken'] = _timestamp(dateTaken.toUtc().toIso8601String());
    }
    if (depth != null) {
      fields['depth'] = _double(depth);
      fields['capture_depth'] = _double(depth);
      fields['capture_depth_unit'] = _string('meters');
    }
    if (aiVerifiedCount != null) {
      fields['ai_verified_count'] = _int(aiVerifiedCount);
    }
    if (aiConfidence != null) {
      fields['ai_confidence'] = _double(aiConfidence);
    }

    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/${RecordCollection.removalRecords}'
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
    if (response.statusCode == 409 && submissionId != null) {
      final existing = await _client.get(
        Uri.parse(
            'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
            '/databases/(default)/documents/${RecordCollection.removalRecords}/${Uri.encodeComponent(documentId)}'),
        headers: {'Authorization': 'Bearer $idToken'},
      );
      if (existing.statusCode != 200) {
        throw StateError('Could not verify the saved removal.');
      }
      final saved = RemovalRecordModel.fromRestDocument(
          jsonDecode(existing.body) as Map<String, dynamic>);
      if (saved.uid != uid ||
          saved.captureId != captureId ||
          saved.imageName != imageName ||
          saved.removedQuantity != removedQuantity ||
          saved.removalMethod != (removalMethod ?? '') ||
          saved.notes != notes) {
        throw StateError(
            'The saved removal differs from this retry. Its original data was preserved.');
      }
      return documentId;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not submit removal record (${response.statusCode}).',
      );
    }
    return documentId;
  }

  Future<List<RemovalRecordModel>> queryAll({
    required String idToken,
    Map<String, CaptureLink> captureLinks = const {},
  }) async {
    final body = await _runQuery(
      idToken: idToken,
      structuredQuery: {
        'from': [
          {'collectionId': RecordCollection.removalRecords},
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'submitted_at'},
            'direction': 'DESCENDING',
          },
        ],
      },
    );
    return _parseQueryResults(body, captureLinks);
  }

  Future<List<RemovalRecordModel>> queryForUser({
    required String idToken,
    required String uid,
    Map<String, CaptureLink> captureLinks = const {},
  }) async {
    final body = await _runQuery(
      idToken: idToken,
      structuredQuery: {
        'from': [
          {'collectionId': RecordCollection.removalRecords},
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
    final records = _parseQueryResults(body, captureLinks);
    records.sort(
      (a, b) => (b.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.submittedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return records;
  }

  Stream<List<RemovalRecordModel>> watchAll({
    required String idToken,
    Map<String, CaptureLink> captureLinks = const {},
  }) {
    return _poll(
      () => queryAll(idToken: idToken, captureLinks: captureLinks),
    );
  }

  Stream<List<RemovalRecordModel>> _poll(
    Future<List<RemovalRecordModel>> Function() fetch,
  ) async* {
    yield await fetch();
    yield* Stream.periodic(
      const Duration(seconds: 15),
      (_) => null,
    ).asyncMap((_) => fetch());
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
        'Could not load removal records (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded;
  }

  List<RemovalRecordModel> _parseQueryResults(
    List<dynamic> rows,
    Map<String, CaptureLink> captureLinks,
  ) {
    final records = <RemovalRecordModel>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final doc = row['document'];
      if (doc is! Map<String, dynamic>) continue;
      final model = RemovalRecordModel.fromRestDocument(doc);
      final link = captureLinks[model.captureId];
      if (link == null) {
        records.add(model);
      } else {
        records.add(
          RemovalRecordModel(
            id: model.id,
            captureId: model.captureId,
            uid: model.uid,
            submittedBy: model.submittedBy,
            imageName: model.imageName,
            removedQuantity: model.removedQuantity,
            removalMethod: model.removalMethod,
            zone: model.zone,
            notes: model.notes,
            submittedAt: model.submittedAt,
            dateTaken: model.dateTaken,
            latitude: model.latitude,
            longitude: model.longitude,
            aiVerifiedCount: model.aiVerifiedCount,
            aiConfidence: model.aiConfidence,
            linkedCaptureDisplayId: link.displayId,
            linkedCaptureAiCount: link.aiCount,
            storedDisplayRecordId: model.storedDisplayRecordId,
          ),
        );
      }
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
