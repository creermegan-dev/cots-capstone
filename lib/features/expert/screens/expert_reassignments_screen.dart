import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase_config.dart';
import '../../../models/follow_up_monitoring_model.dart';
import '../../../models/follow_up_reassignment.dart';
import '../../../models/site_partner.dart';
import '../../../services/site_partner_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/follow_up_monitoring_repository.dart';
import '../../../services/follow_up_reassignment_repository.dart';
import '../../../widgets/follow_up_reassignment_controls.dart';
import '../../../widgets/area_handover_controls.dart';
import '../../admin/theme/admin_theme.dart';
import '../../../widgets/cots_loading_skeleton.dart';

class ExpertReassignmentsScreen extends StatefulWidget {
  const ExpertReassignmentsScreen(
      {super.key,
      this.partnerApi = const SitePartnerApi(),
      this.requestsStream,
      this.handoversBuilder,
      this.requestDetailsBuilder,
      this.monitoringSummaryBuilder});
  final SitePartnerApi partnerApi;
  final Stream<List<FollowUpReassignment>>? requestsStream;
  final WidgetBuilder? handoversBuilder;
  final Widget Function(FollowUpReassignment)? requestDetailsBuilder;
  final Widget Function(FollowUpReassignment)? monitoringSummaryBuilder;
  @override
  State<ExpertReassignmentsScreen> createState() =>
      _ExpertReassignmentsScreenState();
}

class _ExpertReassignmentsScreenState extends State<ExpertReassignmentsScreen> {
  late Stream<List<FollowUpReassignment>> _requests =
      widget.requestsStream ?? FollowUpReassignmentRepository.watch();
  Future<List<SiteTeam>>? _teams;
  Future<List<SitePartnerRequest>>? _partners;
  int _tab = 0, _generation = 0;
  bool _busy = false;
  bool get _supportsSites =>
      SupabaseConfig.isConfigured || widget.requestsStream != null;

  void _refresh() => setState(() {
        _requests =
            widget.requestsStream ?? FollowUpReassignmentRepository.watch();
        _teams = null;
        _partners = null;
        _generation++;
      });

