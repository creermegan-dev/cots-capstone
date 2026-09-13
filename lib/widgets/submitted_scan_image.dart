import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/record_collection.dart';
import '../services/scan_record_image_loader.dart';

/// Loads a submitted scan image via local path, download URL, or Storage object path.
class SubmittedScanImage extends StatefulWidget {
  const SubmittedScanImage({
    super.key,
    this.imageUrl,
    this.imagePath,
    this.storageObjectPath,
    this.recordId,
    this.imageBytes,
    this.recordCollection = RecordCollection.legacyScanRecords,
    this.placeholderMessage,
    this.fit = BoxFit.contain,
  });

  final String? imageUrl;
  final String? imagePath;
  final String? storageObjectPath;
  final String? recordId;
  final Uint8List? imageBytes;
  final String recordCollection;
  final String? placeholderMessage;
  final BoxFit fit;

  @override
  State<SubmittedScanImage> createState() => _SubmittedScanImageState();
}

class _SubmittedScanImageState extends State<SubmittedScanImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant SubmittedScanImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.imagePath != widget.imagePath ||
        oldWidget.storageObjectPath != widget.storageObjectPath ||
        oldWidget.recordId != widget.recordId ||
        oldWidget.recordCollection != widget.recordCollection ||
        oldWidget.imageBytes != widget.imageBytes) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    if (widget.imageBytes != null && widget.imageBytes!.isNotEmpty) {
      setState(() {
        _bytes = widget.imageBytes;
        _loading = false;
        _failed = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _failed = false;
      _bytes = null;
    });

    final bytes = await ScanRecordImageLoader.loadBytes(
      recordId: widget.recordId,
      imageUrl: widget.imageUrl,
      imagePath: widget.imagePath,
      storageObjectPath: widget.storageObjectPath,
      recordCollection: widget.recordCollection,
    );

    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _failed = bytes == null || bytes.isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _placeholder(showProgress: true);
    }
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
      );
    }
    return _placeholder();
  }

  Widget _placeholder({bool showProgress = false}) {
    return Container(
      color: const Color(0xFFE8EEF5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showProgress)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(Icons.photo_outlined, size: 48, color: Colors.grey.shade500),
          if (!_loading && _failed) ...[
            const SizedBox(height: 12),
            Text(
              widget.placeholderMessage ??
                  'Submitted photo unavailable for this record.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
