import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/app_notification.dart';
import '../../../models/capture_model.dart';
import '../../../models/follow_up_monitoring_model.dart';
import '../../../models/follow_up_reassignment.dart';
import '../../../services/follow_up_reassignment_repository.dart';
import '../../../services/follow_up_workflow_store.dart';
import '../../../services/notification_repository.dart';
import '../../../widgets/follow_up_reassignment_controls.dart';
import '../../admin/theme/admin_theme.dart';
import '../../../widgets/cots_loading_skeleton.dart';

class ExpertReassignmentsScreen extends StatefulWidget {
  const ExpertReassignmentsScreen({super.key});
  @override
  State<ExpertReassignmentsScreen> createState() =>
      _ExpertReassignmentsScreenState();
}

class _ExpertReassignmentsScreenState extends State<ExpertReassignmentsScreen> {
  late Stream<List<FollowUpReassignment>> _requests =
      FollowUpReassignmentRepository.watch();
  bool _showHistory = false;
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<FollowUpReassignment>>(
        stream: _requests,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Could not load reassignments: ${snapshot.error}'),
              OutlinedButton(
                  onPressed: () => setState(
                      () => _requests = FollowUpReassignmentRepository.watch()),
                  child: const Text('Retry')),
            ]));
          }
          if (!snapshot.hasData) {
            return const CotsPageLoading(label: 'Loading Expert reassignments');
          }
          final requests = snapshot.data!
              .where((r) =>
                  _showHistory ||
                  (r.isCurrent(DateTime.now()) &&
                      ['requested', 'replacement_needed', 'awaiting_acceptance']
                          .contains(r.status)))
              .toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Reassignments',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.headerTitle)),
            const Text(
                'Review monthly follow-up requests and propose verified replacement divers.'),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title:
                    const Text('Include accepted, cancelled and past requests'),
                value: _showHistory,
                onChanged: (value) => setState(() => _showHistory = value)),
            StreamBuilder<List<AppNotification>>(
                stream: NotificationRepository.watchForUser('experts'),
                builder: (context, notifications) => ExpansionTile(
                        title: const Text('Workflow notifications'),
                        children: [
                          if (notifications.hasError)
                            Text(
                                'Could not load notifications: ${notifications.error}'),
                          if (!notifications.hasData && !notifications.hasError)
                            const CotsLoadingSkeleton(
                                layout: CotsSkeletonLayout.section),
                          for (final n
                              in (notifications.data ?? <AppNotification>[])
                                  .take(10))
                            ListTile(
                                title: Text(n.title),
                                subtitle: Text(n.body),
                                onTap: () => showReassignmentDetails(
                                    context, n.relatedRecordId)),
                        ])),
            if (requests.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No requests requiring Expert attention.')),
            for (final request in requests)
              Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MonitoringSummary(request: request),
                          ReassignmentDetails(
                              key:
                                  ValueKey('${request.id}_${request.revision}'),
                              requestId: request.id),
                        ])),
              ),
          ]);
        },
      );
}

class _MonitoringSummary extends StatelessWidget {
  const _MonitoringSummary({required this.request});
  final FollowUpReassignment request;
  Future<String> _summary() async {
    final store = FollowUpReassignmentRepository.store;
    final assignmentDoc =
        await store.get('follow_up_assignments/${request.areaId}');
    if (assignmentDoc == null) {
      throw StateError('Primary assignment is missing.');
    }
    final assignment = FollowUpAssignmentModel.fromMap(
        FollowUpWorkflowStore.data(assignmentDoc),
        areaId: request.areaId);
    final docs = await store.query('follow_up_surveys',
        field: 'area_id', value: request.areaId);
    final captures = (await store.query('captures',
            field: 'monitoring_area_id', value: request.areaId))
        .map(CaptureModel.fromRestDocument)
        .toList();
    final surveys = docs
        .map((doc) => FollowUpSurveyModel.fromMap(
            FollowUpWorkflowStore.data(doc),
            id: (doc['name'] as String).split('/').last))
        .toList();
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
