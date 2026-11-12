import 'dart:convert';
import 'dart:typed_data';
import '../models/model_comparison.dart';

abstract final class ModelComparisonExport {
  static Uint8List csv(List<ModelComparison> rows) {
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    return Uint8List.fromList(utf8.encode('\ufeff${[
      ModelComparison.headers,
      ...rows.map((row) => row.cells),
      [ModelComparison.note],
    ].map((row) => row.map(cell).join(',')).join('\r\n')}'));
  }
}
