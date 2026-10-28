import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/cots_colors.dart';
import '../models/follow_up_monitoring_model.dart';
import '../models/follow_up_reassignment.dart';
import '../models/follow_up_infestation_assessment.dart';
import '../providers/auth_provider.dart';
import '../services/follow_up_reassignment_repository.dart';
import '../services/follow_up_workflow_store.dart';
import 'cots_loading_skeleton.dart';

class FollowUpAssessmentLabel extends StatefulWidget {
  const FollowUpAssessmentLabel({super.key, required this.areaId});
  final String areaId;
  @override
  State<FollowUpAssessmentLabel> createState() =>
      _FollowUpAssessmentLabelState();
}

class _FollowUpAssessmentLabelState extends State<FollowUpAssessmentLabel> {
  late Future<FollowUpInfestationAssessment?> _assessment =
      FollowUpReassignmentRepository.latestAssessment(widget.areaId);
  @override
  void didUpdateWidget(covariant FollowUpAssessmentLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _assessment =
        FollowUpReassignmentRepository.latestAssessment(widget.areaId);
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<FollowUpInfestationAssessment?>(
          future: _assessment,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return TextButton(
                  onPressed: () => setState(() => _assessment =
                      FollowUpReassignmentRepository.latestAssessment(
                          widget.areaId)),
                  child:
                      const Text('Could not load validated assessment. Retry'));
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const CotsLoadingSkeleton(
                  layout: CotsSkeletonLayout.section);
            }
            final assessment = snapshot.data;
            return Text(
                assessment == null
                    ? 'Latest validated infestation level: Not available'
                    : 'Latest validated infestation level: ${assessment.level}${assessment.isHigh ? ' · High-risk area' : ''}\n'
                        'Survey: ${DateFormat('MMM d, yyyy').format(MonitoringMonth.local(assessment.surveyDate))}',
                style: TextStyle(
                    color: assessment?.isHigh == true ? kDangerRed : kTextNavy,
                    fontWeight: assessment?.isHigh == true
                        ? FontWeight.w700
                        : FontWeight.normal));
          });
}

String _eventLabel(String action) => switch (action) {
      'requested' => 'Reassignment Requested',
      'proposed' => 'Awaiting Acceptance',
      'accepted' => 'Accepted',
      'declined' => 'Declined — Replacement Needed',
      'proposal_cancelled' => 'Pending Proposal Cancelled',
      'cancelled' => 'Cancelled',
      _ => action,
    };

Future<void> showReassignmentDetails(BuildContext context, String id) =>
    showDialog<void>(
        context: context,
        builder: (_) => Dialog(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child:
                          ReassignmentDetails(requestId: id, closeable: true))),
            ));

class FollowUpReassignmentActions extends StatefulWidget {
  const FollowUpReassignmentActions(
      {super.key, required this.assignment, required this.onStart});
  final FollowUpAssignmentModel assignment;
  final VoidCallback onStart;
  @override
  State<FollowUpReassignmentActions> createState() =>
      _FollowUpReassignmentActionsState();
}

