import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction so tests can supply a fixed device secret.
abstract interface class DeviceSecretSource {
  Future<String> readOrCreate();
}

/// A random secret that identifies this app installation.
///
/// It is stored in platform-protected storage (Android keystore, Windows
/// Credential Manager) and kept across sign-outs, so a trusted device stays
/// trusted. Reinstalling the app or clearing its data creates a new secret,
/// which is treated as a new device. Only a SHA-256 hash ever reaches the
/// server.
final class DeviceIdentity implements DeviceSecretSource {
  const DeviceIdentity({FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;

  static const _key = 'cots_monitor.trusted_device_secret.v1';
  static final RegExp _validSecret = RegExp(r'^[A-Za-z0-9_-]{43,128}$');

  final FlutterSecureStorage _storage;

  @override
  Future<String> readOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && _validSecret.hasMatch(existing)) return existing;
    final secret = generateSecret();
    await _storage.write(key: _key, value: secret);
    return secret;
  }

  /// 32 random bytes, base64url without padding (43 characters).
  static String generateSecret([Random? random]) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(32, (_) => source.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static bool isValidSecret(String value) => _validSecret.hasMatch(value);
}
