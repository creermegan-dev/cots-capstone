import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:flutter/material.dart';

import 'cots_map_page.dart';
import 'profile_page.dart';
import 'user_bottom_nav.dart';
import 'zone_details_page.dart';

/// One scan / status row in the records list.
class ScanRecord {
  const ScanRecord({
    required this.zoneId,
    required this.status,
    required this.cotsDetected,
    required this.scanSubmittedAt,
    required this.actionIsScheduled,
    required this.actionAt,
  });

  final String zoneId;
  final String status;
  final int cotsDetected;
  final String scanSubmittedAt;
  /// `true` → "Scheduled For", `false` → "Updated"
  final bool actionIsScheduled;
  final String actionAt;
}

/// Mock records (totals: 24 — Active 9, Scheduled 6, Cleared 9).
final List<ScanRecord> kAllScanRecords = [
  const ScanRecord(zoneId: 'ZD-2024-0010', status: 'Active', cotsDetected: 35, scanSubmittedAt: 'May 18, 2024 8:30 AM', actionIsScheduled: false, actionAt: 'May 18, 2024 8:30 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0007', status: 'Active', cotsDetected: 25, scanSubmittedAt: 'May 18, 2024 7:15 AM', actionIsScheduled: true, actionAt: 'May 20, 2024 10:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0008', status: 'Scheduled', cotsDetected: 12, scanSubmittedAt: 'May 17, 2024 2:00 PM', actionIsScheduled: true, actionAt: 'May 21, 2024 9:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0009', status: 'Cleared', cotsDetected: 0, scanSubmittedAt: 'May 14, 2024 11:00 AM', actionIsScheduled: false, actionAt: 'May 14, 2024 4:00 PM'),
  const ScanRecord(zoneId: 'ZD-2024-0007', status: 'Active', cotsDetected: 15, scanSubmittedAt: 'May 17, 2024 10:20 AM', actionIsScheduled: false, actionAt: 'May 17, 2024 10:20 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0010', status: 'Active', cotsDetected: 28, scanSubmittedAt: 'May 16, 2024 3:45 PM', actionIsScheduled: false, actionAt: 'May 16, 2024 3:45 PM'),
  const ScanRecord(zoneId: 'ZD-2024-0008', status: 'Scheduled', cotsDetected: 8, scanSubmittedAt: 'May 16, 2024 9:05 AM', actionIsScheduled: true, actionAt: 'May 22, 2024 8:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0009', status: 'Cleared', cotsDetected: 2, scanSubmittedAt: 'May 12, 2024 1:20 PM', actionIsScheduled: false, actionAt: 'May 13, 2024 9:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0007', status: 'Active', cotsDetected: 42, scanSubmittedAt: 'May 15, 2024 6:00 AM', actionIsScheduled: false, actionAt: 'May 15, 2024 6:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0010', status: 'Active', cotsDetected: 31, scanSubmittedAt: 'May 15, 2024 4:30 PM', actionIsScheduled: true, actionAt: 'May 19, 2024 7:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0008', status: 'Scheduled', cotsDetected: 6, scanSubmittedAt: 'May 14, 2024 11:30 AM', actionIsScheduled: true, actionAt: 'May 23, 2024 6:30 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0009', status: 'Cleared', cotsDetected: 0, scanSubmittedAt: 'May 10, 2024 8:00 AM', actionIsScheduled: false, actionAt: 'May 10, 2024 5:00 PM'),
  const ScanRecord(zoneId: 'ZD-2024-0007', status: 'Active', cotsDetected: 18, scanSubmittedAt: 'May 13, 2024 2:15 PM', actionIsScheduled: false, actionAt: 'May 13, 2024 2:15 PM'),
  const ScanRecord(zoneId: 'ZD-2024-0010', status: 'Active', cotsDetected: 22, scanSubmittedAt: 'May 12, 2024 7:00 AM', actionIsScheduled: false, actionAt: 'May 12, 2024 7:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0008', status: 'Scheduled', cotsDetected: 10, scanSubmittedAt: 'May 11, 2024 4:00 PM', actionIsScheduled: true, actionAt: 'May 24, 2024 10:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0009', status: 'Cleared', cotsDetected: 1, scanSubmittedAt: 'May 8, 2024 9:40 AM', actionIsScheduled: false, actionAt: 'May 9, 2024 2:00 PM'),
  const ScanRecord(zoneId: 'ZD-2024-0007', status: 'Cleared', cotsDetected: 2, scanSubmittedAt: 'May 10, 2024 10:00 AM', actionIsScheduled: false, actionAt: 'May 11, 2024 2:00 PM'),
  const ScanRecord(zoneId: 'ZD-2024-0010', status: 'Active', cotsDetected: 19, scanSubmittedAt: 'May 9, 2024 5:20 PM', actionIsScheduled: false, actionAt: 'May 9, 2024 5:20 PM'),
  const ScanRecord(zoneId: 'ZD-2024-0008', status: 'Scheduled', cotsDetected: 7, scanSubmittedAt: 'May 8, 2024 8:15 AM', actionIsScheduled: true, actionAt: 'May 25, 2024 7:30 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0009', status: 'Cleared', cotsDetected: 0, scanSubmittedAt: 'May 6, 2024 3:00 PM', actionIsScheduled: false, actionAt: 'May 7, 2024 10:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0007', status: 'Cleared', cotsDetected: 0, scanSubmittedAt: 'May 5, 2024 1:00 PM', actionIsScheduled: false, actionAt: 'May 6, 2024 9:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0010', status: 'Cleared', cotsDetected: 0, scanSubmittedAt: 'May 4, 2024 9:30 AM', actionIsScheduled: false, actionAt: 'May 5, 2024 3:00 PM'),
  const ScanRecord(zoneId: 'ZD-2024-0008', status: 'Scheduled', cotsDetected: 5, scanSubmittedAt: 'May 3, 2024 2:45 PM', actionIsScheduled: true, actionAt: 'May 26, 2024 9:00 AM'),
  const ScanRecord(zoneId: 'ZD-2024-0009', status: 'Cleared', cotsDetected: 3, scanSubmittedAt: 'May 2, 2024 11:00 AM', actionIsScheduled: false, actionAt: 'May 3, 2024 8:00 AM'),
];