class _FollowUpReassignmentActionsState
    extends State<FollowUpReassignmentActions> {
  String? _uid;
  Stream<List<FollowUpReassignment>>? _requests;
  void _refresh() {
    if (mounted) {
      setState(
          () => _requests = FollowUpReassignmentRepository.watch(uid: _uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel!;
    if (_uid != user.uid) {
      _uid = user.uid;
      _requests = FollowUpReassignmentRepository.watch(uid: _uid);
    }
    final assignment = widget.assignment;
    return StreamBuilder<List<FollowUpReassignment>>(
      stream: _requests,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(children: [
            Text('Could not load reassignment: ${snapshot.error}'),
            TextButton(onPressed: _refresh, child: const Text('Retry')),
          ]);
        }
        if (!snapshot.hasData) {
          return const CotsLoadingSkeleton(layout: CotsSkeletonLayout.section);
        }
        final matches = snapshot.data!.where((r) =>
            r.areaId == assignment.areaId && r.isCurrent(DateTime.now()));
        final request = matches.isEmpty ? null : matches.first;
        final responsible =
            request?.responsibleUid ?? assignment.primaryDiverUid;
        final authorized = responsible == user.uid;
        final canStart = authorized &&
            (user.uid == assignment.primaryDiverUid ||
                (user.accountRole == 'user' &&
                    user.isActive &&
                    user.fieldPersonnelVerified));
        final temporary = authorized && user.uid != assignment.primaryDiverUid;
        final canRequest = authorized &&
            (request == null ||
                ['accepted', 'cancelled'].contains(request.status));
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (temporary)
                Text(
                    'Temporary Assignment · ${DateFormat('MMMM yyyy').format(request!.month)}\n'
                    'Original diver: ${assignment.primaryDiverName}',
                    style: const TextStyle(
                        color: kPrimaryTeal, fontWeight: FontWeight.w700)),
              if (request != null)
                TextButton(
                  onPressed: () async {
                    await showReassignmentDetails(context, request.id);
                    _refresh();
                  },
                  child: Text(request.statusLabel),
                ),
              if (!authorized)
                const Text('Another diver is responsible for this month.'),
              if (authorized && !canStart)
                const Text(
                    'Field verification is required to conduct this temporary assignment.'),
              OutlinedButton(
                  onPressed: canStart ? widget.onStart : null,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  child: const Text('Start Follow-up Survey')),
              if (canRequest)
                OutlinedButton.icon(
                  onPressed: () async {
                    await showDialog<void>(
                        context: context,
                        builder: (_) => _RequestDialog(assignment: assignment));
                    _refresh();
                  },
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Unavailable This Month'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
            ]);
      },
    );
  }
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({required this.assignment});
  final FollowUpAssignmentModel assignment;
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FollowUpReassignmentRepository.request(
          assignment: widget.assignment,
          user: context.read<AuthProvider>().userModel!,
          reason: _reason.text);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Unavailable This Month'),
        scrollable: true,
        content: SizedBox(
            width: 440,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.assignment.areaName),
                  Text(context.read<AuthProvider>().userModel!.fullName),
                  Text(DateFormat('MMMM yyyy')
                      .format(MonitoringMonth.local(DateTime.now()))),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _reason,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                          labelText: 'Reason for unavailability (required)',
                          border: OutlineInputBorder())),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: kDangerRed)),
                ])),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Submitting…' : 'Submit Request'))
        ],
      );
}

class ReassignmentDetails extends StatefulWidget {
  const ReassignmentDetails(
      {super.key, required this.requestId, this.closeable = false});
  final String requestId;
  final bool closeable;
  @override
  State<ReassignmentDetails> createState() => _ReassignmentDetailsState();
}