  Widget _card(Widget child) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AdminColors.cardWhite,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0))),
      child: Padding(padding: const EdgeInsets.all(18), child: child));

  Widget _empty(String text) => _card(Text(text));
  Widget _field(String label, String value) => SizedBox(
      width: 290,
      child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: AdminColors.muted)),
            const SizedBox(height: 4),
            Text(value.isEmpty ? 'Not recorded' : value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ])));

  Future<void> _decide(SitePartnerRequest request, bool approve) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(approve
                    ? 'Approve site partner?'
                    : 'Decline site partner?'),
                content: Text('${request.candidateName} · ${request.areaName}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(approve ? 'Approve' : 'Decline'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.partnerApi.decide(request.id, approve: approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(approve
                ? 'Site partner approved.'
                : 'Partner request declined.')));
        _refresh();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AuthService.messageFor(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _overview() => FutureBuilder<List<SiteTeam>>(
      future: _teams ??= widget.partnerApi.teams(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _empty('Could not load site teams. Use Refresh to try again.');
        }
        if (!snapshot.hasData) {
          return const CotsPageLoading(label: 'Loading site teams');
        }
        final teams = snapshot.data!;
        if (teams.isEmpty) return _empty('No assigned sites yet.');
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final team in teams)
                _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(team.areaName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      Wrap(spacing: 24, children: [
                        _field('Main diver', team.mainDiverName),
                        _field('Site partner',
                            team.partnerName ?? 'No approved partner')
                      ]),
                    ])),
            ]);
      });

  Widget _partnerRequests() => FutureBuilder<List<SitePartnerRequest>>(
      future: _partners ??= widget.partnerApi.requests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _empty(
              'Could not load partner requests. Use Refresh to try again.');
        }
        if (!snapshot.hasData) {
          return const CotsPageLoading(label: 'Loading partner requests');
        }
        final requests = snapshot.data!
            .where((r) => ['invited', 'waiting_expert'].contains(r.status))
            .toList();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (requests.isEmpty)
                _empty('No partner requests need attention.'),
              for (final request in requests)
                _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.areaName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(request.statusLabel,
                          style: const TextStyle(
                              color: AdminColors.statYellow,
                              fontWeight: FontWeight.w700)),
                      const Divider(height: 28),
                      Wrap(spacing: 24, children: [
                        _field('Main diver', request.mainDiverName),
                        _field('Proposed partner', request.candidateName),
                        _field('Request source', request.reasonText),
                        _field(
                            'Requested on',
                            request.createdAt == null
                                ? 'Not recorded'
                                : DateFormat('MMM d, yyyy').format(
                                    MonitoringMonth.local(request.createdAt!)))
                      ]),
                      if (request.canDecide)
                        Wrap(spacing: 12, runSpacing: 8, children: [
                          FilledButton(
                              onPressed:
                                  _busy ? null : () => _decide(request, true),
                              child: const Text('Approve partner')),
                          OutlinedButton(
                              onPressed:
                                  _busy ? null : () => _decide(request, false),
                              child: const Text('Decline'))
                        ]),
                    ])),
            ]);
      });

  Widget _coverage() => StreamBuilder<List<FollowUpReassignment>>(
      stream: _requests,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _empty(
              'Could not load coverage requests. Use Refresh to try again.');
        }
        if (!snapshot.hasData) {
          return const CotsPageLoading(label: 'Loading coverage requests');
        }
        final requests = snapshot.data!
            .where((r) => (r.isCurrent(DateTime.now()) &&
                ['requested', 'replacement_needed', 'awaiting_acceptance']
                    .contains(r.status)))
            .toList();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (requests.isEmpty)
                _empty('No coverage requests need attention.'),
              for (final request in requests)
                _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      widget.requestDetailsBuilder?.call(request) ??
                          ReassignmentDetails(
                              key: ValueKey(
                                  '${request.id}_${request.revision}_$_generation'),
                              requestId: request.id,
                              compact: true),
                      const Divider(height: 28),
                      widget.monitoringSummaryBuilder?.call(request) ??
                          _MonitoringSummary(request: request),
                    ])),
            ]);
      });

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Row(children: [
          const Expanded(
              child: Text('Site Coverage',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.headerTitle))),
          IconButton(
              onPressed: _busy ? null : _refresh,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh))
        ]),
        const Text('View site teams and manage coverage requests.',
            style: TextStyle(color: AdminColors.muted)),
        const SizedBox(height: 20),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final entry in [
                'Overview',
                'Partner requests',
                'Temporary coverage',
                'Handovers'
              ].asMap().entries)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                        label: Text(entry.value),
                        selected: _tab == entry.key,
                        onSelected: (_) => setState(() => _tab = entry.key))),
            ])),
        const SizedBox(height: 20),
        if (!_supportsSites && _tab != 2)
          _empty(
              'Site teams, partner requests and handovers are available in the Supabase version.')
        else
          switch (_tab) {
            0 => _overview(),
            1 => _partnerRequests(),
            2 => _coverage(),
            _ => KeyedSubtree(
                key: ValueKey(_generation),
                child: widget.handoversBuilder?.call(context) ??
                    const ExpertHandoversSection()),
          },
      ]);
}

class _MonitoringSummary extends StatelessWidget {
  const _MonitoringSummary({required this.request});
  final FollowUpReassignment request;
  Future<String> _summary() async {
    final assignment =
        await FollowUpMonitoringRepository.assignmentForArea(request.areaId);
    if (assignment == null) {
      throw StateError('Primary assignment is missing.');
    }
    final history =
        await FollowUpMonitoringRepository.loadAreaHistory(request.areaId);
    final captures = history.captures;
    final surveys = history.surveys;
    final valid = surveys
        .where((s) =>
            followUpSurveyStatus(s, captures) == FollowUpSurveyStatus.completed)
        .toList()
      ..sort((a, b) => b.surveyDate.compareTo(a.surveyDate));
    final completed = valid.any((s) =>
        s.surveyDate.year == request.month.year &&
        s.surveyDate.month == request.month.month);
    final past = request.month.isBefore(DateTime(
        MonitoringMonth.local(DateTime.now()).year,
        MonitoringMonth.local(DateTime.now()).month));
    return 'Last monitoring date: ${DateFormat('MMM d, yyyy').format(valid.isEmpty ? assignment.initialDate : valid.first.surveyDate)}\n'
        'Monthly monitoring: ${completed ? 'Monitored · Follow-up Completed' : past ? 'Not Recorded' : 'Awaiting Follow-up'}';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
      future: _summary(),
      builder: (context, snapshot) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: snapshot.hasError
                ? Text('Could not load monitoring summary: ${snapshot.error}')
                : snapshot.hasData
                    ? Text(snapshot.data!)
                    : const CotsLoadingSkeleton(
                        layout: CotsSkeletonLayout.section),
          ));
}
