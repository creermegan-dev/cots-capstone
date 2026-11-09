import 'package:flutter/material.dart';

import '../../../models/scan_record_model.dart';
import '../../../models/submission_group.dart';
import '../../../models/zone_directory_summary.dart';
import '../../../services/scan_record_repository.dart';
import '../../../widgets/cots_loading_skeleton.dart';
import '../widgets/map_monitoring/admin_zone_monitoring_map.dart';
import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_stat_card.dart';

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
                AdminZoneMonitoringMap(records: snapshot.data!),
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
    final zones = SiteDirectorySummary.fromRecords(located)
        .where((row) => row.reports > 0)
        .toList();
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 3
          : constraints.maxWidth >= 520
              ? 2
              : 1;
      final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: AdminStatCard(
              title: 'Saved submissions',
              value: '${SubmissionGroup.fromRecords(records).length}',
              subtitle: 'Saved field submissions',
              icon: Icons.description_outlined,
              accentColor: AdminColors.statBlue,
            ),
          ),
          SizedBox(
            width: width,
            child: AdminStatCard(
              title: 'Mapped photos',
              value: '${located.length}',
              subtitle: 'Photos with original saved coordinates',
              icon: Icons.location_on_outlined,
              accentColor: AdminColors.statGreen,
            ),
          ),
          SizedBox(
            width: width,
            child: AdminStatCard(
              title: 'Monitoring sites',
              value: '${zones.length}',
              subtitle: 'Sites represented in mapped captures',
              icon: Icons.map_outlined,
              accentColor: AdminColors.statPurple,
            ),
          ),
        ],
      );
    });
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
