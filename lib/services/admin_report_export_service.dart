import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../features/admin/models/admin_record_table_row.dart';
import '../models/staff_submission_rows.dart';
import 'report_file_saver.dart';

/// Builds and saves filtered administrator report exports.
class AdminReportExportService {
  const AdminReportExportService();

  static const _headers = <String>[
    'Report ID',
    'Type',
    'Submitted By',
    'Site',
    'Submitted On',
    'COTS confirmed',
    'COTS waiting',
    'COTS not accepted',
    'Confidence',
    'Status',
    'Photos',
    'Photo IDs',
  ];

  Uint8List buildCsv(List<AdminRecordTableRow> rows) {
    final output = StringBuffer()..writeln(_headers.map(_csvCell).join(','));
    for (final row in StaffSubmissionRows.group(rows)) {
      output.writeln(_values(row).map(_csvCell).join(','));
    }
    return Uint8List.fromList(utf8.encode('\ufeff$output'));
  }

  Future<Uint8List> buildPdf(List<AdminRecordTableRow> rows) async {
    rows = StaffSubmissionRows.group(rows);
    final document = pw.Document(
      title: 'COTS Monitor Reports',
      author: 'COTS Monitor',
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'COTS Monitor Reports',
              style: const pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.teal800,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
                '${rows.length} filtered record${rows.length == 1 ? '' : 's'}'),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ),
        build: (_) => [
          pw.TableHelper.fromTextArray(
            headers: _headers,
            data: rows.map(_values).toList(),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
            headerStyle: const pw.TextStyle(
              color: PdfColors.white,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellPadding: const pw.EdgeInsets.all(4),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<String?> saveCsv(List<AdminRecordTableRow> rows) {
    return ReportFileSaver.save(
      name: _fileName(),
      bytes: buildCsv(rows),
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  Future<String?> savePdf(List<AdminRecordTableRow> rows) async {
    return ReportFileSaver.save(
      name: _fileName(),
      bytes: await buildPdf(rows),
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  List<String> _values(AdminRecordTableRow row) => <String>[
        row.recordId,
        row.activityType,
        row.submittedBy,
        row.zone,
        row.dateUploaded.isNotEmpty ? row.dateUploaded : row.dateTime,
        // Stage 3: honest counts (removal rows and visit summaries add none).
        '${row.cotsTally.confirmed}',
        '${row.cotsTally.waiting}',
        '${row.cotsTally.notAccepted}',
        row.isSubmissionSummary ? 'Per photo' : '${row.confidencePercent}%',
        row.displayStatusLabel,
        '${row.isSubmissionSummary ? row.submissionPhotos.length : 1}',
        row.isSubmissionSummary
            ? row.submissionPhotos.map((photo) => photo.recordId).join('; ')
            : row.recordId,
      ];

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  String _fileName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return 'cots_reports_${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}
