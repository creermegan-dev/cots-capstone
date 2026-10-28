import 'package:flutter/material.dart';

import '../../../services/scan_record_repository.dart';
import '../../../widgets/cots_loading_skeleton.dart';
import '../layout/admin_breakpoints.dart';
import '../models/admin_record_table_row.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import 'admin_record_details_screen.dart';

class AdminAlertsScreen extends StatefulWidget {
  const AdminAlertsScreen({super.key});

  @override
  State<AdminAlertsScreen> createState() => _AdminAlertsScreenState();
}

class _AdminAlertsScreenState extends State<AdminAlertsScreen> {
  late Stream<List<AdminRecordTableRow>> _recordsStream;

  @override
  void initState() {
    super.initState();
    _recordsStream = ScanRecordRepository.watchAdminTableRows();
  }

  void _refresh() {
    setState(() => _recordsStream = ScanRecordRepository.watchAdminTableRows());
  }

  @override
  Widget build(BuildContext context) {
    final padding =
        AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);
    return StreamBuilder<List<AdminRecordTableRow>>(
      stream: _recordsStream,
      builder: (context, snapshot) {
        final alerts = snapshot.hasData
            ? snapshot.data!.where(_requiresAttention).toList()
            : <AdminRecordTableRow>[];
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(padding.left, 22, padding.right, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardHeader(
                title: 'Alerts',
                subtitle:
                    'Records requiring expert review, retake, or immediate attention.',
                onRefreshTap: _refresh,
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                _stateCard('Could not load record alerts.', retry: _refresh)
              else if (!snapshot.hasData)
                const CotsLoadingSkeleton(
                  layout: CotsSkeletonLayout.list,
                  label: 'Loading record alerts',
                )
              else if (alerts.isEmpty)
                _stateCard('No records currently require attention.')
              else ...[
                _summary(alerts),
                const SizedBox(height: 14),
                for (var i = 0; i < alerts.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _AlertCard(
                    row: alerts[i],
                    onOpen: () => _open(alerts[i]),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  bool _requiresAttention(AdminRecordTableRow row) =>
      row.displayStatusLabel == 'Under Review' ||
      row.displayStatusLabel == 'Rejected';

  Widget _summary(List<AdminRecordTableRow> rows) {
    final review =
        rows.where((row) => row.displayStatusLabel == 'Under Review').length;
    final rejected =
        rows.where((row) => row.displayStatusLabel == 'Rejected').length;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _countCard('Total alerts', rows.length, AdminColors.statBlue),
        _countCard('Needs review', review, AdminColors.statYellow),
        _countCard('Rejected / retake', rejected, AdminColors.statRed),
      ],
    );
  }

  Widget _countCard(String label, int value, Color color) => Container(
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Text('$label: $value',
            style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      );

  Future<void> _open(AdminRecordTableRow row) async {
    await Navigator.of(context).push<AdminRecordTableRow?>(
      MaterialPageRoute<AdminRecordTableRow?>(
        builder: (_) => AdminRecordDetailsScreen(row: row),
      ),
    );
  }

  Widget _stateCard(String message, {VoidCallback? retry}) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            if (retry != null)
              TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
          ],
        ),
      );
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.row, required this.onOpen});
  final AdminRecordTableRow row;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final rejected = row.displayStatusLabel == 'Rejected';
    final color = rejected ? AdminColors.statRed : AdminColors.statYellow;
    final title = rejected
        ? 'Retake or rejected detection'
        : 'Expert verification required';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AdminColors.headerTitle)),
                    const SizedBox(height: 4),
                    Text(
                      '${row.recordId} · ${row.zone} · ${row.displayAiCount} AI detections · ${row.confidencePercent}% confidence',
                      style: const TextStyle(color: AdminColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
