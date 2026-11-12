import '../../widgets/no_cots_survey_records.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../core/supabase_config.dart';
import '../../models/activity_type.dart';
import '../../models/capture_model.dart';
import '../../models/cots_density.dart';
import '../../models/follow_up_monitoring_model.dart';
import '../../models/follow_up_reassignment.dart';
import '../../models/scan_record_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/capture_repository.dart';
import '../../services/follow_up_monitoring_repository.dart';
import '../../widgets/follow_up_reassignment_controls.dart';
import '../../widgets/area_handover_controls.dart';
import '../../widgets/site_partner_controls.dart';
import '../../services/scan_record_repository.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'scan_detection_page.dart';
import 'user_bottom_nav.dart';
import 'widgets/records_section_tabs.dart';
import 'user_record_details_page.dart';
import '../../widgets/cots_loading_skeleton.dart';

class FollowUpPage extends StatefulWidget {
  const FollowUpPage(
      {super.key,
      this.capturesStream,
      this.assignmentsStream,
      this.surveysStream,
      this.recordsStream});

  final Stream<List<CaptureModel>>? capturesStream;
  final Stream<List<FollowUpAssignmentModel>>? assignmentsStream;
  final Stream<List<FollowUpSurveyModel>>? surveysStream;
  final Stream<List<ScanRecordModel>>? recordsStream;

  @override
  State<FollowUpPage> createState() => _FollowUpPageState();
}

class _FollowUpPageState extends State<FollowUpPage> {
  static final _monthFormat = DateFormat('MMMM yyyy');
  static final _dateFormat = DateFormat('MMM d, yyyy');

  String? _reconciledSignature;
  bool _isReconciling = false;
  Object? _reconciliationError;
  List<String> _ambiguousCaptureIds = const [];
  String? _streamsUid;
  Stream<List<CaptureModel>>? _capturesStream;
  Stream<List<FollowUpAssignmentModel>>? _assignmentsStream;
  Stream<List<FollowUpSurveyModel>>? _surveysStream;
  Stream<List<ScanRecordModel>>? _recordsStream;

