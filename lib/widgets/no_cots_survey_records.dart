import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/supabase_config.dart';
import '../services/no_cots_survey_service.dart';

typedef NoCotsSurveyLoader = Future<List<Map<String, dynamic>>> Function(
    {required bool mineOnly});

/// Read-only survey entries alongside existing records, never approval controls.
class NoCotsSurveyRecords extends StatefulWidget {
  const NoCotsSurveyRecords(
      {super.key,
      this.mineOnly = true,
      this.onLoaded,
      this.renderEntries = true,
      this.areaCode,
      this.searchText = '',
      this.loader,
      this.visible = true});
  final NoCotsSurveyLoader? loader;
  final bool mineOnly;
  final String? areaCode;
  final String searchText;
  final bool visible;
  final bool renderEntries;
  final ValueChanged<List<Map<String, dynamic>>>? onLoaded;
  @override
  State<NoCotsSurveyRecords> createState() => _NoCotsSurveyRecordsState();
}

class _NoCotsSurveyRecordsState extends State<NoCotsSurveyRecords> {
  List<Map<String, dynamic>>? _rows;
  bool _loading = false;
  bool _failed = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (SupabaseConfig.isConfigured || widget.loader != null) {
      _reload();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _reload());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final rows = await (widget.loader ?? NoCotsSurveyService.load)(
          mineOnly: widget.mineOnly);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _failed = false;
      });
      widget.onLoaded?.call(rows);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_failed)
        ListTile(
            title: const Text('Survey records unavailable'),
            trailing:
                TextButton(onPressed: _reload, child: const Text('Retry'))),
      if (_rows == null && _loading) const LinearProgressIndicator(),
      if (widget.renderEntries && widget.visible && _rows != null)
        for (final row in _rows!.where((row) =>
            (widget.areaCode == null ||
                row['area_code'] == widget.areaCode ||
                row['area_name'] == widget.areaCode) &&
            '${row['area_name']} ${row['submitted_by']} No COTS observed'
                .toLowerCase()
                .contains(widget.searchText.trim().toLowerCase())))
          Card(
              child: ListTile(
            leading: const Icon(Icons.fact_check_outlined),
            title: Text(
                '${row['area_name']} · ${NoCotsSurveyService.observation(row)}'),
            subtitle: Text('Diver-reported · ${_time(row['surveyed_at'])}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showNoCotsSurveyDetails(context, row),
          )),
    ]);
  }

  static String _time(dynamic value) {
    final time = DateTime.tryParse(value?.toString() ?? '');
    return time == null
        ? 'Unknown'
        : '${DateFormat('MMM d, yyyy h:mm a').format(time.toUtc().add(const Duration(hours: 8)))} (Manila)';
  }
}

Future<void> showNoCotsSurveyDetails(
        BuildContext context, Map<String, dynamic> row) =>
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Survey details'),
              content: SingleChildScrollView(
                  child: Text(
                      '${NoCotsSurveyService.observation(row)}\nDiver-reported — no Expert approval required\n\n'
                      'Site: ${row['area_name']}\nSubmitted by: ${row['submitted_by']}\n'
                      'Survey time: ${_NoCotsSurveyRecordsState._time(row['surveyed_at'])}\n'
                      'Uploaded: ${_NoCotsSurveyRecordsState._time(row['submitted_at'])}\n'
                      'Phone GPS: ${row['latitude']}, ${row['longitude']}\n'
                      'Accuracy: ±${row['gps_accuracy_m']} m\n'
                      'Surveyed area: ${row['surveyed_area_m2']} m²\n'
                      'Remarks: ${row['notes']}\n\n'
                      'This visit counts for its survey month. Existing COTS totals and site assignments are unchanged.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
