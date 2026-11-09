import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/supabase_config.dart';
import '../../../models/app_notification.dart';
import '../../../models/area_handover.dart';
import '../../../models/follow_up_monitoring_model.dart';
import '../../../models/follow_up_reassignment.dart';
import '../../../models/site_partner.dart';
import '../../../services/auth_service.dart';
import '../../../services/follow_up_reassignment_repository.dart';
import '../../../services/scan_record_repository.dart';
import '../../../services/supabase_follow_up_service.dart';
import '../../../services/site_partner_service.dart';
import '../../../services/supabase_handover_service.dart';
import '../../../widgets/cots_loading_skeleton.dart';
import '../../admin/models/admin_record_table_row.dart';
import '../../admin/screens/admin_notifications_screen.dart';
import '../../admin/theme/admin_theme.dart';
import '../models/expert_action_item.dart';

/// Keeps the Expert's "Needs your action" list up to date. It reads the same
/// data the Verification, Assessments and Reassignments tabs read, so the
/// list and the tab count change as soon as the Expert handles an item.
class ExpertActionsController extends ChangeNotifier {
  ExpertActionsController({
    Stream<List<AdminRecordTableRow>> Function()? records,
    Stream<List<FollowUpReassignment>> Function()? reassignments,
    Future<List<FollowUpSurveyModel>> Function()? visits,
    AreaHandoverApi? handovers,
    SitePartnerApi? sitePartners,
    bool? supabase,
    DateTime Function()? clock,
    this.refreshEvery = SupabaseFollowUpService.refreshInterval,
  })  : _clock = clock ?? DateTime.now,
        _recordsSource = records ?? ScanRecordRepository.watchAdminTableRows,
        _reassignmentsSource =
            reassignments ?? FollowUpReassignmentRepository.watch,
        // Monthly visits and handovers exist only in the Supabase version,
        // like on the Assessments and Reassignments tabs.
        _visitsSource = visits ??
            ((supabase ?? SupabaseConfig.isConfigured)
                ? SupabaseFollowUpService.visitsToAssess
                : null),
        _handoverApi = handovers ??
            ((supabase ?? SupabaseConfig.isConfigured)
                ? const AreaHandoverApi()
                : null),
        _partnerApi = sitePartners ??
            ((supabase ?? SupabaseConfig.isConfigured)
                ? const SitePartnerApi()
                : null);

  /// How often monthly visits and handovers are checked again. The records
  /// and reassignment streams refresh on their own. Null: never (tests).
  final Duration? refreshEvery;

  final DateTime Function() _clock;
  final Stream<List<AdminRecordTableRow>> Function() _recordsSource;
  final Stream<List<FollowUpReassignment>> Function() _reassignmentsSource;
  final Future<List<FollowUpSurveyModel>> Function()? _visitsSource;
  final AreaHandoverApi? _handoverApi;
  final SitePartnerApi? _partnerApi;

  static const _recordsName = 'records';
  static const _visitsName = 'monthly visits';
  static const _reassignmentsName = 'reassignment requests';
  static const _handoversName = 'area handovers';
  static const _partnersName = 'site partners';

  List<AdminRecordTableRow> _records = const [];
  List<FollowUpSurveyModel> _visits = const [];
  List<FollowUpReassignment> _reassignments = const [];
  List<AreaHandover> _handovers = const [];
  List<AreaMissedMonths> _missedMonths = const [];
  List<SitePartnerRequest> _sitePartners = const [];
  final _waitingFor = <String>{};
  final _errors = <String, String>{};
  List<ExpertActionItem>? _items;

  StreamSubscription<List<AdminRecordTableRow>>? _recordsSub;
  StreamSubscription<List<FollowUpReassignment>>? _reassignmentsSub;
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;

  /// True once every source has answered at least once.
  bool get loaded => _started && _waitingFor.isEmpty;

  /// Sources that could not be loaded, as messages for the screen.
  List<String> get errors => [
        for (final entry in _errors.entries)
          'Could not check ${entry.key}: ${entry.value}',
      ];

  List<ExpertActionItem> get items => _items ??= ExpertActions.build(
        records: _records,
        visits: _visits,
        reassignments: _reassignments,
        handovers: _handovers,
        missedMonths: _missedMonths,
        sitePartners: _sitePartners,
        now: _clock(),
      );

