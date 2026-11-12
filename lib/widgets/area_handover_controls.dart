import 'package:flutter/material.dart';

import '../core/cots_colors.dart';
import '../models/area_handover.dart';
import '../models/follow_up_monitoring_model.dart';
import '../services/supabase_handover_service.dart';

/// Stage 4 (claude/agreed_workflow_decisions.md): hand over this area.

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

Widget _line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: value),
      ])),
    );

/// The main Diver's "Hand over this area" button, or the open handover's
/// status (with Cancel while nobody has accepted).
class AreaHandoverButton extends StatefulWidget {
  const AreaHandoverButton({
    super.key,
    required this.assignment,
    this.api = const AreaHandoverApi(),
  });

  final FollowUpAssignmentModel assignment;
  final AreaHandoverApi api;

  @override
  State<AreaHandoverButton> createState() => _AreaHandoverButtonState();
}

class _AreaHandoverButtonState extends State<AreaHandoverButton> {
  late Future<List<AreaHandover>> _handovers = widget.api.list();
  bool _busy = false;

  void _reload() {
    setState(() {
      _handovers = widget.api.list();
    });
  }

  Future<void> _ask() async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _HandoverRequestDialog(
          assignment: widget.assignment, api: widget.api),
    );
    if (!mounted || sent != true) return;
    final partner = widget.assignment.partnerName;
    _snack(
        context,
        partner.isNotEmpty
            ? '$partner is now Main Diver 1 of ${widget.assignment.areaName}.'
            : 'Handover requested. The Expert will choose a new Diver.');
    _reload();
  }

  Future<void> _cancel(AreaHandover handover) async {
    if (!await _confirm(
        context,
        'Cancel handover?',
        'You will stay the main Diver for ${handover.areaName}.',
        'Cancel handover')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.api.cancel(handover.id);
      if (mounted) _snack(context, 'Handover cancelled.');
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
  Widget build(BuildContext context) => FutureBuilder<List<AreaHandover>>(
        future: _handovers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
                onPressed: _reload,
                child: const Text('Could not load handover. Retry'));
          }
          if (!snapshot.hasData) return const SizedBox.shrink();
          final open = snapshot.data!
              .where((h) => h.areaCode == widget.assignment.areaId && h.isOpen);
          if (open.isNotEmpty) {
            final handover = open.first;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPrimaryTeal.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimaryTeal.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Handover of this area',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: kTextNavy)),
                  Text(handover.statusLabel),
                  _line('Reason', handover.reason),
                  if (handover.canCancel)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: _busy ? null : () => _cancel(handover),
                          child: const Text('Cancel handover')),
                    ),
                ],
              ),
            );
          }
          return OutlinedButton.icon(
            onPressed: _busy ? null : _ask,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Hand over this site'),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
          );
        },
      );
}

class _HandoverRequestDialog extends StatefulWidget {
  const _HandoverRequestDialog({required this.assignment, required this.api});
  final FollowUpAssignmentModel assignment;
  final AreaHandoverApi api;

  @override
  State<_HandoverRequestDialog> createState() => _HandoverRequestDialogState();
}

class _HandoverRequestDialogState extends State<_HandoverRequestDialog> {
  final _reason = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Give a reason for the handover.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api
          .request(widget.assignment.areaId, _reason.text, _note.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = _errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Hand over this site'),
        scrollable: true,
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.assignment.partnerName.isNotEmpty
                  // Stage 11: the site partner takes over at once.
                  ? 'Your site partner ${widget.assignment.partnerName} becomes '
                      'Main Diver 1 of ${widget.assignment.areaName} right away. '
                      'The Expert is told. Your past records stay under your name.'
                  : 'The Expert will choose a new Diver for ${widget.assignment.areaName}. '
                      'You stay the main Diver until the new Diver accepts. '
                      'Your past records stay under your name.'),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('handover-reason'),
                controller: _reason,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('handover-note'),
                controller: _note,
                maxLength: 2000,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Note for the next Diver (optional)',
                    hintText: 'For example, how to reach the reef',
                    border: OutlineInputBorder()),
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: kDangerRed)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('Back')),
          FilledButton(
              onPressed: _busy ? null : _send,
              child: const Text('Send request')),
        ],
      );
}

/// Handover offers made to the signed-in Diver, with Accept and Decline.
class HandoverOffersCard extends StatefulWidget {
  const HandoverOffersCard({
    super.key,
    this.api = const AreaHandoverApi(),
    this.onChanged,
  });

  final AreaHandoverApi api;
  final VoidCallback? onChanged;

  @override
  State<HandoverOffersCard> createState() => _HandoverOffersCardState();
}

class _HandoverOffersCardState extends State<HandoverOffersCard> {
  late Future<List<AreaHandover>> _handovers = widget.api.list();
  bool _busy = false;

