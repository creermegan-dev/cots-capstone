import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../layout/admin_breakpoints.dart';
import '../models/admin_record_table_row.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_stat_card.dart';
import 'admin_record_details_screen.dart';

class AdminRecordsSubmissionsScreen extends StatefulWidget {
  const AdminRecordsSubmissionsScreen({super.key});

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
    AdminDataTableColumn('Record ID', 124),
    AdminDataTableColumn('Zone', 84, headerAlign: TextAlign.center),
    AdminDataTableColumn('Date & Time', 176),
    AdminDataTableColumn('COTS Count', 92, headerAlign: TextAlign.right),
    AdminDataTableColumn('Density (COTS/ha)', 112, headerAlign: TextAlign.right),
    AdminDataTableColumn('Risk Level', 104, headerAlign: TextAlign.center),
    AdminDataTableColumn('Status', 100, headerAlign: TextAlign.center),
    AdminDataTableColumn('Submitted By', 148),
    AdminDataTableColumn('Actions', 124, headerAlign: TextAlign.right),
  ];

  static const _zones = ['All Zones', 'Zone A', 'Zone B', 'Zone C', 'Zone D'];
  static const _statuses = ['All Status', 'Verified', 'Needs Review', 'Rejected'];
  static const _risks = ['All Risk Levels', 'High', 'Moderate', 'Low'];

  /// Demo rows: status is derived from [confidencePercent] unless [adminConfirmed].
  final List<AdminRecordTableRow> _rows = _seedRows();

  static List<AdminRecordTableRow> _seedRows() => [
        const AdminRecordTableRow(1, 'REC-2026-0156', 'Zone A', 'May 18, 2026 09:15 AM', 67, 78.40, 'High', 'Juan Dela Cruz', 92),
        const AdminRecordTableRow(2, 'REC-2026-0155', 'Zone B', 'May 18, 2026 08:45 AM', 51, 55.40, 'High', 'Pedro Reyes', 71),
        const AdminRecordTableRow(3, 'REC-2026-0154', 'Zone C', 'May 17, 2026 04:30 PM', 28, 41.75, 'Moderate', 'Maria Santos', 88),
        const AdminRecordTableRow(4, 'REC-2026-0153', 'Zone D', 'May 17, 2026 11:20 AM', 46, 72.10, 'High', 'Luis Mendoza', 60),
        const AdminRecordTableRow(5, 'REC-2026-0152', 'Zone E', 'May 16, 2026 10:10 AM', 10, 8.30, 'Low', 'Ana Garcia', 44),
        const AdminRecordTableRow(6, 'REC-2026-0151', 'Zone F', 'May 16, 2026 09:10 AM', 15, 22.60, 'Moderate', 'Jose Villanueva', 84),
        const AdminRecordTableRow(7, 'REC-2026-0150', 'Zone G', 'May 15, 2026 09:25 AM', 3, 6.20, 'Low', 'Mark Antonio', 95),
        const AdminRecordTableRow(8, 'REC-2026-0149', 'Zone H', 'May 15, 2026 02:15 PM', 4, 4.80, 'Low', 'Rica Bautista', 63),
        const AdminRecordTableRow(9, 'REC-2026-0148', 'Zone I', 'May 14, 2026 05:50 AM', 37, 60.90, 'High', 'Juan Dela Cruz', 59),
        const AdminRecordTableRow(10, 'REC-2026-0147', 'Zone J', 'May 14, 2026 01:40 PM', 12, 19.30, 'Moderate', 'Pedro Reyes', 86),
      ];

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
      _zone = _zones.first;
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
        content: Text('Records refreshed (demo).'),
      ),
    );
  }

  void _openRecordDetails(AdminRecordTableRow row) async {
    final returned = await Navigator.of(context).push<AdminRecordTableRow?>(
      MaterialPageRoute<AdminRecordTableRow?>(
        builder: (_) => AdminRecordDetailsScreen(row: row),
      ),
    );
    if (!mounted || returned == null) return;
    setState(() {
      final i = _rows.indexWhere((r) => r.recordId == returned.recordId);
      if (i >= 0) _rows[i] = returned;
    });
  }

  void _confirmSubmission(AdminRecordTableRow row) {
    setState(() {
      final i = _rows.indexWhere((r) => r.recordId == row.recordId);
      if (i >= 0) _rows[i] = _rows[i].copyWith(adminConfirmed: true);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${row.recordId} marked verified after admin confirmation.'),
      ),
    );
  }

  void _rejectSubmission(AdminRecordTableRow row) {
    setState(() {
      final i = _rows.indexWhere((r) => r.recordId == row.recordId);
      if (i >= 0) _rows[i] = _rows[i].copyWith(adminRejected: true);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('${row.recordId} marked rejected after admin review.'),
      ),
    );
  }

  (int verified, int needsReview, int rejected) _statusCounts() {
    var verified = 0;
    var needsReview = 0;
    var rejected = 0;
    for (final r in _rows) {
      switch (r.displayStatus) {
        case 'Verified':
          verified++;
          break;
        case 'Needs Review':
          needsReview++;
          break;
        case 'Rejected':
          rejected++;
          break;
      }
    }
    return (verified, needsReview, rejected);
  }

  List<AdminRecordTableRow> get _filteredRows {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _rows.where((r) {
      final byQuery = q.isEmpty ||
          r.recordId.toLowerCase().contains(q) ||
          r.zone.toLowerCase().contains(q) ||
          r.submittedBy.toLowerCase().contains(q);
      final byZone = _zone == 'All Zones' || r.zone == _zone;
      final byStatus = _status == 'All Status' || r.displayStatus == _status;
      final byRisk = _risk == 'All Risk Levels' || r.risk == _risk;
      return byQuery && byZone && byStatus && byRisk;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRows;
    final pageCount = (filtered.length / _rowsPerPage).ceil().clamp(1, 999);
    _page = _page.clamp(0, pageCount - 1);
    final start = _page * _rowsPerPage;
    final pageRows = filtered.skip(start).take(_rowsPerPage).toList();
    final end = pageRows.isEmpty ? 0 : start + pageRows.length;

    final pagePad = AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);

    return FadeTransition(
      opacity: _fade,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pagePad.left, 22, pagePad.right, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminDashboardHeader(
              title: 'Records / Submissions',
              subtitle: 'View and manage all monitoring records and submissions.',
              onRefreshTap: _onRecordsHeaderRefresh,
            ),
            const SizedBox(height: 22),
            _stats(),
            const SizedBox(height: 20),
            _filters(),
            const SizedBox(height: 14),
            _table(filtered, pageRows, start, end, pageCount),
            const SizedBox(height: 14),
            _bottomCharts(),
          ],
        ),
      ),
    );
  }

  Widget _stats() {
    return LayoutBuilder(
      builder: (context, c) {
        final maxWidth = c.maxWidth;
        final total = _rows.length;
        final (nVerified, nReview, nRejected) = _statusCounts();
        double rowPct(int count) => total == 0 ? 0.0 : (100 * count / total);
        final avgDensity =
            total == 0 ? 0.0 : _rows.map((e) => e.density).reduce((a, b) => a + b) / total;

        final cards = <Widget>[
          AdminStatCard(
            title: 'Total Records',
            value: '$total',
            subtitle: 'Loaded submissions (demo)',
            icon: Icons.inventory_2_outlined,
            accentColor: AdminColors.statBlue,
            selected: _status == 'All Status',
            onTap: () => setState(() => _status = 'All Status'),
          ),
          AdminStatCard(
            title: 'Verified Records',
            value: '$nVerified',
            subtitle: '${rowPct(nVerified).toStringAsFixed(1)}% · AI ≥85% or admin confirmed',
            icon: Icons.verified_rounded,
            accentColor: AdminColors.statGreen,
            selected: _status == 'Verified',
            onTap: () => setState(() {
              _status = _status == 'Verified' ? 'All Status' : 'Verified';
            }),
          ),
          AdminStatCard(
            title: 'Needs Review',
            value: '$nReview',
            subtitle: '${rowPct(nReview).toStringAsFixed(1)}% · 60–84% confidence',
            icon: Icons.warning_amber_rounded,
            accentColor: AdminColors.statYellow,
            selected: _status == 'Needs Review',
            onTap: () => setState(() {
              _status = _status == 'Needs Review' ? 'All Status' : 'Needs Review';
            }),
          ),
          AdminStatCard(
            title: 'Rejected Records',
            value: '$nRejected',
            subtitle: '${rowPct(nRejected).toStringAsFixed(1)}% · below 60% confidence',
            icon: Icons.cancel_outlined,
            accentColor: AdminColors.statRed,
            selected: _status == 'Rejected',
            onTap: () => setState(() {
              _status = _status == 'Rejected' ? 'All Status' : 'Rejected';
            }),
          ),
          AdminStatCard(
            title: 'Average Density',
            value: avgDensity.toStringAsFixed(2),
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

  Widget _filters() {
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
          _drop(_zones, _zone, (v) => setState(() => _zone = v!)),
          _drop(_statuses, _status, (v) => setState(() => _status = v!)),
          _drop(_risks, _risk, (v) => setState(() => _risk = v!)),
          OutlinedButton.icon(
            onPressed: _resetRecordFilters,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset'),
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
      AdminDataTableCells.text(r.zone, align: TextAlign.center),
      AdminDataTableCells.text(r.dateTime, style: AdminDateTimeTokens.inlineDateTimeTextStyle()),
      AdminDataTableCells.text('${r.cotsCount}', align: TextAlign.right),
      AdminDataTableCells.text(
        r.density.toStringAsFixed(2),
        align: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(label: r.risk, foreground: _riskColor(r.risk), background: _riskColor(r.risk).withValues(alpha: 0.13)),
      ),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(
          label: r.displayStatus,
          foreground: _statusColor(r.displayStatus),
          background: _statusColor(r.displayStatus).withValues(alpha: 0.13),
        ),
      ),
      AdminDataTableCells.text(r.submittedBy),
      AdminDataTableCells.cell(
        align: TextAlign.right,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r.displayStatus == 'Needs Review') ...[
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Reject submission (admin)',
                onPressed: () => _rejectSubmission(r),
                icon: const Icon(Icons.cancel_outlined, size: 20, color: AdminColors.statRed),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Confirm submission (admin)',
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

  Color _riskColor(String risk) {
    switch (risk) {
      case 'High':
        return AdminColors.statRed;
      case 'Moderate':
        return AdminColors.statYellow;
      default:
        return AdminColors.statGreen;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Verified':
        return AdminColors.statGreen;
      case 'Needs Review':
        return AdminColors.statYellow;
      case 'Rejected':
        return AdminColors.statRed;
      default:
        return AdminColors.statBlue;
    }
  }

  Widget _bottomCharts() {
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
              _recordsByStatusChart(),
            ],
          ),
        );
        final right = _card(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top Zones by Average Density',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              SizedBox(height: 12),
              _Bar('Zone A', 78.40, AdminColors.statRed),
              _Bar('Zone D', 72.10, Color(0xFFFF7043)),
              _Bar('Zone I', 60.90, AdminColors.statYellow),
              _Bar('Zone B', 55.40, Color(0xFFFFCA28)),
              _Bar('Zone C', 41.75, AdminColors.statGreen),
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

  /// Pie is inset so fl_chart does not clip the ring; legend is spaced to the right.
  Widget _recordsByStatusChart() {
    const pieSide = 128.0;
    const pieInset = 14.0;
    const ringRadius = 30.0;
    const centerHole = 36.0;

    final (v, n, r) = _statusCounts();
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
                    _Legend('Verified', legendCountPct(v), AdminColors.statGreen),
                    const SizedBox(height: 10),
                    _Legend('Needs Review', legendCountPct(n), AdminColors.statYellow),
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
