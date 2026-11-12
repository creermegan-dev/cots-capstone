import 'detection_model.dart';
import 'monitoring_analytics.dart';
import 'scan_record_model.dart';

class ModelComparison {
  ModelComparison(this.model);
  final String model;
  int photos = 0, expertConfirmed = 0, _detections = 0;
  double _confidenceSum = 0;
  String get confidenceLabel => _detections == 0
      ? '—'
      : '${(_confidenceSum / _detections * 100).toStringAsFixed(1)}%';
  List<String> get cells =>
      [model, '$photos', confidenceLabel, '$expertConfirmed'];
  static const headers = [
    'Model',
    'Photos processed',
    'Avg. confidence',
    'Expert-confirmed COTS'
  ];
  static const note =
      'Confidence does not measure accuracy. Expert-confirmed counts exclude AI-only acceptance. Different photo sets are not a controlled comparison.';

  /// The caller supplies the same filtered captures used by the current view.
  static List<ModelComparison> fromRecords(Iterable<ScanRecordModel> records) {
    final groups = {
      for (final m in DetectionModel.values) m.label: ModelComparison(m.label)
    };
    for (final record in MonitoringAnalytics.fromRecords(records).captures) {
      final name = storedDetectionModelLabel(record.sourceCapture?.modelName);
      final row = groups.putIfAbsent(name, () => ModelComparison(name));
      row.photos++;
      row.expertConfirmed += record.sourceCapture?.expertConfirmedCount ?? 0;
      if (record.detectionBoxes.isNotEmpty) {
        row._detections += record.detectionBoxes.length;
        row._confidenceSum += record.detectionBoxes
            .fold<double>(0, (sum, box) => sum + box.score);
      } else if (record.aiDetectedCount > 0) {
        row._detections += record.aiDetectedCount;
        row._confidenceSum += record.confidence * record.aiDetectedCount;
      }
    }
    return groups.values.toList();
  }
}
