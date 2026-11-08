import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/davao_gulf_geography.dart';
import '../../../models/monitoring_analytics.dart';
import '../../../models/scan_record_model.dart';
import '../../../models/zone_directory_summary.dart';
import '../../../services/scan_record_repository.dart';
import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_stat_card.dart';

enum _ZoneSort {
  site('Site order'),
  name('Site name A–Z'),
  reports('Most reports'),
  confirmed('Most confirmed COTS'),
  pending('Most pending reviews'),
  latest('Latest report');

  const _ZoneSort(this.label);
  final String label;
}

class AdminZonesScreen extends StatefulWidget {
  const AdminZonesScreen({super.key, this.recordsStream});
  final Stream<List<ScanRecordModel>>? recordsStream;
  @override
  State<AdminZonesScreen> createState() => _AdminZonesScreenState();
}

class _AdminZonesScreenState extends State<AdminZonesScreen> {
  final _search = TextEditingController();
  late Stream<List<ScanRecordModel>> _recordsStream;
  String _site = '';
  String _reportStatus = 'All report statuses';
  _ZoneSort _sort = _ZoneSort.site;
  int _page = 0;
  static const _pageSize = 6;
  static const _columns = [
    AdminDataTableColumn('Site', 235),
    AdminDataTableColumn('Location', 200),
    AdminDataTableColumn('Site group', 90),
    AdminDataTableColumn('Reports', 75),
    AdminDataTableColumn('Confirmed COTS', 130),
    AdminDataTableColumn('Pending review', 120),
    AdminDataTableColumn('Latest report', 185),
    AdminDataTableColumn('Action', 120),
  ];

  @override
  void initState() {
    super.initState();
    _recordsStream = widget.recordsStream ?? ScanRecordRepository.watchAll();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {
        _recordsStream =
            widget.recordsStream ?? ScanRecordRepository.watchAll();
      });
  void _filterChanged() => setState(() => _page = 0);

  int _compareSites(SiteDirectorySummary a, SiteDirectorySummary b) {
    final int comparison;
    switch (_sort) {
      case _ZoneSort.site:
        comparison = a.site.index.compareTo(b.site.index);
      case _ZoneSort.name:
        comparison = a.site.displayName
            .toLowerCase()
            .compareTo(b.site.displayName.toLowerCase());
      case _ZoneSort.reports:
        comparison = b.reports.compareTo(a.reports);
      case _ZoneSort.confirmed:
        comparison = (a.reports == 0) != (b.reports == 0)
            ? (a.reports == 0 ? 1 : -1)
            : b.analytics.accepted.compareTo(a.analytics.accepted);
      case _ZoneSort.pending:
        comparison = b.analytics.pendingSubmissionCount
            .compareTo(a.analytics.pendingSubmissionCount);
      case _ZoneSort.latest:
        final aDate = a.latestReport;
        final bDate = b.latestReport;
        comparison = aDate == null
            ? (bDate == null ? 0 : 1)
            : bDate == null
                ? -1
                : bDate.compareTo(aDate);
    }
    return comparison != 0 ? comparison : a.site.index.compareTo(b.site.index);
  }

