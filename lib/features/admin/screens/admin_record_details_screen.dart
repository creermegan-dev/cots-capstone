import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cots_monitor/providers/auth_provider.dart';
import '../models/admin_record_table_row.dart';
import '../theme/admin_theme.dart';
import '../layout/admin_breakpoints.dart';
import '../layout/admin_responsive_chrome.dart';
import '../widgets/admin_back_icon_button.dart';
import '../widgets/admin_record_details_dialogs.dart';
import 'admin_shell_screen.dart';

/// Full detail view for a single record / submission (admin).
class AdminRecordDetailsData {
  const AdminRecordDetailsData({
    required this.recordId,
    required this.verificationBadgeLabel,
    required this.submittedBy,
    required this.submitterRole,
    required this.submissionMethod,
    required this.cotsDetected,
    required this.confidencePercent,
    required this.monitoringStatus,
    required this.monitoringStatusDescription,
    required this.submittedDate,
    required this.submittedTime,
    required this.zone,
    required this.coordinates,
    required this.locationDateTime,
    required this.locationAccuracy,
    required this.autoZoneAssignment,
    required this.detectionImageUrl,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.assignedTo,
    required this.schedulePurpose,
    required this.userRemarks,
    required this.attachmentCount,
  });

  final String recordId;
  final String verificationBadgeLabel;
  final String submittedBy;
  final String submitterRole;
  final String submissionMethod;
  final int cotsDetected;
  final int confidencePercent;
  final String monitoringStatus;
  final String monitoringStatusDescription;
  final String submittedDate;
  final String submittedTime;
  final String zone;
  final String coordinates;
  final String locationDateTime;
  final String locationAccuracy;
  final String autoZoneAssignment;
  final String detectionImageUrl;
  final String scheduledDate;
  final String scheduledTime;
  final String assignedTo;
  final String schedulePurpose;
  final String userRemarks;
  final int attachmentCount;

  factory AdminRecordDetailsData.fromTableRow(AdminRecordTableRow row) {
    final (date, time) = _splitDateTime(row.dateTime);
    final coords = _coordsForZone(row.zone);
    final remarks =
        'Multiple COTS observed near the reef area in ${row.zone}. Water is clear and calm. Submitted via mobile app.';
    return AdminRecordDetailsData(
      recordId: row.recordId,
      verificationBadgeLabel: switch (row.displayStatus) {
        'Verified' => 'VERIFIED',
        'Needs Review' => 'NEEDS REVIEW',
        'Rejected' => 'REJECTED',
        _ => row.displayStatus.toUpperCase(),
      },
      submittedBy: row.submittedBy,
      submitterRole: 'Field Technician',
      submissionMethod: 'Scan / Detection',
      cotsDetected: row.cotsCount,
      confidencePercent: row.confidencePercent,
      monitoringStatus: 'Active',
      monitoringStatusDescription: 'Monitoring is ongoing in this area.',
      submittedDate: date,
      submittedTime: time,
      zone: row.zone,
      coordinates: coords,
      locationDateTime: row.dateTime,
      locationAccuracy: '± 5 m',
      autoZoneAssignment: row.zone,
      detectionImageUrl:
          'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1400&q=80',
      scheduledDate: 'May 22, 2026',
      scheduledTime: '08:00 AM',
      assignedTo: '${row.submittedBy} (Field Technician)',
      schedulePurpose: 'Follow-up monitoring',
      userRemarks: remarks,
      attachmentCount: 2,
    );
  }

  static (String, String) _splitDateTime(String raw) {
    final m = RegExp(r'^(.*)\s(\d{1,2}:\d{2}\s*(?:AM|PM))$').firstMatch(raw.trim());
    if (m != null) {
      return (m.group(1)!.trim(), m.group(2)!.trim());
    }
    return (raw, '');
  }

