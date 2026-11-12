import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_config.dart';
import '../../../models/capture_model.dart';
import '../../../models/record_collection.dart';
import '../../../models/davao_gulf_geography.dart';
import '../../../models/user_model.dart';
import '../../../services/expert_dashboard_service.dart';
import '../../../services/expert_personnel_repository.dart';
import '../../../services/site_levels_service.dart';
import '../../../utils/staff_record_time.dart';
import '../../admin/layout/admin_breakpoints.dart';
import '../../admin/screens/admin_site_details_screen.dart';
import '../../admin/theme/admin_theme.dart';
import '../../admin/widgets/admin_stat_card.dart';
import '../models/expert_action_item.dart';
import 'expert_notifications_screen.dart';
import 'expert_users_screen.dart';

/// Read-only overview. All decisions remain on their existing Expert pages.
class ExpertDashboardScreen extends StatefulWidget {
  const ExpertDashboardScreen(
      {super.key,
      required this.actions,
      required this.onOpen,
      this.siteLevels,
      this.loadUsers,
      this.loadDecisions,
      this.onOpenPersonnel,
      this.onOpenNotifications,
      this.onOpenSite,
      this.now});

  final ExpertActionsController actions;
  final ValueChanged<ExpertActionPlace> onOpen;
  final Future<List<SiteLevel>> Function(DateTime month)? siteLevels;
  final Future<List<UserModel>> Function()? loadUsers;
  final Future<List<ExpertDashboardDecision>> Function()? loadDecisions;
  final VoidCallback? onOpenPersonnel, onOpenNotifications;
  final ValueChanged<SiteLevel>? onOpenSite;
  final DateTime? now;

  @override
  State<ExpertDashboardScreen> createState() => _ExpertDashboardScreenState();
}

class _ExpertDashboardScreenState extends State<ExpertDashboardScreen> {
  late final DateTime _month =
      MonthlySiteLevel.monthOf(widget.now ?? DateTime.now());
  late Future<List<UserModel>> _people;
  late Future<List<SiteLevel>> _sites;
  late Future<List<ExpertDashboardDecision>> _decisions;
  final _sitesKey = GlobalKey();
  bool _highOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<T> _read<T>(Future<T> Function() source,
      {bool injected = false}) async {
    if (!injected && !SupabaseConfig.isConfigured) {
      throw StateError('This information requires Supabase.');
    }
    return source().timeout(const Duration(seconds: 20));
  }

  void _load() {
    _people = _read(widget.loadUsers ?? ExpertPersonnelRepository.fetchUsers,
        injected: widget.loadUsers != null);
    _sites = _read(
        () => (widget.siteLevels ?? const SiteLevelsApi().monthLevels)(_month),
        injected: widget.siteLevels != null);
    _decisions = _read(
        widget.loadDecisions ?? const ExpertDashboardApi().recentDecisions,
        injected: widget.loadDecisions != null);
  }

  void _refresh() {
    setState(_load);
    unawaited(widget.actions.refresh());
  }

