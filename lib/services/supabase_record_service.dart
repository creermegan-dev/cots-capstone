import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cots_confidence_policy.dart';
import '../models/cots_detection_result.dart';
import '../models/capture_model.dart';
import '../models/removal_record_model.dart';
import '../models/activity_type.dart';
import 'cots_yolo_detector.dart';
import 'supabase_evidence_service.dart';
import 'zone_assignment_service.dart';

/// Supabase persistence for immutable pending detection and elimination inputs.
/// Evidence storage/finalization is a separate trusted-worker stage.
abstract final class SupabaseRecordService {
  static SupabaseClient get _client => Supabase.instance.client;

  static const _yolo26Sha =
      'e0b0e5e934577706ad60b88fd75ade5992b8da1443b06eedd3cee6b08b874575';
  static const _yolo11Sha =
      'a2707702a7232ac4864921f52f45e00e361efda71f73cd3c1efb8599e1da8e9f';

  static Future<String> submitCapture({
    required String submissionId,
    String? encounterId,
    required String uid,
    required String imageName,
    required Uint8List imageBytes,
    required EvidenceImagePayload evidence,
    required CotsDetectionResult detection,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required int? imageWidth,
    required int? imageHeight,
    required String notes,
    bool? gpsFromPhoto,
    EvidenceProgressCallback? onEvidenceProgress,
  }) async {
    final assignment = ZoneAssignmentService.resolveMonitoringArea(
      latitude: latitude,
      longitude: longitude,
    );
    if (assignment == null) {
      throw StateError(
        'The image GPS location is outside a mapped Supabase monitoring area.',
      );
    }
    if (imageWidth == null ||
        imageWidth <= 0 ||
        imageHeight == null ||
        imageHeight <= 0) {
      throw StateError('Valid source image dimensions are required.');
    }
    if (detection.boxes.length != detection.count) {
      throw StateError(
        'Detection boxes do not match the detected COTS count.',
      );
    }
    if (evidence.width != imageWidth || evidence.height != imageHeight) {
      throw StateError(
        'Evidence dimensions do not match the image used for detection.',
      );
    }
    for (final box in detection.boxes) {
      if (box.x1 < 0 ||
          box.y1 < 0 ||
          box.x2 <= box.x1 ||
          box.y2 <= box.y1 ||
          box.x2 > evidence.width ||
          box.y2 > evidence.height) {
        throw StateError(
          'A detection bounding box is outside the stored evidence image.',
        );
      }
    }

    final area = await _client
        .from('monitoring_areas')
        .select('id,code')
        .eq('code', assignment.barangay.id)
        .eq('active', true)
        .maybeSingle();
    if (area == null) {
      throw StateError(
        'Monitoring area ${assignment.barangay.id} is not configured in Supabase.',
      );
    }

    final captureId = stableUuid('capture', submissionId);
    final capturedAt = (dateTaken ?? DateTime.now()).toUtc();
    final hasGps = latitude != null && longitude != null;
    final row = <String, dynamic>{
      'id': captureId,
      'owner_id': uid,
      'idempotency_key': stableUuid('capture-idempotency', submissionId),
      'area_id': area['id'],
      'captured_at': capturedAt.toIso8601String(),
      'capture_time_source': dateTaken == null ? 'device' : 'exif',
      'original_time_text': dateTaken?.toIso8601String(),
      'timezone_assumed': false,
      'model_name': CotsYoloDetector.modelName,
      'model_sha256':
          CotsYoloDetector.modelName == 'yolo11' ? _yolo11Sha : _yolo26Sha,
      'source_width': imageWidth,
      'source_height': imageHeight,
      'latitude': latitude,
      'longitude': longitude,
      'gps_source': gpsSourceFor(hasGps: hasGps, gpsFromPhoto: gpsFromPhoto),
      'gps_captured_at': gpsCapturedAt(
        hasGps: hasGps,
        gpsFromPhoto: gpsFromPhoto,
        capturedAt: capturedAt,
      ),
      'notes': notes,
      if (encounterId != null)
        'encounter_id': await _ensureEncounter(encounterId, uid),
    };

    try {
      await _client.from('captures').insert(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      await _validateCaptureRetry(captureId, uid, area['id'].toString());
    }

    if (detection.boxes.isNotEmpty) {
      final items = <Map<String, dynamic>>[
        for (var index = 0; index < detection.boxes.length; index++)
          {
            'id': stableUuid('detection-item', '$submissionId:$index'),
            'capture_id': captureId,
            'item_index': index,
            'confidence': detection.boxes[index].score,
            'x1': detection.boxes[index].x1,
            'y1': detection.boxes[index].y1,
            'x2': detection.boxes[index].x2,
            'y2': detection.boxes[index].y2,
          },
      ];
      try {
        await _client.from('detection_items').insert(items);
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        final saved = await _client
            .from('detection_items')
            .select('id')
            .eq('capture_id', captureId);
        if ((saved as List).length != items.length) {
          throw StateError(
            'The saved detection differs from this retry. Its original data was preserved.',
          );
        }
      }
    }

    if (imageBytes.isEmpty || imageName.trim().isEmpty) {
      throw StateError('Detection evidence image is missing.');
    }
    await SupabaseEvidenceService().reserveUploadAndLink(
      purpose: EvidencePurpose.detection,
      ownerId: uid,
      targetId: captureId,
      assetId: stableUuid('detection-media-asset', submissionId),
      assetIdempotencyKey:
          stableUuid('detection-media-asset-idempotency', submissionId),
      variantId: stableUuid('detection-media-variant', submissionId),
      payload: evidence,
      capturedAt: capturedAt,
      captureTimeSource: dateTaken == null ? 'device' : 'exif',
      onProgress: onEvidenceProgress,
    );
    return captureId;
  }

  /// Where the stored coordinates came from. `gpsFromPhoto` is null only for
  /// submissions queued by older builds, which always recorded 'exif'.
  static String gpsSourceFor({required bool hasGps, bool? gpsFromPhoto}) {
    if (!hasGps) return 'unavailable';
    return gpsFromPhoto == false ? 'device_surface' : 'exif';
  }

  /// Photo GPS is as old as the photo; device GPS was read when the photo was
  /// selected, so it is stamped with the submission time instead.
  static String? gpsCapturedAt({
    required bool hasGps,
    bool? gpsFromPhoto,
    required DateTime capturedAt,
    DateTime? now,
  }) {
    if (!hasGps) return null;
    if (gpsFromPhoto == false) {
      return (now ?? DateTime.now()).toUtc().toIso8601String();
    }
    return capturedAt.toIso8601String();
  }

  static Future<String> submitElimination({
    required String submissionId,
    String? encounterId,
    required String captureId,
    required String uid,
    required int? removedCount,
    required String method,
    required String notes,
    required double? latitude,
    required double? longitude,
    required DateTime? dateTaken,
    required EvidenceImagePayload evidence,
    bool? gpsFromPhoto,
    EvidenceProgressCallback? onEvidenceProgress,
  }) async {
    final eliminationId = stableUuid('elimination', submissionId);
    final capturedAt = (dateTaken ?? DateTime.now()).toUtc();
    final hasGps = latitude != null && longitude != null;
    final row = <String, dynamic>{
      'id': eliminationId,
      'owner_id': uid,
      'idempotency_key': stableUuid('elimination-idempotency', submissionId),
      'capture_id': captureId,
      'captured_at': capturedAt.toIso8601String(),
      'removed_count': removedCount,
      // One removal per encounter (photo total from the encounter's photos).
      if (encounterId != null)
        'encounter_id': stableUuid('encounter', encounterId),
      'method': method.trim(),
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'gps_source': gpsSourceFor(hasGps: hasGps, gpsFromPhoto: gpsFromPhoto),
      'gps_captured_at': gpsCapturedAt(
        hasGps: hasGps,
        gpsFromPhoto: gpsFromPhoto,
        capturedAt: capturedAt,
      ),
    };
    try {
      await _client.from('eliminations').insert(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final saved = await _client
          .from('eliminations')
          .select('owner_id,capture_id,removed_count,method')
          .eq('id', eliminationId)
          .maybeSingle();
      if (saved == null ||
          saved['owner_id'] != uid ||
          saved['capture_id'] != captureId ||
          saved['removed_count'] != removedCount ||
          saved['method'] != method.trim()) {
        throw StateError(
          'The saved elimination differs from this retry. Its original data was preserved.',
        );
      }
    }
    await SupabaseEvidenceService().reserveUploadAndLink(
      purpose: EvidencePurpose.elimination,
      ownerId: uid,
      targetId: eliminationId,
      assetId: stableUuid('elimination-media-asset', submissionId),
      assetIdempotencyKey:
          stableUuid('elimination-media-asset-idempotency', submissionId),
      variantId: stableUuid('elimination-media-variant', submissionId),
      payload: evidence,
      capturedAt: capturedAt,
      captureTimeSource: dateTaken == null ? 'device' : 'exif',
      onProgress: onEvidenceProgress,
    );
    return eliminationId;
  }

  /// Saves the Expert's decision through the server function, which checks
  /// the Expert role, per-COTS rules, and history. The background worker then
  /// finalizes or rejects the capture.
  static Future<String> recordExpertDecision({
    required String captureId,
    required bool approve,
    required List<PerCotsAdminDecision> itemDecisions,
    required String reason,
  }) async {
    final rows = await _client
        .from('detection_items')
        .select('id,item_index')
        .eq('capture_id', captureId)
        .order('item_index');
    final itemIds = [
      for (final row in rows as List) (row as Map)['id'].toString(),
    ];
    final result = await _client.rpc<dynamic>(
      'record_expert_decision',
      params: <String, dynamic>{
        'cid': captureId,
        'sid': null,
        'outcome': approve ? 'approve' : 'reject',
        'reason_text': expertReason(reason, approve: approve),
        'corrected': null,
        'item_results': approve
            ? buildExpertItemResults(itemIds: itemIds, decisions: itemDecisions)
            : const <Map<String, String>>[],
      },
    );
    return result?.toString() ?? '';
  }

  /// Pairs each on-screen COTS decision with its stored detection item.
  /// Pending items are left out; the server requires a decision for every
  /// 20–79% item and refuses to accept any item below 20%.
  static List<Map<String, String>> buildExpertItemResults({
    required List<String> itemIds,
    required List<PerCotsAdminDecision> decisions,
  }) {
    if (itemIds.length != decisions.length) {
      throw StateError(
        'This record changed since it was opened. Reload it and review again.',
      );
    }
    return [
      for (var i = 0; i < itemIds.length; i++)
        if (decisions[i] != PerCotsAdminDecision.pending)
          {
            'item_id': itemIds[i],
            'decision':
                decisions[i] == PerCotsAdminDecision.confirmed ? 'approve' : 'reject',
          },
    ];
  }

  static String expertReason(String reason, {required bool approve}) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      return approve
          ? 'Approved after per-COTS review.'
          : 'Rejected after review.';
    }
    return trimmed.length > 2000 ? trimmed.substring(0, 2000) : trimmed;
  }