  static String _coordsForZone(String zone) {
    final seed = zone.hashCode.abs() % 1000000;
    final lat = 13.0 + (seed % 200000) / 1000000;
    final lng = 120.0 + ((seed ~/ 7) % 300000) / 1000000;
    return '${lat.toStringAsFixed(6)}° N, ${lng.toStringAsFixed(6)}° E (GPS)';
  }
}

class AdminRecordDetailsScreen extends StatefulWidget {
  const AdminRecordDetailsScreen({super.key, required this.row});

  final AdminRecordTableRow row;

  @override
  State<AdminRecordDetailsScreen> createState() => _AdminRecordDetailsScreenState();
}

class _AdminRecordDetailsScreenState extends State<AdminRecordDetailsScreen> {
  late AdminRecordTableRow _row;

  AdminRecordDetailsData get _record => AdminRecordDetailsData.fromTableRow(_row);

  bool get _showAdminConfirm => _row.displayStatus == 'Needs Review';

  @override
  void initState() {
    super.initState();
    _row = widget.row;
  }

  @override
  void didUpdateWidget(covariant AdminRecordDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.recordId != widget.row.recordId) {
      _row = widget.row;
    }
  }

  void _popWithRow() {
    Navigator.of(context).pop(_row);
  }

  void _onAdminConfirm() {
    if (!_showAdminConfirm) return;
    setState(() => _row = _row.copyWith(adminConfirmed: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${_row.recordId} verified after admin confirmation.'),
      ),
    );
  }

  void _onAdminReject() {
    if (!_showAdminConfirm) return;
    setState(() => _row = _row.copyWith(adminRejected: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${_row.recordId} rejected after admin review.'),
      ),
    );
  }
  Future<void> _logout() async {
    if (!context.mounted) return;
    await context.read<AuthProvider>().signOut();
  }

  void _onSidebarSelect(int index) {
    if (index == 3) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminShellScreen(initialIndex: index),
      ),
    );
  }

  void _openFullImage() {
    final url = _record.detectionImageUrl;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToMapMonitoring() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const AdminShellScreen(initialIndex: 1),
      ),
    );
  }

  void _openAllSchedules() {
    showAdminAllSchedulesDialog(context, zoneName: _record.zone);
  }

  void _onRecordDetailsRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Record details refreshed.'),
      ),
    );
    setState(() {});
  }

  void _openViewNotes() {
    final raw = _record.userRemarks;
    final viaIdx = raw.indexOf('Submitted via');
    var body = viaIdx >= 0 ? raw.substring(0, viaIdx).trim() : raw.trim();
    if (body.contains('. Water')) {
      body = body.replaceFirst('. Water', '.\nWater');
    }
    final viaLine = viaIdx >= 0 ? raw.substring(viaIdx).trim() : 'Submitted via mobile app.';
    final submittedOn = _record.submittedTime.isEmpty
        ? _record.locationDateTime
        : '${_record.submittedDate} ${_record.submittedTime}';
    showAdminViewNotesDialog(
      context,
      userRemarksBody: body,
      submittedViaLine: viaLine,
      submittedByLine: '${_record.submittedBy} (${_record.submitterRole})',
      submittedOnLine: submittedOn,
    );
  }

  Color _verificationBadgeColor(String label) {
    if (label == 'VERIFIED') return AdminColors.statGreen;
    if (label == 'REJECTED') return AdminColors.statRed;
    return AdminColors.statYellow;
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _popWithRow();
      },
      child: adminThemedSubtree(
        context,
        child: AdminResponsiveChrome(
        selectedNavIndex: 3,
        onNavSelect: _onSidebarSelect,
        onLogout: _logout,
        pageTitle: 'Record Details',
        showBackButton: false,
        onBack: null,
        body: LayoutBuilder(
          builder: (context, c) {
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: AdminBreakpoints.pagePadding(c.maxWidth),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _header(context),
                      const SizedBox(height: 18),
                      _summaryCard(r),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, c2) {
                          final narrow = c2.maxWidth < 1000;
                              final leftCol = [
                                _locationCard(r),
                                const SizedBox(height: 14),
                                _detectionResultsCard(r),
                                const SizedBox(height: 14),
                                _scheduleCard(r),
                              ];
                              final rightCol = [
                                _imageCard(r),
                                const SizedBox(height: 14),
                                _statusCard(r),
                                const SizedBox(height: 14),
                                _notesCard(r),
                              ];
                              if (narrow) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [...leftCol, ...rightCol],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 52, child: Column(children: leftCol)),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 48, child: Column(children: rightCol)),
                                ],
                              );
                            },
                          ),
                      if (_showAdminConfirm) ...[
                        const SizedBox(height: 22),
                        _recordReviewActionRow(),
                        const SizedBox(height: 16),
                        Text(
                          'Only authorized administrators can confirm or reject submissions that need review (60–84% confidence).',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.muted.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Center(
                        child: Text(
                          'COTS Monitoring System — Protecting our reefs, preserving our future.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AdminColors.muted.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _header(BuildContext context) {
    final dateBtn = OutlinedButton.icon(
      onPressed: () {},
      icon: AdminDateTimeTokens.dateChipIcon(),
      label: const Text(AdminDateTimeTokens.demoDateRangeLabel, style: AdminDateTimeTokens.dateRangeChipTextStyle),
      style: AdminDateTimeTokens.dateRangeOutlinedButtonStyle(),
    );

    final refreshBtn = OutlinedButton.icon(
      onPressed: _onRecordDetailsRefresh,
      icon: AdminDateTimeTokens.refreshIcon,
      label: const Text('Refresh', style: AdminDateTimeTokens.refreshChipTextStyle),
      style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
    );

    const titleCol = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Record / Submission Details',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AdminColors.headerTitle,
            letterSpacing: -0.5,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );

    final backBtn = AdminBackIconButton(onPressed: _popWithRow);

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              backBtn,
              const SizedBox(height: 4),
              titleCol,
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  dateBtn,
                  refreshBtn,
                ],
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            backBtn,
            const SizedBox(width: 6),
            Expanded(child: titleCol),
            const SizedBox(width: 12),
            dateBtn,
            const SizedBox(width: 10),
            refreshBtn,
          ],
        );
      },
    );
  }

  Widget _summaryCard(AdminRecordDetailsData r) {
    final badgeColor = _verificationBadgeColor(r.verificationBadgeLabel);
    return _shell(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final useStacked = w < 960;
          if (useStacked) {
            final half = w > 520 ? (w - 12) / 2 : w;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summaryBlock1(r, badgeColor),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(width: half, child: _summaryMetric(Icons.blur_on_rounded, 'COTS Detected', '${r.cotsDetected}', 'Individuals', AdminColors.statBlue)),
                    SizedBox(width: half, child: _summaryMetric(Icons.verified_outlined, 'Confidence Level', '${r.confidencePercent}%', 'Confidence', AdminColors.statGreen)),
                    SizedBox(width: half, child: _summaryStatusBlock(r)),
                    SizedBox(width: half, child: _summarySubmittedBlock(r)),
                  ],
                ),
              ],
            );
          }
          Widget div() => VerticalDivider(width: 1, thickness: 1, color: Colors.black.withValues(alpha: 0.06));
          return SizedBox(
            width: w,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 34,
                  child: _summaryBlock1(r, badgeColor),
                ),
                div(),
                Expanded(
                  flex: 13,
                  child: _summaryMetric(Icons.blur_on_rounded, 'COTS Detected', '${r.cotsDetected}', 'Individuals', AdminColors.statBlue),
                ),
                div(),
                Expanded(
                  flex: 13,
                  child: _summaryMetric(Icons.verified_outlined, 'Confidence Level', '${r.confidencePercent}%', 'Confidence', AdminColors.statGreen),
                ),
                div(),
                Expanded(
                  flex: 11,
                  child: _summaryStatusBlock(r),
                ),
                div(),
                Expanded(
                  flex: 15,
                  child: _summarySubmittedBlock(r),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryBlock1(AdminRecordDetailsData r, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              r.verificationBadgeLabel,
              style: TextStyle(color: badgeColor, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Text('Record ID: ${r.recordId}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AdminColors.headerTitle)),
          const SizedBox(height: 6),
          Text(
            'Submitted by: ${r.submittedBy} (${r.submitterRole})',
            style: TextStyle(fontSize: 12.5, color: AdminColors.muted.withValues(alpha: 0.95), height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            'Submission Method: ${r.submissionMethod}',
            style: TextStyle(fontSize: 12.5, color: AdminColors.muted.withValues(alpha: 0.95), height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(IconData icon, String title, String value, String subtitle, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.9)),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminColors.headerTitle),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: AdminColors.muted.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryStatusBlock(AdminRecordDetailsData r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdminColors.statGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.check_circle_rounded, color: AdminColors.statGreen, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.9))),
                Text(r.monitoringStatus, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AdminColors.headerTitle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summarySubmittedBlock(AdminRecordDetailsData r) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AdminColors.statBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.calendar_month_rounded, color: AdminColors.statBlue, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Submitted On', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.9))),
                Text(r.submittedDate, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AdminColors.headerTitle)),
                if (r.submittedTime.isNotEmpty)
                  Text(r.submittedTime, style: AdminDateTimeTokens.inlineDateTimeTextStyle(secondary: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(AdminRecordDetailsData r) {
    return _titledCard(
      icon: Icons.location_on_outlined,
      title: 'Location Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Zone', r.zone),
          _kv('Coordinates', r.coordinates),
          _kv('Date & Time', r.locationDateTime),
          _kv('Location Accuracy', r.locationAccuracy),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Auto Zone Assignment', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.9))),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminColors.statGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(r.autoZoneAssignment, style: const TextStyle(color: AdminColors.statGreen, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ActionOutlineButton(icon: Icons.map_outlined, label: 'View on Map', onPressed: _goToMapMonitoring),
        ],
      ),
    );
  }

  Widget _detectionResultsCard(AdminRecordDetailsData r) {
    return _titledCard(
      icon: Icons.center_focus_strong_outlined,
      title: 'Detection Results',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminColors.statBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminColors.statBlue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COTS Detected (Count)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.9))),
                      const SizedBox(height: 4),
                      Text('${r.cotsDetected} individuals', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.headerTitle)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AdminColors.statGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminColors.statGreen.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confidence Level', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.9))),
                      const SizedBox(height: 4),
                      Text('${r.confidencePercent}% Confidence', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AdminColors.headerTitle)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Confidence is the system\'s estimate that the detected organism is COTS.',
            style: TextStyle(fontSize: 11.5, color: AdminColors.muted.withValues(alpha: 0.88), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard(AdminRecordDetailsData r) {
    return _titledCard(
      icon: Icons.event_note_outlined,
      title: 'Schedule (if applicable)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Scheduled Date', r.scheduledDate),
          _kv('Scheduled Time', r.scheduledTime),
          _kv('Assigned To', r.assignedTo),
          _kv('Purpose', r.schedulePurpose),
          const SizedBox(height: 14),
          _ActionOutlineButton(icon: Icons.calendar_month_outlined, label: 'View All Schedules', onPressed: _openAllSchedules),
        ],
      ),
    );
  }

  Widget _imageCard(AdminRecordDetailsData r) {
    return _titledCard(
      icon: Icons.image_outlined,
      title: 'Detection Image',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                r.detectionImageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, p) {
                  if (p == null) return child;
                  return Container(color: const Color(0xFFE8EEF5), child: const Center(child: CircularProgressIndicator()));
                },
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFE8EEF5),
                  alignment: Alignment.center,
                  child: Icon(Icons.photo_outlined, size: 48, color: AdminColors.muted.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ActionOutlineButton(icon: Icons.open_in_full_rounded, label: 'View Full Image', onPressed: _openFullImage),
        ],
      ),
    );
  }

  Widget _statusCard(AdminRecordDetailsData r) {
    return _titledCard(
      icon: Icons.flag_outlined,
      title: 'Status Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AdminColors.statGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.statGreen.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AdminColors.statGreen, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    r.monitoringStatus,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AdminColors.headerTitle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(r.monitoringStatusDescription, style: TextStyle(fontSize: 13, color: AdminColors.muted.withValues(alpha: 0.92), height: 1.4)),
        ],
      ),
    );
  }

  Widget _notesCard(AdminRecordDetailsData r) {
    return _titledCard(
      icon: Icons.sticky_note_2_outlined,
      title: 'Notes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('USER REMARKS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: AdminColors.muted.withValues(alpha: 0.75))),
          const SizedBox(height: 6),
          Text(r.userRemarks, style: TextStyle(fontSize: 13, height: 1.45, color: AdminColors.headerTitle.withValues(alpha: 0.92))),
          const SizedBox(height: 14),
          Text('ATTACHMENTS', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1, color: AdminColors.muted.withValues(alpha: 0.75))),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AdminColors.statGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${r.attachmentCount} files', style: const TextStyle(color: AdminColors.statGreen, fontWeight: FontWeight.w800, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ActionOutlineButton(icon: Icons.note_alt_outlined, label: 'View Notes', onPressed: _openViewNotes),
          const SizedBox(height: 10),
          _ActionOutlineButton(icon: Icons.attach_file_rounded, label: 'View Attachments', onPressed: () {}),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(k, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.85))),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AdminColors.headerTitle))),
        ],
      ),
    );
  }

  Widget _titledCard({required IconData icon, required String title, required Widget child}) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AdminColors.statBlue),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AdminColors.headerTitle)),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _recordReviewActionRow() {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 12,
      children: [
        _RecordReviewActionBtn(
          label: 'Confirm submission',
          icon: Icons.check_circle_outline_rounded,
          fg: AdminColors.statGreen,
          onPressed: _onAdminConfirm,
        ),
        _RecordReviewActionBtn(
          label: 'Reject submission',
          icon: Icons.cancel_outlined,
          fg: AdminColors.statRed,
          onPressed: _onAdminReject,
        ),
      ],
    );
  }
}

