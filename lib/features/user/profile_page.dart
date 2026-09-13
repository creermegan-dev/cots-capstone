import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/user_shell_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../auth/auth_navigation.dart';
import 'cots_map_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

const String _appVersion = '1.0.2+3';

const List<String> _kRoleOptions = <String>[
  'Diver',
  'Field Officer',
  'LGU Staff',
  'BFAR Staff',
  'Researcher',
  'Marine Conservation Officer',
  'Volunteer',
  'Administrator',
  'Other',
];

const List<String> _kOrgOptions = <String>[
  'BFAR',
  'LGU',
  'Research Institution',
  'University / School',
  'Marine Conservation Group',
  'Volunteer Group',
  'Independent / None',
  'Other',
];

List<String> _optionsIncludingCurrent(String? current, List<String> options) {
  final value = current?.trim() ?? '';
  if (value.isEmpty || options.contains(value)) return options;
  return [value, ...options];
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGray,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kNavy,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: kNavy),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: userShellScanFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.profile,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
      ),
      body: SafeArea(
        bottom: false,
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoadingProfile && auth.userModel == null) {
              return const Center(child: CircularProgressIndicator(color: kGreen));
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _ProfileHeaderCard(user: auth.userModel),
                const SizedBox(height: 16),
                _OptionsCard(
                  children: [
                _ProfileOptionTile(
                  icon: Icons.person_outline,
                  label: 'Personal Information',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const PersonalInformationPage(),
                    ),
                  ),
                ),
                _ProfileOptionTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change Password',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const ChangePasswordPage(),
                    ),
                  ),
                ),
                _ProfileOptionTile(
                  icon: Icons.info_outline,
                  label: 'About',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutPage(),
                    ),
                  ),
                ),
                _ProfileOptionTile(
                  icon: Icons.chat_bubble_outline,
                  label: 'Feedback',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const FeedbackPage(),
                    ),
                  ),
                ),
                _ProfileOptionTile(
                  icon: Icons.logout_rounded,
                  label: 'Log Out',
                  isDestructive: true,
                  onTap: () => confirmAndSignOut(context, showSuccessSnackBar: true),
                ),
              ],
            ),
          ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.user});
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName
        : 'Your profile';
    final role = user?.role.trim().isNotEmpty == true ? user!.role : '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: kGreen,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionsCard extends StatelessWidget {
  const _OptionsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey.shade200,
          indent: 16,
          endIndent: 16,
        ));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: rows),
    );
  }
}

