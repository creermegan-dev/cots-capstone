import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/cots_colors.dart';
import '../../models/davao_gulf_geography.dart';
import '../../models/photo_source.dart';
import 'cots_map_page.dart' show CotsMapPage;

/// An overview of the coordinates already read for this photo.
/// No editing controls, current-location lookup, network writes or review queue.
class PhotoLocationReviewPage extends StatelessWidget {
  const PhotoLocationReviewPage({
    super.key,
    required this.fileName,
    required this.originalSource,
    this.original,
    this.capturedAt,
  });

  final String fileName, originalSource;
  final LatLng? original;
  final DateTime? capturedAt;

  @override
  Widget build(BuildContext context) {
    final candidate = original;
    final point = candidate != null &&
            candidate.latitude.isFinite &&
            candidate.longitude.isFinite &&
            candidate.latitude.abs() <= 90 &&
            candidate.longitude.abs() <= 180
        ? candidate
        : null;
    final area = point == null
        ? null
        : DavaoGulfGeography.assignWithinMonitoringArea(
            latitude: point.latitude, longitude: point.longitude);
    final source = PhotoSource.locationLabel(originalSource);
    return Scaffold(
      appBar: AppBar(title: const Text('Review photo location')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(fileName, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Location source: $source'),
            if (capturedAt != null)
              Text(
                  'Photo date: ${DateFormat('MMM d, yyyy · h:mm a').format(capturedAt!.toLocal())}'),
            const SizedBox(height: 12),
            if (point == null)
              const Card(
                  child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'No coordinates are available for this photo. A location cannot be shown.'),
              ))
            else ...[
              SizedBox(
                height: 430,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CotsMapPage(
                    enableSiteZoom: false,
                    embedded: true,
                    initialCenter: point,
                    initialZoom: 14,
                    showMyLocation: false,
                    recordMarkers: [
                      Marker(
                        point: point,
                        width: 44,
                        height: 44,
                        child: Tooltip(
                          message: '$source (fixed location)',
                          child: const Icon(Icons.location_on,
                              color: Colors.blue, size: 40),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                  'Coordinates: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}'),
              const SizedBox(height: 8),
              Text(
                  area == null
                      ? 'This point is outside every dive site.'
                      : area.barangay.displayName,
                  style: TextStyle(
                      color: area == null ? kDangerRed : kPrimaryTeal)),
            ],
            const SizedBox(height: 12),
            Text(originalSource == 'exif'
                ? 'The pin shows GPS read from the photo. GPS may be approximate; it does not prove the exact capture position.'
                : originalSource == 'device_surface'
                    ? 'The pin shows the phone GPS used when the photo was selected. These coordinates are not GPS embedded in the photo.'
                    : 'Only the location already recorded for this photo is shown.'),
            const SizedBox(height: 8),
            const Text(
                'View only. You can pan and zoom, but cannot reposition the pin or change coordinates. Viewing this map does not change submission validation.'),
          ],
        ),
      ),
    );
  }
}
