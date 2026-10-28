import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/cots_confidence_policy.dart';
import '../../../providers/admin_record_review_tracker.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/scan_record_service.dart';
import '../../../services/scan_record_repository.dart';
import '../../../services/notification_repository.dart';
import '../layout/admin_breakpoints.dart';
import '../models/admin_record_table_row.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_stat_card.dart';
import 'admin_record_details_screen.dart';
import '../../../widgets/cots_loading_skeleton.dart';

class AdminRecordsSubmissionsScreen extends StatefulWidget {
  const AdminRecordsSubmissionsScreen({
    super.key,
    this.viewOnly = false,
    this.expertContext = false,
  });

  /// When true, hide approve/reject — admin oversight only.
  final bool viewOnly;

  /// Expert shell — adjusts copy and reviewer labels.
  final bool expertContext;

  @override
  State<AdminRecordsSubmissionsScreen> createState() =>
      _AdminRecordsSubmissionsScreenState();
}

class _AdminRecordsSubmissionsScreenState
    extends State<AdminRecordsSubmissionsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  final TextEditingController _searchCtrl = TextEditingController();
  String _zone = 'All Zones';
  String _status = 'All Status';
  String _risk = 'All Risk Levels';
  int _page = 0;
  int _rowsPerPage = 10;

  static const List<AdminDataTableColumn> _tableColumns = [
    AdminDataTableColumn('#', 44, headerAlign: TextAlign.center),
    AdminDataTableColumn('Record ID', 108),
    AdminDataTableColumn('Activity Type', 108, headerAlign: TextAlign.center),
    AdminDataTableColumn('AI Count', 72, headerAlign: TextAlign.right),
    AdminDataTableColumn('Removed', 72, headerAlign: TextAlign.right),
    AdminDataTableColumn('Avg Size', 76, headerAlign: TextAlign.right),
    AdminDataTableColumn('Capture', 100),
    AdminDataTableColumn('Zone', 72, headerAlign: TextAlign.center),
    AdminDataTableColumn('Date captured', 120),
    AdminDataTableColumn('Date uploaded', 120),
    AdminDataTableColumn('Conf.', 56, headerAlign: TextAlign.right),
    AdminDataTableColumn('Status', 92, headerAlign: TextAlign.center),
    AdminDataTableColumn('Submitted By', 120),
    AdminDataTableColumn('Actions', 108, headerAlign: TextAlign.right),
  ];

  static const _statuses = ['All Status', 'Accepted', 'Under Review', 'Rejected'];
  static const _risks = ['All Risk Levels', 'High', 'Moderate', 'Low'];

  /// Optimistic UI until the Firestore stream refreshes.
  final Map<String, AdminRecordTableRow> _overrides = {};

  List<String> _zoneOptions(List<AdminRecordTableRow> rows) {
    final zones = rows.map((r) => r.zone).toSet().toList()..sort();
    return ['All Zones', ...zones];
  }

  List<AdminRecordTableRow> _mergeRows(List<AdminRecordTableRow> rows) {
    return rows.map((r) => _overrides[r.recordId] ?? r).toList();
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _resetRecordFilters() {
    setState(() {
      _searchCtrl.clear();
      _zone = 'All Zones';
      _status = _statuses.first;
      _risk = _risks.first;
      _page = 0;
    });
  }

  void _onRecordsHeaderRefresh() {
    _resetRecordFilters();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Records refreshed from Firestore.'),
      ),
    );
  }

  void _openRecordDetails(AdminRecordTableRow row) async {
    if (!widget.viewOnly) {
      context.read<AdminRecordReviewTracker>().markOpened(row);
    }
    final returned = await Navigator.of(context).push<AdminRecordTableRow?>(
      MaterialPageRoute<AdminRecordTableRow?>(
        builder: (_) => AdminRecordDetailsScreen(
          row: row,
          viewOnly: widget.viewOnly,
          expertContext: widget.expertContext,
        ),
      ),
    );
    if (!mounted || returned == null) return;
    setState(() {
      _overrides[returned.recordId] = returned;
    });
  }

  Future<void> _confirmSubmission(AdminRecordTableRow row) async {
    final decisions = CotsConfidencePolicy.initialDecisionsForItems(
      row.detectionReviewItems,
    ).map(
      (d) => d == PerCotsAdminDecision.pending
          ? PerCotsAdminDecision.confirmed
          : d,
    ).toList();
    await _persistSubmissionReview(
      row,
      confirmed: true,
      cotsDecisions: decisions,
    );
  }

  Future<void> _rejectSubmission(AdminRecordTableRow row) async {
    final decisions = List<PerCotsAdminDecision>.filled(
      row.detectionReviewItems.length,
      PerCotsAdminDecision.rejected,
    );
    await _persistSubmissionReview(
      row,
      confirmed: false,
      cotsDecisions: decisions,
    );
  }

  Future<void> _persistSubmissionReview(
    AdminRecordTableRow row, {
    required bool confirmed,
    required List<PerCotsAdminDecision> cotsDecisions,
  }) async {
    final recordId = row.documentId;
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

    try {
      await ScanRecordService.updateAdminVerification(
        recordId: recordId,
        recordCollection: row.recordCollection,
        adminConfirmed: confirmed,
        adminRejected: !confirmed,
        reviewedBy: reviewedBy,
        cotsDecisions: cotsDecisions,
      );
      try {
        await NotificationRepository.createReviewDecision(
          recipientUid: row.ownerUid,
          recordId: row.recordId,
          zone: row.zone,
          accepted: confirmed,
        );
      } catch (_) {
        // A saved review remains valid even if its notification cannot be sent.
      }
      if (!mounted) return;
      setState(() {
        _overrides[row.recordId] = row.copyWith(
          adminConfirmed: confirmed,
          adminRejected: !confirmed,
          adminCotsDecisions: cotsDecisions,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            confirmed
                ? '${row.recordId} verified — saved to Firestore.'
                : '${row.recordId} rejected — saved to Firestore.',
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
    }
  }

  (int accepted, int underReview, int rejected) _statusCounts(
    List<AdminRecordTableRow> rows,
  ) {
    var accepted = 0;
    var underReview = 0;
    var rejected = 0;
    for (final r in rows) {
      switch (r.displayStatusLabel) {
        case 'Accepted':
          accepted++;
          break;
        case 'Under Review':
          underReview++;
          break;
        case 'Rejected':
          rejected++;
          break;
      }
    }
    return (accepted, underReview, rejected);
  }

  List<AdminRecordTableRow> _filteredRows(List<AdminRecordTableRow> rows) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return rows.where((r) {
      final byQuery = q.isEmpty ||
          r.recordId.toLowerCase().contains(q) ||
          r.zone.toLowerCase().contains(q) ||
          r.submittedBy.toLowerCase().contains(q);
      final byZone = _zone == 'All Zones' || r.zone == _zone;
      final byStatus = _status == 'All Status' || r.displayStatusLabel == _status;
      final byRisk = _risk == 'All Risk Levels' || r.risk == _risk;
      return byQuery && byZone && byStatus && byRisk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pagePad = AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);

    return StreamBuilder<List<AdminRecordTableRow>>(
      stream: ScanRecordRepository.watchAdminTableRows(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const CotsPageLoading(label: 'Loading monitoring records');
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48, color: AdminColors.muted),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load records',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AdminColors.headerTitle,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AdminColors.muted),
                  ),
                ],
              ),
            ),
          );
        }

        final rows = _mergeRows(snapshot.data ?? []);
        final zoneOptions = _zoneOptions(rows);
        if (!zoneOptions.contains(_zone)) {
          _zone = 'All Zones';
        }

        final filtered = _filteredRows(rows);
        final pageCount = (filtered.length / _rowsPerPage).ceil().clamp(1, 999);
        _page = _page.clamp(0, pageCount - 1);
        final start = _page * _rowsPerPage;
        final pageRows = filtered.skip(start).take(_rowsPerPage).toList();
        final end = pageRows.isEmpty ? 0 : start + pageRows.length;

        return FadeTransition(
          opacity: _fade,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pagePad.left, 22, pagePad.right, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDashboardHeader(
                  title: widget.viewOnly
                      ? 'Records Overview'
                      : 'Records Verification',
                  subtitle: widget.viewOnly
                      ? 'View citizen science submissions and expert verification status. Approval is handled by experts.'
                      : widget.expertContext
                          ? 'Review GoPro detections and approve or reject low-confidence submissions.'
                          : 'Manage GoPro detection records, AI monitoring results, and expert verification in one place.',
                  onRefreshTap: _onRecordsHeaderRefresh,
                ),
                const SizedBox(height: 22),
                _stats(rows),
                const SizedBox(height: 20),
                _filters(zoneOptions),
                const SizedBox(height: 14),
                _table(filtered, pageRows, start, end, pageCount),
                const SizedBox(height: 14),
                _bottomCharts(rows),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _stats(List<AdminRecordTableRow> rows) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxWidth = c.maxWidth;
        final total = rows.length;
        final (nAccepted, nReview, nRejected) = _statusCounts(rows);
        double rowPct(int count) => total == 0 ? 0.0 : (100 * count / total);
        final knownDensities = rows.map((row) => row.density).whereType<double>().toList();
        final avgDensity = knownDensities.isEmpty ? null : knownDensities.reduce((a, b) => a + b) / knownDensities.length;

        final cards = <Widget>[
          AdminStatCard(
            title: 'Total Records',
            value: '$total',
            subtitle: total == 0 ? 'No submissions yet' : 'GoPro & AI monitoring entries',
            icon: Icons.inventory_2_outlined,
            accentColor: AdminColors.statBlue,
            selected: _status == 'All Status',
            onTap: () => setState(() => _status = 'All Status'),
          ),
          AdminStatCard(
            title: 'Accepted',
            value: '$nAccepted',
            subtitle: '${rowPct(nAccepted).toStringAsFixed(1)}% · Automatically Accepted ${CotsConfidencePolicy.autoApproveMin}–100%',
            icon: Icons.verified_rounded,
            accentColor: AdminColors.statGreen,
            selected: _status == 'Accepted',
            onTap: () => setState(() {
              _status = _status == 'Accepted' ? 'All Status' : 'Accepted';
            }),
          ),
          AdminStatCard(
            title: 'Under Review',
            value: '$nReview',
            subtitle: '${rowPct(nReview).toStringAsFixed(1)}% · Requires Expert Validation ${CotsConfidencePolicy.adminReviewMin}–${CotsConfidencePolicy.autoApproveMin - 1}',
            icon: Icons.warning_amber_rounded,
            accentColor: AdminColors.statYellow,
            selected: _status == 'Under Review',
            onTap: () => setState(() {
              _status = _status == 'Under Review' ? 'All Status' : 'Under Review';
            }),
          ),
          AdminStatCard(
            title: 'Rejected',
            value: '$nRejected',
            subtitle: '${rowPct(nRejected).toStringAsFixed(1)}% · Retake photo 0–${CotsConfidencePolicy.adminReviewMin - 1}',
            icon: Icons.cancel_outlined,
            accentColor: AdminColors.statRed,
            selected: _status == 'Rejected',
            onTap: () => setState(() {
              _status = _status == 'Rejected' ? 'All Status' : 'Rejected';
            }),
          ),
          AdminStatCard(
            title: 'Average Density',
            value: avgDensity?.toStringAsFixed(2) ?? 'Not available',
            subtitle: 'COTS/ha (this list)',
            icon: Icons.query_stats_rounded,
            accentColor: AdminColors.statPurple,
          ),
        ];

        if (maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final w in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
            ],
          );
        }
        if (maxWidth < 1100) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards
                .map((w) => SizedBox(width: (maxWidth - 28 - 12) / 2, child: w))
                .toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 12),
                  child: cards[i],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _filters(List<String> zoneOptions) {
    return _card(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Search records...',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: Color(0xFFF7F9FC),
              ),
            ),
          ),
          _drop(zoneOptions, _zone, (v) => setState(() => _zone = v!)),
          _drop(_statuses, _status, (v) => setState(() => _status = v!)),
          _drop(_risks, _risk, (v) => setState(() => _risk = v!)),
          OutlinedButton.icon(
            onPressed: _resetRecordFilters,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  Widget _drop(List<String> options, String value, ValueChanged<String?> onChanged) {
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AdminColors.headerTitle,
    );
    return SizedBox(
      width: 150,
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AdminColors.muted.withValues(alpha: 0.9)),
                style: labelStyle,
                selectedItemBuilder: (context) {
                  return options
                      .map(
                        (e) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            e,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: labelStyle,
                          ),
                        ),
                      )
                      .toList();
                },
                items: options
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e,
                        child: Text(
                          e,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AdminColors.headerTitle,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(
    List<AdminRecordTableRow> filtered,
    List<AdminRecordTableRow> pageRows,
    int start,
    int end,
    int pageCount,
  ) {
    final colMap = AdminDataTableColumn.widthsMap(_tableColumns);
    final tableW = AdminDataTableColumn.totalWidth(_tableColumns);
    return _card(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Monitoring Records',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.headerTitle,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: filtered.isEmpty
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Export ready for ${filtered.length} record(s).',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Export'),
                ),
              ],
            ),
          ),
          AdminDataTableScrollArea(
            tableWidth: tableW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDataTableHeader(columns: _tableColumns),
                for (final row in pageRows)
                  AdminDataTableClickableRow(
                    columnWidths: colMap,
                    onTap: () => _openRecordDetails(row),
                    cells: _recordRowCells(row),
                  ),
              ],
            ),
          ),
          AdminDataTablePaginationBar(
            summaryText: pageRows.isEmpty
                ? 'No records match your filters.'
                : 'Showing ${start + 1} to $end of ${filtered.length} records',
            pageIndex: _page,
            pageCount: pageCount,
            onPageSelected: (p) => setState(() => _page = p),
            trailing: AdminDataTableRowsPerPage(
              value: _rowsPerPage,
              onChanged: (v) => setState(() {
                _rowsPerPage = v ?? 10;
                _page = 0;
              }),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          ),
        ],
      ),
    );
  }

  List<TableCell> _recordRowCells(AdminRecordTableRow r) {
    final removed = r.removedQuantity != null ? '${r.removedQuantity}' : '—';
    final avgSize =
        r.averageSizeCm != null ? '${r.averageSizeCm!.toStringAsFixed(0)} cm' : '—';
    return [
      AdminDataTableCells.text('${r.number}', align: TextAlign.center),
      AdminDataTableCells.cell(
        child: Text(
          r.recordId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: AdminColors.statBlue,
            decoration: TextDecoration.underline,
            decorationColor: AdminColors.statBlue,
          ),
        ),
      ),
      AdminDataTableCells.text(r.activityType, align: TextAlign.center),
      AdminDataTableCells.text('${r.displayAiCount}', align: TextAlign.right),
      AdminDataTableCells.text(removed, align: TextAlign.right),
      AdminDataTableCells.text(avgSize, align: TextAlign.right),
      AdminDataTableCells.text(r.captureSource),
      AdminDataTableCells.text(r.zone, align: TextAlign.center),
      AdminDataTableCells.text(r.dateCaptured, style: AdminDateTimeTokens.inlineDateTimeTextStyle()),
      AdminDataTableCells.text(r.dateUploaded, style: AdminDateTimeTokens.inlineDateTimeTextStyle()),
      AdminDataTableCells.text('${r.confidencePercent}%', align: TextAlign.right),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(
          label: r.displayStatusLabel,
          foreground: _statusColor(r.displayStatusLabel),
          background: _statusColor(r.displayStatusLabel).withValues(alpha: 0.13),
        ),
      ),
      AdminDataTableCells.text(r.submittedBy),
      AdminDataTableCells.cell(
        align: TextAlign.right,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.viewOnly && r.displayStatus == 'Needs Review') ...[
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Reject submission',
                onPressed: () => _rejectSubmission(r),
                icon: const Icon(Icons.cancel_outlined, size: 20, color: AdminColors.statRed),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Confirm submission',
                onPressed: () => _confirmSubmission(r),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20, color: AdminColors.statGreen),
              ),
            ],
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'View details',
              onPressed: () => _openRecordDetails(r),
              icon: const Icon(Icons.visibility_outlined, size: 18, color: AdminColors.statBlue),
            ),
          ],
        ),
      ),
    ];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Accepted':
      case 'Verified':
        return AdminColors.statGreen;
      case 'Under Review':
      case 'Needs Review':
        return AdminColors.statYellow;
      case 'Rejected':
        return AdminColors.statRed;
      default:
        return AdminColors.statBlue;
    }
  }

  Widget _bottomCharts(List<AdminRecordTableRow> rows) {
    final topZones = _topZonesByDensity(rows);

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 720;
        final left = _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Records by Status',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              const SizedBox(height: 8),
              _recordsByStatusChart(rows),
            ],
          ),
        );
        final right = _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Zones by Average Density',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              const SizedBox(height: 12),
              if (topZones.isEmpty)
                const Text('No zone data yet.', style: TextStyle(color: AdminColors.muted))
              else
                for (final z in topZones)
                  _Bar(
                    z.$1,
                    z.$2,
                    switch (z.$1.hashCode % 4) {
                      0 => AdminColors.statRed,
                      1 => const Color(0xFFFF7043),
                      2 => AdminColors.statYellow,
                      _ => AdminColors.statGreen,
                    },
                  ),
            ],
          ),
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              left,
              const SizedBox(height: 14),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  List<(String, double)> _topZonesByDensity(List<AdminRecordTableRow> rows) {
    final totals = <String, (double sum, int count)>{};
    for (final r in rows) {
      final density = r.density;
      if (density == null) continue;
      final current = totals[r.zone] ?? (0, 0);
      totals[r.zone] = (current.$1 + density, current.$2 + 1);
    }
    final averages = totals.entries
        .map((e) => (e.key, e.value.$1 / e.value.$2))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return averages.take(5).toList();
  }

  /// Pie is inset so fl_chart does not clip the ring; legend is spaced to the right.
  Widget _recordsByStatusChart(List<AdminRecordTableRow> rows) {
    const pieSide = 128.0;
    const pieInset = 14.0;
    const ringRadius = 30.0;
    const centerHole = 36.0;

    final (v, n, r) = _statusCounts(rows);
    final total = v + n + r;
    String legendCountPct(int count) {
      if (total == 0) return '0 (0.0%)';
      final p = 100 * count / total;
      return '$count (${p.toStringAsFixed(1)}%)';
    }

    final sections = <PieChartSectionData>[
      if (v > 0)
        PieChartSectionData(
          value: v.toDouble(),
          color: AdminColors.statGreen,
          title: '',
          radius: ringRadius,
        ),
      if (n > 0)
        PieChartSectionData(
          value: n.toDouble(),
          color: AdminColors.statYellow,
          title: '',
          radius: ringRadius,
        ),
      if (r > 0)
        PieChartSectionData(
          value: r.toDouble(),
          color: AdminColors.statRed,
          title: '',
          radius: ringRadius,
        ),
    ];

    if (sections.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('No records in this list.', style: TextStyle(color: AdminColors.muted)),
        ),
      );
    }

    return SizedBox(
      height: 188,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: pieSide,
              height: pieSide,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(pieInset),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: centerHole,
                        sectionsSpace: 2,
                        sections: sections,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Legend('Accepted', legendCountPct(v), AdminColors.statGreen),
                    const SizedBox(height: 10),
                    _Legend('Under Review', legendCountPct(n), AdminColors.statYellow),
                    const SizedBox(height: 10),
                    _Legend('Rejected', legendCountPct(r), AdminColors.statRed),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
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
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AdminColors.headerTitle,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AdminColors.muted.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final widthFactor = (value / 100).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 12,
                value: widthFactor,
                backgroundColor: const Color(0xFFEFF3F8),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value.toStringAsFixed(2),
                textAlign: TextAlign.right,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
