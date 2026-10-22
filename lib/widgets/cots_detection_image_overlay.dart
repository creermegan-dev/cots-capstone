import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/cots_colors.dart';
import '../models/cots_confidence_policy.dart';
import '../models/record_collection.dart';
import 'submitted_scan_image.dart';

/// Detection image with scaled bounding boxes and COTS labels.
class CotsDetectionImageOverlay extends StatelessWidget {
  const CotsDetectionImageOverlay({
    super.key,
    required this.imageWidth,
    required this.imageHeight,
    required this.items,
    this.imageUrl,
    this.imagePath,
    this.imageBytes,
    this.storageObjectPath,
    this.recordId,
    this.recordCollection = RecordCollection.legacyScanRecords,
    this.decisions,
    this.selectedIndex,
    this.onBoxTap,
    this.interactive = false,
    this.placeholderMessage,
    this.showBoxLabels = true,
    this.boxColorOverride,
  });

  final int imageWidth;
  final int imageHeight;
  final List<CotsDetectionReviewItem> items;
  final String? imageUrl;
  final String? imagePath;
  final Uint8List? imageBytes;
  final String? storageObjectPath;
  final String? recordId;
  final String recordCollection;
  final List<PerCotsAdminDecision>? decisions;
  final int? selectedIndex;
  final ValueChanged<int>? onBoxTap;
  final bool interactive;
  final String? placeholderMessage;
  final bool showBoxLabels;
  final Color? boxColorOverride;

  double get _aspectRatio {
    if (imageWidth > 0 && imageHeight > 0) {
      return imageWidth / imageHeight;
    }
    return 16 / 9;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final h = c.maxHeight;
            final srcW = imageWidth > 0 ? imageWidth.toDouble() : w;
            final srcH = imageHeight > 0 ? imageHeight.toDouble() : h;

            return Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(),
                for (var i = 0; i < items.length; i++)
                  _buildBox(
                    item: items[i],
                    index: i,
                    displayWidth: w,
                    displayHeight: h,
                    sourceWidth: srcW,
                    sourceHeight: srcH,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildImage() {
    return SubmittedScanImage(
      recordId: recordId,
      recordCollection: recordCollection,
      imageUrl: imageUrl,
      imagePath: imagePath,
      imageBytes: imageBytes,
      storageObjectPath: storageObjectPath,
      placeholderMessage: placeholderMessage,
      fit: BoxFit.contain,
    );
  }

  Widget _buildBox({
    required CotsDetectionReviewItem item,
    required int index,
    required double displayWidth,
    required double displayHeight,
    required double sourceWidth,
    required double sourceHeight,
  }) {
    final box = item.box;
    final sx = displayWidth / sourceWidth;
    final sy = displayHeight / sourceHeight;

    final left = box.x1 * sx;
    final top = box.y1 * sy;
    final width = (box.x2 - box.x1) * sx;
    final height = (box.y2 - box.y1) * sy;

    final decision = decisions != null && index < decisions!.length
        ? decisions![index]
        : PerCotsAdminDecision.pending;

    final color =
        boxColorOverride ?? _boxColor(item.confidencePercent, decision);
    final selected = selectedIndex == index;

    return Positioned(
      left: left,
      top: top,
      width: width.clamp(0, displayWidth - left),
      height: height.clamp(0, displayHeight - top),
      child: GestureDetector(
        onTap: interactive && onBoxTap != null ? () => onBoxTap!(index) : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? Colors.white : color,
              width: selected ? 3 : 2.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: showBoxLabels
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: top < 22 ? 0 : -22,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${item.label} — ${item.confidencePercent}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  Color _boxColor(int confidencePercent, PerCotsAdminDecision decision) {
    if (decision == PerCotsAdminDecision.confirmed) return kSuccessGreen;
    if (decision == PerCotsAdminDecision.rejected) return kDangerRed;
    return switch (CotsConfidencePolicy.bandFromPercent(confidencePercent)) {
      CotsVerificationBand.aiAutoApproved => kInfoBlue,
      CotsVerificationBand.adminReview => kWarningOrange,
      CotsVerificationBand.retakeRequired => kDangerRed,
    };
  }
}
