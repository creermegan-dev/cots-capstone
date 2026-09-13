import 'package:flutter/material.dart';

import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import 'admin_shell_screen.dart';

/// Settings workspace: 2×2 card grid, top bar, and footer. Sidebar is provided by [AdminShellScreen].
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _fullNameCtrl = TextEditingController(text: 'Admin User');
  final _emailCtrl = TextEditingController(text: 'admin@cotsmonitoring.com');
  final _roleCtrl = TextEditingController(text: 'Administrator');

  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  String _language = 'English';
  bool _useDarkTheme = false;
  String _dateFormat = 'May 18, 2026 (MM DD, YYYY)';
  String _timeFormat = '12-Hour (AM/PM)';

  bool _emailNotifications = true;
  bool _highRiskAlerts = true;
  bool _systemUpdates = true;
  bool _weeklyReports = false;
  bool _twoFactorAuth = false;
  bool _loginAlerts = true;
  bool _sessionTimeout = true;

  final _highThresholdCtrl = TextEditingController(text: '15');
  final _moderateThresholdCtrl = TextEditingController(text: '5');
  final _lowThresholdCtrl = TextEditingController(text: '1');

  static const _languages = ['English', 'Filipino', 'Cebuano'];
  static const _dateFormats = [
    'May 18, 2026 (MM DD, YYYY)',
    '18/05/2026 (DD/MM/YYYY)',
    '2026-05-18 (YYYY-MM-DD)',
  ];
  static const _timeFormats = ['12-Hour (AM/PM)', '24-Hour'];

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _roleCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _highThresholdCtrl.dispose();
    _moderateThresholdCtrl.dispose();
    _lowThresholdCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }

  void _onSettingsRefresh() {
    _snack('Settings refreshed.');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = AdminBreakpoints.pagePadding(c.maxWidth);
        return SingleChildScrollView(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              const SizedBox(height: 20),
              _titleBlock(),
              const SizedBox(height: 22),
              _twoByTwoGrid(c.maxWidth),
              const SizedBox(height: 28),
              _footer(),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        const Spacer(),
        OutlinedButton.icon(
          onPressed: _onSettingsRefresh,
          icon: AdminDateTimeTokens.refreshIcon,
          label: const Text('Refresh', style: AdminDateTimeTokens.refreshChipTextStyle),
          style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
        ),
        const SizedBox(width: 12),
        Badge(
          label: const Text('3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AdminColors.headerTitle,
              side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminShellScreen(initialIndex: 5),
                ),
              );
            },
            icon: const Icon(Icons.notifications_outlined, size: 22),
            tooltip: 'Notifications',
          ),
        ),
        const SizedBox(width: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'May 18, 2026',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
              ),
              SizedBox(height: 2),
              Text(
                '09:30 AM',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AdminColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _titleBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AdminColors.headerTitle,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage system preferences and configuration.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AdminColors.muted.withValues(alpha: 0.95),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _twoByTwoGrid(double maxWidth) {
    final twoCol = maxWidth >= 900;
    const gap = 18.0;

    Widget pair(Widget a, Widget b) {
      if (!twoCol) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            a,
            SizedBox(height: gap),
            b,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          SizedBox(width: gap),
          Expanded(child: b),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair(_profileCard(), _changePasswordCard()),
        SizedBox(height: gap),
        pair(_notificationsCard(), _securitySettingsCard()),
      ],
    );
  }

  Widget _profileCard() {
    return _settingsCard(
      icon: Icons.person_rounded,
      iconBg: AdminColors.statBlue.withValues(alpha: 0.14),
      iconColor: AdminColors.statBlue,
      title: 'Profile Information',
      subtitle: 'Update your profile information.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AdminColors.statBlue.withValues(alpha: 0.12),
                  child: const Icon(Icons.person_rounded, size: 52, color: AdminColors.statBlue),
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Material(
                    color: AdminColors.statBlue,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _snack('Profile photo upload (demo).'),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _fieldLabel('Full Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _fullNameCtrl,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: _inputDeco(),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Email Address'),
          const SizedBox(height: 8),
          TextField(
            controller: _emailCtrl,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDeco(),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Role'),
          const SizedBox(height: 8),
          TextField(
            enabled: false,
            controller: _roleCtrl,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AdminColors.muted.withValues(alpha: 0.85),
            ),
            decoration: _inputDeco().copyWith(
              filled: true,
              fillColor: const Color(0xFFECEFF3),
            ),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(onPressed: () => _snack('Profile settings saved (demo).')),
          ),
        ],
      ),
    );
  }

  Widget _changePasswordCard() {
    return _settingsCard(
      icon: Icons.lock_outline_rounded,
      iconBg: AdminColors.statPurple.withValues(alpha: 0.14),
      iconColor: AdminColors.statPurple,
      title: 'Change Password',
      subtitle: 'Update your account password.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Current Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _currentPasswordCtrl,
            obscureText: true,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: _inputDeco().copyWith(hintText: 'Enter current password'),
          ),
          const SizedBox(height: 16),
          _fieldLabel('New Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _newPasswordCtrl,
            obscureText: true,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: _inputDeco().copyWith(hintText: 'Enter new password'),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Confirm New Password'),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmPasswordCtrl,
            obscureText: true,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            decoration: _inputDeco().copyWith(hintText: 'Re-enter new password'),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(onPressed: () => _snack('Password updated (demo).')),
          ),
        ],
      ),
    );
  }

  Widget _securitySettingsCard() {
    return _settingsCard(
      icon: Icons.security_rounded,
      iconBg: AdminColors.statYellow.withValues(alpha: 0.18),
      iconColor: const Color(0xFFE65100),
      title: 'Security Settings',
      subtitle: 'Manage account security preferences.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toggleTile(
            title: 'Two-Factor Authentication',
            subtitle: 'Require a second step when signing in',
            value: _twoFactorAuth,
            onChanged: (v) => setState(() => _twoFactorAuth = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'Login Alerts',
            subtitle: 'Notify me of new device sign-ins',
            value: _loginAlerts,
            onChanged: (v) => setState(() => _loginAlerts = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'Auto Session Timeout',
            subtitle: 'Sign out after inactivity',
            value: _sessionTimeout,
            onChanged: (v) => setState(() => _sessionTimeout = v),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(onPressed: () => _snack('Security settings saved (demo).')),
          ),
        ],
      ),
    );
  }

  Widget _systemPreferencesCard() {
    return _settingsCard(
      icon: Icons.tune_rounded,
      iconBg: AdminColors.statPurple.withValues(alpha: 0.14),
      iconColor: AdminColors.statPurple,
      title: 'System Preferences',
      subtitle: 'Customize system behavior.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Language'),
          const SizedBox(height: 8),
          _dropdown<String>(
            value: _language,
            items: _languages,
            onChanged: (v) => setState(() => _language = v ?? _language),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Theme'),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Light'), icon: Icon(Icons.light_mode_outlined, size: 18)),
              ButtonSegment(value: true, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined, size: 18)),
            ],
            selected: {_useDarkTheme},
            onSelectionChanged: (s) => setState(() => _useDarkTheme = s.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Date Format'),
          const SizedBox(height: 8),
          _dropdown<String>(
            value: _dateFormat,
            items: _dateFormats,
            onChanged: (v) => setState(() => _dateFormat = v ?? _dateFormat),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Time Format'),
          const SizedBox(height: 8),
          _dropdown<String>(
            value: _timeFormat,
            items: _timeFormats,
            onChanged: (v) => setState(() => _timeFormat = v ?? _timeFormat),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(onPressed: () => _snack('System preferences saved (demo).')),
          ),
        ],
      ),
    );
  }

  Widget _notificationsCard() {
    return _settingsCard(
      icon: Icons.notifications_active_outlined,
      iconBg: AdminColors.statGreen.withValues(alpha: 0.14),
      iconColor: AdminColors.statGreen,
      title: 'Notification Settings',
      subtitle: 'Manage your notification settings.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toggleTile(
            title: 'Email Notifications',
            subtitle: 'Receive email alerts and updates',
            value: _emailNotifications,
            onChanged: (v) => setState(() => _emailNotifications = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'High Risk Alerts',
            subtitle: 'Get notified for high risk zones',
            value: _highRiskAlerts,
            onChanged: (v) => setState(() => _highRiskAlerts = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'System Updates',
            subtitle: 'Receive system update notifications',
            value: _systemUpdates,
            onChanged: (v) => setState(() => _systemUpdates = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'Weekly Reports',
            subtitle: 'Receive weekly summary reports',
            value: _weeklyReports,
            onChanged: (v) => setState(() => _weeklyReports = v),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(onPressed: () => _snack('Notification preferences saved (demo).')),
          ),
        ],
      ),
    );
  }

  Widget _alertThresholdsCard() {
    return _settingsCard(
      icon: Icons.warning_amber_rounded,
      iconBg: AdminColors.statYellow.withValues(alpha: 0.18),
      iconColor: const Color(0xFFE65100),
      title: 'Alert Thresholds',
      subtitle: 'Configure thresholds for risk alerts.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _thresholdRow(
            shieldColor: AdminColors.statRed,
            title: 'High Risk Threshold (COTS/ha)',
            subtitle: 'Alert when density exceeds this value',
            controller: _highThresholdCtrl,
          ),
          const SizedBox(height: 16),
          _thresholdRow(
            shieldColor: AdminColors.statYellow,
            title: 'Moderate Risk Threshold (COTS/ha)',
            subtitle: 'Alert when density exceeds this value',
            controller: _moderateThresholdCtrl,
          ),
          const SizedBox(height: 16),
          _thresholdRow(
            shieldColor: AdminColors.statGreen,
            title: 'Low Risk Threshold (COTS/ha)',
            subtitle: 'Alert when density exceeds this value',
            controller: _lowThresholdCtrl,
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(onPressed: () => _snack('Alert thresholds saved (demo).')),
          ),
        ],
      ),
    );
  }

  Widget _thresholdRow({
    required Color shieldColor,
    required String title,
    required String subtitle,
    required TextEditingController controller,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: shieldColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.shield_outlined, color: shieldColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AdminColors.headerTitle)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.9), height: 1.3),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 120,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  decoration: _inputDeco().copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AdminColors.headerTitle)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12.5, color: AdminColors.muted.withValues(alpha: 0.92), height: 1.35),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.white,
          activeTrackColor: AdminColors.statBlue,
        ),
      ],
    );
  }

  Widget _saveButton({required VoidCallback onPressed}) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save_outlined, size: 20),
      label: const Text('Save Changes'),
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.statBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text('$e', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _settingsCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AdminColors.headerTitle),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AdminColors.muted.withValues(alpha: 0.92), height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _fieldLabel(String t) {
    return Text(
      t,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AdminColors.muted.withValues(alpha: 0.88), letterSpacing: 0.2),
    );
  }

  InputDecoration _inputDeco() {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: AdminColors.statBlue, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
    );
  }

  Widget _footer() {
    return Text(
      '© 2026 COTS Monitoring System. All rights reserved.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AdminColors.muted.withValues(alpha: 0.72)),
    );
  }
}