  Future<void> _answer(AreaHandover offer, {required bool accept}) async {
    final ok = accept
        ? await _confirm(
            context,
            'Accept the handover?',
            'You will become the main Diver for ${offer.areaName} and do its '
                'monthly visits from now on.',
            'Accept')
        : await _confirm(context, 'Decline the handover?',
            'The Expert will choose another Diver.', 'Decline');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.api.respond(offer.offerId!, accept: accept);
      if (mounted) {
        _snack(
            context,
            accept
                ? 'You are now the main Diver for ${offer.areaName}.'
                : 'Handover declined.');
      }
      widget.onChanged?.call();
    } catch (error) {
      if (mounted) _snack(context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _handovers = widget.api.list();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<AreaHandover>>(
        future: _handovers,
        builder: (context, snapshot) {
          final offers = (snapshot.data ?? const <AreaHandover>[])
              .where((h) => h.canRespond && h.offerId != null)
              .toList();
          if (offers.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final offer in offers)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Area handover offer',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: kTextNavy)),
                        const SizedBox(height: 6),
                        Text(
                            '${offer.fromDiverName} is handing over ${offer.areaName}.'),
                        _line('Reason', offer.reason),
                        if (offer.note.isNotEmpty) _line('Note', offer.note),
                        if (offer.monthNote != null) ...[
                          const SizedBox(height: 8),
                          Text(offer.monthNote!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: kPrimaryTeal)),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _answer(offer, accept: false),
                                child: const Text('Decline')),
                            const SizedBox(width: 8),
                            FilledButton(
                                onPressed: _busy
                                    ? null
                                    : () => _answer(offer, accept: true),
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

/// The Expert's handovers: open handovers (choose a Diver, cancel) and areas
/// with 5 or more missed months (start a handover).
class ExpertHandoversSection extends StatefulWidget {
  const ExpertHandoversSection({super.key, this.api = const AreaHandoverApi()});

  final AreaHandoverApi api;

  @override
  State<ExpertHandoversSection> createState() => _ExpertHandoversSectionState();
}

class _ExpertHandoversSectionState extends State<ExpertHandoversSection> {
  late Future<(List<AreaHandover>, List<AreaMissedMonths>)> _data = _load();
  bool _busy = false;

  Future<(List<AreaHandover>, List<AreaMissedMonths>)> _load() async =>
      (await widget.api.list(), await widget.api.missedMonths());

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _snack(context, done);
    } catch (error) {
      if (mounted) _snack(context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _data = _load();
        });
      }
    }
  }

  Future<void> _chooseDiver(AreaHandover handover) async {
    final directory = await widget.api.directory();
    if (!mounted) return;
    final candidates = directory
        .where((p) => p['uid'] != handover.fromDiverUid)
        .toList()
      ..sort((a, b) =>
          (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('New Diver for ${handover.areaName}'),
        children: [
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                  'Choose a verified Diver. They become the main Diver only after they accept.')),
          if (candidates.isEmpty)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No verified Divers are available.')),
          for (final person in candidates)
            SimpleDialogOption(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                onPressed: () => Navigator.pop(dialogContext, person),
                child: Text(person['name'] as String? ?? '')),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Back')),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    if (!await _confirm(context, 'Send the handover offer?',
        'Offer ${handover.areaName} to ${selected['name']}?', 'Send offer')) {
      return;
    }
    await _run(() => widget.api.offer(handover.id, selected['uid'] as String),
        'Offer sent to ${selected['name']}.');
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<(List<AreaHandover>, List<AreaMissedMonths>)>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return TextButton(
                onPressed: () => setState(() {
                      _data = _load();
                    }),
                child: const Text('Could not load site handovers. Retry'));
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final open = snapshot.data!.$1.where((h) => h.isOpen).toList();
          final missed =
              snapshot.data!.$2.where((a) => a.canStartHandover).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Text('Site handovers',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: kTextNavy)),
              if (open.isEmpty && missed.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No site handovers need attention.')),
              for (final handover in open)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(handover.areaName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        _line('From', handover.fromDiverName),
                        _line(
                            'Started by',
                            handover.startedByExpert
                                ? 'The Expert (5 or more missed months)'
                                : 'The Diver'),
                        _line('Reason', handover.reason),
                        if (handover.note.isNotEmpty)
                          _line('Note for the next Diver', handover.note),
                        const SizedBox(height: 6),
                        Text(handover.statusLabel,
                            style: const TextStyle(color: kPrimaryTeal)),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          children: [
                            if (handover.canCancel)
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          if (await _confirm(
                                              context,
                                              'Cancel handover?',
                                              '${handover.fromDiverName} stays the main Diver.',
                                              'Cancel handover')) {
                                            await _run(
                                                () => widget.api
                                                    .cancel(handover.id),
                                                'Handover cancelled.');
                                          }
                                        },
                                  child: const Text('Cancel handover')),
                            if (handover.canOffer)
                              FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _chooseDiver(handover),
                                  child: const Text('Choose a Diver')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (missed.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Sites with 5 or more missed months',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                for (final area in missed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(area.areaName),
                    subtitle: Text(
                        'Main Diver: ${area.mainDiverName} · ${area.missedMonths} months missed in a row'),
                    trailing: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await _confirm(
                                  context,
                                  'Start a handover?',
                                  '${area.areaName} has had no monthly visit for '
                                      '${area.missedMonths} months in a row. You will then choose a new Diver.',
                                  'Start handover')) {
                                await _run(
                                    () => widget.api.start(area.areaCode),
                                    'Handover started. Choose a new Diver.');
                              }
                            },
                      child: const Text('Start handover'),
                    ),
                  ),
              ],
              const Divider(height: 32),
            ],
          );
        },
      );
}
