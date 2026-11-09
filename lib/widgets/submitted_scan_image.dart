import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/record_collection.dart';
import '../services/scan_record_image_loader.dart';
import 'cots_loading_skeleton.dart';

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
    this.loadedBuilder,
    this.loadImage,
  });

  final String? imageUrl;
  final String? imagePath;
  final String? storageObjectPath;
  final String? recordId;
  final Uint8List? imageBytes;
  final String recordCollection;
  final String? placeholderMessage;
  final BoxFit fit;
  final Widget Function(BuildContext, Widget)? loadedBuilder;
  final Future<Uint8List?> Function()? loadImage;

  @override
  State<SubmittedScanImage> createState() => _SubmittedScanImageState();
}

class _SubmittedScanImageState extends State<SubmittedScanImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;
  int _request = 0;
  String? _errorMessage;

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
        oldWidget.imageBytes != widget.imageBytes ||
        oldWidget.loadImage != widget.loadImage) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final request = ++_request;
    _errorMessage = null;
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

    Uint8List? bytes;
    try {
      bytes = widget.loadImage != null
          ? await widget.loadImage!()
          : await ScanRecordImageLoader.loadBytes(
              recordId: widget.recordId,
              imageUrl: widget.imageUrl,
              imagePath: widget.imagePath,
              storageObjectPath: widget.storageObjectPath,
              recordCollection: widget.recordCollection,
              onError: (error) {
                if (request == _request) _recordError(error);
              },
            );
    } catch (error) {
      if (request == _request) _recordError(error);
    }

    if (!mounted || request != _request) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _failed = bytes == null || bytes.isEmpty;
    });
  }

  void _recordError(Object error) {
    // Keep raw Storage responses, private object paths and tokens out of the UI.
    if (error is StorageException) {
      _errorMessage = switch (error.statusCode) {
        '401' || '403' => 'Photo access was denied. Sign in again and retry.',
        '404' => 'The stored photo could not be found.',
        _ => 'The photo download failed. Please retry.',
      };
    } else {
      _errorMessage =
          'The photo could not be downloaded. Check your connection and retry.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CotsLoadingSkeleton(layout: CotsSkeletonLayout.image);
    }
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        fit: widget.fit,
        width: double.infinity,
        height: double.infinity,
        frameBuilder: (context, child, frame, synchronous) {
          if (frame == null) {
            return const CotsLoadingSkeleton(layout: CotsSkeletonLayout.image);
          }
          return widget.loadedBuilder?.call(context, child) ?? child;
        },
        errorBuilder: (context, error, stack) => _placeholder(
            message: 'The downloaded photo could not be opened. Please retry.'),
      );
    }
    return _placeholder();
  }

  Widget _placeholder({String? message}) {
    return Container(
      color: const Color(0xFFE8EEF5),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_outlined, size: 48, color: Colors.grey.shade500),
          if (!_loading && (_failed || message != null)) ...[
            const SizedBox(height: 12),
            Text(
              message ??
                  _errorMessage ??
                  widget.placeholderMessage ??
                  'Submitted photo unavailable for this record.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _resolve,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry photo'),
            ),
          ],
        ],
      )),
    );
  }
}
