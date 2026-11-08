import 'package:flutter/material.dart';

import '../../../../models/monitoring_analytics.dart';
import '../../../../models/scan_record_model.dart';
import '../../../../models/submission_group.dart';
import '../../../user/user_submission_details_page.dart';
import '../../screens/admin_record_details_screen.dart';
import '../../../user/cots_map_page.dart'
    show CotsMapPage, mappableRecords, recordDotMarker;
import '../../theme/admin_theme.dart';

/// The diver's site map, with only saved capture locations added for admin.
class AdminZoneMonitoringMap extends StatelessWidget {
  const AdminZoneMonitoringMap({super.key, required this.records});
  final List<ScanRecordModel> records;

  void _openRecord(BuildContext context, ScanRecordModel record) {
    final group = SubmissionGroup.fromRecords(records).firstWhere((group) =>
        group.records.any((photo) =>
            photo.id == record.id &&
            photo.uid == record.uid &&
            photo.recordCollection == record.recordCollection));
    Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => group.hasBatch
            ? UserSubmissionDetailsPage(
                initialGroup: group,
                includePendingPhotos: false,
                photoPageBuilder: (photo) => AdminRecordDetailsScreen(
                    row: photo.toAdminTableRow(1), viewOnly: true))
            : AdminRecordDetailsScreen(
                row: record.toAdminTableRow(1), viewOnly: true)));
  }

  @override
  Widget build(BuildContext context) {
    final captures = MonitoringAnalytics.fromRecords(records).captures;
    // Stage 13: the Admin sees every record as a dot (red confirmed,
    // orange waiting).
    final located = mappableRecords(records);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Dive sites & detections',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle)),
          const SizedBox(height: 8),
          const Text('The 3 dive sites in Samal — tap a site for its details.',
              style: TextStyle(color: AdminColors.muted)),
          if (located.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.statBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(captures.isEmpty
                  ? 'No saved detections yet. The dive sites are still shown.'
                  : 'No saved capture coordinates available. The dive sites are still shown.'),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 500,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CotsMapPage(
                embedded: true,
                recordMarkers: [
                  for (final record in located)
                    recordDotMarker(record,
                        onTap: () => _openRecord(context, record)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
