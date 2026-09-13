import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_navigation.dart';
import '../../../models/cots_confidence_policy.dart';
import '../../../models/intervention_assignment_model.dart';
import '../../../models/record_collection.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/intervention_assignment_repository.dart';
import '../../../services/notification_repository.dart';
import '../../../services/personnel_repository.dart';
import '../../../services/scan_record_service.dart';
import '../models/admin_record_table_row.dart';
import '../theme/admin_theme.dart';
import '../../../utils/scan_record_image.dart';
import '../../../widgets/cots_detection_image_overlay.dart';
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
    required this.imageUrl,
    required this.imagePath,
    required this.imageName,
    required this.dateCaptured,
    required this.dateUploaded,
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
  final String imageUrl;
  final String imagePath;
  final String imageName;
  final String dateCaptured;
  final String dateUploaded;
  final String scheduledDate;
  final String scheduledTime;
  final String assignedTo;
  final String schedulePurpose;
  final String userRemarks;
  final int attachmentCount;

  factory AdminRecordDetailsData.fromTableRow(AdminRecordTableRow row) {
    final (date, time) = _splitDateTime(
        row.dateUploaded.isNotEmpty ? row.dateUploaded : row.dateTime);
    final coords = row.latitude != null && row.longitude != null
        ? _formatCoords(row.latitude!, row.longitude!)
        : _coordsForZone(row.zone);
    final remarks =
        row.notes.trim().isEmpty ? 'No remarks submitted.' : row.notes.trim();
    final statusLabel = row.displayStatusLabel;
    return AdminRecordDetailsData(
      recordId: row.recordId,
      verificationBadgeLabel: statusLabel.toUpperCase(),
      submittedBy: row.submittedBy,
      submitterRole: 'Field Technician',
      submissionMethod: 'Gallery Upload',
      cotsDetected: row.cotsCount,
      confidencePercent: row.confidencePercent,
      monitoringStatus: statusLabel,
      monitoringStatusDescription:
          CotsConfidencePolicy.adminStatusDescriptionFromItems(
        items: row.detectionReviewItems,
        adminConfirmed: row.adminConfirmed,
        adminRejected: row.adminRejected,
      ),
      submittedDate: date,
      submittedTime: time,
      zone: row.zone,
      coordinates: coords,
      locationDateTime:
          row.dateUploaded.isNotEmpty ? row.dateUploaded : row.dateTime,
      locationAccuracy: 'Live Device GPS',
      autoZoneAssignment: row.zone,
      imageUrl: row.imageUrl,
      imagePath: row.imagePath,
      imageName: row.imageName.isNotEmpty ? row.imageName : 'GoPro image',
      dateCaptured: row.dateCaptured,
      dateUploaded:
          row.dateUploaded.isNotEmpty ? row.dateUploaded : row.dateTime,
      scheduledDate: '—',
      scheduledTime: '—',
      assignedTo: '—',
      schedulePurpose: '—',
      userRemarks: remarks,
      attachmentCount: 1,
    );
  }

  static String _formatCoords(double lat, double lng) {
    return '${lat.abs().toStringAsFixed(6)}° ${lat >= 0 ? 'N' : 'S'}, '
        '${lng.abs().toStringAsFixed(6)}° ${lng >= 0 ? 'E' : 'W'}';
  }

  static (String, String) _splitDateTime(String raw) {
    final m =
        RegExp(r'^(.*)\s(\d{1,2}:\d{2}\s*(?:AM|PM))$').firstMatch(raw.trim());
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
  const AdminRecordDetailsScreen({
    super.key,
    required this.row,
    this.viewOnly = false,
    this.expertContext = false,
  });

  final AdminRecordTableRow row;
  final bool viewOnly;
  final bool expertContext;

  @override
  State<AdminRecordDetailsScreen> createState() =>
      _AdminRecordDetailsScreenState();
}

class _AdminRecordDetailsScreenState extends State<AdminRecordDetailsScreen> {
  late AdminRecordTableRow _row;
  late List<CotsDetectionReviewItem> _detectionItems;
  late List<PerCotsAdminDecision> _cotsDecisions;
  int? _selectedCotsIndex;
  bool _savingReview = false;
  bool _savingAssignment = false;
  final _expertCommentsCtrl = TextEditingController();

  AdminRecordDetailsData get _record =>
      AdminRecordDetailsData.fromTableRow(_row);