class _ReassignmentDetailsState extends State<ReassignmentDetails> {
  late Future<FollowUpReassignment> _request = _load();
  bool _busy = false;
  String? _error;
  Future<FollowUpReassignment> _load() async {
    final doc = await FollowUpReassignmentRepository.store
        .get('follow_up_reassignments/${widget.requestId}');
    if (doc == null) {
      throw StateError('This reassignment request no longer exists.');
    }
    return FollowUpReassignment(
        widget.requestId, FollowUpWorkflowStore.data(doc));
  }

  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
      if (mounted) setState(() => _request = _load());
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(FollowUpReassignment request, String expert) async {
    final directory = await FollowUpReassignmentRepository.directory();
    if (!mounted) return;
    final candidates = directory
        .where((p) => p['uid'] != request.responsibleUid)
        .toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) =>
            SimpleDialog(title: const Text('Assign Replacement'), children: [
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                      'Select a verified field diver. The assignment activates only after acceptance.')),
              if (candidates.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                        'No eligible divers are listed. An administrator can publish the field personnel directory.')),
              for (final person in candidates)
                SimpleDialogOption(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    onPressed: () => Navigator.pop(context, person),
                    child: Text(person['name'] as String)),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
            ]));
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Confirm proposed replacement'),
                content: Text(
                    'Send ${selected['name']} the ${DateFormat('MMMM yyyy').format(request.month)} assignment for ${request.data['area_name']}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Send Proposal'))
                ]));
    if (confirmed == true) {
      await FollowUpReassignmentRepository.propose(request, expert, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().userModel!;
    return FutureBuilder<FollowUpReassignment>(
        future: _request,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Column(mainAxisSize: MainAxisSize.min, children: [
              if (snapshot.hasError)
                Text('Could not load request: ${snapshot.error}')
              else
                const CotsLoadingSkeleton(
                    layout: CotsSkeletonLayout.section,
                    label: 'Loading request'),
              TextButton(
                  onPressed: () => setState(() => _request = _load()),
                  child: const Text('Retry')),
              if (widget.closeable)
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
            ]);
          }
          final r = snapshot.data!;
          final current = r.isCurrent(DateTime.now());
          final d = r.data;
          return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${d['area_name']} · ${d['barangay']}',
                    style: Theme.of(context).textTheme.titleMedium),
                Text('Original diver: ${d['primary_name']}'),
                Text(
                    'Monitoring month: ${DateFormat('MMMM yyyy').format(r.month)}'),
                Text('Reason: ${d['reason']}'),
                Text(
                    'Requested: ${DateFormat('MMM d, yyyy').format(MonitoringMonth.local(d['requested_at'] as DateTime))}'),
                Text('Reassignment: ${r.statusLabel}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (r.replacementUid.isNotEmpty)
                  Text('Proposed replacement: ${d['replacement_name']}'),
                const Text(
                    'Acceptance is separate from monitoring completion.'),
                FollowUpAssessmentLabel(areaId: r.areaId),
                if (!current)
                  const Text(
                      'This calendar month has ended. No new assignment actions are available.'),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: kDangerRed)),
                if (_busy) const LinearProgressIndicator(),
                if (current &&
                    user.isExpert &&
                    ['requested', 'replacement_needed'].contains(r.status))
                  FilledButton(
                      onPressed:
                          _busy ? null : () => _run(() => _select(r, user.uid)),
                      child: const Text('Assign Replacement')),
                if (current &&
                    user.isExpert &&
                    r.status == 'awaiting_acceptance')
                  OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() =>
                              FollowUpReassignmentRepository.cancelProposal(
                                  r, user.uid)),
                      child: const Text('Cancel Pending Proposal')),
                if (current &&
                    r.status == 'awaiting_acceptance' &&
                    r.replacementUid == user.uid) ...[
                  FilledButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() =>
                              FollowUpReassignmentRepository.respond(
                                  r, user.uid, true)),
                      child: const Text('Accept Assignment')),
                  OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() =>
                              FollowUpReassignmentRepository.respond(
                                  r, user.uid, false)),
                      child: const Text('Decline Assignment')),
                ],
                if (current &&
                    (user.isExpert || r.responsibleUid == user.uid) &&
                    ['requested', 'replacement_needed', 'awaiting_acceptance']
                        .contains(r.status))
                  TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() =>
                              FollowUpReassignmentRepository.cancelRequest(
                                  r, user.uid)),
                      child: const Text('Cancel Reassignment Request')),
                ExpansionTile(
                    title: const Text('Reassignment history'),
                    children: [
                      FutureBuilder<List<Map<String, dynamic>>>(
                          future: FollowUpReassignmentRepository.history(r.id),
                          builder: (context, history) {
                            if (history.hasError) {
                              return Text(
                                  'Could not load audit history: ${history.error}');
                            }
                            if (!history.hasData) {
                              return const CotsLoadingSkeleton(
                                  layout: CotsSkeletonLayout.section);
                            }
                            return Column(children: [
                              for (final event in history.data!)
                                ListTile(
                                  title: Text(
                                      '${event['revision']}. ${_eventLabel(event['action'] as String)}'),
                                  subtitle: Text(
                                      'Actor: ${event['actor_uid']}\n${event['at']}\nReplacement: ${(event['state'] as Map)['replacement_name']}'),
                                )
                            ]);
                          }),
                    ]),
                TextButton(
                    onPressed:
                        _busy ? null : () => setState(() => _request = _load()),
                    child: const Text('Refresh')),
                if (widget.closeable)
                  TextButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Close')),
              ]);
        });
  }
}
