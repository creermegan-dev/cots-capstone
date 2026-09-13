import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/activity_type.dart';
import '../../models/cots_confidence_policy.dart';
import '../../models/scan_record_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/scan_record_repository.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'user_bottom_nav.dart';
import 'user_record_details_page.dart';

/// One user submission row in the records list.
class ScanRecord {
  const ScanRecord({
    required this.recordId,
    required this.displayId,
    required this.submittedBy,
    required this.activityType,
    required this.status,
    required this.cotsDetected,
    required this.confidencePercent,
    required this.scanSubmittedAt,
    required this.zone,
  });

  final String recordId;
  final String displayId;
  final String submittedBy;
  final String activityType;
  final String status;
  final int cotsDetected;
  final int confidencePercent;
  final String scanSubmittedAt;
  final String zone;
}

ScanRecord _scanRecordFromModel(ScanRecordModel model) {
  final when = model.submittedAt ?? model.dateTaken ?? DateTime.now();
  final formatted = DateFormat('MMM d, yyyy h:mm a').format(when);
  return ScanRecord(
    recordId: model.id,
    displayId: model.displayRecordId,
    submittedBy: model.submittedBy,
    activityType: CotsActivityType.label(model.activityType),
    status: model.userStatusLabel,
    cotsDetected: model.aiDetectedCount,
    confidencePercent: (model.confidence.clamp(0.0, 1.0) * 100).round(),
    scanSubmittedAt: formatted,
    zone: model.zone,
  );
}

Color _statusColor(String status) {
  switch (status) {
    case 'Accepted':
    case 'Automatically Accepted':
    case 'Verified':
      return kLow;
    case 'Under Review':
    case 'Requires Expert Validation':
    case 'Pending Verification':
      return kModerate;
    case 'Retake Photo':
    case 'Rejected':
      return kHigh;
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

  int get _total => _allRecords.length;
  int get _countAccepted =>
      _allRecords.where((r) =>
          r.status == 'Accepted' ||
          r.status == 'Automatically Accepted').length;
  int get _countUnderReview =>
      _allRecords.where((r) =>
          r.status == 'Under Review' ||
          r.status == 'Requires Expert Validation').length;
  int get _countRetake =>
      _allRecords.where((r) => r.status == 'Retake Photo').length;

  List<ScanRecord> _allRecords = const [];
  List<ScanRecordModel> _allModels = const [];

  List<ScanRecord> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _allRecords.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (q.isEmpty) return true;
      final hay =
          '${r.displayId} ${r.submittedBy} ${r.activityType} ${r.zone}'.toLowerCase();
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
                  _filterChip('Automatically Accepted', 'Automatically Accepted'),
                  _filterChip('Requires Expert Validation', 'Requires Expert Validation'),
                  _filterChip('Retake Photo', 'Retake Photo'),
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
    final uid = context.watch<AuthProvider>().userModel?.uid ??
        FirebaseAuth.instance.currentUser?.uid;

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
      body: uid == null
          ? const Center(
              child: Text(
                'Sign in to view your GoPro submissions.',
                style: TextStyle(color: kNavy),
              ),
            )
          : StreamBuilder<List<ScanRecordModel>>(
              stream: ScanRecordRepository.watchForUser(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: kGreen),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load records.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kNavy),
                      ),
                    ),
                  );
                }

                _allModels = snapshot.data ?? [];
                _allRecords = _allModels.map(_scanRecordFromModel).toList();

                return _buildBody(context);
              },
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final filtered = _filtered;
    final shown = filtered.take(_visibleCount).toList();
    final hasMore = _visibleCount < filtered.length;

    return SafeArea(
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
                    'View your GoPro detection submissions and verification status.',
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
                            hintText: 'Search by record ID or activity',
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
                  if (shown.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Text(
                        'No submissions yet. Tap + to upload a GoPro detection.',
                        style: TextStyle(color: kNavy, height: 1.4),
                      ),
                    )
                  else
                    ...shown.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RecordCard(
                          record: r,
                          onTap: () {
                            ScanRecordModel? model;
                            for (final m in _allModels) {
                              if (m.id == r.recordId) {
                                model = m;
                                break;
                              }
                            }
                            if (model != null) {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (context) =>
                                      UserRecordDetailsPage(record: model!),
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
            label: 'Auto Accepted',
            value: '$_countAccepted',
            accent: kLow,
            iconIsDot: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryTile(
            icon: Icons.circle,
            label: 'Expert Review',
            value: '$_countUnderReview',
            accent: kModerate,
            iconIsDot: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _summaryTile(
            icon: Icons.circle,
            label: 'Retake',
            value: '$_countRetake',
            accent: kHigh,
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
          _guideRow(kLow, 'Automatically Accepted', 'AI detection confidence is 80%–100%. Automatically accepted as an official monitoring record.'),
          const SizedBox(height: 6),
          _guideRow(kModerate, 'Requires Expert Validation', 'AI detection confidence is below 80%. Forwarded to the Expert for manual verification.'),
          const SizedBox(height: 6),
          _guideRow(kHigh, 'Retake Photo', 'Confidence too low (0–${CotsConfidencePolicy.adminReviewMin - 1}%) — capture a clearer GoPro image.'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tap any record to view detection results, GPS info, and image preview.',
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
    required this.onTap,
  });

  final ScanRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(
                  Icons.description_outlined,
                  color: Colors.white,
                  size: 22,
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
                                record.displayId,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: kNavy,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Submitted by ${record.submittedBy}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                record.activityType,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
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
                        Icon(Icons.speed_outlined,
                            size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Text(
                          '${record.confidencePercent}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kNavy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: Colors.grey.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Uploaded ${record.scanSubmittedAt}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (record.zone.isNotEmpty &&
                            record.zone != 'Unassigned') ...[
                          Icon(Icons.place_outlined,
                              size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            record.zone,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
