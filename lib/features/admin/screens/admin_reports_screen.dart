import 'package:flutter/material.dart';

import '../../../services/scan_record_repository.dart';
import '../../../widgets/cots_loading_skeleton.dart';
import '../models/admin_record_table_row.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_data_table.dart';
import 'admin_record_details_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, this.recordsStream});

  final Stream<List<AdminRecordTableRow>>? recordsStream;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  final _searchCtrl = TextEditingController();
  String _type = 'All Types';
  String _status = 'All Status';
  String _confidence = 'All Confidence Levels';
  String _zone = 'All Zones';
  int _page = 0;
  int _rowsPerPage = 10;

  /// Last-used summary stat card (0–4); `null` if filters were changed manually and no preset matches.
  int? _selectedStatIndex;

  late Stream<List<AdminRecordTableRow>> _recordsStream;
  int _refreshGeneration = 0;

  void _onReportsRefresh() {
    if (!mounted) return;
    _recordsStream =
        widget.recordsStream ?? ScanRecordRepository.watchAdminTableRows();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Reports refreshed.'),
      ),
    );
    setState(() => _refreshGeneration++);
  }

  @override
  void initState() {
    super.initState();
    _selectedStatIndex = 0;
    _recordsStream =
        widget.recordsStream ?? ScanRecordRepository.watchAdminTableRows();
  }

  static const _types = [
    'All Types',
    'COTS Detection',
    'Citizen Removal Record',
    'Follow-up Monitoring',
  ];
  static const _statuses = [
    'All Status',
    'Accepted',
    'Under Review',
    'Rejected'
  ];
  static const _confidences = [
    'All Confidence Levels',
    'High',
    'Medium',
    'Low'
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  _RepStatus _statusOf(_ReportRow r) => r.status;

  String _reviewOf(_ReportRow r) => r.reviewDetails;

  List<_ReportRow> _filtered(List<_ReportRow> rows) {
    final q = _searchCtrl.text.trim().toLowerCase();
    return rows.where((r) {
      final byQ = q.isEmpty ||
          r.id.toLowerCase().contains(q) ||
          r.submittedBy.toLowerCase().contains(q) ||
          r.zone.toLowerCase().contains(q);
      final byT = _type == 'All Types' || r.typeLabel == _type;
      final byS = _status == 'All Status' || _statusOf(r).label == _status;
      final byC = _confidence == 'All Confidence Levels' ||
          r.confidenceBand == _confidence;
      final byZ = _zone == 'All Zones' || r.zone == _zone;
      return byQ && byT && byS && byC && byZ;
    }).toList();
  }

  int? _matchingStatCardIndex() {
    if (_type == 'All Types' &&
        _status == 'All Status' &&
        _confidence == 'All Confidence Levels') {
      return 0;
    }
    if (_type == 'COTS Detection' &&
        _status == 'Under Review' &&
        _confidence == 'Medium') {
      return 1;
    }
    if (_type == 'All Types' &&
        _status == 'Accepted' &&
        _confidence == 'High') {
      return 2;
    }
    if (_type == 'All Types' && _status == 'Rejected' && _confidence == 'Low') {
      return 4;
    }
    return null;
  }

  int? _syncedStatSelection() {
    if (_searchCtrl.text.trim().isNotEmpty || _zone != 'All Zones') {
      return null;
    }
    return _matchingStatCardIndex();
  }

  void _applyStatQuickFilter(int index) {
    setState(() {
      _page = 0;
      _selectedStatIndex = index;
      switch (index) {
        case 0:
          _type = 'All Types';
          _status = 'All Status';
          _confidence = 'All Confidence Levels';
          break;
        case 1:
          _type = 'COTS Detection';
          _status = 'Under Review';
          _confidence = 'Medium';
          break;
        case 2:
          _type = 'All Types';
          _status = 'Accepted';
          _confidence = 'High';
          break;
        case 3:
          _type = 'All Types';
          _status = 'All Status';
          _confidence = 'All Confidence Levels';
          break;
        case 4:
          _type = 'All Types';
          _status = 'Rejected';
          _confidence = 'Low';
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminRecordTableRow>>(
      key: ValueKey<int>(_refreshGeneration),
      stream: _recordsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _loadError(snapshot.error);
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: CotsLoadingSkeleton(
              layout: CotsSkeletonLayout.table,
              label: 'Loading reports from Firebase',
            ),
          );
        }
        return _buildReports(
          snapshot.data!.map(_ReportRow.fromRecord).toList(),
        );
      },
    );
  }

  Widget _buildReports(List<_ReportRow> rows) {
    final zones = <String>{for (final row in rows) row.zone}.toList()..sort();
    final zoneOptions = ['All Zones', ...zones];
    if (!zoneOptions.contains(_zone)) {
      _zone = 'All Zones';
    }
    final filtered = _filtered(rows);
    final pageCount = (filtered.length / _rowsPerPage).ceil().clamp(1, 999);
    _page = _page.clamp(0, pageCount - 1);
    final start = _page * _rowsPerPage;
    final pageRows = filtered.skip(start).take(_rowsPerPage).toList();
    final end = pageRows.isEmpty ? 0 : start + pageRows.length;

    return SingleChildScrollView(
      key: ValueKey<int>(_refreshGeneration),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(zoneOptions),
          const SizedBox(height: 18),
          _statCards(rows),
          const SizedBox(height: 18),
          _filterBar(),
          const SizedBox(height: 14),
          _tableCard(pageRows, start, end, filtered.length, pageCount),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 1100) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _confidenceGuide(),
                    const SizedBox(height: 14),
                    _statusGuide(),
                    const SizedBox(height: 14),
                    _systemNotice(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _confidenceGuide()),
                  const SizedBox(width: 14),
                  Expanded(child: _statusGuide()),
                  const SizedBox(width: 14),
                  Expanded(child: _systemNotice()),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _loadError(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 42, color: AdminColors.statRed),
              const SizedBox(height: 12),
              const Text('Could not load reports',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AdminColors.muted)),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _onReportsRefresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(List<String> zoneOptions) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 780;
        final actions = [
          OutlinedButton.icon(
            onPressed: () {},
            icon: AdminDateTimeTokens.dateChipIcon(),
            label: Text(AdminDateTimeTokens.currentDateRangeLabel,
                style: AdminDateTimeTokens.dateRangeChipTextStyle),
            style: AdminDateTimeTokens.dateRangeOutlinedButtonStyle(),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _onReportsRefresh,
            icon: AdminDateTimeTokens.refreshIcon,
            label: const Text('Refresh',
                style: AdminDateTimeTokens.refreshChipTextStyle),
            style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: narrow ? double.infinity : 140,
            child: _dropdownShell(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _zone,
                  isExpanded: true,
                  icon: const Icon(Icons.filter_alt_outlined, size: 20),
                  items: zoneOptions
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _zone = v ?? 'All Zones';
                    _page = 0;
                    _selectedStatIndex = _syncedStatSelection();
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Export PDF'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.statRed,
              side: BorderSide(
                  color: AdminColors.statRed.withValues(alpha: 0.35)),
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.table_view_outlined, size: 18),
            label: const Text('Export Excel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AdminColors.statGreen,
              side: BorderSide(
                  color: AdminColors.statGreen.withValues(alpha: 0.35)),
              backgroundColor: Colors.white,
            ),
          ),
        ];
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Reports',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.headerTitle)),
              const SizedBox(height: 8),
              Text(
                'All system reports submitted by users. Detection reports are reviewed by admin based on confidence level.',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.muted.withValues(alpha: 0.95),
                    height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reports',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AdminColors.headerTitle)),
                  const SizedBox(height: 8),
                  Text(
                    'All system reports submitted by users. Detection reports are reviewed by admin based on confidence level.',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.muted.withValues(alpha: 0.95),
                        height: 1.4),
                  ),
                ],
              ),
            ),
            ...actions,
          ],
        );
      },
    );
  }

  Widget _dropdownShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _statCards(List<_ReportRow> rows) {
    final detectionCount = rows.fold<int>(0, (sum, row) => sum + row.cotsCount);
    final underReview =
        rows.where((r) => r.status == _RepStatus.forReview).length;
    final accepted =
        rows.where((r) => r.status == _RepStatus.autoApproved).length;
    final zoneCount =
        rows.map((r) => r.zone).where((z) => z != 'Unassigned').toSet().length;
    final rejected = rows.where((r) => r.status == _RepStatus.rejected).length;
    final specs = [
      _StatSpec(
          0,
          Icons.pest_control_outlined,
          'Total Detections',
          '$detectionCount',
          'COTS across ${rows.length} reports',
          AdminColors.statBlue),
      _StatSpec(1, Icons.rate_review_outlined, 'Pending Review', '$underReview',
          'Reports needing expert review', AdminColors.statGreen),
      _StatSpec(2, Icons.check_circle_outline_rounded, 'Accepted', '$accepted',
          'Verified or policy-accepted', AdminColors.statPurple),
      _StatSpec(3, Icons.map_outlined, 'Reef Zone Summary', '$zoneCount',
          'Zones with reports', AdminColors.statYellow),
      _StatSpec(4, Icons.cancel_outlined, 'Rejected', '$rejected',
          'Rejected or retake required', AdminColors.statRed),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 1100) {
          final w = c.maxWidth < 520 ? c.maxWidth : (c.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: specs
                .map(
                  (s) => SizedBox(
                    width: w,
                    child: _StatCard(
                      spec: s,
                      selected: _selectedStatIndex == s.index,
                      onTap: () => _applyStatQuickFilter(s.index),
                    ),
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  spec: specs[i],
                  selected: _selectedStatIndex == specs[i].index,
                  onTap: () => _applyStatQuickFilter(specs[i].index),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _filterBar() {
    return _card(
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 900;
          final children = <Widget>[
            SizedBox(
              width: narrow ? double.infinity : 220,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {
                  _page = 0;
                  _selectedStatIndex = _syncedStatSelection();
                }),
                decoration: const InputDecoration(
                  hintText: 'Search reports...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: Color(0xFFF7F9FC),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 150,
              child: _dropdownShell(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _type,
                    isExpanded: true,
                    items: _types
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _type = v ?? 'All Types';
                      _page = 0;
                      _selectedStatIndex = _syncedStatSelection();
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 150,
              child: _dropdownShell(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _status,
                    isExpanded: true,
                    items: _statuses
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _status = v ?? 'All Status';
                      _page = 0;
                      _selectedStatIndex = _syncedStatSelection();
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 190,
              child: _dropdownShell(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _confidence,
                    isExpanded: true,
                    items: _confidences
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _confidence = v ?? 'All Confidence Levels';
                      _page = 0;
                      _selectedStatIndex = _syncedStatSelection();
                    }),
                  ),
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: AdminDateTimeTokens.dateChipIcon(
                  icon: Icons.date_range_outlined),
              label: const Text('Select date range',
                  style: AdminDateTimeTokens.dateRangeChipTextStyle),
              style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _page = 0),
              icon: const Icon(Icons.filter_list_rounded, size: 18),
              label: const Text('Filter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AdminColors.statBlue,
                side: BorderSide(
                    color: AdminColors.statBlue.withValues(alpha: 0.35)),
              ),
            ),
          ];
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  children[i],
                ],
              ],
            );
          }
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          );
        },
      ),
    );
  }

  Widget _tableCard(List<_ReportRow> pageRows, int start, int end,
      int displayTotal, int pageCount) {
    final summaryText = pageRows.isEmpty
        ? 'No reports match your filters.'
        : 'Showing ${start + 1} to $end of $displayTotal reports';

    return _card(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDataTableScrollArea(
            tableWidth: _ReportTableDim.totalWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TableHeader(),
                for (final r in pageRows)
                  _ReportTableRow(
                    row: r,
                    displayStatus: _statusOf(r),
                    displayReview: _reviewOf(r),
                    onOpenDetails: () => _openReportForRow(r),
                    onReview: _statusOf(r) == _RepStatus.forReview
                        ? () => _openReportForRow(r)
                        : null,
                  ),
              ],
            ),
          ),
          AdminDataTablePaginationBar(
            summaryText: summaryText,
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
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          ),
        ],
      ),
    );
  }

  Widget _confidenceGuide() {
    return _infoPanel(
      title: 'Confidence Level Guide',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _guideLine(AdminColors.statGreen, 'High (80–100%)',
              'Accepted by the confidence policy.'),
          const SizedBox(height: 10),
          _guideLine(AdminColors.statYellow, 'Medium (20–79%)',
              'Requires expert verification.'),
          const SizedBox(height: 10),
          _guideLine(AdminColors.statRed, 'Low (<20%)',
              'Retake or rejection required.'),
        ],
      ),
    );
  }

  Widget _statusGuide() {
    return _infoPanel(
      title: 'Status Guide',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _guideLine(AdminColors.statGreen, 'Accepted',
              'Meets policy or was verified by an expert.'),
          const SizedBox(height: 10),
          _guideLine(AdminColors.statYellow, 'Under Review',
              'Queued for expert verification.'),
          const SizedBox(height: 10),
          _guideLine(AdminColors.statRed, 'Rejected',
              'Did not meet minimum confidence or policy.'),
        ],
      ),
    );
  }

  Widget _systemNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.statBlue.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AdminColors.statBlue.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              const Text('System Notice',
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AdminColors.headerTitle)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'All types of reports are listed here. Only detection reports go through admin review based on confidence level.',
            style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AdminColors.headerTitle.withValues(alpha: 0.88)),
          ),
          const SizedBox(height: 12),
          _bullet('High (80–100%) → Accepted'),
          _bullet('Medium (20–79%) → Expert verification'),
          _bullet('Low (<20%) → Retake or rejected'),
        ],
      ),
    );
  }

  Widget _bullet(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AdminColors.statBlue.withValues(alpha: 0.8))),
          Expanded(
              child: Text(t,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _guideLine(Color dot, String title, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AdminColors.headerTitle.withValues(alpha: 0.88),
                  decoration: TextDecoration.none),
              children: [
                TextSpan(
                    text: '$title — ',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                TextSpan(
                    text: text,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoPanel({required String title, required Widget child}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AdminColors.headerTitle)),
          const SizedBox(height: 12),
          child,
        ],
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
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }

  Future<void> _openReportForRow(_ReportRow report) async {
    await Navigator.of(context).push<AdminRecordTableRow?>(
      MaterialPageRoute<AdminRecordTableRow?>(
        builder: (_) => AdminRecordDetailsScreen(row: report.source),
      ),
    );
  }
}

class _StatSpec {
  const _StatSpec(
      this.index, this.icon, this.title, this.value, this.subtitle, this.color);
  final int index;
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
}

class _StatCard extends StatefulWidget {
  const _StatCard(
      {required this.spec, required this.selected, required this.onTap});
  final _StatSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    final accent = s.color;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: 'Apply table filter: ${s.title}',
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            hoverColor: accent.withValues(alpha: 0.06),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: widget.selected
                    ? accent.withValues(alpha: 0.06)
                    : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.selected
                      ? accent.withValues(alpha: 0.55)
                      : Colors.black.withValues(alpha: _hover ? 0.1 : 0.06),
                  width: widget.selected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: _hover || widget.selected ? 0.1 : 0.06),
                    blurRadius: _hover || widget.selected ? 22 : 16,
                    offset: Offset(0, _hover || widget.selected ? 8 : 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(s.icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: AdminColors.headerTitle)),
                        Text(s.value,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: AdminColors.headerTitle)),
                        Text(s.subtitle,
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    AdminColors.muted.withValues(alpha: 0.9))),
                      ],
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

