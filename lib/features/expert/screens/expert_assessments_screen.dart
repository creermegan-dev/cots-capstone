import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/supabase_config.dart';
import '../../../models/cots_density.dart';
import '../../../models/follow_up_monitoring_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_follow_up_service.dart';
import '../../admin/theme/admin_theme.dart';

typedef ConfirmAssessment = Future<void> Function({
  required String surveyId,
  required String level,
  String reason,
});

/// Expert: confirm the infestation level the system calculated for each
/// completed follow-up visit, or record another level with a reason.
class ExpertAssessmentsScreen extends StatefulWidget {
  const ExpertAssessmentsScreen({super.key, this.loadVisits, this.confirm});

  final Future<List<FollowUpSurveyModel>> Function()? loadVisits;
  final ConfirmAssessment? confirm;

  @override
  State<ExpertAssessmentsScreen> createState() =>
      _ExpertAssessmentsScreenState();
}

class _ExpertAssessmentsScreenState extends State<ExpertAssessmentsScreen> {
  static final _dateFormat = DateFormat('MMM d, yyyy');
  late Future<List<FollowUpSurveyModel>> _visits;
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _visits = _load();
  }

  Future<List<FollowUpSurveyModel>> _load() {
    final loader = widget.loadVisits;
    if (loader != null) return loader();
    if (!SupabaseConfig.isConfigured) {
      return Future.error(StateError(
          'Assessments are available in the Supabase version of the app.'));
    }
    return SupabaseFollowUpService.visitsToAssess();
  }

  void _refresh() {
    setState(() {
      _visits = _load();
    });
  }

  Future<void> _save(FollowUpSurveyModel visit, String level,
      [String reason = '']) async {
    setState(() => _savingId = visit.id);
    try {
      final confirm =
          widget.confirm ?? SupabaseFollowUpService.confirmAssessment;
      await confirm(surveyId: visit.id, level: level, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Level saved: $level.')));
      _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Could not save the level: ${AuthService.messageFor(error)}')));
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _chooseLevel(FollowUpSurveyModel visit) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _ChooseLevelDialog(calculated: visit.calculatedLevel),
    );
    if (result == null || !mounted) return;
    await _save(visit, result.$1, result.$2);
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
                child: Text('Infestation Assessments',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.headerTitle))),
            IconButton(
                onPressed: _refresh,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh)),
          ]),
          const Text(
              'Completed follow-up visits. The system calculates the level from '
              'COTS density (Dumas et al., 2020): Low below 15, Moderate 15–100, '
              'High above 100 COTS per hectare. Confirm it, or choose another '
              'level with a reason.'),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<FollowUpSurveyModel>>(
              future: _visits,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        'Could not load visits: ${AuthService.messageFor(snapshot.error!)}',
                        textAlign: TextAlign.center),
                    TextButton(onPressed: _refresh, child: const Text('Retry')),
                  ]));
                }
                final visits = snapshot.data!;
                if (visits.isEmpty) {
                  return const Center(
                      child: Text('No completed visits are waiting for an assessment.'));
                }
                return ListView.separated(
                  itemCount: visits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final visit = visits[index];
                    final calculated = visit.calculatedLevel;
                    final busy = _savingId == visit.id;
                    return Card(
                      color: AdminColors.cardWhite,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('${visit.areaName} · ${visit.barangay}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(
                                '${_dateFormat.format(visit.surveyDate)} · ${visit.submittedBy}'),
                            const SizedBox(height: 8),
                            Text(
                                '${followUpCountSummary(visit)}\n'
                                'Surveyed area: ${visit.surveyedAreaSquareMeters == null ? 'Not recorded' : '${visit.surveyedAreaSquareMeters!.toStringAsFixed(2)} m²'}\n'
                                'Density: ${CotsDensity.describe(visit.densityPerHectare, calculated)}'),
                            if (calculated != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                    'Calculated level: ${CotsDensity.outbreakLabel(calculated)}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: calculated == 'High'
                                            ? AdminColors.statRed
                                            : AdminColors.headerTitle)),
                              ),
                            const SizedBox(height: 12),
                            if (busy) const LinearProgressIndicator(),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              if (calculated != null)
                                FilledButton(
                                    onPressed: busy || _savingId != null
                                        ? null
                                        : () => _save(visit, calculated),
                                    child: Text('Confirm $calculated')),
                              OutlinedButton(
                                  onPressed: busy || _savingId != null
                                      ? null
                                      : () => _chooseLevel(visit),
                                  child: const Text('Choose another level')),
                            ]),
                          ],
                        ),
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

class _ChooseLevelDialog extends StatefulWidget {
  const _ChooseLevelDialog({required this.calculated});
  final String? calculated;

  @override
  State<_ChooseLevelDialog> createState() => _ChooseLevelDialogState();
}

class _ChooseLevelDialogState extends State<_ChooseLevelDialog> {
  final _reason = TextEditingController();
  late String _level = widget.calculated ?? 'Moderate';
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (_level != widget.calculated && reason.isEmpty) {
      setState(() => _error =
          'Give a reason when the level differs from the calculated level.');
      return;
    }
    Navigator.pop(context, (_level, reason));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Choose infestation level'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final level in CotsDensity.levels)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_level == level
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: Text(CotsDensity.outbreakLabel(level)),
                subtitle:
                    level == widget.calculated ? const Text('Calculated') : null,
                onTap: () => setState(() {
                  _level = level;
                  _error = null;
                }),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 5,
              maxLength: 2000,
              decoration: const InputDecoration(
                  labelText: 'Reason',
                  helperText: 'Required when you change the calculated level.',
                  border: OutlineInputBorder()),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AdminColors.statRed)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: _submit, child: const Text('Save level')),
        ],
      );
}
