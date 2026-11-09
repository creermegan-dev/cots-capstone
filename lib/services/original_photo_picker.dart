import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Android photo picker that returns the original files, so the GPS location
/// saved inside each photo is kept.
///
/// The standard picker on Android hands apps a copy with the location removed,
/// which made the app fall back to the phone's current position. Other
/// platforms keep using `image_picker`, which already preserves the location.
abstract final class OriginalPhotoPicker {
  static const MethodChannel _channel =
      MethodChannel('cots_monitor/original_photos');

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// Whether the app may read the GPS saved in photos (Android 10+ needs the
  /// "media location" permission, granted with full photo access).
  static Future<bool> photoLocationAllowed() async {
    if (!isSupported) return true;
    try {
      return await _channel.invokeMethod<bool>('photoLocationAllowed') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<List<XFile>> pickImages({required int limit}) async {
    final picked = await _channel.invokeListMethod<dynamic>(
          'pickImages',
          <String, dynamic>{'limit': limit},
        ) ??
        const <dynamic>[];
    return [
      for (final item in picked)
        if (item is Map && item['path'] is String)
          XFile(
            item['path'] as String,
            name: item['name'] is String ? item['name'] as String : null,
          ),
    ];
  }
}