enum _ReportType { cotsDetection, citizenRemoval, followUp }

extension on _ReportType {
  String get label => switch (this) {
        _ReportType.cotsDetection => 'COTS Detection',
        _ReportType.citizenRemoval => 'Citizen Removal Record',
        _ReportType.followUp => 'Follow-up Monitoring',
      };

  IconData get icon => switch (this) {
        _ReportType.cotsDetection => Icons.biotech_outlined,
        _ReportType.citizenRemoval => Icons.cleaning_services_outlined,
        _ReportType.followUp => Icons.refresh_rounded,
      };

  Color get color => switch (this) {
        _ReportType.cotsDetection => AdminColors.statBlue,
        _ReportType.citizenRemoval => AdminColors.statGreen,
        _ReportType.followUp => AdminColors.statPurple,
      };
}

enum _RepStatus { autoApproved, forReview, rejected }

extension on _RepStatus {
  String get label => switch (this) {
        _RepStatus.autoApproved => 'Accepted',
        _RepStatus.forReview => 'Under Review',
        _RepStatus.rejected => 'Rejected',
      };

  (Color fg, Color bg) get colors => switch (this) {
        _RepStatus.autoApproved => (
            AdminColors.statGreen,
            AdminColors.statGreen.withValues(alpha: 0.14)
          ),
        _RepStatus.forReview => (
            const Color(0xFFE65100),
            const Color(0xFFFFF3E0)
          ),
        _RepStatus.rejected => (
            AdminColors.statRed,
            AdminColors.statRed.withValues(alpha: 0.12)
          ),
      };
}