  /// The number shown on the Notifications tab.
  int get count => loaded ? items.length : 0;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _waitingFor.addAll([
      _recordsName,
      _reassignmentsName,
      if (_visitsSource != null) _visitsName,
      if (_handoverApi != null) _handoversName,
      if (_partnerApi != null) _partnersName,
    ]);
    _recordsSub = _recordsSource().listen(
      (rows) {
        _records = rows;
        _answered(_recordsName);
      },
      onError: (Object error) => _failed(_recordsName, error),
    );
    _reassignmentsSub = _reassignmentsSource().listen(
      (requests) {
        _reassignments = requests;
        _answered(_reassignmentsName);
      },
      onError: (Object error) => _failed(_reassignmentsName, error),
    );
    unawaited(refresh());
    final every = refreshEvery;
    if (every != null) {
      _timer = Timer.periodic(every, (_) => unawaited(refresh()));
    }
  }

  /// Checks monthly visits and handovers again.
  Future<void> refresh() async {
    if (!_started || _disposed) return;
    await Future.wait([_loadVisits(), _loadHandovers(), _loadPartners()]);
  }

  Future<void> _loadPartners() async {
    final api = _partnerApi;
    if (api == null) return;
    try {
      _sitePartners = await api.requests();
      _answered(_partnersName);
    } catch (error) {
      _failed(_partnersName, error);
    }
  }

  /// Stage 10: the Expert approves or declines a site partner candidate.
  /// Returns an error message, or null when it worked.
  Future<String?> decideSitePartner(String requestId,
      {required bool approve}) async {
    final api = _partnerApi;
    if (api == null) return 'Site partners need the Supabase version.';
    try {
      await api.decide(requestId, approve: approve);
      return null;
    } catch (error) {
      return AuthService.messageFor(error);
    } finally {
      await _loadPartners();
    }
  }

  Future<void> _loadVisits() async {
    final source = _visitsSource;
    if (source == null) return;
    try {
      _visits = await source();
      _answered(_visitsName);
    } catch (error) {
      _failed(_visitsName, error);
    }
  }

  Future<void> _loadHandovers() async {
    final api = _handoverApi;
    if (api == null) return;
    try {
      final handovers = await api.list();
      final missed = await api.missedMonths();
      _handovers = handovers;
      _missedMonths = missed;
      _answered(_handoversName);
    } catch (error) {
      _failed(_handoversName, error);
    }
  }

  void _answered(String source) {
    _waitingFor.remove(source);
    _errors.remove(source);
    _changed();
  }

  void _failed(String source, Object error) {
    _waitingFor.remove(source);
    _errors[source] = AuthService.messageFor(error);
    _changed();
  }

  void _changed() {
    if (_disposed) return;
    _items = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_recordsSub?.cancel());
    unawaited(_reassignmentsSub?.cancel());
    super.dispose();
  }
}

/// The Expert's Notifications tab: "Needs your action" and "All notices".
class ExpertNotificationsScreen extends StatefulWidget {
  const ExpertNotificationsScreen({
    super.key,
    required this.actions,
    this.onOpen,
    this.noticesStream,
  });

  final ExpertActionsController actions;

  /// Opens the tab where the Expert acts on an item.
  final ValueChanged<ExpertActionPlace>? onOpen;

  /// Replaces the Expert's notices (tests). Otherwise the signed-in
  /// person's notices are loaded.
  final Stream<List<AppNotification>>? noticesStream;

  static const needsActionLabel = 'Needs your action';
  static const allNoticesLabel = 'All notices';
  static const nothingWaiting = 'Nothing needs your action right now.';

  @override
  State<ExpertNotificationsScreen> createState() =>
      _ExpertNotificationsScreenState();
}

class _ExpertNotificationsScreenState extends State<ExpertNotificationsScreen> {
  bool _showAll = false;
  bool _deciding = false;

