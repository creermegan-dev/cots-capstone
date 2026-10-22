import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/cots_colors.dart';
import '../models/monitoring_analytics.dart';
import '../models/scan_record_model.dart';

/// Dashboard markers use saved capture coordinates, without inferred density.
class MonitoringRecordMap extends StatelessWidget {
  const MonitoringRecordMap(
      {super.key, required this.records, this.onExpandMap});
  final List<ScanRecordModel> records;
  final VoidCallback? onExpandMap;

  @override
  Widget build(BuildContext context) {
    final located = MonitoringAnalytics.fromRecords(records)
        .captures
        .where((r) =>
            r.latitude != null &&
            r.longitude != null &&
            r.latitude!.isFinite &&
            r.longitude!.isFinite &&
            r.latitude!.abs() <= 90 &&
            r.longitude!.abs() <= 180)
        .toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: kSoftCardShadow),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Detection locations',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800, color: kTextNavy)),
        const SizedBox(height: 8),
        if (located.isEmpty)
          const Text('No saved capture coordinates available.')
        else
          SizedBox(
              height: 320,
              child: FlutterMap(
                options: MapOptions(
                    initialCenter: LatLng(
                        located.first.latitude!, located.first.longitude!),
                    initialZoom: 11),
                children: [
                  TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.cots_monitor'),
                  MarkerLayer(markers: [
                    for (final r in located)
                      Marker(
                          point: LatLng(r.latitude!, r.longitude!),
                          width: 48,
                          height: 48,
                          child: Tooltip(
                              message:
                                  '${r.zone}: ${r.aiDetectedCount} COTS detections',
                              child: const Icon(Icons.location_on,
                                  color: kPrimaryTeal, size: 36)))
                  ]),
                  const RichAttributionWidget(attributions: [
                    TextSourceAttribution('OpenStreetMap contributors')
                  ]),
                ],
              )),
        if (onExpandMap != null)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: onExpandMap,
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Open monitoring map'))),
      ]),
    );
  }
}
