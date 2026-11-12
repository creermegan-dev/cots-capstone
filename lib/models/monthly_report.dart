import 'package:intl/intl.dart';

import '../features/admin/models/admin_record_table_row.dart';
import 'photo_source.dart';
import 'record_collection.dart';

/// One monthly PDF report (Admin and Expert, 2026-11-09). The database
/// supplies every number (`monthly_report_json`); the app only formats them.
class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.generatedAt,
    this.areaCode,
    this.areaName,
    this.confirmedCots = 0,
    this.waitingCots = 0,
    this.notAcceptedCots = 0,
    this.records = 0,
    this.noCotsSurveys = 0,
    this.photosAt80 = 0,
    this.sites = const [],
    this.methods = const [],
    this.review = const MonthlyReportReview(),
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    final month = DateTime.tryParse(json['month']?.toString() ?? '');
    final generated = DateTime.tryParse(json['generated_at']?.toString() ?? '');
    return MonthlyReport(
      month: month == null ? DateTime.now() : DateTime(month.year, month.month),
      generatedAt: (generated ?? DateTime.now()).toUtc(),
      areaCode: json['area_code']?.toString(),
      areaName: json['area_name']?.toString(),
      confirmedCots: _int(json['confirmed_cots']),
      waitingCots: _int(json['waiting_cots']),
      notAcceptedCots: _int(json['not_accepted_cots']),
      records: _int(json['records']),
      noCotsSurveys: _int(json['no_cots_surveys']),
      photosAt80: _int(json['photos_at_80']),
      sites: [
        for (final row in (json['sites'] as List?) ?? const [])
          MonthlyReportSite.fromJson(Map<String, dynamic>.from(row as Map)),
      ],
      methods: [
        for (final row in (json['methods'] as List?) ?? const [])
          MonthlyReportMethod.fromJson(Map<String, dynamic>.from(row as Map)),
      ],
      review: json['expert_review'] is Map
          ? MonthlyReportReview.fromJson(
              Map<String, dynamic>.from(json['expert_review'] as Map))
          : const MonthlyReportReview(),
    );
  }

  /// First day of the reported month (Philippine calendar month).
  final DateTime month;
  final DateTime generatedAt;

  /// Set when the report covers one site only.
  final String? areaCode;
  final String? areaName;

  final int confirmedCots;
  final int waitingCots;
  final int notAcceptedCots;
  final int records;
  final int noCotsSurveys;

  /// Photos that used the older 80% automatic-acceptance rule.
  final int photosAt80;

  final List<MonthlyReportSite> sites;
  final List<MonthlyReportMethod> methods;
  final MonthlyReportReview review;

  bool get isEmpty =>
      records == 0 && noCotsSurveys == 0 && sites.isEmpty && methods.isEmpty;

  String get monthLabel => DateFormat('MMMM yyyy').format(month);

  String get scopeLabel => (areaName ?? '').isNotEmpty
      ? areaName!
      : (areaCode ?? '').isNotEmpty
          ? areaCode!
          : 'All sites';

  /// "9 Nov 2026, 10:09 PM (Manila)".
  String get generatedLabel =>
      '${DateFormat('d MMM yyyy, h:mm a').format(generatedAt.add(const Duration(hours: 8)))} (Manila)';

  String get fileName {
    final scope = (areaCode ?? '').isNotEmpty
        ? areaCode!.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        : 'all_sites';
    return 'cots_report_${DateFormat('yyyy-MM').format(month)}_$scope';
  }

  /// The footer of the report: how the numbers are defined.
  String get footnote {
    final accepted = photosAt80 > 0
        ? 'accepted automatically at 85% or higher (photos submitted before '
            'that rule used 80%) plus approved by the Expert'
        : 'accepted automatically at 85% or higher plus approved by the Expert';
    return 'Diver-reported no-COTS surveys: $noCotsSurveys. These complete visits without resetting COTS totals. Generated $generatedLabel. Confirmed = $accepted. '
        'Waiting = still needs the Expert. Not accepted = rejected by the '
        'Expert or too uncertain to count. '
        'Levels: 0-15 Low, 16-100 Moderate, 101+ High confirmed COTS per '
        'site per month. Removal methods count removals submitted in the month.';
  }

  static int _int(dynamic value) => (value as num?)?.toInt() ?? 0;
}

class MonthlyReportSite {
  const MonthlyReportSite({
    required this.areaCode,
    required this.areaName,
    this.level,
    this.records = 0,
    this.confirmedCots = 0,
    this.waitingCots = 0,
    this.mainDiver,
    this.lastVisit,
    this.visits = 0,
    this.missedMonths,
  });

  factory MonthlyReportSite.fromJson(Map<String, dynamic> json) {
    final last = DateTime.tryParse(json['last_visit']?.toString() ?? '');
    return MonthlyReportSite(
      areaCode: json['area_code']?.toString() ?? '',
      areaName: json['area_name']?.toString() ?? '',
      level: json['level']?.toString(),
      records: MonthlyReport._int(json['records']),
      confirmedCots: MonthlyReport._int(json['confirmed_cots']),
      waitingCots: MonthlyReport._int(json['waiting_cots']),
      mainDiver: json['main_diver']?.toString(),
      lastVisit:
          last == null ? null : DateTime(last.year, last.month, last.day),
      visits: MonthlyReport._int(json['visits']),
      missedMonths: (json['missed_months'] as num?)?.toInt(),
    );
  }