class _ReportRow {
  const _ReportRow(
    this.id,
    this.type,
    this.submittedBy,
    this.zone,
    this.submittedOn,
    this.confidencePct,
    this.status,
    this.reviewDetails,
    this.cotsCount,
    this.source,
  );

  factory _ReportRow.fromRecord(AdminRecordTableRow record) {
    final activity = record.activityType.toLowerCase();
    final type = activity.contains('follow')
        ? _ReportType.followUp
        : activity.contains('removal') || record.removedQuantity != null
            ? _ReportType.citizenRemoval
            : _ReportType.cotsDetection;
    final status = switch (record.displayStatusLabel) {
      'Rejected' => _RepStatus.rejected,
      'Under Review' => _RepStatus.forReview,
      _ => _RepStatus.autoApproved,
    };
    final review = switch (status) {
      _RepStatus.rejected =>
        'Rejected by an expert or below the retake threshold.',
      _RepStatus.forReview => 'Waiting for expert verification.',
      _RepStatus.autoApproved => record.adminConfirmed
          ? 'Verified by an expert.'
          : 'Accepted by the confidence policy.',
    };
    return _ReportRow(
      record.recordId,
      type,
      record.submittedBy,
      record.zone,
      record.dateUploaded.isNotEmpty ? record.dateUploaded : record.dateTime,
      record.confidencePercent,
      status,
      review,
      record.displayAiCount,
      record,
    );
  }

