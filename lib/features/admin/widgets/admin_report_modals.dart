import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/admin_report_modal_data.dart';
import '../theme/admin_theme.dart';
import 'admin_record_details_dialogs.dart';

enum ReportReviewOutcome { approved, rejected, cancelled }

Widget _modalKv(String k, String v, {Color? valueColor, bool boldValue = false, Color? badge}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(k, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.85))),
        ),
        Expanded(
          child: badge != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badge.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: Text(v, style: TextStyle(fontWeight: FontWeight.w800, color: badge, fontSize: 12)),
                )
              : Text(
                  v,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: boldValue ? FontWeight.w900 : FontWeight.w600,
                    color: valueColor ?? AdminColors.headerTitle,
                  ),
                ),
        ),
      ],
    ),
  );
}

Future<ReportReviewOutcome?> showReviewDetectionReportDialog(BuildContext context, AdminReportModalData d) {
  return showAdminBlurredDialogForResult<ReportReviewOutcome>(
    context: context,
    maxWidthFraction: 0.78,
    child: Material(
      color: Colors.transparent,
      child: _ReviewReportModalBody(data: d),
    ),
  );
}

/// Full report details body (carousel, metrics, detection tables). Used on [AdminReportDetailsScreen].
class AdminReportDetailsContent extends StatefulWidget {
  const AdminReportDetailsContent({super.key, required this.data});

  final AdminReportModalData data;

  @override
  State<AdminReportDetailsContent> createState() => _AdminReportDetailsContentState();
}