  final String areaCode;
  final String areaName;

  /// 'Low', 'Moderate' or 'High'; null when the site has no records that month.
  final String? level;
  final int records;
  final int confirmedCots;
  final int waitingCots;
  final String? mainDiver;
  final DateTime? lastVisit;
  final int visits;
  final int? missedMonths;

  String get levelLabel => level ?? 'No records';
  String get mainDiverLabel =>
      (mainDiver ?? '').isEmpty ? 'Not assigned' : mainDiver!;
  String get lastVisitLabel => lastVisit == null
      ? 'No visit yet'
      : DateFormat('yyyy-MM-dd').format(lastVisit!);
  String get missedLabel => missedMonths == null ? '-' : '$missedMonths';
}

class MonthlyReportMethod {
  const MonthlyReportMethod(
      {required this.method, required this.cots, required this.removals});

  factory MonthlyReportMethod.fromJson(Map<String, dynamic> json) =>
      MonthlyReportMethod(
        method: json['method']?.toString() ?? 'Not recorded',
        cots: MonthlyReport._int(json['cots']),
        removals: MonthlyReport._int(json['removals']),
      );

  final String method;
  final int cots;
  final int removals;

  /// Share of [total] confirmed COTS, as "46%".
  String shareOf(int total) =>
      total <= 0 ? '0%' : '${(cots * 100 / total).round()}%';
}

class MonthlyReportReview {
  const MonthlyReportReview({
    this.reviewed = 0,
    this.approved = 0,
    this.rejected = 0,
    this.stillWaiting = 0,
    this.avgWaitDays,
    this.oldestWaitingDays,
  });

  factory MonthlyReportReview.fromJson(Map<String, dynamic> json) =>
      MonthlyReportReview(
        reviewed: MonthlyReport._int(json['reviewed']),
        approved: MonthlyReport._int(json['approved']),
        rejected: MonthlyReport._int(json['rejected']),
        stillWaiting: MonthlyReport._int(json['still_waiting']),
        avgWaitDays: (json['avg_wait_days'] as num?)?.toDouble(),
        oldestWaitingDays: (json['oldest_waiting_days'] as num?)?.toDouble(),
      );

  final int reviewed;
  final int approved;
  final int rejected;
  final int stillWaiting;
  final double? avgWaitDays;
  final double? oldestWaitingDays;

  /// "1.8 d", or "-" when no decision has been made yet.
  String get avgWaitLabel =>
      avgWaitDays == null ? '-' : '${avgWaitDays!.toStringAsFixed(1)} d';

  String get summary {
    final parts = <String>[
      '$reviewed record${reviewed == 1 ? '' : 's'} reviewed: $approved approved, $rejected rejected.',
      if (stillWaiting > 0)
        '$stillWaiting still waiting${oldestWaitingDays == null ? '' : ' (oldest: ${oldestWaitingDays!.toStringAsFixed(1)} days)'}.'
      else
        'Nothing is waiting for the Expert.',
    ];
    return parts.join(' ');
  }
}

/// One row of the records appendix: a single photo record.
class MonthlyReportRecord {
  const MonthlyReportRecord({
    required this.recordId,
    required this.encounter,
    required this.site,
    required this.dateTaken,
    required this.locationFrom,
    required this.confirmed,
    required this.status,
  });

  final String recordId;
  final String encounter;
  final String site;
  final String dateTaken;
  final String locationFrom;
  final int confirmed;
  final String status;

  /// The photo records behind [report]'s totals, taken from the loaded record
  /// rows: finalized photos taken in the report month, at the sites the report
  /// lists. Removal records and visit summaries add no COTS and are left out.
  static List<MonthlyReportRecord> forReport(
    MonthlyReport report,
    Iterable<AdminRecordTableRow> rows,
  ) {
    final siteNames = {for (final site in report.sites) site.areaName};
    final picked = <AdminRecordTableRow>[];
    for (final row in rows) {
      if (row.recordCollection != RecordCollection.captures) continue;
      if (row.serverStatus.isNotEmpty && row.serverStatus != 'finalized') {
        continue;
      }
      final taken = row.capturedAt;
      if (taken == null) continue;
      final manila = taken.toUtc().add(const Duration(hours: 8));
      if (manila.year != report.month.year ||
          manila.month != report.month.month) {
        continue;
      }
      if (!siteNames.contains(row.zone)) continue;
      picked.add(row);
    }
    picked.sort((a, b) {
      final byTime = a.capturedAt!.compareTo(b.capturedAt!);
      return byTime != 0 ? byTime : a.recordId.compareTo(b.recordId);
    });
    return [
      for (final row in picked)
        MonthlyReportRecord(
          recordId: row.recordId,
          encounter: row.encounterId.isEmpty
              ? '-'
              : row.encounterId.substring(
                  0, row.encounterId.length < 8 ? row.encounterId.length : 8),
          site: row.zone,
          dateTaken: DateFormat('yyyy-MM-dd')
              .format(row.capturedAt!.toUtc().add(const Duration(hours: 8))),
          locationFrom: PhotoSource.locationLabel(row.locationSource),
          confirmed: row.cotsTally.confirmed,
          status: row.displayStatusLabel,
        ),
    ];
  }
}