  final String id;
  final _ReportType type;
  final String submittedBy;
  final String zone;
  final String submittedOn;
  final int confidencePct;
  final _RepStatus status;
  final String reviewDetails;
  final int cotsCount;
  final AdminRecordTableRow source;

  String get typeLabel => type.label;

  String get confidenceBand {
    if (confidencePct >= 80) return 'High';
    if (confidencePct >= 20) return 'Medium';
    return 'Low';
  }

  Color get confidenceColor {
    if (confidencePct >= 80) return AdminColors.statGreen;
    if (confidencePct >= 20) return AdminColors.statYellow;
    return AdminColors.statRed;
  }
}

/// Rigid table geometry: identical [Table] + [columnWidths] for header and every body row.
abstract final class _ReportTableDim {
  static double get rowHeight => AdminDataTableTokens.rowHeight;
  static EdgeInsets get cellPadding => AdminDataTableTokens.cellPadding;

  static const double reportId = 112;
  static const double type = 148;
  static const double submittedBy = 124;
  static const double zone = 92;
  static const double submittedOn = 168;
  static const double confidence = 120;
  static const double status = 124;
  static const double reviewDetails = 292;
  static const double actions = 136;
  static const double menu = 44;

  static double get totalWidth =>
      reportId +
      type +
      submittedBy +
      zone +
      submittedOn +
      confidence +
      status +
      reviewDetails +
      actions +
      menu;

