import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/davao_gulf_geography.dart';
import '../../providers/auth_provider.dart';
import '../../services/follow_up_monitoring_repository.dart';
import '../../services/offline_submission_service.dart';
import '../../services/zone_assignment_service.dart';

class NoCotsSurveyPage extends StatefulWidget {
  const NoCotsSurveyPage({super.key, this.siteCode});
  final String? siteCode;
  @override
  State<NoCotsSurveyPage> createState() => _NoCotsSurveyPageState();
}

class _NoCotsSurveyPageState extends State<NoCotsSurveyPage> {
  final _form = GlobalKey<FormState>();
  final _area = TextEditingController();
  final _notes = TextEditingController();
  final _id = FollowUpMonitoringRepository.newSurveyId();
  Position? _position;
  String? _site;
  String? _error;
  bool _confirmed = false, _busy = false;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await DavaoGulfGeography.load();
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on phone location and try again.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission is required for a survey.');
      }
      final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 30)));
      final site = ZoneAssignmentService.resolveMonitoringArea(
              latitude: position.latitude, longitude: position.longitude)
          ?.barangay
          .areaCode;
      if (site == null ||
          (widget.siteCode != null && site != widget.siteCode)) {
        throw StateError('Your phone must be at the selected monitoring site.');
      }
      if (mounted) {
        setState(() {
          _position = position;
          _site = site;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _position = null;
          _site = null;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy ||
        !_form.currentState!.validate() ||
        !_confirmed ||
        _position == null ||
        _site == null) {
      return;
    }
    final user = context.read<AuthProvider>().userModel;
    if (user == null) return;
    final position = _position!;
    if (DateTime.now().difference(position.timestamp).abs() >
        const Duration(minutes: 5)) {
      setState(() => _error = 'Refresh phone location before submitting.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final pending = await context
          .read<OfflineSubmissionService>()
          .submitNoCotsSurvey(uid: user.uid, id: _id, params: {
        'p_id': _id,
        'p_area_code': _site,
        'p_kind': widget.siteCode == null ? 'initial' : 'monthly',
        'p_surveyed_at': position.timestamp.toUtc().toIso8601String(),
        'p_latitude': position.latitude,
        'p_longitude': position.longitude,
        'p_gps_at': position.timestamp.toUtc().toIso8601String(),
        'p_accuracy': position.accuracy,
        'p_area_m2': double.parse(_area.text.trim()),
        'p_notes': _notes.text.trim(),
        'p_confirmed': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(pending
              ? 'Survey saved on this device, pending synchronization.'
              : 'Diver-reported survey submitted.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _area.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('No COTS observed')),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              const Text('No COTS observed during this survey',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text(
                  'Diver-reported observation. No photo or AI detection is required. This completes this month’s visit without changing existing COTS totals or site assignments.'),
              const SizedBox(height: 8),
              const Text(
                  'Only one no-COTS survey is allowed per site each month, before any COTS report. COTS photos can still be submitted if COTS are found afterward.'),
              const SizedBox(height: 20),
              Text(
                  'Site: ${_site == null ? "Waiting for phone GPS" : DavaoGulfGeography.barangayById(_site!)?.displayName ?? _site}'),
              if (_position != null) ...[
                Text(
                    'Survey time: ${DateFormat('MMM d, yyyy h:mm a').format(_position!.timestamp.toLocal())}'),
                Text(
                    'Phone GPS: ${_position!.latitude.toStringAsFixed(6)}, ${_position!.longitude.toStringAsFixed(6)}'),
                Text('Accuracy: ±${_position!.accuracy.round()} m'),
              ],
              TextButton.icon(
                  onPressed: _busy ? null : _locate,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Refresh phone location')),
              TextFormField(
                  controller: _area,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'Surveyed area (m²)'),
                  validator: (value) {
                    final area = double.tryParse(value?.trim() ?? '');
                    return area == null || !area.isFinite || area <= 0
                        ? 'Enter a positive surveyed area.'
                        : null;
                  }),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration:
                      const InputDecoration(labelText: 'Remarks (optional)')),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmed,
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _confirmed = value ?? false),
                  title: const Text(
                      'I surveyed this site and did not observe any COTS.')),
              if (_error != null)
                Text(_error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _busy || !_confirmed || _position == null
                      ? null
                      : _submit,
                  child: Text(_busy ? 'Please wait…' : 'Submit survey')),
            ])),
      );
}
