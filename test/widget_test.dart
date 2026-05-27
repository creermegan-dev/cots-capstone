import 'package:cots_monitor/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserModel maps Firestore-shaped data', () {
    final map = <String, dynamic>{
      'uid': 'abc123',
      'fullName': 'Test User',
      'email': 'test@example.com',
      'phoneNumber': '+123456789',
      'role': 'Field Monitor',
      'accountRole': 'user',
      'organization': 'Test Org',
      'profileImage': '',
      'isActive': true,
    };

    final model = UserModel.fromMap(map, uid: 'abc123');
    expect(model.uid, 'abc123');
    expect(model.role, 'Field Monitor');
    expect(model.accountRole, 'user');

    final out = model.toMap();
    expect(out['email'], 'test@example.com');
    expect(out['accountRole'], 'user');
  });
}