  static Map<int, TableColumnWidth> get columnWidths => {
        0: const FixedColumnWidth(reportId),
        1: const FixedColumnWidth(type),
        2: const FixedColumnWidth(submittedBy),
        3: const FixedColumnWidth(zone),
        4: const FixedColumnWidth(submittedOn),
        5: const FixedColumnWidth(confidence),
        6: const FixedColumnWidth(status),
        7: const FixedColumnWidth(reviewDetails),
        8: const FixedColumnWidth(actions),
        9: const FixedColumnWidth(menu),
      };

  static TextStyle get headerTextStyle => AdminDataTableTokens.headerTextStyle;
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Table(
          columnWidths: _ReportTableDim.columnWidths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                _headerCell('Report ID', TextAlign.left),
                _headerCell('Type', TextAlign.left),
                _headerCell('Submitted By', TextAlign.left),
                _headerCell('Zone', TextAlign.left),
                _headerCell('Submitted On', TextAlign.left),
                _headerCell('Confidence', TextAlign.left),
                _headerCell('Status', TextAlign.left),
                _headerCell('Review Details', TextAlign.left),
                _headerCell('Actions', TextAlign.right),
                _headerCell('', TextAlign.center),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static TableCell _headerCell(String label, TextAlign align) {
    return TableCell(
      child: SizedBox(
        height: _ReportTableDim.rowHeight,
        child: Padding(
          padding: _ReportTableDim.cellPadding,
          child: Align(
            alignment: _alignFromTextAlign(align),
            child: Text(label,
                textAlign: align, style: _ReportTableDim.headerTextStyle),
          ),
        ),
      ),
    );
  }

  static Alignment _alignFromTextAlign(TextAlign a) {
    return switch (a) {
      TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };
  }
}

class _ReportTableRow extends StatefulWidget {
  const _ReportTableRow({
    required this.row,
    required this.displayStatus,
    required this.displayReview,
    required this.onOpenDetails,
    this.onReview,
  });
  final _ReportRow row;
  final _RepStatus displayStatus;
  final String displayReview;
  final VoidCallback onOpenDetails;
  final VoidCallback? onReview;

