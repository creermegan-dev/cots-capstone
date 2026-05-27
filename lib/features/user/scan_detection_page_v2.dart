import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:exif/exif.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../models/activity_type.dart';
import '../../models/cots_detection_result.dart';
import '../../providers/auth_provider.dart';
import '../../services/cots_size_estimator.dart';
import '../../services/cots_yolo_detector.dart';
import '../../services/gps_exif_parser.dart';
import '../../services/scan_record_service.dart';
import '../../services/zone_assignment_service.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

const _maxImageBytes = 20 * 1024 * 1024;
const _allowedExtensions = {'.jpg', '.jpeg', '.png'};

enum _DetectionStep { upload, details, review }

class ScanDetectionPage extends StatefulWidget {
  const ScanDetectionPage({super.key});

  @override
  State<ScanDetectionPage> createState() => _ScanDetectionPageState();
}

class _ScanDetectionPageState extends State<ScanDetectionPage> {
  static final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _depthController = TextEditingController();
  final _removedQtyController = TextEditingController();
  final _envNotesController = TextEditingController();

  _DetectionStep _step = _DetectionStep.upload;
  XFile? _imageFile;
  Uint8List? _imageBytes;
  String? _fileName;
  DateTime? _dateTaken;
  double? _latitude;
  double? _longitude;
  int? _widthPx;
  int? _heightPx;
  String _activityType = CotsActivityType.detectionOnly;
  bool? _measurementReferenceVisible;
  String? _removalMethod;
  CotsDetectionResult? _detection;
  CotsSizeEstimate? _sizeEstimate;
  bool _isBusy = false;
  bool _showValidation = false;

