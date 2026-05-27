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
  });

  final String id;
  final String name;
  final String email;
  final String role;
  final String organization;
  final bool active;
  final String joined;

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
    if (r.id == 'USR-00043') {
      return const AdminUserProfileData(
        userId: 'USR-00043',
        name: 'Riza Padilla',
        email: 'r.padilla@bfar.gov.ph',
        phone: '+63 912 123 3456',
        active: true,
        memberSince: 'May 14, 2026',
        lastLogin: 'May 19, 2026 8:15 AM',
        role: 'Field Officer',
        organization: 'BFAR Region 7',
        assignedZones: 'Zone A, Zone B',
        roleDescription:
            'Collects field data, monitors COTS incidents, and submits reports.',
        permissions: [
          'Map Monitoring (View)',
          'Records / Submissions (Create)',
          'Reports (View Only)',
          'Alerts (View)',
        ],
        orgType: 'BFAR',
        orgLocation: 'Central Visayas, Philippines',
        orgDescription: 'Bureau of Fisheries and Aquatic Resources — Region 7 Central Visayas',
        orgEmail: 'region7@bfar.gov.ph',
        orgPhone: '+63 32 345 5678',
        emailVerified: true,
        twoFactorEnabled: true,
        loginAccess: 'Mobile & Web',
        loginIp: '119.94.45.87',
      );
    }
    return AdminUserProfileData._generic(r);
  }

  factory AdminUserProfileData._generic(AdminUserTableRow r) {
    final zones = switch (r.organization) {
      'BFAR Region 7' => 'Zone A, Zone C',
      'LGU Cebu City' => 'Zone B',
      'Marine Institute' => 'Zone D, Zone E',
      _ => 'Zone A',
    };
    final desc = switch (r.role) {
      'Administrator' => 'Full system access, user management, and policy configuration.',
      'Marine Conservation Officer' => 'Reviews detection reports and coordinates conservation response.',
      'LGU Staff' => 'Submits local observations and coordinates with field teams.',
      'Researcher' => 'Views and exports data for analysis and publications.',
      'Volunteer' => 'Limited submission access under supervision.',
      'Field Officer' => 'Collects field data, monitors COTS incidents, and submits reports.',
      'BFAR Staff' => 'Regional data submission and compliance monitoring.',
      _ => 'Standard operational access.',
    };
    final perms = switch (r.role) {
      'Administrator' => [
        'Map Monitoring (Full)',
        'Records / Submissions (Full)',
        'Reports (Full)',
        'Alerts (Full)',
        'Users (Manage)',
      ],
      'Marine Conservation Officer' => [
        'Map Monitoring (View)',
        'Records / Submissions (Review)',
        'Reports (View)',
        'Alerts (View)',
      ],
      'Researcher' => [
        'Map Monitoring (View)',
        'Reports (View)',
        'Analytics (View)',
      ],
      _ => [
        'Map Monitoring (View)',
        'Records / Submissions (Create)',
        'Alerts (View)',
      ],
    };
    return AdminUserProfileData(
      userId: r.id,
      name: r.name,
      email: r.email,
      phone: '+63 917 000 0000',
      active: r.active,
      memberSince: r.joined,
      lastLogin: 'May 19, 2026 7:42 AM',
      role: r.role,
      organization: r.organization,
      assignedZones: zones,
      roleDescription: desc,
      permissions: perms,
      orgType: r.organization.contains('BFAR') ? 'BFAR' : 'Partner Agency',
      orgLocation: 'Philippines',
      orgDescription: '${r.organization} — affiliated unit for COTS monitoring.',
      orgEmail: 'contact@${r.organization.toLowerCase().replaceAll(' ', '')}.gov.ph',
      orgPhone: '+63 2 888 0000',
      emailVerified: r.active,
      twoFactorEnabled: r.role == 'Administrator' || r.role == 'Marine Conservation Officer',
      loginAccess: 'Web',
      loginIp: '203.0.113.${(r.id.hashCode % 200).abs() + 10}',
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