  bool get _needsPerCotsReview =>
      !widget.viewOnly &&
      CotsConfidencePolicy.submissionNeedsPerCotsReview(_detectionItems) &&
      !_row.adminConfirmed &&
      !_row.adminRejected;

  bool get _allCotsAutoApproved =>
      _detectionItems.isNotEmpty &&
      _detectionItems.every(
        (i) => i.band == CotsVerificationBand.aiAutoApproved,
      );

  bool get _allCotsRetakeRequired =>
      _detectionItems.isNotEmpty &&
      _detectionItems.every(
        (i) => i.band == CotsVerificationBand.retakeRequired,
      );

  bool get _canManageAssignment =>
      widget.viewOnly &&
      !widget.expertContext &&
      _row.recordCollection == RecordCollection.captures;

  int get _lowConfidenceReviewedCount {
    var count = 0;
    for (var i = 0; i < _detectionItems.length; i++) {
      if (CotsConfidencePolicy.cotsNeedsAdminReview(
            _detectionItems[i].confidencePercent,
          ) &&
          _cotsDecisions[i] != PerCotsAdminDecision.pending) {
        count++;
      }
    }
    return count;
  }

  bool get _allCotsReviewed {
    for (var i = 0; i < _detectionItems.length; i++) {
      if (CotsConfidencePolicy.cotsNeedsAdminReview(
            _detectionItems[i].confidencePercent,
          ) &&
          _cotsDecisions[i] == PerCotsAdminDecision.pending) {
        return false;
      }
    }
    return _detectionItems.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _row = widget.row;
    _initDetectionReview();
  }

  @override
  void dispose() {
    _expertCommentsCtrl.dispose();
    super.dispose();
  }

  void _initDetectionReview() {
    _detectionItems = CotsConfidencePolicy.buildDetectionItems(
      count: _row.cotsCount,
      averagePercent: _row.confidencePercent,
      boxes: _row.detectionBoxes.isNotEmpty ? _row.detectionBoxes : null,
      imageWidth: _row.imageWidth > 0 ? _row.imageWidth : 1920,
      imageHeight: _row.imageHeight > 0 ? _row.imageHeight : 1080,
    );
    _selectedCotsIndex = null;
    if (_row.adminCotsDecisions.length == _detectionItems.length &&
        (_row.adminConfirmed || _row.adminRejected)) {
      _cotsDecisions = List<PerCotsAdminDecision>.from(_row.adminCotsDecisions);
    } else {
      _cotsDecisions =
          CotsConfidencePolicy.initialDecisionsForItems(_detectionItems);
    }
  }

