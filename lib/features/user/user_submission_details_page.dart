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
      this.photoPageBuilder,
      this.onPhotoOpen});
  final SubmissionGroup initialGroup;
  final Stream<List<ScanRecordModel>>? recordsStream;
  final bool includePendingPhotos;
  final bool reviewPhotos;
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
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(title: const Text('Submission Details')),
        body: StreamBuilder<List<ScanRecordModel>>(
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
            return ListView(
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
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_group.displayId,
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: kTextNavy)),
                            const SizedBox(height: 8),
                            Text(
                                '${_group.photoCount} photo${_group.photoCount == 1 ? '' : 's'} · ${_group.detectedCount} COTS detected'),
                            Text(_group.statusLabel(pendingSync: pending)),
                            Text('Site: ${_group.records.first.zone}'),
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
                    child: ExpansionTile(
                      key: ValueKey(record.id),
                      title: Text(record.imageName.isEmpty
                          ? record.displayRecordId
                          : record.imageName),
                      subtitle: Text(
                          '${record.displayRecordId} · ${pendingIds.contains(record.id) ? 'Pending synchronization' : record.sourceCapture?.serverStatus == 'pending' ? 'Processing evidence' : record.userStatusLabel}'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
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
                            onPressed:
                                record.sourceCapture?.serverStatus == 'pending'
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
            );
          },
        ),
      );
}
