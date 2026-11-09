class AdminPreferences {
  const AdminPreferences({
    required this.uid,
    this.emailNotifications = true,
    this.highRiskAlerts = true,
    this.systemUpdates = true,
    this.weeklyReports = false,
    this.twoFactorAuth = false,
    this.loginAlerts = true,
    this.sessionTimeout = true,
  });

  final String uid;
  final bool emailNotifications;
  final bool highRiskAlerts;
  final bool systemUpdates;
  final bool weeklyReports;
  final bool twoFactorAuth;
  final bool loginAlerts;
  final bool sessionTimeout;

  static const fields = <String>{
    'uid',
    'email_notifications',
    'high_risk_alerts',
    'system_updates',
    'weekly_reports',
    'two_factor_auth',
    'login_alerts',
    'session_timeout',
  };

  factory AdminPreferences.defaults(String uid) => AdminPreferences(uid: uid);

  factory AdminPreferences.fromMap(
    String uid,
    Map<String, dynamic> data,
  ) {
    bool value(String key, bool fallback) {
      final candidate = data[key];
      return candidate is bool ? candidate : fallback;
    }

    return AdminPreferences(
      uid: uid,
      emailNotifications: value('email_notifications', true),
      highRiskAlerts: value('high_risk_alerts', true),
      systemUpdates: value('system_updates', true),
      weeklyReports: value('weekly_reports', false),
      twoFactorAuth: value('two_factor_auth', false),
      loginAlerts: value('login_alerts', true),
      sessionTimeout: value('session_timeout', true),
    );
  }

  factory AdminPreferences.fromRestDocument(
    String uid,
    Map<String, dynamic> document,
  ) {
    final encoded = document['fields'];
    if (encoded is! Map<String, dynamic>) {
      return AdminPreferences.defaults(uid);
    }
    final decoded = <String, dynamic>{};
    for (final entry in encoded.entries) {
      final field = entry.value;
      if (field is! Map<String, dynamic>) continue;
      if (field['booleanValue'] is bool) {
        decoded[entry.key] = field['booleanValue'];
      } else if (field['stringValue'] is String) {
        decoded[entry.key] = field['stringValue'];
      }
    }
    return AdminPreferences.fromMap(uid, decoded);
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'uid': uid,
        'email_notifications': emailNotifications,
        'high_risk_alerts': highRiskAlerts,
        'system_updates': systemUpdates,
        'weekly_reports': weeklyReports,
        'two_factor_auth': twoFactorAuth,
        'login_alerts': loginAlerts,
        'session_timeout': sessionTimeout,
      };
}
