import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/monthly_report.dart';
import '../models/scan_record_model.dart';
import '../features/admin/models/admin_record_table_row.dart';
import 'supabase_record_service.dart';

/// A site the report can be limited to.
class MonthlyReportSiteOption {
  const MonthlyReportSiteOption({required this.code, required this.name});

  final String code;
  final String name;
}

/// Reads the monthly report numbers (Experts and Administrators only; the
/// database refuses everyone else). Tests replace it.
class MonthlyReportApi {
  const MonthlyReportApi();

  /// Only the photo rows used by this report; no live feed or image metadata.
  Future<List<AdminRecordTableRow>> records(MonthlyReport report) async {
    final captures = await SupabaseRecordService.loadReportCaptures(
      month: report.month,
      siteCodes: [for (final site in report.sites) site.areaCode],
    );
    return [
      for (var i = 0; i < captures.length; i++)
        ScanRecordModel.fromCapture(captures[i]).toAdminTableRow(i + 1),
    ];
  }

  /// The report for [month] (any date in it), for one site or all sites.
  Future<MonthlyReport> report(DateTime month, {String? areaCode}) async {
    final data = await Supabase.instance.client
        .rpc<dynamic>('monthly_report_json', params: {
      'p_month': DateFormat('yyyy-MM-01').format(month),
      'p_area_code': areaCode,
    });
    return MonthlyReport.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Active sites for the site picker (practice sites are left out).
  Future<List<MonthlyReportSiteOption>> sites() async {
    final rows = await Supabase.instance.client
        .from('monitoring_areas')
        .select('code,name,geographic_reference')
        .eq('active', true)
        .order('code');
    return [
      for (final row in (rows as List))
        if (!_isPractice(row['geographic_reference']))
          MonthlyReportSiteOption(
            code: row['code'].toString(),
            name: row['name'].toString(),
          ),
    ];
  }

  static bool _isPractice(dynamic reference) =>
      reference is Map && reference['practice'] == true;
}
