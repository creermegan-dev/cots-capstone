import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import '../models/intervention_assignment_model.dart';
import '../models/record_collection.dart';
import 'windows_auth_rest_service.dart';

/// Firestore REST implementation for intervention assignments on Windows.
class WindowsInterventionAssignmentRestService {
  WindowsInterventionAssignmentRestService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _options = DefaultFirebaseOptions.windows;

  String get _base =>
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents';

  Future<InterventionAssignmentModel?> getByCapture({
    required String idToken,
    required String captureId,
  }) async {
    final response = await _client.get(
      Uri.parse(
          '$_base/${RecordCollection.interventionAssignments}/$captureId'),
      headers: {'Authorization': 'Bearer $idToken'},
    );
    if (response.statusCode == 404 || response.statusCode == 403) {
      // Missing doc, or rules deny read for this role — treat as no assignment.
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not load assignment (${response.statusCode}).',
      );
    }
    return InterventionAssignmentModel.fromRestDocument(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<InterventionAssignmentModel>> queryForAssignee({
    required String idToken,
    required String uid,
  }) async {
    final rows = await _runQuery(
      idToken: idToken,
      query: {
        'from': [
          {'collectionId': RecordCollection.interventionAssignments},
        ],
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'assigned_to_uid'},
            'op': 'EQUAL',
            'value': {'stringValue': uid},
          },
        },
      },
    );
    return _parse(rows);
  }

  Stream<List<InterventionAssignmentModel>> watchForAssignee({
    required String idToken,
    required String uid,
  }) async* {
    yield await queryForAssignee(idToken: idToken, uid: uid);
    yield* Stream.periodic(const Duration(seconds: 15)).asyncMap(
      (_) => queryForAssignee(idToken: idToken, uid: uid),
    );
  }

  Future<void> assign({
    required String idToken,
    required InterventionAssignmentModel assignment,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final fields = <String, dynamic>{
      'capture_id': _string(assignment.captureId),
      'capture_display_id': _string(assignment.captureDisplayId),
      'zone': _string(assignment.zone),
      'assigned_to_uid': _string(assignment.assignedToUid),
      'assigned_to_name': _string(assignment.assignedToName),
      'assigned_by_uid': _string(assignment.assignedByUid),
      'assigned_by_name': _string(assignment.assignedByName),
      'assigned_at': _timestamp(now),
      'due_at': _timestamp(
        (assignment.dueAt ?? DateTime.now().add(const Duration(days: 7)))
            .toUtc()
            .toIso8601String(),
      ),
      'status': _string(InterventionAssignmentModel.assignedStatus),
      'removal_record_id': _string(''),
    };
    await _patchDocument(
      idToken: idToken,
      documentId: assignment.captureId,
      fields: fields,
    );
  }

  Future<void> updateStatus({
    required String idToken,
    required String captureId,
    required String status,
    String removalRecordId = '',
  }) async {
    final fields = <String, dynamic>{
      'status': _string(status),
      'removal_record_id': _string(removalRecordId),
    };
    if (status == InterventionAssignmentModel.evidenceSubmittedStatus) {
      fields['evidence_submitted_at'] =
          _timestamp(DateTime.now().toUtc().toIso8601String());
    }
    await _patchDocument(
      idToken: idToken,
      documentId: captureId,
      fields: fields,
    );
  }

  Future<void> _patchDocument({
    required String idToken,
    required String documentId,
    required Map<String, dynamic> fields,
  }) async {
    final mask = fields.keys
        .map((f) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(f)}')
        .join('&');
    final response = await _client.patch(
      Uri.parse(
        '$_base/${RecordCollection.interventionAssignments}/$documentId?$mask',
      ),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not save assignment (${response.statusCode}).',
      );
    }
  }

  Future<List<dynamic>> _runQuery({
    required String idToken,
    required Map<String, dynamic> query,
  }) async {
    final response = await _client.post(
      Uri.parse('$_base:runQuery'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'structuredQuery': query}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not load assignments (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    return decoded is List ? decoded : const [];
  }

  List<InterventionAssignmentModel> _parse(List<dynamic> rows) {
    final assignments = <InterventionAssignmentModel>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final doc = row['document'];
      if (doc is Map<String, dynamic>) {
        assignments.add(
          InterventionAssignmentModel.fromRestDocument(doc),
        );
      }
    }
    assignments.sort(
      (a, b) =>
          (a.dueAt ?? DateTime(9999)).compareTo(b.dueAt ?? DateTime(9999)),
    );
    return assignments;
  }

  Map<String, dynamic> _string(String value) => {'stringValue': value};
  Map<String, dynamic> _timestamp(String value) => {'timestampValue': value};
}
