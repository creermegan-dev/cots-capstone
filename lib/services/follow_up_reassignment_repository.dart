import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../core/supabase_config.dart';
import '../models/follow_up_monitoring_model.dart';
import '../models/follow_up_infestation_assessment.dart';
import '../models/follow_up_reassignment.dart';
import '../models/user_model.dart';
import 'follow_up_workflow_store.dart';
import 'supabase_follow_up_service.dart';

abstract final class FollowUpReassignmentRepository {
  static FollowUpWorkflowStore _store = FollowUpWorkflowStore();
  static FollowUpWorkflowStore get store => _store;
  @visibleForTesting
  static set store(FollowUpWorkflowStore value) => _store = value;
  static const collection = 'follow_up_reassignments';

  static bool get _useSupabase => SupabaseConfig.isConfigured;

  /// With Supabase, the database returns only the requests the signed-in
  /// person may see (all of them for the Expert), so [uid] is not needed.
  static Stream<List<FollowUpReassignment>> watch({String? uid}) async* {
    if (_useSupabase) {
      yield* SupabaseFollowUpService.poll(SupabaseFollowUpService.reassignments);
      return;
    }
    Future<List<FollowUpReassignment>> load() async {
      final docs = await store.query(collection,
          field: uid == null ? null : 'participants',
          value: uid,
          op: 'ARRAY_CONTAINS');
      final items = docs
          .map((doc) => FollowUpReassignment(
              (doc['name'] as String).split('/').last,
              FollowUpWorkflowStore.data(doc)))
          .toList();
      items.sort((a, b) => (b.data['requested_at'] as DateTime)
          .compareTo(a.data['requested_at'] as DateTime));
      return items;
    }

    yield await load();
    yield* Stream.periodic(const Duration(seconds: 15)).asyncMap((_) => load());
  }

  /// One request by its ID.
  static Future<FollowUpReassignment?> getRequest(String id) async {
    if (_useSupabase) {
      final list = await SupabaseFollowUpService.reassignments(requestId: id);
      return list.isEmpty ? null : list.first;
    }
    final doc = await store.get('$collection/$id');
    return doc == null
        ? null
        : FollowUpReassignment(id, FollowUpWorkflowStore.data(doc));
  }

  static Future<FollowUpReassignment?> forMonth(
      String areaId, DateTime instant) async {
    if (_useSupabase) {
      final key = MonitoringMonth.key(instant);
      for (final request in await SupabaseFollowUpService.reassignments()) {
        if (request.areaId == areaId &&
            '${request.data['year']}_${request.data['month']}' == key &&
            !['cancelled'].contains(request.status)) {
          return request;
        }
      }
      return null;
    }
    final id = MonitoringMonth.id(areaId, instant);
    final doc = await store.get('$collection/$id');
    return doc == null
        ? null
        : FollowUpReassignment(id, FollowUpWorkflowStore.data(doc));
  }

  static Future<bool> isResponsible(FollowUpAssignmentModel assignment,
      String uid, DateTime surveyDate) async {
    if (_useSupabase) {
      // The database knows this month's responsible Diver.
      return SupabaseFollowUpService.canSubmit(assignment.areaId, surveyDate);
    }
    // Survey dates are calendar dates, not UTC instants.
    final instant =
        DateTime.utc(surveyDate.year, surveyDate.month, surveyDate.day, 4);
    final request = await forMonth(assignment.areaId, instant);
    return (request?.responsibleUid ?? assignment.primaryDiverUid) == uid &&
        (uid == assignment.primaryDiverUid ||
            MonitoringMonth.surveyKey(surveyDate) ==
                MonitoringMonth.key(DateTime.now()));
  }

  static Future<void> ensureMonthAuthorization(
      FollowUpAssignmentModel assignment, String uid, DateTime date) async {
    // Supabase starts each month for the original Diver by itself.
    if (_useSupabase) return;
    final id = '${assignment.areaId}_${date.year}_${date.month}';
    if (await store.get('follow_up_month_authorizations/$id') != null) return;
    if (uid != assignment.primaryDiverUid) {
      throw StateError('This month is not assigned to you.');
    }
    try {
      await store.commit([
        store.write(
            'follow_up_month_authorizations/$id',
            {
              'area_id': assignment.areaId,
              'year': date.year,
              'month': date.month,
              'primary_uid': assignment.primaryDiverUid,
              'responsible_uid': uid,
            },
            create: true)
      ]);
    } catch (_) {
      // A concurrent request may have initialized the same month. Never overwrite it.
      if (await store.get('follow_up_month_authorizations/$id') == null) {
        rethrow;
      }
    }
  }

