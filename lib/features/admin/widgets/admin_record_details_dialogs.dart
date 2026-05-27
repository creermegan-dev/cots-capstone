import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import 'admin_data_table.dart';

/// Enterprise-style overlay: dim + light blur. Sidebar stays visible underneath.
Future<void> showAdminBlurredDialog({
  required BuildContext context,
  required Widget child,
  double maxWidthFraction = 0.74,
  double? maxWidthPx,
}) {
  final size = MediaQuery.sizeOf(context);
  final maxW = maxWidthPx ?? size.width * maxWidthFraction;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _BlurredBarrier(
        onDismiss: () => Navigator.of(ctx).pop(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW.clamp(320, 1400), maxHeight: size.height * 0.92),
            child: child,
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Same overlay/animation as [showAdminBlurredDialog], but returns a result from [Navigator.pop].
Future<T?> showAdminBlurredDialogForResult<T>({
  required BuildContext context,
  required Widget child,
  double maxWidthFraction = 0.74,
  double? maxWidthPx,
}) {
  final size = MediaQuery.sizeOf(context);
  final maxW = maxWidthPx ?? size.width * maxWidthFraction;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _BlurredBarrier(
        onDismiss: () => Navigator.of(ctx).pop(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW.clamp(320, 1400), maxHeight: size.height * 0.92),
            child: child,
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _BlurredBarrier extends StatelessWidget {
  const _BlurredBarrier({required this.onDismiss, required this.child});

  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.38)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// ─── All Schedules ───────────────────────────────────────────────────────────

class _ScheduleRow {
  const _ScheduleRow({
    required this.num,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.assignedTo,
    required this.purpose,
    required this.status,
    required this.createdOn,
  });

  final int num;
  final String scheduledDate;
  final String scheduledTime;
  final String assignedTo;
  final String purpose;
  final String status;
  final String createdOn;
}

Future<void> showAdminAllSchedulesDialog(BuildContext context, {required String zoneName}) {
  const rows = <_ScheduleRow>[
    _ScheduleRow(
      num: 1,
      scheduledDate: 'May 22, 2026',
      scheduledTime: '08:00 AM',
      assignedTo: 'Juan Dela Cruz (Field Technician)',
      purpose: 'Follow-up monitoring',
      status: 'Scheduled',
      createdOn: 'May 10, 2026 02:30 PM',
    ),
    _ScheduleRow(
      num: 2,
      scheduledDate: 'May 29, 2026',
      scheduledTime: '08:00 AM',
      assignedTo: 'Juan Dela Cruz',
      purpose: 'Regular monitoring',
      status: 'Scheduled',
      createdOn: 'May 10, 2026 02:30 PM',
    ),
    _ScheduleRow(
      num: 3,
      scheduledDate: 'Jun 05, 2026',
      scheduledTime: '08:00 AM',
      assignedTo: 'Maria Santos',
      purpose: 'Regular monitoring',
      status: 'Scheduled',
      createdOn: 'May 10, 2026 02:30 PM',
    ),
    _ScheduleRow(
      num: 4,
      scheduledDate: 'Jun 12, 2026',
      scheduledTime: '08:00 AM',
      assignedTo: 'Juan Dela Cruz',
      purpose: 'Follow-up monitoring',
      status: 'Scheduled',
      createdOn: 'May 10, 2026 02:30 PM',
    ),
    _ScheduleRow(
      num: 5,
      scheduledDate: 'May 18, 2026',
      scheduledTime: '08:00 AM',
      assignedTo: 'Juan Dela Cruz',
      purpose: 'Completed monitoring',
      status: 'Completed',
      createdOn: 'May 05, 2026 09:10 AM',
    ),
    _ScheduleRow(
      num: 6,
      scheduledDate: 'May 11, 2026',
      scheduledTime: '08:00 AM',
      assignedTo: 'Maria Santos',
      purpose: 'Baseline monitoring',
      status: 'Completed',
      createdOn: 'Apr 28, 2026 11:45 AM',
    ),
  ];

  return showAdminBlurredDialog(
    context: context,
    maxWidthFraction: 0.74,
    child: Material(
      color: Colors.transparent,
      child: _SchedulesModalBody(zoneName: zoneName, rows: rows),
    ),
  );
}

class _SchedulesModalBody extends StatefulWidget {
  const _SchedulesModalBody({required this.zoneName, required this.rows});

  final String zoneName;
  final List<_ScheduleRow> rows;

  @override
  State<_SchedulesModalBody> createState() => _SchedulesModalBodyState();
}

class _SchedulesModalBodyState extends State<_SchedulesModalBody> {
  int _page = 0;
  static const _perPage = 6;

  static const List<AdminDataTableColumn> _scheduleColumns = [
    AdminDataTableColumn('#', 40, headerAlign: TextAlign.center),
    AdminDataTableColumn('Scheduled Date', 108),
    AdminDataTableColumn('Scheduled Time', 88),
    AdminDataTableColumn('Assigned To', 200),
    AdminDataTableColumn('Purpose', 280),
    AdminDataTableColumn('Status', 104, headerAlign: TextAlign.center),
    AdminDataTableColumn('Created On', 148),
    AdminDataTableColumn('Actions', 92, headerAlign: TextAlign.right),
  ];

  @override
  Widget build(BuildContext context) {
    final total = widget.rows.length;
    final pageCount = (total / _perPage).ceil().clamp(1, 999);
    _page = _page.clamp(0, pageCount - 1);
    final pageRows = widget.rows.skip(_page * _perPage).take(_perPage).toList();
    final startIdx = _page * _perPage;
    final start = total == 0 ? 0 : startIdx + 1;
    final end = total == 0 ? 0 : startIdx + pageRows.length;

    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'All Schedules',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'List of all scheduled monitoring activities for ${widget.zoneName}.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.muted.withValues(alpha: 0.92)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(foregroundColor: AdminColors.headerTitle),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.black.withValues(alpha: 0.08)),
            LayoutBuilder(
              builder: (context, c) {
                final maxTableH = MediaQuery.sizeOf(context).height * 0.52;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxTableH),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: AdminDataTableColumn.totalWidth(_scheduleColumns),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AdminDataTableHeader(columns: _scheduleColumns),
                            for (final r in pageRows)
                              AdminDataTableStaticRow(
                                columnWidths: AdminDataTableColumn.widthsMap(_scheduleColumns),
                                cells: _scheduleRowCells(r),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Divider(height: 1, thickness: 1, color: Colors.black.withValues(alpha: 0.08)),
            AdminDataTablePaginationBar(
              summaryText: total == 0 ? 'No schedules.' : 'Showing $start to $end of $total schedules',
              pageIndex: _page,
              pageCount: pageCount,
              onPageSelected: (p) => setState(() => _page = p),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            ),
          ],
        ),
      ),
    );
  }

  Color _scheduleStatusColor(String s) {
    switch (s) {
      case 'Scheduled':
        return AdminColors.statBlue;
      case 'Completed':
        return AdminColors.statGreen;
      case 'Cancelled':
        return AdminColors.statRed;
      default:
        return AdminColors.muted;
    }
  }

  List<TableCell> _scheduleRowCells(_ScheduleRow r) {
    final c = _scheduleStatusColor(r.status);
    return [
      AdminDataTableCells.text('${r.num}', align: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
      AdminDataTableCells.text(r.scheduledDate, style: const TextStyle(fontWeight: FontWeight.w600)),
      AdminDataTableCells.text(r.scheduledTime),
      AdminDataTableCells.text(r.assignedTo, style: const TextStyle(fontWeight: FontWeight.w600)),
      AdminDataTableCells.text(r.purpose),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(label: r.status, foreground: c, background: c.withValues(alpha: 0.12)),
      ),
      AdminDataTableCells.text(r.createdOn, style: TextStyle(fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.95))),
      AdminDataTableCells.cell(
        align: TextAlign.right,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _IconHoverButton(icon: Icons.visibility_outlined, tooltip: 'View', onPressed: () {}),
            _IconHoverButton(icon: Icons.more_vert_rounded, tooltip: 'More', onPressed: () {}),
          ],
        ),
      ),
    ];
  }
}

