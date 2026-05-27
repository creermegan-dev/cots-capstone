import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/cots_colors.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

class _SelectedGoProImage {
  _SelectedGoProImage({required this.id, required this.file, required this.fileName});

  final String id;
  final XFile file;
  final String fileName;
  Uint8List? bytes;
  DateTime? dateTaken;
  double? latitude;
  double? longitude;
  int? widthPx;
  int? heightPx;
  bool metadataLoaded = false;
  String manualDepthInput = '';
}

class ScanDetectionPage extends StatefulWidget {
  const ScanDetectionPage({super.key});

  @override
  State<ScanDetectionPage> createState() => _ScanDetectionPageState();
}

class _ScanDetectionPageState extends State<ScanDetectionPage> {
  static final _picker = ImagePicker();
  final _images = <_SelectedGoProImage>[];
  final _formKey = GlobalKey<FormState>();
  final _depthController = TextEditingController();

  String? _activeImageId;
  bool _isAnalyzing = false;
  bool _showDepthValidation = false;
  int? _lastCotsCount;
  double? _lastConfidence;

  _SelectedGoProImage? get _activeImage =>
      _images.where((img) => img.id == _activeImageId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _depthController.addListener(_syncDepthToActiveImage);
  }

  @override
  void dispose() {
    _depthController.removeListener(_syncDepthToActiveImage);
    _depthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: AppBackIconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          iconColor: kTextNavy,
        ),
        title: const Text(
          'Scan / Detection',
          style: TextStyle(color: kTextNavy, fontSize: 18, fontWeight: FontWeight.w700),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSelection(),
                const SizedBox(height: 16),
                _buildPreview(),
                const SizedBox(height: 16),
                _buildAnalyzeButton(),
                const SizedBox(height: 16),
                _buildImageInfoAndDepth(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Selected Images (${_images.length})',
                  style: const TextStyle(color: kTextNavy, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text('Choose an image to analyze', style: TextStyle(color: kMutedGray, fontSize: 13)),
              ]),
            ),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Images'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryTeal,
                side: const BorderSide(color: kPrimaryTeal, width: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 118,
          child: _images.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderGray),
                  ),
                  alignment: Alignment.center,
                  child: const Text('No images yet - tap Add Images', style: TextStyle(color: kMutedGray, fontSize: 13)),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (_, i) {
                    final image = _images[i];
                    return _Thumb(
                      image: image,
                      selected: image.id == _activeImageId,
                      onTap: () => _selectImage(image.id),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: _images.length,
                ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final active = _activeImage;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Preview', style: TextStyle(color: kTextNavy, fontSize: 16, fontWeight: FontWeight.w700)),
        if (active != null) ...[
          const SizedBox(height: 4),
          Text(active.fileName, style: const TextStyle(color: kMutedGray, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: 16 / 10, child: _buildPreviewImage(active)),
        ),
      ]),
    );
  }

  Widget _buildPreviewImage(_SelectedGoProImage? active) {
    if (active == null) {
      return const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: Center(child: Text('Select an image to preview', style: TextStyle(color: kMutedGray))),
      );
    }
    return FutureBuilder<Uint8List>(
      future: _loadBytes(active),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator(color: kPrimaryTeal));
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(snap.data!, fit: BoxFit.cover),
            if (_isAnalyzing)
              Container(
                color: Colors.black38,
                alignment: Alignment.center,
                child: const Text('Analyzing image...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyzeButton() {
    final canAnalyze = _activeImage != null && !_isAnalyzing;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: canAnalyze ? _onAnalyzePressed : null,
        icon: const Icon(Icons.auto_fix_high_rounded),
        label: const Text('Analyze Image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: kPrimaryTeal,
          disabledBackgroundColor: kPrimaryTeal.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildImageInfoAndDepth() {
    final active = _activeImage;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Image Information', style: TextStyle(color: kPrimaryTeal, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (active == null)
          const Text('Import and select a GoPro image to view metadata.', style: TextStyle(color: kMutedGray))
        else
          FutureBuilder<void>(
            future: _ensureMetadata(active),
            builder: (_, __) {
              final date = active.dateTaken;
              final date1 = date != null ? DateFormat('MMM dd, yyyy').format(date) : '--';
              final date2 = date != null ? DateFormat('h:mm a').format(date) : '--';
              final lat = active.latitude;
              final lng = active.longitude;
              final loc1 = lat != null ? '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}' : '--';
              final loc2 = lng != null ? '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}' : '--';
              final w = active.widthPx;
              final h = active.heightPx;
              final res1 = (w != null && h != null) ? '$w x $h' : '--';
              final res2 = (w != null && h != null) ? '${((w * h) / 1000000).toStringAsFixed(1)} MP' : '--';

              return Column(
                children: [
                  LayoutBuilder(builder: (context, c) {
                    final narrow = c.maxWidth < 540;
                    final items = <Widget>[
                      Expanded(child: _Info(icon: Icons.calendar_today_outlined, title: 'Date Taken', line1: date1, line2: date2)),
                      Expanded(child: _Info(icon: Icons.location_on_outlined, title: 'Location (GPS)', line1: loc1, line2: loc2)),
                      Expanded(child: _Info(icon: Icons.photo_size_select_large_outlined, title: 'Resolution', line1: res1, line2: res2)),
                    ];
                    if (narrow) {
                      return Column(
                        children: [
                          _Info(icon: Icons.calendar_today_outlined, title: 'Date Taken', line1: date1, line2: date2),
                          const SizedBox(height: 12),
                          _Info(icon: Icons.location_on_outlined, title: 'Location (GPS)', line1: loc1, line2: loc2),
                          const SizedBox(height: 12),
                          _Info(icon: Icons.photo_size_select_large_outlined, title: 'Resolution', line1: res1, line2: res2),
                        ],
                      );
                    }
                    return Row(children: items);
                  }),
                  const SizedBox(height: 16),
                  _buildDepthField(active != null),
                ],
              );
            },
          ),
      ]),
    );
  }

  Widget _buildDepthField(bool enabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Depth (m) *', style: TextStyle(color: kTextNavy, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Enter the depth at which the image was taken.', style: TextStyle(color: kMutedGray, fontSize: 12.5)),
        const SizedBox(height: 10),
        TextFormField(
          controller: _depthController,
          enabled: enabled && !_isAnalyzing,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
          autovalidateMode: _showDepthValidation ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          validator: (value) {
            if (_activeImage == null) return null;
            final raw = (value ?? '').trim();
            if (raw.isEmpty) return 'Please enter capture depth.';
            final depth = double.tryParse(raw);
            if (depth == null) return 'Please enter capture depth.';
            if (depth < 0 || depth > 100) return 'Depth must be between 0 and 100 m.';
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Enter depth',
            suffixText: 'm',
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
          ),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 92);
    if (picked.isEmpty) return;
    final newItems = <_SelectedGoProImage>[];
    for (final file in picked) {
      final name = _fileNameFromPath(file.path);
      final exists = _images.any((i) => i.file.path == file.path);
      if (exists) continue;
      newItems.add(_SelectedGoProImage(
        id: '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
        file: file,
        fileName: name,
      ));
    }
    if (newItems.isEmpty) return;
    setState(() {
      _images.addAll(newItems);
      _activeImageId ??= newItems.first.id;
      _lastCotsCount = null;
      _lastConfidence = null;
      _showDepthValidation = false;
    });
    _syncDepthFieldFromActiveImage();
    for (final image in newItems) {
      await _ensureMetadata(image);
    }
    if (mounted) setState(() {});
  }

  void _selectImage(String id) {
    setState(() {
      _activeImageId = id;
      _lastCotsCount = null;
      _lastConfidence = null;
      _showDepthValidation = false;
    });
    _syncDepthFieldFromActiveImage();
  }

  Future<Uint8List> _loadBytes(_SelectedGoProImage image) async {
    image.bytes ??= await image.file.readAsBytes();
    return image.bytes!;
  }

  Future<void> _ensureMetadata(_SelectedGoProImage image) async {
    if (image.metadataLoaded) return;
    final bytes = await _loadBytes(image);
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image.widthPx = frame.image.width;
      image.heightPx = frame.image.height;
      frame.image.dispose();
    } catch (_) {}
    try {
      final exif = await readExifFromBytes(bytes);
      image.dateTaken = _parseExifDate(exif);
      final gps = _parseExifGps(exif);
      image.latitude = gps?.$1;
      image.longitude = gps?.$2;
    } catch (_) {}
    image.metadataLoaded = true;
  }

  DateTime? _parseExifDate(Map<String, IfdTag> exif) {
    final raw = exif['EXIF DateTimeOriginal']?.printable ?? exif['Image DateTime']?.printable;
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateFormat('yyyy:MM:dd HH:mm:ss').parse(raw);
    } catch (_) {
      return null;
    }
  }

  (double, double)? _parseExifGps(Map<String, IfdTag> exif) {
    final latTag = exif['GPS GPSLatitude'];
    final lngTag = exif['GPS GPSLongitude'];
    if (latTag == null || lngTag == null) return null;
    final lat = _dmsToDecimal(latTag.values.toList());
    final lng = _dmsToDecimal(lngTag.values.toList());
    if (lat == null || lng == null) return null;
    final latRef = exif['GPS GPSLatitudeRef']?.printable;
    final lngRef = exif['GPS GPSLongitudeRef']?.printable;
    return (latRef == 'S' ? -lat : lat, lngRef == 'W' ? -lng : lng);
  }

  double? _dmsToDecimal(List<dynamic> parts) {
    if (parts.length < 3) return null;
    double value(dynamic v) {
      if (v is Ratio) return v.numerator / v.denominator;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }
    return value(parts[0]) + (value(parts[1]) / 60) + (value(parts[2]) / 3600);
  }

  Future<void> _onAnalyzePressed() async {
    setState(() => _showDepthValidation = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _analyzeSelectedImage();
  }

  Future<void> _analyzeSelectedImage() async {
    final active = _activeImage;
    final depth = double.tryParse(_depthController.text.trim());
    if (active == null || depth == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);
    await _loadBytes(active);
    await _ensureMetadata(active);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _isAnalyzing = false;
      _lastCotsCount = 5;
      _lastConfidence = 0.92;
    });

    await FirebaseFirestore.instance.collection('scan_records').add({
      'image_name': active.fileName,
      'image_path': active.file.path,
      'cots_count': _lastCotsCount,
      'confidence': _lastConfidence,
      'gps': {'latitude': active.latitude, 'longitude': active.longitude},
      'date_taken': active.dateTaken != null ? Timestamp.fromDate(active.dateTaken!) : null,
      'resolution': {
        'width': active.widthPx,
        'height': active.heightPx,
        'label': (active.widthPx != null && active.heightPx != null) ? '${active.widthPx} x ${active.heightPx}' : null,
      },
      'capture_depth': depth,
      'capture_depth_unit': 'meters',
      'processed_at': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analysis complete for ${active.fileName}: $_lastCotsCount COTS detected.'),
        backgroundColor: kPrimaryTeal,
      ),
    );
  }

  void _syncDepthToActiveImage() {
    final active = _activeImage;
    if (active == null) return;
    active.manualDepthInput = _depthController.text;
  }

  void _syncDepthFieldFromActiveImage() {
    final next = _activeImage?.manualDepthInput ?? '';
    if (_depthController.text == next) return;
    _depthController.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
  }

  String _fileNameFromPath(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : 'image.jpg';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
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

class _Thumb extends StatelessWidget {
  const _Thumb({required this.image, required this.selected, required this.onTap});
  final _SelectedGoProImage image;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(children: [
          Container(
            width: 88,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? kPrimaryTeal : kBorderGray, width: selected ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: FutureBuilder<Uint8List>(
              future: image.bytes != null ? Future.value(image.bytes) : image.file.readAsBytes().then((b) => image.bytes = b),
              builder: (_, s) {
                if (!s.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryTeal));
                return Image.memory(s.data!, fit: BoxFit.cover);
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            image.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10, color: selected ? kPrimaryTeal : kMutedGray, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.title, required this.line1, required this.line2});
  final IconData icon;
  final String title;
  final String line1;
  final String line2;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryTeal, size: 22),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: kMutedGray, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(line1, textAlign: TextAlign.center, style: const TextStyle(color: kTextNavy, fontSize: 12, fontWeight: FontWeight.w700)),
        Text(line2, textAlign: TextAlign.center, style: const TextStyle(color: kTextNavy, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/cots_colors.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

class _SelectedGoProImage {
  _SelectedGoProImage({
    required this.id,
    required this.file,
    required this.fileName,
  });

  final String id;
  final XFile file;
  final String fileName;

  Uint8List? bytes;
  DateTime? dateTaken;
  double? latitude;
  double? longitude;
  int? widthPx;
  int? heightPx;
  bool metadataLoaded = false;
  String manualDepthInput = '';
}

class ScanDetectionPage extends StatefulWidget {
  const ScanDetectionPage({super.key});

  @override
  State<ScanDetectionPage> createState() => _ScanDetectionPageState();
}

class _ScanDetectionPageState extends State<ScanDetectionPage> {
  static final _picker = ImagePicker();

  final List<_SelectedGoProImage> _images = [];
  final _depthFormKey = GlobalKey<FormState>();
  final _depthController = TextEditingController();

  String? _activeImageId;
  bool _isAnalyzing = false;
  bool _showDepthValidation = false;
  int? _lastCotsCount;
  double? _lastConfidence;

  _SelectedGoProImage? get _activeImage {
    if (_activeImageId == null) return null;
    for (final image in _images) {
      if (image.id == _activeImageId) return image;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _depthController.addListener(_syncDepthToActiveImage);
  }

  @override
  void dispose() {
    _depthController.removeListener(_syncDepthToActiveImage);
    _depthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: _buildAppBar(),
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.scan,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _depthFormKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageSelectionSection(),
                const SizedBox(height: 16),
                _buildPreviewSection(),
                const SizedBox(height: 16),
                _buildAnalyzeButton(),
                const SizedBox(height: 16),
                _buildImageInformationSection(),
                const SizedBox(height: 16),
                _buildInstructionBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: AppBackIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        iconColor: kTextNavy,
      ),
      title: const Text(
        'Scan / Detection',
        style: TextStyle(
          color: kTextNavy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'About detection',
          icon: const Icon(Icons.info_outline_rounded, color: kTextNavy),
          onPressed: _showInfoDialog,
        ),
      ],
    );
  }

  Widget _buildImageSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Images (${_images.length})',
                    style: const TextStyle(
                      color: kTextNavy,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose an image to analyze',
                    style: TextStyle(
                      color: kMutedGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Images'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryTeal,
                side: const BorderSide(color: kPrimaryTeal, width: 1.4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_images.isEmpty)
          _buildEmptyThumbnailsPlaceholder()
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final image = _images[index];
                final isSelected = image.id == _activeImageId;
                return _ThumbnailTile(
                  image: image,
                  isSelected: isSelected,
                  onTap: () => _selectImage(image.id),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyThumbnailsPlaceholder() {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderGray),
      ),
      child: const Text(
        'No images yet — tap Add Images to import GoPro photos',
        textAlign: TextAlign.center,
        style: TextStyle(color: kMutedGray, fontSize: 13),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final active = _activeImage;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Preview',
                  style: TextStyle(
                    color: kTextNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (active != null)
                TextButton.icon(
                  onPressed: () => _removeImage(active.id),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: kDangerRed,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: kDangerRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (active != null) ...[
            const SizedBox(height: 4),
            Text(
              active.fileName,
              style: const TextStyle(
                color: kMutedGray,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _buildPreviewImage(active),
            ),
          ),
          if (_lastCotsCount != null && active != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kPrimaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Last analysis: $_lastCotsCount COTS detected'
                '${_lastConfidence != null ? ' (${(_lastConfidence! * 100).toStringAsFixed(0)}% confidence)' : ''}',
                style: const TextStyle(
                  color: kDarkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewImage(_SelectedGoProImage? active) {
    if (active == null) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 40, color: kMutedGray),
            SizedBox(height: 8),
            Text(
              'Select an image to preview',
              style: TextStyle(color: kMutedGray, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _loadBytes(active),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryTeal, strokeWidth: 2),
          );
        }

        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(
            child: Text('Could not load image', style: TextStyle(color: kMutedGray)),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            if (_isAnalyzing)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Analyzing image...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildAnalyzeButton() {
    final canAnalyze = _activeImage != null && !_isAnalyzing;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: canAnalyze ? _onAnalyzePressed : null,
        icon: const Icon(Icons.auto_fix_high_rounded, size: 22),
        label: const Text(
          'Analyze Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: kPrimaryTeal,
          disabledBackgroundColor: kPrimaryTeal.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildImageInformationSection() {
    final active = _activeImage;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Image Information',
            style: TextStyle(
              color: kPrimaryTeal,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (active == null)
            const Text(
              'Import and select a GoPro image to view metadata.',
              style: TextStyle(color: kMutedGray, fontSize: 13),
            )
          else
            FutureBuilder<void>(
              future: _ensureMetadata(active),
              builder: (context, _) {
                final date = active.dateTaken;
                final dateLine1 =
                    date != null ? DateFormat('MMM dd, yyyy').format(date) : '--';
                final dateLine2 =
                    date != null ? DateFormat('h:mm a').format(date) : '--';

                final lat = active.latitude;
                final lng = active.longitude;
                final locLine1 = lat != null
                    ? '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}'
                    : '--';
                final locLine2 = lng != null
                    ? '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}'
                    : '--';

                final width = active.widthPx;
                final height = active.heightPx;
                final resLine1 =
                    width != null && height != null ? '$width x $height' : '--';
                final mp = (width != null && height != null)
                    ? '${((width * height) / 1000000).toStringAsFixed(1)} MP'
                    : '--';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 540;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _InfoColumn(
                                icon: Icons.calendar_today_outlined,
                                title: 'Date Taken',
                                line1: dateLine1,
                                line2: dateLine2,
                              ),
                              const SizedBox(height: 14),
                              _InfoColumn(
                                icon: Icons.location_on_outlined,
                                title: 'Location (GPS)',
                                line1: locLine1,
                                line2: locLine2,
                              ),
                              const SizedBox(height: 14),
                              _InfoColumn(
                                icon: Icons.photo_size_select_large_outlined,
                                title: 'Resolution',
                                line1: resLine1,
                                line2: mp,
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.calendar_today_outlined,
                                title: 'Date Taken',
                                line1: dateLine1,
                                line2: dateLine2,
                              ),
                            ),
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.location_on_outlined,
                                title: 'Location (GPS)',
                                line1: locLine1,
                                line2: locLine2,
                              ),
                            ),
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.photo_size_select_large_outlined,
                                title: 'Resolution',
                                line1: resLine1,
                                line2: mp,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDepthField(active),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDepthField(_SelectedGoProImage? active) {
    final isEnabled = active != null && !_isAnalyzing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Depth (m) *',
          style: TextStyle(
            color: kTextNavy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the depth at which the image was taken.',
          style: TextStyle(
            color: kMutedGray,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _depthController,
          enabled: isEnabled,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: false),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
          ],
          autovalidateMode: _showDepthValidation
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          validator: (value) {
            if (_activeImage == null) return null;
            final raw = value?.trim() ?? '';
            if (raw.isEmpty) return 'Please enter capture depth.';
            final depth = double.tryParse(raw);
            if (depth == null) return 'Please enter capture depth.';
            if (depth < 0 || depth > 100) {
              return 'Depth must be between 0 and 100 m.';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Enter depth',
            suffixText: 'm',
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryTeal, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDangerRed, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDangerRed, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryTeal.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: kPrimaryTeal, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Select a GoPro image, enter capture depth, and tap 'Analyze Image' "
              'to detect Crown-of-Thorns Starfish (COTS).',
              style: TextStyle(
                color: kDarkTeal,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 92);
      if (picked.isEmpty) return;

      final newItems = <_SelectedGoProImage>[];
      for (final file in picked) {
        final name = _fileNameFromPath(file.path);
        final exists = _images.any(
          (item) => item.fileName == name && item.file.path == file.path,
        );
        if (exists) continue;
        newItems.add(
          _SelectedGoProImage(
            id: '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
            file: file,
            fileName: name,
          ),
        );
      }

      if (newItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Those images are already in the list.')),
        );
        return;
      }

      setState(() {
        _images.addAll(newItems);
        _activeImageId ??= newItems.first.id;
        _lastCotsCount = null;
        _lastConfidence = null;
        _showDepthValidation = false;
      });
      _syncDepthFieldFromActiveImage();

      for (final image in newItems) {
        await _ensureMetadata(image);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  void _selectImage(String id) {
    setState(() {
      _activeImageId = id;
      _lastCotsCount = null;
      _lastConfidence = null;
      _showDepthValidation = false;
    });
    _syncDepthFieldFromActiveImage();
  }

  void _removeImage(String id) {
    setState(() {
      final index = _images.indexWhere((item) => item.id == id);
      if (index < 0) return;

      _images.removeAt(index);
      if (_activeImageId == id) {
        _activeImageId = _images.isEmpty ? null : _images.first.id;
      }
      _lastCotsCount = null;
      _lastConfidence = null;
      _showDepthValidation = false;
    });
    _syncDepthFieldFromActiveImage();
  }

  Future<Uint8List> _loadBytes(_SelectedGoProImage image) async {
    image.bytes ??= await image.file.readAsBytes();
    return image.bytes!;
  }

  Future<void> _ensureMetadata(_SelectedGoProImage image) async {
    if (image.metadataLoaded) return;
    final bytes = await _loadBytes(image);

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image.widthPx = frame.image.width;
      image.heightPx = frame.image.height;
      frame.image.dispose();
    } catch (e) {
      debugPrint('Decode size error: $e');
    }

    try {
      final exif = await readExifFromBytes(bytes);
      image.dateTaken = _parseExifDate(exif);
      final gps = _parseExifGps(exif);
      image.latitude = gps?.$1;
      image.longitude = gps?.$2;
    } catch (e) {
      debugPrint('EXIF read error: $e');
    }

    image.metadataLoaded = true;
  }

  DateTime? _parseExifDate(Map<String, IfdTag> exif) {
    final raw =
        exif['EXIF DateTimeOriginal']?.printable ?? exif['Image DateTime']?.printable;
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateFormat('yyyy:MM:dd HH:mm:ss').parse(raw);
    } catch (_) {
      return null;
    }
  }

  (double, double)? _parseExifGps(Map<String, IfdTag> exif) {
    final latTag = exif['GPS GPSLatitude'];
    final lngTag = exif['GPS GPSLongitude'];
    final latRef = exif['GPS GPSLatitudeRef']?.printable;
    final lngRef = exif['GPS GPSLongitudeRef']?.printable;
    if (latTag == null || lngTag == null) return null;

    final lat = _dmsToDecimal(latTag.values.toList());
    final lng = _dmsToDecimal(lngTag.values.toList());
    if (lat == null || lng == null) return null;

    final latSigned = latRef == 'S' ? -lat : lat;
    final lngSigned = lngRef == 'W' ? -lng : lng;
    return (latSigned, lngSigned);
  }

  double? _dmsToDecimal(List<dynamic> parts) {
    if (parts.length < 3) return null;

    double toDouble(dynamic value) {
      if (value is Ratio) return value.numerator / value.denominator;
      if (value is int) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0;
    }

    final degrees = toDouble(parts[0]);
    final minutes = toDouble(parts[1]);
    final seconds = toDouble(parts[2]);
    return degrees + (minutes / 60) + (seconds / 3600);
  }

  Future<void> _onAnalyzePressed() async {
    setState(() => _showDepthValidation = true);
    final isValid = _depthFormKey.currentState?.validate() ?? false;
    if (!isValid) return;
    await _analyzeSelectedImage();
  }

  void _syncDepthToActiveImage() {
    final active = _activeImage;
    if (active == null) return;
    active.manualDepthInput = _depthController.text;
  }

  void _syncDepthFieldFromActiveImage() {
    final nextValue = _activeImage?.manualDepthInput ?? '';
    if (_depthController.text == nextValue) return;
    _depthController.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  double? _validatedCaptureDepth() {
    final raw = _depthController.text.trim();
    if (raw.isEmpty) return null;
    final depth = double.tryParse(raw);
    if (depth == null || depth < 0 || depth > 100) return null;
    return depth;
  }

  Future<void> _saveDetectionRecord({
    required _SelectedGoProImage image,
    required int cotsCount,
    required double confidence,
    required double captureDepth,
  }) async {
    final dateTaken = image.dateTaken;
    final width = image.widthPx;
    final height = image.heightPx;
    final megapixels = (width != null && height != null)
        ? (width * height) / 1000000
        : null;

    await FirebaseFirestore.instance.collection('scan_records').add({
      'image_name': image.fileName,
      'image_path': image.file.path,
      'cots_count': cotsCount,
      'confidence': confidence,
      'gps': {
        'latitude': image.latitude,
        'longitude': image.longitude,
      },
      'date_taken': dateTaken != null ? Timestamp.fromDate(dateTaken) : null,
      'resolution': {
        'width': width,
        'height': height,
        'label': width != null && height != null ? '$width x $height' : null,
        'megapixels': megapixels,
      },
      'capture_depth': captureDepth,
      'capture_depth_unit': 'meters',
      'processed_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _analyzeSelectedImage() async {
    final active = _activeImage;
    final captureDepth = _validatedCaptureDepth();
    if (active == null || captureDepth == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      await _loadBytes(active);
      await _ensureMetadata(active);

      // Placeholder until model integration is wired in-app.
      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _lastCotsCount = 5;
        _lastConfidence = 0.92;
      });

      try {
        await _saveDetectionRecord(
          image: active,
          cotsCount: _lastCotsCount!,
          confidence: _lastConfidence!,
          captureDepth: captureDepth,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Analysis completed, but record save failed: $e'),
            ),
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Analysis complete for ${active.fileName}: $_lastCotsCount COTS detected.',
          ),
          backgroundColor: kPrimaryTeal,
        ),
      );
    } catch (e) {
      debugPrint('Analyze error: $e');
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    }
  }

  String _fileNameFromPath(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : 'image.jpg';
  }

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GoPro scan workflow'),
        content: const Text(
          'Underwater photos are captured on a GoPro, transferred to your phone, '
          'then imported here. You can add multiple images, but only the selected '
          'image is analyzed when you tap Analyze Image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: kPrimaryTeal)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.image,
    required this.isSelected,
    required this.onTap,
  });

  final _SelectedGoProImage image;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 88,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? kPrimaryTeal : kBorderGray,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected ? kSoftCardShadow : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FutureBuilder<Uint8List>(
                      future: image.bytes != null
                          ? Future.value(image.bytes)
                          : image.file.readAsBytes().then((bytes) {
                              image.bytes = bytes;
                              return bytes;
                            }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kPrimaryTeal,
                                ),
                              ),
                            ),
                          );
                        }
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      },
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: kPrimaryTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              image.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? kPrimaryTeal : kMutedGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.icon,
    required this.title,
    required this.line1,
    required this.line2,
  });

  final IconData icon;
  final String title;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryTeal, size: 22),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kMutedGray,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          line1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          line2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/cots_colors.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

/// GoPro / gallery image queued for single-image COTS analysis.
class _SelectedGoProImage {
  _SelectedGoProImage({
    required this.id,
    required this.file,
    required this.fileName,
  });

  final String id;
  final XFile file;
  final String fileName;

  Uint8List? bytes;
  DateTime? dateTaken;
  double? latitude;
  double? longitude;
  int? widthPx;
  int? heightPx;
  bool metadataLoaded = false;
  String manualDepthInput = '';
}

/// Scan workflow: import multiple GoPro images, preview one, analyze one.
class ScanDetectionPage extends StatefulWidget {
  const ScanDetectionPage({super.key});

  @override
  State<ScanDetectionPage> createState() => _ScanDetectionPageState();
}

class _ScanDetectionPageState extends State<ScanDetectionPage> {
  static final _picker = ImagePicker();

  final List<_SelectedGoProImage> _images = [];
  final _depthFormKey = GlobalKey<FormState>();
  final _depthController = TextEditingController();

  String? _activeImageId;
  bool _isAnalyzing = false;
  bool _showDepthValidation = false;
  int? _lastCotsCount;
  double? _lastConfidence;

  _SelectedGoProImage? get _activeImage {
    if (_activeImageId == null) return null;
    for (final img in _images) {
      if (img.id == _activeImageId) return img;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _depthController.addListener(_syncDepthToActiveImage);
  }

  @override
  void dispose() {
    _depthController.removeListener(_syncDepthToActiveImage);
    _depthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: _buildAppBar(),
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.scan,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _depthFormKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageSelectionSection(),
                const SizedBox(height: 16),
                _buildPreviewSection(),
                const SizedBox(height: 16),
                _buildAnalyzeButton(),
                const SizedBox(height: 16),
                _buildImageInformationSection(),
                const SizedBox(height: 16),
                _buildInstructionBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: AppBackIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        iconColor: kTextNavy,
      ),
      title: const Text(
        'Scan / Detection',
        style: TextStyle(
          color: kTextNavy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'About detection',
          icon: const Icon(Icons.info_outline_rounded, color: kTextNavy),
          onPressed: _showInfoDialog,
        ),
      ],
    );
  }

  Widget _buildImageSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Images (${_images.length})',
                    style: const TextStyle(
                      color: kTextNavy,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose an image to analyze',
                    style: TextStyle(
                      color: kMutedGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Images'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryTeal,
                side: const BorderSide(color: kPrimaryTeal, width: 1.4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_images.isEmpty)
          _buildEmptyThumbnailsPlaceholder()
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final img = _images[index];
                final isSelected = img.id == _activeImageId;
                return _ThumbnailTile(
                  image: img,
                  isSelected: isSelected,
                  onTap: () => _selectImage(img.id),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyThumbnailsPlaceholder() {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderGray),
      ),
      child: const Text(
        'No images yet — tap Add Images to import GoPro photos',
        textAlign: TextAlign.center,
        style: TextStyle(color: kMutedGray, fontSize: 13),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final active = _activeImage;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Preview',
                  style: TextStyle(
                    color: kTextNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (active != null)
                TextButton.icon(
                  onPressed: () => _removeImage(active.id),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: kDangerRed,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: kDangerRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (active != null) ...[
            const SizedBox(height: 4),
            Text(
              active.fileName,
              style: const TextStyle(
                color: kMutedGray,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _buildPreviewImage(active),
            ),
          ),
          if (_lastCotsCount != null && active != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kPrimaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Last analysis: $_lastCotsCount COTS detected'
                '${_lastConfidence != null ? ' (${(_lastConfidence! * 100).toStringAsFixed(0)}% confidence)' : ''}',
                style: const TextStyle(
                  color: kDarkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewImage(_SelectedGoProImage? active) {
    if (active == null) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 40, color: kMutedGray),
            SizedBox(height: 8),
            Text(
              'Select an image to preview',
              style: TextStyle(color: kMutedGray, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _loadBytes(active),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryTeal, strokeWidth: 2),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(
            child: Text('Could not load image', style: TextStyle(color: kMutedGray)),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            if (_isAnalyzing)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Analyzing image...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildAnalyzeButton() {
    final canAnalyze = _activeImage != null && !_isAnalyzing;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: canAnalyze ? _onAnalyzePressed : null,
        icon: const Icon(Icons.auto_fix_high_rounded, size: 22),
        label: const Text(
          'Analyze Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: kPrimaryTeal,
          disabledBackgroundColor: kPrimaryTeal.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildImageInformationSection() {
    final active = _activeImage;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Image Information',
            style: TextStyle(
              color: kPrimaryTeal,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (active == null)
            const Text(
              'Import and select a GoPro image to view metadata.',
              style: TextStyle(color: kMutedGray, fontSize: 13),
            )
          else
            FutureBuilder<void>(
              future: _ensureMetadata(active),
              builder: (context, _) {
                final date = active.dateTaken;
                final dateLine1 =
                    date != null ? DateFormat('MMM dd, yyyy').format(date) : '--';
                final dateLine2 =
                    date != null ? DateFormat('h:mm a').format(date) : '--';

                final lat = active.latitude;
                final lng = active.longitude;
                final locLine1 = lat != null
                    ? '${lat.abs().toStringAsFixed(4)} deg ${lat >= 0 ? 'N' : 'S'}'
                    : '--';
                final locLine2 = lng != null
                    ? '${lng.abs().toStringAsFixed(4)} deg ${lng >= 0 ? 'E' : 'W'}'
                    : '--';

                final w = active.widthPx;
                final h = active.heightPx;
                final resLine1 = w != null && h != null ? '$w x $h' : '--';
                final mp = (w != null && h != null)
                    ? '${((w * h) / 1000000).toStringAsFixed(1)} MP'
                    : '--';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 540;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _InfoColumn(
                                icon: Icons.calendar_today_outlined,
                                title: 'Date Taken',
                                line1: dateLine1,
                                line2: dateLine2,
                              ),
                              const SizedBox(height: 14),
                              _InfoColumn(
                                icon: Icons.location_on_outlined,
                                title: 'Location (GPS)',
                                line1: locLine1,
                                line2: locLine2,
                              ),
                              const SizedBox(height: 14),
                              _InfoColumn(
                                icon: Icons.photo_size_select_large_outlined,
                                title: 'Resolution',
                                line1: resLine1,
                                line2: mp,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.calendar_today_outlined,
                                title: 'Date Taken',
                                line1: dateLine1,
                                line2: dateLine2,
                              ),
                            ),
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.location_on_outlined,
                                title: 'Location (GPS)',
                                line1: locLine1,
                                line2: locLine2,
                              ),
                            ),
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.photo_size_select_large_outlined,
                                title: 'Resolution',
                                line1: resLine1,
                                line2: mp,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDepthField(active),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDepthField(_SelectedGoProImage? active) {
    final isEnabled = active != null && !_isAnalyzing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Depth (m) *',
          style: TextStyle(
            color: kTextNavy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the depth at which the image was taken.',
          style: TextStyle(
            color: kMutedGray,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _depthController,
          enabled: isEnabled,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: false),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
          ],
          autovalidateMode: _showDepthValidation
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          validator: (value) {
            if (_activeImage == null) return null;
            final raw = value?.trim() ?? '';
            if (raw.isEmpty) return 'Please enter capture depth.';
            final depth = double.tryParse(raw);
            if (depth == null) return 'Please enter capture depth.';
            if (depth < 0 || depth > 100) {
              return 'Depth must be between 0 and 100 m.';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Enter depth',
            suffixText: 'm',
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryTeal, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDangerRed, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDangerRed, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryTeal.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: kPrimaryTeal, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Select a GoPro image, enter capture depth, and tap 'Analyze Image' "
              'to detect Crown-of-Thorns Starfish (COTS).',
              style: TextStyle(
                color: kDarkTeal,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 92);
      if (picked.isEmpty) return;

      final newItems = <_SelectedGoProImage>[];
      for (final file in picked) {
        final name = _fileNameFromPath(file.path);
        final exists =
            _images.any((i) => i.fileName == name && i.file.path == file.path);
        if (exists) continue;
        newItems.add(
          _SelectedGoProImage(
            id: '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
            file: file,
            fileName: name,
          ),
        );
      }

      if (newItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Those images are already in the list.')),
        );
        return;
      }

      setState(() {
        _images.addAll(newItems);
        _activeImageId ??= newItems.first.id;
        _lastCotsCount = null;
        _lastConfidence = null;
      });
      _syncDepthFieldFromActiveImage();

      for (final img in newItems) {
        await _ensureMetadata(img);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  void _selectImage(String id) {
    setState(() {
      _activeImageId = id;
      _lastCotsCount = null;
      _lastConfidence = null;
      _showDepthValidation = false;
    });
    _syncDepthFieldFromActiveImage();
  }

  void _removeImage(String id) {
    setState(() {
      final index = _images.indexWhere((i) => i.id == id);
      if (index < 0) return;
      _images.removeAt(index);
      if (_activeImageId == id) {
        _activeImageId = _images.isEmpty ? null : _images.first.id;
      }
      _lastCotsCount = null;
      _lastConfidence = null;
      _showDepthValidation = false;
    });
    _syncDepthFieldFromActiveImage();
  }

  Future<Uint8List> _loadBytes(_SelectedGoProImage image) async {
    image.bytes ??= await image.file.readAsBytes();
    return image.bytes!;
  }

  Future<void> _ensureMetadata(_SelectedGoProImage image) async {
    if (image.metadataLoaded) return;
    final bytes = await _loadBytes(image);

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image.widthPx = frame.image.width;
      image.heightPx = frame.image.height;
      frame.image.dispose();
    } catch (e) {
      debugPrint('Decode size error: $e');
    }

    try {
      final exif = await readExifFromBytes(bytes);
      image.dateTaken = _parseExifDate(exif);
      final gps = _parseExifGps(exif);
      image.latitude = gps.$1;
      image.longitude = gps.$2;
    } catch (e) {
      debugPrint('EXIF read error: $e');
    }

    image.metadataLoaded = true;
  }

  DateTime? _parseExifDate(Map<String, IfdTag> exif) {
    final raw =
        exif['EXIF DateTimeOriginal']?.printable ?? exif['Image DateTime']?.printable;
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateFormat('yyyy:MM:dd HH:mm:ss').parse(raw);
    } catch (_) {
      return null;
    }
  }

  (double, double) _parseExifGps(Map<String, IfdTag> exif) {
    final latTag = exif['GPS GPSLatitude'];
    final lngTag = exif['GPS GPSLongitude'];
    final latRef = exif['GPS GPSLatitudeRef']?.printable;
    final lngRef = exif['GPS GPSLongitudeRef']?.printable;
    if (latTag == null || lngTag == null) return (double.nan, double.nan);

    final lat = _dmsToDecimal(latTag.values.toList());
    final lng = _dmsToDecimal(lngTag.values.toList());
    if (lat == null || lng == null) return (double.nan, double.nan);

    final latSigned = latRef == 'S' ? -lat : lat;
    final lngSigned = lngRef == 'W' ? -lng : lng;
    return (latSigned, lngSigned);
  }

  double? _dmsToDecimal(List<dynamic> parts) {
    if (parts.length < 3) return null;
    double toDouble(dynamic v) {
      if (v is Ratio) return v.numerator / v.denominator;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final d = toDouble(parts[0]);
    final m = toDouble(parts[1]);
    final s = toDouble(parts[2]);
    return d + (m / 60) + (s / 3600);
  }

  Future<void> _onAnalyzePressed() async {
    setState(() => _showDepthValidation = true);
    final valid = _depthFormKey.currentState?.validate() ?? false;
    if (!valid) return;
    await _analyzeSelectedImage();
  }

  void _syncDepthToActiveImage() {
    final active = _activeImage;
    if (active == null) return;
    active.manualDepthInput = _depthController.text;
  }

  void _syncDepthFieldFromActiveImage() {
    final nextValue = _activeImage?.manualDepthInput ?? '';
    if (_depthController.text == nextValue) return;
    _depthController.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  double? _validatedCaptureDepth() {
    final raw = _depthController.text.trim();
    if (raw.isEmpty) return null;
    final depth = double.tryParse(raw);
    if (depth == null || depth < 0 || depth > 100) return null;
    return depth;
  }

  Future<void> _saveDetectionRecord({
    required _SelectedGoProImage image,
    required int cotsCount,
    required double confidence,
    required double captureDepth,
  }) async {
    final dateTaken = image.dateTaken;
    final width = image.widthPx;
    final height = image.heightPx;
    final megapixels = (width != null && height != null)
        ? (width * height) / 1000000
        : null;

    final hasValidLat = image.latitude != null && image.latitude!.isFinite;
    final hasValidLng = image.longitude != null && image.longitude!.isFinite;

    await FirebaseFirestore.instance.collection('scan_records').add({
      'image_name': image.fileName,
      'image_path': image.file.path,
      'cots_count': cotsCount,
      'confidence': confidence,
      'gps': {
        'latitude': hasValidLat ? image.latitude : null,
        'longitude': hasValidLng ? image.longitude : null,
      },
      'date_taken': dateTaken != null ? Timestamp.fromDate(dateTaken) : null,
      'resolution': {
        'width': width,
        'height': height,
        'label': width != null && height != null ? '$width x $height' : null,
        'megapixels': megapixels,
      },
      'capture_depth': captureDepth,
      'capture_depth_unit': 'meters',
      'processed_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _analyzeSelectedImage() async {
    final active = _activeImage;
    final captureDepth = _validatedCaptureDepth();
    if (active == null || captureDepth == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      await _loadBytes(active);
      await _ensureMetadata(active);

      // Placeholder until Roboflow / TFLite model is wired in the app.
      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _lastCotsCount = 5;
        _lastConfidence = 0.92;
      });

      try {
        await _saveDetectionRecord(
          image: active,
          cotsCount: _lastCotsCount!,
          confidence: _lastConfidence!,
          captureDepth: captureDepth,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Analysis completed, but record save failed: $e'),
            ),
          );
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Analysis complete for ${active.fileName}: $_lastCotsCount COTS detected.',
          ),
          backgroundColor: kPrimaryTeal,
        ),
      );
    } catch (e) {
      debugPrint('Analyze error: $e');
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    }
  }

  String _fileNameFromPath(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : 'image.jpg';
  }

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GoPro scan workflow'),
        content: const Text(
          'Underwater photos are captured on a GoPro, transferred to your phone, '
          'then imported here. You can add multiple images, but only the selected '
          'image is analyzed when you tap Analyze Image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: kPrimaryTeal)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.image,
    required this.isSelected,
    required this.onTap,
  });

  final _SelectedGoProImage image;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 88,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? kPrimaryTeal : kBorderGray,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected ? kSoftCardShadow : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FutureBuilder<Uint8List>(
                      future: image.bytes != null
                          ? Future.value(image.bytes)
                          : image.file.readAsBytes().then((b) {
                              image.bytes = b;
                              return b;
                            }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kPrimaryTeal,
                                ),
                              ),
                            ),
                          );
                        }
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      },
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: kPrimaryTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              image.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? kPrimaryTeal : kMutedGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.icon,
    required this.title,
    required this.line1,
    required this.line2,
  });

  final IconData icon;
  final String title;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryTeal, size: 22),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kMutedGray,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          line1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          line2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/cots_colors.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

/// GoPro / gallery image queued for single-image COTS analysis.
class _SelectedGoProImage {
  _SelectedGoProImage({
    required this.id,
    required this.file,
    required this.fileName,
  });

  final String id;
  final XFile file;
  final String fileName;

  Uint8List? bytes;
  DateTime? dateTaken;
  double? latitude;
  double? longitude;
  int? widthPx;
  int? heightPx;
  bool metadataLoaded = false;
}

/// Scan workflow: import multiple GoPro images, preview one, analyze one.
class ScanDetectionPage extends StatefulWidget {
  const ScanDetectionPage({super.key});

  @override
  State<ScanDetectionPage> createState() => _ScanDetectionPageState();
}

class _ScanDetectionPageState extends State<ScanDetectionPage> {
  static final _picker = ImagePicker();

  final List<_SelectedGoProImage> _images = [];
  String? _activeImageId;
  bool _isAnalyzing = false;
  int? _lastCotsCount;
  double? _lastConfidence;
  final _depthFormKey = GlobalKey<FormState>();
  final _depthController = TextEditingController();
  bool _showDepthValidation = false;

  _SelectedGoProImage? get _activeImage {
    if (_activeImageId == null) return null;
    for (final img in _images) {
      if (img.id == _activeImageId) return img;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _depthController.addListener(_syncDepthToActiveImage);
  }

  @override
  void dispose() {
    _depthController.removeListener(_syncDepthToActiveImage);
    _depthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: _buildAppBar(),
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.scan,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _depthFormKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildImageSelectionSection(),
                const SizedBox(height: 16),
                _buildPreviewSection(),
                const SizedBox(height: 16),
                _buildAnalyzeButton(),
                const SizedBox(height: 16),
                _buildImageInformationSection(),
                const SizedBox(height: 16),
                _buildInstructionBox(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      scrolledUnderElevation: 0,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: AppBackIconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        iconColor: kTextNavy,
      ),
      title: const Text(
        'Scan / Detection',
        style: TextStyle(
          color: kTextNavy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          tooltip: 'About detection',
          icon: const Icon(Icons.info_outline_rounded, color: kTextNavy),
          onPressed: _showInfoDialog,
        ),
      ],
    );
  }

  Widget _buildImageSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected Images (${_images.length})',
                    style: const TextStyle(
                      color: kTextNavy,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose an image to analyze',
                    style: TextStyle(
                      color: kMutedGray,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Images'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimaryTeal,
                side: const BorderSide(color: kPrimaryTeal, width: 1.4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (_images.isEmpty)
          _buildEmptyThumbnailsPlaceholder()
        else
          SizedBox(
            height: 118,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final img = _images[index];
                final isSelected = img.id == _activeImageId;
                return _ThumbnailTile(
                  image: img,
                  isSelected: isSelected,
                  onTap: () => _selectImage(img.id),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyThumbnailsPlaceholder() {
    return Container(
      height: 100,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderGray),
      ),
      child: const Text(
        'No images yet — tap Add Images to import GoPro photos',
        textAlign: TextAlign.center,
        style: TextStyle(color: kMutedGray, fontSize: 13),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final active = _activeImage;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Preview',
                  style: TextStyle(
                    color: kTextNavy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (active != null)
                TextButton.icon(
                  onPressed: () => _removeImage(active.id),
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: kDangerRed),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      color: kDangerRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (active != null) ...[
            const SizedBox(height: 4),
            Text(
              active.fileName,
              style: const TextStyle(
                color: kMutedGray,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: _buildPreviewImage(active),
            ),
          ),
          if (_lastCotsCount != null && active != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kPrimaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Last analysis: $_lastCotsCount COTS detected'
                '${_lastConfidence != null ? ' (${(_lastConfidence! * 100).toStringAsFixed(0)}% confidence)' : ''}',
                style: const TextStyle(
                  color: kDarkTeal,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewImage(_SelectedGoProImage? active) {
    if (active == null) {
      return Container(
        color: const Color(0xFFF1F5F9),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 40, color: kMutedGray),
            SizedBox(height: 8),
            Text(
              'Select an image to preview',
              style: TextStyle(color: kMutedGray, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Uint8List>(
      future: _loadBytes(active),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimaryTeal, strokeWidth: 2),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null) {
          return const Center(
            child: Text('Could not load image', style: TextStyle(color: kMutedGray)),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            if (_isAnalyzing)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'Analyzing image…',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _buildAnalyzeButton() {
    final canAnalyze = _activeImage != null && !_isAnalyzing;
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: canAnalyze ? _onAnalyzePressed : null,
        icon: const Icon(Icons.auto_fix_high_rounded, size: 22),
        label: const Text(
          'Analyze Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: kPrimaryTeal,
          disabledBackgroundColor: kPrimaryTeal.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildImageInformationSection() {
    final active = _activeImage;
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Image Information',
            style: TextStyle(
              color: kPrimaryTeal,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (active == null)
            const Text(
              'Import and select a GoPro image to view metadata.',
              style: TextStyle(color: kMutedGray, fontSize: 13),
            )
          else
            FutureBuilder<void>(
              future: _ensureMetadata(active),
              builder: (context, _) {
                final date = active.dateTaken;
                final dateLine1 = date != null
                    ? DateFormat('MMM dd, yyyy').format(date)
                    : '--';
                final dateLine2 =
                    date != null ? DateFormat('h:mm a').format(date) : '--';

                final lat = active.latitude;
                final lng = active.longitude;
                final locLine1 = lat != null
                    ? '${lat.abs().toStringAsFixed(4)}° ${lat >= 0 ? 'N' : 'S'}'
                    : '--';
                final locLine2 = lng != null
                    ? '${lng.abs().toStringAsFixed(4)}° ${lng >= 0 ? 'E' : 'W'}'
                    : '--';

                final w = active.widthPx;
                final h = active.heightPx;
                final resLine1 =
                    w != null && h != null ? '$w x $h' : '--';
                final mp = (w != null && h != null)
                    ? '${((w * h) / 1000000).toStringAsFixed(1)} MP'
                    : '--';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 540;
                        if (isNarrow) {
                          return Column(
                            children: [
                              _InfoColumn(
                                icon: Icons.calendar_today_outlined,
                                title: 'Date Taken',
                                line1: dateLine1,
                                line2: dateLine2,
                              ),
                              const SizedBox(height: 14),
                              _InfoColumn(
                                icon: Icons.location_on_outlined,
                                title: 'Location (GPS)',
                                line1: locLine1,
                                line2: locLine2,
                              ),
                              const SizedBox(height: 14),
                              _InfoColumn(
                                icon: Icons.photo_size_select_large_outlined,
                                title: 'Resolution',
                                line1: resLine1,
                                line2: mp,
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.calendar_today_outlined,
                                title: 'Date Taken',
                                line1: dateLine1,
                                line2: dateLine2,
                              ),
                            ),
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.location_on_outlined,
                                title: 'Location (GPS)',
                                line1: locLine1,
                                line2: locLine2,
                              ),
                            ),
                            Expanded(
                              child: _InfoColumn(
                                icon: Icons.photo_size_select_large_outlined,
                                title: 'Resolution',
                                line1: resLine1,
                                line2: mp,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildDepthField(active),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDepthField(_SelectedGoProImage? active) {
    final isEnabled = active != null && !_isAnalyzing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Depth (m) *',
          style: TextStyle(
            color: kTextNavy,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Enter the depth at which the image was taken.',
          style: TextStyle(
            color: kMutedGray,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _depthController,
          enabled: isEnabled,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true, signed: false),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
          ],
          autovalidateMode: _showDepthValidation
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          validator: (value) {
            if (_activeImage == null) return null;
            final raw = value?.trim() ?? '';
            if (raw.isEmpty) return 'Please enter capture depth.';
            final depth = double.tryParse(raw);
            if (depth == null) return 'Please enter capture depth.';
            if (depth < 0 || depth > 100) {
              return 'Depth must be between 0 and 100 m.';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Enter depth',
            suffixText: 'm',
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kBorderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimaryTeal, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDangerRed, width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kDangerRed, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _onAnalyzePressed() async {
    setState(() => _showDepthValidation = true);
    final isValid = _depthFormKey.currentState?.validate() ?? false;
    if (!isValid) return;
    await _analyzeSelectedImage();
  }

  void _syncDepthToActiveImage() {
    final active = _activeImage;
    if (active == null) return;
    active.manualDepthInput = _depthController.text;
  }

  void _syncDepthFieldFromActiveImage() {
    final nextValue = _activeImage?.manualDepthInput ?? '';
    if (_depthController.text == nextValue) return;
    _depthController.value = TextEditingValue(
      text: nextValue,
      selection: TextSelection.collapsed(offset: nextValue.length),
    );
  }

  double? _validatedCaptureDepth() {
    final raw = _depthController.text.trim();
    if (raw.isEmpty) return null;
    final depth = double.tryParse(raw);
    if (depth == null || depth < 0 || depth > 100) return null;
    return depth;
  }

  Future<void> _saveDetectionRecord({
    required _SelectedGoProImage image,
    required int cotsCount,
    required double confidence,
    required double captureDepth,
  }) async {
    final dateTaken = image.dateTaken;
    final width = image.widthPx;
    final height = image.heightPx;
    final megapixels = (width != null && height != null)
        ? (width * height) / 1000000
        : null;
    await FirebaseFirestore.instance.collection('scan_records').add({
      'image_name': image.fileName,
      'image_path': image.file.path,
      'cots_count': cotsCount,
      'confidence': confidence,
      'gps': {
        'latitude': image.latitude,
        'longitude': image.longitude,
      },
      'date_taken': dateTaken != null ? Timestamp.fromDate(dateTaken) : null,
      'resolution': {
        'width': width,
        'height': height,
        'label': width != null && height != null ? '$width x $height' : null,
        'megapixels': megapixels,
      },
      'capture_depth': captureDepth,
      'capture_depth_unit': 'meters',
      'processed_at': FieldValue.serverTimestamp(),
    });
  }

  void _showSaveWarning(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Analysis completed, but record save failed: $e'),
      ),
    );
  }

  Widget _buildInstructionBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryTeal.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: kPrimaryTeal, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Select a GoPro image, enter capture depth, and tap 'Analyze Image' "
              'to detect Crown-of-Thorns Starfish (COTS).',
              style: TextStyle(
                color: kDarkTeal,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 92);
      if (picked.isEmpty) return;

      final newItems = <_SelectedGoProImage>[];
      for (final file in picked) {
        final name = _fileNameFromPath(file.path);
        final exists = _images.any((i) => i.fileName == name && i.file.path == file.path);
        if (exists) continue;
        newItems.add(_SelectedGoProImage(
          id: '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
          file: file,
          fileName: name,
        ));
      }

      if (newItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Those images are already in the list.')),
        );
        return;
      }

      setState(() {
        _images.addAll(newItems);
        _activeImageId ??= newItems.first.id;
        _lastCotsCount = null;
        _lastConfidence = null;
      });
      _syncDepthFieldFromActiveImage();

      for (final img in newItems) {
        await _ensureMetadata(img);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  void _selectImage(String id) {
    setState(() {
      _activeImageId = id;
      _lastCotsCount = null;
      _lastConfidence = null;
    });
    _syncDepthFieldFromActiveImage();
  }

  void _removeImage(String id) {
    setState(() {
      final index = _images.indexWhere((i) => i.id == id);
      if (index < 0) return;
      _images.removeAt(index);
      if (_activeImageId == id) {
        _activeImageId = _images.isEmpty ? null : _images.first.id;
      }
      _lastCotsCount = null;
      _lastConfidence = null;
    });
    _syncDepthFieldFromActiveImage();
  }

  Future<Uint8List> _loadBytes(_SelectedGoProImage image) async {
    image.bytes ??= await image.file.readAsBytes();
    return image.bytes!;
  }

  Future<void> _ensureMetadata(_SelectedGoProImage image) async {
    if (image.metadataLoaded) return;
    final bytes = await _loadBytes(image);

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image.widthPx = frame.image.width;
      image.heightPx = frame.image.height;
      frame.image.dispose();
    } catch (e) {
      debugPrint('Decode size error: $e');
    }

    try {
      final exif = await readExifFromBytes(bytes);
      image.dateTaken = _parseExifDate(exif);
      final gps = _parseExifGps(exif);
      image.latitude = gps?.$1;
      image.longitude = gps?.$2;
    } catch (e) {
      debugPrint('EXIF read error: $e');
    }

    image.metadataLoaded = true;
  }

  DateTime? _parseExifDate(Map<String, IfdTag> exif) {
    final raw = exif['EXIF DateTimeOriginal']?.printable ??
        exif['Image DateTime']?.printable;
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateFormat('yyyy:MM:dd HH:mm:ss').parse(raw);
    } catch (_) {
      return null;
    }
  }

  (double, double)? _parseExifGps(Map<String, IfdTag> exif) {
    final latTag = exif['GPS GPSLatitude'];
    final lngTag = exif['GPS GPSLongitude'];
    final latRef = exif['GPS GPSLatitudeRef']?.printable;
    final lngRef = exif['GPS GPSLongitudeRef']?.printable;
    if (latTag == null || lngTag == null) return null;

    final lat = _dmsToDecimal(latTag.values.toList());
    final lng = _dmsToDecimal(lngTag.values.toList());
    if (lat == null || lng == null) return null;

    final latSigned = latRef == 'S' ? -lat : lat;
    final lngSigned = lngRef == 'W' ? -lng : lng;
    return (latSigned, lngSigned);
  }

  double? _dmsToDecimal(List<dynamic> parts) {
    if (parts.length < 3) return null;
    double toDouble(dynamic v) {
      if (v is Ratio) return v.numerator / v.denominator;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final d = toDouble(parts[0]);
    final m = toDouble(parts[1]);
    final s = toDouble(parts[2]);
    return d + (m / 60) + (s / 3600);
  }

  Future<void> _analyzeSelectedImage() async {
    final active = _activeImage;
    final captureDepth = _validatedCaptureDepth();
    if (active == null || captureDepth == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      await _loadBytes(active);
      await _ensureMetadata(active);
      // Placeholder until Roboflow / TFLite model is wired in the app.
      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _lastCotsCount = 5;
        _lastConfidence = 0.92;
      });

      try {
        await _saveDetectionRecord(
          image: active,
          cotsCount: _lastCotsCount!,
          confidence: _lastConfidence!,
          captureDepth: captureDepth,
        );
      } catch (e) {
        if (mounted) _showSaveWarning(e);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Analysis complete for ${active.fileName}: $_lastCotsCount COTS detected.',
          ),
          backgroundColor: kPrimaryTeal,
        ),
      );
    } catch (e) {
      debugPrint('Analyze error: $e');
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    }
  }

  String _fileNameFromPath(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : 'image.jpg';
  }

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GoPro scan workflow'),
        content: const Text(
          'Underwater photos are captured on a GoPro, transferred to your phone, '
          'then imported here. You can add multiple images, but only the selected '
          'image is analyzed when you tap Analyze Image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: kPrimaryTeal)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.image,
    required this.isSelected,
    required this.onTap,
  });

  final _SelectedGoProImage image;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 88,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? kPrimaryTeal : kBorderGray,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected ? kSoftCardShadow : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FutureBuilder<Uint8List>(
                      future: image.bytes != null
                          ? Future.value(image.bytes)
                          : image.file.readAsBytes().then((b) {
                              image.bytes = b;
                              return b;
                            }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kPrimaryTeal,
                                ),
                              ),
                            ),
                          );
                        }
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      },
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: kPrimaryTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              image.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? kPrimaryTeal : kMutedGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.icon,
    required this.title,
    required this.line1,
    required this.line2,
  });

  final IconData icon;
  final String title;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryTeal, size: 22),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kMutedGray,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          line1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          line2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
                      ),
                    ),
                    Expanded(
                      child: _InfoColumn(
                        icon: Icons.location_on_outlined,
                        title: 'Location (GPS)',
                        line1: locLine1,
                        line2: locLine2,
                      ),
                    ),
                    Expanded(
                      child: _InfoColumn(
                        icon: Icons.photo_size_select_large_outlined,
                        title: 'Resolution',
                        line1: resLine1,
                        line2: mp,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kPrimaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryTeal.withValues(alpha: 0.2)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: kPrimaryTeal, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Select an image and tap 'Analyze Image' to detect "
              'Crown-of-Thorns Starfish (COTS).',
              style: TextStyle(
                color: kDarkTeal,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 92);
      if (picked.isEmpty) return;

      final newItems = <_SelectedGoProImage>[];
      for (final file in picked) {
        final name = _fileNameFromPath(file.path);
        final exists = _images.any((i) => i.fileName == name && i.file.path == file.path);
        if (exists) continue;
        newItems.add(_SelectedGoProImage(
          id: '${DateTime.now().microsecondsSinceEpoch}_${newItems.length}',
          file: file,
          fileName: name,
        ));
      }

      if (newItems.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Those images are already in the list.')),
        );
        return;
      }

      setState(() {
        _images.addAll(newItems);
        _activeImageId ??= newItems.first.id;
        _lastCotsCount = null;
        _lastConfidence = null;
      });

      for (final img in newItems) {
        await _ensureMetadata(img);
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Image pick error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gallery: $e')),
      );
    }
  }

  void _selectImage(String id) {
    setState(() {
      _activeImageId = id;
      _lastCotsCount = null;
      _lastConfidence = null;
    });
  }

  void _removeImage(String id) {
    setState(() {
      final index = _images.indexWhere((i) => i.id == id);
      if (index < 0) return;
      _images.removeAt(index);
      if (_activeImageId == id) {
        _activeImageId = _images.isEmpty ? null : _images.first.id;
      }
      _lastCotsCount = null;
      _lastConfidence = null;
    });
  }

  Future<Uint8List> _loadBytes(_SelectedGoProImage image) async {
    image.bytes ??= await image.file.readAsBytes();
    return image.bytes!;
  }

  Future<void> _ensureMetadata(_SelectedGoProImage image) async {
    if (image.metadataLoaded) return;
    final bytes = await _loadBytes(image);

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      image.widthPx = frame.image.width;
      image.heightPx = frame.image.height;
      frame.image.dispose();
    } catch (e) {
      debugPrint('Decode size error: $e');
    }

    try {
      final exif = await readExifFromBytes(bytes);
      image.dateTaken = _parseExifDate(exif);
      final gps = _parseExifGps(exif);
      image.latitude = gps?.$1;
      image.longitude = gps?.$2;
    } catch (e) {
      debugPrint('EXIF read error: $e');
    }

    image.metadataLoaded = true;
  }

  DateTime? _parseExifDate(Map<String, IfdTag> exif) {
    final raw = exif['EXIF DateTimeOriginal']?.printable ??
        exif['Image DateTime']?.printable;
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateFormat('yyyy:MM:dd HH:mm:ss').parse(raw);
    } catch (_) {
      return null;
    }
  }

  (double, double)? _parseExifGps(Map<String, IfdTag> exif) {
    final latTag = exif['GPS GPSLatitude'];
    final lngTag = exif['GPS GPSLongitude'];
    final latRef = exif['GPS GPSLatitudeRef']?.printable;
    final lngRef = exif['GPS GPSLongitudeRef']?.printable;
    if (latTag == null || lngTag == null) return null;

    final lat = _dmsToDecimal(latTag.values.toList());
    final lng = _dmsToDecimal(lngTag.values.toList());
    if (lat == null || lng == null) return null;

    final latSigned = latRef == 'S' ? -lat : lat;
    final lngSigned = lngRef == 'W' ? -lng : lng;
    return (latSigned, lngSigned);
  }

  double? _dmsToDecimal(List<dynamic> parts) {
    if (parts.length < 3) return null;
    double toDouble(dynamic v) {
      if (v is Ratio) return v.numerator / v.denominator;
      if (v is int) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final d = toDouble(parts[0]);
    final m = toDouble(parts[1]);
    final s = toDouble(parts[2]);
    return d + (m / 60) + (s / 3600);
  }

  Future<void> _analyzeSelectedImage() async {
    final active = _activeImage;
    if (active == null || _isAnalyzing) return;

    setState(() => _isAnalyzing = true);

    try {
      await _loadBytes(active);
      // Placeholder until Roboflow / TFLite model is wired in the app.
      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _lastCotsCount = 5;
        _lastConfidence = 0.92;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Analysis complete for ${active.fileName}: $_lastCotsCount COTS detected.',
          ),
          backgroundColor: kPrimaryTeal,
        ),
      );
    } catch (e) {
      debugPrint('Analyze error: $e');
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis failed: $e')),
      );
    }
  }

  String _fileNameFromPath(String path) {
    final segments = path.split(RegExp(r'[\\/]'));
    return segments.isNotEmpty ? segments.last : 'image.jpg';
  }

  void _showInfoDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('GoPro scan workflow'),
        content: const Text(
          'Underwater photos are captured on a GoPro, transferred to your phone, '
          'then imported here. You can add multiple images, but only the selected '
          'image is analyzed when you tap Analyze Image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: kPrimaryTeal)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
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

class _ThumbnailTile extends StatelessWidget {
  const _ThumbnailTile({
    required this.image,
    required this.isSelected,
    required this.onTap,
  });

  final _SelectedGoProImage image;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 88,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? kPrimaryTeal : kBorderGray,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected ? kSoftCardShadow : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: FutureBuilder<Uint8List>(
                      future: image.bytes != null
                          ? Future.value(image.bytes)
                          : image.file.readAsBytes().then((b) {
                              image.bytes = b;
                              return b;
                            }),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: kPrimaryTeal,
                                ),
                              ),
                            ),
                          );
                        }
                        return Image.memory(snapshot.data!, fit: BoxFit.cover);
                      },
                    ),
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: kPrimaryTeal,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              image.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? kPrimaryTeal : kMutedGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.icon,
    required this.title,
    required this.line1,
    required this.line2,
  });

  final IconData icon;
  final String title;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: kPrimaryTeal, size: 22),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kMutedGray,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          line1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          line2,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: kTextNavy,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
