import 'package:cots_monitor/core/remembered_login.dart';
import 'package:cots_monitor/core/secure_supabase_local_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _sessionKey = 'cots_monitor.supabase.session.v1';
const _deviceKey = 'cots_monitor.trusted_device_secret.v1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = SecureSupabaseLocalStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      _sessionKey: '{"saved":"session"}',
      _deviceKey: 'A' * 43,
    });
  });

  test('remember me is on by default and keeps the session', () async {
    expect(await SecureSupabaseLocalStorage.rememberSession(), isTrue);

    await storage.initialize();

    expect(await storage.hasAccessToken(), isTrue);
  });

  test('unticked remember me signs out on the next app start', () async {
    await SecureSupabaseLocalStorage.setRememberSession(false);
    expect(await SecureSupabaseLocalStorage.rememberSession(), isFalse);

    await storage.initialize();

    expect(await storage.hasAccessToken(), isFalse);
    // The trusted-device secret survives, so no new email code is needed.
    expect(
      await const FlutterSecureStorage().read(key: _deviceKey),
      'A' * 43,
    );
  });

  test('ticking it again keeps future sessions', () async {
    await SecureSupabaseLocalStorage.setRememberSession(false);
    await SecureSupabaseLocalStorage.setRememberSession(true);

    await storage.initialize();

    expect(await SecureSupabaseLocalStorage.rememberSession(), isTrue);
    expect(await storage.hasAccessToken(), isTrue);
  });

  test('remember me saves the email (never the password) for next time',
      () async {
    expect(await RememberedLogin.email(), '');

    await RememberedLogin.save(email: '  diver@example.com ', remember: true);

    expect(await RememberedLogin.email(), 'diver@example.com');
  });

  test('unticking remember me forgets the saved email', () async {
    await RememberedLogin.save(email: 'diver@example.com', remember: true);

    await RememberedLogin.save(email: 'diver@example.com', remember: false);

    expect(await RememberedLogin.email(), '');
  });

  test('the remembered email is kept after signing out', () async {
    await RememberedLogin.save(email: 'diver@example.com', remember: true);
    await storage.removePersistedSession();

    expect(await RememberedLogin.email(), 'diver@example.com');
  });
}
