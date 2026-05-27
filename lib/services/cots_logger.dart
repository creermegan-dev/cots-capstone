import 'package:flutter/foundation.dart';

/// ANSI-colored telemetry and performance logger.
/// 
/// Provides high-visibility terminal diagnostics for file size, 
/// in-memory footprints, isolate decoding duration, and inference benchmarks.
abstract final class CotsLogger {
  static const String _reset = '\x1B[0m';
  static const String _cyan = '\x1B[36m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _magenta = '\x1B[35m';

  static void info(String message) {
    debugPrint('$_cyan[COTS INFO]$_reset $message');
  }

  static void success(String message) {
    debugPrint('$_green[COTS SUCCESS]$_reset $message');
  }

  static void warn(String message) {
    debugPrint('$_yellow[COTS WARNING]$_reset $message');
  }

  static void perf(String message) {
    debugPrint('$_magenta[COTS PERF]$_reset $message');
  }
}
