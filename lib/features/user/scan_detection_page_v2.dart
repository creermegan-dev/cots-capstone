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
import '../../services/cots_yolo_detector.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import 'user_bottom_nav.dart';

class _SelectedImage {
  _SelectedImage({
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
  String depthInput = '';
}

class ScanDetectionPage extends StatefulWidget {
  const ScanDetectionPage({super.key});

  @override
  State<ScanDetectionPage> createState() => _ScanDetectionPageState();
}

class _ScanDetectionPageState extends State<ScanDetectionPage> {
  static final _picker = ImagePicker();
  final _images = <_SelectedImage>[];
  final _depthController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _activeId;
  bool _isAnalyzing = false;
  bool _showValidation = false;
  int? _lastCount;
  double? _lastConfidence;

  _SelectedImage? get _active {
    for (final image in _images) {
      if (image.id == _activeId) return image;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _depthController.addListener(() {
      final active = _active;
      if (active != null) active.depthInput = _depthController.text;
    });
  }

  @override
  void dispose() {
    _depthController.dispose();
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
                _buildSelectionSection(),
                const SizedBox(height: 16),
                _buildPreviewSection(),
                const SizedBox(height: 16),
                _buildAnalyzeButton(),
                const SizedBox(height: 16),
                _buildImageInfoSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Selected Images (${_images.length})',
                style: const TextStyle(color: kTextNavy, fontSize: 17, fontWeight: FontWeight.w700)),
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
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 116,
        child: _images.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorderGray),
                  color: const Color(0xFFF8FAFC),
                ),
                alignment: Alignment.center,
                child: const Text('No images yet - tap Add Images', style: TextStyle(color: kMutedGray)),
              )
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, i) {
                  final image = _images[i];
                  return _Thumb(
                    image: image,
                    selected: image.id == _activeId,
                    onTap: () => _selectImage(image.id),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemCount: _images.length,
              ),
      ),
    ]);
  }

  Widget _buildPreviewSection() {
    final active = _active;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Preview', style: TextStyle(color: kTextNavy, fontSize: 16, fontWeight: FontWeight.w700)),
        if (active != null) ...[
          const SizedBox(height: 4),
          Text(active.fileName, style: const TextStyle(color: kMutedGray, fontSize: 12)),
        ],
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(aspectRatio: 16 / 10, child: _buildPreviewImage(active)),
        ),
        if (_lastCount != null && active != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: kPrimaryTeal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Last analysis: $_lastCount COTS detected'
              '${_lastConfidence != null ? ' (${(_lastConfidence! * 100).toStringAsFixed(0)}% confidence)' : ''}',
              style: const TextStyle(
                color: kDarkTeal,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildPreviewImage(_SelectedImage? active) {
    if (active == null) {
      return const ColoredBox(
        color: Color(0xFFF1F5F9),
        child: Center(child: Text('Select an image to preview', style: TextStyle(color: kMutedGray))),
      );
    }
    return FutureBuilder<Uint8List>(
      future: _loadBytes(active),
      builder: (_, snap) {
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
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: _active != null && !_isAnalyzing ? _onAnalyzePressed : null,
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

  Widget _buildImageInfoSection() {
    final active = _active;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Image Information', style: TextStyle(color: kPrimaryTeal, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        if (active == null)
          const Text('Import and select a GoPro image to view metadata.', style: TextStyle(color: kMutedGray))
        else
          FutureBuilder<void>(
            future: _ensureMetadata(active),
            builder: (_, __) {
              final d = active.dateTaken;
              final date1 = d != null ? DateFormat('MMM dd, yyyy').format(d) : '--';
              final date2 = d != null ? DateFormat('h:mm a').format(d) : '--';
              final lat1 = active.latitude != null ? '${active.latitude!.abs().toStringAsFixed(4)}° ${active.latitude! >= 0 ? 'N' : 'S'}' : '--';
              final lng1 = active.longitude != null ? '${active.longitude!.abs().toStringAsFixed(4)}° ${active.longitude! >= 0 ? 'E' : 'W'}' : '--';
              final res1 = (active.widthPx != null && active.heightPx != null) ? '${active.widthPx} x ${active.heightPx}' : '--';
              final res2 = (active.widthPx != null && active.heightPx != null)
                  ? '${((active.widthPx! * active.heightPx!) / 1000000).toStringAsFixed(1)} MP'
                  : '--';
              return Column(children: [
                LayoutBuilder(builder: (_, c) {
                  if (c.maxWidth < 540) {
                    return Column(children: [
                      _Info(icon: Icons.calendar_today_outlined, title: 'Date Taken', line1: date1, line2: date2),
                      const SizedBox(height: 10),
                      _Info(icon: Icons.location_on_outlined, title: 'Location (GPS)', line1: lat1, line2: lng1),
                      const SizedBox(height: 10),
                      _Info(icon: Icons.photo_size_select_large_outlined, title: 'Resolution', line1: res1, line2: res2),
                    ]);
                  }
                  return Row(children: [
                    Expanded(child: _Info(icon: Icons.calendar_today_outlined, title: 'Date Taken', line1: date1, line2: date2)),
                    Expanded(child: _Info(icon: Icons.location_on_outlined, title: 'Location (GPS)', line1: lat1, line2: lng1)),
                    Expanded(child: _Info(icon: Icons.photo_size_select_large_outlined, title: 'Resolution', line1: res1, line2: res2)),
                  ]);
                }),
                const SizedBox(height: 16),
                _buildDepthField(),
              ]);
            },
          ),
      ]),
    );
  }

  Widget _buildDepthField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Depth (m) *', style: TextStyle(color: kTextNavy, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Enter the depth at which the image was taken.', style: TextStyle(color: kMutedGray, fontSize: 12.5)),
      const SizedBox(height: 10),
      TextFormField(
        controller: _depthController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))],
        autovalidateMode: _showValidation ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        validator: (value) {
          if (_active == null) return null;
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
    ]);
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 92);
    if (picked.isEmpty) return;
    final added = <_SelectedImage>[];
    for (final file in picked) {
      if (_images.any((i) => i.file.path == file.path)) continue;
      added.add(_SelectedImage(
        id: '${DateTime.now().microsecondsSinceEpoch}_${added.length}',
        file: file,
        fileName: file.path.split(RegExp(r'[\\/]')).last,
      ));
    }
    if (added.isEmpty) return;
    setState(() {
      _images.addAll(added);
      _activeId ??= added.first.id;
      _showValidation = false;
    });
    _depthController.text = _active?.depthInput ?? '';
    for (final image in added) {
      await _ensureMetadata(image);
    }
    if (mounted) setState(() {});
  }

  void _selectImage(String id) {
    setState(() {
      _activeId = id;
      _showValidation = false;
    });
    _depthController.text = _active?.depthInput ?? '';
  }

  Future<Uint8List> _loadBytes(_SelectedImage image) async {
    image.bytes ??= await image.file.readAsBytes();
    return image.bytes!;
  }

  Future<void> _ensureMetadata(_SelectedImage image) async {
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
      final rawDate = exif['EXIF DateTimeOriginal']?.printable ?? exif['Image DateTime']?.printable;
      if (rawDate != null && rawDate.isNotEmpty) {
        image.dateTaken = DateFormat('yyyy:MM:dd HH:mm:ss').parse(rawDate);
      }
    } catch (_) {}
    image.metadataLoaded = true;
  }

  Future<void> _onAnalyzePressed() async {
    setState(() => _showValidation = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final active = _active;
    final depth = double.tryParse(_depthController.text.trim());
    if (active == null || depth == null) return;

    setState(() {
      _isAnalyzing = true;
      _lastCount = null;
      _lastConfidence = null;
    });

    try {
      final bytes = await _loadBytes(active);
      final result = await CotsYoloDetector.instance.detect(bytes);

      _lastCount = result.count;
      _lastConfidence = result.confidence;

      await FirebaseFirestore.instance.collection('scan_records').add({
        'image_name': active.fileName,
        'image_path': active.file.path,
        'cots_count': result.count,
        'confidence': result.confidence,
        'gps': {'latitude': active.latitude, 'longitude': active.longitude},
        'date_taken': active.dateTaken != null ? Timestamp.fromDate(active.dateTaken!) : null,
        'resolution': {'width': active.widthPx, 'height': active.heightPx},
        'capture_depth': depth,
        'capture_depth_unit': 'meters',
        'processed_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Analysis complete for ${active.fileName}: ${result.count} COTS detected.',
          ),
          backgroundColor: kPrimaryTeal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAnalyzing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Detection failed: $e\n'
            'Ensure ${CotsYoloDetector.modelAssetPath} exists in the project.',
          ),
        ),
      );
    }
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
  final _SelectedImage image;
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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: selected ? kPrimaryTeal : kBorderGray, width: selected ? 2 : 1),
            ),
            child: FutureBuilder<Uint8List>(
              future: image.bytes != null ? Future.value(image.bytes) : image.file.readAsBytes().then((b) => image.bytes = b),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryTeal));
                return Image.memory(snap.data!, fit: BoxFit.cover);
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            image.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: selected ? kPrimaryTeal : kMutedGray, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({
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
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: kMutedGray, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(line1, textAlign: TextAlign.center, style: const TextStyle(color: kTextNavy, fontWeight: FontWeight.w700)),
        Text(line2, textAlign: TextAlign.center, style: const TextStyle(color: kTextNavy, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