  @override
  State<_ReportTableRow> createState() => _ReportTableRowState();
}

class _ReportTableRowState extends State<_ReportTableRow> {
  bool _hover = false;

  Color _zoneColor(String z) {
    switch (z) {
      case 'Zone A':
        return AdminColors.statRed;
      case 'Zone B':
        return AdminColors.statGreen;
      case 'Zone C':
        return AdminColors.statYellow;
      case 'Zone D':
        return AdminColors.statPurple;
      default:
        return AdminColors.statBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    final disp = widget.displayStatus;
    final st = disp.colors;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onOpenDetails,
              borderRadius: BorderRadius.circular(10),
              hoverColor: const Color(0xFFF8FBFF).withValues(alpha: 0.75),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: _hover ? const Color(0xFFF8FBFF) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          Colors.black.withValues(alpha: _hover ? 0.1 : 0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Table(
                  columnWidths: _ReportTableDim.columnWidths,
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      children: [
                        _bodyCell(
                          Row(
                            children: [
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EEF5),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.image_outlined,
                                    size: 16, color: AdminColors.statBlue),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: InkWell(
                                  onTap: widget.onOpenDetails,
                                  child: Text(
                                    r.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      color: AdminColors.statBlue,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AdminColors.statBlue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          align: Alignment.centerLeft,
                        ),
                        _bodyCell(
                          Row(
                            children: [
                              Icon(r.type.icon, size: 18, color: r.type.color),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  r.typeLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                      color: r.type.color),
                                ),
                              ),
                            ],
                          ),
                          align: Alignment.centerLeft,
                        ),
                        _bodyCell(
                          Text(
                            r.submittedBy,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          align: Alignment.centerLeft,
                        ),
                        _bodyCell(
                          _badge(r.zone, _zoneColor(r.zone),
                              _zoneColor(r.zone).withValues(alpha: 0.12)),
                          align: Alignment.centerLeft,
                        ),
                        _bodyCell(
                          Text(
                            r.submittedOn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdminDateTimeTokens.inlineDateTimeTextStyle(
                                secondary: true),
                          ),
                          align: Alignment.centerLeft,
                        ),
                        _bodyCell(
                          _badge(
                              '${r.confidencePct}% ${r.confidenceBand}',
                              r.confidenceColor,
                              r.confidenceColor.withValues(alpha: 0.13)),
                          align: Alignment.centerLeft,
                        ),
                        _bodyCell(
                          _badge(disp.label, st.$1, st.$2),
                          align: Alignment.centerLeft,
                        ),
                        _bodyCell(
                          Text(
                            widget.displayReview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: AdminColors.headerTitle
                                    .withValues(alpha: 0.88)),
                          ),
                          align: Alignment.centerLeft,
                        ),
                        _bodyCell(
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              TextButton(
                                onPressed:
                                    widget.onReview ?? widget.onOpenDetails,
                                style: TextButton.styleFrom(
                                  foregroundColor: widget.onReview != null
                                      ? const Color(0xFFE65100)
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                    widget.onReview != null ? 'Review' : 'View',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5)),
                              ),
                            ],
                          ),
                          align: Alignment.centerRight,
                        ),
                        _bodyCell(
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 36, minHeight: 36),
                            onPressed: () {},
                            icon: Icon(Icons.more_vert_rounded,
                                size: 20,
                                color:
                                    AdminColors.muted.withValues(alpha: 0.85)),
                          ),
                          align: Alignment.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static TableCell _bodyCell(Widget child, {required Alignment align}) {
    return TableCell(
      child: SizedBox(
        height: _ReportTableDim.rowHeight,
        child: Padding(
          padding: _ReportTableDim.cellPadding,
          child: Align(alignment: align, child: child),
        ),
      ),
    );
  }

  Widget _badge(String text, Color fg, Color bg) {
    return AdminDataTableBadge(
        label: text, foreground: fg, background: bg, centerInCell: false);
  }
}
