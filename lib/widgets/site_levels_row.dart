import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/cots_colors.dart';
import '../core/user_shell_theme.dart' show kLow, kModerate, kHigh;
import '../services/site_levels_service.dart';

/// Dashboards (user, 2026-11-08): one small row with each dive site's level
/// this month (confirmed COTS; 0-15 Low, 16-100 Moderate, over 100 High),
/// High first. Practice sites are left out.
class SiteLevelsRow extends StatefulWidget {
  const SiteLevelsRow({super.key, this.levels, this.now});

  /// Tests replace the data source and the clock.
  final Future<List<SiteLevel>> Function(DateTime month)? levels;
  final DateTime? now;

  @override
  State<SiteLevelsRow> createState() => _SiteLevelsRowState();
}

class _SiteLevelsRowState extends State<SiteLevelsRow> {
  late final DateTime _month =
      MonthlySiteLevel.monthOf(widget.now ?? DateTime.now());
  late Future<List<SiteLevel>> _data = _load();

  Future<List<SiteLevel>> _load() => widget.levels != null
      ? widget.levels!(_month)
      : const SiteLevelsApi().monthLevels(_month);

  static int _rank(String? level) => switch (level) {
        'High' => 0,
        'Moderate' => 1,
        'Low' => 2,
        _ => 3,
      };

  static Color _color(String? level) => switch (level) {
        'High' => kHigh,
        'Moderate' => kModerate,
        'Low' => kLow,
        _ => const Color(0xFFD1D5DB),
      };

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('site-levels-row'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [
                Text('Site levels · ${DateFormat('MMMM yyyy').format(_month)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextNavy)),
                const Text('confirmed COTS this month',
                    style: TextStyle(fontSize: 12, color: kMutedGray)),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<SiteLevel>>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: () => setState(() => _data = _load()),
                        child: const Text('Could not load site levels. Retry')),
                  );
                }
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final sites = [
                  for (final s in snapshot.data!)
                    if (!s.isPractice) s
                ]..sort((a, b) {
                    final r = _rank(a.level).compareTo(_rank(b.level));
                    return r != 0 ? r : a.areaCode.compareTo(b.areaCode);
                  });
                if (sites.isEmpty) {
                  return const Text('No dive sites yet.',
                      style: TextStyle(color: kMutedGray));
                }
                return LayoutBuilder(builder: (context, c) {
                  final perRow = c.maxWidth >= 640 ? 4 : 2;
                  final width = (c.maxWidth - 10 * (perRow - 1)) / perRow;
                  return Wrap(spacing: 10, runSpacing: 10, children: [
                    for (final s in sites)
                      SizedBox(width: width, child: _box(s)),
                  ]);
                });
              },
            ),
          ],
        ),
      );

  Widget _box(SiteLevel s) {
    final color = _color(s.level);
    final high = s.level == 'High';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: high ? const Color(0xFFFFF5F4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderGray),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.areaName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: kTextNavy, fontSize: 13)),
          const SizedBox(height: 4),
          s.level == null
              ? const Text('No records',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kMutedGray,
                      fontSize: 13))
              : Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${s.confirmedCots}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: kTextNavy)),
                    const TextSpan(text: ' COTS · '),
                    TextSpan(
                        text: s.level,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color.lerp(color, Colors.black, 0.25))),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                ),
        ],
      ),
            ),
          ),
        ]),
      ),
    );
  }
}
