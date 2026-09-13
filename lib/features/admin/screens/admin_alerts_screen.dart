import 'package:flutter/material.dart';

import '../models/admin_alert_models.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_data_table.dart';
import 'admin_alert_details_screen.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'All Status';
  int _page = 0;
  int _rowsPerPage = 10;
  int _refreshGeneration = 0;

  void _onAlertsRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Alerts refreshed.'),
      ),
    );
    setState(() => _refreshGeneration++);
  }

  static const List<AdminDataTableColumn> _tableColumns = [
    AdminDataTableColumn('Alert ID', 112),
    AdminDataTableColumn('Alert Title', 188),
    AdminDataTableColumn('Reef Zone', 88, headerAlign: TextAlign.center),
    AdminDataTableColumn('Message', 240),
    AdminDataTableColumn('Moderate/High Risk', 130, headerAlign: TextAlign.center),
    AdminDataTableColumn('Alert Status', 108, headerAlign: TextAlign.center),
    AdminDataTableColumn('Date', 168),
    AdminDataTableColumn('Recommended Intervention', 160),
    AdminDataTableColumn('Actions', 96, headerAlign: TextAlign.right),
  ];

  static const _statusOptions = ['All Status', 'New', 'In Progress', 'Resolved'];

  static const _rows = <AdminAlertListRow>[
    AdminAlertListRow(
      'ALT-2026-0006',
      AdminAlertType.cotsDetected,
      'Zone A',
      'COTS detected in monitored area. 7 individuals detected.',
      AdminAlertSeverity.high,
      AdminAlertStatus.new_,
      'May 18, 2026 09:15 AM',
    ),
    AdminAlertListRow(
      'ALT-2026-0005',
      AdminAlertType.highDensity,
      'Zone B',
      'COTS density exceeds threshold. Density: 78.40 /100 m²',
      AdminAlertSeverity.high,
      AdminAlertStatus.inProgress,
      'May 18, 2026 08:42 AM',
    ),
    AdminAlertListRow(
      'ALT-2026-0004',
      AdminAlertType.outbreak,
      'Zone C',
      'Multiple high-density COTS records detected across adjacent reef sectors.',
      AdminAlertSeverity.moderate,
      AdminAlertStatus.new_,
      'May 17, 2026 04:20 PM',
    ),
    AdminAlertListRow(
      'ALT-2026-0003',
      AdminAlertType.cotsDetected,
      'Zone D',
      'Elevated COTS count reported by diver GoPro monitoring capture.',
      AdminAlertSeverity.moderate,
      AdminAlertStatus.inProgress,
      'May 16, 2026 11:05 AM',
    ),
    AdminAlertListRow(
      'ALT-2026-0002',
      AdminAlertType.expertValidation,
      'Zone E',
      'Detection confidence 65% is below the 80% automatic acceptance threshold. Forwarded for expert validation.',
      AdminAlertSeverity.moderate,
      AdminAlertStatus.new_,
      'May 15, 2026 02:10 PM',
    ),
    AdminAlertListRow(
      'ALT-2026-0001',
      AdminAlertType.highDensity,
      'Zone F',
      'Validated COTS infestation trending upward; schedule removal intervention.',
      AdminAlertSeverity.moderate,
      AdminAlertStatus.resolved,
      'May 14, 2026 09:30 AM',
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openAlertDetails(AdminAlertListRow row) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminAlertDetailsScreen(
          data: AdminAlertDetailsData.fromListRow(row),
        ),
      ),
    );
  }

  List<AdminAlertListRow> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _rows.where((r) {
      final byQ = q.isEmpty ||
          r.id.toLowerCase().contains(q) ||
          r.zone.toLowerCase().contains(q) ||
          r.message.toLowerCase().contains(q) ||
          r.typeLabel.toLowerCase().contains(q);
      final byS = _statusFilter == 'All Status' || r.status.label == _statusFilter;
      return byQ && byS;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final pageCount = (rows.length / _rowsPerPage).ceil().clamp(1, 999);
    _page = _page.clamp(0, pageCount - 1);
    final start = _page * _rowsPerPage;
    final pageRows = rows.skip(start).take(_rowsPerPage).toList();
    final end = pageRows.isEmpty ? 0 : start + pageRows.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDashboardHeader(
            title: 'Alerts',
            subtitle: 'Monitor COTS detections, density outbreaks, and expert-validation alerts from the monitoring workflow.',
            onRefreshTap: _onAlertsRefresh,
          ),
          const SizedBox(height: 18),
          _statCards(),
          const SizedBox(height: 18),
          LayoutBuilder(
            key: ValueKey<int>(_refreshGeneration),
            builder: (context, c) {
              if (c.maxWidth < 1100) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _alertsTableCard(rows, pageRows, start, end, pageCount),
                    const SizedBox(height: 16),
                    _infoPanel(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 62, child: _alertsTableCard(rows, pageRows, start, end, pageCount)),
                  const SizedBox(width: 16),
                  Expanded(flex: 28, child: _infoPanel()),
                ],
              );
            },
          ),
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
        ],
      ),
    );
  }

  Widget _statCards() {
    final cards = [
      const _StatSpec('Total Alerts', '6', 'COTS monitoring alerts', Icons.notifications_active_outlined, AdminColors.statBlue),
      const _StatSpec('High Alerts', '2', 'Require immediate action', Icons.trending_up_rounded, AdminColors.statRed),
      const _StatSpec('Moderate Alerts', '4', 'Needs monitoring / validation', Icons.horizontal_rule_rounded, AdminColors.statYellow),
      const _StatSpec('Resolved', '1', 'Intervention completed', Icons.check_circle_outline_rounded, AdminColors.statGreen),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
          final width = c.maxWidth < 480 ? c.maxWidth : (c.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards.map((e) => SizedBox(width: width, child: _StatCard(spec: e))).toList(),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _StatCard(spec: cards[i])),
            ],
          ],
        );
      },
    );
  }

  Widget _alertsTableCard(
    List<AdminAlertListRow> allRows,
    List<AdminAlertListRow> pageRows,
    int start,
    int end,
    int pageCount,
  ) {
    final colMap = AdminDataTableColumn.widthsMap(_tableColumns);
    final tableW = AdminDataTableColumn.totalWidth(_tableColumns);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 720;
              final maxControlW = c.maxWidth.isFinite ? c.maxWidth : 720.0;
              final dropdownW =
                  narrow ? maxControlW : (maxControlW * 0.28).clamp(156.0, 220.0).toDouble();
              final searchW =
                  narrow ? maxControlW : (maxControlW * 0.36).clamp(180.0, 280.0).toDouble();
              const filterLabelStyle = TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AdminColors.headerTitle,
              );
              final controls = [
                Container(
                  width: dropdownW,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      isExpanded: true,
                      borderRadius: BorderRadius.circular(10),
                      dropdownColor: Colors.white,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: AdminColors.muted.withValues(alpha: 0.9)),
                      style: filterLabelStyle,
                      selectedItemBuilder: (context) {
                        return _statusOptions
                            .map(
                              (e) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  e,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: filterLabelStyle,
                                ),
                              ),
                            )
                            .toList();
                      },
                      items: _statusOptions
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
                      onChanged: (v) => setState(() {
                        _statusFilter = v ?? 'All Status';
                        _page = 0;
                      }),
                    ),
                  ),
                ),
                SizedBox(
                  width: searchW,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {
                      _page = 0;
                    }),
                    decoration: const InputDecoration(
                      hintText: 'Search alerts...',
                      prefixIcon: Icon(Icons.search_rounded, size: 22),
                      isDense: true,
                      filled: true,
                      fillColor: Color(0xFFF7F9FC),
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: () {},
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFF7F9FC), foregroundColor: AdminColors.headerTitle),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ];
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Alerts List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdminColors.headerTitle)),
                    const SizedBox(height: 12),
                    controls[0],
                    const SizedBox(height: 10),
                    controls[1],
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: controls[2]),
                  ],
                );
              }
              return Row(
                children: [
                  const Text('Alerts List', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AdminColors.headerTitle)),
                  const Spacer(),
                  controls[0],
                  const SizedBox(width: 10),
                  controls[1],
                  const SizedBox(width: 8),
                  controls[2],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          AdminDataTableScrollArea(
            tableWidth: tableW,
            horizontalPadding: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDataTableHeader(columns: _tableColumns),
                for (final r in pageRows)
                  AdminDataTableClickableRow(
                    columnWidths: colMap,
                    onTap: () => _openAlertDetails(r),
                    cells: _alertRowCells(r),
                  ),
              ],
            ),
          ),
          AdminDataTablePaginationBar(
            summaryText: pageRows.isEmpty
                ? 'No alerts match your filters.'
                : 'Showing ${start + 1} to $end of ${allRows.length} alerts',
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          ),
        ],
      ),
    );
  }

  List<TableCell> _alertRowCells(AdminAlertListRow r) {
    final sev = r.severity.color;
    final st = r.status.colors;
    return [
      AdminDataTableCells.cell(
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
      AdminDataTableCells.cell(
        child: Row(
          children: [
            Icon(r.type.icon, size: 18, color: r.type.iconColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.typeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
      AdminDataTableCells.text(r.zone, align: TextAlign.center),
      AdminDataTableCells.text(
        r.message,
        maxLines: 1,
        style: TextStyle(fontSize: 12.5, height: 1.2, color: AdminColors.headerTitle.withValues(alpha: 0.88)),
      ),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(label: r.severity.label, foreground: sev, background: sev.withValues(alpha: 0.13)),
      ),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(label: r.status.label, foreground: st.$1, background: st.$2),
      ),
      AdminDataTableCells.text(
        r.detectedOn,
        style: AdminDateTimeTokens.inlineDateTimeTextStyle(secondary: true),
      ),
      AdminDataTableCells.text(
        r.type == AdminAlertType.expertValidation
            ? 'Expert manual verification'
            : r.severity == AdminAlertSeverity.high
                ? 'Immediate removal recommended'
                : r.severity == AdminAlertSeverity.moderate
                    ? 'Schedule intervention'
                    : 'Continue monitoring',
        maxLines: 2,
        style: TextStyle(
          fontSize: 12,
          height: 1.25,
          fontWeight: FontWeight.w600,
          color: AdminColors.headerTitle.withValues(alpha: 0.88),
        ),
      ),
      AdminDataTableCells.cell(
        align: TextAlign.right,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _openAlertDetails(r),
              icon: const Icon(Icons.visibility_outlined, size: 18, color: AdminColors.statBlue),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {},
              icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AdminColors.muted.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _infoPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ABOUT ALERTS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AdminColors.muted),
          ),
          const SizedBox(height: 10),
          Text(
            'Alerts are generated from machine learning COTS detections, density thresholds, outbreak patterns, and expert-validation needs in the monitoring workflow.',
            style: TextStyle(fontSize: 13, height: 1.45, color: AdminColors.headerTitle.withValues(alpha: 0.88)),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 18),
          const Text(
            'ALERT TYPES',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AdminColors.muted),
          ),
          const SizedBox(height: 12),
          _statusLegendLine('COTS Detected', 'New starfish detections from diver captures.'),
          const SizedBox(height: 8),
          _statusLegendLine('High Density', 'Infestation exceeds reef-zone density threshold.'),
          const SizedBox(height: 8),
          _statusLegendLine('Outbreak Alert', 'Multiple high-risk detections in nearby zones.'),
          const SizedBox(height: 8),
          _statusLegendLine('Expert Validation', 'Confidence below 80% — needs expert review.'),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 18),
          const Text(
            'SEVERITY LEVELS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AdminColors.muted),
          ),
          const SizedBox(height: 12),
          _legendRow(AdminColors.statRed, 'High', 'Critical COTS conditions requiring immediate intervention.'),
          const SizedBox(height: 10),
          _legendRow(AdminColors.statYellow, 'Moderate', 'Needs monitoring, validation, or scheduled removal.'),
          const SizedBox(height: 10),
          _legendRow(AdminColors.statGreen, 'Low', 'Lower-priority COTS follow-up items.'),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
          const SizedBox(height: 18),
          const Text(
            'STATUS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: AdminColors.muted),
          ),
          const SizedBox(height: 12),
          _statusLegendLine('New', 'Newly generated COTS alert.'),
          const SizedBox(height: 8),
          _statusLegendLine('In Progress', 'Intervention or validation is ongoing.'),
          const SizedBox(height: 8),
          _statusLegendLine('Resolved', 'COTS issue has been addressed.'),
        ],
      ),
    );
  }

  Widget _legendRow(Color dot, String title, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, height: 1.4, color: AdminColors.headerTitle.withValues(alpha: 0.88), decoration: TextDecoration.none),
              children: [
                TextSpan(text: '$title — ', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusLegendLine(String title, String text) {
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, height: 1.4, color: AdminColors.headerTitle.withValues(alpha: 0.88), decoration: TextDecoration.none),
        children: [
          TextSpan(text: '$title — ', style: const TextStyle(fontWeight: FontWeight.w800)),
          TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
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
}

class _StatSpec {
  const _StatSpec(this.title, this.value, this.subtitle, this.icon, this.color);
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatefulWidget {
  const _StatCard({required this.spec});
  final _StatSpec spec;

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.1 : 0.06),
              blurRadius: _hover ? 22 : 16,
              offset: Offset(0, _hover ? 8 : 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: s.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(s.icon, color: s.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AdminColors.headerTitle)),
                  Text(s.value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: AdminColors.headerTitle)),
                  Text(s.subtitle, style: TextStyle(fontSize: 11, color: AdminColors.muted.withValues(alpha: 0.9))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