  @override
  Widget build(BuildContext context) {
    final padding =
        AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width);
    return StreamBuilder<List<ScanRecordModel>>(
        stream: _recordsStream,
        builder: (context, snapshot) {
          final available = snapshot.hasData && !snapshot.hasError;
          final records = available ? snapshot.data! : <ScanRecordModel>[];
          final rows = SiteDirectorySummary.fromRecords(records);
          final analytics = MonitoringAnalytics.fromRecords(records);
          final unmatched = analytics.submissionCount -
              rows.fold<int>(0, (n, row) => n + row.reports);
          final query = _search.text.trim().toLowerCase();
          final visible = rows
              .where((row) =>
                  (_site.isEmpty || row.site.id == _site) &&
                  ('${row.site.displayName} ${row.site.municipalityName} ${row.site.zoneLabel}'
                      .toLowerCase()
                      .contains(query)) &&
                  (!available ||
                      _reportStatus == 'All report statuses' ||
                      (_reportStatus == 'With reports'
                          ? row.reports > 0
                          : row.reports == 0)))
              .toList()
            ..sort(_compareSites);
          final pages = (visible.length / _pageSize).ceil().clamp(1, 1000);
          final page = _page.clamp(0, pages - 1);
          final pageRows =
              visible.skip(page * _pageSize).take(_pageSize).toList();
          return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(padding.left, 22, padding.right, 28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminDashboardHeader(
                        title: 'Monitoring Sites',
                        subtitle:
                            'The 3 dive sites in Samal and their reports.',
                        onRefreshTap: _refresh),
                    const SizedBox(height: 18),
                    LayoutBuilder(builder: (context, c) {
                      final columns = c.maxWidth >= 1000
                          ? 4
                          : c.maxWidth >= 520
                              ? 2
                              : 1;
                      final width = (c.maxWidth - 12 * (columns - 1)) / columns;
                      return Wrap(spacing: 12, runSpacing: 12, children: [
                        _stat(
                            width,
                            'Total sites',
                            '${rows.length}',
                            'Defined on the monitoring map',
                            Icons.map_outlined,
                            AdminColors.statBlue),
                        _stat(
                            width,
                            'Practice sites',
                            '${rows.where((row) => row.site.zoneCode == 'PRACTICE').length}',
                            'Temporary testing locations',
                            Icons.location_on_outlined,
                            AdminColors.statGreen),
                        _stat(
                            width,
                            'Sites with reports',
                            available
                                ? '${rows.where((row) => row.reports > 0).length}'
                                : '—',
                            'Sites with saved captures',
                            Icons.description_outlined,
                            AdminColors.statPurple),
                        _stat(
                            width,
                            'Pending review',
                            available
                                ? '${analytics.pendingSubmissionCount}'
                                : '—',
                            'Reports awaiting expert review',
                            Icons.schedule_outlined,
                            AdminColors.statYellow),
                      ]);
                    }),
                    const SizedBox(height: 18),
                    if (!available) ...[
                      Text(snapshot.hasError
                          ? 'Could not load reports. Site definitions remain available; report totals are unavailable.'
                          : 'Loading report totals…'),
                      if (snapshot.hasError)
                        TextButton(
                            onPressed: _refresh, child: const Text('Retry')),
                      const SizedBox(height: 12),
                    ],
                    LayoutBuilder(
                        builder: (context, c) =>
                            Wrap(spacing: 12, runSpacing: 12, children: [
                              SizedBox(
                                  width: c.maxWidth < 350 ? c.maxWidth : 350,
                                  child: TextField(
                                    controller: _search,
                                    onChanged: (_) => _filterChanged(),
                                    textInputAction: TextInputAction.search,
                                    onSubmitted: (_) {
                                      _filterChanged();
                                      FocusScope.of(context).unfocus();
                                    },
                                    decoration: const InputDecoration(
                                        hintText: 'Search site or location…',
                                        prefixIcon: Icon(Icons.search_rounded),
                                        filled: true,
                                        fillColor: Colors.white),
                                  )),
                              SizedBox(
                                  width: c.maxWidth < 250 ? c.maxWidth : 250,
                                  child: DropdownButtonFormField<String>(
                                    key:
                                        const ValueKey('directory-site-filter'),
                                    initialValue: _site,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Dive site',
                                        filled: true,
                                        fillColor: Colors.white),
                                    items: [
                                      const DropdownMenuItem(
                                          value: '', child: Text('All sites')),
                                      for (final row in rows)
                                        DropdownMenuItem(
                                            value: row.site.id,
                                            child: Text(row.site.displayName,
                                                overflow:
                                                    TextOverflow.ellipsis))
                                    ],
                                    onChanged: (value) {
                                      _site = value!;
                                      _filterChanged();
                                    },
                                  )),
                              SizedBox(
                                  width: c.maxWidth < 220 ? c.maxWidth : 220,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _reportStatus,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Report status',
                                        filled: true,
                                        fillColor: Colors.white),
                                    items: [
                                      for (final status in [
                                        'All report statuses',
                                        'With reports',
                                        'No reports'
                                      ])
                                        DropdownMenuItem(
                                            value: status, child: Text(status))
                                    ],
                                    onChanged: available
                                        ? (value) {
                                            _reportStatus = value!;
                                            _filterChanged();
                                          }
                                        : null,
                                  )),
                              SizedBox(
                                width: c.maxWidth < 240 ? c.maxWidth : 240,
                                child: DropdownButtonFormField<_ZoneSort>(
                                  key: const ValueKey('zone-sort'),
                                  initialValue: _sort,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Sort by',
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: [
                                    for (final sort in _ZoneSort.values)
                                      DropdownMenuItem(
                                          value: sort, child: Text(sort.label)),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    _sort = value;
                                    _filterChanged();
                                  },
                                ),
                              ),
                            ])),
                    const SizedBox(height: 16),
                    Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Site directory',
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: AdminColors.headerTitle)),
                              const SizedBox(height: 6),
                              const Text(
                                  'Sites remain listed even without reports. Temporary practice sites are included. Totals count submissions; each photo keeps its own evidence.',
                                  style: TextStyle(color: AdminColors.muted)),
                              const SizedBox(height: 14),
                              AdminDataTableScrollArea(
                                  horizontalPadding: 0,
                                  tableWidth:
                                      AdminDataTableColumn.totalWidth(_columns),
                                  child: Column(children: [
                                    const AdminDataTableHeader(
                                        columns: _columns),
                                    for (final row in pageRows)
                                      AdminDataTableStaticRow(
                                          showShadow: false,
                                          columnWidths:
                                              AdminDataTableColumn.widthsMap(
                                                  _columns),
                                          cells: [
                                            _cell(row.site.displayName),
                                            _cell(row.site.municipalityName),
                                            _cell(row.site.zoneLabel),
                                            _cell(available
                                                ? '${row.reports}'
                                                : '—'),
                                            _cell(available && row.reports > 0
                                                ? '${row.analytics.accepted}'
                                                : '—'),
                                            _cell(available
                                                ? '${row.analytics.pendingSubmissionCount}'
                                                : '—'),
                                            _cell(!available
                                                ? 'Unavailable'
                                                : row.reports == 0
                                                    ? 'No reports yet'
                                                    : row.latestReport == null
                                                        ? 'Date unavailable'
                                                        : DateFormat(
                                                                'MMM d, yyyy · h:mm a')
                                                            .format(row
                                                                .latestReport!
                                                                .toLocal())),
                                            TableCell(
                                                child: TextButton(
                                                    onPressed: () =>
                                                        _showSite(row.site),
                                                    child: const Text(
                                                        'View site'))),
                                          ]),
                                  ])),
                              if (visible.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.all(24),
                                    child:
                                        Text('No sites match your filters.')),
                              AdminDataTablePaginationBar(
                                  summaryText:
                                      'Showing ${visible.isEmpty ? 0 : page * _pageSize + 1}–${page * _pageSize + pageRows.length} of ${visible.length} sites',
                                  pageIndex: page,
                                  pageCount: pages,
                                  onPageSelected: (value) =>
                                      setState(() => _page = value)),
                              const Text(
                                  'No reports means not assessed. “—” does not mean zero COTS.',
                                  style: TextStyle(color: AdminColors.muted)),
                              if (available && unmatched > 0)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                        '$unmatched capture report(s) have no recognized site. They remain available in Records / Submissions.')),
                            ])),
                  ]));
        });
  }

  Widget _stat(double width, String title, String value, String subtitle,
          IconData icon, Color color) =>
      SizedBox(
          width: width,
          child: AdminStatCard(
              title: title,
              value: value,
              subtitle: subtitle,
              icon: icon,
              accentColor: color));
  TableCell _cell(String value) => TableCell(
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Text(value, style: AdminDataTableTokens.bodyTextStyle())));

  void _showSite(GulfCoastalBarangay site) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(site.displayName),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(site.municipalityName),
            const SizedBox(height: 12),
            Text(
                'Barangay ${site.name} · ${site.reefHectares.toStringAsFixed(0)} ha'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }
}
