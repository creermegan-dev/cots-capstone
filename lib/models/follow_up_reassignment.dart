/// A month is a Philippine calendar month, independent of the device timezone.
abstract final class MonitoringMonth {
  static DateTime local(DateTime instant) =>
      instant.toUtc().add(const Duration(hours: 8));
  static DateTime calendar(DateTime instant) {
    final ph = local(instant);
    return DateTime(ph.year, ph.month, ph.day, ph.hour, ph.minute, ph.second);
  }

  static String key(DateTime instant) {
    final date = local(instant);
    return '${date.year}_${date.month}';
  }

  static String id(String areaId, DateTime instant) =>
      '${areaId}_${key(instant)}';
  static String surveyKey(DateTime date) => '${date.year}_${date.month}';
}

class FollowUpReassignment {
  const FollowUpReassignment(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  String get areaId => data['area_id'] as String;
  String get primaryUid => data['primary_uid'] as String;
  String get responsibleUid => data['responsible_uid'] as String;
  String get replacementUid => data['replacement_uid'] as String;
  String get status => data['status'] as String;
  int get revision => data['revision'] as int;
  DateTime get month => DateTime(data['year'] as int, data['month'] as int);
  bool isCurrent(DateTime now) =>
      MonitoringMonth.key(now) == '${data['year']}_${data['month']}';
  String get statusLabel => switch (status) {
        'requested' => 'Reassignment Requested — Awaiting Expert Review',
        'awaiting_acceptance' => 'Awaiting Acceptance',
        'accepted' => 'Accepted',
        'replacement_needed' => 'Replacement Needed',
        'cancelled' => 'Cancelled',
        _ => status,
      };
}
