import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Shared display identity only; never used as a photo ID in backend writes.
abstract final class SubmissionIdentity {
  static String fromKey(String key) =>
      'SUB-${sha256.convert(utf8.encode(key)).toString().substring(0, 10).toUpperCase()}';
  static String forBatch(String owner, String encounter, String site) =>
      owner.isEmpty || encounter.isEmpty || site.isEmpty
          ? ''
          : fromKey(jsonEncode(['batch-site', owner, encounter, site]));
}
