import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_type.dart';
import '../../models/cots_confidence_policy.dart';
import '../../models/follow_up_monitoring_model.dart';
import '../../models/scan_record_model.dart';
import '../../models/capture_model.dart';
import '../../services/capture_repository.dart';
import '../../widgets/cots_detection_image_overlay.dart';
import 'cots_map_page.dart';
import '../../widgets/cots_loading_skeleton.dart';

/// Full detail view for a single GoPro submission (user-facing).
class UserRecordDetailsPage extends StatelessWidget {
  const UserRecordDetailsPage(
      {super.key,
      required this.record,
      this.watchSurvey = true,
      this.linkedCaptures = const []});

  final ScanRecordModel record;
  final bool watchSurvey;
  final List<CaptureModel> linkedCaptures;

  static final _dateFmt = DateFormat('MMM d, yyyy h:mm a');

  String get _dateCaptured =>
      record.dateTaken != null ? _dateFmt.format(record.dateTaken!) : 'Unknown';

  String get _dateUploaded => record.submittedAt != null
      ? _dateFmt.format(record.submittedAt!)
      : _dateCaptured;

  String get _userRemarks => record.notes.trim().isEmpty
      ? 'No remarks submitted.'
      : record.notes.trim();

  Color _statusColor(String status) {
    switch (status) {
      case 'Accepted':
      case 'Automatically Accepted':
      case 'Verified':
        return kLow;
      case 'Under Review':
      case 'Requires Expert Validation':
      case 'Pending Verification':
        return kModerate;
      case 'Retake Photo':
      case 'Rejected':
        return kHigh;
      default:
        return kNavy;
    }
  }

  String get _statusDescription => record.userStatusDescription;

  List<CotsDetectionReviewItem> get _detectionItems =>
      CotsConfidencePolicy.buildDetectionItems(
        count: record.aiDetectedCount,
        averagePercent: record.confidencePercent,
        boxes: record.detectionBoxes.isNotEmpty ? record.detectionBoxes : null,
        imageWidth: record.imageWidth > 0 ? record.imageWidth : 1920,
        imageHeight: record.imageHeight > 0 ? record.imageHeight : 1080,
      );

