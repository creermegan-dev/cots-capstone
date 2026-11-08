import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/activity_type.dart';
import '../../models/cots_confidence_policy.dart';
import '../../models/scan_record_model.dart';
import '../../models/submission_group.dart';
import '../../providers/auth_provider.dart';
import '../../services/scan_record_repository.dart';
import '../../services/offline_submission_service.dart';
import 'cots_map_page.dart';
import 'follow_up_page.dart';
import 'widgets/records_section_tabs.dart';
import 'profile_page.dart';
import 'user_bottom_nav.dart';
import 'user_record_details_page.dart';
import 'user_submission_details_page.dart';

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
    this.group,
    this.pendingSync = false,
    this.searchText = '',
  });

  final String recordId;
  final String displayId;
  final String submittedBy;
  final String activityType;
  final String status;
  final int cotsDetected;
  final int? confidencePercent;
  final SubmissionGroup? group;
  final bool pendingSync;
  final String searchText;
  final String scanSubmittedAt;
  final String zone;
}

ScanRecord _scanRecordFromModel(ScanRecordModel model) {
  final when = model.submittedAt ?? model.dateTaken ?? DateTime.now();
  final formatted = DateFormat('MMM d, yyyy h:mm a').format(when.toLocal());
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
    case 'Pending synchronization':
    case 'Processing evidence':
    case 'Partially accepted':
      return kModerate;
    case 'Retake Photo':
    case 'Rejected':
      return kHigh;
    default:
      return kNavy;
  }
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key, this.recordsStream});
  final Stream<List<ScanRecordModel>>? recordsStream;

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  final TextEditingController _search = TextEditingController();
  String? _statusFilter;
  int _visibleCount = 8;
  Stream<List<ScanRecordModel>>? _recordsStream;
  String? _recordsUid;
  Timer? _retryTimer;

  void _retryRecords() {
    _retryTimer?.cancel();
    _retryTimer = null;
    if (mounted) setState(() => _recordsStream = null);
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  int get _total => _allRecords.length;
  int get _countAccepted => _allRecords
      .where(
          (r) => r.status == 'Accepted' || r.status == 'Automatically Accepted')
      .length;
  int get _countUnderReview => _allRecords
      .where((r) =>
          r.status == 'Under Review' ||
          r.status == 'Requires Expert Validation')
      .length;
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
          '${r.displayId} ${r.submittedBy} ${r.activityType} ${r.zone} ${r.searchText}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  void _submitSearch() {
    setState(() => _visibleCount = 8);
    FocusScope.of(context).unfocus();
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
                  _filterChip(
                      'Automatically Accepted', 'Automatically Accepted'),
                  _filterChip('Requires Expert Validation',
                      'Requires Expert Validation'),
                  _filterChip('Retake Photo', 'Retake Photo'),
                  _filterChip('Submitted', 'Submitted'),
                  _filterChip('Pending Validation', 'Pending Validation'),
                  _filterChip('Completed Monitoring', 'Completed Monitoring'),
                  _filterChip('Accepted', 'Accepted'),
                  _filterChip('Partially accepted', 'Partially accepted'),
                  _filterChip(
                      'Pending synchronization', 'Pending synchronization'),
                  _filterChip('Processing evidence', 'Processing evidence'),
                  _filterChip('Needs Correction', 'Needs Correction'),
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
    final authProvider = context.watch<AuthProvider>();
    final uid = authProvider.userModel?.uid ??
        (authProvider.usesSupabase
            ? null
            : FirebaseAuth.instance.currentUser?.uid);
    if (uid != null && (_recordsStream == null || _recordsUid != uid)) {
      if (_recordsUid != uid) {
        _allModels = const [];
        _allRecords = const [];
      }
      _recordsUid = uid;
      _recordsStream =
          widget.recordsStream ?? ScanRecordRepository.watchForUser(uid);
    }

    return Scaffold(
      backgroundColor: kGray,
      extendBody: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Records',
          style: TextStyle(
            color: kNavy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        // "My records" | "Monthly visits" (Follow-up moved here, 2026-11-06).
        bottom: RecordsSectionTabs(
          active: RecordsSection.records,
          onOpen: (context, _) => Navigator.of(context).pushReplacement(
              recordsSectionRoute((_) => const FollowUpPage(),
                  name: userFollowUpRoute)),
        ),
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
                'Sign in to view your COTS photo submissions.',
                style: TextStyle(color: kNavy),
              ),
            )
          : StreamBuilder<List<ScanRecordModel>>(
              stream: _recordsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return _buildBody(context, unavailable: true, loading: true);
                }
                if (snapshot.hasError) {
                  if (widget.recordsStream == null) {
                    _retryTimer ??=
                        Timer(const Duration(seconds: 15), _retryRecords);
                  }
                  return _buildBody(context, unavailable: true);
                }

                _retryTimer?.cancel();
                _retryTimer = null;

                _allModels = (snapshot.data ?? [])
                    .where((record) => record.uid == uid)
                    .toList();

                return _buildBody(context);
              },
            ),
    );
  }

  Widget _buildBody(BuildContext context,
      {bool unavailable = false, bool loading = false}) {
    final offline = context.watch<OfflineSubmissionService>();
    final local = offline.pendingSubmissions
        .where((task) => task.record != null && task.record!.uid == _recordsUid)
        .toList();
    final pendingIds = local.map((task) => task.record!.id).toSet();
    final groups = SubmissionGroup.fromRecords([
      ..._allModels,
      ...local.map((task) => task.record!),
    ]);
    _allRecords = groups.map((group) {
      final pending =
          group.records.any((record) => pendingIds.contains(record.id));
      if (!group.hasBatch && !pending) {
        return _scanRecordFromModel(group.records.single);
      }
      final first = group.records.first;
      final time = group.latestSubmittedAt;
      return ScanRecord(
          recordId: group.key,
          displayId: group.displayId,
          submittedBy: first.submittedBy,
          activityType:
              '${group.photoCount} photo${group.photoCount == 1 ? '' : 's'}',
          status: group.statusLabel(pendingSync: pending),
          cotsDetected: group.detectedCount,
          confidencePercent: null,
          scanSubmittedAt: time == null
              ? 'Unknown'
              : DateFormat('MMM d, yyyy h:mm a').format(time.toLocal()),
          zone: first.zone,
          group: group,
          pendingSync: pending,
          searchText: group.records
              .map((r) => '${r.displayRecordId} ${r.imageName}')
              .join(' '));
    }).toList();
    final pendingSubmissionCount = _allRecords
            .where((r) => r.pendingSync)
            .length +
        offline.pendingSubmissions.where((task) => task.record == null).length;
    final filtered = _filtered;
    final shown = filtered.take(_visibleCount).toList();
    final hasMore = _visibleCount < filtered.length;
    final hasSearchOrFilter =
        _search.text.trim().isNotEmpty || _statusFilter != null;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                if (unavailable)
                  Card(
                      child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              loading
                                  ? 'Connecting to records…'
                                  : 'Saved records unavailable while disconnected',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const Text(
                              'Pending submissions below are saved on this device. Reconnect to synchronize and refresh server records.'),
                          if (!loading)
                            TextButton(
                                onPressed: _retryRecords,
                                child: const Text('Retry records')),
                        ]),
                  )),
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
                  'View your COTS photo submissions and verification status.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                Consumer<OfflineSubmissionService>(
                  builder: (context, offline, _) {
                    if (offline.pendingCount == 0 && !offline.isSyncing) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF2C66D)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              offline.isSyncing
                                  ? Icons.sync_rounded
                                  : Icons.cloud_upload_outlined,
                              color: const Color(0xFF8A5A00),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                offline.isSyncing
                                    ? 'Synchronizing pending submissions…'
                                    : '$pendingSubmissionCount submission${pendingSubmissionCount == 1 ? '' : 's'} pending synchronization',
                                style: const TextStyle(
                                  color: Color(0xFF684500),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: offline.isSyncing
                                  ? null
                                  : () => offline.syncPending(),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Consumer<OfflineSubmissionService>(
                    builder: (context, offline, _) {
                  final pending = offline.pendingSubmissions
                      .where((task) => task.record == null)
                      .toList();
                  if (pending.isEmpty) return const SizedBox.shrink();
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Saved on this device',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        for (final task in pending)
                          Card(
                              child: ListTile(
                            leading: const Icon(Icons.cloud_upload_outlined),
                            title: Text(task.name),
                            subtitle: Text(
                                'Pending synchronization${task.createdAt == null ? '' : '\n${DateFormat('MMM d, yyyy h:mm a').format(task.createdAt!.toLocal())}'}'),
                            isThreeLine: task.createdAt != null,
                          )),
                      ]);
                }),
                if (!unavailable || _allRecords.isNotEmpty) _summaryRow(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() => _visibleCount = 8),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _submitSearch(),
                        decoration: InputDecoration(
                          hintText: 'Search by record ID or activity',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: IconButton(
                            onPressed: _submitSearch,
                            tooltip: 'Search records',
                            icon: Icon(Icons.search,
                                color: Colors.grey.shade600, size: 22),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
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
                      onPressed: () => setState(() => _statusFilter = null),
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
                    child: hasSearchOrFilter
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No matching records',
                                style: TextStyle(color: kNavy, height: 1.4),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _statusFilter = null;
                                  _visibleCount = 8;
                                }),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                ),
                                child: const Text('Clear search and filters'),
                              ),
                            ],
                          )
                        : Text(
                            unavailable
                                ? 'Server records will appear after reconnecting. Pending submissions are listed separately above.'
                                : 'No submissions yet. Tap + to upload COTS photos.',
                            style: const TextStyle(color: kNavy, height: 1.4),
                          ),
                  )
                else
                  ...shown.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: r.group != null
                            ? _GroupedRecordCard(
                                record: r,
                                onTap: () => Navigator.of(context)
                                    .push<void>(MaterialPageRoute(
                                  builder: (_) => UserSubmissionDetailsPage(
                                      initialGroup: r.group!),
                                )),
                              )
                            : _RecordCard(
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
                                            UserRecordDetailsPage(
                                                record: model!),
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
          _guideRow(kLow, 'Automatically Accepted',
              'AI detection confidence is 80%–100%. Automatically accepted as an official monitoring record.'),
          const SizedBox(height: 6),
          _guideRow(kModerate, 'Requires Expert Validation',
              'AI detection confidence is below 80%. Forwarded to the Expert for manual verification.'),
          const SizedBox(height: 6),
          _guideRow(kHigh, 'Retake Photo',
              'Confidence too low (0–${CotsConfidencePolicy.adminReviewMin - 1}%) — take a clearer COTS photo.'),
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
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade800, height: 1.35),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: kNavy),
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

class _GroupedRecordCard extends StatelessWidget {
  const _GroupedRecordCard({required this.record, required this.onTap});
  final ScanRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(record.displayId,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, color: kNavy))),
                    const Icon(Icons.chevron_right),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                      '${record.activityType} · ${record.cotsDetected} COTS detected',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(record.status,
                      style: TextStyle(
                          color: _statusColor(record.status),
                          fontWeight: FontWeight.w600)),
                  Text('Site: ${record.zone}'),
                  Text('Submitted by ${record.submittedBy}'),
                  Text('Latest activity: ${record.scanSubmittedAt}'),
                  const Text('Confidence and GPS are shown for each photo.'),
                ]),
          ),
        ),
      );
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
                        Flexible(
                            child: Container(
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
                              Flexible(
                                  child: Text(
                                record.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: stColor,
                                ),
                              )),
                            ],
                          ),
                        )),
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