  @override
  void dispose() {
    _notesController.dispose();
    _depthController.dispose();
    _removedQtyController.dispose();
    _envNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: AppBackIconButton(
          onPressed: _onBack,
          iconColor: kTextNavy,
        ),
        title: Text(
          _stepTitle,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.scan,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _stepIndicator(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: switch (_step) {
                    _DetectionStep.upload => _buildUploadStep(),
                    _DetectionStep.details => _buildDetailsStep(),
                    _DetectionStep.review => _buildReviewStep(),
                  },
                ),
              ),
              _bottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  String get _stepTitle {
    return switch (_step) {
      _DetectionStep.upload => 'New Detection',
      _DetectionStep.details => 'Details',
      _DetectionStep.review => 'Review',
    };
  }

  void _onBack() {
    if (_step == _DetectionStep.upload) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _step = _step == _DetectionStep.review
          ? _DetectionStep.details
          : _DetectionStep.upload;
    });
  }

  Widget _stepIndicator() {
    final steps = ['Upload', 'Details', 'Review'];
    final index = _step.index;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= index ? kPrimaryTeal : kBorderGray,
                ),
              ),
            _StepDot(
              label: steps[i],
              active: i == index,
              done: i < index,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadStep() {
    final zone = ZoneAssignmentService.assignZone(
      latitude: _latitude,
      longitude: _longitude,
    );
    final when = _dateTaken ?? DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload GoPro Underwater Image',
                style: TextStyle(
                  color: kTextNavy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'JPG, JPEG, or PNG only · max 20 MB · image only (no video)',
                style: TextStyle(color: kMutedGray, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _pickImage,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text(_imageFile == null ? 'Choose Image' : 'Change Image'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryTeal,
                  side: const BorderSide(color: kPrimaryTeal, width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              if (_imageBytes != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                  ),
                ),
                if (_fileName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _fileName!,
                      style: const TextStyle(color: kMutedGray, fontSize: 12),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Activity Type',
                style: TextStyle(
                  color: kTextNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              _activityTile(
                CotsActivityType.detectionOnly,
                'Detection Only',
                'Observed COTS but did not remove.',
                Icons.visibility_outlined,
              ),
              const SizedBox(height: 8),
              _activityTile(
                CotsActivityType.removalActivity,
                'Removal Activity',
                'Removed one or more COTS underwater.',
                Icons.cleaning_services_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notes',
                style: TextStyle(
                  color: kTextNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: _inputDecoration('Optional field notes'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Auto Capture',
                style: TextStyle(
                  color: kPrimaryTeal,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              _autoRow(
                Icons.location_on_outlined,
                'Location',
                ZoneAssignmentService.formatCoordinates(_latitude, _longitude),
              ),
              _autoRow(Icons.map_outlined, 'Zone', zone),
              _autoRow(
                Icons.calendar_today_outlined,
                'Date',
                DateFormat('MMM dd, yyyy').format(when),
              ),
              _autoRow(
                Icons.access_time_rounded,
                'Time',
                DateFormat('h:mm a').format(when),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsStep() {
    final isRemoval = CotsActivityType.isRemoval(_activityType);
    final count = _detection?.count ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_detection != null)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Analysis',
                  style: TextStyle(
                    color: kPrimaryTeal,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Detected: $count COTS',
                  style: const TextStyle(
                    color: kTextNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI Count: $count'
                  '${_detection!.confidence > 0 ? ' (${(_detection!.confidence * 100).toStringAsFixed(0)}% confidence)' : ''}',
                  style: const TextStyle(color: kMutedGray, fontSize: 13),
                ),
                if (_sizeEstimate != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Estimated sizes: ${_sizeEstimate!.perCotsCm.map((s) => '${s.toStringAsFixed(0)} cm').join(', ')}',
                    style: const TextStyle(color: kDarkTeal, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 14),
        if (!isRemoval) ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Environmental Observations',
                  style: TextStyle(
                    color: kTextNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _envNotesController,
                  maxLines: 3,
                  decoration: _inputDecoration('Visibility, substrate, currents…'),
                ),
              ],
            ),
          ),
        ] else ...[
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Removed Quantity',
                  style: TextStyle(
                    color: kTextNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'AI suggested quantity — you may correct before submit.',
                  style: TextStyle(color: kMutedGray, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _removedQtyController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autovalidateMode: _showValidation
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  validator: (v) {
                    if (!isRemoval) return null;
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Enter removed quantity.';
                    return null;
                  },
                  decoration: _inputDecoration('Removed quantity'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Measurement Reference Visible?',
                  style: TextStyle(
                    color: kTextNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Removal tool, measuring stick, or calibration marker in frame.',
                  style: TextStyle(color: kMutedGray, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('Yes'),
                        value: true,
                        groupValue: _measurementReferenceVisible,
                        activeColor: kPrimaryTeal,
                        onChanged: (v) => setState(() {
                          _measurementReferenceVisible = v;
                          _recomputeSizeEstimate();
                        }),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        title: const Text('No'),
                        value: false,
                        groupValue: _measurementReferenceVisible,
                        activeColor: kPrimaryTeal,
                        onChanged: (v) => setState(() {
                          _measurementReferenceVisible = v;
                          _sizeEstimate = null;
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Removal Method',
                  style: TextStyle(
                    color: kTextNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _removalMethod,
                  decoration: _inputDecoration('Select method'),
                  items: RemovalMethod.options
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text(m)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _removalMethod = v),
                  validator: (v) {
                    if (!isRemoval || !_showValidation) return null;
                    if (v == null || v.isEmpty) return 'Select removal method.';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isRemoval ? 'Depth (optional)' : 'Depth',
                style: const TextStyle(
                  color: kTextNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _depthController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
                autovalidateMode: _showValidation
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                validator: (value) {
                  if (isRemoval) return null;
                  final raw = (value ?? '').trim();
                  if (raw.isEmpty) return 'Please enter capture depth.';
                  final depth = double.tryParse(raw);
                  if (depth == null) return 'Please enter capture depth.';
                  if (depth < 0 || depth > 100) {
                    return 'Depth must be between 0 and 100 m.';
                  }
                  return null;
                },
                decoration: _inputDecoration('Depth in meters').copyWith(
                  suffixText: 'm',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final isRemoval = CotsActivityType.isRemoval(_activityType);
    final removed = int.tryParse(_removedQtyController.text.trim());
    final depth = double.tryParse(_depthController.text.trim());
    final zone = ZoneAssignmentService.assignZone(
      latitude: _latitude,
      longitude: _longitude,
    );
    final when = _dateTaken ?? DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.memory(_imageBytes!, fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: 14),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _reviewRow('Activity Type', CotsActivityType.label(_activityType)),
              _reviewRow('AI Count', '${_detection?.count ?? 0}'),
              if (isRemoval)
                _reviewRow('Removed Quantity', '${removed ?? '--'}'),
              if (_sizeEstimate != null) ...[
                _reviewRow(
                  'Average Size',
                  '${_sizeEstimate!.averageCm.toStringAsFixed(0)} cm',
                ),
                _reviewRow(
                  'Estimated Sizes',
                  _sizeEstimate!.perCotsCm
                      .map((s) => '${s.toStringAsFixed(0)} cm')
                      .join(', '),
                ),
              ],
              _reviewRow('GPS', ZoneAssignmentService.formatCoordinates(_latitude, _longitude)),
              _reviewRow('Zone', zone),
              _reviewRow('Date', DateFormat('MMM dd, yyyy').format(when)),
              _reviewRow('Time', DateFormat('h:mm a').format(when)),
              if (depth != null) _reviewRow('Depth', '${depth.toStringAsFixed(1)} m'),
              if (_notesController.text.trim().isNotEmpty)
                _reviewRow('Notes', _notesController.text.trim()),
              _reviewRow('Capture Source', CaptureSource.goProUnderwaterImage),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton(
          onPressed: _isBusy ? null : _onPrimaryAction,
          style: FilledButton.styleFrom(
            backgroundColor: kPrimaryTeal,
            disabledBackgroundColor: kPrimaryTeal.withValues(alpha: 0.35),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isBusy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  switch (_step) {
                    _DetectionStep.upload => 'Next → Details',
                    _DetectionStep.details => 'Next → Review',
                    _DetectionStep.review => 'Submit Record',
                  },
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  Future<void> _onPrimaryAction() async {
    switch (_step) {
      case _DetectionStep.upload:
        await _goToDetails();
      case _DetectionStep.details:
        await _goToReview();
      case _DetectionStep.review:
        await _submitRecord();
    }
  }

  Future<void> _goToDetails() async {
    if (_imageFile == null || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a GoPro underwater image.')),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final bytes = _imageBytes!;
      _detection = await CotsYoloDetector.instance.detect(bytes);
      if (CotsActivityType.isRemoval(_activityType)) {
        _removedQtyController.text = '${_detection!.count}';
      }
      setState(() => _step = _DetectionStep.details);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI analysis failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _goToReview() async {
    setState(() => _showValidation = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (CotsActivityType.isRemoval(_activityType) &&
        _measurementReferenceVisible == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Indicate whether a measurement reference is visible.'),
        ),
      );
      return;
    }
    _recomputeSizeEstimate();
    setState(() => _step = _DetectionStep.review);
  }

  void _recomputeSizeEstimate() {
    if (_measurementReferenceVisible != true ||
        _detection == null ||
        _widthPx == null ||
        _heightPx == null) {
      _sizeEstimate = null;
      return;
    }
    _sizeEstimate = CotsSizeEstimator.estimate(
      boxes: _detection!.boxes,
      imageWidth: _widthPx!,
      imageHeight: _heightPx!,
    );
  }

  Future<void> _submitRecord() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a record.')),
      );
      return;
    }

    setState(() => _isBusy = true);
    try {
      final depth = double.tryParse(_depthController.text.trim());
      final removed = CotsActivityType.isRemoval(_activityType)
          ? int.tryParse(_removedQtyController.text.trim())
          : null;

      await ScanRecordService.submit(
        uid: uid,
        submittedBy: user.fullName,
        imageName: _fileName ?? 'gopro_image.jpg',
        imagePath: _imageFile!.path,
        activityType: _activityType,
        detection: _detection!,
        latitude: _latitude,
        longitude: _longitude,
        dateTaken: _dateTaken,
        imageWidth: _widthPx,
        imageHeight: _heightPx,
        notes: [
          _notesController.text.trim(),
          if (_envNotesController.text.trim().isNotEmpty)
            _envNotesController.text.trim(),
        ].where((s) => s.isNotEmpty).join('\n'),
        depth: depth,
        confirmedRemovedQuantity: removed,
        measurementReferenceVisible: _measurementReferenceVisible,
        removalMethod: _removalMethod,
        sizeEstimate: _sizeEstimate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Citizen science record submitted successfully.'),
          backgroundColor: kPrimaryTeal,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return;

    final ext = _extension(picked.path);
    if (!_allowedExtensions.contains(ext)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only JPG, JPEG, and PNG images are supported.'),
        ),
      );
      return;
    }

    final bytes = await picked.readAsBytes();
    if (bytes.length > _maxImageBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image must be 20 MB or smaller.')),
      );
      return;
    }

    setState(() {
      _imageFile = picked;
      _imageBytes = bytes;
      _fileName = picked.path.split(RegExp(r'[\\/]')).last;
      _detection = null;
      _sizeEstimate = null;
    });

    await _loadMetadata(bytes);
    if (mounted) setState(() {});
  }

  String _extension(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0) return '';
    return path.substring(i).toLowerCase();
  }

  Future<void> _loadMetadata(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _widthPx = frame.image.width;
      _heightPx = frame.image.height;
      frame.image.dispose();
    } catch (_) {}

    try {
      final exif = await readExifFromBytes(bytes);
      final rawDate = exif['EXIF DateTimeOriginal']?.printable ??
          exif['Image DateTime']?.printable;
      if (rawDate != null && rawDate.isNotEmpty) {
        _dateTaken = DateFormat('yyyy:MM:dd HH:mm:ss').parse(rawDate);
      }
      final gps = GpsExifParser.parse(exif);
      if (gps != null) {
        _latitude = gps.$1;
        _longitude = gps.$2;
      }
    } catch (_) {}

    if (_latitude == null || _longitude == null) {
      try {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      } catch (_) {}
    }
  }

  Widget _activityTile(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _activityType == value;
    return InkWell(
      onTap: () => setState(() => _activityType = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kPrimaryTeal : kBorderGray,
            width: selected ? 2 : 1,
          ),
          color: selected ? kPrimaryTeal.withValues(alpha: 0.06) : Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? kPrimaryTeal : kMutedGray),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: kTextNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: kMutedGray, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: kPrimaryTeal),
          ],
        ),
      ),
    );
  }

  Widget _autoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: kPrimaryTeal, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(
              title,
              style: const TextStyle(
                color: kMutedGray,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: kTextNavy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: kMutedGray, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: kTextNavy,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderGray),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryTeal, width: 1.6),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderGray),
        boxShadow: kSoftCardShadow,
      ),
      child: child,
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.label,
    required this.active,
    required this.done,
  });

  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final color = active || done ? kPrimaryTeal : kBorderGray;
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: active || done ? kPrimaryTeal : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: done && !active
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : active
                  ? const Icon(Icons.circle, size: 8, color: Colors.white)
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? kPrimaryTeal : kMutedGray,
          ),
        ),
      ],
    );
  }
}
