import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// True on Windows desktop — auth uses REST instead of native Firebase plugins.
bool get deferFirebaseUntilFirstUse =>
    !kIsWeb && Platform.isWindows;

/// Ensures Firebase is initialized (idempotent).
Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