  void _bindStreams(String uid) {
    _streamsUid = uid;
    _reconciledSignature = null;
    _capturesStream = widget.capturesStream ?? CaptureRepository.watchAll();
    _assignmentsStream = widget.assignmentsStream ??
        FollowUpMonitoringRepository.watchAssignmentsForDiver(uid);
    _surveysStream = widget.surveysStream ??
        FollowUpMonitoringRepository.watchMonitoringHistory(uid);
    _recordsStream = widget.recordsStream ?? ScanRecordRepository.watchAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid != null && uid != _streamsUid) _bindStreams(uid);
  }

  void _reconcileHistory(List<CaptureModel> captures, String uid) {
    // Supabase already owns assignment creation. Do not fetch all captures
    // again just to call the repository's Supabase no-op.
    if (context.read<AuthProvider>().usesSupabase) return;
    final signature = captures
        .map((capture) =>
            '${capture.id}:${capture.uid}:${capture.monitoringAreaId}:'
            '${capture.submittedAt?.millisecondsSinceEpoch ?? 0}:'
            '${capture.adminConfirmed}:${capture.adminRejected}')
        .join('|');
    if (signature == _reconciledSignature || _isReconciling) return;
    _reconciledSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      setState(() {
        _isReconciling = true;
        _reconciliationError = null;
      });
      try {
        final ambiguous =
            await FollowUpMonitoringRepository.reconcileHistoricalAssignments(
          captures: await FollowUpMonitoringRepository.loadDetectionHistory(),
          currentDiverUid: uid,
        );
        if (!mounted) return;
        setState(() => _ambiguousCaptureIds = ambiguous);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _reconciliationError = error;
        });
      } finally {
        if (mounted) setState(() => _isReconciling = false);
      }
    });
  }

  void _retryReconciliation() {
    setState(() {
      _reconciledSignature = null;
      final uid = context.read<AuthProvider>().userModel?.uid;
      if (uid != null) _bindStreams(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().userModel;
    final uid = authUser?.uid;
    if (authUser == null ||
        !authUser.isActive ||
        authUser.isAdmin ||
        authUser.isExpert) {
      return const Scaffold(
          body: Center(
              child: Text(
                  'Sign in with an active diver account to view Follow-up.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      extendBody: false,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Records',
          style: TextStyle(
            color: kTextNavy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        // The monthly follow-up is the "Monthly visits" tab of Records.
        bottom: RecordsSectionTabs(
          active: RecordsSection.visits,
          onOpen: (context, _) => Navigator.of(context)
              .pushReplacement(recordsSectionRoute((_) => const RecordsPage())),
        ),
      ),
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.followUp,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: uid == null
          ? const Center(
              child: Text('Sign in to view assigned follow-up areas.'))
          : StreamBuilder<List<CaptureModel>>(
              stream: _capturesStream,
              builder: (context, captureSnapshot) {
                return StreamBuilder<List<FollowUpAssignmentModel>>(
                  stream: _assignmentsStream,
                  builder: (context, assignmentSnapshot) {
                    return StreamBuilder<List<FollowUpSurveyModel>>(
                      stream: _surveysStream,
                      builder: (context, surveySnapshot) {
                        return StreamBuilder<List<ScanRecordModel>>(
                          stream: _recordsStream,
                          builder: (context, recordSnapshot) {
                            // All four subscriptions start together, even while
                            // another source is still waiting for its first data.
                            if (captureSnapshot.hasError) {
                              return _loadError(
                                  'Could not load detection history.',
                                  captureSnapshot.error!);
                            }
                            if (assignmentSnapshot.hasError) {
                              return _loadError(
                                  'Could not load assigned monitoring areas.',
                                  assignmentSnapshot.error!);
                            }
                            if (surveySnapshot.hasError) {
                              return _loadError(
                                  'Could not load monitoring history.',
                                  surveySnapshot.error!);
                            }
                            if (recordSnapshot.hasError) {
                              return _loadError(
                                'Could not load linked elimination records.',
                                recordSnapshot.error!,
                              );
                            }
                            if (!captureSnapshot.hasData ||
                                !assignmentSnapshot.hasData ||
                                !surveySnapshot.hasData ||
                                !recordSnapshot.hasData) {
                              return const CotsPageLoading(
                                  label: 'Loading follow-up monitoring');
                            }
                            final captures = captureSnapshot.data!;
                            _reconcileHistory(captures, uid);
                            return _buildContent(
                              assignments: assignmentSnapshot.data!,
                              surveys: surveySnapshot.data ?? const [],
                              records: recordSnapshot.data ?? const [],
                              captures: captures,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _loadError(
    String message,
    Object error,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: kMutedGray, size: 36),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMutedGray, fontSize: 12),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _retryReconciliation,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent({
    required List<FollowUpAssignmentModel> assignments,
    required List<FollowUpSurveyModel> surveys,
    required List<ScanRecordModel> records,
    required List<CaptureModel> captures,
  }) {
    final surveysByArea = <String, List<FollowUpSurveyModel>>{};
    for (final survey in surveys) {
      surveysByArea.putIfAbsent(survey.areaId, () => []).add(survey);
    }
    for (final areaSurveys in surveysByArea.values) {
      areaSurveys.sort((a, b) => b.surveyDate.compareTo(a.surveyDate));
    }

    return RefreshIndicator(
      color: kPrimaryTeal,
      onRefresh: () async {
        _retryReconciliation();
        await Future<void>.delayed(const Duration(milliseconds: 300));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
        children: [
          _pageIntro(),
          const NoCotsSurveyRecords(),

          // Stage 4: handover offers made to this Diver.
          if (SupabaseConfig.isConfigured) ...[
            const SizedBox(height: 12),
            HandoverOffersCard(onChanged: _retryReconciliation),
            // Stage 10: site partner invitations sent to this Diver.
            SitePartnerInvitesCard(onChanged: _retryReconciliation),
          ],
          if (_isReconciling) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(color: kPrimaryTeal),
            const SizedBox(height: 6),
            const Text(
              'Checking previous accepted detections for original assignments…',
              style: TextStyle(color: kMutedGray, fontSize: 12),
            ),
          ],
          if (_reconciliationError != null) ...[
            const SizedBox(height: 12),
            _inlineError(
              'Could not reconcile previous detections: $_reconciliationError',
              onRetry: _retryReconciliation,
            ),
          ],
          if (_ambiguousCaptureIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ambiguityNotice(_ambiguousCaptureIds),
          ],
          const SizedBox(height: 16),
          if (assignments.isEmpty && !_isReconciling)
            _emptyState()
          else
            for (final assignment in assignments) ...[
              _areaCard(
                assignment: assignment,
                surveys: surveysByArea[assignment.areaId] ?? const [],
                records: records,
                captures: captures,
              ),
              const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }

  Widget _pageIntro() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderGray),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly reef follow-up',
              style: TextStyle(
                color: kTextNavy,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Return once during each calendar month. This page lists your primary monitoring areas and accepted temporary assignments for this month.',
              style: TextStyle(color: kMutedGray, height: 1.4),
            ),
          ],
        ),
      );

  Widget _areaCard({
    required FollowUpAssignmentModel assignment,
    required List<FollowUpSurveyModel> surveys,
    required List<ScanRecordModel> records,
    required List<CaptureModel> captures,
  }) {
    final now = MonitoringMonth.calendar(DateTime.now());
    final history = buildFollowUpMonthHistory(
      initialDate: MonitoringMonth.calendar(assignment.initialDate),
      surveys: surveys,
      currentDate: now,
      completedSurveyIds: surveys
          .where((survey) =>
              followUpSurveyStatus(survey, captures) ==
              FollowUpSurveyStatus.completed)
          .map((survey) => survey.id)
          .toSet(),
    );
    final thisMonth = history.where(
      (entry) => entry.month.year == now.year && entry.month.month == now.month,
    );
    final status = thisMonth.isEmpty
        ? FollowUpMonthStatus.upcoming
        : thisMonth.first.status;
    final latestSurvey = surveys.isEmpty ? null : surveys.first;
    final completed = surveys.where((survey) =>
        followUpSurveyStatus(survey, captures) ==
        FollowUpSurveyStatus.completed);
    final lastDate =
        completed.isEmpty ? assignment.initialDate : completed.first.surveyDate;
    final initialRemovals = records
        .where(
          (record) =>
              record.linkedCaptureId == assignment.initialCaptureId &&
              CotsActivityType.isRemoval(record.activityType),
        )
        .toList();
    final initialEliminated = initialRemovals.isEmpty
        ? null
        : initialRemovals.fold<int>(
            0, (sum, record) => sum + (record.removedQuantity ?? 0));
    final areaSurveys =
        surveys.where((survey) => survey.areaId == assignment.areaId).toList();

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kBorderGray)),
      child: ExpansionTile(
        key: PageStorageKey('monthly-site-${assignment.areaId}'),
        maintainState: true,
        tilePadding: const EdgeInsets.all(16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.coronavirus_outlined,
                color: kPrimaryTeal, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assignment.areaName,
                    style: const TextStyle(
                      color: kTextNavy,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    assignment.municipality,
                    style: const TextStyle(
                      color: kMutedGray,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
                alignment: Alignment.centerLeft, child: _statusChip(status))),
        children: [
          DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 13, color: kTextNavy, height: 1.4),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 16),
                  _infoRow('First detection date',
                      _dateFormat.format(assignment.initialDate)),
                  _infoRow('Initial COTS detected',
                      '${assignment.initialDetectedCount}'),
                  _infoRow('Initially reported removals',
                      initialEliminated?.toString() ?? 'Not recorded'),
                  _infoRow(
                      'Last monitoring date', _dateFormat.format(lastDate)),
                  _infoRow('Current target month',
                      _monthFormat.format(followUpTargetMonth(now, status))),
                  FollowUpAssessmentLabel(
                      areaId: assignment.areaId,
                      valueBuilder: (value) => _infoRow('Site level', value)),
                  if (!SupabaseConfig.isConfigured)
                    _infoRow('Assigned diver', assignment.primaryDiverName),
                  // Stage 10: both main Divers, and "Add site partner".
                  if (SupabaseConfig.isConfigured) ...[
                    const SizedBox(height: 6),
                    SiteTeamPanel(
                        areaCode: assignment.areaId,
                        fallbackDiverName: assignment.primaryDiverName),
                  ],
                  const SizedBox(height: 10),
                  FollowUpReassignmentActions(
                    assignment: assignment,
                    onStart: () => _openSurvey(
                        assignment: assignment, previousSurvey: latestSurvey),
                  ),
                  // Stage 4: only the main Diver can hand over the area.
                  if (SupabaseConfig.isConfigured &&
                      assignment.primaryDiverUid ==
                          context.read<AuthProvider>().userModel?.uid) ...[
                    const SizedBox(height: 8),
                    AreaHandoverButton(assignment: assignment),
                  ],
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text(
                      'Monitoring history',
                      style: TextStyle(
                        color: kTextNavy,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${areaSurveys.length} saved visit(s)',
                      style: const TextStyle(color: kMutedGray, fontSize: 12),
                    ),
                    children: [
                      for (final entry in history)
                        _monthHistoryRow(
                          entry,
                          captures: captures,
                          baseline:
                              '${assignment.primaryDiverName} · AI detections ${assignment.initialDetectedCount}, reported eliminated ${initialEliminated ?? 'Not recorded'}',
                          isInitialMonth: entry.month.year ==
                                  assignment.initialDate.toLocal().year &&
                              entry.month.month ==
                                  assignment.initialDate.toLocal().month,
                        ),
                    ],
                  ),
                ]),
          )
        ],
      ),
    );
  }

  Widget _monthHistoryRow(
    FollowUpMonthEntry entry, {
    required bool isInitialMonth,
    required List<CaptureModel> captures,
    required String baseline,
  }) {
    final visits = entry.surveys;
    final color = _statusColor(entry.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(_monthFormat.format(entry.month))),
              Text(
                entry.statusLabel,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          if (isInitialMonth)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Initial detection baseline · $baseline',
                style: const TextStyle(color: kMutedGray, fontSize: 12),
              ),
            ),
          for (final survey in visits)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 12),
              child: TextButton(
                style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    minimumSize: const Size(48, 48)),
                onPressed: survey.noCotsObserved
                    ? () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                                title: const Text(
                                    'No COTS observed during this survey'),
                                content:
                                    Text('Diver-reported · ${survey.areaName}\n${_dateFormat.format(survey.surveyDate)}\n${survey.cotsReportedLater ? 'COTS were reported later this month. This earlier survey remains in history.\n' : ''}This month’s visit is complete. Existing COTS totals are unchanged.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'))
                                ]))
                    : () => Navigator.of(context).push<void>(MaterialPageRoute(
                        builder: (_) => UserRecordDetailsPage(
                            record: ScanRecordModel.fromFollowUpSurvey(survey)))),
                child: Text(
                  '${_dateFormat.format(survey.surveyDate)} · '
                  '${survey.submittedBy} · ${survey.noCotsObserved ? (survey.cotsReportedLater ? 'No COTS observed earlier; COTS reported later this month · Diver-reported' : 'No COTS observed during this visit · Diver-reported') : followUpSurveyStatusLabel(followUpSurveyStatus(survey, captures))} · '
                  '${followUpCountSummary(survey)}'
                  '${survey.calculatedLevel == null ? '' : ' · ${CotsDensity.describe(survey.densityPerHectare, survey.calculatedLevel)}'}'
                  '${survey.assessedLevel == null ? '' : ' · Expert: ${survey.assessedLevel}'}',
                  style: const TextStyle(color: kMutedGray, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(FollowUpMonthStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        _statusLabel(status),
        style:
            TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  Color _statusColor(FollowUpMonthStatus status) => switch (status) {
        FollowUpMonthStatus.monitored => kSuccessGreen,
        FollowUpMonthStatus.awaiting => kWarningOrange,
        FollowUpMonthStatus.notRecorded => kDangerRed,
        FollowUpMonthStatus.upcoming => kMutedGray,
      };

  String _statusLabel(FollowUpMonthStatus status) => switch (status) {
        FollowUpMonthStatus.monitored => 'Monitored',
        FollowUpMonthStatus.awaiting => 'Awaiting Follow-up',
        FollowUpMonthStatus.notRecorded => 'Not Recorded',
        FollowUpMonthStatus.upcoming => 'Upcoming',
      };

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width < 400 ? 132 : 168,
              child: Text(
                label,
                style: const TextStyle(color: kMutedGray, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(
                  color: kTextNavy,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kBorderGray),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.travel_explore_outlined, color: kPrimaryTeal, size: 42),
            SizedBox(height: 10),
            Text(
              'No monitoring areas assigned yet',
              style: TextStyle(
                color: kTextNavy,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Accepted detections in a uniquely mapped site are assigned to their original diver.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kMutedGray, height: 1.4),
            ),
          ],
        ),
      );

  Widget _ambiguityNotice(List<String> captureIds) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          border: Border.all(color: kWarningOrange.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${captureIds.length} accepted detection(s) could not be assigned '
          'because location, diver identity, chronology, or validation is uncertain. '
          'No primary diver was guessed. Record IDs: ${captureIds.join(', ')}.',
          style: const TextStyle(color: kTextNavy, height: 1.35, fontSize: 12),
        ),
      );

  Widget _inlineError(String message, {required VoidCallback onRetry}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(message, style: const TextStyle(fontSize: 12))),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );

  void _openSurvey({
    required FollowUpAssignmentModel assignment,
    required FollowUpSurveyModel? previousSurvey,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ScanDetectionPage(
          followUpAssignment: assignment,
          previousFollowUpSurvey: previousSurvey,
        ),
      ),
    );
  }
}