  void _personnel() => widget.onOpenPersonnel != null
      ? widget.onOpenPersonnel!()
      : unawaited(Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const ExpertUsersScreen())));
  void _notifications() => widget.onOpenNotifications != null
      ? widget.onOpenNotifications!()
      : unawaited(Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => ExpertNotificationsScreen(
              actions: widget.actions, onOpen: widget.onOpen))));

  Future<void> _openSite(SiteLevel level) async {
    if (widget.onOpenSite != null) {
      widget.onOpenSite!(level);
      return;
    }
    try {
      await DavaoGulfGeography.load();
      if (!mounted) return;
      final matches =
          DavaoGulfGeography.allBarangays.where((s) => s.id == level.areaCode);
      if (matches.isEmpty) throw StateError('Site boundary unavailable');
      await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => AdminSiteDetailsScreen(site: matches.first)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open this site. Please retry.')));
      }
    }
  }

  Color _levelColor(String? level) => switch (level) {
        'High' => AdminColors.statRed,
        'Moderate' => AdminColors.statYellow,
        'Low' => AdminColors.statGreen,
        _ => AdminColors.muted,
      };
  String _date(DateTime time) =>
      DateFormat('MMM d, yyyy · h:mm a').format(StaffRecordTime.inManila(time));
  List<UserModel> _pending(List<UserModel> people) => people
      .where((p) =>
          p.isActive && !p.isAdmin && !p.isExpert && !p.fieldPersonnelVerified)
      .toList();

  Widget _panel(String title, Widget child, {Widget? action}) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.headerTitle)),
              if (action != null) action
            ]),
        const SizedBox(height: 12),
        child,
      ]));
  Widget _message(String text) => Text(text,
      style: const TextStyle(fontSize: 13, color: AdminColors.muted));
  Widget _error(String text) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _message(text),
        TextButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry')),
      ]);
  Widget _entry(String title, String detail, IconData icon, Color color,
          String action, VoidCallback onTap,
          {Key? key}) =>
      Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: LayoutBuilder(builder: (context, constraints) {
            final text =
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    _message(detail),
                  ])),
            ]);
            final button = TextButton(onPressed: onTap, child: Text(action));
            if (constraints.maxWidth < 380 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    text,
                    Align(alignment: Alignment.centerRight, child: button)
                  ]);
            }
            return Row(children: [
              Expanded(child: text),
              const SizedBox(width: 8),
              button
            ]);
          }));

  Widget _attention(AsyncSnapshot<List<UserModel>> people) {
    final ready = widget.actions.loaded && widget.actions.errors.isEmpty;
    final items = ready
        ? widget.actions.items
            .where((i) => i.place != ExpertActionPlace.assessments)
            .toList()
        : <ExpertActionItem>[];
    final pending = _pending(people.data ?? []);
    return _panel(
        'Needs your attention',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!widget.actions.loaded ||
              people.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (widget.actions.errors.isNotEmpty)
            _error('Some review or coverage requests could not be loaded.'),
          if (people.hasError)
            _error('Personnel requests could not be loaded.'),
          for (final item in items
              .where((i) => i.place == ExpertActionPlace.verification)
              .take(2))
            _entry(
                item.title,
                item.detail,
                Icons.fact_check_outlined,
                AdminColors.statYellow,
                'Review',
                () => widget.onOpen(item.place)),
          if (!people.hasError && pending.isNotEmpty)
            _entry(
                'Personnel verification',
                '${pending.first.fullName} · Credentials awaiting verification',
                Icons.people_outline,
                AdminColors.statGreen,
                'Check',
                _personnel),
          for (final item in items
              .where((i) => i.place == ExpertActionPlace.reassignments)
              .take(2))
            _entry(item.title, item.detail, Icons.swap_horiz_rounded,
                AdminColors.statBlue, 'Open', () => widget.onOpen(item.place)),
          if (ready && people.hasData && items.isEmpty && pending.isEmpty)
            _message(
                'No pending work. Everything needing your attention will appear here.'),
        ]),
        action: TextButton(
            onPressed: _notifications, child: const Text('View all notices')));
  }

  Widget _recent(AsyncSnapshot<List<ExpertDashboardDecision>> decisions,
      AsyncSnapshot<List<UserModel>> people) {
    final entries = <({
      String title,
      String detail,
      DateTime time,
      Color color,
      VoidCallback open
    })>[
      if (!decisions.hasError)
        for (final d in decisions.data ?? <ExpertDashboardDecision>[])
          if (d.at != null)
            (
              title:
                  '${CaptureModel.formatDisplayRecordId(d.captureId)} · ${d.label}',
              detail: 'Expert record review',
              time: d.at!,
              color: d.decision == 'reject'
                  ? AdminColors.statRed
                  : AdminColors.statGreen,
              open: () => widget.onOpen(ExpertActionPlace.verification)
            ),
      if (!people.hasError)
        for (final p in people.data ?? <UserModel>[])
          if (!p.isAdmin &&
              !p.isExpert &&
              p.fieldPersonnelVerified &&
              p.personnelVerifiedAt != null)
            (
              title: 'Personnel verified',
              detail: p.fullName,
              time: p.personnelVerifiedAt!,
              color: AdminColors.statGreen,
              open: _personnel
            ),
    ]..sort((a, b) => b.time.compareTo(a.time));
    return _panel(
        'Recent decisions',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (decisions.connectionState == ConnectionState.waiting)
            const LinearProgressIndicator(),
          if (decisions.hasError)
            _error('Recent record decisions could not be loaded.'),
          if (people.hasError)
            _message('Personnel decision history is unavailable.'),
          if (entries.isEmpty && decisions.hasData && people.hasData)
            _message('No recent Expert decisions recorded.'),
          for (final entry in entries.take(5))
            _entry(entry.title, '${entry.detail}\n${_date(entry.time)}',
                Icons.check_circle_outline, entry.color, 'View', entry.open),
        ]));
  }

  Widget _siteOverview(AsyncSnapshot<List<SiteLevel>> snapshot) {
    final sites = (snapshot.data ?? [])
        .where((s) => !s.isPractice && (!_highOnly || s.level == 'High'))
        .toList()
      ..sort((a, b) => a.areaCode.compareTo(b.areaCode));
    return Container(
        key: _sitesKey,
        child: _panel(
            'Monthly site overview',
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _message(DateFormat('MMMM yyyy').format(_month)),
              if (_highOnly)
                TextButton(
                    onPressed: () => setState(() => _highOnly = false),
                    child: const Text('Show all sites')),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator()
              else if (snapshot.hasError)
                _error('Monthly site levels could not be loaded.')
              else if (sites.isEmpty)
                _message(_highOnly
                    ? 'No High-level sites this month.'
                    : 'No dive sites available.')
              else
                LayoutBuilder(builder: (context, constraints) {
                  final scale =
                      MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
                  return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowHeight: 56 * scale,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 120 * scale,
                          horizontalMargin: 8,
                          columnSpacing: 22,
                          columns: const [
                            DataColumn(label: Text('Site')),
                            DataColumn(label: Text('Confirmed COTS')),
                            DataColumn(label: Text('Site level')),
                            DataColumn(label: Text('Latest capture')),
                            DataColumn(label: Text('Action'))
                          ],
                          rows: [
                            for (final site in sites)
                              DataRow(cells: [
                                DataCell(Text(site.areaName)),
                                DataCell(Text(site.level == null
                                    ? '—'
                                    : '${site.confirmedCots}')),
                                DataCell(Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: _levelColor(site.level)
                                            .withValues(alpha: .12),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(site.level ?? 'No reports',
                                        style: TextStyle(
                                            color: _levelColor(site.level),
                                            fontWeight: FontWeight.w600)))),
                                DataCell(Text(_latestCapture(site))),
                                DataCell(TextButton(
                                    key: ValueKey(
                                        'expert-site-${site.areaCode}'),
                                    onPressed: () => _openSite(site),
                                    child: const Text('View site'))),
                              ])
                          ],
                        ),
                      ));
                }),
              const SizedBox(height: 10),
              _message(
                  'Levels count confirmed COTS this month. No reports does not mean zero COTS.'),
            ])));
  }

  String _latestCapture(SiteLevel site) {
    if (!widget.actions.loaded || widget.actions.errors.isNotEmpty) {
      return 'Unavailable';
    }
    DateTime? latest;
    for (final row in widget.actions.records) {
      if (row.recordCollection != RecordCollection.captures) continue;
      if (row.siteId != site.areaCode &&
          !(row.siteId.isEmpty && row.zone == site.areaName)) {
        continue;
      }
      if (row.serverStatus.isNotEmpty && row.serverStatus != 'finalized') {
        continue;
      }
      final taken = row.capturedAt;
      if (taken == null || MonthlySiteLevel.monthOf(taken) != _month) continue;
      if (latest == null || taken.isAfter(latest)) latest = taken;
    }
    return latest == null
        ? '—'
        : DateFormat('MMM d, yyyy').format(StaffRecordTime.inManila(latest));
  }

  Widget _body(
      AsyncSnapshot<List<UserModel>> people,
      AsyncSnapshot<List<SiteLevel>> sites,
      AsyncSnapshot<List<ExpertDashboardDecision>> decisions) {
    final actionsReady = widget.actions.loaded && widget.actions.errors.isEmpty;
    final siteData = (sites.data ?? []).where((s) => !s.isPractice);
    final cards = <Widget>[
      AdminStatCard(
          key: const ValueKey('expert-dashboard-review'),
          title: 'Records awaiting review',
          value: actionsReady
              ? '${widget.actions.items.where((i) => i.place == ExpertActionPlace.verification).length}'
              : '—',
          subtitle: 'Open Verification',
          icon: Icons.fact_check_outlined,
          accentColor: AdminColors.statYellow,
          onTap: () => widget.onOpen(ExpertActionPlace.verification)),
      AdminStatCard(
          key: const ValueKey('expert-dashboard-personnel'),
          title: 'Personnel to verify',
          value: people.hasData && !people.hasError
              ? '${_pending(people.data!).length}'
              : '—',
          subtitle: 'Check field credentials',
          icon: Icons.people_outline,
          accentColor: AdminColors.statGreen,
          onTap: _personnel),
      AdminStatCard(
          key: const ValueKey('expert-dashboard-coverage'),
          title: 'Coverage requests',
          value: actionsReady
              ? '${widget.actions.items.where((i) => i.place == ExpertActionPlace.reassignments).length}'
              : '—',
          subtitle: 'Open Site Coverage',
          icon: Icons.swap_horiz_rounded,
          accentColor: AdminColors.statBlue,
          onTap: () => widget.onOpen(ExpertActionPlace.reassignments)),
      AdminStatCard(
          key: const ValueKey('expert-dashboard-high'),
          title: 'High-level sites',
          value: sites.hasData && !sites.hasError
              ? '${siteData.where((s) => s.level == 'High').length}'
              : '—',
          subtitle: 'This month · view sites',
          icon: Icons.location_on_outlined,
          accentColor: AdminColors.statRed,
          onTap: () {
            setState(() => _highOnly = !_highOnly);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final target = _sitesKey.currentContext;
              if (target != null) unawaited(Scrollable.ensureVisible(target));
            });
          }),
    ];
    return SingleChildScrollView(
        padding: AdminBreakpoints.pagePadding(MediaQuery.sizeOf(context).width),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expert Dashboard',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AdminColors.headerTitle)),
                      SizedBox(height: 4),
                      Text('Review evidence and keep site monitoring on track.',
                          style: TextStyle(
                              fontSize: 13, color: AdminColors.muted)),
                    ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                      child: Text(DateFormat('MMMM yyyy').format(_month),
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(
                      onPressed: _notifications,
                      tooltip: 'Open Expert notifications',
                      icon: Badge(
                          isLabelVisible: widget.actions.count > 0,
                          label: Text('${widget.actions.count}'),
                          child: const Icon(Icons.notifications_outlined))),
                  IconButton(
                      onPressed: _refresh,
                      tooltip: 'Refresh Expert dashboard',
                      icon: const Icon(Icons.refresh)),
                ]),
              ]),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, c) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = c.maxWidth >= 1100 && scale <= 1.4
                ? 4
                : c.maxWidth >= 550 && scale <= 1.4
                    ? 2
                    : 1;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final card in cards)
                SizedBox(
                    width: (c.maxWidth - 12 * (columns - 1)) / columns,
                    child: card)
            ]);
          }),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, c) {
            final left = _attention(people), right = _recent(decisions, people);
            if (c.maxWidth < 1000 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.4) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [left, const SizedBox(height: 16), right]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: right)
            ]);
          }),
          const SizedBox(height: 18),
          _siteOverview(sites),
        ]));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<UserModel>>(
      future: _people,
      builder: (context, people) => FutureBuilder<List<SiteLevel>>(
          future: _sites,
          builder: (context, sites) =>
              FutureBuilder<List<ExpertDashboardDecision>>(
                  future: _decisions,
                  builder: (context, decisions) => ListenableBuilder(
                      listenable: widget.actions,
                      builder: (context, _) =>
                          _body(people, sites, decisions)))));
}
