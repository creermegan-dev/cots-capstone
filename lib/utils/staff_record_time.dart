/// Display-only conversion for Admin and Expert record timestamps.
abstract final class StaffRecordTime {
  /// Asia/Manila is UTC+08:00 and does not observe daylight saving time.
  /// The UTC container holds the Manila wall clock for formatting only.
  static DateTime inManila(DateTime value) =>
      value.toUtc().add(const Duration(hours: 8));
}