class _IconHoverButton extends StatefulWidget {
  const _IconHoverButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<_IconHoverButton> createState() => _IconHoverButtonState();
}

class _IconHoverButtonState extends State<_IconHoverButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: IconButton(
          onPressed: widget.onPressed,
          icon: Icon(widget.icon, size: 20),
          style: IconButton.styleFrom(
            foregroundColor: _hover ? AdminColors.statBlue : AdminColors.headerTitle,
            backgroundColor: _hover ? AdminColors.statBlue.withValues(alpha: 0.08) : Colors.transparent,
          ),
        ),
      ),
    );
  }
}

// ─── View Notes ──────────────────────────────────────────────────────────────

Future<void> showAdminViewNotesDialog(
  BuildContext context, {
  required String userRemarksBody,
  required String submittedViaLine,
  required String submittedByLine,
  required String submittedOnLine,
}) {
  return showAdminBlurredDialog(
    context: context,
    maxWidthFraction: 0.5,
    maxWidthPx: 480,
    child: Material(
      color: Colors.transparent,
      child: _ViewNotesModal(
        userRemarksBody: userRemarksBody,
        submittedViaLine: submittedViaLine,
        submittedByLine: submittedByLine,
        submittedOnLine: submittedOnLine,
      ),
    ),
  );
}

class _ViewNotesModal extends StatefulWidget {
  const _ViewNotesModal({
    required this.userRemarksBody,
    required this.submittedViaLine,
    required this.submittedByLine,
    required this.submittedOnLine,
  });

  final String userRemarksBody;
  final String submittedViaLine;
  final String submittedByLine;
  final String submittedOnLine;

  @override
  State<_ViewNotesModal> createState() => _ViewNotesModalState();
}

class _ViewNotesModalState extends State<_ViewNotesModal> {
  bool _closeHover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'View Notes',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Notes and remarks for this record.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.muted.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(foregroundColor: AdminColors.headerTitle),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: Colors.black.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'User Remarks',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.userRemarksBody,
                    style: TextStyle(fontSize: 14, height: 1.5, color: AdminColors.headerTitle.withValues(alpha: 0.92)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.submittedViaLine,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AdminColors.muted.withValues(alpha: 0.88)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Submitted By',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.submittedByLine,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminColors.headerTitle),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Submitted On',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.submittedOnLine,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AdminColors.headerTitle),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              child: Align(
                alignment: Alignment.centerRight,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _closeHover = true),
                  onExit: (_) => setState(() => _closeHover = false),
                  cursor: SystemMouseCursors.click,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      foregroundColor: AdminColors.headerTitle,
                      side: BorderSide(color: Colors.black.withValues(alpha: _closeHover ? 0.22 : 0.14)),
                      backgroundColor: _closeHover ? const Color(0xFFF3F6FB) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