  static Future<List<Map<String, dynamic>>> directory() async {
    if (_useSupabase) return SupabaseFollowUpService.directory();
    return (await store.query('follow_up_personnel',
            field: 'eligible', value: true))
        .map((doc) => {
              ...FollowUpWorkflowStore.data(doc),
              'uid': (doc['name'] as String).split('/').last,
            })
        .where((entry) => entry['eligible'] == true)
        .toList();
  }

  static Future<FollowUpInfestationAssessment?> latestAssessment(
      String areaId) async {
    if (_useSupabase) return SupabaseFollowUpService.latestAssessment(areaId);
    final assessments = (await store.query('follow_up_assessments',
            field: 'area_id', value: areaId))
        .map((doc) => FollowUpInfestationAssessment.fromMap(
            FollowUpWorkflowStore.data(doc)))
        .whereType<FollowUpInfestationAssessment>()
        .toList()
      ..sort((a, b) {
        final date = b.surveyDate.compareTo(a.surveyDate);
        return date == 0 ? b.validatedAt.compareTo(a.validatedAt) : date;
      });
    return assessments.isEmpty ? null : assessments.first;
  }

  /// Admin-only publication. No email, phone, photo or organization is exposed.
  static Future<void> publishPersonnel(List<UserModel> users) async {
    // Supabase reads approved Divers directly; nothing to publish.
    if (_useSupabase) return;
    for (final user in users) {
      final eligible = user.accountRole == 'user' &&
          user.isActive &&
          user.fieldPersonnelVerified;
      if (!eligible) {
        await store.commit([
          {'delete': '${store.root}/follow_up_personnel/${user.uid}'}
        ]);
        continue;
      }
      await store.commit([
        store.write('follow_up_personnel/${user.uid}', {
          'name': user.fullName,
          'eligible': true,
        })
      ]);
    }
  }

  static Future<void> request(
      {required FollowUpAssignmentModel assignment,
      required UserModel user,
      required String reason}) async {
    if (reason.trim().isEmpty || reason.trim().length > 2000) {
      throw ArgumentError('Enter a reason of up to 2,000 characters.');
    }
    if (_useSupabase) {
      await SupabaseFollowUpService.request(assignment.areaId, reason);
      return;
    }
    final now = MonitoringMonth.local(DateTime.now());
    final id = MonitoringMonth.id(assignment.areaId, DateTime.now());
    final existing = await store.get('$collection/$id');
    final old = existing == null ? null : FollowUpWorkflowStore.data(existing);
    if (old != null &&
        (old['responsible_uid'] != user.uid ||
            !['accepted', 'cancelled'].contains(old['status']))) {
      throw StateError('A reassignment request already exists for this month.');
    }
    final next = <String, dynamic>{
      if (old != null) ...old,
      'area_id': assignment.areaId,
      'area_name': assignment.areaName,
      'barangay': assignment.barangay,
      'municipality': assignment.municipality,
      'primary_uid': assignment.primaryDiverUid,
      'primary_name': assignment.primaryDiverName,
      'year': now.year,
      'month': now.month,
      'responsible_uid': old?['responsible_uid'] ?? assignment.primaryDiverUid,
      'requester_uid': user.uid,
      'reason': reason.trim(),
      'status': 'requested',
      'replacement_uid': '',
      'replacement_name': '',
      'expert_uid': '',
      'participants': old?['participants'] ?? [assignment.primaryDiverUid],
      'revision': (old?['revision'] as int? ?? 0) + 1,
      'requested_at': old?['requested_at'] ?? DateTime.now().toUtc(),
      'updated_at': DateTime.now().toUtc(),
    };
    await _save(id, next, existing, user.uid, 'requested');
  }

  static Future<void> propose(FollowUpReassignment request, String expertUid,
      Map<String, dynamic> personnel) async {
    if (personnel['uid'] == request.responsibleUid ||
        personnel['eligible'] != true) {
      throw StateError('Select another eligible field diver.');
    }
    if (_useSupabase) {
      await SupabaseFollowUpService.propose(
          request.id, personnel['uid'] as String);
      return;
    }
    await _change(request, expertUid, 'proposed', {
      'status': 'awaiting_acceptance',
      'expert_uid': expertUid,
      'replacement_uid': personnel['uid'],
      'replacement_name': personnel['name'],
      'participants': {
        ...(request.data['participants'] as List).cast<String>(),
        personnel['uid'] as String
      }.toList(),
    });
  }

