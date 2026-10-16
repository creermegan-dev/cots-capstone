import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/personnel_repository.dart';
import '../../../services/follow_up_reassignment_repository.dart';
import '../models/admin_user_models.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dashboard_header.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_user_profile_modal.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchCtrl = TextEditingController();
  String _role = 'All Roles';
  String _org = 'All Organizations';
  String _status = 'All Status';
  int _page = 0;
  int _rowsPerPage = 10;

  static const List<AdminDataTableColumn> _tableColumns = [
    AdminDataTableColumn('User ID', 100),
    AdminDataTableColumn('Name', 200),
    AdminDataTableColumn('Email', 260),
    AdminDataTableColumn('Role', 200, headerAlign: TextAlign.center),
    AdminDataTableColumn('Organization', 180),
    AdminDataTableColumn('Status', 100, headerAlign: TextAlign.center),
    AdminDataTableColumn('Date Joined', 120),
    AdminDataTableColumn('Actions', 96, headerAlign: TextAlign.right),
  ];

  static const _roles = [
    'All Roles',
    'Administrator',
    'Marine Conservation Officer',
    'LGU Staff',
    'Researcher',
    'Volunteer',
    'Field Officer',
    'BFAR Staff',
  ];
  static const _orgs = [
    'All Organizations',
    'BFAR Region 7',
    'LGU Cebu City',
    'Marine Institute',
    'NGO ReefWatch',
    'DENR Region 7',
  ];
  static const _statuses = ['All Status', 'Active', 'Inactive'];

  static const _allRows = <AdminUserTableRow>[
    AdminUserTableRow(
      id: 'USR-00048',
      name: 'Juan Dela Cruz',
      email: 'juan.delacruz@bfar.gov.ph',
      role: 'Administrator',
      organization: 'BFAR Region 7',
      active: true,
      joined: 'May 18, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00047',
      name: 'Maria Santos',
      email: 'maria.santos@bfar.gov.ph',
      role: 'Marine Conservation Officer',
      organization: 'BFAR Region 7',
      active: true,
      joined: 'May 17, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00046',
      name: 'Pedro Reyes',
      email: 'pedro.reyes@cebu.gov.ph',
      role: 'LGU Staff',
      organization: 'LGU Cebu City',
      active: true,
      joined: 'May 16, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00045',
      name: 'Anna Garcia',
      email: 'anna.garcia@marine.edu.ph',
      role: 'Researcher',
      organization: 'Marine Institute',
      active: true,
      joined: 'May 15, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00044',
      name: 'Luis Mendoza',
      email: 'luis.m@reefwatch.org',
      role: 'Volunteer',
      organization: 'NGO ReefWatch',
      active: false,
      joined: 'May 14, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00043',
      name: 'Riza Padilla',
      email: 'r.padilla@bfar.gov.ph',
      role: 'Field Officer',
      organization: 'BFAR Region 7',
      active: true,
      joined: 'May 14, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00042',
      name: 'Carla Ramos',
      email: 'c.ramos@bfar.gov.ph',
      role: 'BFAR Staff',
      organization: 'BFAR Region 7',
      active: true,
      joined: 'May 12, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00041',
      name: 'Miguel Torres',
      email: 'm.torres@denr.gov.ph',
      role: 'Marine Conservation Officer',
      organization: 'DENR Region 7',
      active: true,
      joined: 'May 10, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00040',
      name: 'Elena Cruz',
      email: 'elena.cruz@bfar.gov.ph',
      role: 'LGU Staff',
      organization: 'LGU Cebu City',
      active: false,
      joined: 'May 8, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00039',
      name: 'James Ong',
      email: 'j.ong@marine.edu.ph',
      role: 'Researcher',
      organization: 'Marine Institute',
      active: true,
      joined: 'May 5, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00038',
      name: 'Sofia Lim',
      email: 'sofia.lim@bfar.gov.ph',
      role: 'Field Officer',
      organization: 'BFAR Region 7',
      active: true,
      joined: 'May 3, 2026',
    ),
    AdminUserTableRow(
      id: 'USR-00037',
      name: 'Daniel Cruz',
      email: 'daniel@reefwatch.org',
      role: 'Volunteer',
      organization: 'NGO ReefWatch',
      active: true,
      joined: 'Apr 28, 2026',
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AdminUserTableRow> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _allRows.where((r) {
      final byQ = q.isEmpty ||
          r.id.toLowerCase().contains(q) ||
          r.name.toLowerCase().contains(q) ||
          r.email.toLowerCase().contains(q) ||
          r.organization.toLowerCase().contains(q);
      final byR = _role == 'All Roles' || r.role == _role;
      final byO = _org == 'All Organizations' || r.organization == _org;
      final byS = _status == 'All Status' ||
          (_status == 'Active' && r.active) ||
          (_status == 'Inactive' && !r.active);
      return byQ && byR && byO && byS;
    }).toList();
  }

  static const _totalUsers = 48;

  void _openProfile(AdminUserTableRow row) {
    showAdminUserProfileDialog(context, AdminUserProfileData.fromTableRow(row));
  }

  void _onUsersHeaderRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Users list refreshed (demo).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final pageCount = (filtered.length / _rowsPerPage).ceil().clamp(1, 999);
    _page = _page.clamp(0, pageCount - 1);
    final start = _page * _rowsPerPage;
    final pageRows = filtered.skip(start).take(_rowsPerPage).toList();
    final end = pageRows.isEmpty ? 0 : start + pageRows.length;
    final displayTotal = _searchCtrl.text.trim().isEmpty &&
            _role == 'All Roles' &&
            _org == 'All Organizations' &&
            _status == 'All Status'
        ? _totalUsers
        : filtered.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 18),
          const _PersonnelVerificationPanel(),
          const SizedBox(height: 18),
          _statRow(),
          const SizedBox(height: 18),
          _filterCard(),
          const SizedBox(height: 14),
          _tableCard(pageRows, start, end, displayTotal, pageCount),
          const SizedBox(height: 20),
          _bottomInfo(),
        ],
      ),
    );
  }

  Widget _header() {
    final addUserBtn = FilledButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Add New User (mock) — form not implemented.')),
        );
      },
      icon: const Icon(Icons.person_add_outlined, size: 20),
      label: const Text('Add New User'),
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.statBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    return AdminDashboardHeader(
      title: 'Users',
      subtitle: 'Manage user accounts, roles, and organization access.',
      onRefreshTap: _onUsersHeaderRefresh,
      trailingExtra: addUserBtn,
    );
  }

  Widget _statRow() {
    const specs = [
      _UserStatSpec(Icons.groups_outlined, 'Total Users', '48',
          'All registered users', AdminColors.statBlue),
      _UserStatSpec(Icons.verified_user_outlined, 'Active Users', '42',
          'Enabled accounts', AdminColors.statGreen),
      _UserStatSpec(Icons.person_off_outlined, 'Inactive Users', '6',
          'Disabled accounts', AdminColors.statYellow),
      _UserStatSpec(Icons.admin_panel_settings_outlined, 'Roles', '8',
          'User roles defined', AdminColors.statPurple),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 1100) {
          final w = c.maxWidth < 520 ? c.maxWidth : (c.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: specs
                .map((s) => SizedBox(width: w, child: _UserStatCard(spec: s)))
                .toList(),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _UserStatCard(spec: specs[i])),
            ],
          ],
        );
      },
    );
  }

  Widget _filterCard() {
    return _card(
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 900;
          final children = <Widget>[
            SizedBox(
              width: narrow ? double.infinity : 240,
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() => _page = 0),
                decoration: const InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: Color(0xFFF7F9FC),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 160,
              child: _dropdownShell(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _role,
                    isExpanded: true,
                    items: _roles
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _role = v ?? 'All Roles';
                      _page = 0;
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 190,
              child: _dropdownShell(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _org,
                    isExpanded: true,
                    items: _orgs
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _org = v ?? 'All Organizations';
                      _page = 0;
                    }),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: narrow ? double.infinity : 140,
              child: _dropdownShell(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _status,
                    isExpanded: true,
                    items: _statuses
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _status = v ?? 'All Status';
                      _page = 0;
                    }),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _page = 0),
              icon: const Icon(Icons.filter_list_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF7F9FC),
                foregroundColor: AdminColors.headerTitle,
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ];
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  children[i],
                ],
              ],
            );
          }
          return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: children);
        },
      ),
    );
  }

  Widget _dropdownShell({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _tableCard(List<AdminUserTableRow> pageRows, int start, int end,
      int displayTotal, int pageCount) {
    final colMap = AdminDataTableColumn.widthsMap(_tableColumns);
    final tableW = AdminDataTableColumn.totalWidth(_tableColumns);
    return _card(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminDataTableScrollArea(
            tableWidth: tableW,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AdminDataTableHeader(columns: _tableColumns),
                for (final r in pageRows)
                  AdminDataTableClickableRow(
                    columnWidths: colMap,
                    onTap: () => _openProfile(r),
                    cells: _userRowCells(r),
                  ),
              ],
            ),
          ),
          AdminDataTablePaginationBar(
            summaryText: pageRows.isEmpty
                ? 'No users match your filters.'
                : 'Showing ${start + 1} to $end of $displayTotal users',
            pageIndex: _page,
            pageCount: pageCount,
            onPageSelected: (p) => setState(() => _page = p),
            trailing: AdminDataTableRowsPerPage(
              value: _rowsPerPage,
              onChanged: (v) => setState(() {
                _rowsPerPage = v ?? 10;
                _page = 0;
              }),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          ),
        ],
      ),
    );
  }

  List<TableCell> _userRowCells(AdminUserTableRow r) {
    final rc = adminUserRoleColor(r.role);
    return [
      AdminDataTableCells.text(r.id,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
      AdminDataTableCells.cell(
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: rc.withValues(alpha: 0.18),
              child: Text(r.initials,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900, color: rc)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: AdminColors.statBlue,
                  decoration: TextDecoration.underline,
                  decorationColor: AdminColors.statBlue,
                ),
              ),
            ),
          ],
        ),
      ),
      AdminDataTableCells.text(r.email,
          style: TextStyle(
              fontSize: 12.5,
              color: AdminColors.headerTitle.withValues(alpha: 0.88))),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(
            label: r.role,
            foreground: rc,
            background: rc.withValues(alpha: 0.12)),
      ),
      AdminDataTableCells.text(r.organization,
          style: const TextStyle(fontSize: 12)),
      AdminDataTableCells.cell(
        align: TextAlign.center,
        child: AdminDataTableBadge(
          label: r.active ? 'Active' : 'Inactive',
          foreground: r.active ? AdminColors.statGreen : AdminColors.statRed,
          background: (r.active ? AdminColors.statGreen : AdminColors.statRed)
              .withValues(alpha: 0.14),
        ),
      ),
      AdminDataTableCells.text(r.joined,
          style: TextStyle(
              fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.95))),
      AdminDataTableCells.cell(
        align: TextAlign.right,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'View',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => _openProfile(r),
              icon: Icon(Icons.visibility_outlined,
                  size: 20, color: AdminColors.statBlue.withValues(alpha: 0.9)),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {},
              icon: Icon(Icons.more_vert_rounded,
                  size: 20, color: AdminColors.muted.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _bottomInfo() {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 960;
        final left = _card(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AdminColors.statBlue.withValues(alpha: 0.85)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('About user roles & organizations',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      'Roles define the level of access and permissions in the system.\n\n'
                      'Organizations help group users by their affiliation or agency.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color:
                              AdminColors.headerTitle.withValues(alpha: 0.88)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        final right = _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Role legend',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 10),
              _legendLine(const Color(0xFF6A1B9A), 'Administrator',
                  'Full system access and management'),
              _legendLine(
                  AdminColors.statBlue,
                  'Marine Conservation Officer / Field Officer',
                  'Monitoring and review access'),
              _legendLine(AdminColors.statGreen, 'LGU Staff / BFAR Staff',
                  'Data submission and monitoring access'),
              _legendLine(const Color(0xFFF57C00), 'Researcher',
                  'View and analyze data'),
              _legendLine(AdminColors.statRed, 'Volunteer',
                  'Limited access for data submission'),
              _legendLine(AdminColors.muted, 'Other', 'Custom access level'),
            ],
          ),
        );
        if (narrow) {
          return Column(children: [left, const SizedBox(height: 14), right]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _legendLine(Color dot, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AdminColors.headerTitle.withValues(alpha: 0.88),
                    decoration: TextDecoration.none),
                children: [
                  TextSpan(
                      text: '$title — ',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(
                      text: text,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

class _PersonnelVerificationPanel extends StatefulWidget {
  const _PersonnelVerificationPanel();

  @override
  State<_PersonnelVerificationPanel> createState() =>
      _PersonnelVerificationPanelState();
}

class _PersonnelVerificationPanelState
    extends State<_PersonnelVerificationPanel> {
  String? _savingUid;

  Future<void> _setVerified(UserModel user, bool verified) async {
    final action = verified ? 'verify' : 'revoke verification for';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:
            Text(verified ? 'Verify field personnel?' : 'Revoke verification?'),
        content: Text(
          'Do you want to $action ${user.fullName}? '
          '${verified ? 'Only confirm credentials that were checked outside the app.' : 'They will no longer be eligible for new assignments.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(verified ? 'Verify' : 'Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final admin = context.read<AuthProvider>().userModel;
    setState(() => _savingUid = user.uid);
    try {
      await PersonnelRepository.setVerification(
        userId: user.uid,
        verified: verified,
        verifiedBy: admin?.uid ?? '',
      );
      await FollowUpReassignmentRepository.publishPersonnel(
          [user.copyWith(fieldPersonnelVerified: verified)]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? '${user.fullName} is now verified field personnel.'
                : '${user.fullName} is no longer verified field personnel.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update verification: $error')),
      );
    } finally {
      if (mounted) setState(() => _savingUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminColors.statGreen.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AdminColors.statGreen),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Field Personnel Verification',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AdminColors.headerTitle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm only credentials checked with the issuing organization. '
            'Verified users become available for intervention and temporary follow-up assignment.',
            style: TextStyle(color: AdminColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<UserModel>>(
            stream: PersonnelRepository.watchUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  'Could not load registered users: ${snapshot.error}',
                  style: const TextStyle(color: AdminColors.statRed),
                );
              }
              final users = (snapshot.data ?? const <UserModel>[])
                  .where((u) => !u.isAdmin && !u.isExpert && u.isActive)
                  .toList();
              if (users.isEmpty) {
                return const Text('No eligible registered users found.');
              }
              return Column(
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.publish_outlined),
                    label: const Text('Publish follow-up personnel directory'),
                    onPressed: _savingUid != null
                        ? null
                        : () async {
                            setState(() => _savingUid = 'directory');
                            try {
                              await FollowUpReassignmentRepository
                                  .publishPersonnel(snapshot.data ?? []);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Follow-up personnel directory published.')));
                              }
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    content: Text(
                                        'Could not publish directory: $error')));
                              }
                            } finally {
                              if (mounted) setState(() => _savingUid = null);
                            }
                          },
                  ),
                  for (var index = 0; index < users.length; index++) ...[
                    if (index > 0) const Divider(height: 18),
                    _personnelRow(users[index]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _personnelRow(UserModel user) {
    final verified = user.fieldPersonnelVerified;
    final busy = _savingUid == user.uid;
    return Row(
      children: [
        CircleAvatar(
          backgroundColor:
              (verified ? AdminColors.statGreen : AdminColors.muted)
                  .withValues(alpha: 0.14),
          child: Icon(
            verified ? Icons.verified_rounded : Icons.person_outline_rounded,
            color: verified ? AdminColors.statGreen : AdminColors.muted,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName.isEmpty ? user.email : user.fullName,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              Text(
                [
                  if (user.role.isNotEmpty) user.role,
                  if (user.organization.isNotEmpty) user.organization,
                  if (user.assignedArea.isNotEmpty) user.assignedArea,
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AdminColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : () => _setVerified(user, !verified),
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  verified
                      ? Icons.verified_user_outlined
                      : Icons.fact_check_outlined,
                  size: 18,
                ),
          label: Text(verified ? 'Verified' : 'Verify'),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                verified ? AdminColors.statGreen : AdminColors.statBlue,
          ),
        ),
      ],
    );
  }
}

class _UserStatSpec {
  const _UserStatSpec(
      this.icon, this.title, this.value, this.subtitle, this.color);
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
}

class _UserStatCard extends StatefulWidget {
  const _UserStatCard({required this.spec});
  final _UserStatSpec spec;

  @override
  State<_UserStatCard> createState() => _UserStatCardState();
}

class _UserStatCardState extends State<_UserStatCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.spec;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.1 : 0.06),
              blurRadius: _hover ? 22 : 16,
              offset: Offset(0, _hover ? 8 : 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(s.icon, color: s.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AdminColors.headerTitle)),
                  Text(s.value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                          color: AdminColors.headerTitle)),
                  Text(s.subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: AdminColors.muted.withValues(alpha: 0.9))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
