import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/cots_detection_result.dart';
import '../models/follow_up_monitoring_model.dart';
import 'cots_size_estimator.dart';
import 'follow_up_monitoring_repository.dart';
import 'offline_sync_monitor.dart';
import 'scan_record_service.dart';

typedef OfflineDirectoryProvider = Future<Directory> Function();
typedef OfflineRecordUploader = Future<void> Function(
  Map<String, dynamic> task,
  File image,
);
typedef OfflineSurveyUploader = Future<void> Function(
  Map<String, dynamic> task,
);

class OfflineSubmitResult {
  const OfflineSubmitResult({required this.recordId, required this.isPending});

  final String recordId;
  final bool isPending;
}

/// Durably stores reviewed submissions and retries them after connectivity returns.
/// Drafts never enter this queue.
class OfflineSubmissionService extends ChangeNotifier
    with WidgetsBindingObserver {
  OfflineSubmissionService({
    OfflineDirectoryProvider? directoryProvider,
    OfflineRecordUploader? recordUploader,
    OfflineSurveyUploader? surveyUploader,
    bool enableAutomaticSync = true,
  })  : _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory,
        _recordUploaderOverride = recordUploader,
        _surveyUploaderOverride = surveyUploader,
        _enableAutomaticSync = enableAutomaticSync;

  static final OfflineSubmissionService instance = OfflineSubmissionService();

  final OfflineDirectoryProvider _directoryProvider;
  final OfflineRecordUploader? _recordUploaderOverride;
  final OfflineSurveyUploader? _surveyUploaderOverride;
  final bool _enableAutomaticSync;
  late final OfflineSyncMonitor _connectivityMonitor = OfflineSyncMonitor(
    onOnline: syncPending,
  );
  Timer? _retryTimer;
  bool _initialized = false;
  bool _syncing = false;
  int _pendingCount = 0;
  String? _activeUserId;

  int get pendingCount => _pendingCount;
  bool get isSyncing => _syncing;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (_enableAutomaticSync) WidgetsBinding.instance.addObserver(this);
    await _refreshCount();
    if (_enableAutomaticSync) {
      await _connectivityMonitor.start();
      _retryTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(syncPending()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncPending());
  }

  /// Limits queue visibility and uploads to the currently authenticated user.
  Future<void> setActiveUser(String? uid) async {
    final normalized = uid?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (_activeUserId == next) return;
    _activeUserId = next;
    await _refreshCount();
    if (next != null) await syncPending();
  }

  Future<OfflineSubmitResult> submitRecord({
    required String uid,
    required String submittedBy,
    required String imageName,
    required Uint8List imageBytes,
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
    required String submissionId,
    String? linkedCaptureId,
    bool isFollowUp = false,
    String? followUpSurveyId,
    DateTime? followUpSurveyDate,
    FollowUpAssignmentModel? followUpAssignment,
    void Function(String message)? onWarning,
  }) async {
    _activeUserId = uid.trim();
    final task = <String, dynamic>{
      'version': 1,
      'kind': 'record',
      'id': submissionId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'uid': uid,
      'submitted_by': submittedBy,
      'image_name': imageName,
      'activity_type': activityType,
      'detection': {
        'count': detection.count,
        'confidence': detection.confidence,
        'boxes': detection.boxes.map((box) => box.toMap()).toList(),
      },
      'latitude': latitude,
      'longitude': longitude,
      'date_taken': dateTaken?.toUtc().toIso8601String(),
      'image_width': imageWidth,
      'image_height': imageHeight,
      'notes': notes,
      'depth': depth,
      'confirmed_removed_quantity': confirmedRemovedQuantity,
      'measurement_reference_visible': measurementReferenceVisible,
      'removal_method': removalMethod,
      'size_estimate': sizeEstimate == null
          ? null
          : {
              'per_cots_cm': sizeEstimate.perCotsCm,
              'average_cm': sizeEstimate.averageCm,
              'minimum_cm': sizeEstimate.minimumCm,
              'maximum_cm': sizeEstimate.maximumCm,
              'confidence_score': sizeEstimate.confidenceScore,
            },
      'linked_capture_id': linkedCaptureId,
      'is_follow_up': isFollowUp,
      'follow_up_survey_id': followUpSurveyId,
      'follow_up_survey_date': followUpSurveyDate?.toUtc().toIso8601String(),
      'follow_up_assignment': followUpAssignment == null
          ? null
          : {
              'area_id': followUpAssignment.areaId,
              'area_name': followUpAssignment.areaName,
              'barangay': followUpAssignment.barangay,
              'municipality': followUpAssignment.municipality,
              'primary_diver_uid': followUpAssignment.primaryDiverUid,
              'primary_diver_name': followUpAssignment.primaryDiverName,
              'initial_capture_id': followUpAssignment.initialCaptureId,
              'initial_date':
                  followUpAssignment.initialDate.toUtc().toIso8601String(),
              'initial_detected_count': followUpAssignment.initialDetectedCount,
              'initial_collection': followUpAssignment.initialCollection,
            },
    };
    final directory = await _writeTask(task, imageBytes: imageBytes);
    try {
      await _sendRecord(
        task,
        File('${directory.path}${Platform.pathSeparator}image.jpg'),
        onWarning: onWarning,
      );
      await _deleteTask(directory);
      return OfflineSubmitResult(recordId: submissionId, isPending: false);
    } catch (error) {
      if (!_isConnectivityError(error)) {
        await _deleteTask(directory);
        rethrow;
      }
      await _refreshCount();
      return OfflineSubmitResult(recordId: submissionId, isPending: true);
    }
  }

  Future<bool> submitSurvey({
    required String surveyId,
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
    bool deferUpload = false,
  }) async {
    _activeUserId = uid.trim();
    final task = <String, dynamic>{
      'version': 1,
      'kind': 'survey',
      'id': surveyId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'area_id': areaId,
      'area_name': areaName,
      'barangay': barangay,
      'municipality': municipality,
      'uid': uid,
      'submitted_by': submittedBy,
      'survey_date': surveyDate.toUtc().toIso8601String(),
      'field_observed_count': fieldObservedCount,
      'field_eliminated_count': fieldEliminatedCount,
      'capture_ids': captureIds,
      'ai_detected_count': aiDetectedCount,
      'latitude': latitude,
      'longitude': longitude,
      'surveyed_area_square_meters': surveyedAreaSquareMeters,
      'elimination_method': eliminationMethod,
      'notes': notes,
    };
    final directory = await _writeTask(task);
    if (deferUpload) return true;
    try {
      await _sendSurvey(task);
      await _deleteTask(directory);
      return false;
    } catch (error) {
      if (!_isConnectivityError(error)) {
        await _deleteTask(directory);
        rethrow;
      }
      await _refreshCount();
      return true;
    }
  }

  Future<void> syncPending() async {
    final activeUserId = _activeUserId;
    if (_syncing || activeUserId == null) return;
    _syncing = true;
    notifyListeners();
    try {
      final root = await _queueRoot();
      final tasks = root.existsSync()
          ? root.listSync().whereType<Directory>().toList()
          : <Directory>[];
      tasks.sort((a, b) => a.path.compareTo(b.path));
      for (final directory in tasks) {
        try {
          final metadata =
              File('${directory.path}${Platform.pathSeparator}metadata.json');
          if (!metadata.existsSync()) continue;
          final task = Map<String, dynamic>.from(
            jsonDecode(await metadata.readAsString()) as Map,
          );
          if (task['uid'] != activeUserId) continue;
          if (task['kind'] == 'record') {
            await _sendRecord(task,
                File('${directory.path}${Platform.pathSeparator}image.jpg'));
          } else if (task['kind'] == 'survey') {
            await _sendSurvey(task);
          } else {
            continue;
          }
          await _deleteTask(directory);
        } catch (error) {
          if (_isConnectivityError(error)) break;
          // Invalid tasks remain for manual retry and diagnosis.
        }
      }
    } finally {
      _syncing = false;
      await _refreshCount();
      notifyListeners();
    }
  }

  Future<Directory> _writeTask(Map<String, dynamic> task,
      {Uint8List? imageBytes}) async {
    final root = await _queueRoot();
    final safeId =
        (task['id'] as String).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final safeCreatedAt = (task['created_at'] as String).replaceAll(':', '-');
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}${safeCreatedAt}_$safeId',
    );
    await directory.create(recursive: true);
    if (imageBytes != null) {
      await File('${directory.path}${Platform.pathSeparator}image.jpg')
          .writeAsBytes(imageBytes, flush: true);
    }
    await File('${directory.path}${Platform.pathSeparator}metadata.json')
        .writeAsString(jsonEncode(task), flush: true);
    await _refreshCount();
    return directory;
  }

  Future<Directory> _queueRoot() async {
    final base = await _directoryProvider();
    final root =
        Directory('${base.path}${Platform.pathSeparator}pending_submissions');
    await root.create(recursive: true);
    return root;
  }

  Future<void> _refreshCount() async {
    final root = await _queueRoot();
    final activeUserId = _activeUserId;
    var count = 0;
    if (activeUserId != null) {
      for (final directory in root.listSync().whereType<Directory>()) {
        try {
          final metadata = File(
            '${directory.path}${Platform.pathSeparator}metadata.json',
          );
          if (!metadata.existsSync()) continue;
          final task = jsonDecode(await metadata.readAsString());
          if (task is Map && task['uid'] == activeUserId) count++;
        } catch (_) {
          // A corrupt task is ignored here and retained for diagnosis.
        }
      }
    }
    _pendingCount = count;
    notifyListeners();
  }

  Future<void> _deleteTask(Directory directory) async {
    if (directory.existsSync()) await directory.delete(recursive: true);
    await _refreshCount();
  }

  Future<void> _sendRecord(
    Map<String, dynamic> task,
    File image, {
    void Function(String message)? onWarning,
  }) =>
      _recordUploaderOverride?.call(task, image) ??
      _uploadRecord(task, image, onWarning: onWarning);

  Future<void> _sendSurvey(Map<String, dynamic> task) =>
      _surveyUploaderOverride?.call(task) ?? _uploadSurvey(task);

  Future<void> _uploadRecord(
    Map<String, dynamic> task,
    File image, {
    void Function(String message)? onWarning,
  }) async {
    if (!image.existsSync()) {
      throw StateError('Pending submission image is missing.');
    }
    final detectionMap = Map<String, dynamic>.from(task['detection'] as Map);
    final sizeMap = task['size_estimate'] is Map
        ? Map<String, dynamic>.from(task['size_estimate'] as Map)
        : null;
    final assignmentMap = task['follow_up_assignment'] is Map
        ? Map<String, dynamic>.from(task['follow_up_assignment'] as Map)
        : null;
    await ScanRecordService.submit(
      submissionId: task['id'] as String,
      followUpSurveyId: task['follow_up_survey_id'] as String?,
      followUpSurveyDate: _date(task['follow_up_survey_date']),
      followUpAssignment: assignmentMap == null
          ? null
          : FollowUpAssignmentModel.fromMap(
              assignmentMap,
              areaId: assignmentMap['area_id'] as String,
            ),
      uid: task['uid'] as String,
      submittedBy: task['submitted_by'] as String,
      imageName: task['image_name'] as String,
      imagePath: image.path,
      imageBytes: await image.readAsBytes(),
      activityType: task['activity_type'] as String,
      detection: CotsDetectionResult(
        count: (detectionMap['count'] as num).round(),
        confidence: (detectionMap['confidence'] as num).toDouble(),
        boxes: CotsBoundingBox.listFromDynamic(detectionMap['boxes']),
      ),
      latitude: _double(task['latitude']),
      longitude: _double(task['longitude']),
      dateTaken: _date(task['date_taken']),
      imageWidth: (task['image_width'] as num?)?.round(),
      imageHeight: (task['image_height'] as num?)?.round(),
      notes: task['notes'] as String? ?? '',
      depth: _double(task['depth']),
      confirmedRemovedQuantity:
          (task['confirmed_removed_quantity'] as num?)?.round(),
      measurementReferenceVisible:
          task['measurement_reference_visible'] as bool?,
      removalMethod: task['removal_method'] as String?,
      sizeEstimate: sizeMap == null
          ? null
          : CotsSizeEstimate(
              perCotsCm: (sizeMap['per_cots_cm'] as List)
                  .map((value) => (value as num).toDouble())
                  .toList(),
              averageCm: _double(sizeMap['average_cm'])!,
              minimumCm: _double(sizeMap['minimum_cm'])!,
              maximumCm: _double(sizeMap['maximum_cm'])!,
              confidenceScore: _double(sizeMap['confidence_score'])!,
            ),
      linkedCaptureId: task['linked_capture_id'] as String?,
      isFollowUp: task['is_follow_up'] as bool? ?? false,
      onWarning: onWarning,
    );
  }

  Future<void> _uploadSurvey(Map<String, dynamic> task) async {
    await FollowUpMonitoringRepository.submitSurvey(
      surveyId: task['id'] as String,
      areaId: task['area_id'] as String,
      areaName: task['area_name'] as String,
      barangay: task['barangay'] as String,
      municipality: task['municipality'] as String,
      uid: task['uid'] as String,
      submittedBy: task['submitted_by'] as String,
      surveyDate: _date(task['survey_date'])!,
      fieldObservedCount: (task['field_observed_count'] as num).round(),
      fieldEliminatedCount: (task['field_eliminated_count'] as num).round(),
      captureIds: (task['capture_ids'] as List).cast<String>(),
      aiDetectedCount: (task['ai_detected_count'] as num).round(),
      latitude: _double(task['latitude']),
      longitude: _double(task['longitude']),
      surveyedAreaSquareMeters: _double(task['surveyed_area_square_meters']),
      eliminationMethod: task['elimination_method'] as String? ?? '',
      notes: task['notes'] as String? ?? '',
    );
  }

  bool _isConnectivityError(Object error) {
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return true;
    }
    if (error is FirebaseException) {
      return const {
        'unavailable',
        'deadline-exceeded',
        'network-request-failed',
        'unknown',
      }.contains(error.code);
    }
    final message = error.toString().toLowerCase();
    return message.contains('socket') ||
        message.contains('network') ||
        message.contains('connection') ||
        message.contains('timed out') ||
        message.contains('failed host lookup');
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
  static double? _double(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');

  @override
  void dispose() {
    if (_enableAutomaticSync) WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    if (_enableAutomaticSync) unawaited(_connectivityMonitor.dispose());
    super.dispose();
  }
}