  static Future<void> respond(
      FollowUpReassignment request, String uid, bool accept) async {
    if (_useSupabase) {
      final proposalId = request.data['proposal_id'] as String? ?? '';
      if (proposalId.isEmpty) {
        throw StateError('This proposal is no longer available. Refresh.');
      }
      await SupabaseFollowUpService.respond(proposalId, accept);
      return;
    }
    await _change(request, uid, accept ? 'accepted' : 'declined', {
      'status': accept ? 'accepted' : 'replacement_needed',
      if (accept) 'responsible_uid': uid,
    });
  }

  static Future<void> cancelProposal(
      FollowUpReassignment request, String expertUid) async {
    if (_useSupabase) {
      await SupabaseFollowUpService.cancelProposal(request.id);
      return;
    }
    await _change(request, expertUid, 'proposal_cancelled',
        {'status': 'replacement_needed'});
  }

  static Future<void> cancelRequest(
      FollowUpReassignment request, String uid) async {
    if (_useSupabase) {
      await SupabaseFollowUpService.cancelRequest(request.id);
      return;
    }
    await _change(request, uid, 'cancelled', {'status': 'cancelled'});
  }

  static Future<void> _change(FollowUpReassignment request, String actor,
      String action, Map<String, dynamic> changes) async {
    final existing = await store.get('$collection/${request.id}');
    if (existing == null ||
        FollowUpWorkflowStore.data(existing)['revision'] != request.revision) {
      throw StateError('This request changed. Refresh before trying again.');
    }
    await _save(
        request.id,
        {
          ...request.data,
          ...changes,
          'revision': request.revision + 1,
          'updated_at': DateTime.now().toUtc(),
        },
        existing,
        actor,
        action);
  }

  static Future<void> _save(String id, Map<String, dynamic> next,
      Map<String, dynamic>? existing, String actor, String action) async {
    final revision = next['revision'] as int;
    final eventId = '${id}_$revision';
    final recipients = <String>{
      'experts',
      next['primary_uid'] as String,
      if ((next['replacement_uid'] as String).isNotEmpty)
        next['replacement_uid'] as String,
      if (existing != null &&
          (FollowUpWorkflowStore.data(existing)['replacement_uid'] as String)
              .isNotEmpty)
        FollowUpWorkflowStore.data(existing)['replacement_uid'] as String,
    };
    final month = DateFormat('MMMM yyyy')
        .format(DateTime(next['year'] as int, next['month'] as int));
    final title = action == 'proposed'
        ? 'New Follow-up Assignment'
        : switch (action) {
            'requested' => 'Follow-up replacement requested',
            'accepted' => 'Replacement accepted',
            'declined' => 'Replacement declined — replacement needed',
            'proposal_cancelled' => 'Pending replacement cancelled',
            'cancelled' => 'Reassignment request cancelled',
            _ => 'Follow-up reassignment updated',
          };
    final assessment = action == 'proposed'
        ? await latestAssessment(next['area_id'] as String)
        : null;
    final body = '$month · ${next['area_name']} · ${next['barangay']}\n'
        'Original diver: ${next['primary_name']}\n'
        '${action == 'proposed' ? 'Please accept or decline this assignment.' : title}\n'
        'Latest validated infestation level: ${assessment?.level ?? 'Not available'}.';
    await store.commit([
      store.write('follow_up_month_authorizations/$id', {
        'area_id': next['area_id'],
        'year': next['year'],
        'month': next['month'],
        'primary_uid': next['primary_uid'],
        'responsible_uid': next['responsible_uid'],
      }),
      store.write('$collection/$id', next,
          existing: existing,
          create: existing == null,
          serverTimes: ['updated_at', if (existing == null) 'requested_at']),
      store.write(
          'follow_up_reassignment_events/$eventId',
          {
            'request_id': id,
            'revision': revision,
            'actor_uid': actor,
            'action': action,
            'at': DateTime.now().toUtc(),
            'state': next,
          },
          create: true,
          serverTimes: [
            'at',
            'state.updated_at',
            if (existing == null) 'state.requested_at'
          ]),
      for (final recipient in recipients)
        store.write(
            'notifications/${eventId}_$recipient',
            {
              'recipient_uid': recipient,
              'type': 'follow_up_reassignment',
              'title': title,
              'body': body,
              'related_record_id': id,
              'zone': next['area_name'],
              'is_read': false,
              'event_revision': revision,
              'created_at': DateTime.now().toUtc(),
            },
            create: true,
            serverTimes: ['created_at']),
    ]);
  }

  static Future<List<Map<String, dynamic>>> history(String requestId) async {
    if (_useSupabase) return SupabaseFollowUpService.history(requestId);
    return (await store.query('follow_up_reassignment_events',
            field: 'request_id', value: requestId))
        .map(FollowUpWorkflowStore.data)
        .toList()
      ..sort(
          (a, b) => (a['revision'] as int).compareTo(b['revision'] as int));
  }
}
