import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/cots_colors.dart';
import '../core/user_shell_theme.dart' show kLow, kModerate, kHigh;
import '../models/davao_gulf_geography.dart';
import '../services/site_levels_service.dart';

/// Analytics (2026-11-08): each dive site's level per month, from the
/// confirmed COTS recorded there (0-15 Low, 16-100 Moderate, over 100 High).
/// Practice sites are left out.
class MonthlySiteLevelsCard extends StatefulWidget {
  const MonthlySiteLevelsCard({super.key, this.history, this.months = 6});

  /// Tests replace the data source.
  final Future<List<SiteLevel>> Function()? history;
  final int months;

  @override
  State<MonthlySiteLevelsCard> createState() => _MonthlySiteLevelsCardState();
}

class _MonthlySiteLevelsCardState extends State<MonthlySiteLevelsCard> {
  late Future<List<SiteLevel>> _data = _load();

  Future<List<SiteLevel>> _load() => widget.history != null
      ? widget.history!()
      : const SiteLevelsApi().history(months: widget.months);

  static Color _color(String? level) => switch (level) {
        'Low' => kLow,
        'Moderate' => kModerate,
        'High' => kHigh,
        _ => const Color(0xFF9CA3AF),
      };

  @override
  Widget build(BuildContext context) {
    final now = MonthlySiteLevel.monthOf(DateTime.now());
    final months = [
      for (var i = 0; i < widget.months; i++) DateTime(now.year, now.month - i),
    ];
    final sites = [
      for (final zone in DavaoGulfGeography.municipalities)
        if (zone.zoneLabel != 'Practice')
          for (final site in zone.areas) site,
    ];
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorderGray)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly site levels',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kTextNavy)),
            const SizedBox(height: 4),
            const Text(
                'Confirmed COTS recorded at each site per month: '
                '0–15 Low, 16–100 Moderate, over 100 High. '
                'COTS waiting for the Expert are not counted yet.',
                style: TextStyle(color: kMutedGray, fontSize: 12)),
            const SizedBox(height: 6),
            Text(
                'Last ${widget.months} calendar months · independent of the date filter above',
                style: const TextStyle(fontSize: 12, color: kMutedGray)),
            const SizedBox(height: 14),
            FutureBuilder<List<SiteLevel>>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return TextButton(
                      onPressed: () => setState(() => _data = _load()),
                      child: const Text(
                          'Could not load monthly site levels. Retry'));
                }
                if (!snapshot.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator());
                }
                final byKey = {
                  for (final l in snapshot.data!)
                    if (l.month != null && !l.isPractice)
                      '${l.areaCode}|${l.month!.year}-${l.month!.month}': l,
                };
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    key: const ValueKey('monthly-site-levels'),
                    headingRowColor: WidgetStatePropertyAll(
                        kPrimaryTeal.withValues(alpha: .05)),
                    headingTextStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kTextNavy),
                    dataTextStyle:
                        const TextStyle(fontSize: 12, color: kTextNavy),
                    columnSpacing: 16,
                    headingRowHeight: 40,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 60,
                    columns: [
                      const DataColumn(label: Text('Site')),
                      for (final m in months)
                        DataColumn(
                            label: Text(DateFormat('MMM yyyy').format(m))),
                    ],
                    rows: [
                      for (final site in sites)
                        DataRow(cells: [
                          DataCell(Text(site.displayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                          for (final m in months)
                            DataCell(_cell(
                                byKey['${site.code}|${m.year}-${m.month}'])),
                        ]),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(SiteLevel? l) {
    if (l == null || l.level == null) {
      return const Text('—', style: TextStyle(color: kMutedGray));
    }
    final color = _color(l.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${l.confirmedCots} COTS',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: kTextNavy, fontSize: 12)),
          Text(
              l.waitingCots > 0
                  ? '${l.level} · ${l.waitingCots} waiting'
                  : l.level!,
              style: TextStyle(
                  color: kTextNavy.withValues(alpha: 0.8), fontSize: 11)),
        ],
      ),
    );
  }
}
