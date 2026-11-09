import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cots_monitor/features/expert/screens/expert_users_screen.dart';
import 'package:cots_monitor/models/user_model.dart';

UserModel person(String name, {String? role, bool approved = false}) =>
    UserModel.fromSupabaseProfile({
      'id': name,
      'full_name': name,
      'organization': 'Reef team',
      'active': true,
      'field_verified': approved,
    }, email: 'private@example.invalid', privilegedRole: role);

void main() {
  testWidgets('search actions preserve directory filters without reloading',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ExpertUsersScreen(loadUsers: () async {
          loads++;
          return [
            person('Approved Diver', approved: true),
            person('Pending Diver'),
            person('Marine Expert', role: 'expert'),
          ];
        }),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verified Personnel'));
    final field = find.byType(TextField);
    await tester.enterText(field, ' DiVeR ');
    await tester.tap(find.byTooltip('Search users'));
    await tester.pumpAndSettle();
    expect(find.text('Approved Diver'), findsOneWidget);
    expect(find.text('Pending Diver'), findsNothing);
    expect(find.text('Marine Expert'), findsNothing);
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isFalse);

    await tester.tap(find.text('Pending Verification'));
    await tester.enterText(field, 'pending');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('Pending Diver'), findsOneWidget);
    expect(find.text('Marine Expert'), findsNothing);
    expect(find.text('Approved Diver'), findsNothing);
    expect(loads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'personnel tabs separate saved statuses and exclude staff accounts',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ExpertUsersScreen(
      loadUsers: () async => [
        person('Approved Diver', approved: true),
        person('Pending Diver'),
        person('Marine Expert', role: 'expert')
      ],
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Pending Diver'), findsOneWidget);
    expect(find.text('Approved Diver'), findsNothing);
    expect(find.text('Marine Expert'), findsNothing);
    await tester.tap(find.text('Verified Personnel'));
    await tester.pumpAndSettle();
    expect(find.text('Approved Diver'), findsOneWidget);
    expect(find.text('Pending Diver'), findsNothing);
    expect(find.text('Marine Expert'), findsNothing);
    await tester.tap(find.text('Approved Diver'));
    await tester.pumpAndSettle();
    expect(find.text('Role: Diver'), findsOneWidget);
    expect(find.textContaining('private@example.invalid'), findsNothing);
    expect(find.text('Disable'), findsNothing);
    expect(find.text('Approve'), findsNothing);
  });

  testWidgets('search and retry recover from directory failures',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: ExpertUsersScreen(loadUsers: () async {
      if (attempts++ == 0) throw StateError('unavailable');
      return [person('Diver One'), person('Diver Two')];
    }))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'two');
    await tester.pumpAndSettle();
    expect(find.text('Diver Two'), findsOneWidget);
    expect(find.text('Diver One'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