  /// Review state shown in the app: the latest Expert decision, or the
  /// server's final status when no decision was needed.
  static ExpertReviewState reviewStateFor({
    required String status,
    required List<String> itemIds,
    required List<double> itemConfidences,
    required List<Map<String, dynamic>> decisions,
  }) {
    Map<String, dynamic>? latest;
    for (final decision in decisions) {
      final sequence = (decision['decision_sequence'] as num?) ?? -1;
      final best = (latest?['decision_sequence'] as num?) ?? -1;
      if (latest == null || sequence > best) latest = decision;
    }
    final outcome = latest?['decision']?.toString();
    if (latest == null || outcome == null) {
      return ExpertReviewState(
        confirmed: status == 'finalized',
        rejected: status == 'rejected',
        itemDecisions: const [],
        reviewerId: '',
        reviewedAt: null,
      );
    }
    final byItem = <String, String>{};
    final rawItems = latest['item_decisions'];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          byItem['${raw['item_id']}'] = '${raw['decision']}';
        }
      }
    }
    final approved = outcome == 'approve' || outcome == 'correct';
    return ExpertReviewState(
      confirmed: approved,
      rejected: outcome == 'reject',
      itemDecisions: [
        for (var i = 0; i < itemIds.length; i++)
          switch (byItem[itemIds[i]]) {
            'approve' => PerCotsAdminDecision.confirmed,
            'reject' => PerCotsAdminDecision.rejected,
            _ => !approved
                ? PerCotsAdminDecision.rejected
                : (itemConfidences[i] * 100).round() >= 80
                    ? PerCotsAdminDecision.confirmed
                    : PerCotsAdminDecision.rejected,
          },
      ],
      reviewerId: latest['expert_id']?.toString() ?? '',
      reviewedAt: DateTime.tryParse(latest['decided_at']?.toString() ?? ''),
    );
  }

  static Stream<List<CaptureModel>> watchCaptures({String? ownerId}) {
    return _poll(() => loadCaptures(ownerId: ownerId));
  }

  static Future<List<CaptureModel>> loadCaptures({String? ownerId}) async {
    var query = _client.from('captures').select(
          '*,monitoring_areas(code,name,municipality,barangay,geographic_reference),detection_items(*),'
          'expert_decisions(decision,item_decisions,decision_sequence,expert_id,decided_at),'
          'zone_review_assigned_to',
        );
    if (ownerId != null) query = query.eq('owner_id', ownerId);
    final rows = await query.order('submitted_at', ascending: false);
    final evidence = await _evidenceForTargets(
      linkTable: 'capture_evidence',
      targetColumn: 'capture_id',
      targetIds:
          (rows as List).map((row) => (row as Map)['id'].toString()).toSet(),
    );
    final names = await _profileNames(
      rows.map((row) => (row as Map)['owner_id'].toString()).toSet(),
    );
    return [
      for (final raw in rows)
        _captureFromRow(
          Map<String, dynamic>.from(raw as Map),
          names,
          evidence,
        ),
    ];
  }

  static Future<CaptureModel?> getCapture(String captureId) async {
    final row = await _client
        .from('captures')
        .select(
          '*,monitoring_areas(code,name,municipality,barangay,geographic_reference),detection_items(*),'
          'expert_decisions(decision,item_decisions,decision_sequence,expert_id,decided_at),'
          'zone_review_assigned_to',
        )
        .eq('id', captureId)
        .maybeSingle();
    if (row == null) return null;
    final names = await _profileNames({row['owner_id'].toString()});
    final evidence = await _evidenceForTargets(
      linkTable: 'capture_evidence',
      targetColumn: 'capture_id',
      targetIds: {captureId},
    );
    return _captureFromRow(Map<String, dynamic>.from(row), names, evidence);
  }

  static Stream<List<RemovalRecordModel>> watchEliminations({
    String? ownerId,
  }) {
    return _poll(() => loadEliminations(ownerId: ownerId));
  }

  static Future<List<RemovalRecordModel>> loadEliminations({
    String? ownerId,
  }) async {
    var query = _client.from('eliminations').select(
          '*,captures(id,owner_id,submitted_at,monitoring_areas(code,name,municipality,barangay),detection_items(confidence))',
        );
    if (ownerId != null) query = query.eq('owner_id', ownerId);
    final rows = await query.order('submitted_at', ascending: false);
    final evidence = await _evidenceForTargets(
      linkTable: 'elimination_evidence',
      targetColumn: 'elimination_id',
      targetIds:
          (rows as List).map((row) => (row as Map)['id'].toString()).toSet(),
    );
    final names = await _profileNames(
      rows.map((row) => (row as Map)['owner_id'].toString()).toSet(),
    );
    return [
      for (final raw in rows)
        _eliminationFromRow(
          Map<String, dynamic>.from(raw as Map),
          names,
          evidence,
        ),
    ];
  }

  static Stream<List<T>> _poll<T>(Future<List<T>> Function() loader) async* {
    yield await loader();
    await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
      yield await loader();
    }
  }

  static Future<Map<String, String>> _profileNames(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    try {
      final rows = await _client
          .from('profiles')
          .select('id,full_name')
          .inFilter('id', ids.toList());
      return {
        for (final row in rows as List)
          (row as Map)['id'].toString(): row['full_name']?.toString() ?? '',
      };
    } on PostgrestException {
      return const {};
    }
  }

  static Future<Map<String, _EvidenceReference>> _evidenceForTargets({
    required String linkTable,
    required String targetColumn,
    required Set<String> targetIds,
  }) async {
    if (targetIds.isEmpty) return const {};
    final rawLinks = await _client
        .from(linkTable)
        .select('$targetColumn,variant_id')
        .inFilter(targetColumn, targetIds.toList());
    final links = (rawLinks as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList()
      ..sort((a, b) {
        final target =
            a[targetColumn].toString().compareTo(b[targetColumn].toString());
        return target != 0
            ? target
            : a['variant_id'].toString().compareTo(b['variant_id'].toString());
      });
    final variantIds = links
        .map((row) => row['variant_id'].toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (variantIds.isEmpty) return const {};
    final rawVariants = await _client
        .from('media_variants')
        .select('id,asset_id,bucket,object_path,kind')
        .inFilter('id', variantIds.toList());
    final variants = {
      for (final raw in rawVariants as List)
        (raw as Map)['id'].toString(): Map<String, dynamic>.from(raw),
    };
    final assetIds = variants.values
        .map((row) => row['asset_id'].toString())
        .where((id) => id.isNotEmpty)
        .toSet();
    final names = <String, String>{};
    if (assetIds.isNotEmpty) {
      final rawAssets = await _client
          .from('media_assets')
          .select('id,original_name')
          .inFilter('id', assetIds.toList());
      for (final raw in rawAssets as List) {
        final row = raw as Map;
        names[row['id'].toString()] = row['original_name']?.toString() ?? '';
      }
    }
    final result = <String, _EvidenceReference>{};
    for (final link in links) {
      final targetId = link[targetColumn].toString();
      if (result.containsKey(targetId)) continue;
      final variant = variants[link['variant_id'].toString()];
      if (variant == null || variant['kind'] == 'thumbnail') continue;
      result[targetId] = _EvidenceReference(
        bucket: variant['bucket']?.toString() ?? '',
        objectPath: variant['object_path']?.toString() ?? '',
        originalName: names[variant['asset_id'].toString()] ?? '',
      );
    }
    return result;
  }

  static CaptureModel _captureFromRow(
    Map<String, dynamic> row,
    Map<String, String> names,
    Map<String, _EvidenceReference> evidence,
  ) {
    final rawItems = (row['detection_items'] as List?) ?? const [];
    final items = rawItems
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList()
      ..sort(
          (a, b) => (a['item_index'] as num).compareTo(b['item_index'] as num));
    final boxes = [
      for (final item in items)
        CotsBoundingBox(
          x1: (item['x1'] as num).toDouble(),
          y1: (item['y1'] as num).toDouble(),
          x2: (item['x2'] as num).toDouble(),
          y2: (item['y2'] as num).toDouble(),
          score: (item['confidence'] as num).toDouble(),
        ),
    ];
    final average = boxes.isEmpty
        ? 0.0
        : boxes.fold<double>(0, (sum, box) => sum + box.score) / boxes.length;
    final area = row['monitoring_areas'] is Map
        ? Map<String, dynamic>.from(row['monitoring_areas'] as Map)
        : const <String, dynamic>{};
    final code = area['code']?.toString() ?? '';
    final photo = evidence[row['id'].toString()];
    final review = reviewStateFor(
      status: row['status']?.toString() ?? 'pending',
      itemIds: [for (final item in items) item['id'].toString()],
      itemConfidences: [for (final box in boxes) box.score],
      decisions: [
        for (final decision in (row['expert_decisions'] as List?) ?? const [])
          Map<String, dynamic>.from(decision as Map),
      ],
    );
    return CaptureModel(
      id: row['id'].toString(),
      uid: row['owner_id'].toString(),
      submittedBy: names[row['owner_id'].toString()] ?? 'Field personnel',
      imageName: photo?.originalName ?? '',
      storageObjectPath:
          photo?.bucket == 'detection-evidence' ? photo!.objectPath : '',
      aiDetectedCount: boxes.length,
      confidence: average,
      captureSource: CaptureSource.goProUnderwaterImage,
      zone: area['name']?.toString() ?? 'Unassigned',
      notes: row['notes']?.toString() ?? '',
      submittedAt: DateTime.tryParse(row['submitted_at']?.toString() ?? ''),
      monitoringAreaId: code,
      municipality: area['municipality']?.toString() ?? '',
      barangay: area['barangay']?.toString() ?? '',
      dateTaken: DateTime.tryParse(row['captured_at']?.toString() ?? ''),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      detectionBoxes: boxes,
      imageWidth: (row['source_width'] as num?)?.round() ?? 0,
      imageHeight: (row['source_height'] as num?)?.round() ?? 0,
      adminConfirmed: review.confirmed,
      adminRejected: review.rejected,
      adminReviewedBy: review.reviewerId.isEmpty
          ? ''
          : names[review.reviewerId] ?? 'Expert',
      adminReviewedAt: review.reviewedAt,
      adminCotsDecisions: review.itemDecisions,
      zoneAssignedTo: row['zone_review_assigned_to']?.toString() ?? '',
    );
  }

  /// Stage 2: the Diver the zone is assigned to when this submission is
  /// another Diver's record waiting for the Expert; null otherwise.
  static Future<String?> zoneReviewAssignedTo(String submissionId) async {
    final row = await _client
        .from('captures')
        .select('zone_review_assigned_to')
        .eq('id', stableUuid('capture', submissionId))
        .maybeSingle();
    final name = row?['zone_review_assigned_to']?.toString() ?? '';
    return name.isEmpty ? null : name;
  }

  static RemovalRecordModel _eliminationFromRow(
    Map<String, dynamic> row,
    Map<String, String> names,
    Map<String, _EvidenceReference> evidence,
  ) {
    final capture = row['captures'] is Map
        ? Map<String, dynamic>.from(row['captures'] as Map)
        : const <String, dynamic>{};
    final area = capture['monitoring_areas'] is Map
        ? Map<String, dynamic>.from(capture['monitoring_areas'] as Map)
        : const <String, dynamic>{};
    final items = (capture['detection_items'] as List?) ?? const [];
    final confidence = items.isEmpty
        ? null
        : items.fold<double>(
              0,
              (sum, item) =>
                  sum + ((item as Map)['confidence'] as num).toDouble(),
            ) /
            items.length;
    final photo = evidence[row['id'].toString()];
    return RemovalRecordModel(
      id: row['id'].toString(),
      captureId: row['capture_id'].toString(),
      uid: row['owner_id'].toString(),
      submittedBy: names[row['owner_id'].toString()] ?? 'Field personnel',
      imageName: photo?.originalName ?? '',
      storageObjectPath:
          photo?.bucket == 'elimination-evidence' ? photo!.objectPath : '',
      removedQuantity: (row['removed_count'] as num?)?.round(),
      removalMethod: row['method']?.toString() ?? '',
      zone: area['name']?.toString() ?? 'Unassigned',
      notes: row['notes']?.toString() ?? '',
      submittedAt: DateTime.tryParse(row['submitted_at']?.toString() ?? ''),
      dateTaken: DateTime.tryParse(row['captured_at']?.toString() ?? ''),
      latitude: (row['latitude'] as num?)?.toDouble(),
      longitude: (row['longitude'] as num?)?.toDouble(),
      aiVerifiedCount: items.length,
      aiConfidence: confidence,
      linkedCaptureDisplayId:
          CaptureModel.formatDisplayRecordId(row['capture_id'].toString()),
      linkedCaptureAiCount: items.length,
    );
  }

  static Future<void> _validateCaptureRetry(
    String captureId,
    String uid,
    String areaId,
  ) async {
    final saved = await _client
        .from('captures')
        .select('owner_id,area_id,model_sha256')
        .eq('id', captureId)
        .maybeSingle();
    if (saved == null ||
        saved['owner_id'] != uid ||
        saved['area_id'] != areaId ||
        saved['model_sha256'] !=
            (CotsYoloDetector.modelName == 'yolo11'
                ? _yolo11Sha
                : _yolo26Sha)) {
      throw StateError(
        'The saved capture differs from this retry. Its original data was preserved.',
      );
    }
  }

  /// Creates the encounter that groups an encounter's photos, once. Each
  /// photo upload calls this; retries and later photos reuse the same row.
  static Future<String> _ensureEncounter(String encounterKey, String uid) async {
    final encounterId = stableUuid('encounter', encounterKey);
    try {
      await _client.from('encounters').insert({
        'id': encounterId,
        'owner_id': uid,
        'idempotency_key': stableUuid('encounter-idempotency', encounterKey),
      });
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
    }
    return encounterId;
  }

  static String stableUuid(String scope, String value) {
    final digest = sha256
        .convert(
          Uint8List.fromList('$scope:$value'.codeUnits),
        )
        .bytes
        .toList();
    digest[6] = (digest[6] & 0x0f) | 0x50;
    digest[8] = (digest[8] & 0x3f) | 0x80;
    final hex =
        digest.take(16).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}

class _EvidenceReference {
  const _EvidenceReference({
    required this.bucket,
    required this.objectPath,
    required this.originalName,
  });

  final String bucket;
  final String objectPath;
  final String originalName;
}

/// The Expert review state of one capture, as shown in the app.
class ExpertReviewState {
  const ExpertReviewState({
    required this.confirmed,
    required this.rejected,
    required this.itemDecisions,
    required this.reviewerId,
    required this.reviewedAt,
  });

  final bool confirmed;
  final bool rejected;
  final List<PerCotsAdminDecision> itemDecisions;
  final String reviewerId;
  final DateTime? reviewedAt;
}
