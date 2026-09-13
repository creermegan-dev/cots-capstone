import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/scan_record_model.dart';
import '../../../services/scan_record_repository.dart';
import '../theme/admin_theme.dart';
import 'admin_data_table.dart';

class RecentSubmissionsTableCard extends StatefulWidget {
  const RecentSubmissionsTableCard({super.key});

  /// Fixed viewport height for dashboard embedding inside [SingleChildScrollView].
  static const double _tableViewportHeight = 360;

  static const List<AdminDataTableColumn> _columns = [
    AdminDataTableColumn('#', 44, headerAlign: TextAlign.center),
    AdminDataTableColumn('Date and Time', 196),
    AdminDataTableColumn('Diver/User', 180),
    AdminDataTableColumn('Reef Zone', 100, headerAlign: TextAlign.center),
    AdminDataTableColumn('COTS Detected', 100, headerAlign: TextAlign.right),
    AdminDataTableColumn('Validation Status', 140, headerAlign: TextAlign.center),
    AdminDataTableColumn('Actions', 100, headerAlign: TextAlign.right),
  ];

  @override
  State<RecentSubmissionsTableCard> createState() =>
      _RecentSubmissionsTableCardState();
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
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Recent Monitoring Captures',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.headerTitle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Latest diver monitoring captures with expert validation status',
            style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<ScanRecordModel>>(
            stream: ScanRecordRepository.watchRecent(limit: 5),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SizedBox(
                  height: RecentSubmissionsTableCard._tableViewportHeight,
                  child: Center(
                    child: CircularProgressIndicator(color: AdminColors.statBlue),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  height: RecentSubmissionsTableCard._tableViewportHeight,
                  child: Center(
                    child: Text(
                      'Could not load submissions.',
                      style: TextStyle(color: AdminColors.muted),
                    ),
                  ),
                );
              }

              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return const SizedBox(
                  height: RecentSubmissionsTableCard._tableViewportHeight,
                  child: Center(
                    child: Text(
                      'No submissions yet.',
                      style: TextStyle(color: AdminColors.muted),
                    ),
                  ),
                );
              }

              return LayoutBuilder(
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
                              AdminDataTableHeader(
                                columns: RecentSubmissionsTableCard._columns,
                              ),
                              for (var i = 0; i < records.length; i++)
                                AdminDataTableStaticRow(
                                  columnWidths: colMap,
                                  cells: _rowCells(records[i], i + 1),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  List<TableCell> _rowCells(ScanRecordModel record, int index) {
    final when = record.submittedAt ?? record.dateTaken ?? DateTime.now();
    final dt = DateFormat('MMM d, yyyy · HH:mm').format(when);
    final status = _validationStatus(record);

    return [
      AdminDataTableCells.text('$index', align: TextAlign.center),
      AdminDataTableCells.text(dt, style: AdminDateTimeTokens.inlineDateTimeTextStyle()),
      AdminDataTableCells.text(record.submittedBy),
      AdminDataTableCells.text(
        record.zone.isEmpty ? '—' : record.zone,
        align: TextAlign.center,
      ),
      AdminDataTableCells.text('${record.aiDetectedCount}', align: TextAlign.right),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: _statusBadge(status),
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
          ],
        ),
      ),
    ];
  }

  static _Status _validationStatus(ScanRecordModel record) {
    if (record.adminConfirmed ||
        record.userStatusLabel == 'Accepted' ||
        record.userStatusLabel == 'Automatically Accepted') {
      return _Status.validated;
    }
    if (record.adminRejected || record.userStatusLabel == 'Retake Photo') {
      return _Status.cleared;
    }
    if (record.aiDetectedCount >= 15) {
      return _Status.intervention;
    }
    return _Status.pending;
  }

  static Widget _statusBadge(_Status s) {
    late Color bg;
    late Color fg;
    late String label;
    switch (s) {
      case _Status.pending:
        bg = AdminColors.statYellow.withValues(alpha: 0.18);
        fg = const Color(0xFFF57F17);
        label = 'Pending Validation';
        break;
      case _Status.validated:
        bg = AdminColors.statBlue.withValues(alpha: 0.12);
        fg = AdminColors.statBlue;
        label = 'Validated';
        break;
      case _Status.intervention:
        bg = AdminColors.statRed.withValues(alpha: 0.12);
        fg = AdminColors.statRed;
        label = 'Intervention Required';
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

enum _Status { pending, validated, intervention, cleared }
