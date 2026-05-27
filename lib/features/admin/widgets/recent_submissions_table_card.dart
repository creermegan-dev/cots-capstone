import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import 'admin_data_table.dart';

class RecentSubmissionsTableCard extends StatefulWidget {
  const RecentSubmissionsTableCard({super.key});

  /// Fixed viewport height for dashboard embedding inside [SingleChildScrollView].
  static const double _tableViewportHeight = 360;

  static const _rows = [
    _Row('1', 'May 18, 2026 · 09:42', 'Field Monitor A', 'Zone B', '18', _Status.scheduled),
    _Row('2', 'May 18, 2026 · 08:15', 'Researcher K', 'Zone A', '42', _Status.active),
    _Row('3', 'May 17, 2026 · 16:03', 'Ranger M', 'Zone F', '0', _Status.cleared),
    _Row('4', 'May 17, 2026 · 11:22', 'Biologist P', 'Zone C', '12', _Status.scheduled),
    _Row('5', 'May 16, 2026 · 14:50', 'Field Monitor A', 'Zone E', '7', _Status.cleared),
  ];

  static const List<AdminDataTableColumn> _columns = [
    AdminDataTableColumn('#', 44, headerAlign: TextAlign.center),
    AdminDataTableColumn('Date & Time', 196),
    AdminDataTableColumn('User', 180),
    AdminDataTableColumn('Zone', 88, headerAlign: TextAlign.center),
    AdminDataTableColumn('COTS Detected', 100, headerAlign: TextAlign.right),
    AdminDataTableColumn('Status', 120, headerAlign: TextAlign.center),
    AdminDataTableColumn('Actions', 100, headerAlign: TextAlign.right),
  ];

  @override
  State<RecentSubmissionsTableCard> createState() => _RecentSubmissionsTableCardState();
}

class _RecentSubmissionsTableCardState extends State<RecentSubmissionsTableCard> {
  final ScrollController _horizontalScroll = ScrollController();

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableW = AdminDataTableColumn.totalWidth(RecentSubmissionsTableCard._columns);
    final colMap = AdminDataTableColumn.widthsMap(RecentSubmissionsTableCard._columns);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Submissions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.headerTitle,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, c) {
              return SizedBox(
                height: RecentSubmissionsTableCard._tableViewportHeight,
                child: Scrollbar(
                  controller: _horizontalScroll,
                  thumbVisibility: c.maxWidth < 900,
                  child: SingleChildScrollView(
                    controller: _horizontalScroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: c.maxWidth < tableW + 40 ? tableW + 40 : c.maxWidth - 40,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AdminDataTableHeader(columns: RecentSubmissionsTableCard._columns),
                          for (final r in RecentSubmissionsTableCard._rows)
                            AdminDataTableStaticRow(
                              columnWidths: colMap,
                              cells: _rowCells(r),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<TableCell> _rowCells(_Row r) {
    return [
      AdminDataTableCells.text(r.id, align: TextAlign.center),
      AdminDataTableCells.text(r.dt, style: AdminDateTimeTokens.inlineDateTimeTextStyle()),
      AdminDataTableCells.text(r.user),
      AdminDataTableCells.text(r.zone, align: TextAlign.center),
      AdminDataTableCells.text(r.cots, align: TextAlign.right),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: _statusBadge(r.status),
      ),
      AdminDataTableCells.cell(
        align: TextAlign.right,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'View',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.visibility_outlined, size: 20),
              color: AdminColors.statBlue,
              onPressed: () {},
            ),
            IconButton(
              tooltip: 'Edit',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AdminColors.muted,
              onPressed: () {},
            ),
          ],
        ),
      ),
    ];
  }

  static Widget _statusBadge(_Status s) {
    late Color bg;
    late Color fg;
    late String label;
    switch (s) {
      case _Status.active:
        bg = AdminColors.statRed.withValues(alpha: 0.12);
        fg = AdminColors.statRed;
        label = 'Active';
        break;
      case _Status.scheduled:
        bg = AdminColors.statYellow.withValues(alpha: 0.18);
        fg = const Color(0xFFF57F17);
        label = 'Scheduled';
        break;
      case _Status.cleared:
        bg = AdminColors.statGreen.withValues(alpha: 0.12);
        fg = AdminColors.statGreen;
        label = 'Cleared';
        break;
    }
    return AdminDataTableBadge(label: label, foreground: fg, background: bg);
  }
}

enum _Status { active, scheduled, cleared }

class _Row {
  const _Row(this.id, this.dt, this.user, this.zone, this.cots, this.status);

  final String id;
  final String dt;
  final String user;
  final String zone;
  final String cots;
  final _Status status;
}
