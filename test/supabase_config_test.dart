import 'package:cots_monitor/core/supabase_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain Flutter builds select Supabase unless rollback is explicit', () {
    const rollback = bool.fromEnvironment('USE_FIREBASE');
    expect(SupabaseConfig.useFirebase, rollback);
    expect(SupabaseConfig.isConfigured, !rollback);
    expect(Uri.parse(SupabaseConfig.url).scheme, 'https');
    expect(SupabaseConfig.publishableKey, startsWith('sb_publishable_'));
  });
}
