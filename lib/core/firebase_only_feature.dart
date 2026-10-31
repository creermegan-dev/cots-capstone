import 'supabase_config.dart';

/// Raised by features that still use Firebase when the app runs with the
/// Supabase backend. Firebase is not started in that build, so these features
/// report this instead of crashing the screen while it is drawn.
class FirebaseOnlyFeatureUnavailable implements Exception {
  const FirebaseOnlyFeatureUnavailable(this.feature);

  final String feature;

  @override
  String toString() => '$feature is not available in this version yet.';
}

/// True when the running build uses Supabase (Firebase is not started).
bool get firebaseFeaturesUnavailable => SupabaseConfig.isConfigured;

/// A stream that reports [FirebaseOnlyFeatureUnavailable] for [feature].
Stream<T> firebaseOnlyFeatureStream<T>(String feature) =>
    Stream<T>.error(FirebaseOnlyFeatureUnavailable(feature));
