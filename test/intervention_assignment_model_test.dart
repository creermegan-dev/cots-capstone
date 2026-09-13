import 'package:cots_monitor/models/intervention_assignment_model.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assignment parses workflow fields', () {
    final due = DateTime(2026, 7, 30);
    final assignment = InterventionAssignmentModel.fromMap(
      {
        'capture_id': 'capture-1',
        'capture_display_id': 'CAP-0001',
        'zone': 'Zone A',
        'assigned_to_uid': 'person-1',
        'assigned_to_name': 'Field Diver',
        'assigned_by_uid': 'admin-1',
        'assigned_by_name': 'Administrator',
        'status': InterventionAssignmentModel.assignedStatus,
        'due_at': due,
      },
      captureId: 'fallback',
    );

    expect(assignment.captureId, 'capture-1');
    expect(assignment.assignedToUid, 'person-1');
    expect(assignment.dueAt, due);
    expect(assignment.isOpen, isTrue);
  });

  test('only active normal users qualify as verified field personnel', () {
    final user = UserModel.fromMap(
      {
        'uid': 'person-1',
        'fullName': 'Field Diver',
        'accountRole': UserModel.defaultAccountRole,
        'fieldPersonnelVerified': true,
        'isActive': true,
      },
      uid: 'person-1',
    );

    expect(user.isVerifiedFieldPersonnel, isTrue);
    expect(
      user
          .copyWith(accountRole: UserModel.adminAccountRole)
          .isVerifiedFieldPersonnel,
      isFalse,
    );
  });
}
