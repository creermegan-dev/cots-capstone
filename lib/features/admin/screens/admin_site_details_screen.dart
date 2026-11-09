import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../models/davao_gulf_geography.dart';
import '../../../models/scan_record_model.dart';
import '../../../models/zone_directory_summary.dart';
import '../../../models/submission_group.dart';
import '../../../services/scan_record_repository.dart';
import '../../../services/site_levels_service.dart';
import '../../../utils/staff_record_time.dart';
import '../../user/cots_map_page.dart';
import '../../user/user_submission_details_page.dart';
import '../theme/admin_theme.dart';

/// Read-only site information using the same saved records and monthly levels.
class AdminSiteDetailsScreen extends StatefulWidget {
  const AdminSiteDetailsScreen(
      {super.key,
      required this.site,
      this.recordsStream,
      this.levelsApi = const SiteLevelsApi()});
  final GulfCoastalBarangay site;
  final Stream<List<ScanRecordModel>>? recordsStream;
  final SiteLevelsApi levelsApi;
  @override
  State<AdminSiteDetailsScreen> createState() => _AdminSiteDetailsScreenState();
}

class _AdminSiteDetailsScreenState extends State<AdminSiteDetailsScreen> {
  late Stream<List<ScanRecordModel>> _records =
      widget.recordsStream ?? ScanRecordRepository.watchAll();
  Future<List<SiteLevel>>? _history;
  void _refresh() => setState(() {
        _records = widget.recordsStream ?? ScanRecordRepository.watchAll();
        _history = null;
      });
  Color _color(String? level) => switch (level) {
        'Low' => AdminColors.statGreen,
        'Moderate' => AdminColors.statYellow,
        'High' => AdminColors.statRed,
        _ => AdminColors.muted,
      };
  Widget _card(String title, Widget child) => Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.headerTitle)),
            const SizedBox(height: 14),
            child,
          ])));
  Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(spacing: 12, runSpacing: 4, children: [
        SizedBox(
            width: 160,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 13, color: AdminColors.muted))),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ]));
  String _date(DateTime? when) => when == null
      ? 'No reports yet'
      : DateFormat('MMM d, yyyy h:mm a').format(StaffRecordTime.inManila(when));

  Widget _trend(List<SiteLevel> levels) {
    final known = levels
        .where((level) => level.month != null && level.level != null)
        .toList()
      ..sort((a, b) => a.month!.compareTo(b.month!));
    if (known.isEmpty) {
      return const Text('No monthly site levels in the last six months.');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Confirmed COTS per calendar month',
          style: TextStyle(color: AdminColors.muted, fontSize: 12)),
      const SizedBox(height: 18),
      SizedBox(
          height: 215,
          child: BarChart(BarChartData(
            minY: 0,
            borderData: FlBorderData(show: false),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 34)),
              bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        return i < 0 || i >= known.length
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                    DateFormat('MMM yy')
                                        .format(known[i].month!),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 10)));
                      })),
            ),
            barGroups: [
              for (var i = 0; i < known.length; i++)
                BarChartGroupData(x: i, barRods: [
                  BarChartRodData(
                      toY: known[i].confirmedCots.toDouble(),
                      width: 24,
                      color: _color(known[i].level),
                      borderRadius: BorderRadius.circular(4))
                ])
            ],
          ))),
      const SizedBox(height: 10),
      const Text('Months without reports are not treated as zero COTS.',
          style: TextStyle(fontSize: 12, color: AdminColors.muted)),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AdminColors.contentBg,
        appBar: AppBar(title: const Text('Site Details'), actions: [
          IconButton(
              onPressed: _refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh))
        ]),
        body: StreamBuilder<List<ScanRecordModel>>(
            stream: _records,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                    child: TextButton(
                        onPressed: _refresh,
                        child:
                            const Text('Could not load site records. Retry')));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final records = snapshot.data!
                  .where((record) =>
                      SiteDirectorySummary.siteIdFor(record) == widget.site.id)
                  .toList();
              final summary = SiteDirectorySummary(widget.site, records);
              final groups =
                  SubmissionGroup.fromRecords(summary.analytics.captures);
              return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(builder: (context, size) {
                          final details = _card(
                              widget.site.displayName,
                              Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(widget.site.municipalityName),
                                    _line('Barangay', widget.site.name),
                                    _line('Site size',
                                        '${widget.site.reefHectares.toStringAsFixed(0)} ha'),
                                    _line('Submissions', '${summary.reports}'),
                                    _line('Confirmed COTS (all time)',
                                        '${summary.analytics.accepted}'),
                                    _line('Waiting COTS',
                                        '${summary.analytics.pending}'),
                                    _line('Latest report',
                                        _date(summary.latestReport)),
                                  ]));
                          final map = _card(
                              'Site location',
                              SizedBox(
                                  height: 520 +
                                      160 *
                                          (MediaQuery.textScalerOf(context)
                                                      .scale(1) -
                                                  1)
                                              .clamp(0, 1),
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CotsMapPage(
                                        embedded: true,
                                        diverStyle: true,
                                        initialCenter: widget.site.centroid,
                                        initialZoom: 15,
                                        records: records,
                                        onOpenRecord: (record) {
                                          final group = groups.firstWhere((g) =>
                                              g.records.any((r) =>
                                                  r.id == record.id &&
                                                  r.recordCollection ==
                                                      record.recordCollection));
                                          Navigator.of(context).push<void>(
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      UserSubmissionDetailsPage(
                                                          initialGroup: group,
                                                          includePendingPhotos:
                                                              false,
                                                          useReadOnlyLayout:
                                                              true)));
                                        },
                                      ))));
                          return size.maxWidth < 950
                              ? Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                      details,
                                      const SizedBox(height: 16),
                                      map
                                    ])
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Expanded(flex: 4, child: details),
                                      const SizedBox(width: 16),
                                      Expanded(flex: 6, child: map)
                                    ]);
                        }),
                        const SizedBox(height: 16),
                        FutureBuilder<List<SiteLevel>>(
                            future: _history ??=
                                widget.levelsApi.history(months: 6),
                            builder: (context, history) {
                              if (history.hasError) {
                                return _card(
                                    'Monthly site levels',
                                    const Text(
                                        'Monthly levels unavailable. Use Refresh to try again.'));
                              }
                              if (!history.hasData) {
                                return _card('Monthly site levels',
                                    const LinearProgressIndicator());
                              }
                              final levels = history.data!
                                  .where((s) => s.areaCode == widget.site.id)
                                  .toList()
                                ..sort((a, b) => (b.month ?? DateTime(1970))
                                    .compareTo(a.month ?? DateTime(1970)));
                              final latest = levels
                                  .where(
                                      (s) => s.level != null && s.month != null)
                                  .firstOrNull;
                              return _card(
                                  'Monthly confirmed-COTS trend',
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (latest != null) ...[
                                          Text(
                                              '${latest.level} · ${latest.confirmedCots} confirmed COTS · ${MonthlySiteLevel.monthLabel(latest.month!)}',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: _color(latest.level))),
                                          const SizedBox(height: 16),
                                        ],
                                        _trend(levels),
                                        const SizedBox(height: 12),
                                        const Text(
                                            'Low 0–15 · Moderate 16–100 · High 101+ confirmed COTS per site per month.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AdminColors.muted)),
                                      ]));
                            }),
                        const SizedBox(height: 16),
                        _card(
                            'Recent monitoring records',
                            groups.isEmpty
                                ? const Text(
                                    'No saved monitoring records for this site.')
                                : Column(children: [
                                    for (final group in groups.take(10))
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(group.displayId,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        subtitle: Text(
                                            '${group.records.first.submittedBy} · ${_date(group.latestSubmittedAt)}\n${group.photoCount} photo(s) · ${group.detectedCount} detected COTS · ${group.statusLabel()}'),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () => Navigator.of(context)
                                            .push<void>(MaterialPageRoute(
                                                builder: (_) =>
                                                    UserSubmissionDetailsPage(
                                                        initialGroup: group,
                                                        includePendingPhotos:
                                                            false,
                                                        useReadOnlyLayout:
                                                            true))),
                                      )
                                  ])),
                      ]));
            }),
      );
}
