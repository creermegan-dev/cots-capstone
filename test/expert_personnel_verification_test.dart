import 'dart:async';

import 'package:cots_monitor/features/expert/screens/expert_users_screen.dart';
import 'package:cots_monitor/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserModel _person({bool verified = false, bool active = true, String? role}) =>
    UserModel.fromSupabaseProfile({
      'id': 'person-1',
      'full_name': 'Field Person',
      'active': active,
      'field_verified': verified,
    }, email: 'hidden@example.invalid', privilegedRole: role);

void main() {
  testWidgets('confirmed verification saves once then refreshes real status',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var verified = false;
    var saves = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertUsersScreen(
      loadUsers: () async => [_person(verified: verified)],
      setVerification: (user, decision) async {
        expect(user.uid, 'person-1');
        expect(decision, isTrue);
        saves++;
        await pending.future;
        verified = decision;
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Field Person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verify personnel'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    await tester.tap(find.text('Verify'));
    await tester.pump();
    expect(saves, 1);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final refresh = tester.widget<IconButton>(find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == 'Refresh users'));
    expect(refresh.onPressed, isNull);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Field Person'), findsNothing);
    await tester.tap(find.text('Verified Personnel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Approved field personnel'), findsOneWidget);
    expect(find.text('Personnel verified.'), findsOneWidget);
    expect(saves, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmed revocation refreshes status without disabling account',
      (tester) async {
    var verified = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertUsersScreen(
      loadUsers: () async => [_person(verified: verified)],
      setVerification: (user, decision) async {
        expect(user.isActive, isTrue);
        expect(decision, isFalse);
        verified = decision;
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verified Personnel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Field Person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke verification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke verification'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(verified, isFalse);
    expect(find.text('Field Person'), findsNothing);
    await tester.tap(find.text('Pending Verification'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Awaiting field approval'), findsOneWidget);
    expect(find.text('Personnel verification revoked.'), findsOneWidget);
  });

  testWidgets('cancelling revocation preserves the existing verification',
      (tester) async {
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertUsersScreen(
      loadUsers: () async => [_person(verified: true)],
      setVerification: (user, decision) async {
        saves++;
      },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verified Personnel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Field Person'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke verification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saves, 0);
    expect(find.textContaining('Approved field personnel'), findsOneWidget);
  });

  testWidgets('failed save preserves status and allows retry', (tester) async {
    var attempts = 0;
    var verified = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertUsersScreen(
      loadUsers: () async => [_person(verified: verified)],
      setVerification: (_, decision) async {
        if (attempts++ == 0) throw StateError('unavailable');
        verified = decision;
      },
    ))));
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.tap(find.text('Field Person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify personnel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      if (attempt == 0) {
        expect(find.textContaining('Could not update personnel verification.'),
            findsOneWidget);
        expect(find.textContaining('Awaiting field approval'), findsOneWidget);
      }
    }
    expect(attempts, 2);
    expect(verified, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final person in [
    _person(role: 'administrator'),
    _person(role: 'expert'),
    _person(active: false)
  ]) {
    testWidgets(
        'no personnel decisions for role ${person.accountRole}, active ${person.isActive}',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ExpertUsersScreen(loadUsers: () async => [person]))));
      await tester.pumpAndSettle();
      if (!person.isAdmin && !person.isExpert) {
        await tester.tap(find.text('Field Person'));
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Field Person'), findsNothing);
        await tester.tap(find.text('Verified Personnel'));
        await tester.pumpAndSettle();
        expect(find.text('Field Person'), findsNothing);
      }
      expect(find.text('Verify personnel'), findsNothing);
      expect(find.text('Revoke verification'), findsNothing);
      expect(find.text('Disable'), findsNothing);
      expect(find.text('Enable'), findsNothing);
    });
  }
}
