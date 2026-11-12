import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Keeps Windows exports out of file_saver's native save handler, which can
/// overflow the platform thread's stack. Other platforms keep their save flow.
class ReportFileSaver {
  static Future<String?> save({
    required String name,
    required Uint8List bytes,
    required String fileExtension,
    required MimeType mimeType,
  }) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final location = await FileSelectorPlatform.instance.getSaveLocation(
        acceptedTypeGroups: [
          XTypeGroup(
              label: fileExtension.toUpperCase(), extensions: [fileExtension]),
        ],
        options: SaveDialogOptions(suggestedName: '$name.$fileExtension'),
      );
      if (location == null) return null;
      // The Windows dialog can return a path without the extension; add it.
      final ext = '.${fileExtension.toLowerCase()}';
      final path = location.path.toLowerCase().endsWith(ext)
          ? location.path
          : '${location.path}$ext';
      await XFile.fromData(bytes).saveTo(path);
      return path;
    }
    return FileSaver.instance.saveAs(
      name: name,
      bytes: bytes,
      fileExtension: fileExtension,
      mimeType: mimeType,
    );
  }
}
