import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../models/admin_preferences.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/admin_preferences_repository.dart';
import '../../../widgets/cots_loading_skeleton.dart';
import '../layout/admin_breakpoints.dart';
import '../theme/admin_theme.dart';
import 'admin_shell_screen.dart';

/// Settings workspace: 2×2 card grid, top bar, and footer. Sidebar is provided by [AdminShellScreen].
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key, this.preferencesStore});

  final AdminPreferencesStore? preferencesStore;

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late final AdminPreferencesStore _preferencesStore;
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _roleCtrl = TextEditingController(text: 'Administrator');

  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _emailNotifications = true;
  bool _highRiskAlerts = true;
  bool _systemUpdates = true;
  bool _weeklyReports = false;
  bool _twoFactorAuth = false;
  bool _loginAlerts = true;
  bool _sessionTimeout = true;
  bool _profileInitialized = false;
  bool _savingProfile = false;
  bool _changingPassword = false;
  bool _preferencesLoadStarted = false;
  bool _loadingPreferences = false;
  bool _savingPreferences = false;
  String? _preferencesError;
  String? _preferencesUid;

  @override
  void initState() {
    super.initState();
    _preferencesStore = widget.preferencesStore ?? AdminPreferencesRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profileInitialized) return;
    final profile = context.read<AuthProvider>().userModel;
    if (profile == null) return;
    _profileInitialized = true;
    _fullNameCtrl.text = profile.fullName;
    _emailCtrl.text = profile.email;
    _roleCtrl.text = profile.isAdmin
        ? 'Administrator'
        : profile.isExpert
            ? 'Expert'
            : profile.role;
    _preferencesUid = profile.uid;
    if (!_preferencesLoadStarted) {
      _preferencesLoadStarted = true;
      unawaited(_loadPreferences());
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _roleCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }

  Future<void> _loadPreferences() async {
    final uid = _preferencesUid;
    if (uid == null || uid.isEmpty) return;
    setState(() {
      _loadingPreferences = true;
      _preferencesError = null;
    });
    try {
      final preferences = await _preferencesStore.load(uid);
      if (!mounted) return;
      setState(() {
        _emailNotifications = preferences.emailNotifications;
        _highRiskAlerts = preferences.highRiskAlerts;
        _systemUpdates = preferences.systemUpdates;
        _weeklyReports = preferences.weeklyReports;
        _twoFactorAuth = preferences.twoFactorAuth;
        _loginAlerts = preferences.loginAlerts;
        _sessionTimeout = preferences.sessionTimeout;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferencesError =
            'Could not load saved preferences. Check your connection and Firestore rules.';
      });
    } finally {
      if (mounted) setState(() => _loadingPreferences = false);
    }
  }

  Future<void> _onSettingsRefresh() async {
    await context.read<AuthProvider>().refreshProfile();
    if (!mounted) return;
    await _loadPreferences();
    if (mounted && _preferencesError == null) {
      _snack('Settings refreshed.');
    }
  }

  Future<void> _savePreferences() async {
    final uid = _preferencesUid;
    if (uid == null || uid.isEmpty) {
      _snack('Sign in again to save preferences.');
      return;
    }
    setState(() {
      _savingPreferences = true;
      _preferencesError = null;
    });
    try {
      await _preferencesStore.save(AdminPreferences(
        uid: uid,
        emailNotifications: _emailNotifications,
        highRiskAlerts: _highRiskAlerts,
        systemUpdates: _systemUpdates,
        weeklyReports: _weeklyReports,
        twoFactorAuth: _twoFactorAuth,
        loginAlerts: _loginAlerts,
        sessionTimeout: _sessionTimeout,
      ));
      _snack('Preferences saved.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preferencesError =
            'Could not save preferences. Check your connection and Firestore rules.';
      });
      _snack(_preferencesError!);
    } finally {
      if (mounted) setState(() => _savingPreferences = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _fullNameCtrl.text.trim();
    if (name.length < 2) {
      _snack('Enter a valid full name.');
      return;
    }
    final auth = context.read<AuthProvider>();
    final profile = auth.userModel;
    if (profile == null) return;
    setState(() => _savingProfile = true);
    try {
      await auth.updateProfile(
        fullName: name,
        phoneNumber: profile.phoneNumber,
        role: profile.role,
        organization: profile.organization,
        assignedArea: profile.assignedArea,
      );
      _snack('Profile updated.');
    } catch (_) {
      _snack(auth.lastError ?? 'Could not update profile.');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _currentPasswordCtrl.text;
    final next = _newPasswordCtrl.text;
    if (current.isEmpty) {
      _snack('Enter your current password.');
      return;
    }
    if (next.length < 8) {
      _snack('Use at least 8 characters for the new password.');
      return;
    }
    if (next != _confirmPasswordCtrl.text) {
      _snack('New passwords do not match.');
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => _changingPassword = true);
    try {
      await auth.changePassword(currentPassword: current, newPassword: next);
      _currentPasswordCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _snack('Password updated.');
    } catch (_) {
      _snack(auth.lastError ?? 'Could not update password.');
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
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
              if (_loadingPreferences)
                const CotsLoadingSkeleton(
                  layout: CotsSkeletonLayout.section,
                  label: 'Loading administrator preferences',
                )
              else ...[
                if (_preferencesError != null) ...[
                  _preferencesErrorCard(),
                  const SizedBox(height: 18),
                ],
                _twoByTwoGrid(c.maxWidth),
              ],
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
          onPressed: _loadingPreferences ? null : _onSettingsRefresh,
          icon: AdminDateTimeTokens.refreshIcon,
          label: const Text('Refresh',
              style: AdminDateTimeTokens.refreshChipTextStyle),
          style: AdminDateTimeTokens.refreshOutlinedButtonStyle(),
        ),
        const SizedBox(width: 12),
        Badge(
          label: const Text('3',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
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
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DateFormat('MMM d, yyyy').format(DateTime.now()),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.headerTitle),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('h:mm a').format(DateTime.now()),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AdminColors.muted),
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
            const SizedBox(height: gap),
            b,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: gap),
          Expanded(child: b),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair(_profileCard(), _changePasswordCard()),
        const SizedBox(height: gap),
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
                  child: const Icon(Icons.person_rounded,
                      size: 52, color: AdminColors.statBlue),
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
            enabled: false,
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
            child: _saveButton(
              onPressed: _savingProfile ? null : _saveProfile,
              label: _savingProfile ? 'Saving...' : 'Save Changes',
            ),
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
            decoration:
                _inputDeco().copyWith(hintText: 'Enter current password'),
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
            decoration:
                _inputDeco().copyWith(hintText: 'Re-enter new password'),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(
              onPressed: _changingPassword ? null : _changePassword,
              label: _changingPassword ? 'Updating...' : 'Update Password',
            ),
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
            onChanged: _savingPreferences
                ? null
                : (v) => setState(() => _twoFactorAuth = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'Login Alerts',
            subtitle: 'Notify me of new device sign-ins',
            value: _loginAlerts,
            onChanged: _savingPreferences
                ? null
                : (v) => setState(() => _loginAlerts = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'Auto Session Timeout',
            subtitle: 'Sign out after inactivity',
            value: _sessionTimeout,
            onChanged: _savingPreferences
                ? null
                : (v) => setState(() => _sessionTimeout = v),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(
              onPressed: _savingPreferences ? null : _savePreferences,
              label: _savingPreferences ? 'Saving...' : 'Save Preferences',
            ),
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
            onChanged: _savingPreferences
                ? null
                : (v) => setState(() => _emailNotifications = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'High Risk Alerts',
            subtitle: 'Get notified for high risk zones',
            value: _highRiskAlerts,
            onChanged: _savingPreferences
                ? null
                : (v) => setState(() => _highRiskAlerts = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'System Updates',
            subtitle: 'Receive system update notifications',
            value: _systemUpdates,
            onChanged: _savingPreferences
                ? null
                : (v) => setState(() => _systemUpdates = v),
          ),
          const Divider(height: 22),
          _toggleTile(
            title: 'Weekly Reports',
            subtitle: 'Receive weekly summary reports',
            value: _weeklyReports,
            onChanged: _savingPreferences
                ? null
                : (v) => setState(() => _weeklyReports = v),
          ),
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: _saveButton(
              onPressed: _savingPreferences ? null : _savePreferences,
              label: _savingPreferences ? 'Saving...' : 'Save Preferences',
            ),
          ),
        ],
      ),
    );
  }

  Widget _preferencesErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminColors.statRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AdminColors.statRed.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AdminColors.statRed),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _preferencesError!,
              style: const TextStyle(
                color: AdminColors.headerTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _loadPreferences,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _toggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AdminColors.headerTitle)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 12.5,
                    color: AdminColors.muted.withValues(alpha: 0.92),
                    height: 1.35),
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

  Widget _saveButton(
      {required VoidCallback? onPressed, String label = 'Save Changes'}) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.save_outlined, size: 20),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.statBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
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
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AdminColors.headerTitle),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AdminColors.muted.withValues(alpha: 0.92),
                          height: 1.35),
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
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AdminColors.muted.withValues(alpha: 0.88),
          letterSpacing: 0.2),
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
      style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AdminColors.muted.withValues(alpha: 0.72)),
    );
  }
}
