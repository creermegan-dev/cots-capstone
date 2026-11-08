import 'dart:async';
import 'dart:ui' as ui;

import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:exif/exif.dart';
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
import '../../core/supabase_config.dart';
import '../../models/activity_type.dart';
import '../../models/davao_gulf_geography.dart';
import '../../models/photo_location_rule.dart';
import '../../models/photo_source.dart';
import '../../models/cots_confidence_policy.dart';
import '../../models/cots_detection_result.dart';
import '../../models/cots_density.dart';
import '../../models/follow_up_monitoring_model.dart';
import '../../widgets/cots_detection_image_overlay.dart';
import '../../widgets/cots_loading_skeleton.dart';
import '../../providers/auth_provider.dart';
import '../../services/cots_yolo_detector.dart';
import '../../services/gps_exif_parser.dart';
import '../../services/follow_up_monitoring_repository.dart';
import '../../services/follow_up_reassignment_repository.dart';
import '../../models/follow_up_reassignment.dart';
import '../../services/offline_submission_service.dart';
import '../../services/original_photo_picker.dart';
import '../../services/supabase_record_service.dart';
import '../../models/zone_review.dart';
import '../../services/area_messages.dart';
import '../../services/zone_assignment_service.dart';
import 'cots_map_page.dart';
import 'photo_location_review_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';
import 'widgets/batch_detection_gallery.dart';

const _maxImageBytes = 20 * 1024 * 1024;
/// Photo limits (agreed): 15 per first encounter, 10 per monthly visit.
const scanMaxEncounterPhotos = 15;
const scanMaxFollowUpPhotos = 10;

/// Agreed wording (claude/agreed_workflow_decisions.md).
const scanNoCotsMessage =
    'No COTS detected. Please upload another photo where COTS are clearly visible.';
const scanAnalysisFailedMessage =
    'The AI could not process this photo. Tap Retry, or replace it with another photo.';
const scanPhotoRuleNote =
    "A photo can show many COTS, but don't photograph the same COTS twice.";
const scanRemovalConfirmationText =
    'I confirm that all COTS in these photos were removed, and each one appears in only one photo.';

/// Whether a photo must be retried, replaced or removed before continuing:
/// the AI could not process it, or (first encounter only) it shows no COTS.
/// Monthly visits may have zero COTS.
bool scanPhotoNeedsAttention({
  required bool isFollowUp,
  required bool analysisFailed,
  int? detectedCount,
  bool locationProblem = false,
}) =>
    locationProblem || analysisFailed || (!isFollowUp && detectedCount == 0);

/// Phone location status on the record page (Stage 7).
enum ScanLocationAccess { checking, ready, serviceOff, denied, deniedForever }
const _allowedExtensions = {'.jpg', '.jpeg', '.png'};

const _scanBoxPurple = Color(0xFFAB47BC);

enum _DetectionStep { upload, details, review }

class ScanDetectionPage extends StatefulWidget {
  const ScanDetectionPage({
    super.key,
    this.initialActivityType,
    this.initialLinkedCaptureId,
    this.followUpAssignment,
    this.previousFollowUpSurvey,
  });

  final String? initialActivityType;
  final String? initialLinkedCaptureId;
  final FollowUpAssignmentModel? followUpAssignment;
  final FollowUpSurveyModel? previousFollowUpSurvey;

  @override
  State<ScanDetectionPage> createState() => _ScanDetectionPageState();
}

