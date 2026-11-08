import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_supabase_local_storage.dart';
import 'supabase_auth_callback.dart';

/// Compile-time Supabase client configuration.
///
/// Only the public project URL and publishable key belong in the Flutter build.
/// Never pass a service-role key through `--dart-define`.
abstract final class SupabaseConfig {
  /// Explicit rollback: --dart-define=USE_FIREBASE=true.
  static const bool useFirebase = bool.fromEnvironment('USE_FIREBASE');

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kgfehorbjzhooxnnkfac.supabase.co',
  );
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_cnrQpU8FTeBHd_wRwL7EVg_nmphLoN0',
    ),
  );

  static bool get isConfigured =>
      !useFirebase && url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;

  static Future<bool> initializeIfConfigured() async {
    if (!isConfigured) return false;
    await Supabase.initialize(
      url: url.trim(),
      publishableKey: publishableKey.trim(),
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        persistSession: true,
        localStorage: SecureSupabaseLocalStorage(),
        detectSessionInUri: true,
        detectSessionInUriPredicate: SupabaseAuthCallback.capture,
      ),
    );
    return true;
  }
}