  Future<void> _decidePartner(ExpertActionItem item,
      {required bool approve}) async {
    final name = item.detail.split(' · ').first;
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(approve ? 'Approve $name?' : 'Decline $name?'),
            content: Text(approve
                ? '$name becomes the site partner. Any other candidates for '
                    'this site are closed ("Place already filled"). A site '
                    'partner cannot be removed later.'
                : '$name will be told. The place stays open.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Back')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(approve ? 'Approve' : 'Decline')),
            ],
          ),
        ) ??
        false;
    if (!ok || !mounted) return;
    setState(() => _deciding = true);
    final error =
        await widget.actions.decideSitePartner(item.id, approve: approve);
    if (!mounted) return;
    setState(() => _deciding = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error ??
            (approve
                ? '$name is now the site partner.'
                : '$name was not approved.'))));
  }

  @override
  void initState() {
    super.initState();
    // Coming back to this tab: check again what still waits.
    if (widget.actions.loaded) unawaited(widget.actions.refresh());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.actions,
        builder: (context, _) {
          final actions = widget.actions;
          final needsLabel = actions.loaded
              ? '${ExpertNotificationsScreen.needsActionLabel} (${actions.count})'
              : ExpertNotificationsScreen.needsActionLabel;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
                child: Row(children: [
                  const Expanded(
                    child: Text('Notifications',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.headerTitle)),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => unawaited(actions.refresh()),
                    icon: const Icon(Icons.refresh),
                  ),
                ]),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                    'What is waiting for you, and every notice sent to you.'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: Text(needsLabel),
                    selected: !_showAll,
                    onSelected: (_) => setState(() => _showAll = false),
                  ),
                  ChoiceChip(
                    label:
                        const Text(ExpertNotificationsScreen.allNoticesLabel),
                    selected: _showAll,
                    onSelected: (_) => setState(() => _showAll = true),
                  ),
                ]),
              ),
              Expanded(
                child: _showAll
                    ? AdminNotificationsScreen(
                        notificationsStream: widget.noticesStream,
                        showHeader: false,
                        emptyMessage:
                            'Notices sent to the Expert will appear here.',
                        loadingLabel: 'Loading Expert notices',
                      )
                    : _actionList(actions),
              ),
            ],
          );
        },
      );

  Widget _actionList(ExpertActionsController actions) {
    if (!actions.loaded) {
      return const CotsPageLoading(label: 'Checking what needs your action');
    }
    final items = actions.items;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final error in actions.errors)
          Card(
            color: AdminColors.cardWhite,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: const Icon(Icons.cloud_off_rounded,
                  color: AdminColors.statRed),
              title: Text(error),
              trailing: TextButton(
                onPressed: () => unawaited(actions.refresh()),
                child: const Text('Retry'),
              ),
            ),
          ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(ExpertNotificationsScreen.nothingWaiting,
                textAlign: TextAlign.center),
          ),
        for (final item in items)
          Card(
            color: AdminColors.cardWhite,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: Icon(_icon(item.kind), color: _color(item.kind)),
              title: Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.detail),
                  const SizedBox(height: 4),
                  if (item.decidedHere)
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed: _deciding
                              ? null
                              : () => _decidePartner(item, approve: false),
                          child: const Text('Decline')),
                      FilledButton(
                          onPressed: _deciding
                              ? null
                              : () => _decidePartner(item, approve: true),
                          child: const Text('Approve')),
                    ])
                  else
                    Text('Open ${item.place.label}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.statBlue)),
                ],
              ),
              trailing: item.decidedHere
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpen == null || item.decidedHere
                  ? null
                  : () => widget.onOpen!(item.place),
            ),
          ),
      ],
    );
  }

  static IconData _icon(ExpertActionKind kind) => switch (kind) {
        ExpertActionKind.recordReview => Icons.rate_review_outlined,
        ExpertActionKind.zoneApproval => Icons.place_outlined,
        ExpertActionKind.visitAssessment => Icons.assignment_outlined,
        ExpertActionKind.reassignment => Icons.swap_horiz_rounded,
        ExpertActionKind.handover => Icons.swap_horiz_rounded,
        ExpertActionKind.missedMonths => Icons.event_busy_outlined,
        ExpertActionKind.sitePartner => Icons.group_add_outlined,
      };

  static Color _color(ExpertActionKind kind) => switch (kind) {
        ExpertActionKind.recordReview ||
        ExpertActionKind.zoneApproval =>
          AdminColors.statYellow,
        ExpertActionKind.visitAssessment => AdminColors.statBlue,
        ExpertActionKind.reassignment ||
        ExpertActionKind.handover =>
          AdminColors.statPurple,
        ExpertActionKind.missedMonths => AdminColors.statRed,
        ExpertActionKind.sitePartner => AdminColors.statGreen,
      };
}
