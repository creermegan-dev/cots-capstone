import 'package:flutter/material.dart';

import '../../../models/scan_record_model.dart';
import '../../../services/scan_record_repository.dart';
import '../../../widgets/cots_loading_skeleton.dart';
import '../../../widgets/monitoring_record_map.dart';
import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';

class AdminMapMonitoringScreen extends StatefulWidget {
  const AdminMapMonitoringScreen({super.key});

  @override
  State<AdminMapMonitoringScreen> createState() =>
      _AdminMapMonitoringScreenState();
}

class _AdminMapMonitoringScreenState extends State<AdminMapMonitoringScreen> {
  late Stream<List<ScanRecordModel>> _recordsStream;

  @override
  void initState() {
    super.initState();
    _recordsStream = ScanRecordRepository.watchAll();
  }

  void _refresh() {
    setState(() => _recordsStream = ScanRecordRepository.watchAll());
  }

  @override
  Widget build(BuildContext context) {
    final pagePadding =
        AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);
    return StreamBuilder<List<ScanRecordModel>>(
      stream: _recordsStream,
      builder: (context, snapshot) {
        return SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(pagePadding.left, 22, pagePadding.right, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminDashboardHeader(
                title: 'Map Monitoring',
                subtitle: 'Saved monitoring locations from real field records.',
                onRefreshTap: _refresh,
              ),
              const SizedBox(height: 18),
              if (snapshot.hasError)
                _errorCard(snapshot.error)
              else if (!snapshot.hasData)
                const CotsLoadingSkeleton(
                  layout: CotsSkeletonLayout.detail,
                  label: 'Loading monitoring locations',
                )
              else ...[
                _summary(snapshot.data!),
                const SizedBox(height: 14),
                MonitoringRecordMap(records: snapshot.data!),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _summary(List<ScanRecordModel> records) {
    final located = records
        .where((record) => record.latitude != null && record.longitude != null)
        .toList();
    final zones = located
        .map((record) => record.zone)
        .where((zone) => zone.isNotEmpty && zone != 'Unassigned')
        .toSet();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _summaryCard('Saved records', '${records.length}', Icons.description),
        _summaryCard(
            'Mapped records', '${located.length}', Icons.location_on_outlined),
        _summaryCard('Monitoring areas', '${zones.length}', Icons.map_outlined),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AdminColors.statBlue),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: AdminColors.muted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorCard(Object? error) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 42, color: AdminColors.statRed),
          const SizedBox(height: 10),
          const Text('Could not load monitoring records.'),
          TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
