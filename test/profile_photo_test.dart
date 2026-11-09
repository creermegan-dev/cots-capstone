import 'dart:typed_data';

import 'package:cots_monitor/models/user_model.dart';
import 'package:cots_monitor/services/profile_photo_service.dart';
import 'package:cots_monitor/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('a big picture is shrunk to a small JPEG', () {
    final big = img.Image(width: 3000, height: 2000);
    final png = Uint8List.fromList(img.encodePng(big));
    final jpg = ProfilePhotoService.shrinkToJpeg(png);
    final back = img.decodeJpg(jpg)!;
    expect(back.width, 512);
    expect(back.height, lessThan(512));
    expect(jpg.length, lessThanOrEqualTo(ProfilePhotoService.maxBytes));
  });

  test('a non-picture file is refused', () {
    expect(
      () => ProfilePhotoService.shrinkToJpeg(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  test('new photo paths stay in the person folder', () {
    const uid = '02900185-e835-41c4-a34f-37cfb872a631';
    final a = ProfilePhotoService.newPath(uid);
    final b = ProfilePhotoService.newPath(uid);
    final pattern = RegExp(r'^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$');
    expect(pattern.hasMatch(a), isTrue);
    expect(a.startsWith('$uid/'), isTrue);
    expect(a, isNot(b));
  });

  test('profile photo path is read from the Supabase profile', () {
    final user = UserModel.fromSupabaseProfile(
      {'id': 'u1', 'avatar_path': 'u1/p.jpg'},
      email: 'a@example.invalid',
    );
    expect(user.profileImage, 'u1/p.jpg');
    final none =
        UserModel.fromSupabaseProfile({'id': 'u1'}, email: 'a@example.invalid');
    expect(none.profileImage, '');
  });

  testWidgets('avatar shows the person icon without a photo', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ProfileAvatar(path: '')),
    ));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('avatar falls back to the icon when the photo cannot load',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProfileAvatar(
          path: 'u1/p.jpg',
          loadUrl: (_) async => throw Exception('offline'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