class _AdminReportDetailsContentState extends State<AdminReportDetailsContent> {
  late final PageController _pageCtrl;
  int _img = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 900;
              final top = [
                _imageCarousel(d),
                _overviewColumn(d),
                _confidenceColumn(d),
              ];
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...top.expand((w) => [w, const SizedBox(height: 16)])]..removeLast(),
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 34, child: top[0]),
                    const SizedBox(width: 16),
                    Expanded(flex: 32, child: top[1]),
                    const SizedBox(width: 16),
                    Expanded(flex: 30, child: top[2]),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          _detectionSummaryRow(d),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 800;
              final left = _detectionTableCard(d);
              final right = _additionalInfoCard(d);
              if (narrow) {
                return Column(children: [left, const SizedBox(height: 14), right]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 14),
                  Expanded(child: right),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _capturedSection(d, setCarouselIndex: (i) {
            setState(() => _img = i);
            _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _imageCarousel(AdminReportModalData d) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          MouseRegion(
            onEnter: (_) => setState(() {}),
            child: SizedBox(
              height: 240,
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _img = i),
                itemCount: d.imageUrls.length,
                itemBuilder: (context, i) {
                  return AnimatedScale(
                    scale: 1,
                    duration: const Duration(milliseconds: 200),
                    child: Image.network(
                      d.imageUrls[i],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE8EEF5),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined, size: 48),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _roundNav(Icons.chevron_left_rounded, _img > 0, () {
                if (_img > 0) {
                  _pageCtrl.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
                }
              }),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _roundNav(Icons.chevron_right_rounded, _img < d.imageUrls.length - 1, () {
                if (_img < d.imageUrls.length - 1) {
                  _pageCtrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
                }
              }),
            ),
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_img + 1} / ${d.imageUrls.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundNav(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: enabled ? AdminColors.headerTitle : AdminColors.muted),
        ),
      ),
    );
  }

  Widget _overviewColumn(AdminReportModalData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modalKv('Report ID', d.id),
        _modalKv('Type', d.typeLabel, valueColor: d.typeColor, boldValue: true),
        _modalKv('Submitted By', d.submittedBy),
        _modalKv('Zone', d.zoneLong, valueColor: AdminColors.statRed),
        _modalKv('Submitted On', d.submittedOn),
      ],
    );
  }

  Widget _confidenceColumn(AdminReportModalData d) {
    final ac = d.confidenceAccentColor;
    final p = d.confidencePct / 100.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: p,
                    strokeWidth: 7,
                    backgroundColor: ac.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(ac),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${d.confidencePct}%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: ac)),
                    Text(d.confidenceBand, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: ac)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Confidence Level: ${d.confidencePct}% (${d.confidenceBand})',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ac)),
                const SizedBox(height: 4),
                Text('Status: ${d.statusLabel}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ac)),
                const SizedBox(height: 6),
                Text(d.confidenceDescription, style: TextStyle(fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.9), height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detectionSummaryRow(AdminReportModalData d) {
    final items = [
      _MiniMetric(Icons.blur_on_rounded, AdminColors.statBlue, 'COTS Count', '${d.cotsCount}', 'Crown of Thorns Starfish'),
      _MiniMetric(Icons.psychology_outlined, AdminColors.statPurple, 'Detection Method', d.detectionMethod, 'System automated detection'),
      _MiniMetric(Icons.location_on_outlined, AdminColors.statGreen, 'Location', d.gpsCoordinates, 'View on map', link: true),
      _MiniMetric(Icons.schedule_rounded, AdminColors.statYellow, 'Date & Time Detected', d.detectedDate, d.detectedTime),
      _MiniMetric(Icons.person_outline_rounded, AdminColors.statBlue, 'Recorded By', d.submittedBy, d.recordedRole),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            SizedBox(width: 168, child: items[i]),
          ],
        ],
      ),
    );
  }

  Widget _detectionTableCard(AdminReportModalData d) {
    final total = d.totalCotsTable;
    return _subCard(
      title: 'Detection Results',
      child: Column(
        children: [
          _tableRow('COTS Detected', total, 100, showBar: true),
          _tableRow('Other Marine Life', d.otherMarine, total == 0 ? 0 : (d.otherMarine / total * 100).clamp(0, 100)),
          _tableRow('False Positives', d.falsePositives, total == 0 ? 0 : (d.falsePositives / total * 100).clamp(0, 100)),
          const Divider(height: 20),
          _tableRow('Total', total, 100, isTotal: true, showBar: true),
        ],
      ),
    );
  }

  Widget _tableRow(String cat, int count, double pct, {bool isTotal = false, bool showBar = false}) {
    final countStyle = TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: isTotal ? 16 : 15,
      height: 1.05,
      color: AdminColors.statRed,
    );
    final pctStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      height: 1.05,
      color: AdminColors.muted.withValues(alpha: 0.92),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              cat,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700,
                fontSize: 12,
                height: 1.25,
                color: AdminColors.statRed.withValues(alpha: 0.88),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            height: 24,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '$count',
                maxLines: 1,
                textAlign: TextAlign.right,
                style: countStyle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 48,
            height: 22,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${pct.toStringAsFixed(0)}%',
                maxLines: 1,
                textAlign: TextAlign.right,
                style: pctStyle,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: showBar
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct / 100,
                      minHeight: 8,
                      backgroundColor: AdminColors.statBlue.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AdminColors.statBlue),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _additionalInfoCard(AdminReportModalData d) {
    return _subCard(
      title: 'Additional Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _modalKv('Water Visibility', d.waterVisibility, badge: AdminColors.statGreen),
          _modalKv('Weather Condition', d.weather),
          _modalKv('Depth', d.depthRange),
          const SizedBox(height: 6),
          Text('Notes from Submitter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.muted.withValues(alpha: 0.8))),
          const SizedBox(height: 6),
          Text(d.notes, style: TextStyle(fontSize: 13, height: 1.45, color: AdminColors.headerTitle.withValues(alpha: 0.9))),
        ],
      ),
    );
  }

  Widget _capturedSection(AdminReportModalData d, {required void Function(int) setCarouselIndex}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Captured Images', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.headerTitle)),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: const Text('View All Images', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < d.imageUrls.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _Thumb(url: d.imageUrls[i], index: i + 1, onTap: () => setCarouselIndex(i)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _subCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AdminColors.headerTitle)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

}

class _ReviewReportModalBody extends StatefulWidget {
  const _ReviewReportModalBody({required this.data});
  final AdminReportModalData data;

  @override
  State<_ReviewReportModalBody> createState() => _ReviewReportModalBodyState();
}

