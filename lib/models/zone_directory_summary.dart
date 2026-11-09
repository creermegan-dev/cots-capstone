import 'davao_gulf_geography.dart';
import 'monitoring_analytics.dart';
import 'scan_record_model.dart';

/// Joins existing map definitions to deduplicated saved captures.
class ZoneDirectorySummary {
  ZoneDirectorySummary(this.zone, List<ScanRecordModel> records)
      : analytics = MonitoringAnalytics.fromRecords(records);
  final GulfCoastalMunicipality zone;
  final MonitoringAnalytics analytics;
  int get reports => analytics.submissionCount;
  DateTime? get latestReport {
    DateTime? latest;
    for (final record in analytics.captures) {
      final date = record.submittedAt ?? record.dateTaken;
      if (date != null && (latest == null || date.isAfter(latest))) {
        latest = date;
      }
    }
    return latest;
  }

  static String? zoneCodeFor(ScanRecordModel record) {
    final source = record.sourceCapture;
    final part =
        DavaoGulfGeography.barangayById(source?.monitoringAreaId ?? '');
    if (part != null) return part.zoneCode;
    // A site code (S1) or site name (Site 1 · Tambo) stored with the record.
    final label = record.zone.trim().toLowerCase();
    for (final site in DavaoGulfGeography.allBarangays) {
      if (label == site.id.toLowerCase() ||
          label == site.displayName.toLowerCase()) {
        return site.zoneCode;
      }
    }
    for (final zone in DavaoGulfGeography.municipalities) {
      final names = [
        zone.name.toLowerCase(),
        zone.id.toLowerCase(),
        zone.zoneLabel.toLowerCase(),
      ];
      if (names.contains(record.zone.trim().toLowerCase()) ||
          names.contains((source?.municipality ?? '').trim().toLowerCase())) {
        return zone.zoneCode;
      }
    }
    return DavaoGulfGeography.assignWithinMonitoringArea(
            latitude: record.latitude, longitude: record.longitude)
        ?.municipality
        .zoneCode;
  }

  static List<ZoneDirectorySummary> fromRecords(List<ScanRecordModel> records) {
    final groups = <String, List<ScanRecordModel>>{};
    for (final record in MonitoringAnalytics.fromRecords(records).captures) {
      final code = zoneCodeFor(record);
      if (code != null) (groups[code] ??= []).add(record);
    }
    return [
      for (final zone in DavaoGulfGeography.municipalities)
        ZoneDirectorySummary(zone, groups[zone.zoneCode] ?? [])
    ];
  }
}

/// Read-only site breakdown of the same saved captures used by the zone totals.
class SiteDirectorySummary {
  SiteDirectorySummary(this.site, List<ScanRecordModel> records)
      : _summary = ZoneDirectorySummary(
            DavaoGulfGeography.municipalityByZoneCode(site.zoneCode)!, records);

  final GulfCoastalBarangay site;
  final ZoneDirectorySummary _summary;
  MonitoringAnalytics get analytics => _summary.analytics;
  int get reports => _summary.reports;
  DateTime? get latestReport => _summary.latestReport;

  static String? siteIdFor(ScanRecordModel record) {
    final storedSite = DavaoGulfGeography.barangayById(
        record.sourceCapture?.monitoringAreaId ?? '');
    if (storedSite != null) return storedSite.id;
    return siteIdForLocation(record.zone,
        latitude: record.latitude, longitude: record.longitude);
  }

  static String? siteIdForLocation(String location,
      {double? latitude, double? longitude}) {
    final label = location.trim().toLowerCase();
    for (final site in DavaoGulfGeography.allBarangays) {
      if ([site.id, site.displayName, site.name]
          .any((name) => name.toLowerCase() == label)) {
        return site.id;
      }
    }
    return DavaoGulfGeography.assignWithinMonitoringArea(
            latitude: latitude, longitude: longitude)
        ?.barangay
        .id;
  }

  static List<SiteDirectorySummary> fromRecords(List<ScanRecordModel> records) {
    final groups = <String, List<ScanRecordModel>>{};
    for (final record in MonitoringAnalytics.fromRecords(records).captures) {
      final id = siteIdFor(record);
      if (id != null) (groups[id] ??= []).add(record);
    }
    return [
      for (final site in DavaoGulfGeography.allBarangays)
        SiteDirectorySummary(site, groups[site.id] ?? []),
    ];
  }
}
