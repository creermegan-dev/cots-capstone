import 'package:cots_monitor/services/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FCM token document IDs are stable and hide the raw token', () {
    final first = PushNotificationService.tokenDocumentId('device-token-123');
    final second = PushNotificationService.tokenDocumentId('device-token-123');

    expect(first, second);
    expect(first, hasLength(64));
    expect(first, isNot(contains('device-token-123')));
  });
}