class _ReviewReportModalBodyState extends State<_ReviewReportModalBody> {
  late final PageController _pageCtrl;
  int _img = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final ac = d.confidenceAccentColor;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: GestureDetector(
        onTap: () {},
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 36, offset: const Offset(0, 18)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _modalHeader(
                context,
                title: 'Review Detection Report',
                subtitle: 'Please review the detection report details and take an action.',
              ),
              Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        final narrow = c.maxWidth < 900;
                        final img = _reviewImageBlock(d);
                        final mid = _reviewMidColumn(d);
                        final right = _reviewConfidence(d, ac);
                        if (narrow) {
                          return Column(children: [img, const SizedBox(height: 14), mid, const SizedBox(height: 14), right]);
                        }
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 34, child: img),
                              const SizedBox(width: 14),
                              Expanded(flex: 36, child: mid),
                              const SizedBox(width: 14),
                              Expanded(flex: 28, child: right),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, c) {
                        final narrow = c.maxWidth < 800;
                        final sum = _reviewSummaryStrip(d);
                        final add = _reviewAdditional(d);
                        if (narrow) return Column(children: [sum, const SizedBox(height: 12), add]);
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: sum),
                            const SizedBox(width: 12),
                            Expanded(child: add),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _capturedReviewSection(d, setCarouselIndex: (i) {
                      setState(() => _img = i);
                      _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
                    }),
                    const SizedBox(height: 18),
                    Text(
                      'Approving will mark this report as Cleared.\nRejecting will mark this report as Rejected.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: AdminColors.muted.withValues(alpha: 0.88), height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _OutlinedHoverButton(label: 'Cancel', onPressed: () => Navigator.pop(context, ReportReviewOutcome.cancelled)),
                        const Spacer(),
                        _OutlinedHoverButton(
                          label: 'Reject',
                          icon: Icons.close_rounded,
                          foreground: AdminColors.statRed,
                          onPressed: () => Navigator.pop(context, ReportReviewOutcome.rejected),
                        ),
                        const SizedBox(width: 10),
                        _FilledHoverButton(
                          label: 'Approve',
                          icon: Icons.check_rounded,
                          color: AdminColors.statGreen,
                          onPressed: () => Navigator.pop(context, ReportReviewOutcome.approved),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _reviewImageBlock(AdminReportModalData d) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _img = i),
              itemCount: d.imageUrls.length,
              itemBuilder: (_, i) => Image.network(d.imageUrls[i], fit: BoxFit.cover, width: double.infinity),
            ),
            Positioned(left: 6, top: 0, bottom: 0, child: Center(child: _roundNav(Icons.chevron_left_rounded, _img > 0, () => _pageCtrl.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic)))),
            Positioned(right: 6, top: 0, bottom: 0, child: Center(child: _roundNav(Icons.chevron_right_rounded, _img < d.imageUrls.length - 1, () => _pageCtrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic)))),
            Positioned(
              left: 10,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                child: Text('${_img + 1} / ${d.imageUrls.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewMidColumn(AdminReportModalData d) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _modalKv('Report ID', d.id),
        _modalKv('Type', d.typeLabel, valueColor: d.typeColor, boldValue: true),
        _modalKv('Submitted By', d.submittedBy),
        _modalKv('Zone', d.zoneLong, valueColor: AdminColors.statGreen),
        _modalKv('Submitted On', d.submittedOn),
        _modalKv('COTS Count', '${d.cotsCount}'),
        _modalKv('Detection Method', d.detectionMethod),
      ],
    );
  }

  Widget _reviewConfidence(AdminReportModalData d, Color ac) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ac.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Confidence Level', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.muted.withValues(alpha: 0.8))),
          Text('${d.confidencePct}%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ac)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            decoration: BoxDecoration(color: ac.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
            child: Text(d.confidenceBand, style: TextStyle(fontWeight: FontWeight.w900, color: ac)),
          ),
          Text('Status: ${d.statusLabel}', style: TextStyle(fontWeight: FontWeight.w800, color: ac)),
          const SizedBox(height: 8),
          Text(d.confidenceDescription, style: TextStyle(fontSize: 12.5, height: 1.35, color: AdminColors.headerTitle.withValues(alpha: 0.88))),
        ],
      ),
    );
  }

  Widget _reviewSummaryStrip(AdminReportModalData d) {
    final area = NumberFormat('#,##0').format(d.totalAreaM2);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _reviewChip(Icons.blur_on_rounded, 'COTS Detected', '${d.cotsCount}'),
          _reviewChip(Icons.set_meal_outlined, 'Other Marine Life', '${d.otherMarine}'),
          _reviewChip(Icons.cancel_outlined, 'False Positives', '${d.falsePositives}'),
          _reviewChip(Icons.square_foot_rounded, 'Total Analyzed Area', '$area m²'),
        ],
      ),
    );
  }

  Widget _reviewChip(IconData i, String t, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 20, color: AdminColors.statBlue),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AdminColors.muted.withValues(alpha: 0.8))),
            Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _reviewAdditional(AdminReportModalData d) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Additional Information', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 10),
          _modalKv('Water Visibility', d.waterVisibility, badge: AdminColors.statGreen),
          _modalKv('Weather Condition', d.weather),
          _modalKv('Depth', d.depthRange),
          const SizedBox(height: 6),
          Text('Notes from Submitter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.muted.withValues(alpha: 0.8))),
          const SizedBox(height: 6),
          Text(d.notes, style: const TextStyle(fontSize: 13, height: 1.45)),
        ],
      ),
    );
  }

  Widget _capturedReviewSection(AdminReportModalData d, {required void Function(int) setCarouselIndex}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('Captured Images', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const Spacer(),
            TextButton(onPressed: () {}, child: const Text('View All Images', style: TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < d.imageUrls.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _Thumb(url: d.imageUrls[i], index: i + 1, onTap: () => setCarouselIndex(i))),
            ],
          ],
        ),
      ],
    );
  }

  Widget _roundNav(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(padding: const EdgeInsets.all(6), child: Icon(icon, color: enabled ? AdminColors.headerTitle : AdminColors.muted)),
      ),
    );
  }
}

