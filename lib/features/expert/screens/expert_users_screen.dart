import 'package:flutter/material.dart';

import '../../../models/user_model.dart';
import '../../../services/expert_personnel_repository.dart';
import '../../admin/theme/admin_theme.dart';

class ExpertUsersScreen extends StatefulWidget {
  const ExpertUsersScreen({super.key, this.loadUsers});

  final Future<List<UserModel>> Function()? loadUsers;

  @override
  State<ExpertUsersScreen> createState() => _ExpertUsersScreenState();
}

class _ExpertUsersScreenState extends State<ExpertUsersScreen> {
  late Future<List<UserModel>> _users;
  String _query = '';
  String _role = 'All roles';
  bool _eligibleOnly = false;

  @override
  void initState() {
    super.initState();
    _users = _load();
  }

  Future<List<UserModel>> _load() =>
      (widget.loadUsers ?? ExpertPersonnelRepository.fetchUsers)();

  void _refresh() {
    setState(() {
      _users = _load();
    });
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

  void _profile(UserModel user) {
    showDialog<void>(
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
                child: Text('Users',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.headerTitle))),
            IconButton(
                onPressed: _refresh,
                tooltip: 'Refresh users',
                icon: const Icon(Icons.refresh)),
          ]),
          const Text(
              'Read-only personnel directory. Account approval and management belong to the Administrator.'),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
                labelText: 'Search name, organization or position',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder()),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _role,
                  items: const ['All roles', 'Administrator', 'Expert', 'Diver']
                      .map((role) =>
                          DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (value) => setState(() => _role = value!),
                ),
                FilterChip(
                    label: const Text('Approved Divers only'),
                    selected: _eligibleOnly,
                    onSelected: (value) =>
                        setState(() => _eligibleOnly = value)),
              ]),
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
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Unable to load users. Check your connection and Expert access. If newly installed, the directory migration may still need deployment.',
                        textAlign: TextAlign.center),
                    TextButton(onPressed: _refresh, child: const Text('Retry')),
                  ]));
                }
                final users = snapshot.data!
                    .where((user) =>
                        (_role == 'All roles' || _roleLabel(user) == _role) &&
                        (!_eligibleOnly || user.isVerifiedFieldPersonnel) &&
                        (_query.isEmpty ||
                            '${user.fullName} ${user.organization} ${user.role}'
                                .toLowerCase()
                                .contains(_query)))
                    .toList();
                if (users.isEmpty) {
                  return const Center(
                      child: Text('No users match these filters.'));
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
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
                        onTap: () => _profile(user),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
