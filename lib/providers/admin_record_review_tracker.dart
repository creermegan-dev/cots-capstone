import 'package:flutter/foundation.dart';

import '../features/admin/models/admin_record_table_row.dart';

/// Tracks which submissions the admin has opened this session (in-memory).
class AdminRecordReviewTracker extends ChangeNotifier {
  final Set<String> _openedKeys = {};

  static String recordKey(AdminRecordTableRow row) =>
      row.documentId.isNotEmpty ? row.documentId : row.recordId;

  bool isOpened(AdminRecordTableRow row) => _openedKeys.contains(recordKey(row));

  void markOpened(AdminRecordTableRow row) {
    final key = recordKey(row);
    if (_openedKeys.add(key)) notifyListeners();
  }

  /// Submissions awaiting admin review that have not been opened yet.
  int unopenedNeedsReviewCount(List<AdminRecordTableRow> rows) {
    return rows
        .where(
          (r) => r.displayStatus == 'Needs Review' && !isOpened(r),
        )
        .length;
  }
}
