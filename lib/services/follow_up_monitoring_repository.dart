import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../core/firebase_bootstrap.dart';
import '../firebase_options.dart';
import '../models/capture_model.dart';
import '../models/cots_confidence_policy.dart';
import '../models/cots_detection_result.dart';
import '../models/davao_gulf_geography.dart';
import '../models/follow_up_monitoring_model.dart';
import '../models/record_collection.dart';
import '../models/activity_type.dart';
import 'scan_record_repository.dart';
import 'capture_repository.dart';
import 'capture_image_store.dart';
import 'windows_auth_rest_service.dart';
import 'zone_assignment_service.dart';
import 'follow_up_reassignment_repository.dart';
import 'follow_up_workflow_store.dart';
import '../models/follow_up_reassignment.dart';

abstract final class FollowUpMonitoringRepository {
  static final http.Client _http = http.Client();
  static const _options = DefaultFirebaseOptions.windows;
  static const _assignments = 'follow_up_assignments';
  static const _surveys = 'follow_up_surveys';

  static CollectionReference<Map<String, dynamic>> get _assignmentCollection =>
      FirebaseFirestore.instance.collection(_assignments);

  static CollectionReference<Map<String, dynamic>> get _surveyCollection =>
      FirebaseFirestore.instance.collection(_surveys);

  static Stream<List<FollowUpAssignmentModel>> watchAssignmentsForDiver(
    String uid,
  ) async* {
    Future<List<FollowUpAssignmentModel>> load() async {
      final primary = (await FollowUpReassignmentRepository.store
              .query(_assignments, field: 'primary_diver_uid', value: uid))
          .map((doc) => FollowUpAssignmentModel.fromMap(
              FollowUpWorkflowStore.data(doc),
              areaId: (doc['name'] as String).split('/').last))
          .toList();
      final requests =
          await FollowUpReassignmentRepository.watch(uid: uid).first;
      final byId = {
        for (final assignment in primary) assignment.areaId: assignment
      };
      for (final request in requests) {
        if (!request.isCurrent(DateTime.now()) ||
            request.responsibleUid != uid ||
            byId.containsKey(request.areaId)) {
          continue;
        }
        final doc = await FollowUpReassignmentRepository.store
            .get('$_assignments/${request.areaId}');
        if (doc != null) {
          byId[request.areaId] = FollowUpAssignmentModel.fromMap(
              FollowUpWorkflowStore.data(doc),
              areaId: request.areaId);
        }
      }
      return byId.values.toList()
        ..sort((a, b) => a.areaName.compareTo(b.areaName));
    }

    yield await load();
    yield* Stream.periodic(const Duration(seconds: 15)).asyncMap((_) => load());
  }

