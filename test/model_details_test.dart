import 'package:cots_monitor/features/user/user_submission_details_page.dart';
import 'package:cots_monitor/models/capture_model.dart';
import 'package:cots_monitor/models/scan_record_model.dart';
import 'package:cots_monitor/models/staff_submission_rows.dart';
import 'package:cots_monitor/models/submission_group.dart';
import 'package:cots_monitor/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cots_monitor/models/user_model.dart';

class _RoleAuth extends AuthProvider {
  _RoleAuth(this.expert);
  final bool expert;
  @override
  UserModel? get userModel => UserModel.fromSupabaseProfile(
      {'id': 'viewer', 'full_name': 'Viewer', 'active': true},
      email: '', privilegedRole: expert ? 'expert' : 'user');
}

ScanRecordModel _photo(String id, String model) =>
    ScanRecordModel.fromCapture(CaptureModel(
        id: id,
        uid: 'diver',
        submittedBy: 'Diver',
        imageName: '$id.jpg',
        aiDetectedCount: 1,
        confidence: .9,
        captureSource: 'camera',
        zone: 'Site 4 · Balet',
        notes: '',
        submittedAt: DateTime.utc(2026, 11, 10),
        encounterId: 'batch',
        monitoringAreaId: 'S4',
        modelName: model));

void main() {
  test('staff adapters and copied rows preserve the individual photo model',
      () {
    final photo = _photo('a', 'yolo26');
    final row = photo.toAdminTableRow(1).copyWith();
    expect(row.modelName, 'yolo26');
    expect(StaffSubmissionRows.photo(row).sourceCapture!.modelName, 'yolo26');
  });

  for (final role in ['Diver', 'Admin', 'Expert']) {
    testWidgets('$role details respect role and selected photo attribution',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final photos = [_photo('a', 'yolo26'), _photo('b', '')];
      final auth = _RoleAuth(role == 'Expert');
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              home: UserSubmissionDetailsPage(
            initialGroup: SubmissionGroup.fromRecords(photos).single,
            recordsStream: Stream.value(photos),
            includePendingPhotos: false,
            useReadOnlyLayout: role != 'Diver',
          ))));
      await tester.pumpAndSettle();
      expect(find.text('Detection model'),
          role == 'Expert' ? findsNothing : findsOneWidget);
      expect(find.text('YOLO26'),
          role == 'Expert' ? findsNothing : findsOneWidget);
      tester
          .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>))
          .onChanged!('b');
      await tester.pumpAndSettle();
      expect(find.text('YOLO26'), findsNothing);
      expect(find.text('Model not recorded'),
          role == 'Expert' ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
