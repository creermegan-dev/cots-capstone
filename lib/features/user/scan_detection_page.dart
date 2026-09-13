import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:exif/exif.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/cots_colors.dart';
import '../../models/activity_type.dart';
import '../../models/capture_model.dart';
import '../../models/cots_confidence_policy.dart';
import '../../models/cots_detection_result.dart';
import '../../widgets/cots_detection_image_overlay.dart';
import '../../providers/auth_provider.dart';
import '../../services/cots_yolo_detector.dart';
import '../../services/gps_exif_parser.dart';
import '../../services/capture_repository.dart';
import '../../services/scan_record_service.dart';
import '../../services/zone_assignment_service.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

const _maxImageBytes = 20 * 1024 * 1024;
const _maxBatchImages = 30;
const _allowedExtensions = {'.jpg', '.jpeg', '.png'};

const _scanBoxPurple = Color(0xFFAB47BC);

enum _DetectionStep { upload, details, review }

class ScanDetectionPage extends StatefulWidget {
  const ScanDetectionPage({
    super.key,
    this.initialActivityType,
    this.initialLinkedCaptureId,
  });

  final String? initialActivityType;
  final String? initialLinkedCaptureId;

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
  final List<_PendingScanImage> _images = [];
  String? _detectionProgress;
  double? _deviceGpsLat;
  double? _deviceGpsLng;
  String _activityType = CotsActivityType.detectionOnly;
  String? _removalMethod;
  String? _linkedCaptureId;
  List<CaptureModel> _userCaptures = const [];
  CaptureModel? _assignedCapture;
  StreamSubscription<List<CaptureModel>>? _captureSub;
  bool _isBusy = false;
  bool _showValidation = false;
  Timer? _liveClockTimer;

  bool get _hasImages => _images.isNotEmpty;
  bool get _isBatch => _images.length > 1;
  _PendingScanImage? get _primary => _hasImages ? _images.first : null;

  Uint8List? get _imageBytes => _primary?.bytes;
  XFile? get _imageFile => _primary?.file;
  String? get _fileName => _primary?.fileName;
  CotsDetectionResult? get _detection => _primary?.detection;
  DateTime? get _dateTaken => _primary?.metadata.dateTaken;
  double? get _latitude => _primary?.metadata.latitude;
  double? get _longitude => _primary?.metadata.longitude;
  int? get _widthPx => _primary?.metadata.widthPx;
  int? get _heightPx => _primary?.metadata.heightPx;
  bool get _gpsFromExif => _primary?.metadata.gpsFromExif ?? false;
  String get _deviceLabel => _primary?.metadata.deviceLabel ?? 'Unknown Device';

  int get _totalCotsDetected =>
      _images.fold(0, (sum, img) => sum + (img.detection?.count ?? 0));

  DateTime get _captureInstant => _dateTaken ?? DateTime.now();

  String get _assignedZone => ZoneAssignmentService.assignZone(
        latitude: _latitude,
        longitude: _longitude,
      );

  String get _dateCapturedLabel =>
      DateFormat('MMM dd, yyyy h:mm a').format(_captureInstant);

  String get _locationSourceLabel {
    if (_latitude == null || _longitude == null) return 'Unavailable';
    return _gpsFromExif ? 'Image EXIF GPS' : 'Live Device GPS';
  }

  String get _activityTypeLabel => CotsActivityType.isRemoval(_activityType)
      ? 'Removal Activity'
      : 'Detection Only';

