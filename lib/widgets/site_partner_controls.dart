import 'package:flutter/material.dart';

import '../core/cots_colors.dart';
import '../models/site_partner.dart';
import '../services/site_partner_service.dart';

/// Stage 10: site partners (2 main Divers per site), on the Diver side.

String _errorText(Object error) {
  final text = error.toString();
  final match = RegExp(r'message: ([^,]+)').firstMatch(text);
  return match?.group(1) ?? text;
}

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

Future<bool> _confirm(BuildContext context, String title, String message,
        String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action)),
        ],
      ),
    ) ??
    false;

/// On a site's card: "Main Divers: …", the "Add site partner" button for
/// Main Diver 1 while the place is empty, and the open request for the site.
class SiteTeamPanel extends StatefulWidget {
  const SiteTeamPanel({
    super.key,
    required this.areaCode,
    this.api = const SitePartnerApi(),
    this.fallbackDiverName = '',
  });

  final String areaCode;
  final SitePartnerApi api;
  final String fallbackDiverName;

  @override
  State<SiteTeamPanel> createState() => _SiteTeamPanelState();
}

class _SiteTeamPanelState extends State<SiteTeamPanel> {
  late Future<(List<SiteTeam>, List<SitePartnerRequest>)> _data = _load();
  bool _busy = false;

  Future<(List<SiteTeam>, List<SitePartnerRequest>)> _load() async =>
      (await widget.api.teams(), await widget.api.requests());

  void _reload() => setState(() {
        _data = _load();
      });

  Future<void> _add(SiteTeam team) async {
    List<Map<String, dynamic>> choices;
    try {
      choices = await widget.api.choices(team.areaCode);
    } catch (error) {
      if (mounted) _snack(context, _errorText(error));
      return;
    }
    if (!mounted) return;
    var query = '';
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(builder: (context, updateSearch) {
        final filtered = choices
            .where((person) => (person['name']?.toString() ?? '')
                .toLowerCase()
                .contains(query.trim().toLowerCase()))
            .toList();
        return SimpleDialog(
          title: const Text('Add site partner'),
          children: [
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                    'Choose a verified Diver to share ${team.areaName} with you. '
                    'They must accept, and then the Expert approves.')),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: TextField(
                onChanged: (value) => updateSearch(() => query = value),
                decoration: const InputDecoration(
                  hintText: 'Search diver by name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            if (choices.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No other verified Divers have an account yet.')),
            if (choices.isNotEmpty && filtered.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No divers match your search.')),
            for (final person in filtered)
              SimpleDialogOption(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  onPressed: () => Navigator.pop(dialogContext, person),
                  child: Text(person['name']?.toString() ?? '')),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Back')),
          ],
        );
      }),
    );
    if (selected == null || !mounted) return;
    final name = selected['name']?.toString() ?? '';
    if (!await _confirm(
        context,
        'Invite $name?',
        '$name will be asked to accept. If they accept, the Expert decides. '
            'A site partner cannot be removed later.',
        'Send invitation')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.invite(team.areaCode, selected['uid'].toString());
      if (mounted) _snack(context, 'Invitation sent to $name.');
    } catch (error) {
      if (mounted) _snack(context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
  }

  Future<void> _leave(SiteTeam team) async {
    if (!await _confirm(
        context,
        'Leave ${team.areaName}?',
        'You will no longer be a main Diver of this site. Your new records '
            'there will wait for the Expert. Your past records and visits stay '
            'under your name. ${team.mainDiverName} and the Expert will be told.',
        'Leave site')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.leave(team.areaCode);
      if (mounted) _snack(context, 'You left ${team.areaName}.');
    } catch (error) {
      if (mounted) _snack(context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(List<SiteTeam>, List<SitePartnerRequest>)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.fallbackDiverName.isNotEmpty)
                    Text('Assigned diver: ${widget.fallbackDiverName}'),
                  TextButton(
                      onPressed: _reload,
                      child: const Text(
                          'Could not load the site\'s Divers. Retry')),
                ]);
          }
          if (!snapshot.hasData) {
            return widget.fallbackDiverName.isEmpty
                ? const SizedBox.shrink()
                : Text('Assigned diver: ${widget.fallbackDiverName}');
          }
          final team = snapshot.data!.$1
              .where((t) => t.areaCode == widget.areaCode)
              .firstOrNull;
          if (team == null) {
            return widget.fallbackDiverName.isEmpty
                ? const SizedBox.shrink()
                : Text('Assigned diver: ${widget.fallbackDiverName}');
          }
          final open = snapshot.data!.$2
              .where((r) =>
                  r.areaCode == widget.areaCode &&
                  (r.status == 'invited' || r.status == 'waiting_expert'))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text.rich(TextSpan(children: [
                const TextSpan(
                    text: 'Main Divers: ',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: team.mainDiversText),
              ])),
              for (final request in open)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      'Site partner: ${request.candidateName} · ${request.statusLabel}',
                      style: const TextStyle(color: kPrimaryTeal)),
                ),
              if (team.canLeave) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _busy ? null : () => _leave(team),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Leave site'),
                ),
              ],
              if (team.canInvite && open.every((r) => !r.wasInvited)) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _add(team),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Add site partner'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                ),
              ],
            ],
          );
        },
      );
}

/// Site partner invitations sent to the signed-in Diver, with Accept and
/// Decline.
class SitePartnerInvitesCard extends StatefulWidget {
  const SitePartnerInvitesCard({
    super.key,
    this.api = const SitePartnerApi(),
    this.onChanged,
  });

  final SitePartnerApi api;
  final VoidCallback? onChanged;

  @override
  State<SitePartnerInvitesCard> createState() => _SitePartnerInvitesCardState();
}

class _SitePartnerInvitesCardState extends State<SitePartnerInvitesCard> {
  late Future<List<SitePartnerRequest>> _requests = widget.api.requests();
  bool _busy = false;

  Future<void> _answer(SitePartnerRequest invite,
      {required bool accept}) async {
    final ok = accept
        ? await _confirm(
            context,
            'Accept the invitation?',
            'If the Expert approves, you will be the site partner of '
                '${invite.areaName} together with ${invite.invitedByName ?? invite.mainDiverName}. '
                'Your records there will no longer wait for the Expert.',
            'Accept')
        : await _confirm(
            context,
            'Decline the invitation?',
            '${invite.invitedByName ?? invite.mainDiverName} will be told.',
            'Decline');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.respond(invite.id, accept: accept);
      if (mounted) {
        _snack(
            context,
            accept
                ? 'Accepted. The Expert will now approve or decline.'
                : 'Invitation declined.');
      }
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) _snack(context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _requests = widget.api.requests();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<SitePartnerRequest>>(
        future: _requests,
        builder: (context, snapshot) {
          final invites = (snapshot.data ?? const <SitePartnerRequest>[])
              .where((r) => r.canRespond)
              .toList();
          if (invites.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final invite in invites)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Site partner invitation',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: kTextNavy)),
                        const SizedBox(height: 6),
                        Text(
                            '${invite.invitedByName ?? invite.mainDiverName} invited you to '
                            'be the site partner of ${invite.areaName}.'),
                        const SizedBox(height: 4),
                        const Text(
                            'If you accept, the Expert approves or declines.',
                            style: TextStyle(color: kPrimaryTeal)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _answer(invite, accept: false),
                                child: const Text('Decline')),
                            const SizedBox(width: 8),
                            FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _answer(invite, accept: true),
                                child: const Text('Accept')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}
