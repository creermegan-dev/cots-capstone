import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import '../../../models/model_comparison.dart';
import '../../../models/scan_record_model.dart';
import '../../../services/model_comparison_export.dart';
import '../../../services/report_file_saver.dart';

class AdminModelComparisonCard extends StatefulWidget {
  const AdminModelComparisonCard({super.key, required this.records});
  final List<ScanRecordModel> records;
  @override
  State<AdminModelComparisonCard> createState() =>
      _AdminModelComparisonCardState();
}

class _AdminModelComparisonCardState extends State<AdminModelComparisonCard> {
  bool _saving = false;
  Future<void> _export(List<ModelComparison> rows) async {
    setState(() => _saving = true);
    try {
      await ReportFileSaver.save(
          name: 'cots_model_comparison',
          bytes: ModelComparisonExport.csv(rows),
          fileExtension: 'csv',
          mimeType: MimeType.csv);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not export model comparison. Please retry.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ModelComparison.fromRecords(widget.records);
    return Container(
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Model comparison',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton.icon(
                    onPressed: _saving ? null : () => _export(rows),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Export CSV'))
              ]),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                horizontalMargin: 8,
                columnSpacing: 24,
                columns: [
                  for (final title in ModelComparison.headers)
                    DataColumn(label: Text(title))
                ],
                rows: [
                  for (final row in rows)
                    DataRow(cells: [
                      for (final value in row.cells) DataCell(Text(value))
                    ])
                ],
              )),
          const SizedBox(height: 8),
          const Text(ModelComparison.note,
              style: TextStyle(fontSize: 12, color: Color(0xFF627D98))),
        ]));
  }
}
