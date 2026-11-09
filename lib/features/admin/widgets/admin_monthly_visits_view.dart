import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../services/monthly_visits_service.dart';
import '../theme/admin_theme.dart';

/// Read-only list of monthly visits for staff (Records / Submissions tab).
/// Shows each visit a Diver submitted, plus assigned sites with no visit in
/// the chosen month. Nothing here writes to the database.
class AdminMonthlyVisitsView extends StatefulWidget {
  const AdminMonthlyVisitsView({super.key, this.load, this.now});

  /// For tests; defaults to [MonthlyVisitsApi.load].
  final Future<MonthlyVisitsData> Function()? load;

  /// For tests; defaults to the current Philippine month.
  final DateTime? now;

  @override
  State<AdminMonthlyVisitsView> createState() => _AdminMonthlyVisitsViewState();
}

class _AdminMonthlyVisitsViewState extends State<AdminMonthlyVisitsView> {
  static const _allMonths = 'All months';
  static const _allSites = 'All Sites';

  late Future<MonthlyVisitsData> _future;
  late final DateTime _thisMonth;
  String _month = '';
  String _site = _allSites;

  @override
  void initState() {
    super.initState();
    final now = widget.now ??
        DateTime.now().toUtc().add(const Duration(hours: 8)); // Manila
    _thisMonth = DateTime(now.year, now.month);
    _month = _monthLabel(_thisMonth);
    _reload();
  }

  void _reload() {
    _future = (widget.load ?? MonthlyVisitsApi.load)();
  }

  static String _plural(int n, String word) =>
      '$n ${n == 1 ? word : '${word}s'}';

  static String _monthLabel(DateTime m) => DateFormat('MMMM yyyy').format(m);

  List<DateTime> _monthOptions(MonthlyVisitsData data) {
    final set = <DateTime>{
      for (var i = 0; i < 12; i++) DateTime(_thisMonth.year, _thisMonth.month - i),
      ...data.months,
    };
    return set.toList()..sort((a, b) => b.compareTo(a));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonthlyVisitsData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError || snap.data == null) {
          return _card(
            child: Column(
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 40, color: AdminColors.muted),
                const SizedBox(height: 8),
                const Text('Could not load monthly visits.',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AdminColors.headerTitle)),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        final data = snap.data!;
        final months = _monthOptions(data);
        final monthLabels = [
          for (final m in months) _monthLabel(m),
          _allMonths,
        ];
        if (!monthLabels.contains(_month)) _month = _monthLabel(_thisMonth);
        final sites = [_allSites, ...data.siteNames];
        if (!sites.contains(_site)) _site = _allSites;

        final selectedMonth = _month == _allMonths
            ? null
            : months.firstWhere((m) => _monthLabel(m) == _month);
        final rows = data.rowsFor(selectedMonth,
            site: _site == _allSites ? null : _site);
        final visits = rows.where((r) => !r.missing).length;
        final missing = rows.where((r) => r.missing).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _drop('visits-month-filter', monthLabels, _month,
                      (v) => setState(() => _month = v)),
                  _drop('visits-site-filter', sites, _site,
                      (v) => setState(() => _site = v)),
                  OutlinedButton.icon(
                    onPressed: () => setState(_reload),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Refresh'),
                  ),
                  Text(
                    selectedMonth == null
                        ? _plural(visits, 'visit')
                        : '${_plural(visits, 'visit')} · '
                            '${_plural(missing, 'site')} with no visit',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _card(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: rows.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: Text('No monthly visits for this filter.',
                            style: TextStyle(color: AdminColors.muted)),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < rows.length; i++) ...[
                          if (i > 0)
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          _VisitTile(row: rows[i]),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _drop(String key, List<String> options, String value,
      ValueChanged<String> onChanged) {
    return SizedBox(
      width: 190,
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: ValueKey(key),
              value: value,
              isExpanded: true,
              dropdownColor: Colors.white,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.headerTitle),
              items: [
                for (final o in options)
                  DropdownMenuItem(
                      value: o,
                      child: Text(o, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ),
    );
  }

  static Widget _card({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        padding: padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.row});

  final MonthlyVisitRow row;

  Color get _color => switch (row.statusLabel) {
        'Completed' => AdminColors.statGreen,
        'Waiting for Expert' => AdminColors.statYellow,
        'Needs correction' => AdminColors.statRed,
        'No visit' => AdminColors.statRed,
        _ => AdminColors.statBlue,
      };

  @override
  Widget build(BuildContext context) {
    final date = row.date;
    final cots = row.cotsCounted;
    final details = [
      row.diverName,
      if (date != null) DateFormat('MMM d, yyyy').format(date),
      if (cots != null) '$cots COTS',
      if (row.waiting > 0) '${row.waiting} waiting for Expert',
    ].join(' · ');
    return InkWell(
      onTap: row.missing ? null : () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              row.missing
                  ? Icons.event_busy_outlined
                  : Icons.event_available_outlined,
              color: _color,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.siteName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.headerTitle)),
                  const SizedBox(height: 2),
                  Text(details,
                      style: const TextStyle(
                          fontSize: 12.5, color: AdminColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(row.statusLabel,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _color)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final s = row.survey!;
    String whole(double? v) => v == null ? '—' : v.toStringAsFixed(0);
    final lines = <(String, String)>[
      ('Site', row.siteName),
      ('Diver', row.diverName),
      ('Visit date', DateFormat('MMM d, yyyy').format(s.surveyDate)),
      ('Status', row.statusLabel),
      ('COTS seen (Diver count)', '${s.fieldObservedCount}'),
      ('COTS confirmed', '${s.confirmedCount ?? '—'}'),
      if ((s.waitingCount ?? 0) > 0)
        ('Waiting for Expert', '${s.waitingCount}'),
      ('COTS removed', '${s.fieldEliminatedCount}'),
      if (s.eliminationMethod.trim().isNotEmpty)
        ('Removal method', s.eliminationMethod),
      ('Photos', '${s.captureIds.length}'),
      if (s.surveyedAreaSquareMeters != null)
        ('Surveyed area (m²)', whole(s.surveyedAreaSquareMeters)),
      if (s.earlyVisitNote != null) ('Note', s.earlyVisitNote!),
      if (s.notes.trim().isNotEmpty) ('Diver notes', s.notes.trim()),
    ];
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly visit'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, value) in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 13, color: AdminColors.muted)),
                      ),
                      Expanded(
                        child: Text(value,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.headerTitle)),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close')),
        ],
      ),
    );
  }
}