  static Stream<List<FollowUpAssignmentModel>> watchPrimaryAssignmentsForDiver(
    String uid,
  ) {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load follow-up assignments.'),
        );
      }
      return _pollWindows(
        () => _queryWindows<FollowUpAssignmentModel>(
          token: token,
          collection: _assignments,
          uid: uid,
          field: 'primary_diver_uid',
          parse: (id, fields) =>
              FollowUpAssignmentModel.fromMap(fields, areaId: id),
        ),
      );
    }

    return _assignmentCollection
        .where('primary_diver_uid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final assignments =
          snapshot.docs.map(FollowUpAssignmentModel.fromFirestore).toList();
      assignments.sort((a, b) => a.areaName.compareTo(b.areaName));
      return assignments;
    });
  }

  static Stream<List<FollowUpSurveyModel>> watchSurveysForDiver(String uid) {
    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        return Stream.error(
          StateError('Not signed in — cannot load follow-up surveys.'),
        );
      }
      return _pollWindows(
        () => querySurveysForDiver(uid, idToken: token),
      );
    }

    return _surveyCollection.where('uid', isEqualTo: uid).snapshots().map(
      (snapshot) {
        final surveys =
            snapshot.docs.map(FollowUpSurveyModel.fromFirestore).toList();
        surveys.sort((a, b) => b.surveyDate.compareTo(a.surveyDate));
        return surveys;
      },
    );
  }

  static Stream<List<FollowUpSurveyModel>> watchMonitoringHistory(
      String uid) async* {
    Future<List<FollowUpSurveyModel>> load() async {
      final own = await querySurveysForDiver(uid);
      final assignments = await watchAssignmentsForDiver(uid).first;
      final surveys = {for (final survey in own) survey.id: survey};
      for (final assignment in assignments) {
        final docs = await FollowUpReassignmentRepository.store
            .query(_surveys, field: 'area_id', value: assignment.areaId);
        for (final doc in docs) {
          final id = (doc['name'] as String).split('/').last;
          surveys[id] = FollowUpSurveyModel.fromMap(
              FollowUpWorkflowStore.data(doc),
              id: id);
        }
      }
      return surveys.values.toList()
        ..sort((a, b) => b.surveyDate.compareTo(a.surveyDate));
    }

    yield await load();
    yield* Stream.periodic(const Duration(seconds: 15)).asyncMap((_) => load());
  }

  static Future<List<FollowUpSurveyModel>> querySurveysForDiver(
    String uid, {
    String? idToken,
  }) async {
    if (deferFirebaseUntilFirstUse) {
      final token = idToken ?? ScanRecordRepository.windowsIdToken;
      if (token == null) {
        throw StateError('Not signed in — cannot load follow-up surveys.');
      }
      final surveys = await _queryWindows<FollowUpSurveyModel>(
        token: token,
        collection: _surveys,
        uid: uid,
        field: 'uid',
        parse: (id, fields) => FollowUpSurveyModel.fromMap(fields, id: id),
      );
      surveys.sort((a, b) => b.surveyDate.compareTo(a.surveyDate));
      return surveys;
    }
    await ensureFirebaseInitialized();
    final snapshot = await _surveyCollection.where('uid', isEqualTo: uid).get();
    final surveys =
        snapshot.docs.map(FollowUpSurveyModel.fromFirestore).toList();
    surveys.sort((a, b) => b.surveyDate.compareTo(a.surveyDate));
    return surveys;
  }

  static Future<List<String>> reconcileHistoricalAssignments({
    required List<CaptureModel> captures,
    required String currentDiverUid,
    bool allowOtherDivers = false,
  }) async {
    final byArea =
        <String, List<({CaptureModel capture, GulfCoastalBarangay area})>>{};
    final ambiguousCaptureIds = <String>[];

    for (final capture in captures) {
      if (capture.aiDetectedCount <= 0 ||
          capture.adminRejected ||
          capture.followUpSurveyId.isNotEmpty) {
        continue;
      }
      if (capture.adminCotsDecisions.length == capture.aiDetectedCount &&
          capture.adminCotsDecisions
              .every((decision) => decision == PerCotsAdminDecision.rejected)) {
        continue;
      }
      final area = _areaForCapture(capture);
      if (area == null) {
        if (capture.uid == currentDiverUid) {
          ambiguousCaptureIds.add(capture.id);
        }
        continue;
      }
      byArea.putIfAbsent(area.id, () => []).add((capture: capture, area: area));
    }

    final municipalities = {
      for (final municipality in DavaoGulfGeography.municipalities)
        municipality.id: municipality,
    };
    for (final entries in byArea.values) {
      final original = originalFollowUpDetection(
          entries.map((entry) => entry.capture).toList());
      if (original == null) {
        ambiguousCaptureIds.addAll(
          entries
              .where((entry) => entry.capture.uid == currentDiverUid)
              .map((entry) => entry.capture.id),
        );
        continue;
      }
      final first =
          entries.firstWhere((entry) => identical(entry.capture, original));
      if (_acceptedCount(first.capture) <= 0) {
        ambiguousCaptureIds.addAll(entries
            .where((entry) => entry.capture.uid == currentDiverUid)
            .map((entry) => entry.capture.id));
        continue;
      }
      if (!allowOtherDivers && first.capture.uid != currentDiverUid) continue;
      final municipality = municipalities[first.area.municipalityId];
      if (municipality == null) {
        ambiguousCaptureIds.add(first.capture.id);
        continue;
      }
      await createAssignmentIfAbsent(
        FollowUpAssignmentModel(
          areaId: first.area.id,
          areaName: '${first.area.zoneLabel} · ${first.area.siteCode}',
          barangay: first.area.name,
          municipality: municipality.name,
          primaryDiverUid: first.capture.uid,
          primaryDiverName: first.capture.submittedBy,
          initialCaptureId: first.capture.id,
          initialDate: first.capture.dateTaken ?? first.capture.submittedAt!,
          initialDetectedCount: first.capture.aiDetectedCount,
          initialCollection: first.capture.sourceCollection,
        ),
      );
    }
    return List.unmodifiable(ambiguousCaptureIds);
  }

  static Future<bool> considerNewDetection({
    required String captureId,
    required String uid,
    required String diverName,
    required CotsDetectionResult detection,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required DateTime submittedAt,
    required int? imageWidth,
    required int? imageHeight,
  }) async {
    if (_acceptedDetectionCount(
          detection: detection,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ) <=
        0) {
      return false;
    }
    final area = ZoneAssignmentService.resolveMonitoringArea(
      latitude: latitude,
      longitude: longitude,
    );
    if (area == null) return false;

    await reconcileHistoricalAssignments(
        captures: await loadDetectionHistory(), currentDiverUid: uid);
    return true;
  }

  static Future<void> considerExpertValidatedCapture(
    CaptureModel capture,
  ) async {
    if (capture.submittedAt == null || capture.followUpSurveyId.isNotEmpty) {
      return;
    }
    final area = _areaForCapture(capture);
    if (area == null) return;
    final history = await loadDetectionHistory();
    await reconcileHistoricalAssignments(
        captures: history
            .where((item) => _areaForCapture(item)?.id == area.id)
            .toList(),
        currentDiverUid: capture.uid,
        allowOtherDivers: true);
  }

  static Future<List<CaptureModel>> loadDetectionHistory() async {
    final captures = await CaptureRepository.watchAll().first;
    final records = await ScanRecordRepository.watchAll().first;
    return [
      ...captures,
      ...records
          .where((record) =>
              !CotsActivityType.isRemoval(record.activityType) &&
              record.recordCollection == RecordCollection.legacyScanRecords)
          .map((record) => CaptureModel(
                id: record.id,
                uid: record.uid,
                submittedBy: record.submittedBy,
                imageName: record.imageName,
                aiDetectedCount: record.aiDetectedCount,
                confidence: record.confidence,
                captureSource: record.captureSource,
                zone: record.zone,
                notes: record.notes,
                submittedAt: record.submittedAt,
                dateTaken: record.dateTaken,
                latitude: record.latitude,
                longitude: record.longitude,
                detectionBoxes: record.detectionBoxes,
                imageWidth: record.imageWidth,
                imageHeight: record.imageHeight,
                adminConfirmed: record.adminConfirmed,
                adminRejected: record.adminRejected,
                adminCotsDecisions: record.adminCotsDecisions,
                sourceCollection: record.recordCollection,
              ))
    ];
  }

  static Future<bool> createAssignmentIfAbsent(
    FollowUpAssignmentModel assignment,
  ) async {
    if (assignment.areaId.trim().isEmpty ||
        assignment.primaryDiverUid.trim().isEmpty ||
        assignment.initialCaptureId.trim().isEmpty ||
        assignment.initialDetectedCount <= 0) {
      throw ArgumentError(
        'A valid area, diver, capture, and COTS count are required.',
      );
    }

    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        throw StateError('Not signed in — cannot save follow-up assignment.');
      }
      return _createWindowsIfAbsent(
        token: token,
        collection: _assignments,
        documentId: assignment.areaId,
        fields: _assignmentRestFields(assignment),
        operation: 'save follow-up assignment',
      );
    }

    await ensureFirebaseInitialized();
    final ref = _assignmentCollection.doc(assignment.areaId);
    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final existing = await transaction.get(ref);
      if (existing.exists) {
        if (existing.data()?['primary_diver_uid'] !=
                assignment.primaryDiverUid ||
            existing.data()?['initial_capture_id'] !=
                assignment.initialCaptureId ||
            (existing.data()?['initial_collection'] ??
                    RecordCollection.captures) !=
                assignment.initialCollection) {
          throw StateError(
              'An existing primary assignment conflicts with reliable detection history for ${assignment.areaId}. It was preserved for review.');
        }
        return false;
      }
      transaction.set(ref, assignment.toFirestore());
      return true;
    });
  }

  static Future<FollowUpSurveyModel> submitSurvey({
    String? surveyId,
    required String areaId,
    required String areaName,
    required String barangay,
    required String municipality,
    required String uid,
    required String submittedBy,
    required DateTime surveyDate,
    required int fieldObservedCount,
    required int fieldEliminatedCount,
    required List<String> captureIds,
    required int aiDetectedCount,
    required double? latitude,
    required double? longitude,
    required double? surveyedAreaSquareMeters,
    required String eliminationMethod,
    required String notes,
  }) async {
    if (areaId.trim().isEmpty || uid.trim().isEmpty) {
      throw ArgumentError(
          'A monitoring area and signed-in diver are required.');
    }
    final assignmentDoc =
        await FollowUpReassignmentRepository.store.get('$_assignments/$areaId');
    if (assignmentDoc == null) {
      throw StateError('This reef monitoring zone is not assigned to you.');
    }
    final assignment = FollowUpAssignmentModel.fromMap(
        FollowUpWorkflowStore.data(assignmentDoc),
        areaId: areaId);
    if (!await FollowUpReassignmentRepository.isResponsible(
        assignment, uid, surveyDate)) {
      throw StateError(
          'Only the authorized diver for this calendar month can submit.');
    }
    await FollowUpReassignmentRepository.ensureMonthAuthorization(
        assignment, uid, surveyDate);
    final day = DateTime(surveyDate.year, surveyDate.month, surveyDate.day);
    final initial = MonitoringMonth.calendar(assignment.initialDate);
    final today = MonitoringMonth.calendar(DateTime.now());
    if (day.isAfter(DateTime(today.year, today.month, today.day)) ||
        day.isBefore(DateTime(initial.year, initial.month, initial.day))) {
      throw ArgumentError(
          'Monitoring date must be between the initial detection and today.');
    }
    if (captureIds.isEmpty ||
        captureIds.length > 8 ||
        captureIds.toSet().length != captureIds.length) {
      throw ArgumentError(
          'Include between 1 and 8 distinct processed image records per visit.');
    }
    if ((latitude == null) != (longitude == null) ||
        (latitude != null &&
            (!latitude.isFinite || latitude < -90 || latitude > 90)) ||
        (longitude != null &&
            (!longitude.isFinite || longitude < -180 || longitude > 180))) {
      throw ArgumentError(
          'Provide a valid coordinate pair or leave both blank.');
    }
    final referenceArea = ZoneAssignmentService.resolveMonitoringArea(
        latitude: latitude, longitude: longitude);
    if (referenceArea != null && referenceArea.barangay.id != areaId) {
      throw ArgumentError('GPS reference belongs to another monitoring zone.');
    }
    var imageCount = 0;
    for (final captureId in captureIds) {
      final capture = await CaptureRepository.getById(captureId);
      if (capture == null ||
          capture.uid != uid ||
          capture.monitoringAreaId != areaId ||
          (surveyId != null && capture.followUpSurveyId != surveyId)) {
        throw StateError(
            'An image record is missing or belongs to another survey or zone.');
      }
      if (await CaptureImageStore.load(captureId: captureId) == null) {
        throw StateError(
            'An image upload is incomplete. Retry the submission.');
      }
      imageCount += capture.aiDetectedCount;
    }
    if (imageCount != aiDetectedCount) {
      throw ArgumentError('AI image totals do not match linked records.');
    }
    if (fieldEliminatedCount > 0 && eliminationMethod.trim().isEmpty) {
      throw ArgumentError('Record the actual elimination method.');
    }
    if (fieldObservedCount < 0 ||
        fieldEliminatedCount < 0 ||
        fieldEliminatedCount > fieldObservedCount) {
      throw ArgumentError(
          'Field observations and eliminated counts are invalid.');
    }
    if (surveyedAreaSquareMeters != null &&
        (!surveyedAreaSquareMeters.isFinite || surveyedAreaSquareMeters <= 0)) {
      throw ArgumentError('Surveyed reef area must be greater than zero.');
    }

    final survey = FollowUpSurveyModel(
      id: surveyId ?? newSurveyId(),
      areaId: areaId,
      areaName: areaName,
      barangay: barangay,
      municipality: municipality,
      uid: uid,
      submittedBy: submittedBy,
      surveyDate: DateTime(surveyDate.year, surveyDate.month, surveyDate.day),
      fieldObservedCount: fieldObservedCount,
      fieldEliminatedCount: fieldEliminatedCount,
      captureIds: List.unmodifiable(captureIds),
      submittedAt: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      surveyedAreaSquareMeters: surveyedAreaSquareMeters,
      eliminationMethod: eliminationMethod,
      notes: notes,
      aiDetectedCount: aiDetectedCount,
    );

    if (deferFirebaseUntilFirstUse) {
      final token = ScanRecordRepository.windowsIdToken;
      if (token == null) {
        throw StateError('Not signed in — cannot submit follow-up survey.');
      }
      await _createWindowsIfAbsent(
        token: token,
        collection: _surveys,
        documentId: survey.id,
        fields: _surveyRestFields(survey),
        operation: 'submit follow-up survey',
      );
    } else {
      await ensureFirebaseInitialized();
      final ref = _surveyCollection.doc(survey.id);
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final existing = await transaction.get(ref);
        if (!existing.exists) {
          transaction.set(ref, survey.toFirestore());
        } else {
          _verifyRetry(existing.data()!, survey.toFirestore());
        }
      });
    }
    return survey;
  }

  static int _acceptedCount(CaptureModel capture) {
    if (capture.aiDetectedCount <= 0 || capture.adminRejected) return 0;
    if (capture.adminCotsDecisions.isNotEmpty) {
      return capture.adminCotsDecisions
          .where((item) => item == PerCotsAdminDecision.confirmed)
          .length;
    }
    if (capture.adminConfirmed) return capture.aiDetectedCount;
    final items = CotsConfidencePolicy.buildDetectionItems(
      count: capture.aiDetectedCount,
      averagePercent: capture.confidencePercent,
      boxes: capture.detectionBoxes.isEmpty ? null : capture.detectionBoxes,
      imageWidth: capture.imageWidth > 0 ? capture.imageWidth : 1920,
      imageHeight: capture.imageHeight > 0 ? capture.imageHeight : 1080,
    );
    return CotsConfidencePolicy.countAutoApproved(items);
  }

  static int _acceptedDetectionCount({
    required CotsDetectionResult detection,
    required int? imageWidth,
    required int? imageHeight,
  }) {
    if (detection.count <= 0) return 0;
    final items = CotsConfidencePolicy.buildDetectionItems(
      count: detection.count,
      averagePercent:
          CotsConfidencePolicy.percentFromConfidence(detection.confidence),
      boxes: detection.boxes.isEmpty ? null : detection.boxes,
      imageWidth: imageWidth ?? 1920,
      imageHeight: imageHeight ?? 1080,
    );
    return CotsConfidencePolicy.countAutoApproved(items);
  }

  static GulfCoastalBarangay? _areaForCapture(CaptureModel capture) {
    final storedId = capture.monitoringAreaId.trim();
    if (storedId.isNotEmpty) {
      final area = DavaoGulfGeography.barangayById(storedId);
      final gpsArea = ZoneAssignmentService.resolveMonitoringArea(
          latitude: capture.latitude, longitude: capture.longitude);
      if (area == null || (gpsArea != null && gpsArea.barangay.id != area.id)) {
        return null;
      }
      return area;
    }
    return ZoneAssignmentService.resolveMonitoringArea(
      latitude: capture.latitude,
      longitude: capture.longitude,
    )?.barangay;
  }

  static Stream<List<T>> _pollWindows<T>(
    Future<List<T>> Function() fetch,
  ) async* {
    yield await fetch();
    yield* Stream.periodic(const Duration(seconds: 15), (_) => null)
        .asyncMap((_) => fetch());
  }

  static Future<List<T>> _queryWindows<T>({
    required String token,
    required String collection,
    required String uid,
    required String field,
    required T Function(String id, Map<String, dynamic> fields) parse,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents:runQuery',
    );
    final response = await _http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'structuredQuery': {
          'from': [
            {'collectionId': collection},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': field},
              'op': 'EQUAL',
              'value': {'stringValue': uid},
            },
          },
        },
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not load $collection (${response.statusCode}).',
      );
    }
    final rows = jsonDecode(response.body);
    if (rows is! List) return const [];
    final items = <T>[];
    for (final row in rows) {
      if (row is! Map<String, dynamic>) continue;
      final document = row['document'];
      if (document is! Map<String, dynamic>) continue;
      final name = document['name'] as String? ?? '';
      final id = name.split('/').last;
      final fields = document['fields'];
      if (fields is! Map<String, dynamic>) continue;
      items.add(parse(id, _decodeRestFields(fields)));
    }
    return items;
  }

  static Future<bool> _createWindowsIfAbsent({
    required String token,
    required String collection,
    required String documentId,
    required Map<String, dynamic> fields,
    required String operation,
  }) async {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
      '/databases/(default)/documents/$collection'
      '?documentId=${Uri.encodeQueryComponent(documentId)}',
    );
    final response = await _http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'fields': fields}),
    );
    if (response.statusCode == 409) {
      final existing = await _http.get(
          Uri.parse(
            'https://firestore.googleapis.com/v1/projects/${_options.projectId}'
            '/databases/(default)/documents/$collection/${Uri.encodeComponent(documentId)}',
          ),
          headers: {'Authorization': 'Bearer $token'});
      if (existing.statusCode != 200) {
        throw StateError('Could not verify an existing $collection record.');
      }
      final document = jsonDecode(existing.body) as Map<String, dynamic>;
      _verifyRetry(
          _decodeRestFields(
              Map<String, dynamic>.from(document['fields'] as Map)),
          _decodeRestFields(fields));
      return false;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WindowsAuthRestException(
        'Could not $operation (${response.statusCode}).',
      );
    }
    return true;
  }

  static void _verifyRetry(
      Map<String, dynamic> existing, Map<String, dynamic> proposed) {
    for (final key in [
      'uid',
      'area_id',
      'primary_diver_uid',
      'initial_capture_id',
      'field_observed_count',
      'field_eliminated_count',
      'ai_detected_count',
      'survey_calendar_date',
      'elimination_method',
      'notes',
      'capture_ids',
      'initial_collection',
      'gps',
      'surveyed_area_square_meters'
    ]) {
      final existingValue = key == 'initial_collection'
          ? existing[key] ?? RecordCollection.captures
          : existing[key];
      if (proposed.containsKey(key) &&
          jsonEncode(existingValue) != jsonEncode(proposed[key])) {
        throw StateError(
            'The saved record differs from this retry ($key). The original record was preserved.');
      }
    }
  }

  static Map<String, dynamic> _assignmentRestFields(
    FollowUpAssignmentModel assignment,
  ) =>
      _encodeFields({
        'area_id': assignment.areaId,
        'area_name': assignment.areaName,
        'barangay': assignment.barangay,
        'municipality': assignment.municipality,
        'primary_diver_uid': assignment.primaryDiverUid,
        'primary_diver_name': assignment.primaryDiverName,
        'initial_capture_id': assignment.initialCaptureId,
        'initial_date': assignment.initialDate,
        'initial_detected_count': assignment.initialDetectedCount,
        'initial_collection': assignment.initialCollection,
        'created_at': DateTime.now().toUtc(),
      });

  static Map<String, dynamic> _surveyRestFields(
    FollowUpSurveyModel survey,
  ) =>
      _encodeFields({
        'area_id': survey.areaId,
        'area_name': survey.areaName,
        'barangay': survey.barangay,
        'municipality': survey.municipality,
        'uid': survey.uid,
        'submitted_by': survey.submittedBy,
        'survey_date': surveyCalendarInstant(survey.surveyDate),
        'survey_calendar_date': surveyCalendarDate(survey.surveyDate),
        'field_observed_count': survey.fieldObservedCount,
        'field_eliminated_count': survey.fieldEliminatedCount,
        'capture_ids': survey.captureIds,
        'gps': {
          'latitude': survey.latitude,
          'longitude': survey.longitude,
        },
        if (survey.surveyedAreaSquareMeters != null)
          'surveyed_area_square_meters': survey.surveyedAreaSquareMeters,
        'elimination_method': survey.eliminationMethod,
        'notes': survey.notes,
        'ai_detected_count': survey.aiDetectedCount,
        'submitted_at': survey.submittedAt ?? DateTime.now().toUtc(),
      });

  static Map<String, dynamic> _encodeFields(Map<String, dynamic> fields) => {
        for (final entry in fields.entries)
          entry.key: _encodeValue(entry.value),
      };

  static Map<String, dynamic> _encodeValue(Object? value) {
    if (value == null) return {'nullValue': null};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is num) return {'doubleValue': value.toDouble()};
    if (value is String) return {'stringValue': value};
    if (value is List) {
      return {
        'arrayValue': {
          'values': [for (final item in value) _encodeValue(item)],
        },
      };
    }
    if (value is Map<String, dynamic>) {
      return {
        'mapValue': {'fields': _encodeFields(value)}
      };
    }
    throw ArgumentError.value(value, 'value', 'Unsupported Firestore value.');
  }

  static Map<String, dynamic> _decodeRestFields(
    Map<String, dynamic> fields,
  ) =>
      {
        for (final entry in fields.entries)
          entry.key: _decodeRestValue(entry.value),
      };

  static Object? _decodeRestValue(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) {
      return int.tryParse('${value['integerValue']}');
    }
    if (value.containsKey('doubleValue')) {
      return double.tryParse('${value['doubleValue']}');
    }
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('nullValue')) return null;
    final mapValue = value['mapValue'];
    if (mapValue is Map<String, dynamic>) {
      final fields = mapValue['fields'];
      if (fields is Map<String, dynamic>) return _decodeRestFields(fields);
    }
    final arrayValue = value['arrayValue'];
    if (arrayValue is Map<String, dynamic>) {
      final values = arrayValue['values'];
      if (values is List) {
        return values.map(_decodeRestValue).toList(growable: false);
      }
    }
    return null;
  }

  static String newSurveyId() {
    final random = math.Random.secure();
    final suffix = List.generate(
      20,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }
}
