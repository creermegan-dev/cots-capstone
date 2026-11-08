import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../../services/expert_personnel_repository.dart';
import '../../../services/auth_service.dart';
import '../../admin/theme/admin_theme.dart';

class ExpertUsersScreen extends StatefulWidget {
  const ExpertUsersScreen({super.key, this.loadUsers, this.setVerification});

  final Future<List<UserModel>> Function()? loadUsers;
  final Future<void> Function(UserModel, bool)? setVerification;

  @override
  State<ExpertUsersScreen> createState() => _ExpertUsersScreenState();
}

class _ExpertUsersScreenState extends State<ExpertUsersScreen> {
  late Future<List<UserModel>> _users;
  String _query = '';
  bool _verifiedTab = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _users = _load();
  }

  Future<List<UserModel>> _load() =>
      (widget.loadUsers ?? ExpertPersonnelRepository.fetchUsers)();

  void _submitSearch() {
    setState(() {});
    FocusScope.of(context).unfocus();
  }

  void _refresh() {
    if (_saving) return;
    setState(() {
      _users = _load();
    });
  }

  Future<void> _reviewPersonnel(UserModel user, bool verified) async {
    if (_saving || user.isAdmin || user.isExpert || !user.isActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(verified
            ? 'Verify field personnel?'
            : 'Revoke personnel verification?'),
        content: Text(verified
            ? 'Confirm that you checked ${user.fullName}\'s field credentials with their organization. This allows eligible field submissions and assignments.'
            : 'Revoke field verification for ${user.fullName}? They will no longer be eligible for new field submissions and assignments. Their account and saved records will remain.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(verified ? 'Verify' : 'Revoke verification')),
        ],
      ),
    );
    if (confirmed != true || !mounted || _saving) return;
    setState(() => _saving = true);
    try {
      await (widget.setVerification ??
          ExpertPersonnelRepository.setVerification)(user, verified);
      if (!mounted) return;
      setState(() {
        _users = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(verified
              ? 'Personnel verified.'
              : 'Personnel verification revoked.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Could not update personnel verification. ${AuthService.messageFor(error)}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _roleLabel(UserModel user) => user.isAdmin
      ? 'Administrator'
      : user.isExpert
          ? 'Expert'
          : 'Diver';

  static String _status(UserModel user) => !user.isActive
      ? 'Inactive'
      : user.isVerifiedFieldPersonnel
          ? 'Approved field personnel'
          : user.isAdmin || user.isExpert
              ? 'Active'
              : 'Awaiting field approval';

  Future<void> _profile(UserModel user) async {
    final decision = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.fullName.isEmpty ? 'Unnamed user' : user.fullName),
        scrollable: true,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Role: ${_roleLabel(user)}'),
            const SizedBox(height: 12),
            Text(
                'Organization: ${user.organization.isEmpty ? 'Not provided' : user.organization}'),
            const SizedBox(height: 12),
            Text('Position: ${user.role.isEmpty ? 'Not provided' : user.role}'),
            const SizedBox(height: 12),
            Text('Status: ${_status(user)}'),
          ],
        ),
        actions: [
          if (!user.isAdmin && !user.isExpert && user.isActive)
            FilledButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.pop(context, !user.fieldPersonnelVerified),
              child: Text(user.fieldPersonnelVerified
                  ? 'Revoke verification'
                  : 'Verify personnel'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
    if (decision != null && mounted) await _reviewPersonnel(user, decision);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                    child: Text('Personnel Verification',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.headerTitle))),
                IconButton(
                    onPressed: _saving ? null : _refresh,
                    tooltip: 'Refresh users',
                    icon: const Icon(Icons.refresh)),
              ]),
              const Text(
                  'Check field credentials before verifying personnel. Verification affects field eligibility; account activation and existing records are unchanged.'),
              if (_saving) const LinearProgressIndicator(),
              const SizedBox(height: 16),
              TextField(
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(),
                decoration: InputDecoration(
                    labelText: 'Search name, organization or position',
                    prefixIcon: IconButton(
                      onPressed: _submitSearch,
                      tooltip: 'Search users',
                      icon: const Icon(Icons.search),
                    ),
                    border: const OutlineInputBorder()),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              TabBar(
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                onTap: (index) => setState(() => _verifiedTab = index == 1),
                tabs: const [
                  Tab(
                      height: 64,
                      child: Text('Pending Verification',
                          softWrap: true, textAlign: TextAlign.center)),
                  Tab(
                      height: 64,
                      child: Text('Verified Personnel',
                          softWrap: true, textAlign: TextAlign.center)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<UserModel>>(
                  future: _users,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Unable to load users. Check your connection and Expert access. If newly installed, the directory migration may still need deployment.',
                            textAlign: TextAlign.center),
                        TextButton(
                            onPressed: _refresh, child: const Text('Retry')),
                      ]));
                    }
                    final users = snapshot.data!
                        .where((user) =>
                            !user.isAdmin &&
                            !user.isExpert &&
                            user.fieldPersonnelVerified == _verifiedTab &&
                            (_query.isEmpty ||
                                '${user.fullName} ${user.organization} ${user.role}'
                                    .toLowerCase()
                                    .contains(_query)))
                        .toList();
                    if (users.isEmpty) {
                      return Center(
                          child: Text(_verifiedTab
                              ? 'No verified personnel match this search.'
                              : 'No pending personnel match this search.'));
                    }
                    return ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return Card(
                          color: AdminColors.cardWhite,
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: const Icon(Icons.person_outline),
                            title: Text(user.fullName.isEmpty
                                ? 'Unnamed user'
                                : user.fullName),
                            subtitle: Text(
                                '${_roleLabel(user)} • ${user.organization.isEmpty ? 'No organization' : user.organization}\n${_status(user)}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _saving ? null : () => _profile(user),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ));
  }
}