class _ProfileOptionTile extends StatelessWidget {
  const _ProfileOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final fg = isDestructive ? kHigh : kNavy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDestructive ? kHigh : Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub pages ─────────────────────────────────────────────────────────────

class _SubScaffold extends StatelessWidget {
  const _SubScaffold({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: AppBackIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconColor: kNavy,
        ),
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: kNavy,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: child,
        ),
      ),
    );
  }
}

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullName = TextEditingController();
  late final TextEditingController _email = TextEditingController();
  late final TextEditingController _phone = TextEditingController();
  late final TextEditingController _assignedArea = TextEditingController();

  String _role = _kRoleOptions.first;
  String? _organization;
  bool _saving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final user = context.read<AuthProvider>().userModel;
    if (user != null) {
      _fullName.text = user.fullName;
      _email.text = user.email;
      _phone.text = user.phoneNumber;
      _assignedArea.text = user.assignedArea;
      _role = user.role.trim().isNotEmpty ? user.role : _kRoleOptions.first;
      _organization = user.organization.trim().isEmpty ? null : user.organization;
    }
    _initialized = true;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _assignedArea.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    auth.clearLastError();

    try {
      await auth.updateProfile(
        fullName: _fullName.text,
        phoneNumber: _phone.text,
        role: _role,
        organization: _organization ?? '',
        assignedArea: _assignedArea.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? AuthService.messageFor(e)),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangesSavedDialog(
        fullName: _fullName.text.trim(),
        position: _role,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        organization: _organization ?? '—',
        assignedArea: _assignedArea.text.trim().isEmpty
            ? '—'
            : _assignedArea.text.trim(),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kGray,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: AppBackIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconColor: kNavy,
        ),
        centerTitle: true,
        title: const Text(
          'Personal Information',
          style: TextStyle(
            color: kNavy,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      floatingActionButton: userShellScanFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.profile,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              _PersonalHeaderCard(user: context.watch<AuthProvider>().userModel),
              const SizedBox(height: 14),
              _PersonalFormCard(
                children: [
                  const _SectionTitle('Personal Information'),
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Full Name',
                    child: _TextInput(
                      controller: _fullName,
                      icon: Icons.person_outline,
                      hintText: 'Enter full name',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ),
                  _LabeledField(
                    label: 'Position / Role',
                    child: _DropdownInput<String>(
                      value: _role,
                      icon: Icons.badge_outlined,
                      items: _optionsIncludingCurrent(_role, _kRoleOptions),
                      onChanged: (v) =>
                          setState(() => _role = v ?? _role),
                    ),
                  ),
                  _LabeledField(
                    label: 'Email Address',
                    child: _TextInput(
                      controller: _email,
                      icon: Icons.mail_outline,
                      hintText: 'name@example.com',
                      keyboardType: TextInputType.emailAddress,
                      readOnly: true,
                    ),
                  ),
                  _LabeledField(
                    label: 'Phone Number',
                    child: _TextInput(
                      controller: _phone,
                      icon: Icons.phone_outlined,
                      hintText: '+63 ___ ___ ____',
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Invalid phone'
                          : null,
                    ),
                  ),
                  _LabeledField(
                    label: 'Organization (Optional)',
                    child: _DropdownInput<String>(
                      value: _organization,
                      icon: Icons.apartment_outlined,
                      items: _optionsIncludingCurrent(
                        _organization,
                        _kOrgOptions,
                      ),
                      hint: 'Select organization',
                      onChanged: (v) =>
                          setState(() => _organization = v),
                    ),
                  ),
                  _LabeledField(
                    label: 'Assigned Area',
                    child: _TextInput(
                      controller: _assignedArea,
                      icon: Icons.location_on_outlined,
                      hintText: 'e.g. Panabo Reef',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kNavy,
                            side: const BorderSide(
                                color: Color(0xFFD1D5DB)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalHeaderCard extends StatelessWidget {
  const _PersonalHeaderCard({required this.user});
  final UserModel? user;

  @override
  Widget build(BuildContext context) {
    final name = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName
        : 'Your profile';
    final role = user?.role.trim().isNotEmpty == true ? user!.role : '—';
    final email = user?.email.trim().isNotEmpty == true ? user!.email : '—';
    final phone =
        user?.phoneNumber.trim().isNotEmpty == true ? user!.phoneNumber : '—';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: kGreen,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: kNavy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: const TextStyle(
                    color: kNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: const TextStyle(
                    color: kNavy,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalFormCard extends StatelessWidget {
  const _PersonalFormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: kNavy,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  required IconData icon,
  String? hintText,
}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
    borderSide: BorderSide(color: Color(0xFFD1D5DB)),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF9CA3AF),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    prefixIcon: Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Icon(icon, size: 18, color: const Color(0xFF6B7280)),
    ),
    prefixIconConstraints:
        const BoxConstraints(minWidth: 0, minHeight: 0),
    isDense: true,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: border,
    border: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: kGreen, width: 1.4),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: kHigh),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: kHigh, width: 1.4),
    ),
  );
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.icon,
    this.hintText,
    this.keyboardType,
    this.validator,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final IconData icon;
  final String? hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: TextStyle(
        color: readOnly ? const Color(0xFF6B7280) : kNavy,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(icon: icon, hintText: hintText),
    );
  }
}

class _DropdownInput<T> extends StatelessWidget {
  const _DropdownInput({
    required this.value,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final T? value;
  final IconData icon;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      isDense: true,
      iconSize: 22,
      icon: const Padding(
        padding: EdgeInsets.only(right: 10),
        child: Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280)),
      ),
      style: const TextStyle(
        color: kNavy,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      hint: hint == null
          ? null
          : Text(
              hint!,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
      decoration: _fieldDecoration(icon: icon),
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text('$e'),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

class _ChangesSavedDialog extends StatelessWidget {
  const _ChangesSavedDialog({
    required this.fullName,
    required this.position,
    required this.email,
    required this.phone,
    required this.organization,
    required this.assignedArea,
  });

  final String fullName;
  final String position;
  final String email;
  final String phone;
  final String organization;
  final String assignedArea;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: kGreen,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 32),
              ),
              const SizedBox(height: 14),
              const Text(
                'Changes Saved Successfully!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: kNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your personal information has been updated.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Column(
                  children: [
                    _SummaryDialogRow(
                      icon: Icons.person_outline,
                      label: 'Full Name:',
                      value: fullName,
                    ),
                    _SummaryDialogRow(
                      icon: Icons.badge_outlined,
                      label: 'Position:',
                      value: position,
                    ),
                    _SummaryDialogRow(
                      icon: Icons.mail_outline,
                      label: 'Email Address:',
                      value: email,
                    ),
                    _SummaryDialogRow(
                      icon: Icons.phone_outlined,
                      label: 'Phone Number:',
                      value: phone,
                    ),
                    _SummaryDialogRow(
                      icon: Icons.apartment_outlined,
                      label: 'Organization:',
                      value: organization,
                    ),
                    _SummaryDialogRow(
                      icon: Icons.location_on_outlined,
                      label: 'Assigned Area:',
                      value: assignedArea,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'OK, GOT IT',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryDialogRow extends StatelessWidget {
  const _SummaryDialogRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFEEF1F4), width: 1),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: kGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kNavy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    auth.clearLastError();

    try {
      await auth.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.lastError ?? AuthService.messageFor(e)),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated successfully.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _SubScaffold(
      title: 'Change Password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _passwordField(
              label: 'Current Password',
              controller: _current,
              show: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            _passwordField(
              label: 'New Password',
              controller: _next,
              show: _showNext,
              onToggle: () => setState(() => _showNext = !_showNext),
              validator: (v) {
                if (v == null || v.length < 8) {
                  return 'Use at least 8 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _passwordField(
              label: 'Confirm New Password',
              controller: _confirm,
              show: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
              validator: (v) {
                if (v != _next.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'UPDATE PASSWORD',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required String label,
    required TextEditingController controller,
    required bool show,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kGreen, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.grey.shade600,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SubScaffold(
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _aboutHeroCard(),
          const SizedBox(height: 14),
          _aboutSectionCard(
            icon: Icons.public_rounded,
            iconColor: const Color(0xFFE53935),
            title: 'Why COTS Must Be Controlled',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crown-of-Thorns Starfish (Acanthaster planci) are coral predators. '
                  'During outbreak events they can strip reefs of living coral tissue, '
                  'weaken biodiversity, and slow recovery for years.',
                  style: TextStyle(fontSize: 13, color: kNavy, height: 1.45),
                ),
                SizedBox(height: 10),
                Text(
                  'Early detection and timely removal protect reef health, fisheries, '
                  'and coastal communities that depend on healthy coral ecosystems.',
                  style: TextStyle(fontSize: 13, color: kNavy, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _aboutSectionCard(
            icon: Icons.lightbulb_outline_rounded,
            iconColor: const Color(0xFFF6A623),
            title: 'COTS Facts',
            child: Column(
              children: const [
                _FactTile(
                  emojiIcon: Icons.restaurant_rounded,
                  title: 'Coral eaters',
                  body:
                      'A single adult COTS can consume large areas of coral tissue, '
                      'preferring fast-growing reef-building corals.',
                ),
                _FactTile(
                  emojiIcon: Icons.groups_rounded,
                  title: 'Outbreak risk',
                  body:
                      'When populations boom, reefs can lose most live coral cover '
                      'in months — turning vibrant reefs into white, dead skeletons.',
                ),
                _FactTile(
                  emojiIcon: Icons.visibility_rounded,
                  title: 'Hard to spot underwater',
                  body:
                      'COTS blend into reef textures. Divers and GoPro footage help '
                      'catch infestations earlier than patrols alone.',
                ),
                _FactTile(
                  emojiIcon: Icons.eco_rounded,
                  title: 'Removal works',
                  body:
                      'Targeted manual removal and injection methods, guided by '
                      'accurate maps, are proven ways to reduce outbreak pressure.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _aboutSectionCard(
            icon: Icons.memory_rounded,
            iconColor: const Color(0xFF1F7A7A),
            title: 'About This System',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COTS Monitoring is a Machine Learning-Based Crown of Thorn Starfish '
                  'Detection and GIS Mapping System. It supports field divers and '
                  'experts in finding, validating, and mapping COTS threats.',
                  style: TextStyle(fontSize: 13, color: kNavy, height: 1.45),
                ),
                SizedBox(height: 12),
                _SystemBullet(
                  title: 'Machine Learning Detection',
                  body: 'Upload GoPro images to detect COTS with confidence scores.',
                ),
                _SystemBullet(
                  title: 'GIS Mapping',
                  body: 'Visualize reef zones and infestation levels on interactive maps.',
                ),
                _SystemBullet(
                  title: 'Expert Validation',
                  body: 'Experts approve or reject uncertain detections before action.',
                ),
                _SystemBullet(
                  title: 'Removal Evidence',
                  body: 'Submit removal photos to close the monitoring–intervention loop.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _aboutSectionCard(
            icon: Icons.handshake_outlined,
            iconColor: const Color(0xFF2563EB),
            title: 'Your Role as a Diver',
            child: const Text(
              'Every capture you submit strengthens outbreak awareness. Clear photos, '
              'accurate GPS, and honest notes help experts validate detections faster '
              'and guide where intervention teams should go next.',
              style: TextStyle(fontSize: 13, color: kNavy, height: 1.45),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Information',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                  ),
                ),
                const SizedBox(height: 8),
                const _AboutRow(label: 'Version', value: _appVersion),
                const _AboutDivider(),
                const _AboutRow(
                  label: 'Developer',
                  value: 'Megan Creer',
                ),
                const _AboutDivider(),
                const _AboutRow(
                  label: 'Project Manager',
                  value: 'Angek Lyhksine Mayor',
                ),
                const _AboutDivider(),
                const _AboutRow(
                  label: 'Project Analyst',
                  value: 'Meariell Deace Bantillo',
                ),
                const _AboutDivider(),
                const _AboutRow(label: 'Platform', value: 'Flutter (Windows / Mobile)'),
                const _AboutDivider(),
                const _AboutRow(label: 'License', value: 'Internal / Academic'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _aboutHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF174F57)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COTS Monitor',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Protect coral reefs through machine learning detection, expert validation, '
            'and GIS-guided intervention.',
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white70,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _aboutSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.emojiIcon,
    required this.title,
    required this.body,
  });

  final IconData emojiIcon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(emojiIcon, size: 18, color: const Color(0xFF1F7A7A)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemBullet extends StatelessWidget {
  const _SystemBullet({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.check_circle, size: 14, color: Color(0xFF1F7A7A)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: Colors.grey.shade700,
                ),
                children: [
                  TextSpan(
                    text: '$title — ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kNavy,
                    ),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: kNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutDivider extends StatelessWidget {
  const _AboutDivider();
  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFEEEEEE),
      );
}

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _message = TextEditingController();
  String _category = 'Bug';
  int _rating = 5;
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a short message.')),
      );
      return;
    }
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for the feedback! (demo)')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _SubScaffold(
      title: 'Feedback',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How would you rate the app?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return IconButton(
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: filled ? kModerate : Colors.grey.shade400,
                ),
                onPressed: () => setState(() => _rating = i + 1),
              );
            }),
          ),
          const SizedBox(height: 12),
          const Text(
            'Category',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Bug', 'Suggestion', 'Praise', 'Other'].map((c) {
              final selected = _category == c;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => setState(() => _category = c),
                selectedColor: kGreen.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  color: selected ? kGreen : kNavy,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Text(
            'Message',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _message,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Tell us what happened or what could be better...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kGreen, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: const Text(
              'SEND',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