  @override
  void didUpdateWidget(covariant AdminRecordDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.row.recordId != widget.row.recordId) {
      _row = widget.row;
      _initDetectionReview();
    }
  }

  void _setCotsDecision(int index, PerCotsAdminDecision decision) {
    setState(() {
      _cotsDecisions[index] = decision;
      _selectedCotsIndex = index;
    });
  }

  int get _confirmedCotsCount =>
      _cotsDecisions.where((d) => d == PerCotsAdminDecision.confirmed).length;

  void _popWithRow() {
    Navigator.of(context).pop(_row);
  }

  Future<void> _onAdminConfirm() async {
    if (!_needsPerCotsReview || !_allCotsReviewed || _savingReview) return;
    await _persistAdminReview(confirmed: true);
  }

  Future<void> _onAdminReject() async {
    if (!_needsPerCotsReview || !_allCotsReviewed || _savingReview) return;
    await _persistAdminReview(confirmed: false);
  }

  Future<void> _persistAdminReview({required bool confirmed}) async {
    final recordId = _row.documentId;
    if (recordId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Cannot save review — missing Firestore record ID.'),
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final reviewedBy = auth.userModel?.fullName.trim().isNotEmpty == true
        ? auth.userModel!.fullName.trim()
        : auth.firebaseUser?.email ??
            (widget.expertContext ? 'Expert' : 'Admin');

    setState(() => _savingReview = true);
    try {
      await ScanRecordService.updateAdminVerification(
        recordId: recordId,
        recordCollection: _row.recordCollection,
        adminConfirmed: confirmed,
        adminRejected: !confirmed,
        reviewedBy: reviewedBy,
        cotsDecisions: _cotsDecisions,
      );
      try {
        await NotificationRepository.createReviewDecision(
          recipientUid: _row.ownerUid,
          recordId: _row.recordId,
          zone: _row.zone,
          accepted: confirmed,
        );
      } catch (_) {
        // A saved review remains valid even if its notification cannot be sent.
      }
      if (!mounted) return;
      setState(() {
        _row = _row.copyWith(
          adminConfirmed: confirmed,
          adminRejected: !confirmed,
          adminCotsDecisions: List<PerCotsAdminDecision>.from(_cotsDecisions),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            confirmed
                ? '${_row.recordId}: $_confirmedCotsCount of ${_detectionItems.length} COTS confirmed — saved to Firestore.'
                : '${_row.recordId} rejected — saved to Firestore.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not save expert review: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingReview = false);
    }
  }

  Future<void> _logout() async {
    await confirmAndSignOut(context);
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
    final networkUrl = ScanRecordImage.networkUrl(
      imageUrl: _row.imageUrl,
      imagePath: _row.imagePath,
    );

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
                child: CotsDetectionImageOverlay(
                  imageWidth: _row.imageWidth > 0 ? _row.imageWidth : 1920,
                  imageHeight: _row.imageHeight > 0 ? _row.imageHeight : 1080,
                  items: _detectionItems,
                  recordId: _row.documentId,
                  recordCollection: _row.recordCollection,
                  imageUrl: networkUrl ?? _row.imageUrl,
                  imagePath: _row.imagePath,
                  storageObjectPath: _row.storageObjectPath,
                  decisions: _cotsDecisions,
                  selectedIndex: _selectedCotsIndex,
                  interactive: _needsPerCotsReview,
                  onBoxTap: (index) =>
                      setState(() => _selectedCotsIndex = index),
                  placeholderMessage:
                      'Submitted photo unavailable. Ask the user to re-submit so the image is uploaded to cloud storage.',
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToMapMonitoring() {
    if (widget.expertContext) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const AdminShellScreen(initialIndex: 1),
      ),
    );
  }

  Widget _expertChrome({required Widget body}) {
    return Scaffold(
      backgroundColor: AdminColors.contentBg,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: AdminColors.sidebarTop,
        foregroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _popWithRow,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text(
          'Expert Verification',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: body,
    );
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
    final viaLine = viaIdx >= 0
        ? raw.substring(viaIdx).trim()
        : 'Submitted via mobile app.';
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
    final u = label.toUpperCase();
    if (u.contains('ACCEPT') || u.contains('VERIF'))
      return AdminColors.statGreen;
    if (u.contains('REJECT')) return AdminColors.statRed;
    return AdminColors.statYellow;
  }

  @override
  Widget build(BuildContext context) {
    final r = _record;
    final detailsBody = LayoutBuilder(
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
                      final perCotsBelowImage = _needsPerCotsReview;
                      final leftCol = [
                        _detectionResultsCard(r),
                        const SizedBox(height: 14),
                        _confidencePolicyCard(),
                        const SizedBox(height: 14),
                        _informationCard(r),
                        if (_canManageAssignment) ...[
                          const SizedBox(height: 14),
                          _interventionAssignmentCard(),
                        ],
                        if (!perCotsBelowImage) ...[
                          const SizedBox(height: 14),
                          _perCotsVerificationCard(),
                        ],
                      ];
                      final rightCol = [
                        _imageCard(r),
                        if (perCotsBelowImage) ...[
                          const SizedBox(height: 14),
                          _perCotsVerificationCard(),
                        ],
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
                          Expanded(
                              flex: 52, child: Column(children: leftCol)),
                          const SizedBox(width: 16),
                          Expanded(
                              flex: 48,
                              child: Column(children: rightCol)),
                        ],
                      );
                    },
                  ),
                  if (_needsPerCotsReview) ...[
                    const SizedBox(height: 22),
                    _recordReviewActionRow(),
                    const SizedBox(height: 12),
                    Text(
                      'Review each COTS below ${CotsConfidencePolicy.autoApproveMin}% (${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1}% band). '
                      'Higher-confidence COTS in the same photo are already auto-approved.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.muted.withValues(alpha: 0.85),
                        height: 1.4,
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
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _popWithRow();
      },
      child: adminThemedSubtree(
        context,
        child: widget.expertContext
            ? _expertChrome(body: detailsBody)
            : AdminResponsiveChrome(
                selectedNavIndex: 3,
                onNavSelect: _onSidebarSelect,
                onLogout: _logout,
                pageTitle: 'Record Details',
                showBackButton: false,
                onBack: null,
                body: detailsBody,
              ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final dateBtn = OutlinedButton.icon(
      onPressed: () {},
      icon: AdminDateTimeTokens.dateChipIcon(),
      label: Text(AdminDateTimeTokens.demoDateRangeLabel,
          style: AdminDateTimeTokens.dateRangeChipTextStyle),
      style: AdminDateTimeTokens.dateRangeOutlinedButtonStyle(),
    );

    final refreshBtn = OutlinedButton.icon(
      onPressed: _onRecordDetailsRefresh,
      icon: AdminDateTimeTokens.refreshIcon,
      label: const Text('Refresh',
          style: AdminDateTimeTokens.refreshChipTextStyle),
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
                    SizedBox(
                        width: half,
                        child: _summaryMetric(
                            Icons.blur_on_rounded,
                            'COTS Detected',
                            '${r.cotsDetected}',
                            'Individuals',
                            AdminColors.statBlue)),
                    SizedBox(
                        width: half,
                        child: _summaryMetric(
                            Icons.verified_outlined,
                            'Confidence Level',
                            '${r.confidencePercent}%',
                            'Confidence',
                            AdminColors.statGreen)),
                    SizedBox(width: half, child: _summaryStatusBlock(r)),
                    SizedBox(width: half, child: _summarySubmittedBlock(r)),
                  ],
                ),
              ],
            );
          }
          Widget div() => VerticalDivider(
              width: 1,
              thickness: 1,
              color: Colors.black.withValues(alpha: 0.06));
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
                  child: _summaryMetric(Icons.blur_on_rounded, 'COTS Detected',
                      '${r.cotsDetected}', 'Individuals', AdminColors.statBlue),
                ),
                div(),
                Expanded(
                  flex: 13,
                  child: _summaryMetric(
                      Icons.verified_outlined,
                      'Confidence Level',
                      '${r.confidencePercent}%',
                      'Confidence',
                      AdminColors.statGreen),
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
              style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Text('Record ID: ${r.recordId}',
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AdminColors.headerTitle)),
          const SizedBox(height: 6),
          Text(
            'Submitted by: ${r.submittedBy} (${r.submitterRole})',
            style: TextStyle(
                fontSize: 12.5,
                color: AdminColors.muted.withValues(alpha: 0.95),
                height: 1.35),
          ),
          const SizedBox(height: 4),
          Text(
            'Submission Method: ${r.submissionMethod}',
            style: TextStyle(
                fontSize: 12.5,
                color: AdminColors.muted.withValues(alpha: 0.95),
                height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(IconData icon, String title, String value,
      String subtitle, Color accent) {
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
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AdminColors.muted.withValues(alpha: 0.9)),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AdminColors.headerTitle),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: AdminColors.muted.withValues(alpha: 0.85)),
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
            child: const Icon(Icons.check_circle_rounded,
                color: AdminColors.statGreen, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.muted.withValues(alpha: 0.9))),
                Text(r.monitoringStatus,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.headerTitle)),
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
            child: const Icon(Icons.calendar_month_rounded,
                color: AdminColors.statBlue, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Submitted On',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.muted.withValues(alpha: 0.9))),
                Text(r.submittedDate,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AdminColors.headerTitle)),
                if (r.submittedTime.isNotEmpty)
                  Text(r.submittedTime,
                      style: AdminDateTimeTokens.inlineDateTimeTextStyle(
                          secondary: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationCard(AdminRecordDetailsData r) {
    return _titledCard(
      icon: Icons.info_outline_rounded,
      title: 'Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Coordinates', r.coordinates),
          _kv('Location source', r.locationAccuracy),
          _kv('GPS source', r.locationAccuracy),
          _kv('Capture device', 'Unknown Device'),
          _kv('Upload method', r.submissionMethod),
          _kv('Date captured', r.dateCaptured),
          _kv('Date uploaded', r.dateUploaded),
          _kv('User remarks', r.userRemarks),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Auto Zone Assignment',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.muted),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminColors.statGreen.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  r.autoZoneAssignment,
                  style: const TextStyle(
                      color: AdminColors.statGreen,
                      fontWeight: FontWeight.w800,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _ActionOutlineButton(
                      icon: Icons.note_alt_outlined,
                      label: 'View Notes',
                      onPressed: _openViewNotes)),
              if (!widget.expertContext) ...[
                const SizedBox(width: 10),
                Expanded(
                    child: _ActionOutlineButton(
                        icon: Icons.map_outlined,
                        label: 'View on Map',
                        onPressed: _goToMapMonitoring)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _interventionAssignmentCard() {
    return StreamBuilder<InterventionAssignmentModel?>(
      stream: InterventionAssignmentRepository.watchForCapture(
        _row.documentId,
      ),
      builder: (context, snapshot) {
        final assignment = snapshot.data;
        return _titledCard(
          icon: Icons.assignment_ind_outlined,
          title: 'Intervention Assignment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (snapshot.hasError)
                Text(
                  'Could not load assignment: ${snapshot.error}',
                  style: const TextStyle(
                    color: AdminColors.statRed,
                    fontSize: 12,
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(child: CircularProgressIndicator())
              else if (assignment == null) ...[
                Text(
                  _row.displayStatusLabel == 'Accepted'
                      ? 'No personnel assigned yet.'
                      : 'This detection must be accepted before personnel can be assigned.',
                  style: const TextStyle(
                    color: AdminColors.muted,
                    fontSize: 12.5,
                  ),
                ),
                if (_row.displayStatusLabel == 'Accepted') ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _savingAssignment ? null : _showAssignmentDialog,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Assign Verified Personnel'),
                  ),
                ],
              ] else ...[
                _kv('Assigned to', assignment.assignedToName),
                _kv('Zone', assignment.zone),
                _kv(
                  'Due date',
                  assignment.dueAt == null
                      ? 'Not set'
                      : _formatAssignmentDate(assignment.dueAt!),
                ),
                _kv('Status', _assignmentStatusLabel(assignment.status)),
                if (assignment.hasEvidence) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _savingAssignment
                        ? null
                        : () => _confirmAssignmentCleared(assignment),
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('Confirm Area Cleared'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AdminColors.statGreen,
                    ),
                  ),
                ],
                if (assignment.isOpen) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _savingAssignment ? null : _showAssignmentDialog,
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Reassign'),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAssignmentDialog() async {
    List<UserModel> personnel;
    try {
      personnel = await PersonnelRepository.watchVerifiedPersonnel().first;
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load verified personnel: $error')),
      );
      return;
    }
    if (!mounted) return;
    if (personnel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verify at least one field personnel account in Admin → Users first.',
          ),
        ),
      );
      return;
    }

    String? selectedUid;
    DateTime? dueAt;
    final result = await showDialog<(String, DateTime)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Assign intervention task'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Only Administrator-verified personnel are shown.',
                  style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: selectedUid,
                  decoration: const InputDecoration(
                    labelText: 'Field personnel',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final person in personnel)
                      DropdownMenuItem(
                        value: person.uid,
                        child: Text(
                          '${person.fullName} · ${person.assignedArea.isEmpty ? 'Any zone' : person.assignedArea}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedUid = value),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: dialogContext,
                      initialDate: DateTime.now().add(const Duration(days: 7)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (selected != null) {
                      setDialogState(() => dueAt = selected);
                    }
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    dueAt == null
                        ? 'Select due date'
                        : _formatAssignmentDate(dueAt!),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedUid == null || dueAt == null
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        (selectedUid!, dueAt!),
                      ),
              child: const Text('Assign'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    final person = personnel.firstWhere((p) => p.uid == result.$1);
    final admin = context.read<AuthProvider>().userModel;
    setState(() => _savingAssignment = true);
    try {
      await InterventionAssignmentRepository.assign(
        InterventionAssignmentModel(
          captureId: _row.documentId,
          captureDisplayId: _row.recordId,
          zone: _row.zone,
          assignedToUid: person.uid,
          assignedToName: person.fullName,
          assignedByUid: admin?.uid ?? '',
          assignedByName: admin?.fullName ?? 'Administrator',
          assignedAt: DateTime.now(),
          dueAt: result.$2,
          status: InterventionAssignmentModel.assignedStatus,
        ),
      );
      try {
        await NotificationRepository.createInterventionAssigned(
          recipientUid: person.uid,
          recordId: _row.recordId,
          zone: _row.zone,
          dueAt: result.$2,
        );
      } catch (_) {
        // A saved assignment remains valid even if its notification cannot be sent.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task assigned to ${person.fullName}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not assign personnel: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingAssignment = false);
    }
  }

  Future<void> _confirmAssignmentCleared(
    InterventionAssignmentModel assignment,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm area cleared?'),
        content: Text(
          'Confirm that the submitted removal evidence for '
          '${assignment.captureDisplayId} has been reviewed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Cleared'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _savingAssignment = true);
    try {
      await InterventionAssignmentRepository.markCleared(
        assignment.captureId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Area marked as cleared.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update assignment: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingAssignment = false);
    }
  }

  String _assignmentStatusLabel(String status) {
    return switch (status) {
      InterventionAssignmentModel.assignedStatus => 'Assigned',
      InterventionAssignmentModel.evidenceSubmittedStatus =>
        'Evidence Submitted',
      InterventionAssignmentModel.clearedStatus => 'Cleared',
      _ => status,
    };
  }

  String _formatAssignmentDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/${date.year}';

  Widget _confidencePolicyCard() {
    return _titledCard(
      icon: Icons.policy_outlined,
      title: 'Verification Policy',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _policyRow(
            AdminColors.statGreen,
            'AI Auto-Approved (${CotsConfidencePolicy.autoApproveMin}–100%)',
            'Each COTS at ${CotsConfidencePolicy.autoApproveMin}%+ is accepted automatically — Automatically Accepted.',
          ),
          const SizedBox(height: 8),
          _policyRow(
            AdminColors.statYellow,
            'Requires Expert Validation (${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1})',
            'Any individual COTS below ${CotsConfidencePolicy.autoApproveMin}% must be accepted or rejected by an expert — even when other COTS in the same photo are higher.',
          ),
          const SizedBox(height: 8),
          _policyRow(
            AdminColors.statRed,
            'Retake Photo (0–${CotsConfidencePolicy.adminReviewMin - 1})',
            'Confidence too low. User should capture a clearer GoPro image.',
          ),
        ],
      ),
    );
  }

  Widget _policyRow(Color color, String title, String body) {
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
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: AdminColors.headerTitle)),
              const SizedBox(height: 2),
              Text(body,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.muted.withValues(alpha: 0.9),
                      height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _perCotsVerificationCard() {
    if (_detectionItems.isEmpty) {
      return _titledCard(
        icon: Icons.checklist_rtl_rounded,
        title: 'Per-COTS Verification',
        child: Text(
          'No labeled COTS to verify for this submission.',
          style: TextStyle(
              fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.9)),
        ),
      );
    }

    final readOnly = !_needsPerCotsReview;
    final autoCount = CotsConfidencePolicy.countAutoApproved(_detectionItems);
    final reviewCount =
        CotsConfidencePolicy.countNeedingAdminReview(_detectionItems);
    final reviewNeeded =
        CotsConfidencePolicy.countNeedingAdminReview(_detectionItems);
    final titleSuffix = _needsPerCotsReview
        ? ' · $_lowConfidenceReviewedCount / $reviewNeeded reviewed'
        : _allCotsAutoApproved
            ? ' · AI auto-approved'
            : _allCotsRetakeRequired
                ? ' · Retake required'
                : ' · Review complete';

    return _titledCard(
      icon: Icons.checklist_rtl_rounded,
      title: 'Per-COTS Verification$titleSuffix',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_needsPerCotsReview)
            Text(
              'Inspect each bounding box on the image. COTS at ${CotsConfidencePolicy.autoApproveMin}%+ are auto-approved; '
              'any COTS below ${CotsConfidencePolicy.autoApproveMin}% (${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1}%) needs your confirmation.',
              style: TextStyle(
                  fontSize: 12,
                  color: AdminColors.muted.withValues(alpha: 0.92),
                  height: 1.4),
            )
          else if (_allCotsAutoApproved)
            Text(
              'All ${_detectionItems.length} detections are ${CotsConfidencePolicy.autoApproveMin}%+ — each COTS was AI auto-approved.',
              style: TextStyle(
                  fontSize: 12,
                  color: AdminColors.statGreen.withValues(alpha: 0.95),
                  height: 1.4),
            )
          else if (_allCotsRetakeRequired)
            Text(
              'Submission flagged for retake — detections are not reviewed individually.',
              style: TextStyle(
                  fontSize: 12,
                  color: AdminColors.statRed.withValues(alpha: 0.9),
                  height: 1.4),
            )
          else
            Text(
              '$autoCount COTS auto-approved · $reviewCount reviewed by expert.',
              style: TextStyle(
                  fontSize: 12,
                  color: AdminColors.statGreen.withValues(alpha: 0.95),
                  height: 1.4),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < _detectionItems.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _cotsReviewRow(
              _detectionItems[i],
              _cotsDecisions[i],
              readOnly ||
                  !CotsConfidencePolicy.cotsNeedsAdminReview(
                    _detectionItems[i].confidencePercent,
                  ),
              i,
            ),
          ],
          if (_needsPerCotsReview) ...[
            const SizedBox(height: 12),
            Text(
              'Confirmed COTS: $_confirmedCotsCount · Rejected: ${_cotsDecisions.where((d) => d == PerCotsAdminDecision.rejected).length}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.muted.withValues(alpha: 0.9)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cotsReviewRow(
    CotsDetectionReviewItem item,
    PerCotsAdminDecision decision,
    bool readOnly,
    int index,
  ) {
    final selected = _selectedCotsIndex == index;
    Color statusColor;
    IconData statusIcon;
    switch (decision) {
      case PerCotsAdminDecision.confirmed:
        statusColor = AdminColors.statGreen;
        statusIcon = Icons.check_circle_rounded;
      case PerCotsAdminDecision.rejected:
        statusColor = AdminColors.statRed;
        statusIcon = Icons.cancel_rounded;
      case PerCotsAdminDecision.pending:
        statusColor = AdminColors.statYellow;
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            readOnly ? null : () => setState(() => _selectedCotsIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AdminColors.statBlue.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AdminColors.statBlue
                  : statusColor.withValues(alpha: 0.25),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(statusIcon, size: 18, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.label} — ${item.confidencePercent}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: AdminColors.headerTitle,
                      ),
                    ),
                    Text(
                      readOnly
                          ? (CotsConfidencePolicy.cotsNeedsAdminReview(
                              item.confidencePercent,
                            )
                              ? decision.label
                              : item.band == CotsVerificationBand.aiAutoApproved
                                  ? 'AI auto-approved'
                                  : decision.label)
                          : 'Tap box on image or use buttons to accept/deny',
                      style: TextStyle(
                        fontSize: 11,
                        color: AdminColors.muted.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if (!readOnly) ...[
                IconButton(
                  tooltip: 'Confirm COTS',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () =>
                      _setCotsDecision(index, PerCotsAdminDecision.confirmed),
                  icon: Icon(
                    Icons.check_circle_outline_rounded,
                    color: decision == PerCotsAdminDecision.confirmed
                        ? AdminColors.statGreen
                        : AdminColors.muted.withValues(alpha: 0.55),
                  ),
                ),
                IconButton(
                  tooltip: 'Reject detection',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () =>
                      _setCotsDecision(index, PerCotsAdminDecision.rejected),
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: decision == PerCotsAdminDecision.rejected
                        ? AdminColors.statRed
                        : AdminColors.muted.withValues(alpha: 0.55),
                  ),
                ),
              ] else
                Text(
                  decision.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: statusColor,
                  ),
                ),
            ],
          ),
        ),
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
                    border: Border.all(
                        color: AdminColors.statBlue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COTS Detected (Count)',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.muted.withValues(alpha: 0.9))),
                      const SizedBox(height: 4),
                      Text('${r.cotsDetected} individuals',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AdminColors.headerTitle)),
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
                    border: Border.all(
                        color: AdminColors.statGreen.withValues(alpha: 0.22)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Confidence Level',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AdminColors.muted.withValues(alpha: 0.9))),
                      const SizedBox(height: 4),
                      Text('${r.confidencePercent}% avg',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AdminColors.headerTitle)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Average confidence across all labeled COTS. '
            'Each COTS is evaluated individually: '
            '${CotsConfidencePolicy.autoApproveMin}–100% = AI auto-approve · '
            '${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1} = expert review for that COTS · '
            '0–${CotsConfidencePolicy.adminReviewMin - 1} = retake photo.',
            style: TextStyle(
                fontSize: 11.5,
                color: AdminColors.muted.withValues(alpha: 0.88),
                height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _imageCard(AdminRecordDetailsData r) {
    final imgW = _row.imageWidth > 0 ? _row.imageWidth : 1920;
    final imgH = _row.imageHeight > 0 ? _row.imageHeight : 1080;
    final networkUrl = ScanRecordImage.networkUrl(
      imageUrl: _row.imageUrl,
      imagePath: _row.imagePath,
    );

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
            recordId: _row.documentId,
            recordCollection: _row.recordCollection,
            imageUrl: networkUrl ?? _row.imageUrl,
            imagePath: _row.imagePath,
            storageObjectPath: _row.storageObjectPath,
            decisions: _cotsDecisions,
            selectedIndex: _selectedCotsIndex,
            interactive: _needsPerCotsReview,
            onBoxTap: (index) => setState(() => _selectedCotsIndex = index),
            placeholderMessage: 'Submitted photo unavailable for this record.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: const [
              _LegendDot(
                  color: AdminColors.statBlue,
                  label:
                      'High confidence (${CotsConfidencePolicy.autoApproveMin}%+)'),
              _LegendDot(
                  color: AdminColors.statYellow,
                  label:
                      'Needs review (${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1}%)'),
              _LegendDot(color: AdminColors.statGreen, label: 'Confirmed COTS'),
              _LegendDot(color: AdminColors.statRed, label: 'Rejected'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Each box is labeled (e.g. COTS 1 — 43%). Match boxes to the checklist — accept real starfish, reject false positives.',
            style: TextStyle(
                fontSize: 11.5,
                color: AdminColors.muted.withValues(alpha: 0.88),
                height: 1.4),
          ),
          const SizedBox(height: 14),
          _ActionOutlineButton(
              icon: Icons.open_in_full_rounded,
              label: 'View Full Image',
              onPressed: _openFullImage),
          const SizedBox(height: 16),
          Divider(color: AdminColors.muted.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          _statusSection(r),
        ],
      ),
    );
  }

  Widget _statusSection(AdminRecordDetailsData r) {
    final color = _verificationBadgeColor(r.monitoringStatus);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.flag_outlined,
                size: 18, color: AdminColors.muted.withValues(alpha: 0.9)),
            const SizedBox(width: 8),
            const Text(
              'Status Information',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AdminColors.headerTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r.monitoringStatus,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AdminColors.headerTitle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          r.monitoringStatusDescription,
          style: TextStyle(
            fontSize: 13,
            color: AdminColors.muted.withValues(alpha: 0.92),
            height: 1.4,
          ),
        ),
      ],
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
            child: Text(k,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.muted.withValues(alpha: 0.85))),
          ),
          Expanded(
              child: Text(v,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.headerTitle))),
        ],
      ),
    );
  }

  Widget _titledCard(
      {required IconData icon, required String title, required Widget child}) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AdminColors.statBlue),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.headerTitle)),
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
    final canFinalize = _allCotsReviewed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.expertContext) ...[
          Text(
            'Comments',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AdminColors.headerTitle.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _expertCommentsCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add expert validation comments (optional)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (!canFinalize)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Review all ${_detectionItems.length} labeled COTS before finalizing.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AdminColors.statYellow.withValues(alpha: 0.95),
              ),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 12,
          runSpacing: 12,
          children: [
            _RecordReviewActionBtn(
              label: 'Approve',
              icon: Icons.check_circle_outline_rounded,
              fg: AdminColors.statGreen,
              onPressed: canFinalize ? _onAdminConfirm : null,
            ),
            _RecordReviewActionBtn(
              label: 'Reject',
              icon: Icons.cancel_outlined,
              fg: AdminColors.statRed,
              onPressed: canFinalize ? _onAdminReject : null,
            ),
          ],
        ),
      ],
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: AdminColors.muted.withValues(alpha: 0.9))),
      ],
    );
  }
}

class _ActionOutlineButton extends StatefulWidget {
  const _ActionOutlineButton(
      {required this.icon, required this.label, required this.onPressed});
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
              side: BorderSide(
                  color: AdminColors.statBlue
                      .withValues(alpha: _hover ? 0.55 : 0.35)),
              backgroundColor: _hover
                  ? AdminColors.statBlue.withValues(alpha: 0.04)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
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
            side: BorderSide(
                color: widget.fg
                    .withValues(alpha: enabled && _hover ? 0.75 : 0.45)),
            backgroundColor: enabled && _hover
                ? widget.fg.withValues(alpha: 0.06)
                : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