Widget _modalHeader(BuildContext context, {required String title, required String subtitle}) {
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminColors.headerTitle)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: AdminColors.muted.withValues(alpha: 0.92), height: 1.35)),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded),
              style: IconButton.styleFrom(foregroundColor: AdminColors.headerTitle),
            ),
          ],
        ),
      ),
      Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
    ],
  );
}

class _MiniMetric extends StatefulWidget {
  const _MiniMetric(this.icon, this.color, this.title, this.value, this.subtitle, {this.link = false});
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subtitle;
  final bool link;

  @override
  State<_MiniMetric> createState() => _MiniMetricState();
}

class _MiniMetricState extends State<_MiniMetric> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: _hover ? 0.12 : 0.07)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.04), blurRadius: _hover ? 14 : 8, offset: Offset(0, _hover ? 5 : 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(widget.icon, color: widget.color, size: 22),
            const SizedBox(height: 8),
            Text(widget.title, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AdminColors.muted.withValues(alpha: 0.85))),
            Text(widget.value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            Text(
              widget.subtitle,
              style: TextStyle(
                fontSize: 11,
                fontWeight: widget.link ? FontWeight.w800 : FontWeight.w600,
                color: widget.link ? AdminColors.statBlue : AdminColors.muted.withValues(alpha: 0.88),
                decoration: widget.link ? TextDecoration.underline : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({required this.url, required this.index, required this.onTap});
  final String url;
  final int index;
  final VoidCallback onTap;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedScale(
            scale: _hover ? 1.03 : 1,
            duration: const Duration(milliseconds: 180),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.1,
                    child: Image.network(
                      widget.url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE8EEF5),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined, size: 32),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AdminColors.statBlue,
                      child: Text('${widget.index}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedHoverButton extends StatefulWidget {
  const _OutlinedHoverButton({required this.label, required this.onPressed, this.icon, this.foreground});
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final Color? foreground;

  @override
  State<_OutlinedHoverButton> createState() => _OutlinedHoverButtonState();
}

class _OutlinedHoverButtonState extends State<_OutlinedHoverButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final fg = widget.foreground ?? AdminColors.headerTitle;
    final style = OutlinedButton.styleFrom(
      foregroundColor: fg,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      side: BorderSide(color: fg.withValues(alpha: _hover ? 0.55 : 0.35)),
      backgroundColor: _hover ? fg.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: widget.icon == null
          ? OutlinedButton(onPressed: widget.onPressed, style: style, child: Text(widget.label))
          : OutlinedButton.icon(onPressed: widget.onPressed, icon: Icon(widget.icon, size: 18), label: Text(widget.label), style: style),
    );
  }
}

class _FilledHoverButton extends StatefulWidget {
  const _FilledHoverButton({required this.label, required this.icon, required this.color, required this.onPressed});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_FilledHoverButton> createState() => _FilledHoverButtonState();
}

class _FilledHoverButtonState extends State<_FilledHoverButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final c = Color.lerp(widget.color, Colors.black, _hover ? 0.06 : 0)!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: FilledButton.icon(
        onPressed: widget.onPressed,
        icon: Icon(widget.icon, size: 18, color: Colors.white),
        label: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w800)),
        style: FilledButton.styleFrom(
          backgroundColor: c,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