class _ActionOutlineButton extends StatefulWidget {
  const _ActionOutlineButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_ActionOutlineButton> createState() => _ActionOutlineButtonState();
}

class _ActionOutlineButtonState extends State<_ActionOutlineButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: AdminColors.statBlue.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: widget.onPressed,
            icon: Icon(widget.icon, size: 18),
            label: Text(widget.label),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AdminColors.statBlue,
              side: BorderSide(color: AdminColors.statBlue.withValues(alpha: _hover ? 0.55 : 0.35)),
              backgroundColor: _hover ? AdminColors.statBlue.withValues(alpha: 0.04) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Same interaction pattern as alert-detail status actions ([OutlinedButton] + hover tint).
class _RecordReviewActionBtn extends StatefulWidget {
  const _RecordReviewActionBtn({
    required this.label,
    required this.icon,
    required this.fg,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color fg;
  final VoidCallback? onPressed;

  @override
  State<_RecordReviewActionBtn> createState() => _RecordReviewActionBtnState();
}

class _RecordReviewActionBtnState extends State<_RecordReviewActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled ? 1 : 0.45,
        child: OutlinedButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 18),
          label: Text(widget.label),
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.fg,
            side: BorderSide(color: widget.fg.withValues(alpha: enabled && _hover ? 0.75 : 0.45)),
            backgroundColor: enabled && _hover ? widget.fg.withValues(alpha: 0.06) : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
