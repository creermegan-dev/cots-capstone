import 'package:cots_monitor/features/expert/screens/expert_reassignments_screen.dart';
import 'package:cots_monitor/models/follow_up_reassignment.dart';
import 'package:cots_monitor/models/site_partner.dart';
import 'package:cots_monitor/services/site_partner_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Api extends SitePartnerApi {
  final calls = <bool>[];
  bool decided = false;
  @override
  Future<List<SiteTeam>> teams() async => [
        SiteTeam(
            areaCode: 'S4',
            areaName: 'Site 4 Balet',
            mainDiverUid: 'main',
            mainDiverName: 'Main Diver',
            partnerName: decided ? 'Partner Diver' : null)
      ];
  @override
  Future<List<SitePartnerRequest>> requests() async => [
        SitePartnerRequest(
            id: 'partner-1',
            areaCode: 'S4',
            areaName: 'Site 4 Balet',
            candidateUid: 'partner',
            candidateName: 'Partner Diver',
            source: 'invited',
            status: decided ? 'approved' : 'waiting_expert',
            mainDiverName: 'Main Diver',
            canDecide: !decided)
      ];
  @override
  Future<String> decide(String id, {required bool approve}) async {
    expect(id, 'partner-1');
    calls.add(approve);
    decided = true;
    return 'approved';
  }
}

void main() {
  for (final config in [(360.0, 1.0), (1400.0, 1.0), (360.0, 2.0)]) {
    testWidgets('coverage tabs preserve actions at $config', (tester) async {
      tester.view.physicalSize = Size(config.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _Api();
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(config.$1, 1000),
                  textScaler: TextScaler.linear(config.$2)),
              child: Scaffold(
                  body: ExpertReassignmentsScreen(
                partnerApi: api,
                requestsStream: Stream.value(const <FollowUpReassignment>[]),
                handoversBuilder: (_) =>
                    const Text('Existing handover actions'),
              )))));
      await tester.pumpAndSettle();
      expect(find.text('Main Diver'), findsOneWidget);
      await tester.ensureVisible(find.text('Partner requests'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Partner requests'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Approve partner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve partner'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      await tester.tap(find.text('Approve partner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(api.calls, [true]);
      expect(find.text('Approve partner'), findsNothing);
      await tester.ensureVisible(find.text('Temporary coverage'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Temporary coverage'));
      await tester.pumpAndSettle();
      expect(find.text('No coverage requests need attention.'), findsOneWidget);
      await tester.ensureVisible(find.text('Handovers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Handovers'));
      await tester.pumpAndSettle();
      expect(find.text('Existing handover actions'), findsOneWidget);
      await tester.ensureVisible(find.text('Overview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overview'));
      await tester.pumpAndSettle();
      expect(find.text('Partner Diver'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
