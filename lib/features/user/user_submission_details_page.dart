import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../models/photo_source.dart';
import '../../models/scan_record_model.dart';
import '../../models/submission_group.dart';
import '../../services/offline_submission_service.dart';
import '../../services/scan_record_repository.dart';
import '../../widgets/cots_detection_image_overlay.dart';
import 'user_record_details_page.dart';

/// One batch/site submission, with original per-photo evidence left intact.
class UserSubmissionDetailsPage extends StatefulWidget {
  const UserSubmissionDetailsPage(
      {super.key,
      required this.initialGroup,
      this.recordsStream,
      this.includePendingPhotos = true,
      this.reviewPhotos = false,
      this.useReadOnlyLayout = false,
      this.reviewPanelBuilder,
      this.photoPageBuilder,
      this.onPhotoOpen});
  final SubmissionGroup initialGroup;
  final Stream<List<ScanRecordModel>>? recordsStream;
  final bool includePendingPhotos;
  final bool reviewPhotos;

  /// Reuses the photo selector and detail cards for staff view-only routes.
  /// Expert review routes retain their original actions and photo builder.
  final bool useReadOnlyLayout;
  final Widget Function(ScanRecordModel record, VoidCallback refresh)?
      reviewPanelBuilder;
  final Widget Function(ScanRecordModel)? photoPageBuilder;
  final ValueChanged<ScanRecordModel>? onPhotoOpen;

  @override
  State<UserSubmissionDetailsPage> createState() =>
      _UserSubmissionDetailsPageState();
}

class _UserSubmissionDetailsPageState extends State<UserSubmissionDetailsPage> {
  late Stream<List<ScanRecordModel>> _stream;
  late SubmissionGroup _group;
  Timer? _retryTimer;
  String? _selectedPhotoId;
  final Set<String> _openedReviewPhotos = {};

