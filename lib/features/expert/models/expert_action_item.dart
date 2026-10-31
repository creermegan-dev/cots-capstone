import 'package:intl/intl.dart';

import '../../../models/area_handover.dart';
import '../../../models/follow_up_monitoring_model.dart';
import '../../../models/follow_up_reassignment.dart';
import '../../../models/zone_review.dart';
import '../../admin/models/admin_record_table_row.dart';

/// Expert Notifications tab (claude/agreed_workflow_decisions.md): the tab of
/// the Expert Workspace where the Expert acts on an item.
enum ExpertActionPlace {
  verification('Verification'),
  reassignments('Reassignments'),
  assessments('Assessments');

  const ExpertActionPlace(this.label);
  final String label;
}

/// The kinds of work that wait for the Expert, in the order they are listed.
enum ExpertActionKind {
  recordReview,
  zoneApproval,
  visitAssessment,
  reassignment,
  handover,
  missedMonths,
}

/// One thing that is waiting for the Expert. It leaves the list once the
/// Expert has handled it, because the list is built from the current data.
class ExpertActionItem {
  const ExpertActionItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.detail,
  });

  final ExpertActionKind kind;
  final String id;
  final String title;
  final String detail;

  ExpertActionPlace get place => switch (kind) {
        ExpertActionKind.recordReview ||
        ExpertActionKind.zoneApproval =>
          ExpertActionPlace.verification,
        ExpertActionKind.visitAssessment => ExpertActionPlace.assessments,
        ExpertActionKind.reassignment ||
        ExpertActionKind.handover ||
        ExpertActionKind.missedMonths =>
          ExpertActionPlace.reassignments,
      };
}

/// Builds the "Needs your action" list from what the Expert can already see
/// on the other tabs. Nothing here decides a rule: each check uses the same
/// field the matching tab uses.
abstract final class ExpertActions {
  static const recordReviewTitle = 'Detection needs review';
  static const zoneApprovalTitle = 'Record needs your approval';
  static const visitTitle = 'Monthly visit waiting for assessment';
  static const reassignmentTitle =
      'Reassignment request: choose a replacement Diver';
  static const reassignmentDeclinedTitle =
      'Replacement declined: choose another Diver';
  static const handoverTitle = 'Area handover: choose a new Diver';
  static const handoverDeclinedTitle =
      'Handover offer declined: choose another Diver';
  static String missedMonthsTitle(int months) =>
      '$months missed months in a row';
  static const missedMonthsHint = 'You can start an area handover.';

  /// Reassignment statuses that wait for the Expert to choose a Diver.
  /// 'awaiting_acceptance' waits for the offered Diver, not the Expert.
  static const reassignmentStatuses = {'requested', 'replacement_needed'};

  static final _day = DateFormat('MMM d, yyyy');
  static final _month = DateFormat('MMMM yyyy');

  static String _join(List<String?> parts) => parts
      .map((part) => part?.trim() ?? '')
      .where((part) => part.isNotEmpty)
      .join(' · ');

  static List<ExpertActionItem> build({
    List<AdminRecordTableRow> records = const [],
    List<FollowUpSurveyModel> visits = const [],
    List<FollowUpReassignment> reassignments = const [],
    List<AreaHandover> handovers = const [],
    List<AreaMissedMonths> missedMonths = const [],
    required DateTime now,
  }) {
    final items = <ExpertActionItem>[];

    // Verification tab: the same "Needs Review" status the tab shows.
    for (final row in records) {
      if (row.displayStatus != 'Needs Review') continue;
      final id = row.documentId.isNotEmpty ? row.documentId : row.recordId;
      final zoneRecord = ZoneReview.isWaiting(
        assignedTo: row.zoneAssignedTo,
        confirmed: row.adminConfirmed,
        rejected: row.adminRejected,
      );
      items.add(zoneRecord
          ? ExpertActionItem(
              kind: ExpertActionKind.zoneApproval,
              id: id,
              title: zoneApprovalTitle,
              detail: _join([
                ZoneReview.expertTitle,
                row.recordId,
                row.zone,
                'by ${row.submittedBy}',
                'zone assigned to ${row.zoneAssignedTo}',
              ]),
            )
          : ExpertActionItem(
              kind: ExpertActionKind.recordReview,
              id: id,
              title: recordReviewTitle,
              detail: _join([
                row.recordId,
                row.zone,
                'by ${row.submittedBy}',
                row.dateTime,
              ]),
            ));
    }

    // Assessments tab: every visit in it still waits for an assessment.
    for (final visit in visits) {
      items.add(ExpertActionItem(
        kind: ExpertActionKind.visitAssessment,
        id: visit.id,
        title: visitTitle,
        detail: [
          _join([
            visit.areaName,
            visit.barangay,
            _day.format(visit.surveyDate),
            'by ${visit.submittedBy}',
          ]),
          // Stage 5: the early-visit flag.
          if (visit.earlyVisitNote != null) visit.earlyVisitNote!,
        ].join('\n'),
      ));
    }

    // Reassignments tab: this month's requests that wait for the Expert.
    for (final request in reassignments) {
      if (!request.isCurrent(now) ||
          !reassignmentStatuses.contains(request.status)) {
        continue;
      }
      final mainDiver = request.data['primary_name']?.toString() ?? '';
      items.add(ExpertActionItem(
        kind: ExpertActionKind.reassignment,
        id: request.id,
        title: request.status == 'replacement_needed'
            ? reassignmentDeclinedTitle
            : reassignmentTitle,
        detail: _join([
          request.data['area_name']?.toString(),
          _month.format(request.month),
          if (mainDiver.isNotEmpty) 'main Diver: $mainDiver',
        ]),
      ));
    }

    // Reassignments tab: handovers where the database lets the Expert offer.
    for (final handover in handovers) {
      if (!handover.canOffer) continue;
      items.add(ExpertActionItem(
        kind: ExpertActionKind.handover,
        id: handover.id,
        title: handover.offerStatus == 'declined'
            ? handoverDeclinedTitle
            : handoverTitle,
        detail: _join([
          handover.areaName,
          handover.startedByExpert
              ? 'started after missed months'
              : 'requested by ${handover.fromDiverName}',
          handover.reason,
        ]),
      ));
    }

    // Reassignments tab: areas where the Expert can start a handover.
    for (final area in missedMonths) {
      if (!area.canStartHandover) continue;
      items.add(ExpertActionItem(
        kind: ExpertActionKind.missedMonths,
        id: area.areaCode,
        title: missedMonthsTitle(area.missedMonths),
        detail: _join([
          area.areaName,
          'main Diver: ${area.mainDiverName}',
          missedMonthsHint,
        ]),
      ));
    }

    // Stable order by kind; within a kind, the order the tab uses.
    final order = {
      for (final kind in ExpertActionKind.values) kind: kind.index,
    };
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final byKind = order[a.$2.kind]!.compareTo(order[b.$2.kind]!);
      return byKind != 0 ? byKind : a.$1.compareTo(b.$1);
    });
    return [for (final entry in indexed) entry.$2];
  }
}
