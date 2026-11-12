import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/monthly_report.dart';
import '../models/model_comparison.dart';
import 'report_file_saver.dart';

/// Builds and saves the one-file monthly PDF report (Admin and Expert).
class MonthlyReportPdfService {
  const MonthlyReportPdfService();

  static const _ink = PdfColor.fromInt(0xFF102A43);
  static const _muted = PdfColor.fromInt(0xFF627D98);
  static const _line = PdfColor.fromInt(0xFFD0D7E2);
  static const _tile = PdfColor.fromInt(0xFFF3F5F8);

  Future<Uint8List> build(
    MonthlyReport report,
    List<MonthlyReportRecord> records, {
    List<ModelComparison>? modelComparison,
  }) async {
    final document = pw.Document(
      title: 'COTS Monitor report ${report.monthLabel}',
      author: 'COTS Monitor',
    );
    final confirmedTotal =
        report.methods.fold<int>(0, (sum, m) => sum + m.cots);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'COTS Monitor report · ${report.monthLabel} · ${report.scopeLabel}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
        build: (context) => [
          pw.Text(
            'COTS Monitor report',
            style: const pw.TextStyle(
                fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            '${report.monthLabel} · ${report.scopeLabel}',
            style: const pw.TextStyle(fontSize: 11, color: _muted),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _tile2(
                  'Found and removed (confirmed)', '${report.confirmedCots}'),
              pw.SizedBox(width: 8),
              _tile2('Waiting for Expert', '${report.waitingCots}'),
              pw.SizedBox(width: 8),
              _tile2('Not accepted', '${report.notAcceptedCots}'),
              pw.SizedBox(width: 8),
              _tile2('Avg. Expert wait', report.review.avgWaitLabel),
            ],
          ),
          _note(
              'Diver-reported no-COTS surveys: ${report.noCotsSurveys}. These visits do not reset COTS totals.'),
          _heading('1. Sites'),
          report.sites.isEmpty
              ? _note('No sites had records or an assigned Diver this month.')
              : _table(
                  const [
                    'Site',
                    'Level',
                    'Confirmed',
                    'Main Diver',
                    'Last visit',
                    'Visits',
                    'Missed'
                  ],
                  [
                    for (final site in report.sites)
                      [
                        site.areaName,
                        site.levelLabel,
                        '${site.confirmedCots}',
                        site.mainDiverLabel,
                        site.lastVisitLabel,
                        '${site.visits}',
                        site.missedLabel,
                      ],
                  ],
                  const [3, 2, 2, 3, 2.4, 1.4, 1.6],
                  rightAligned: const {2, 5, 6},
                ),
          _heading('2. Removal methods'),
          report.methods.isEmpty
              ? _note('No confirmed removals were submitted this month.')
              : _table(
                  const ['Method', 'Removals', 'Confirmed', 'Share'],
                  [
                    for (final method in report.methods)
                      [
                        method.method,
                        '${method.removals}',
                        '${method.cots}',
                        method.shareOf(confirmedTotal),
                      ],
                  ],
                  const [4, 2, 2, 2],
                  rightAligned: const {1, 2, 3},
                ),
          _heading('3. Expert review'),
          pw.Text(report.review.summary,
              style: const pw.TextStyle(fontSize: 10, color: _ink)),
          _heading('Appendix: records (${records.length})'),
          records.isEmpty
              ? _note('No photo records for this month.')
              : _table(
                  const [
                    'Record',
                    'Encounter',
                    'Site',
                    'Date taken',
                    'Location from',
                    'Confirmed',
                    'Status'
                  ],
                  [
                    for (final record in records)
                      [
                        record.recordId,
                        record.encounter,
                        record.site,
                        record.dateTaken,
                        record.locationFrom,
                        '${record.confirmed}',
                        record.status,
                      ],
                  ],
                  const [2.4, 2, 3, 2.2, 2.6, 1.7, 2],
                  rightAligned: const {5},
                  fontSize: 7.5,
                ),
          if (modelComparison != null) ...[
            _heading('Model comparison'),
            _table(
                ModelComparison.headers,
                modelComparison
                    .map((row) => row.cells
                        .map((cell) => cell.replaceAll('—', '-'))
                        .toList())
                    .toList(),
                const [2, 2, 2, 3]),
            _note(ModelComparison.note),
          ],
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
                border:
                    pw.Border(top: pw.BorderSide(color: _line, width: 0.5))),
            child: pw.Text(report.footnote,
                style: const pw.TextStyle(fontSize: 7.5, color: _muted)),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<String?> save(
    MonthlyReport report,
    List<MonthlyReportRecord> records,
  ) async {
    return ReportFileSaver.save(
      name: report.fileName,
      bytes: await build(report, records),
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  static pw.Widget _tile2(String label, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
              color: _tile, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 8, color: _muted)),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: const pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink)),
            ],
          ),
        ),
      );

  static pw.Widget _heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Text(text,
            style: const pw.TextStyle(
                fontSize: 12, fontWeight: pw.FontWeight.bold, color: _ink)),
      );

  static pw.Widget _note(String text) =>
      pw.Text(text, style: const pw.TextStyle(fontSize: 9, color: _muted));

  /// A bordered table whose header row repeats on every page.
  static pw.Widget _table(
    List<String> headers,
    List<List<String>> rows,
    List<double> widths, {
    Set<int> rightAligned = const {},
    double fontSize = 8.5,
  }) {
    pw.Widget cell(String text, int column, {bool header = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
          child: pw.Text(
            text,
            textAlign: rightAligned.contains(column)
                ? pw.TextAlign.right
                : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _ink,
            ),
          ),
        );

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.5),
      columnWidths: {
        for (var i = 0; i < widths.length; i++)
          i: pw.FlexColumnWidth(widths[i]),
      },
      children: [
        pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(color: _tile),
          children: [
            for (var i = 0; i < headers.length; i++)
              cell(headers[i], i, header: true),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (var i = 0; i < row.length; i++) cell(row[i], i),
            ],
          ),
      ],
    );
  }

  /// Used by tests and file names: the month as yyyy-MM.
  static String monthKey(DateTime month) => DateFormat('yyyy-MM').format(month);
}
