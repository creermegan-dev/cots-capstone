import 'package:supabase_flutter/supabase_flutter.dart';

class NoCotsSurveyConflict implements Exception {
  const NoCotsSurveyConflict(this.message);
  final String message;
  static bool matchesReason(String? reason) =>
      reason != null &&
      (reason.startsWith('COTS have already been reported at this site') ||
          reason.startsWith('A no-COTS survey already completes this site'));
  @override
  String toString() => message;
}

/// Separate observations, never synthetic detections or Expert decisions.
abstract final class NoCotsSurveyService {
  static Future<void> submit(Map<String, dynamic> task) async {
    try {
      await Supabase.instance.client
          .rpc('submit_no_cots_survey',
              params: Map<String, dynamic>.from(task['survey_params'] as Map))
          .timeout(const Duration(seconds: 30));
    } on PostgrestException catch (error) {
      if (error.code == 'NC001' || error.code == 'NC002') {
        throw NoCotsSurveyConflict(error.message);
      }
      rethrow;
    }
  }

  static String observation(Map<String, dynamic> row) =>
      row['cots_reported_later'] == true
          ? 'No COTS observed earlier; COTS reported later this month'
          : 'No COTS observed during this survey';

  static Future<List<Map<String, dynamic>>> load({bool mineOnly = true}) async {
    final result = await Supabase.instance.client.rpc<dynamic>(
        'no_cots_surveys_json',
        params: {'p_mine_only': mineOnly}).timeout(const Duration(seconds: 15));
    return [
      for (final row in result as List) Map<String, dynamic>.from(row as Map)
    ];
  }
}