class _ScanDetectionPageState extends State<ScanDetectionPage>
    with WidgetsBindingObserver {
  static final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _depthController = TextEditingController();
  final _envNotesController = TextEditingController();
  final _surveyedAreaController = TextEditingController();
  final _surveyLatitudeController = TextEditingController();
  final _surveyLongitudeController = TextEditingController();

  _DetectionStep _step = _DetectionStep.upload;
  final List<_PendingScanImage> _images = [];
  String? _detectionProgress;
  double? _deviceGpsLat;
  double? _deviceGpsLng;
  DateTime? _deviceGpsAt;
  ScanLocationAccess _locationAccess = ScanLocationAccess.checking;
  String get _activityType => _isFollowUp
      ? CotsActivityType.detectionOnly
      : CotsActivityType.removalActivity;
  String? _removalMethod;
  bool _isBusy = false;
  bool _showValidation = false;
  DateTime _surveyDate = MonitoringMonth.calendar(DateTime.now());
  String? _followUpRemovalMethod;

  /// The Diver's "I confirm..." tick on the Review step.
  bool _removalConfirmed = false;

  /// Groups this encounter's photos (one removal record per encounter).
  final String _encounterSubmissionId =
      FollowUpMonitoringRepository.newSurveyId();
  final String _followUpSurveyId = FollowUpMonitoringRepository.newSurveyId();
  Timer? _liveClockTimer;

  bool get _isFollowUp => widget.followUpAssignment != null;
  bool get _isLinkedRemoval =>
      !_isFollowUp && (widget.initialLinkedCaptureId?.isNotEmpty ?? false);
  int get _imageLimit =>
      _isFollowUp ? scanMaxFollowUpPhotos : scanMaxEncounterPhotos;
  bool get _hasImages => _images.isNotEmpty;
  bool get _isBatch => _images.length > 1;
  _PendingScanImage? get _primary => _hasImages ? _images.first : null;

  Uint8List? get _imageBytes => _primary?.bytes;
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

  /// COTS in the 20-79% band: sent to the Expert after submitting.
  int get _waitingForExpert => _images.fold(0, (sum, img) {
        final boxes = img.detection?.boxes ?? const <CotsBoundingBox>[];
        return sum +
            boxes.where((box) {
              final percent =
                  CotsConfidencePolicy.percentFromConfidence(box.score);
              return percent >= CotsConfidencePolicy.adminReviewMin &&
                  percent < CotsConfidencePolicy.autoApproveMin;
            }).length;
      });

  /// Photos to fix before continuing: the AI could not process them, or
  /// (first encounter only) they show no COTS.
  List<_PendingScanImage> get _problemImages => [
        for (final img in _images)
          if (scanPhotoNeedsAttention(
            isFollowUp: _isFollowUp,
            analysisFailed: img.detectionError != null,
            detectedCount: img.detection?.count,
            locationProblem: img.metadata.locationProblem !=
                PhotoLocationProblem.none,
          ))
            img,
      ];

  DateTime get _captureInstant => _dateTaken ?? DateTime.now();

  String get _assignedZone => ZoneAssignmentService.assignZone(
        latitude: _latitude,
        longitude: _longitude,
      );

  String get _dateCapturedLabel =>
      DateFormat('MMM dd, yyyy h:mm a').format(_captureInstant);

  String get _locationSourceLabel {
    if (_latitude == null || _longitude == null) return 'Unavailable';
    return PhotoSource.locationLabel(
        _gpsFromExif ? 'exif' : 'device_surface');
  }

  String get _activityTypeLabel => _isFollowUp
      ? 'Follow-up Survey'
      : CotsActivityType.isRemoval(_activityType)
          ? 'Removal Activity'
          : 'Detection Only';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLiveClock();
    _checkLocationAccess(ask: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from Settings: check again.
    if (state == AppLifecycleState.resumed) _checkLocationAccess();
  }

  /// Checks (and, the first time, asks for) the phone's location (Stage 7).
  Future<void> _checkLocationAccess({bool ask = false}) async {
    ScanLocationAccess next;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        next = ScanLocationAccess.serviceOff;
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied && ask) {
          permission = await Geolocator.requestPermission();
        }
        next = switch (permission) {
          LocationPermission.deniedForever => ScanLocationAccess.deniedForever,
          LocationPermission.denied ||
          LocationPermission.unableToDetermine =>
            ScanLocationAccess.denied,
          _ => ScanLocationAccess.ready,
        };
      }
    } catch (_) {
      next = ScanLocationAccess.denied;
    }
    if (!mounted) return;
    setState(() => _locationAccess = next);
  }

  /// Fixes the location of photos still waiting for the phone's GPS.
  Future<void> _retryPhotoLocations() async {
    await _checkLocationAccess(ask: true);
    _deviceGpsLat = null;
    _deviceGpsLng = null;
    for (final image in _images) {
      if (image.metadata.locationProblem == PhotoLocationProblem.none ||
          image.metadata.gpsFromExif) {
        continue;
      }
      image.metadata = await _extractMetadata(image.bytes);
    }
    if (mounted) setState(() {});
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
    WidgetsBinding.instance.removeObserver(this);
    _stopLiveClock();
    _notesController.dispose();
    _depthController.dispose();
    _envNotesController.dispose();
    _surveyedAreaController.dispose();
    _surveyLatitudeController.dispose();
    _surveyLongitudeController.dispose();
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
        active:
            _isFollowUp ? UserNavDestination.followUp : UserNavDestination.scan,
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
                  child: _isBusy
                      ? _buildDetectionLoading()
                      : switch (_step) {
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

  Widget _buildDetectionLoading() {
    final label = _detectionProgress ??
        (_step == _DetectionStep.review
            ? 'Submitting detection record…'
            : 'Processing detection images…');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: kPrimaryTeal, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: kTextNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        CotsLoadingSkeleton(
          layout: CotsSkeletonLayout.detail,
          label: label,
        ),
      ],
    );
  }

  String get _stepTitle {
    if (_isLinkedRemoval) return 'Record Removal Evidence';
    if (_isFollowUp) {
      return switch (_step) {
        _DetectionStep.upload => 'Follow-up Survey',
        _DetectionStep.details => 'Survey Details',
        _DetectionStep.review => 'Review Follow-up',
      };
    }
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
            Expanded(
              child: _StepDot(
                label: steps[i],
                active: i == index,
                done: i < index,
              ),
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
          _isFollowUp
              ? 'Upload GoPro Monitoring Images'
              : isRemoval
                  ? 'Upload COTS Image'
                  : 'Upload GoPro Image',
          _isFollowUp
              ? 'Add photos from this visit. Each image will use the existing AI detection workflow.'
              : isRemoval
                  ? 'Upload the photos you took before removing the COTS. Record the removal method in Details.'
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
                        'JPG, JPEG, or PNG · max 20 MB each · up to $_imageLimit photos',
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
        const SizedBox(height: 12),
        _locationAccessCard(),
        _photoRuleNoteCard(),
        if (_problemImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildProblemPhotosCard(),
        ],
        if (!_isFollowUp) ...[
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
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$')),
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
                    'Photo Capture Date',
                    style: TextStyle(
                      color: kTextNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
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
        ],
        const SizedBox(height: 16),
        _buildAutoCaptureCard(dateUploadedLabel: 'Set when you submit'),
        const SizedBox(height: 16),
        _buildCaptureSourceCard(),
      ],
    );
  }

  Widget _buildDetailsStep() {
    if (_isBatch) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBatchDetailsStep(),
          if (_isFollowUp) ...[
            const SizedBox(height: 14),
            _buildFollowUpFields(),
          ],
        ],
      );
    }

    final isRemoval = CotsActivityType.isRemoval(_activityType);
    final count = _detection?.count ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_imageBytes != null) ...[
          _buildDetectionImagePreview(showLabels: true),
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
                      'Infestation cannot be determined from one photo',
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
        if (_isFollowUp)
          _buildFollowUpFields()
        else
          _assignedZoneCard(_assignedZone),
        if (isRemoval) _buildRemovalDetails(),
      ],
    );
  }

  Widget _buildRemovalDetails() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(
            'Removal Details',
            'The removed count is taken from your photos. Choose the removal method you used.',
          ),
          const SizedBox(height: 10),
          _card(
            child: Row(
              children: [
                const Icon(Icons.cleaning_services_outlined,
                    color: kPrimaryTeal, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'COTS removed (from your photos): $_totalCotsDetected',
                    style: const TextStyle(
                      color: kTextNavy,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
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
                  initialValue: _removalMethod,
                  isExpanded: true,
                  decoration: _inputDecoration('Select method'),
                  items: RemovalMethod.options
                      .map(
                        (m) => DropdownMenuItem(value: m, child: Text(m)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _removalMethod = v),
                  validator: (v) {
                    if (!_showValidation) return null;
                    if (v == null || v.isEmpty) return 'Select removal method.';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildFollowUpFields() {
    final assignment = widget.followUpAssignment!;
    final previous = widget.previousFollowUpSurvey;
    final dateLabel = DateFormat('MMM d, yyyy').format(_surveyDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assigned site',
                style: TextStyle(
                  color: kTextNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${assignment.areaName} · ${assignment.barangay}, '
                '${assignment.municipality}',
                style: const TextStyle(color: kMutedGray, height: 1.35),
              ),
              const Divider(height: 22),
              Text(
                previous == null
                    ? 'No previous follow-up survey has been recorded.'
                    : 'Previous visit: '
                        '${DateFormat('MMM d, yyyy').format(previous.surveyDate)} · '
                        'Field observed ${previous.fieldObservedCount}, '
                        'eliminated ${previous.fieldEliminatedCount}, '
                        'AI detections ${previous.aiDetectedCount}.',
                style: const TextStyle(
                  color: kTextNavy,
                  height: 1.35,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Actual monitoring date',
                style: TextStyle(
                  color: kTextNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _chooseSurveyDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(dateLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryTeal,
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderGray),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cleaning_services_outlined,
                        color: kPrimaryTeal, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'COTS found and removed: $_totalCotsDetected\n'
                        'Taken from your photos.',
                        style: const TextStyle(
                          color: kTextNavy,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_totalCotsDetected > 0) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _followUpRemovalMethod,
                  decoration: _inputDecoration('Removal method'),
                  items: RemovalMethod.options
                      .map((method) => DropdownMenuItem(
                            value: method,
                            child: Text(method),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _followUpRemovalMethod = value),
                  validator: (value) {
                    if (!_showValidation) return null;
                    return value == null || value.isEmpty
                        ? 'Select the method used.'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'GPS reference location (optional)',
                style: TextStyle(
                  color: kTextNavy,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _surveyLatitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                autovalidateMode: _showValidation
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                validator: (_) => _surveyCoordinatesError(),
                decoration: _inputDecoration('Latitude'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _surveyLongitudeController,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                autovalidateMode: _showValidation
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                validator: (_) => _surveyCoordinatesError(),
                decoration: _inputDecoration('Longitude'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _surveyedAreaController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
                autovalidateMode: _showValidation
                    ? AutovalidateMode.onUserInteraction
                    : AutovalidateMode.disabled,
                validator: (value) {
                  // Required: used to calculate COTS per hectare.
                  final raw = (value ?? '').trim();
                  if (raw.isEmpty) {
                    return 'Enter the surveyed reef area in square meters.';
                  }
                  final area = double.tryParse(raw);
                  if (area == null || !area.isFinite || area <= 0) {
                    return 'Enter a surveyed area greater than zero.';
                  }
                  return null;
                },
                decoration: _inputDecoration(
                  'Surveyed reef area',
                ).copyWith(
                  suffixText: 'm²',
                  helperText: 'Used to calculate COTS per hectare.',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: _inputDecoration('Field notes (optional)'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _surveyCoordinatesError() {
    final latitudeText = _surveyLatitudeController.text.trim();
    final longitudeText = _surveyLongitudeController.text.trim();
    if (latitudeText.isEmpty && longitudeText.isEmpty) return null;
    if (latitudeText.isEmpty || longitudeText.isEmpty) {
      return 'Enter both coordinates or leave both blank.';
    }
    final latitude = double.tryParse(latitudeText);
    final longitude = double.tryParse(longitudeText);
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return 'Enter valid latitude and longitude coordinates.';
    }
    return null;
  }

  Future<void> _chooseSurveyDate() async {
    final now = MonitoringMonth.calendar(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _surveyDate.isAfter(now) ? now : _surveyDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null && mounted) setState(() => _surveyDate = picked);
  }

  Widget _buildReviewStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildReviewStepBody(),
          const SizedBox(height: 16),
          _buildConfirmationCard(),
        ],
      );

  Widget _buildConfirmationCard() {
    final waiting = _waitingForExpert;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionCardTitle(
              _isFollowUp ? 'Before you submit' : 'Removal summary'),
          const SizedBox(height: 10),
          Text(
            '${_isFollowUp ? 'COTS found and removed' : 'COTS removed'} '
            '(from your photos): $_totalCotsDetected',
            style: const TextStyle(
                color: kTextNavy, fontWeight: FontWeight.w700, fontSize: 14),
          ),
          if (!_isFollowUp &&
              _removalMethod != null &&
              _removalMethod!.isNotEmpty)
            Text('Removal method: $_removalMethod',
                style: const TextStyle(color: kMutedGray, fontSize: 12.5)),
          const SizedBox(height: 6),
          Text(
            waiting > 0
                ? '$waiting COTS will be sent to the Expert after you submit. '
                    'The final count includes only confirmed COTS.'
                : 'After you submit, the photos will be verified and the COTS '
                    'counted automatically.',
            style: const TextStyle(
                color: kMutedGray, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _removalConfirmed,
            onChanged: _isBusy
                ? null
                : (value) => setState(() => _removalConfirmed = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: kPrimaryTeal,
            title: const Text(
              scanRemovalConfirmationText,
              style: TextStyle(fontSize: 13, color: kTextNavy, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStepBody() {
    if (_isBatch) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBatchReviewStep(),
          if (_isFollowUp) ...[
            const SizedBox(height: 14),
            _buildFollowUpReviewCard(),
          ],
        ],
      );
    }

    final isRemoval = CotsActivityType.isRemoval(_activityType);
    final depth = double.tryParse(_depthController.text.trim());
    final notes = _notesController.text.trim();
    final count = _detection?.count ?? 0;
    final pct = _confidencePercent;
    final items = _detectionItems;
    final band = items.isNotEmpty
        ? CotsConfidencePolicy.recordBandFromItems(items)
        : CotsConfidencePolicy.bandFromPercent(pct);
    final zeroCotsSurvey = _isFollowUp && _detection != null && count == 0;
    final statusLabel = zeroCotsSurvey
        ? 'No AI detections'
        : switch (band) {
            CotsVerificationBand.aiAutoApproved => 'Automatically Accepted',
            CotsVerificationBand.adminReview => 'Requires Expert Validation',
            CotsVerificationBand.retakeRequired => 'Retake Photo',
          };
    final statusDesc = zeroCotsSurvey
        ? 'AI processing completed with no COTS detected in this image. Field observations are recorded separately. This result does not establish reef clearance.'
        : switch (band) {
            CotsVerificationBand.retakeRequired => items.isNotEmpty
                ? CotsConfidencePolicy.userStatusDescriptionFromItems(items)
                : CotsConfidencePolicy.userStatusDescription(pct),
            CotsVerificationBand.adminReview => items.isEmpty
                ? 'Some COTS are below ${CotsConfidencePolicy.autoApproveMin}% confidence. After you submit, they will be sent to the Expert and count only if the Expert approves them.'
                : '${CotsConfidencePolicy.countNeedingAdminReview(items)} of ${items.length} COTS are below ${CotsConfidencePolicy.autoApproveMin}% confidence. After you submit, they will be sent to the Expert and count only if the Expert approves them.',
            CotsVerificationBand.aiAutoApproved => items.isEmpty
                ? 'After you submit and the photo is verified, these COTS will be accepted automatically (${CotsConfidencePolicy.autoApproveMin}%–100%).'
                : 'All ${items.length} COTS are at ${CotsConfidencePolicy.autoApproveMin}% confidence or above. After you submit and the photo is verified, they will be accepted automatically.',
          };
    final statusColor = zeroCotsSurvey
        ? kPrimaryTeal
        : switch (band) {
            CotsVerificationBand.aiAutoApproved => kSuccessGreen,
            CotsVerificationBand.adminReview => kWarningOrange,
            CotsVerificationBand.retakeRequired => kDangerRed,
          };
    final statusIcon = zeroCotsSurvey
        ? Icons.fact_check_outlined
        : switch (band) {
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
                        'Average AI confidence',
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
                  Expanded(
                      child: Text(
                    'Infestation requires a field assessment',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  )),
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
        if (_isFollowUp)
          _buildFollowUpReviewCard()
        else
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
                  label: 'COTS removed (from your photos)',
                  value: '$_totalCotsDetected COTS',
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

  Widget _buildFollowUpReviewCard() {
    final latitude = double.tryParse(_surveyLatitudeController.text.trim());
    final longitude = double.tryParse(_surveyLongitudeController.text.trim());
    final surveyedArea = double.tryParse(_surveyedAreaController.text.trim());
    final density = CotsDensity.perHectare(_totalCotsDetected, surveyedArea);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionCardTitle('Follow-up Survey'),
          const SizedBox(height: 12),
          _reviewMetaRow(
            icon: Icons.calendar_month_outlined,
            label: 'Monitoring date',
            value: DateFormat('MMM d, yyyy').format(_surveyDate),
          ),
          _reviewMetaRow(
            icon: Icons.cleaning_services_outlined,
            label: 'COTS found and removed (from your photos)',
            value: '$_totalCotsDetected',
          ),
          if (_waitingForExpert > 0)
            _reviewMetaRow(
              icon: Icons.hourglass_top_rounded,
              label: 'Will be checked by the Expert after you submit',
              value: '$_waitingForExpert',
            ),
          _reviewMetaRow(
            icon: Icons.location_on_outlined,
            label: 'GPS reference',
            value: latitude == null || longitude == null
                ? 'Not provided'
                : '${latitude.toStringAsFixed(6)}, '
                    '${longitude.toStringAsFixed(6)}',
          ),
          _reviewMetaRow(
            icon: Icons.square_foot_outlined,
            label: 'Surveyed area',
            value: surveyedArea == null
                ? 'Not provided'
                : '${surveyedArea.toStringAsFixed(2)} m²',
          ),
          _reviewMetaRow(
            icon: Icons.analytics_outlined,
            label: 'COTS density (calculated)',
            value: CotsDensity.describe(density, CotsDensity.level(density)),
          ),
          if (_totalCotsDetected > 0)
            _reviewMetaRow(
              icon: Icons.build_outlined,
              label: 'Removal method',
              value: _followUpRemovalMethod ?? 'Not selected',
            ),
        ],
      ),
    );
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: kTextNavy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
          onPressed: _isBusy ||
                  (_step == _DetectionStep.review && !_removalConfirmed)
              ? null
              : _onPrimaryAction,
          style: FilledButton.styleFrom(
            backgroundColor: kPrimaryTeal,
            disabledBackgroundColor: kPrimaryTeal.withValues(alpha: 0.35),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isBusy
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                    semanticsLabel: _detectionProgress ?? 'Processing',
                  ),
                )
              : Text(
                  switch (_step) {
                    _DetectionStep.upload => 'Next → Details',
                    _DetectionStep.details => 'Review',
                    _DetectionStep.review =>
                      _isBatch ? 'Submit ${_images.length} Records' : 'Submit',
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
        } catch (e) {
          pending.detection = null;
          pending.detectionError = _detectionErrorMessage(e);
        }
      }

      if (!mounted) return;
      final problems = _problemImages;
      if (problems.isNotEmpty) {
        final locationCount = problems
            .where((img) =>
                img.metadata.locationProblem != PhotoLocationProblem.none)
            .length;
        final failedCount =
            problems.where((img) => img.detectionError != null).length;
        final noCotsCount = problems.length - failedCount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              locationCount > 0
                  ? '$locationCount photo(s) need a location. See the notes below the photos.'
                  : failedCount == 0
                  ? scanNoCotsMessage
                  : noCotsCount == 0
                      ? 'The AI could not process $failedCount photo(s). Retry or replace them.'
                      : 'Some photos need attention. Fix them before continuing.',
            ),
          ),
        );
        setState(() {});
        return;
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
    if (_isFollowUp) {
      setState(() => _showValidation = true);
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_surveyCoordinatesError() != null) return;
      if (_totalCotsDetected > 0 &&
          (_followUpRemovalMethod == null || _followUpRemovalMethod!.isEmpty)) {
        return;
      }
      setState(() {
        _removalConfirmed = false;
        _step = _DetectionStep.review;
      });
      return;
    }

    final isRemoval = CotsActivityType.isRemoval(_activityType);
    if (isRemoval) {
      setState(() => _showValidation = true);
      if (!(_formKey.currentState?.validate() ?? false)) return;
    }
    setState(() {
      _removalConfirmed = false;
      _step = _DetectionStep.review;
    });
  }

  Future<void> _submitRecord() async {
    if (_isBusy) return;
    // The Diver must confirm the removal before anything is submitted.
    if (!_removalConfirmed) return;
    final auth = context.read<AuthProvider>();
    final user = auth.userModel;
    final uid = user?.uid;
    if (uid == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to submit a record.')),
      );
      return;
    }

    final ready = _images.where((img) => img.detection != null).toList();
    if (_isFollowUp && (!user.isActive || user.isAdmin || user.isExpert)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Only the assigned diver can submit this survey.')),
      );
      return;
    }
    if (ready.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No analyzed images ready to submit.')),
      );
      return;
    }
    if (_isFollowUp) {
      String? otherPart;
      for (final image in ready) {
        final area = ZoneAssignmentService.resolveMonitoringArea(
            latitude: image.metadata.latitude,
            longitude: image.metadata.longitude);
        if (area != null &&
            area.barangay.id != widget.followUpAssignment!.areaId) {
          otherPart = area.barangay.id;
          break;
        }
      }
      final conflict = otherPart != null;
      if (conflict || ready.length > scanMaxFollowUpPhotos) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(conflict
                ? AreaMessages.otherPart(otherPart!)
                : 'Submit at most $scanMaxFollowUpPhotos images per visit.')));
        return;
      }
    }

    setState(() => _isBusy = true);
    var submitted = 0;
    var queued = 0;
    final captureIds = <String>[];
    final submissionWarnings = <String>[];
    try {
      if (_isFollowUp) {
        if (!await FollowUpReassignmentRepository.isResponsible(
            widget.followUpAssignment!, uid, _surveyDate)) {
          throw StateError(
              'Only the authorized diver for this calendar month can submit.');
        }
        if (!mounted) return;
        await FollowUpReassignmentRepository.ensureMonthAuthorization(
            widget.followUpAssignment!, uid, _surveyDate);
      }
      final depth = double.tryParse(_depthController.text.trim());
      final isRemoval = CotsActivityType.isRemoval(_activityType);
      // One encounter: the first photo carries the encounter's single removal
      // record with the photo total; the other photos are detections only.
      final removalTotal = _totalCotsDetected;
      final notes = [
        _notesController.text.trim(),
        if (_envNotesController.text.trim().isNotEmpty)
          _envNotesController.text.trim(),
      ].where((s) => s.isNotEmpty).join('\n');

      for (var i = 0; i < ready.length; i++) {
        final img = ready[i];
        if (img.savedCaptureId != null) {
          if (_isFollowUp) captureIds.add(img.savedCaptureId!);
          submitted++;
          continue;
        }
        if (!mounted) return;
        setState(() {
          _detectionProgress = 'Submitting ${i + 1} of ${ready.length}…';
        });
        final carriesRemoval = isRemoval && (i == 0 || _isLinkedRemoval);
        final removed = !carriesRemoval
            ? null
            : _isLinkedRemoval
                ? (img.detection?.count ?? 0)
                : removalTotal;

        final result = await OfflineSubmissionService.instance.submitRecord(
          onWarning: submissionWarnings.add,
          submissionId: img.submissionId,
          followUpSurveyId: _isFollowUp ? _followUpSurveyId : null,
          followUpSurveyDate: _isFollowUp ? _surveyDate : null,
          followUpAssignment: widget.followUpAssignment,
          uid: uid,
          submittedBy: user.fullName,
          imageName: img.fileName,
          imageBytes: img.bytes,
          activityType: carriesRemoval
              ? _activityType
              : _isFollowUp
                  ? _activityType
                  : CotsActivityType.detectionOnly,
          detection: img.detection!,
          latitude: img.metadata.latitude,
          longitude: img.metadata.longitude,
          gpsFromPhoto: img.metadata.gpsFromExif,
          // The date comes from the photo only when it had one; otherwise
          // captureInstant is the moment the photo was selected.
          timeFromPhoto: img.metadata.dateTaken != null,
          dateTaken: img.captureInstant,
          imageWidth: img.metadata.widthPx,
          imageHeight: img.metadata.heightPx,
          notes: notes,
          depth: depth,
          confirmedRemovedQuantity: removed,
          measurementReferenceVisible: null,
          removalMethod: _removalMethod,
          sizeEstimate: null,
          linkedCaptureId:
              _isLinkedRemoval ? widget.initialLinkedCaptureId : null,
          encounterId: _isFollowUp || _isLinkedRemoval
              ? null
              : _encounterSubmissionId,
          isFollowUp: _isFollowUp,
        );
        final captureId = result.recordId;
        if (result.isPending) queued++;
        if (_isFollowUp) captureIds.add(captureId);
        img.savedCaptureId = captureId;
        submitted++;
      }

      if (_isFollowUp) {
        final assignment = widget.followUpAssignment!;
        final surveyPending =
            await OfflineSubmissionService.instance.submitSurvey(
          surveyId: _followUpSurveyId,
          areaId: assignment.areaId,
          areaName: assignment.areaName,
          barangay: assignment.barangay,
          municipality: assignment.municipality,
          uid: uid,
          submittedBy: user.fullName,
          surveyDate: _surveyDate,
          fieldObservedCount: _totalCotsDetected,
          fieldEliminatedCount: _totalCotsDetected,
          captureIds: captureIds,
          aiDetectedCount: _totalCotsDetected,
          latitude: double.tryParse(_surveyLatitudeController.text.trim()),
          longitude: double.tryParse(_surveyLongitudeController.text.trim()),
          surveyedAreaSquareMeters:
              double.tryParse(_surveyedAreaController.text.trim()),
          eliminationMethod: _followUpRemovalMethod ?? '',
          notes: _notesController.text.trim(),
          deferUpload: queued > 0,
        );
        if (surveyPending) queued++;
      }

      // Stage 2: another Diver's record in an assigned zone waits for the
      // Expert. Offline records get the same message as a notification when
      // they upload.
      String? zoneAssignedTo;
      if (SupabaseConfig.isConfigured && !_isFollowUp && queued == 0) {
        try {
          zoneAssignedTo = await SupabaseRecordService.zoneReviewAssignedTo(
              ready.first.submissionId);
        } catch (_) {
          // The database also sends this message as a notification.
        }
      }
      if (!mounted) return;
      final assignedTo = zoneAssignedTo;
      if (assignedTo != null) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Sent to the Expert'),
            content: Text(ZoneReview.waitingMessage(assignedTo)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kPrimaryTeal,
          content: Text(
            queued > 0
                ? '$queued submission${queued == 1 ? '' : 's'} saved on this device and pending synchronization.'
                : _isFollowUp
                    ? 'Follow-up survey and $submitted image record(s) saved.'
                    : submissionWarnings.isNotEmpty
                        ? submissionWarnings.first
                        : submitted == 1
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
                ? 'Submitted $submitted image record(s), then failed to save '
                    '${_isFollowUp ? 'the follow-up survey' : 'the record'}: $e'
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
    final remaining = _imageLimit - _images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('You can upload up to $_imageLimit photos per batch.')),
      );
      return;
    }

    final limit = addMore ? remaining : _imageLimit;
    final List<XFile> picked;
    try {
      // On Android, read the original photos so their GPS location is kept.
      picked = OriginalPhotoPicker.isSupported
          ? await OriginalPhotoPicker.pickImages(limit: limit)
          : await _picker.pickMultiImage(imageQuality: 92, limit: limit);
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The photos could not be opened. Try again.')),
      );
      return;
    }
    if (picked.isEmpty) return;

    if (!addMore) {
      _images.clear();
      _deviceGpsLat = null;
      _deviceGpsLng = null;
    }

    var skipped = 0;
    for (final file in picked) {
      if (_images.length >= _imageLimit) break;

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
    await _askPhotoLocationPermissionIfNeeded();
    if (!mounted) return;

    if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '$skipped file(s) skipped (unsupported type or over 20 MB).')),
      );
    }
  }

  /// Phone location status, with the way to fix it (Stage 7).
  Widget _locationAccessCard() {
    if (_locationAccess == ScanLocationAccess.ready ||
        _locationAccess == ScanLocationAccess.checking) {
      return const SizedBox.shrink();
    }
    final (String message, String button, Future<void> Function() action) =
        switch (_locationAccess) {
      ScanLocationAccess.serviceOff => (
          'Location is turned off. Turn it on so photos without GPS can use '
              "your phone's location.",
          'Open settings',
          () async {
            await Geolocator.openLocationSettings();
          },
        ),
      ScanLocationAccess.deniedForever => (
          'Location permission is blocked for COTS Monitor. Allow it in the '
              "app's settings (Permissions → Location → While using the app).",
          'Open settings',
          () async {
            await Geolocator.openAppSettings();
          },
        ),
      _ => (
          'COTS Monitor needs your location (while using the app).',
          'Allow location',
          () => _checkLocationAccess(ask: true),
        ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kDangerRed.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kDangerRed.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_off_rounded,
                    color: kDangerRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${PhotoLocationRule.locationRequiredBanner}\n$message',
                    style: const TextStyle(
                        color: kTextNavy, fontSize: 12.5, height: 1.35),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _isBusy ? null : action,
                  child: Text(button),
                ),
                TextButton(
                  onPressed: _isBusy ? null : _retryPhotoLocations,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Android hides the GPS saved in photos unless the app may read photo
  /// locations. When photos came in without GPS and that permission is
  /// missing, explain it and offer the app settings (Stage 7).
  Future<void> _askPhotoLocationPermissionIfNeeded() async {
    if (!OriginalPhotoPicker.isSupported) return;
    if (_images.every((image) => image.metadata.gpsFromExif)) return;
    if (await OriginalPhotoPicker.photoLocationAllowed()) return;
    if (!mounted) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(PhotoLocationRule.photoLocationPermissionTitle),
        content: const Text(PhotoLocationRule.photoLocationPermissionMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (open == true) await Geolocator.openAppSettings();
  }

  Widget _photoRuleNoteCard() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kPrimaryTeal.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimaryTeal.withValues(alpha: 0.3)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, color: kPrimaryTeal, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                scanPhotoRuleNote,
                style: TextStyle(color: kTextNavy, fontSize: 12.5, height: 1.35),
              ),
            ),
          ],
        ),
      );

  Widget _buildProblemPhotosCard() {
    final problems = _problemImages;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            problems.length == 1
                ? '1 photo needs attention'
                : '${problems.length} photos need attention',
            style: const TextStyle(
                color: kDangerRed, fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text('Fix these photos before continuing.',
              style: TextStyle(color: kMutedGray, fontSize: 12)),
          for (final img in problems) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(img.bytes,
                      width: 56, height: 56, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
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
                            fontSize: 12.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        img.metadata.locationProblem !=
                                PhotoLocationProblem.none
                            ? PhotoLocationRule.message(
                                img.metadata.locationProblem)
                            : img.detectionError != null
                                ? scanAnalysisFailedMessage
                                : scanNoCotsMessage,
                        style: const TextStyle(
                            color: kDangerRed, fontSize: 12, height: 1.3),
                      ),
                      if (img.detectionError != null)
                        Text(
                          img.detectionError!,
                          style:
                              const TextStyle(color: kMutedGray, fontSize: 11),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (img.metadata.locationProblem ==
                              PhotoLocationProblem.noLocation)
                            OutlinedButton.icon(
                              onPressed:
                                  _isBusy ? null : _retryPhotoLocations,
                              icon: const Icon(Icons.my_location_rounded,
                                  size: 16),
                              label: const Text('Try again'),
                            ),
                          if (img.metadata.locationProblem != PhotoLocationProblem.none)
                            OutlinedButton.icon(
                              onPressed: _isBusy ? null : () => _reviewPhotoLocation(img),
                              icon: const Icon(Icons.map_outlined, size: 16),
                              label: const Text('Review photo location'),
                            ),
                          if (img.detectionError != null)
                            OutlinedButton.icon(
                              onPressed:
                                  _isBusy ? null : () => _retryAnalysis(img),
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Retry'),
                            ),
                          TextButton.icon(
                            onPressed: _isBusy ? null : () => _removeImage(img),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 16),
                            label: const Text('Remove'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reviewPhotoLocation(_PendingScanImage image) async {
    final metadata = image.metadata;
    final original = metadata.latitude == null || metadata.longitude == null
        ? null : LatLng(metadata.latitude!, metadata.longitude!);
    await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => PhotoLocationReviewPage(
      fileName: image.fileName, original: original,
      originalSource: original == null ? 'unavailable' : metadata.gpsFromExif ? 'exif' : 'device_surface',
      capturedAt: metadata.dateTaken,
    )));
    // This view never replaces metadata or clears the location problem.
  }

  Future<void> _retryAnalysis(_PendingScanImage img) async {
    setState(() {
      _isBusy = true;
      _detectionProgress = 'Analyzing ${img.fileName}';
    });
    try {
      img.detection = await CotsYoloDetector.instance.detect(img.bytes);
      img.detectionError = null;
    } catch (e) {
      img.detection = null;
      img.detectionError = _detectionErrorMessage(e);
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _detectionProgress = null;
        });
      }
    }
  }

  void _removeImage(_PendingScanImage img) {
    setState(() {
      _images.remove(img);
      _removalConfirmed = false;
      if (_images.isEmpty) {
        _deviceGpsLat = null;
        _deviceGpsLng = null;
        _startLiveClock();
      }
    });
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

  List<DetectionPhotoPreview> get _batchPhotoPreviews => [
        for (final photo in _images)
          DetectionPhotoPreview(
            id: photo.submissionId,
            name: photo.fileName,
            bytes: photo.bytes,
            width: photo.metadata.widthPx ?? 1920,
            height: photo.metadata.heightPx ?? 1080,
            detection: photo.detection,
            error: photo.detectionError,
          ),
      ];

  Widget _buildBatchDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BatchDetectionGallery(photos: _batchPhotoPreviews),
        if (!_isFollowUp) ...[
          const Divider(height: 36, thickness: 2, color: kBorderGray),
          _buildRemovalDetails(),
        ],
      ],
    );
  }

  Widget _batchResultTile(_PendingScanImage img) {
    final count = img.detection?.count;
    final pct = CotsConfidencePolicy.percentFromConfidence(
      img.detection?.confidence ?? 0,
    );
    final failed = img.detectionError != null;
    final editing = _step == _DetectionStep.details;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (!editing) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(img.bytes,
                    width: 56, height: 56, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
            ],
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
                      editing
                          ? img.assignedZone
                          : '$count COTS \u00b7 $pct% confidence \u00b7 ${img.assignedZone}',
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
        BatchDetectionSummary(photos: _batchPhotoPreviews),
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
      final make = exif['Image Make']?.printable.trim();
      final model = exif['Image Model']?.printable.trim();
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

    final now = DateTime.now();
    // User 2026-11-06: the phone's location comes FIRST (action cameras such
    // as DJI Mimo can write a wrong or old GPS into the photo). The photo's
    // own GPS is used only when the phone has no location, when the photo is
    // over 2 hours old, or when the phone is outside every site but the photo
    // GPS is inside one.
    bool insideSite(double? lat, double? lng) =>
        lat != null &&
        lng != null &&
        DavaoGulfGeography.assignWithinMonitoringArea(
              latitude: lat,
              longitude: lng,
            ) !=
            null;
    if (PhotoLocationRule.phoneGpsAllowed(dateTaken: dateTaken, now: now)) {
      await _ensureDeviceGps();
      final phoneLat = _deviceGpsLat;
      final phoneLng = _deviceGpsLng;
      if (phoneLat != null &&
          phoneLng != null &&
          (insideSite(phoneLat, phoneLng) ||
              !insideSite(latitude, longitude))) {
        latitude = phoneLat;
        longitude = phoneLng;
        gpsFromExif = false;
      }
    }
    final hasLocation = latitude != null && longitude != null;
    final locationProblem = PhotoLocationRule.check(
      hasPhotoGps: gpsFromExif,
      hasLocation: hasLocation,
      insideArea: hasLocation &&
          DavaoGulfGeography.assignWithinMonitoringArea(
                latitude: latitude,
                longitude: longitude,
              ) !=
              null,
      dateTaken: dateTaken,
      now: now,
    );

    return _ScanImageMetadata(
      dateTaken: dateTaken,
      latitude: gpsFromExif || locationProblem != PhotoLocationProblem.tooOld
          ? latitude
          : null,
      longitude: gpsFromExif || locationProblem != PhotoLocationProblem.tooOld
          ? longitude
          : null,
      gpsFromExif: gpsFromExif,
      locationProblem: locationProblem,
      deviceLabel: deviceLabel,
      widthPx: widthPx == 0 ? null : widthPx,
      heightPx: heightPx == 0 ? null : heightPx,
    );
  }

  Future<void> _ensureDeviceGps() async {
    // Reuse a phone fix for at most 1 minute, so the location is fresh.
    final at = _deviceGpsAt;
    if (_deviceGpsLat != null &&
        _deviceGpsLng != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 1)) {
      return;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _deviceGpsLat = pos.latitude;
      _deviceGpsLng = pos.longitude;
      _deviceGpsAt = DateTime.now();
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
                      'Dive site',
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
                  hasGps
                      ? coords
                      : 'GPS unavailable — enable location or use a photo with EXIF GPS.',
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
                ? 'Matched from GPS to its dive site.'
                : 'No dive site matched — the location is on land, past the drop-off, or the photo has no GPS.',
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

/// Circular confidence gauge for scan and detection results.
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
            'Average AI confidence',
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
    this.locationProblem = PhotoLocationProblem.none,
    this.deviceLabel = 'Unknown Device',
    this.widthPx,
    this.heightPx,
  });

  final DateTime? dateTaken;
  final double? latitude;
  final double? longitude;
  final bool gpsFromExif;

  /// Stage 7: why this photo cannot be submitted yet (location), if any.
  final PhotoLocationProblem locationProblem;
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
  });

  final XFile file;
  final String submissionId = FollowUpMonitoringRepository.newSurveyId();
  String? savedCaptureId;
  final DateTime selectedAt = DateTime.now();
  final Uint8List bytes;
  final String fileName;
  _ScanImageMetadata metadata;
  CotsDetectionResult? detection;
  String? detectionError;

  DateTime get captureInstant => metadata.dateTaken ?? selectedAt;

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
