import 'package:flutter/material.dart';

import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_stat_card.dart';
import 'admin_zone_details_screen.dart';

class AdminZonesManagementScreen extends StatefulWidget {
  const AdminZonesManagementScreen({super.key});

  @override
  State<AdminZonesManagementScreen> createState() => _AdminZonesManagementScreenState();
}

class _AdminZonesManagementScreenState extends State<AdminZonesManagementScreen> {
  final _searchCtrl = TextEditingController();
  String _status = 'All Status';
  String _risk = 'All Risk Levels';
  String _density = 'All Density Levels';
  int _page = 0;
  static const _perPage = 12;

  static const List<AdminDataTableColumn> _tableColumns = [
    AdminDataTableColumn('#', 40, headerAlign: TextAlign.center),
    AdminDataTableColumn('Zone Name', 172),
    AdminDataTableColumn('Location', 200),
    AdminDataTableColumn('Status', 132, headerAlign: TextAlign.center),
    AdminDataTableColumn('Risk Level', 108, headerAlign: TextAlign.center),
    AdminDataTableColumn('Average Density', 132, headerAlign: TextAlign.right),
    AdminDataTableColumn('Last Monitoring', 152),
    AdminDataTableColumn('Last Updated', 152),
    AdminDataTableColumn('Actions', 96, headerAlign: TextAlign.right),
  ];

  static const _rows = [
    _ZoneRow('A', 'Zone A', 'Brgy. San Isidro, Cityville', 'Active (Outbreak)', 'High', 78.40, 'May 18, 2026 09:15 AM', 'May 18, 2026 09:30 AM'),
    _ZoneRow('B', 'Zone B', 'Brgy. Riverside, Cityville', 'Active (Outbreak)', 'High', 55.40, 'May 18, 2026 08:45 AM', 'May 18, 2026 09:00 AM'),
    _ZoneRow('C', 'Zone C', 'Brgy. Greenfield, Cityville', 'Scheduled', 'Moderate', 41.75, 'May 17, 2026 04:30 PM', 'May 17, 2026 04:45 PM'),
    _ZoneRow('D', 'Zone D', 'Brgy. Hilltop, Cityville', 'Active (Outbreak)', 'High', 72.10, 'May 17, 2026 11:20 AM', 'May 17, 2026 11:35 AM'),
    _ZoneRow('E', 'Zone E', 'Brgy. Central, Cityville', 'Cleared', 'Low', 8.30, 'May 16, 2026 10:10 AM', 'May 16, 2026 10:30 AM'),
    _ZoneRow('F', 'Zone F', 'Brgy. Lakeside, Cityville', 'Scheduled', 'Moderate', 22.60, 'May 16, 2026 03:10 PM', 'May 16, 2026 03:30 PM'),
    _ZoneRow('G', 'Zone G', 'Brgy. Eastview, Cityville', 'Cleared', 'Low', 6.20, 'May 15, 2026 09:25 AM', 'May 15, 2026 09:40 AM'),
    _ZoneRow('H', 'Zone H', 'Brgy. Westwood, Cityville', 'Cleared', 'Low', 4.80, 'May 15, 2026 02:15 PM', 'May 15, 2026 02:30 PM'),
    _ZoneRow('I', 'Zone I', 'Brgy. Northpoint, Cityville', 'Active (Outbreak)', 'High', 60.90, 'May 14, 2026 08:50 AM', 'May 14, 2026 09:05 AM'),
    _ZoneRow('J', 'Zone J', 'Brgy. Southridge, Cityville', 'Scheduled', 'Moderate', 19.30, 'May 14, 2026 01:40 PM', 'May 14, 2026 02:00 PM'),
    _ZoneRow('K', 'Zone K', 'Brgy. Pinecrest, Cityville', 'Cleared', 'Low', 3.10, 'May 13, 2026 10:05 AM', 'May 13, 2026 10:20 AM'),
    _ZoneRow('L', 'Zone L', 'Brgy. Meadowbrook, Cityville', 'Cleared', 'Low', 5.00, 'May 13, 2026 03:35 PM', 'May 13, 2026 03:50 PM'),
  ];

