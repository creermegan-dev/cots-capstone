import 'dart:io';

/// Resolves how to load a submitted scan image (cloud URL vs local file).
abstract final class ScanRecordImage {
  static String? networkUrl({required String imageUrl, required String imagePath}) {
    final url = imageUrl.trim();
    if (url.startsWith('http')) return url;
    final path = imagePath.trim();
    if (path.startsWith('http')) return path;
    return null;
  }

  static bool hasReadableLocalFile(String imagePath) {
    final path = imagePath.trim();
    if (path.isEmpty || path.startsWith('http')) return false;
    return File(path).existsSync();
  }

  static String contentTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  /// Safe object name for Firebase Storage (no path separators or odd characters).
  static String safeStorageFilename(String raw) {
    final trimmed = raw.trim();
    final base = trimmed.isEmpty
        ? 'gopro_image.jpg'
        : trimmed.split(RegExp(r'[\\/]')).last;
    final sanitized = base.replaceAll(RegExp(r'[^\w.\-]'), '_');
    if (sanitized.isEmpty) return 'gopro_image.jpg';
    if (!sanitized.contains('.')) return '$sanitized.jpg';
    return sanitized;
  }

  /// Firebase Storage object path, e.g. `scan_records/{uid}/{scanId}/photo.jpg`.
  static String scanObjectPath({
    required String uid,
    required String scanId,
    required String filename,
  }) {
    final safeName = safeStorageFilename(filename);
    return 'scan_records/$uid/$scanId/$safeName';
  }

  /// Best available Storage object path for reloading an image.
  static String? resolveStorageObjectPath({
    String? storageObjectPath,
    String? imageUrl,
  }) {
    final explicit = storageObjectPath?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return storagePathFromDownloadUrl(imageUrl);
  }

  /// Parses `scan_records/...` from a Firebase Storage download URL.
  static String? storagePathFromDownloadUrl(String? url) {
    final raw = url?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    final oIndex = segments.indexOf('o');
    if (oIndex >= 0 && oIndex + 1 < segments.length) {
      return Uri.decodeComponent(segments[oIndex + 1]);
    }

    final name = uri.queryParameters['name'];
    if (name != null && name.isNotEmpty) return name;
    return null;
  }
}