  @override
  Widget build(BuildContext context) {
    final survey = record.followUpSurvey;
    if (watchSurvey && survey != null) {
      return StreamBuilder<List<CaptureModel>>(
        stream: CaptureRepository.watchForUser(survey.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
                appBar: AppBar(title: const Text('Survey details')),
                body: const Center(
                    child: Text('Could not load linked validation results.')));
          }
          if (!snapshot.hasData) {
            return const Scaffold(
                body: CotsPageLoading(layout: CotsSkeletonLayout.detail));
          }
          return UserRecordDetailsPage(
            record: ScanRecordModel.fromFollowUpSurvey(survey,
                status: followUpSurveyStatus(survey, snapshot.data!)),
            watchSurvey: false,
            linkedCaptures: snapshot.data!
                .where((capture) => survey.captureIds.contains(capture.id))
                .toList(),
          );
        },
      );
    }
    final status = record.userStatusLabel;
    final statusColor = _statusColor(status);
    final confidencePct = (record.confidence.clamp(0.0, 1.0) * 100).round();

    return Scaffold(
      backgroundColor: kGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: kNavy,
        leading: AppBackIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconColor: kNavy,
        ),
        title: Column(
          children: [
            const Text(
              'Record Details',
              style: TextStyle(
                color: kNavy,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            Text(
              record.displayRecordId,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 900;
          final leftCol = [
            if (record.shouldRetakePhoto) ...[
              _retakePhotoBanner(),
              const SizedBox(height: 14),
            ],
            _summaryHeader(status, statusColor),
            const SizedBox(height: 14),
            if (record.followUpSurvey case final survey?) ...[
              _followUpSurveyCard(survey),
            ] else ...[
              _detectionResultsCard(record.aiDetectedCount, confidencePct),
              const SizedBox(height: 14),
              _confidencePolicyCard(),
            ],
            const SizedBox(height: 14),
            _informationCard(),
            const SizedBox(height: 14),
          ];
          final rightCol = [
            if (record.followUpSurvey case final survey?)
              _followUpCaptureReferences(context, survey)
            else
              _imageCard(),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...leftCol,
                      const SizedBox(height: 14),
                      ...rightCol
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 52, child: Column(children: leftCol)),
                      const SizedBox(width: 16),
                      Expanded(flex: 48, child: Column(children: rightCol)),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _followUpSurveyCard(FollowUpSurveyModel survey) {
    return _titledCard(
      icon: Icons.event_repeat_outlined,
      title: 'Follow-up Monitoring Results',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _metricBox(
            'Field-observed COTS',
            '${survey.fieldObservedCount} individuals',
            const Color(0xFF1565C0),
          ),
          const SizedBox(height: 10),
          Text(record.userStatusLabel,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _metricBox(
            'Field-reported eliminated',
            '${survey.fieldEliminatedCount} individuals',
            kGreen,
          ),
          const SizedBox(height: 12),
          for (final capture in linkedCaptures)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                  '${capture.displayRecordId}: Expert-confirmed image detections: '
                  '${capture.adminCotsDecisions.isNotEmpty ? capture.adminCotsDecisions.where((decision) => decision == PerCotsAdminDecision.confirmed).length : capture.adminConfirmed ? capture.aiDetectedCount : 'Not yet validated'}. '
                  'These are image detections, not a unique survey count.'),
            ),
          Text(
            'AI image detections: ${survey.aiDetectedCount} across '
            '${survey.captureIds.length} image record(s). Counts across '
            'images are not treated as unique individuals.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _kv(
            'Monitoring area',
            '${survey.areaName} · ${survey.barangay}, ${survey.municipality}',
          ),
          _kv(
            'Actual monitoring date',
            _dateFmt.format(survey.surveyDate),
          ),
          _kv(
            'GPS reference',
            survey.latitude == null || survey.longitude == null
                ? 'Not provided'
                : '${survey.latitude!.toStringAsFixed(6)}, '
                    '${survey.longitude!.toStringAsFixed(6)}',
          ),
          _kv(
            'Surveyed reef area',
            survey.surveyedAreaSquareMeters == null
                ? 'Not provided; infestation density not calculated'
                : '${survey.surveyedAreaSquareMeters!.toStringAsFixed(2)} m²',
          ),
          if (survey.fieldEliminatedCount > 0)
            _kv('Elimination method', survey.eliminationMethod),
          if (survey.notes.trim().isNotEmpty)
            _kv('Field notes', survey.notes.trim()),
        ],
      ),
    );
  }

  Widget _followUpCaptureReferences(
      BuildContext context, FollowUpSurveyModel survey) {
    return _titledCard(
      icon: Icons.photo_library_outlined,
      title: 'GoPro Image Records',
      child: survey.captureIds.isEmpty
          ? const Text('No linked image records.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${survey.captureIds.length} saved image record(s). '
                  'Each image remains available as its own record.',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final id in survey.captureIds)
                      ActionChip(
                        onPressed: () async {
                          try {
                            final capture = await CaptureRepository.getById(id);
                            if (!context.mounted) return;
                            if (capture == null) {
                              throw StateError('Image record unavailable.');
                            }
                            await Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                    builder: (_) => UserRecordDetailsPage(
                                        record: ScanRecordModel.fromCapture(
                                            capture))));
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Could not open image record. Please retry.')));
                            }
                          }
                        },
                        label: Text(
                          id.length > 14 ? '${id.substring(0, 14)}…' : id,
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _summaryHeader(String status, Color statusColor) {
    return _card(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kGreen,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.displayRecordId,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: kNavy,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Submitted by ${record.submittedBy}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  CotsActivityType.label(record.activityType),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                if (record.linkedCaptureDisplayId != null &&
                    record.linkedCaptureDisplayId!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Detection Record ID / Linked Detection: ${record.linkedCaptureDisplayId}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detectionResultsCard(int count, int confidencePct) {
    return _titledCard(
      icon: Icons.center_focus_strong_outlined,
      title: 'Detection Results',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _metricBox(
                  'AI Detected (Count)',
                  '$count individuals',
                  const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metricBox(
                  'Confidence Level',
                  '$confidencePct% avg',
                  kGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Each COTS is evaluated individually: '
            '${CotsConfidencePolicy.autoApproveMin}–100% = AI auto-approved · '
            'any COTS ${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1}% = expert review · '
            '0–${CotsConfidencePolicy.adminReviewMin - 1} = retake photo.',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade700,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _retakePhotoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kHigh.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kHigh.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.photo_camera_outlined, color: kHigh, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please retake your photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: kNavy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.userStatusDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidencePolicyCard() {
    return _titledCard(
      icon: Icons.policy_outlined,
      title: 'How verification works',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _policyLine(
              kLow,
              'Automatically Accepted (${CotsConfidencePolicy.autoApproveMin}–100%)',
              'Each COTS at ${CotsConfidencePolicy.autoApproveMin}%+ is accepted automatically.'),
          const SizedBox(height: 8),
          _policyLine(
              kModerate,
              'Requires Expert Validation (${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1})',
              'Any individual COTS below ${CotsConfidencePolicy.autoApproveMin}% needs expert verification — even if others in the same photo are higher.'),
          const SizedBox(height: 8),
          _policyLine(
              kHigh,
              'Retake Photo (0–${CotsConfidencePolicy.adminReviewMin - 1})',
              'Too low confidence — upload a clearer GoPro shot.'),
        ],
      ),
    );
  }

  Widget _policyLine(Color color, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12, color: kNavy)),
              Text(body,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade700,
                      height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _informationCard() {
    return _titledCard(
      icon: Icons.info_outline_rounded,
      title: 'Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Coordinates', record.formattedCoordinates),
          _kv('Location source', 'Live Device GPS'),
          _kv('GPS source', 'Live Device GPS'),
          _kv('Capture device', 'Unknown Device'),
          _kv('Upload method', 'Gallery Upload'),
          _kv('Date captured', _dateCaptured),
          _kv('Date uploaded', _dateUploaded),
          _kv('User remarks', _userRemarks),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Auto Zone Assignment',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kLow.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record.zone,
                  style: const TextStyle(
                    color: kLow,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imageCard() {
    final imgW = record.imageWidth > 0 ? record.imageWidth : 1920;
    final imgH = record.imageHeight > 0 ? record.imageHeight : 1080;
    final status = record.userStatusLabel;
    final statusColor = _statusColor(status);

    return _titledCard(
      icon: Icons.image_outlined,
      title: 'Detection Image',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CotsDetectionImageOverlay(
            imageWidth: imgW,
            imageHeight: imgH,
            items: _detectionItems,
            recordId: record.id,
            imageUrl: record.imageUrl.isNotEmpty
                ? record.imageUrl
                : record.submittedImageUrl,
            imagePath: record.imagePath,
            storageObjectPath: record.storageObjectPath,
            placeholderMessage: 'Submitted photo unavailable for this record.',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: const [
              _LegendDot(
                  color: Color(0xFF1565C0),
                  label:
                      'AI auto-approved (${CotsConfidencePolicy.autoApproveMin}%+)'),
              _LegendDot(
                  color: kModerate,
                  label:
                      'Needs review (${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1}%)'),
              _LegendDot(color: kHigh, label: 'Low confidence / retake'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Each labeled box shows a detected COTS (e.g. COTS 1 — 43%). '
            '${record.aiDetectedCount} total detections in this image.',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 14),
          _statusSection(status, statusColor),
        ],
      ),
    );
  }

  Widget _statusSection(String status, Color statusColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 8),
            const Text(
              'Status Information',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: kNavy,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: statusColor, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: kNavy,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _statusDescription,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _metricBox(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kNavy,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _titledCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: kGreen),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