  List<_ZoneRow> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _rows.where((r) {
      final byQuery = q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.location.toLowerCase().contains(q);
      final byStatus = _status == 'All Status' || _status == r.status;
      final byRisk = _risk == 'All Risk Levels' || _risk == r.risk;
      final byDensity = switch (_density) {
        '>= 70 COTS/ha' => r.density >= 70,
        '50 - 69 COTS/ha' => r.density >= 50 && r.density < 70,
        '< 50 COTS/ha' => r.density < 50,
        _ => true,
      };
      return byQuery && byStatus && byRisk && byDensity;
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _open(_ZoneRow row) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminZoneDetailsScreen(
          zone: AdminZoneDetailsData(
            zoneName: row.name,
            location: row.location,
            riskLevel: row.risk,
            density: row.density,
            totalDetected: (row.density * 0.85).round(),
            lastMonitoring: row.lastMonitoring,
            zoneInitials: row.id,
            alertStatus: row.status,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _filtered;
    final pageCount = (rows.length / _perPage).ceil().clamp(1, 999);
    _page = _page.clamp(0, pageCount - 1);
    final start = _page * _perPage;
    final pageRows = rows.skip(start).take(_perPage).toList();
    final end = pageRows.isEmpty ? 0 : start + pageRows.length;
    final colMap = AdminDataTableColumn.widthsMap(_tableColumns);
    final tableW = AdminDataTableColumn.totalWidth(_tableColumns);
    final pagePad = AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);
    final filtersActive = _status != 'All Status' ||
        _risk != 'All Risk Levels' ||
        _density != 'All Density Levels' ||
        _searchCtrl.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(pagePad.left, 22, pagePad.right, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 22),
          _stats(),
          const SizedBox(height: 20),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      height: 48,
                      width: 220,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Search zones...',
                          isDense: true,
                          filled: true,
                          fillColor: Color(0xFFF7F9FC),
                        ),
                      ),
                    ),
                    _drop(
                      const ['All Status', 'Active (Outbreak)', 'Scheduled', 'Cleared'],
                      _status,
                      (v) => setState(() => _status = v!),
                      width: 200,
                    ),
                    _drop(
                      const ['All Risk Levels', 'High', 'Moderate', 'Low'],
                      _risk,
                      (v) => setState(() => _risk = v!),
                    ),
                    _drop(
                      const ['All Density Levels', '>= 70 COTS/ha', '50 - 69 COTS/ha', '< 50 COTS/ha'],
                      _density,
                      (v) => setState(() => _density = v!),
                    ),
                    OutlinedButton.icon(
                      onPressed: _resetZoneFilters,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reset'),
                    ),
                  ],
                ),
                if (filtersActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Showing ${rows.length} of ${_rows.length} zones. The list is filtered — use Reset or set Status / Risk / Density to “All” to show every zone.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: AdminColors.muted.withValues(alpha: 0.95),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
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
                      for (var i = 0; i < pageRows.length; i++)
                        AdminDataTableClickableRow(
                          columnWidths: colMap,
                          onTap: () => _open(pageRows[i]),
                          cells: _zoneRowCells(start + i + 1, pageRows[i]),
                        ),
                    ],
                  ),
                ),
                AdminDataTablePaginationBar(
                  summaryText: pageRows.isEmpty
                      ? 'No zones match your filters.'
                      : 'Showing ${start + 1} to $end of ${rows.length} zones',
                  pageIndex: _page,
                  pageCount: pageCount,
                  onPageSelected: (p) => setState(() => _page = p),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _resetZoneFilters() {
    setState(() {
      _searchCtrl.clear();
      _status = 'All Status';
      _risk = 'All Risk Levels';
      _density = 'All Density Levels';
      _page = 0;
    });
  }

  void _onZonesHeaderRefresh() {
    _resetZoneFilters();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Zones data refreshed (demo).'),
      ),
    );
  }

  Widget _header() {
    return AdminDashboardHeader(
      title: 'Zones',
      subtitle:
          'Manage and monitor all zones. View zone status, risk level, density, and last monitoring information.',
      onRefreshTap: _onZonesHeaderRefresh,
    );
  }

  Widget _stats() {
    return LayoutBuilder(
      builder: (context, c) {
        final maxWidth = c.maxWidth;
        final cards = <Widget>[
          AdminStatCard(
            title: 'Total Zones',
            value: '12',
            subtitle: 'All monitoring zones',
            icon: Icons.map_outlined,
            accentColor: AdminColors.statBlue,
            selected: _status == 'All Status',
            onTap: () => setState(() => _status = 'All Status'),
          ),
          AdminStatCard(
            title: 'Active Zones (Outbreak)',
            value: '4',
            subtitle: 'Require immediate action',
            icon: Icons.emergency_outlined,
            accentColor: AdminColors.statRed,
            selected: _status == 'Active (Outbreak)',
            onTap: () => setState(() {
              _status = _status == 'Active (Outbreak)' ? 'All Status' : 'Active (Outbreak)';
            }),
          ),
          AdminStatCard(
            title: 'Scheduled Zones',
            value: '3',
            subtitle: 'Planned for removal',
            icon: Icons.schedule_rounded,
            accentColor: AdminColors.statYellow,
            selected: _status == 'Scheduled',
            onTap: () => setState(() {
              _status = _status == 'Scheduled' ? 'All Status' : 'Scheduled';
            }),
          ),
          AdminStatCard(
            title: 'Cleared Zones',
            value: '5',
            subtitle: 'No COTS detected',
            icon: Icons.check_circle_outline_rounded,
            accentColor: AdminColors.statGreen,
            selected: _status == 'Cleared',
            onTap: () => setState(() {
              _status = _status == 'Cleared' ? 'All Status' : 'Cleared';
            }),
          ),
          AdminStatCard(
            title: 'Total COTS Detected',
            value: '248',
            subtitle: 'Across all zones',
            icon: Icons.pest_control_outlined,
            accentColor: AdminColors.statPurple,
            onTap: () => setState(() => _status = 'All Status'),
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

  Widget _drop(
    List<String> options,
    String value,
    ValueChanged<String?> onChanged, {
    double width = 170,
  }) {
    const labelStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AdminColors.headerTitle,
    );
    return SizedBox(
      width: width,
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

  List<TableCell> _zoneRowCells(int index, _ZoneRow row) {
    final cStatus = _zoneStatusColor(row.status);
    final cRisk = _zoneRiskColor(row.risk);
    return [
      AdminDataTableCells.text('$index', align: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      AdminDataTableCells.cell(
        align: TextAlign.left,
        child: Text(
          row.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            color: AdminColors.statBlue,
            decoration: TextDecoration.underline,
            decorationColor: AdminColors.statBlue,
          ),
        ),
      ),
      AdminDataTableCells.text(row.location),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(label: row.status, foreground: cStatus, background: cStatus.withValues(alpha: 0.14)),
      ),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(label: row.risk, foreground: cRisk, background: cRisk.withValues(alpha: 0.14)),
      ),
      AdminDataTableCells.text(
        '${row.density.toStringAsFixed(2)} COTS/ha',
        align: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
      ),
      AdminDataTableCells.text(row.lastMonitoring, style: TextStyle(fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.95))),
      AdminDataTableCells.text(row.lastUpdated, style: TextStyle(fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.95))),
      AdminDataTableCells.cell(
        align: TextAlign.right,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => _open(row),
              icon: Icon(Icons.visibility_outlined, size: 18, color: AdminColors.statBlue.withValues(alpha: 0.9)),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () {},
              icon: Icon(Icons.edit_outlined, size: 18, color: AdminColors.muted.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    ];
  }

  Color _zoneStatusColor(String status) {
    switch (status) {
      case 'Active (Outbreak)':
        return AdminColors.statRed;
      case 'Scheduled':
        return AdminColors.statYellow;
      default:
        return AdminColors.statGreen;
    }
  }

  Color _zoneRiskColor(String risk) {
    switch (risk) {
      case 'High':
        return AdminColors.statRed;
      case 'Moderate':
        return AdminColors.statYellow;
      default:
        return AdminColors.statGreen;
    }
  }
}

class _ZoneRow {
  const _ZoneRow(
    this.id,
    this.name,
    this.location,
    this.status,
    this.risk,
    this.density,
    this.lastMonitoring,
    this.lastUpdated,
  );
  final String id;
  final String name;
  final String location;
  final String status;
  final String risk;
  final double density;
  final String lastMonitoring;
  final String lastUpdated;
}