CotsZone? _zoneForId(String id) {
  try {
    return kSampleZones.firstWhere((z) => z.id == id);
  } catch (_) {
    return null;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'Active':
      return kHigh;
    case 'Scheduled':
      return kModerate;
    case 'Cleared':
      return kLow;
    default:
      return kNavy;
  }
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final TextEditingController _search = TextEditingController();
  String? _statusFilter;
  int _visibleCount = 8;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int get _total => kAllScanRecords.length;
  int get _countActive =>
      kAllScanRecords.where((r) => r.status == 'Active').length;
  int get _countScheduled =>
      kAllScanRecords.where((r) => r.status == 'Scheduled').length;
  int get _countCleared =>
      kAllScanRecords.where((r) => r.status == 'Cleared').length;

  List<ScanRecord> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return kAllScanRecords.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      final z = _zoneForId(r.zoneId);
      if (z == null) return false;
      final hay = '${z.label} ${z.name} ${z.location}'.toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _openFilters() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filter by status',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kNavy,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip('All', null),
                  _filterChip('Active', 'Active'),
                  _filterChip('Scheduled', 'Scheduled'),
                  _filterChip('Cleared', 'Cleared'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, String? value) {
    final selected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
          _visibleCount = 8;
        });
        Navigator.pop(context);
      },
      selectedColor: kGreen.withValues(alpha: 0.15),
      checkmarkColor: kGreen,
      labelStyle: TextStyle(
        color: selected ? kGreen : kNavy,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final shown = filtered.take(_visibleCount).toList();
    final hasMore = _visibleCount < filtered.length;

    return Scaffold(
      backgroundColor: kGray,
      extendBody: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: AppBackIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconColor: kNavy,
        ),
        title: const Text(
          'Records',
          style: TextStyle(
            color: kNavy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: userShellScanFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.records,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  const Text(
                    'RECORDS PAGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: kGreen,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'View all scan submissions and status updates of monitored zones.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _summaryRow(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) =>
                              setState(() => _visibleCount = 8),
                          decoration: InputDecoration(
                            hintText: 'Search by zone name or location',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                            prefixIcon: Icon(Icons.search,
                                color: Colors.grey.shade600, size: 22),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: kGreen, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _openFilters,
                        icon: Icon(Icons.filter_list,
                            size: 18, color: Colors.grey.shade800),
                        label: Text(
                          'Filters',
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_statusFilter != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _statusFilter = null),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(
                          'Clear filter: $_statusFilter',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ...shown.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecordCard(
                          record: r,
                          zone: _zoneForId(r.zoneId),
                          onTap: () {
                            final z = _zoneForId(r.zoneId);
                            if (z != null) {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      ZoneDetailsPage(zone: z),
                                ),
                              );
                            }
                          },
                        ),
                      )),
                  if (hasMore)
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _visibleCount += 8,
                        ),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Load more'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _statusGuideFooter(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow() {
    return Row(
      children: [
        Expanded(
          child: _summaryTile(
            icon: Icons.description_outlined,
            label: 'Total Records',
            value: '$_total',
            accent: kGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryTile(
            icon: Icons.circle,
            label: 'Active',
            value: '$_countActive',
            accent: kHigh,
            iconIsDot: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryTile(
            icon: Icons.circle,
            label: 'Scheduled',
            value: '$_countScheduled',
            accent: kModerate,
            iconIsDot: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryTile(
            icon: Icons.circle,
            label: 'Cleared',
            value: '$_countCleared',
            accent: kLow,
            iconIsDot: true,
          ),
        ),
      ],
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
    bool iconIsDot = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: iconIsDot ? 10 : 20,
            color: accent,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusGuideFooter() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STATUS GUIDE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kNavy,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          _guideRow(kHigh, 'Active', 'COTS are present in this area.'),
          const SizedBox(height: 6),
          _guideRow(kModerate, 'Scheduled', 'Removal planned but not yet done.'),
          const SizedBox(height: 6),
          _guideRow(kLow, 'Cleared', 'No COTS detected after removal.'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap any record to view detailed information, status history, and map.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _guideRow(Color dot, String title, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800, height: 1.35),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kNavy),
                ),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.record,
    required this.zone,
    required this.onTap,
  });

  final ScanRecord record;
  final CotsZone? zone;
  final VoidCallback onTap;

  String get _avatarLetter {
    if (zone == null) return '?';
    final l = zone!.label;
    if (l.isEmpty) return '?';
    return l.substring(l.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (zone == null) return const SizedBox.shrink();
    final z = zone!;
    final stColor = _statusColor(record.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _avatarLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${z.label} – ${z.name}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kNavy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                z.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: stColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: stColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                record.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: stColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.pest_control_outlined,
                            size: 16, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Text(
                          '${record.cotsDetected} COTS',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kNavy,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            record.scanSubmittedAt,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          record.actionIsScheduled
                              ? Icons.event_outlined
                              : Icons.update_outlined,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            record.actionIsScheduled
                                ? 'Scheduled for ${record.actionAt}'
                                : 'Updated ${record.actionAt}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
