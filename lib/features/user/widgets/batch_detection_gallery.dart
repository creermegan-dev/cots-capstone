import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';
import '../../../models/cots_confidence_policy.dart';
import '../../../models/cots_detection_result.dart';
import '../../../widgets/cots_detection_image_overlay.dart';

class DetectionPhotoPreview {
  const DetectionPhotoPreview({
    required this.id,
    required this.name,
    required this.bytes,
    required this.width,
    required this.height,
    this.detection,
    this.error,
  });

  final String id;
  final String name;
  final Uint8List bytes;
  final int width;
  final int height;
  final CotsDetectionResult? detection;
  final String? error;
}

class BatchDetectionSummary extends StatelessWidget {
  const BatchDetectionSummary(
      {super.key, required this.photos, this.showPhotoHint = false});

  final List<DetectionPhotoPreview> photos;
  final bool showPhotoHint;

  @override
  Widget build(BuildContext context) {
    final total = photos.fold<int>(
        0, (sum, p) => sum + (p.error == null ? p.detection?.count ?? 0 : 0));
    // Weight photo means by detection count so every COTS contributes equally.
    final confidenceSum = photos.fold<double>(0, (sum, photo) {
      final detection = photo.detection;
      if (photo.error != null || detection == null || detection.count <= 0) {
        return sum;
      }
      return sum + detection.confidence * detection.count;
    });
    final confidenceLabel = total > 0
        ? '${CotsConfidencePolicy.percentFromConfidence(confidenceSum / total)}%'
        : '—';
    final failed = photos.where((p) => p.error != null).length;
    return _detectionCard(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Total COTS detected',
            style: TextStyle(color: kTextNavy, fontWeight: FontWeight.w700)),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('$total',
                key: const ValueKey('batch-detection-total'),
                style: const TextStyle(
                    color: kPrimaryTeal,
                    fontSize: 32,
                    fontWeight: FontWeight.w900)),
            Text('Overall confidence: $confidenceLabel',
                key: const ValueKey('batch-detection-confidence'),
                style: const TextStyle(
                    color: kPrimaryTeal, fontWeight: FontWeight.w700)),
          ],
        ),
        Text('Across ${photos.length} uploaded photos',
            style: const TextStyle(color: kMutedGray)),
        if (showPhotoHint) ...[
          const SizedBox(height: 6),
          const Text('Tap a photo to inspect its detection results.',
              style: TextStyle(color: kMutedGray)),
        ],
        if (failed > 0) ...[
          const SizedBox(height: 8),
          Text(
              '$failed photo(s) could not be analyzed and are excluded from the total.',
              style: const TextStyle(color: kDangerRed)),
        ],
      ],
    ));
  }
}

/// Batch overview starts unselected. Its confidence is an average across all
/// detected COTS; verification decisions continue to use each COTS's score.
class BatchDetectionGallery extends StatefulWidget {
  const BatchDetectionGallery({super.key, required this.photos});

  final List<DetectionPhotoPreview> photos;

  @override
  State<BatchDetectionGallery> createState() => _BatchDetectionGalleryState();
}

class _BatchDetectionGalleryState extends State<BatchDetectionGallery> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final selected =
        widget.photos.where((p) => p.id == _selectedId).firstOrNull;
    if (selected != null) return _photoDetails(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BatchDetectionSummary(photos: widget.photos, showPhotoHint: true),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final columns = (constraints.maxWidth / 120).floor().clamp(2, 6);
          final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(spacing: 10, runSpacing: 12, children: [
            for (var i = 0; i < widget.photos.length; i++)
              SizedBox(width: width, child: _thumbnail(widget.photos[i], i)),
          ]);
        }),
      ],
    );
  }

  Widget _thumbnail(DetectionPhotoPreview photo, int index) => Semantics(
        button: true,
        label: 'Open photo ${index + 1}: ${photo.name}',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('detection-thumbnail-${photo.id}'),
            onTap: () => setState(() => _selectedId = photo.id),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                      aspectRatio: 1,
                      child: Image.memory(photo.bytes, fit: BoxFit.cover)),
                  Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Photo ${index + 1}',
                              style: const TextStyle(
                                  color: kTextNavy,
                                  fontWeight: FontWeight.w700)),
                          Text(photo.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: kMutedGray, fontSize: 12)),
                          if (photo.error != null)
                            const Text('Analysis failed',
                                style: TextStyle(color: kDangerRed)),
                        ],
                      )),
                ]),
          ),
        ),
      );

  Widget _photoDetails(DetectionPhotoPreview photo) {
    final detection = photo.detection;
    final valid = photo.error == null && detection != null;
    final items = valid
        ? CotsConfidencePolicy.buildDetectionItems(
            count: detection.count,
            averagePercent: CotsConfidencePolicy.percentFromConfidence(
                detection.confidence),
            boxes: detection.boxes,
            imageWidth: photo.width,
            imageHeight: photo.height,
          )
        : const <CotsDetectionReviewItem>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            key: const ValueKey('batch-photo-back'),
            tooltip: 'Back to all photos',
            icon: const Icon(Icons.chevron_left_rounded,
                color: kTextNavy, size: 24),
            onPressed: () => setState(() => _selectedId = null),
          )),
      Text(photo.name,
          style: const TextStyle(
              color: kTextNavy, fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      CotsDetectionImageOverlay(
          imageWidth: photo.width,
          imageHeight: photo.height,
          imageBytes: photo.bytes,
          items: items),
      const SizedBox(height: 14),
      _detectionCard(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!valid)
          Text(photo.error ?? 'Analysis is not available for this photo.',
              style: const TextStyle(color: kDangerRed))
        else ...[
          Text('${detection.count} COTS detected in this photo',
              key: const ValueKey('selected-photo-count'),
              style: const TextStyle(
                  color: kTextNavy, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              'Overall confidence: ${detection.count > 0 ? '${CotsConfidencePolicy.percentFromConfidence(detection.confidence)}%' : '—'}',
              key: const ValueKey('selected-photo-confidence'),
              style: const TextStyle(
                  color: kPrimaryTeal, fontWeight: FontWeight.w700)),
          if (detection.count == 0)
            const Text(
                'No COTS were detected. This does not establish area clearance.')
        ],
      ])),
    ]);
  }
}

Widget _detectionCard(Widget child) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorderGray),
          boxShadow: kSoftCardShadow),
      child: child,
    );
