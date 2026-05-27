import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_user_models.dart';
import '../theme/admin_theme.dart';
import 'admin_record_details_dialogs.dart';

Future<void> showAdminUserProfileDialog(BuildContext context, AdminUserProfileData d) {
  return showAdminBlurredDialog(
    context: context,
    maxWidthFraction: 0.72,
    child: Material(
      color: Colors.transparent,
      child: _UserProfileModalBody(data: d),
    ),
  );
}

class _UserProfileModalBody extends StatelessWidget {
  const _UserProfileModalBody({required this.data});
  final AdminUserProfileData data;

  @override
  Widget build(BuildContext context) {
    final roleColor = adminUserRoleColor(data.role);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).maybePop(),
      },
      child: GestureDetector(
        onTap: () {},
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 36, offset: const Offset(0, 18)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(context),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          final narrow = c.maxWidth < 720;
                          final left = _profileLeftCard(context);
                          final right = _detailsGrid(roleColor);
                          if (narrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [left, const SizedBox(height: 14), right],
                            );
                          }
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 42, child: left),
                                const SizedBox(width: 16),
                                Expanded(flex: 58, child: right),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      LayoutBuilder(
                        builder: (context, c) {
                          final narrow = c.maxWidth < 800;
                          final roleCard = _roleCard(roleColor);
                          final orgCard = _orgCard();
                          if (narrow) {
                            return Column(children: [roleCard, const SizedBox(height: 12), orgCard]);
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: roleCard),
                              const SizedBox(width: 12),
                              Expanded(child: orgCard),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _accountCard(),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _OutlinedCloseButton(onPressed: () => Navigator.pop(context)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminColors.headerTitle)),
                    SizedBox(height: 6),
                    Text(
                      'View user information and account details.',
                      style: TextStyle(fontSize: 13, color: AdminColors.muted, height: 1.35),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(foregroundColor: AdminColors.headerTitle),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
      ],
    );
  }

  Widget _profileLeftCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: AdminColors.statBlue.withValues(alpha: 0.15),
            child: Text(
              adminUserInitials(data.name),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AdminColors.statBlue),
            ),
          ),
          const SizedBox(height: 12),
          Text(data.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: data.active ? AdminColors.statGreen.withValues(alpha: 0.14) : AdminColors.statRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              data.active ? 'Active' : 'Inactive',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: data.active ? AdminColors.statGreen : AdminColors.statRed,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _smallLabel('Email'),
                Text(data.email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                _smallLabel('Phone'),
                Text(data.phone, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 10),
                _smallLabel('Member since'),
                Text(data.memberSince, style: TextStyle(fontSize: 13, color: AdminColors.headerTitle.withValues(alpha: 0.88))),
                const SizedBox(height: 10),
                _smallLabel('Last login'),
                Text(data.lastLogin, style: TextStyle(fontSize: 13, color: AdminColors.headerTitle.withValues(alpha: 0.88))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallLabel(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.muted.withValues(alpha: 0.85))),
    );
  }

  Widget _detailsGrid(Color roleColor) {
    Widget row(String k, Widget v) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 128,
              child: Text(k, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.85))),
            ),
            Expanded(child: v),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            'User ID',
            Text(data.userId, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
          ),
          row(
            'Role',
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                child: Text(data.role, style: TextStyle(fontWeight: FontWeight.w800, color: roleColor, fontSize: 12)),
              ),
            ),
          ),
          row('Organization', Text(data.organization, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          row('Assigned Zone(s)', Text(data.assignedZones, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          row(
            'Status',
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: data.active ? AdminColors.statGreen.withValues(alpha: 0.14) : AdminColors.statRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  data.active ? 'ACTIVE' : 'INACTIVE',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                    color: data.active ? AdminColors.statGreen : AdminColors.statRed,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(Color roleColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Role information', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdminColors.headerTitle)),
          const SizedBox(height: 10),
          Text(data.role, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: roleColor)),
          const SizedBox(height: 8),
          Text(data.roleDescription, style: TextStyle(fontSize: 13, height: 1.45, color: AdminColors.headerTitle.withValues(alpha: 0.88))),
          const SizedBox(height: 14),
          Text('Permissions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AdminColors.muted.withValues(alpha: 0.85))),
          const SizedBox(height: 8),
          for (final p in data.permissions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded, size: 18, color: AdminColors.statGreen),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _orgCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Organization information', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AdminColors.headerTitle)),
          const SizedBox(height: 10),
          Text(data.organization, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          _orgLine('Organization type', data.orgType),
          _orgLine('Location', data.orgLocation),
          const SizedBox(height: 8),
          Text(data.orgDescription, style: TextStyle(fontSize: 13, height: 1.45, color: AdminColors.headerTitle.withValues(alpha: 0.88))),
          const SizedBox(height: 12),
          _orgLine('Organization email', data.orgEmail),
          _orgLine('Contact number', data.orgPhone),
        ],
      ),
    );
  }

  Widget _orgLine(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(k, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.85))),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _accountCard() {
    Widget badge(String text, bool ok) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ok ? AdminColors.statGreen.withValues(alpha: 0.14) : AdminColors.statRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: ok ? AdminColors.statGreen : AdminColors.statRed),
        ),
      );
    }

    Widget line(String k, Widget trailing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 2,
              child: Text(k, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AdminColors.muted.withValues(alpha: 0.88))),
            ),
            Expanded(flex: 3, child: Align(alignment: Alignment.centerRight, child: trailing)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 12, bottom: 4),
            child: Text('Account information', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ),
          Divider(height: 1, color: Colors.black.withValues(alpha: 0.06)),
          line('Email verified', badge(data.emailVerified ? 'Verified' : 'Not verified', data.emailVerified)),
          line('Two-factor authentication', badge(data.twoFactorEnabled ? 'Enabled' : 'Disabled', data.twoFactorEnabled)),
          line('Last login', Text(data.lastLogin, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          line('Login access', Text(data.loginAccess, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          line(
            'Login IP address',
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.public_rounded, size: 18, color: AdminColors.statBlue.withValues(alpha: 0.85)),
                const SizedBox(width: 6),
                Text(data.loginIp, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlinedCloseButton extends StatefulWidget {
  const _OutlinedCloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_OutlinedCloseButton> createState() => _OutlinedCloseButtonState();
}

class _OutlinedCloseButtonState extends State<_OutlinedCloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: OutlinedButton(
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.headerTitle,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          side: BorderSide(color: AdminColors.headerTitle.withValues(alpha: _hover ? 0.45 : 0.28)),
          backgroundColor: _hover ? AdminColors.headerTitle.withValues(alpha: 0.05) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}