  @override
  void initState() {
    super.initState();
    _activityType =
        widget.initialActivityType ?? CotsActivityType.detectionOnly;
    _linkedCaptureId = widget.initialLinkedCaptureId;
    _startLiveClock();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeCaptures());
  }

  Future<void> _initializeCaptures() async {
    final linkedId = widget.initialLinkedCaptureId;
    try {
      if (linkedId != null && linkedId.isNotEmpty) {
        _assignedCapture = await CaptureRepository.getById(linkedId);
      }
    } finally {
      if (mounted) _subscribeUserCaptures();
    }
  }

  void _subscribeUserCaptures() {
    _captureSub?.cancel();
    final auth = context.read<AuthProvider>();
    final uid = auth.userModel?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _captureSub = CaptureRepository.watchForUser(uid).listen((captures) {
      if (!mounted) return;
      final linked = _assignedCapture;
      final merged = <CaptureModel>[
        ...captures,
        if (linked != null && !captures.any((c) => c.id == linked.id)) linked,
      ];
      setState(() {
        _userCaptures = merged;
        if (_linkedCaptureId != null &&
            !merged.any((c) => c.id == _linkedCaptureId)) {
          _linkedCaptureId = null;
        }
      });
    });
  }

  void _startLiveClock() {
    _liveClockTimer?.cancel();
    _liveClockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _dateTaken != null) return;
      setState(() {});
    });
  }

  void _stopLiveClock() {
    _liveClockTimer?.cancel();
    _liveClockTimer = null;
  }

  @override
  void dispose() {
    _captureSub?.cancel();
    _stopLiveClock();
    _notesController.dispose();
    _depthController.dispose();
    _removedQtyController.dispose();
    _envNotesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
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
      _DetectionStep.details => 'Scan / Detection',
      _DetectionStep.review => 'Review',
    };
  }

  int get _confidencePercent =>
      CotsConfidencePolicy.percentFromConfidence(_detection?.confidence ?? 0);

  List<CotsDetectionReviewItem> get _detectionItems {
    final count = _detection?.count ?? 0;
    if (count <= 0) return const [];
    return CotsConfidencePolicy.buildDetectionItems(
      count: count,
      averagePercent: _confidencePercent,
      boxes: _detection?.boxes.isNotEmpty == true ? _detection!.boxes : null,
      imageWidth: _widthPx ?? 1920,
      imageHeight: _heightPx ?? 1080,
    );
  }

  /// Uploaded photo with AI bounding boxes — labels shown on review for admin preview.
  Widget _buildDetectionImagePreview({required bool showLabels}) {
    final count = _detection?.count ?? 0;
    final imgW = _widthPx ?? 1920;
    final imgH = _heightPx ?? 1080;
    if (_imageBytes == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            CotsDetectionImageOverlay(
              imageWidth: imgW,
              imageHeight: imgH,
              items: _detectionItems,
              imageBytes: _imageBytes,
              showBoxLabels: showLabels,
              boxColorOverride: showLabels ? null : _scanBoxPurple,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: kPrimaryTeal,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimaryTeal.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$count COTS DETECTED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showLabels && count > 0) ...[
          const SizedBox(height: 10),
          Text(
            'Each box is labeled (e.g. COTS 1 — 43%). Admins use these labels to '
            'verify every detected starfish individually.',
            style: TextStyle(
              color: kMutedGray.withValues(alpha: 0.95),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
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
      if (_step == _DetectionStep.upload) {
        for (final img in _images) {
          img.detection = null;
          img.detectionError = null;
        }
        _detectionProgress = null;
      }
    });
  }

  Widget _stepIndicator() {
    final steps = ['Upload', 'Details', 'Review'];
    final index = _step.index;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderGray),
      ),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: i <= index ? kPrimaryTeal : kBorderGray,
                  ),
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
    final isRemoval = CotsActivityType.isRemoval(_activityType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          isRemoval ? 'Upload Removal Image' : 'Upload GoPro Image',
          isRemoval
              ? 'Upload underwater evidence of COTS removal for this assignment.'
              : 'Select one or more underwater photos for AI crown-of-thorns detection.',
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: _isBusy ? null : () => _pickImages(),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _hasImages ? kPrimaryTeal : kBorderGray,
                      width: _hasImages ? 1.6 : 1.2,
                    ),
                    color: _hasImages
                        ? kPrimaryTeal.withValues(alpha: 0.04)
                        : const Color(0xFFF8FAFC),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _hasImages
                            ? Icons.check_circle_rounded
                            : Icons.cloud_upload_outlined,
                        size: 40,
                        color: _hasImages ? kPrimaryTeal : kMutedGray,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        !_hasImages
                            ? 'Tap to choose images'
                            : _isBatch
                                ? '${_images.length} images selected'
                                : 'Image selected',
                        style: const TextStyle(
                          color: kTextNavy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'JPG, JPEG, or PNG · max 20 MB each · up to $_maxBatchImages photos',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: kMutedGray, fontSize: 12),
                      ),
                      if (_hasImages) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isBusy
                                  ? null
                                  : () => _pickImages(addMore: true),
                              icon: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 18),
                              label: const Text('Add more'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPrimaryTeal,
                                side: const BorderSide(color: kPrimaryTeal),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isBusy ? null : _clearImages,
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              label: const Text('Clear all'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kDangerRed,
                                side: BorderSide(
                                    color: kDangerRed.withValues(alpha: 0.5)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_hasImages) ...[
                const SizedBox(height: 14),
                if (_isBatch)
                  _batchThumbnailGrid()
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    ),
                  ),
                if (_fileName != null && !_isBatch)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_photo_outlined,
                            size: 16, color: kMutedGray),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _fileName!,
                            style: const TextStyle(
                              color: kMutedGray,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionHeader(
          'Activity Type',
          'What did you do during this dive observation?',
        ),
        const SizedBox(height: 10),
        _card(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
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
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Depth',
                style: TextStyle(
                  color: kTextNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _depthController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                decoration: _inputDecoration('Depth').copyWith(
                  suffixText: 'm',
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isRemoval ? 'Remarks' : 'Notes',
                style: const TextStyle(
                  color: kTextNavy,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: _inputDecoration(
                  isRemoval ? 'optional remarks' : 'optional field notes',
                ),
              ),
              if (isRemoval) ...[
                const SizedBox(height: 18),
                const Text(
                  'Date Removed',
                  style: TextStyle(
                    color: kTextNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderGray),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_outlined,
                          color: kPrimaryTeal, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _dateCapturedLabel,
                          style: const TextStyle(
                            color: kTextNavy,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAutoCaptureCard(dateUploadedLabel: 'Set when you submit'),
        const SizedBox(height: 16),
        _buildCaptureSourceCard(),
      ],
    );
  }

  Widget _buildDetailsStep() {
    if (_isBatch) return _buildBatchDetailsStep();

    final isRemoval = CotsActivityType.isRemoval(_activityType);
    final count = _detection?.count ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_imageBytes != null) ...[
          _buildDetectionImagePreview(showLabels: false),
          const SizedBox(height: 14),
        ],
        _card(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DETECTION COUNT',
                      style: TextStyle(
                        color: kMutedGray.withValues(alpha: 0.9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: kTextNavy,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'COTS Detected',
                      style: TextStyle(
                        color: kTextNavy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Infestation Level: ${_infestationLevelLabel(count)}',
                      style: TextStyle(
                        color: kMutedGray.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _ConfidenceGauge(percent: _confidencePercent),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _assignedZoneCard(_assignedZone),
        if (isRemoval) ...[
          const SizedBox(height: 16),
          _linkedCaptureSelector(),
          const SizedBox(height: 16),
          _sectionHeader(
            'Removal Details',
            'Confirm removal count and method before continuing.',
          ),
          const SizedBox(height: 10),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Removed Quantity',
                  style: TextStyle(
                    color: kTextNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'AI suggested quantity — you may correct before submit.',
                  style: TextStyle(color: kMutedGray, fontSize: 12),
                ),
                const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Removal Method',
                  style: TextStyle(
                    color: kTextNavy,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
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
      ],
    );
  }

  Widget _buildReviewStep() {
    if (_isBatch) return _buildBatchReviewStep();

    final isRemoval = CotsActivityType.isRemoval(_activityType);
    final removed = int.tryParse(_removedQtyController.text.trim());
    final depth = double.tryParse(_depthController.text.trim());
    final notes = _notesController.text.trim();
    final count = _detection?.count ?? 0;
    final pct = _confidencePercent;
    final items = _detectionItems;
    final band = items.isNotEmpty
        ? CotsConfidencePolicy.recordBandFromItems(items)
        : CotsConfidencePolicy.bandFromPercent(pct);
    final statusLabel = switch (band) {
      CotsVerificationBand.aiAutoApproved => 'Automatically Accepted',
      CotsVerificationBand.adminReview => 'Requires Expert Validation',
      CotsVerificationBand.retakeRequired => 'Retake Photo',
    };
    final statusDesc = switch (band) {
      CotsVerificationBand.retakeRequired => items.isNotEmpty
          ? CotsConfidencePolicy.userStatusDescriptionFromItems(items)
          : CotsConfidencePolicy.userStatusDescription(pct),
      CotsVerificationBand.adminReview =>
        'The AI detection confidence is $pct%, which is below the automatic acceptance threshold. This record has been forwarded to the Expert for manual verification before it becomes an official monitoring record.',
      CotsVerificationBand.aiAutoApproved =>
        'The AI detection confidence is $pct%. This detection has been Automatically Accepted (80%–100% threshold).',
    };
    final statusColor = switch (band) {
      CotsVerificationBand.aiAutoApproved => kSuccessGreen,
      CotsVerificationBand.adminReview => kWarningOrange,
      CotsVerificationBand.retakeRequired => kDangerRed,
    };
    final statusIcon = switch (band) {
      CotsVerificationBand.aiAutoApproved => Icons.check_circle_rounded,
      CotsVerificationBand.adminReview => Icons.hourglass_top_rounded,
      CotsVerificationBand.retakeRequired => Icons.refresh_rounded,
    };
    final uploadPreview =
        DateFormat('MMM dd, yyyy h:mm a').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(statusIcon, color: statusColor, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detection Status',
                          style: TextStyle(
                            color: kMutedGray.withValues(alpha: 0.95),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Confidence Score',
                        style: TextStyle(
                          color: kMutedGray.withValues(alpha: 0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                statusDesc,
                style: TextStyle(
                  color: kTextNavy.withValues(alpha: 0.75),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: statusColor),
                  const SizedBox(width: 6),
                  Text(
                    'Infestation Level: ${_infestationLevelLabel(count)}',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_imageBytes != null) ...[
          const SizedBox(height: 14),
          _buildDetectionImagePreview(showLabels: true),
        ],
        const SizedBox(height: 14),
        _card(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DETECTION COUNT',
                      style: TextStyle(
                        color: kMutedGray.withValues(alpha: 0.9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$count',
                      style: const TextStyle(
                        color: kTextNavy,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'COTS Detected',
                      style: TextStyle(
                        color: kTextNavy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _ConfidenceGauge(percent: pct),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _assignedZoneCard(_assignedZone),
        const SizedBox(height: 16),
        _buildAutoCaptureCard(dateUploadedLabel: uploadPreview),
        const SizedBox(height: 16),
        _buildCaptureSourceCard(),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionCardTitle('Submission Details'),
              const SizedBox(height: 14),
              _reviewMetaRow(
                icon: Icons.category_outlined,
                label: 'Activity Type',
                value: _activityTypeLabel,
              ),
              Divider(height: 24, color: kBorderGray.withValues(alpha: 0.8)),
              _reviewMetaRow(
                icon: Icons.insert_photo_outlined,
                label: 'Image File',
                value: _fileName ?? 'gopro_image.jpg',
              ),
              Divider(height: 24, color: kBorderGray.withValues(alpha: 0.8)),
              _reviewMetaRow(
                icon: Icons.waves_rounded,
                label: 'Depth',
                value: depth != null ? '${depth.toStringAsFixed(1)} m' : '—',
              ),
              Divider(height: 24, color: kBorderGray.withValues(alpha: 0.8)),
              _reviewMetaRow(
                icon: Icons.notes_rounded,
                label: isRemoval ? 'Remarks' : 'Notes',
                value: notes.isNotEmpty ? notes : '—',
              ),
              if (isRemoval) ...[
                Divider(height: 24, color: kBorderGray.withValues(alpha: 0.8)),
                _reviewMetaRow(
                  icon: Icons.event_available_outlined,
                  label: 'Date Removed',
                  value: _dateCapturedLabel,
                ),
                Divider(height: 24, color: kBorderGray.withValues(alpha: 0.8)),
                _reviewMetaRow(
                  icon: Icons.cleaning_services_outlined,
                  label: 'Removed Quantity',
                  value: '${removed ?? '--'} COTS',
                ),
                if (_removalMethod != null && _removalMethod!.isNotEmpty) ...[
                  Divider(
                      height: 24, color: kBorderGray.withValues(alpha: 0.8)),
                  _reviewMetaRow(
                    icon: Icons.build_outlined,
                    label: 'Removal Method',
                    value: _removalMethod!,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _infestationLevelLabel(int count) {
    if (count <= 0) return 'None';
    if (count <= 5) return 'Low';
    if (count <= 15) return 'Moderate';
    return 'High';
  }

  Widget _buildAutoCaptureCard({required String dateUploadedLabel}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionCardTitle('Auto Capture'),
          const SizedBox(height: 14),
          _autoRow(
            Icons.location_on_outlined,
            'GPS Coordinates',
            ZoneAssignmentService.formatCoordinates(_latitude, _longitude),
            trailing: _hasCaptureCoordinates ? _gpsMapButton() : null,
          ),
          _autoRow(
            Icons.calendar_today_outlined,
            'Date',
            _dateCapturedLabel.split('·').first.trim().isEmpty
                ? _dateCapturedLabel
                : _dateCapturedLabel.split('·').first.trim(),
          ),
          _autoRow(
            Icons.access_time_rounded,
            'Time',
            _dateCapturedLabel.contains('·')
                ? _dateCapturedLabel.split('·').last.trim()
                : (_dateCapturedLabel.contains(',')
                    ? _dateCapturedLabel.split(',').last.trim()
                    : _dateCapturedLabel),
          ),
          _autoRow(
            Icons.cloud_upload_outlined,
            'Date uploaded',
            dateUploadedLabel,
          ),
          if (_dateTaken == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Live device time — updates until EXIF date is found.',
                style: TextStyle(
                  fontSize: 11,
                  color: kMutedGray.withValues(alpha: 0.95),
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaptureSourceCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionCardTitle('Capture Source'),
          const SizedBox(height: 14),
          _autoRow(Icons.photo_camera_outlined, 'Device', _deviceLabel),
          _autoRow(
              Icons.upload_file_outlined, 'Upload Method', 'Gallery Upload'),
          _autoRow(
              Icons.gps_fixed_rounded, 'Location Source', _locationSourceLabel),
        ],
      ),
    );
  }

  Widget _sectionCardTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: kPrimaryTeal,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _reviewMetaRow({
    required IconData icon,
    required String label,
    required String value,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kPrimaryTeal, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: kMutedGray.withValues(alpha: 0.95),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: kTextNavy,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: kMutedGray.withValues(alpha: 0.9),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _bottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      decoration: BoxDecoration(
        color: Colors.white,
        border:
            Border(top: BorderSide(color: kBorderGray.withValues(alpha: 0.9))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton(
          onPressed: _isBusy ? null : _onPrimaryAction,
          style: FilledButton.styleFrom(
            backgroundColor: kPrimaryTeal,
            disabledBackgroundColor: kPrimaryTeal.withValues(alpha: 0.35),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    _DetectionStep.details => 'Review',
                    _DetectionStep.review => _isBatch
                        ? 'Submit ${_images.length} Records'
                        : 'Submit',
                  },
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
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
    if (!_hasImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload at least one GoPro image.')),
      );
      return;
    }

    setState(() => _showValidation = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isBusy = true;
      _detectionProgress = 'Preparing…';
    });

    var analyzed = 0;
    var failed = 0;
    try {
      for (var i = 0; i < _images.length; i++) {
        final pending = _images[i];
        if (!mounted) return;
        setState(() {
          _detectionProgress =
              'Analyzing ${i + 1} of ${_images.length}: ${pending.fileName}';
        });
        try {
          pending.detection =
              await CotsYoloDetector.instance.detect(pending.bytes);
          pending.detectionError = null;
          analyzed++;
        } catch (e) {
          pending.detection = null;
          pending.detectionError = _detectionErrorMessage(e);
          failed++;
        }
      }

      if (analyzed == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI analysis failed for all images.')),
        );
        return;
      }

      if (CotsActivityType.isRemoval(_activityType) && !_isBatch) {
        _removedQtyController.text = '${_primary!.detection!.count}';
      }

      if (!mounted) return;
      if (failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Analyzed $analyzed image(s). $failed could not be processed and will be skipped on submit.',
            ),
          ),
        );
      }
      setState(() => _step = _DetectionStep.details);
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _detectionProgress = null;
        });
      }
    }
  }

  Future<void> _goToReview() async {
    final isRemoval = CotsActivityType.isRemoval(_activityType);
    if (isRemoval) {
      if (_linkedCaptureId == null || _linkedCaptureId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Select the detection capture this removal is linked to.',
            ),
          ),
        );
        return;
      }
      setState(() => _showValidation = true);
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }
    setState(() => _step = _DetectionStep.review);
  }

  Future<void> _submitRecord() async {
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    final uid = user?.uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a record.')),
      );
      return;
    }

    final ready = _images.where((img) => img.detection != null).toList();
    if (ready.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No analyzed images ready to submit.')),
      );
      return;
    }

    setState(() => _isBusy = true);
    var submitted = 0;
    try {
      final depth = double.tryParse(_depthController.text.trim());
      final isRemoval = CotsActivityType.isRemoval(_activityType);
      final removedSingle = isRemoval && !_isBatch
          ? int.tryParse(_removedQtyController.text.trim())
          : null;
      final notes = [
        _notesController.text.trim(),
        if (_envNotesController.text.trim().isNotEmpty)
          _envNotesController.text.trim(),
      ].where((s) => s.isNotEmpty).join('\n');

      for (var i = 0; i < ready.length; i++) {
        final img = ready[i];
        if (!mounted) return;
        setState(() {
          _detectionProgress = 'Submitting ${i + 1} of ${ready.length}…';
        });
        final removed = isRemoval
            ? (_isBatch ? img.detection!.count : removedSingle)
            : null;

        await ScanRecordService.submit(
          uid: uid,
          submittedBy: user.fullName,
          imageName: img.fileName,
          imagePath: img.file.path,
          imageBytes: img.bytes,
          activityType: _activityType,
          detection: img.detection!,
          latitude: img.metadata.latitude,
          longitude: img.metadata.longitude,
          dateTaken: img.captureInstant,
          imageWidth: img.metadata.widthPx,
          imageHeight: img.metadata.heightPx,
          notes: notes,
          depth: depth,
          confirmedRemovedQuantity: removed,
          measurementReferenceVisible: null,
          removalMethod: _removalMethod,
          sizeEstimate: null,
          linkedCaptureId: _linkedCaptureId,
        );
        submitted++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kPrimaryTeal,
          content: Text(
            submitted == 1
                ? 'Citizen science record submitted successfully.'
                : '$submitted citizen science records submitted successfully.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            submitted > 0
                ? 'Submitted $submitted record(s), then failed: $e'
                : 'Submit failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _detectionProgress = null;
        });
      }
    }
  }

  void _clearImages() {
    setState(() {
      _images.clear();
      _deviceGpsLat = null;
      _deviceGpsLng = null;
      _startLiveClock();
    });
  }

  Future<void> _pickImages({bool addMore = false}) async {
    final remaining = _maxBatchImages - _images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'You can upload up to $_maxBatchImages photos per batch.')),
      );
      return;
    }

    final picked = await _picker.pickMultiImage(
      imageQuality: 92,
      limit: addMore ? remaining : _maxBatchImages,
    );
    if (picked.isEmpty) return;

    if (!addMore) {
      _images.clear();
      _deviceGpsLat = null;
      _deviceGpsLng = null;
    }

    var skipped = 0;
    for (final file in picked) {
      if (_images.length >= _maxBatchImages) break;

      final ext = _extension(file.name);
      if (!_allowedExtensions.contains(ext)) {
        skipped++;
        continue;
      }

      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        skipped++;
        continue;
      }

      final metadata = await _extractMetadata(bytes);
      _images.add(
        _PendingScanImage(
          file: file,
          bytes: bytes,
          fileName: file.path.split(RegExp(r'[\\/]')).last,
          metadata: metadata,
        ),
      );
    }

    if (_primary?.metadata.dateTaken == null) {
      _startLiveClock();
    } else {
      _stopLiveClock();
    }

    if (!mounted) return;
    setState(() {});

    if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '$skipped file(s) skipped (unsupported type or over 20 MB).')),
      );
    }
  }

  Widget _batchThumbnailGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final img = _images[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(img.bytes, fit: BoxFit.cover),
              Positioned(
                left: 4,
                bottom: 4,
                right: 4,
                child: Text(
                  img.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBatchDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_detectionProgress != null) ...[
          LinearProgressIndicator(
            color: kPrimaryTeal,
            backgroundColor: kPrimaryTeal.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Text(
            _detectionProgress!,
            style: const TextStyle(color: kMutedGray, fontSize: 12),
          ),
          const SizedBox(height: 12),
        ],
        _card(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BATCH SUMMARY',
                      style: TextStyle(
                        color: kMutedGray.withValues(alpha: 0.9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_images.length}',
                      style: const TextStyle(
                        color: kTextNavy,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'Photos analyzed',
                      style: TextStyle(
                          color: kTextNavy, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '$_totalCotsDetected',
                    style: const TextStyle(
                      color: kPrimaryTeal,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Text(
                    'Total COTS',
                    style: TextStyle(
                        color: kMutedGray, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (CotsActivityType.isRemoval(_activityType)) ...[
          const SizedBox(height: 16),
          _linkedCaptureSelector(),
        ],
        const SizedBox(height: 14),
        ..._images.map(_batchResultTile),
      ],
    );
  }

  Widget _batchResultTile(_PendingScanImage img) {
    final count = img.detection?.count;
    final pct = CotsConfidencePolicy.percentFromConfidence(
      img.detection?.confidence ?? 0,
    );
    final failed = img.detectionError != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(img.bytes,
                  width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    img.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kTextNavy,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (failed)
                    Text(
                      img.detectionError!,
                      style: const TextStyle(color: kDangerRed, fontSize: 11),
                    )
                  else
                    Text(
                      '$count COTS · $pct% confidence · ${img.assignedZone}',
                      style: const TextStyle(color: kMutedGray, fontSize: 11.5),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchReviewStep() {
    final uploadPreview =
        DateFormat('MMM dd, yyyy h:mm a').format(DateTime.now());
    final depth = double.tryParse(_depthController.text.trim());
    final notes = _notesController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to submit ${_images.where((i) => i.detection != null).length} records',
                style: const TextStyle(
                  color: kTextNavy,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Total COTS detected across batch: $_totalCotsDetected',
                style: const TextStyle(color: kMutedGray, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ..._images.where((i) => i.detection != null).map(_batchResultTile),
        const SizedBox(height: 16),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionCardTitle('Shared dive details'),
              const SizedBox(height: 14),
              _reviewMetaRow(
                icon: Icons.category_outlined,
                label: 'Activity Type',
                value: _activityTypeLabel,
              ),
              Divider(height: 24, color: kBorderGray.withValues(alpha: 0.8)),
              _reviewMetaRow(
                icon: Icons.waves_rounded,
                label: 'Depth',
                value: depth != null ? '${depth.toStringAsFixed(1)} m' : '—',
              ),
              Divider(height: 24, color: kBorderGray.withValues(alpha: 0.8)),
              _reviewMetaRow(
                icon: Icons.cloud_upload_outlined,
                label: 'Upload time',
                value: uploadPreview,
              ),
              if (notes.isNotEmpty) ...[
                Divider(height: 24, color: kBorderGray.withValues(alpha: 0.8)),
                _reviewMetaRow(
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: notes,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _extension(String path) {
    final i = path.lastIndexOf('.');
    if (i < 0) return '';
    return path.substring(i).toLowerCase();
  }

  Future<_ScanImageMetadata> _extractMetadata(Uint8List bytes) async {
    var widthPx = 0;
    var heightPx = 0;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        final oriented = img.bakeOrientation(decoded);
        widthPx = oriented.width;
        heightPx = oriented.height;
      }
    } catch (_) {
      try {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        widthPx = frame.image.width;
        heightPx = frame.image.height;
        frame.image.dispose();
      } catch (_) {}
    }

    var deviceLabel = 'Unknown Device';
    DateTime? dateTaken;
    double? latitude;
    double? longitude;
    var gpsFromExif = false;

    try {
      final exif = await readExifFromBytes(bytes);
      final make = exif['Image Make']?.printable?.trim();
      final model = exif['Image Model']?.printable?.trim();
      if ((make != null && make.isNotEmpty) ||
          (model != null && model.isNotEmpty)) {
        deviceLabel = [make, model]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' ');
      }

      final rawDate = exif['EXIF DateTimeOriginal']?.printable ??
          exif['Image DateTime']?.printable;
      if (rawDate != null && rawDate.isNotEmpty) {
        dateTaken = DateFormat('yyyy:MM:dd HH:mm:ss').parse(rawDate);
      }

      final gps = GpsExifParser.parse(exif);
      if (gps != null) {
        latitude = gps.$1;
        longitude = gps.$2;
        gpsFromExif = true;
      }
    } catch (_) {}

    if (latitude == null || longitude == null) {
      await _ensureDeviceGps();
      latitude ??= _deviceGpsLat;
      longitude ??= _deviceGpsLng;
    }

    return _ScanImageMetadata(
      dateTaken: dateTaken,
      latitude: latitude,
      longitude: longitude,
      gpsFromExif: gpsFromExif,
      deviceLabel: deviceLabel,
      widthPx: widthPx == 0 ? null : widthPx,
      heightPx: heightPx == 0 ? null : heightPx,
    );
  }

  Future<void> _ensureDeviceGps() async {
    if (_deviceGpsLat != null && _deviceGpsLng != null) return;
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
      _deviceGpsLat = pos.latitude;
      _deviceGpsLng = pos.longitude;
    } catch (_) {}
  }

  String _detectionErrorMessage(Object error) {
    final msg = error.toString();
    if (msg.contains('yolov8_best.onnx') ||
        msg.contains('Unable to load asset')) {
      return 'AI model file is missing. Add assets/models/yolov8_best.onnx on your PC, then rebuild and reinstall the app.';
    }
    return 'AI analysis failed: $msg';
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: kMutedGray.withValues(alpha: 0.95),
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _activityTile(
    String value,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final selected = _activityType == value;
    return InkWell(
      onTap: () => setState(() {
        _activityType = value;
        if (!CotsActivityType.isRemoval(value)) {
          _linkedCaptureId = null;
        }
      }),
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

  Widget _linkedCaptureSelector() {
    final zone = _assignedZone;
    final inZone = _userCaptures.where((c) {
      if (zone == 'Unassigned') return true;
      return c.zone == zone || c.zone.contains(zone);
    }).toList();
    final options = inZone.isNotEmpty ? inZone : _userCaptures;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Previous Detection',
            style: TextStyle(
              color: kTextNavy,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Removal records must reference the original detection capture (foreign key).',
            style: TextStyle(color: kMutedGray, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (_userCaptures.isEmpty)
            Text(
              'No detection captures yet. Submit a Detection Only scan first.',
              style: TextStyle(
                color: kDangerRed.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            DropdownButtonFormField<String>(
              value: _linkedCaptureId,
              decoration: _inputDecoration('Select capture'),
              items: [
                for (final c in options)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(
                      '${c.displayRecordId} · ${c.zone} · ${c.aiDetectedCount} COTS',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _linkedCaptureId = v),
              validator: (v) {
                if (!CotsActivityType.isRemoval(_activityType) ||
                    !_showValidation) {
                  return null;
                }
                if (v == null || v.isEmpty) {
                  return 'Select the linked detection capture.';
                }
                return null;
              },
            ),
        ],
      ),
    );
  }

  Widget _assignedZoneCard(String zone) {
    final assigned = zone != 'Unassigned';
    final coords =
        ZoneAssignmentService.formatCoordinates(_latitude, _longitude);
    final hasGps = _latitude != null && _longitude != null;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.map_outlined, color: kPrimaryTeal, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reef Zone',
                      style: TextStyle(
                        color: kMutedGray.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      zone,
                      style: TextStyle(
                        color: assigned ? kTextNavy : kMutedGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: assigned
                      ? kPrimaryTeal.withValues(alpha: 0.12)
                      : kMutedGray.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: assigned
                        ? kPrimaryTeal.withValues(alpha: 0.35)
                        : kBorderGray,
                  ),
                ),
                child: Text(
                  assigned ? 'Assigned' : 'Unassigned',
                  style: TextStyle(
                    color: assigned ? kPrimaryTeal : kMutedGray,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: kBorderGray.withValues(alpha: 0.9)),
          const SizedBox(height: 12),
          Text(
            'GPS Coordinates',
            style: TextStyle(
              color: kMutedGray.withValues(alpha: 0.95),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasGps ? coords : 'GPS unavailable — enable location or use a photo with EXIF GPS.',
                  style: TextStyle(
                    color: hasGps ? kTextNavy : kMutedGray,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              if (hasGps) ...[
                const SizedBox(width: 8),
                _gpsMapButton(),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            assigned
                ? 'Auto-assigned from GPS to the nearest monitoring zone.'
                : 'No monitoring zone matched — enable GPS or use a photo with location data.',
            style: TextStyle(
              color: kMutedGray.withValues(alpha: 0.95),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  bool get _hasCaptureCoordinates => _latitude != null && _longitude != null;

  Widget _gpsMapButton() {
    return Material(
      color: kPrimaryTeal.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: _showCaptureLocationMap,
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            'GPS',
            style: TextStyle(
              color: kPrimaryTeal,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  void _showCaptureLocationMap() {
    final lat = _latitude;
    final lng = _longitude;
    if (lat == null || lng == null) return;

    final point = LatLng(lat, lng);
    final coordsLabel = ZoneAssignmentService.formatCoordinates(lat, lng);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.52,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, __) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: kBorderGray,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Capture Location',
                            style: TextStyle(
                              color: kTextNavy,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: kMutedGray),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            FlutterMap(
                              options: MapOptions(
                                initialCenter: point,
                                initialZoom: 15,
                                interactionOptions: const InteractionOptions(
                                  flags: InteractiveFlag.all,
                                ),
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.cotsmonitor.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: point,
                                      width: 36,
                                      height: 36,
                                      child: const Icon(
                                        Icons.location_on,
                                        color: kPrimaryTeal,
                                        size: 36,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: kPrimaryTeal,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            coordsLabel,
                            style: const TextStyle(
                              color: kTextNavy,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _autoRow(
    IconData icon,
    String title,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryTeal, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 108,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
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

  Widget _card(
      {required Widget child,
      EdgeInsetsGeometry padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
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

/// Circular confidence gauge matching the scan/detection mockup.
class _ConfidenceGauge extends StatelessWidget {
  const _ConfidenceGauge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: clamped / 100,
                    strokeWidth: 7,
                    backgroundColor: kBorderGray.withValues(alpha: 0.55),
                    color: kPrimaryTeal,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  '$clamped%',
                  style: const TextStyle(
                    color: kTextNavy,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Confidence Score',
            style: TextStyle(
              color: kMutedGray,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanImageMetadata {
  const _ScanImageMetadata({
    this.dateTaken,
    this.latitude,
    this.longitude,
    this.gpsFromExif = false,
    this.deviceLabel = 'Unknown Device',
    this.widthPx,
    this.heightPx,
  });

  final DateTime? dateTaken;
  final double? latitude;
  final double? longitude;
  final bool gpsFromExif;
  final String deviceLabel;
  final int? widthPx;
  final int? heightPx;
}

class _PendingScanImage {
  _PendingScanImage({
    required this.file,
    required this.bytes,
    required this.fileName,
    required this.metadata,
    this.detection,
    this.detectionError,
  });

  final XFile file;
  final Uint8List bytes;
  final String fileName;
  final _ScanImageMetadata metadata;
  CotsDetectionResult? detection;
  String? detectionError;

  DateTime get captureInstant => metadata.dateTaken ?? DateTime.now();

  String get assignedZone => ZoneAssignmentService.assignZone(
        latitude: metadata.latitude,
        longitude: metadata.longitude,
      );
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
