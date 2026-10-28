import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Table row on the Users management screen.
class AdminUserTableRow {
  const AdminUserTableRow({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.organization,
    required this.active,
    required this.joined,
    this.phone = '',
    this.assignedArea = '',
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String organization;
  final bool active;
  final String joined;
  final String phone;
  final String assignedArea;

  String get initials => adminUserInitials(name);
}

/// Full profile payload for [showAdminUserProfileDialog].
class AdminUserProfileData {
  const AdminUserProfileData({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.active,
    required this.memberSince,
    required this.lastLogin,
    required this.role,
    required this.organization,
    required this.assignedZones,
    required this.roleDescription,
    required this.permissions,
    required this.orgType,
    required this.orgLocation,
    required this.orgDescription,
    required this.orgEmail,
    required this.orgPhone,
    required this.emailVerified,
    required this.twoFactorEnabled,
    required this.loginAccess,
    required this.loginIp,
  });

  final String userId;
  final String name;
  final String email;
  final String phone;
  final bool active;
  final String memberSince;
  final String lastLogin;
  final String role;
  final String organization;
  final String assignedZones;
  final String roleDescription;
  final List<String> permissions;
  final String orgType;
  final String orgLocation;
  final String orgDescription;
  final String orgEmail;
  final String orgPhone;
  final bool emailVerified;
  final bool twoFactorEnabled;
  final String loginAccess;
  final String loginIp;

  factory AdminUserProfileData.fromTableRow(AdminUserTableRow r) {
    return AdminUserProfileData(
      userId: r.id,
      name: r.name,
      email: r.email,
      phone: r.phone.isEmpty ? 'Not provided' : r.phone,
      active: r.active,
      memberSince: r.joined,
      lastLogin: 'Not available',
      role: r.role,
      organization: r.organization,
      assignedZones: r.assignedArea.isEmpty ? 'Not assigned' : r.assignedArea,
      roleDescription: 'Role information from the registered user profile.',
      permissions: const [],
      orgType: 'Registered organization',
      orgLocation: 'Not provided',
      orgDescription:
          r.organization.isEmpty ? 'No organization provided.' : r.organization,
      orgEmail: 'Not provided',
      orgPhone: 'Not provided',
      emailVerified: false,
      twoFactorEnabled: false,
      loginAccess: 'Not available',
      loginIp: 'Not available',
    );
  }
}

String adminUserInitials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    final p = parts.first;
    if (p.length >= 2) return p.substring(0, 2).toUpperCase();
    return p.isEmpty ? '?' : '${p[0]}•'.toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

Color adminUserRoleColor(String role) {
  return switch (role) {
    'Administrator' => const Color(0xFF6A1B9A),
    'Marine Conservation Officer' => AdminColors.statBlue,
    'LGU Staff' => AdminColors.statGreen,
    'Researcher' => const Color(0xFFF57C00),
    'Volunteer' => AdminColors.statRed,
    'Field Officer' => const Color(0xFF039BE5),
    'BFAR Staff' => const Color(0xFF7B1FA2),
    _ => AdminColors.muted,
  };
}