  void _markReviewPhotoOpened(ScanRecordModel photo) {
    if (widget.reviewPanelBuilder == null ||
        !_openedReviewPhotos.add(photo.id)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPhotoOpen?.call(photo);
    });
  }

  @override
  void initState() {
    super.initState();
    _group = widget.initialGroup;
    _connect();
  }

  void _connect() {
    _retryTimer?.cancel();
    _retryTimer = null;
    try {
      _stream = widget.recordsStream ??
          ScanRecordRepository.watchForUser(_group.ownerId);
    } catch (error) {
      _stream = Stream.error(error);
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  String _time(DateTime? time) => time == null
      ? 'Unknown'
      : DateFormat('MMM d, yyyy h:mm a').format(time.toLocal());

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ScanRecordModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError && widget.recordsStream == null) {
            _retryTimer ??= Timer(const Duration(seconds: 15), () {
              if (mounted) setState(_connect);
            });
          } else if (snapshot.hasData) {
            _retryTimer?.cancel();
            _retryTimer = null;
          }
          final local = widget.includePendingPhotos
              ? context
                  .watch<OfflineSubmissionService>()
                  .pendingSubmissions
                  .map((task) => task.record)
                  .whereType<ScanRecordModel>()
                  .where((record) => record.uid == _group.ownerId)
                  .toList()
              : <ScanRecordModel>[];
          final pendingIds = local.map((record) => record.id).toSet();
          final groups = SubmissionGroup.fromRecords([
            ...?snapshot.data,
            ...local,
            ..._group.records,
          ]);
          for (final group in groups) {
            if (group.key == widget.initialGroup.key) {
              _group = group;
              break;
            }
          }
          final pending =
              _group.records.any((record) => pendingIds.contains(record.id));
          final tally = _group.cotsTally;
          if (widget.reviewPanelBuilder != null ||
              ((widget.photoPageBuilder == null || widget.useReadOnlyLayout) &&
                  !widget.reviewPhotos)) {
            final photos = _group.records;
            final selected = photos.firstWhere(
                (photo) => photo.id == _selectedPhotoId,
                orElse: () => photos.first);
            _markReviewPhotoOpened(selected);
            return UserRecordDetailsPage(
              record: selected,
              displayId: _group.displayId,
              statusLabel: _group.statusLabel(pendingSync: pending),
              statusDescription:
                  'Confirmed: ${tally.confirmed} · Waiting: ${tally.waiting} · Not accepted: ${tally.notAccepted}',
              pendingSync: pendingIds.contains(selected.id),
              reviewPanel: widget.reviewPanelBuilder?.call(selected, () {
                if (mounted) setState(_connect);
              }),
              photoSelector: photos.length > 1 ||
                      snapshot.hasError ||
                      _group.hasCrossSiteEncounter
                  ? Card(
                      color: Colors.white,
                      elevation: 0,
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (photos.length > 1) ...[
                                  Text(
                                      '${_group.photoCount} photos · ${_group.detectedCount} COTS detected',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    initialValue: selected.id,
                                    key: ValueKey(
                                        'submission-photo-${selected.id}'),
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Photo',
                                        border: OutlineInputBorder(),
                                        isDense: true),
                                    items: [
                                      for (var i = 0; i < photos.length; i++)
                                        DropdownMenuItem(
                                            value: photos[i].id,
                                            child: Text(
                                                'Photo ${i + 1} · ${photos[i].imageName.isEmpty ? photos[i].displayRecordId : photos[i].imageName}',
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis))
                                    ],
                                    onChanged: (id) {
                                      setState(() => _selectedPhotoId = id);
                                      _markReviewPhotoOpened(photos.firstWhere(
                                          (photo) => photo.id == id));
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                      'Photo status: ${pendingIds.contains(selected.id) ? 'Pending synchronization' : selected.userStatusLabel}',
                                      style: const TextStyle(fontSize: 12)),
                                ],
                                if (_group.hasCrossSiteEncounter)
                                  const Text(
                                      'This batch spans multiple sites. Its existing removal total is not a per-site total.'),
                                if (snapshot.hasError) ...[
                                  const Text(
                                      'Showing saved submission details. Reconnect to refresh.'),
                                  TextButton(
                                      onPressed: () => setState(_connect),
                                      child: const Text('Retry')),
                                ],
                              ])))
                  : null,
            );
          }
          return Scaffold(
              backgroundColor: const Color(0xFFF4F6F9),
              appBar: AppBar(title: const Text('Submission Details')),
              body: DefaultTextStyle.merge(
                  style: const TextStyle(
                      fontSize: 13, color: kTextNavy, height: 1.4),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (snapshot.hasError)
                        Card(
                            child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                    'Showing saved submission details. Reconnect to refresh.'),
                                TextButton(
                                    onPressed: () => setState(_connect),
                                    child: const Text('Retry')),
                              ]),
                        )),
                      Card(
                          color: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_group.displayId,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: kTextNavy)),
                                  const SizedBox(height: 8),
                                  Text(
                                      '${_group.photoCount} photo${_group.photoCount == 1 ? '' : 's'} · ${_group.detectedCount} COTS detected'),
                                  const SizedBox(height: 8),
                                  Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                          color: kPrimaryTeal.withValues(
                                              alpha: .08),
                                          borderRadius:
                                              BorderRadius.circular(9)),
                                      child: Text(
                                          _group.statusLabel(
                                              pendingSync: pending),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700))),
                                  const SizedBox(height: 8),
                                  Text('Site: ${_group.records.first.zone}',
                                      style: const TextStyle(
                                          fontSize: 13, color: kTextNavy)),
                                  Text(
                                      'Confirmed: ${tally.confirmed} · Waiting: ${tally.waiting} · Not accepted: ${tally.notAccepted}'),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Each photo keeps its own GPS, capture time, confidence and review decisions.'),
                                  if (_group.hasCrossSiteEncounter)
                                    const Text(
                                        'This batch spans multiple sites. Its existing removal total is not a per-site total.'),
                                ],
                              ))),
                      for (final record in _group.records)
                        Card(
                          color: Colors.white,
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          child: ExpansionTile(
                            key: ValueKey(record.id),
                            leading: const Icon(Icons.image_outlined,
                                color: kPrimaryTeal),
                            title: Text(
                                record.imageName.isEmpty
                                    ? record.displayRecordId
                                    : record.imageName,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                '${record.displayRecordId} · ${pendingIds.contains(record.id) ? 'Pending synchronization' : record.sourceCapture?.serverStatus == 'pending' ? 'Processing evidence' : record.userStatusLabel}',
                                style: const TextStyle(fontSize: 12)),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                  '${record.aiDetectedCount} COTS · ${record.confidencePercent}% confidence'),
                              Text(
                                  'Coordinates: ${record.latitude == null || record.longitude == null ? 'Not available' : record.formattedCoordinates}'),
                              Text(
                                  'Location from: ${PhotoSource.locationLabel(record.locationSource)}'),
                              Text(
                                  'Date taken: ${PhotoSource.dateTaken(_time(record.dateTaken), record.timeSource)}'),
                              Text(
                                  '${pendingIds.contains(record.id) ? 'Saved on device' : 'Uploaded'}: ${_time(record.submittedAt)}'),
                              const SizedBox(height: 12),
                              CotsDetectionImageOverlay(
                                recordId: record.id,
                                recordCollection: record.recordCollection,
                                imageWidth: record.imageWidth,
                                imageHeight: record.imageHeight,
                                imagePath: record.imagePath,
                                imageUrl: record.imageUrl,
                                storageObjectPath: record.storageObjectPath,
                                items: record.detectionReviewItems,
                                decisions: record.adminCotsDecisions,
                              ),
                              if (!pendingIds.contains(record.id))
                                TextButton(
                                  onPressed: record
                                              .sourceCapture?.serverStatus ==
                                          'pending'
                                      ? null
                                      : () async {
                                          widget.onPhotoOpen?.call(record);
                                          await Navigator.of(context)
                                              .push<Object?>(MaterialPageRoute(
                                                  builder: (_) =>
                                                      widget.photoPageBuilder
                                                          ?.call(record) ??
                                                      UserRecordDetailsPage(
                                                          record: record)));
                                          if (mounted) setState(_connect);
                                        },
                                  child: Text(widget.reviewPhotos
                                      ? 'Review photo'
                                      : 'View photo details'),
                                ),
                            ],
                          ),
                        ),
                    ],
                  )));
        },
      );
}
