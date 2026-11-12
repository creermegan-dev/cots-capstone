import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/model_comparison.dart';
import '../../../models/staff_submission_rows.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/monthly_report.dart';
import '../../../services/monthly_report_pdf_service.dart';
import '../../../services/monthly_report_service.dart';
import '../../../services/report_file_saver.dart';
import '../../../services/site_levels_service.dart';
import '../models/admin_record_table_row.dart';
import '../theme/admin_theme.dart';

/// "Create report" (Admin and Expert, 2026-11-09): pick a month and an optional
/// site, preview the report on screen, then export it as one PDF.
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({
    super.key,
    this.showBack = true,
    this.api = const MonthlyReportApi(),
    this.loadRecords,
    this.save,
    this.now,
  });

  /// Shown when the page was opened from another page (Admin Reports).
  final bool showBack;

  /// Tests replace the database reads and the file save.
  final MonthlyReportApi api;
  final Future<List<AdminRecordTableRow>> Function()? loadRecords;
  final Future<String?> Function(Uint8List bytes, String fileName)? save;
  final DateTime Function()? now;

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  late final List<DateTime> _months;
  late DateTime _month;
  String? _siteCode;
  List<MonthlyReportSiteOption> _sites = const [];

  bool _loading = false;
  bool _exporting = false;
  Object? _error;
  MonthlyReport? _report;
  List<MonthlyReportRecord> _records = const [];
  List<ModelComparison>? _modelComparison;
  int _generation = 0;

  List<ModelComparison>? get _adminModelComparison =>
      context.read<AuthProvider?>()?.userModel?.isAdmin == true
          ? _modelComparison
          : null;

  @override
  void initState() {
    super.initState();
    final current =
        MonthlySiteLevel.monthOf((widget.now ?? DateTime.now).call());
    _months = [
      for (var i = 0; i < 12; i++) DateTime(current.year, current.month - i),
    ];
    _month = _months.first;
    widget.api.sites().then((sites) {
      if (mounted) setState(() => _sites = sites);
    }).catchError((_) {
      // The report still works for all sites without the picker list.
    });
  }

  Future<void> _create() async {
    if (_loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.api.report(_month, areaCode: _siteCode).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException(
              'The report summary did not respond. Check your connection and retry.'));
      final rows = report.isEmpty
          ? const <AdminRecordTableRow>[]
          : await (widget.loadRecords?.call() ?? widget.api.records(report))
              .timeout(const Duration(seconds: 30),
                  onTimeout: () => throw TimeoutException(
                      'The report records did not finish loading. Check your connection and retry.'));
      if (!mounted || generation != _generation) return;
      setState(() {
        _report = report;
        _records = MonthlyReportRecord.forReport(report, rows);
        final ids = _records.map((record) => record.recordId).toSet();
        _modelComparison = ModelComparison.fromRecords(rows
            .where((row) => ids.contains(row.recordId))
            .map(StaffSubmissionRows.photo));
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _report = null;
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _export() async {
    final report = _report;
    if (report == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await const MonthlyReportPdfService()
          .build(report, _records, modelComparison: _adminModelComparison);
      final path = widget.save != null
          ? await widget.save!(bytes, report.fileName)
          : await ReportFileSaver.save(
              name: report.fileName,
              bytes: bytes,
              fileExtension: 'pdf',
              mimeType: MimeType.pdf,
            );
      if (!mounted) return;
      if (path == null || path.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('PDF report saved to $path'),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdminColors.statRed,
        content: Text('Could not export the report: $error'),
      ));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final canExport = report != null && !report.isEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topBar(
              report == null ? 'Create report' : 'Report preview',
              report == null
                  ? 'Choose a month and site to see the report'
                  : '${report.monthLabel} · ${report.scopeLabel}',
              canExport),
          const SizedBox(height: 16),
          _form(),
          const SizedBox(height: 16),
          _preview(),
        ],
      ),
    );
  }

  Widget _topBar(String title, String subtitle, bool canExport) {
    return Row(
      children: [
        if (widget.showBack)
          IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AdminColors.headerTitle)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 13.5, color: AdminColors.muted)),
            ],
          ),
        ),
        if (canExport)
          FilledButton.icon(
            key: const Key('export-pdf'),
            onPressed: _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded, size: 18),
            label: const Text('Export PDF'),
          ),
      ],
    );
  }

  Widget _form() {
    final monthFormat = DateFormat('MMMM yyyy');
    final monthField = DropdownButtonFormField<DateTime>(
      key: const Key('month-picker'),
      initialValue: _month,
      decoration: const InputDecoration(
          labelText: 'Month', border: OutlineInputBorder(), isDense: true),
      items: [
        for (var i = 0; i < _months.length; i++)
          DropdownMenuItem(
            value: _months[i],
            child: Text(
                '${monthFormat.format(_months[i])}${i == 0 ? ' (this month)' : ''}'),
          ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _month = value);
      },
    );
    final siteField = DropdownButtonFormField<String?>(
      key: const Key('site-picker'),
      initialValue: _siteCode,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: 'Site', border: OutlineInputBorder(), isDense: true),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All sites')),
        for (final site in _sites)
          DropdownMenuItem<String?>(
              value: site.code,
              child: Text(site.name, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (value) => setState(() => _siteCode = value),
    );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 560) {
              return Column(children: [
                monthField,
                const SizedBox(height: 12),
                siteField,
              ]);
            }
            return Row(children: [
              Expanded(child: monthField),
              const SizedBox(width: 12),
              Expanded(child: siteField),
            ]);
          }),
          const SizedBox(height: 8),
          const Text(
            'Months follow Philippine time. Site levels count every Diver\'s confirmed COTS at the site.',
            style: TextStyle(fontSize: 12, color: AdminColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('create-report'),
            onPressed: _loading ? null : _create,
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text('Create report'),
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    if (_loading) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return _card(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 36, color: AdminColors.statRed),
            const SizedBox(height: 8),
            Text('Could not create the report: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AdminColors.muted)),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _create, child: const Text('Retry')),
          ],
        ),
      );
    }
    final report = _report;
    if (report == null) {
      return _card(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              Icon(Icons.insert_chart_outlined_rounded,
                  size: 34, color: AdminColors.muted),
              SizedBox(height: 8),
              Text('No report yet',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(height: 2),
              Text(
                'Pick a month and site, then tap Create report. The report preview appears here, with an Export PDF button.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AdminColors.muted),
              ),
            ],
          ),
        ),
      );
    }
    if (report.isEmpty) {
      return _card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 34, color: AdminColors.muted),
              const SizedBox(height: 8),
              const Text('No records for this month',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                'Nothing was recorded in ${report.monthLabel} for ${report.scopeLabel}. Try another month or site.',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12.5, color: AdminColors.muted),
              ),
            ],
          ),
        ),
      );
    }
    return MonthlyReportView(
        report: report,
        records: _records,
        modelComparison: _adminModelComparison);
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AdminColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: child,
      );
}

/// The report as shown on screen; the PDF has the same sections.
class MonthlyReportView extends StatelessWidget {
  const MonthlyReportView(
      {super.key,
      required this.report,
      required this.records,
      this.modelComparison});

  final MonthlyReport report;
  final List<MonthlyReportRecord> records;
  final List<ModelComparison>? modelComparison;

  @override
  Widget build(BuildContext context) {
    final methodTotal = report.methods.fold<int>(0, (sum, m) => sum + m.cots);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('COTS Monitor report',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AdminColors.headerTitle)),
          const SizedBox(height: 2),
          Text('${report.monthLabel} · ${report.scopeLabel}',
              style: const TextStyle(fontSize: 12.5, color: AdminColors.muted)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _tile('Found and removed (confirmed)', '${report.confirmedCots}'),
              _tile('Waiting for Expert', '${report.waitingCots}'),
              _tile('Not accepted', '${report.notAcceptedCots}'),
              _tile(
                  'Diver-reported no-COTS surveys', '${report.noCotsSurveys}'),
              _tile('Avg. Expert wait', report.review.avgWaitLabel),
            ],
          ),
          _heading('1. Sites'),
          if (report.sites.isEmpty)
            _note('No sites had records or an assigned Diver this month.')
          else
            _ReportTable(
              headers: const [
                'Site',
                'Level',
                'Confirmed',
                'Main Diver',
                'Last visit',
                'Visits',
                'Missed'
              ],
              widths: const [3, 2, 2, 3, 2.4, 1.4, 1.6],
              rightAligned: const {2, 5, 6},
              rows: [
                for (final site in report.sites)
                  [
                    Text(site.areaName),
                    _levelChip(site.level),
                    Text('${site.confirmedCots}'),
                    Text(site.mainDiverLabel),
                    Text(site.lastVisitLabel),
                    Text('${site.visits}'),
                    Text(site.missedLabel),
                  ],
              ],
            ),
          _heading('2. Removal methods'),
          if (report.methods.isEmpty)
            _note('No confirmed removals were submitted this month.')
          else
            _ReportTable(
              headers: const ['Method', 'Removals', 'Confirmed', 'Share'],
              widths: const [4, 2, 2, 2],
              rightAligned: const {1, 2, 3},
              rows: [
                for (final method in report.methods)
                  [
                    Text(method.method),
                    Text('${method.removals}'),
                    Text('${method.cots}'),
                    Text(method.shareOf(methodTotal)),
                  ],
              ],
            ),
          _heading('3. Expert review'),
          Text(report.review.summary, style: const TextStyle(fontSize: 13)),
          _heading('Appendix: records (${records.length})'),
          if (records.isEmpty)
            _note('No photo records for this month.')
          else
            _ReportTable(
              headers: const [
                'Record',
                'Encounter',
                'Site',
                'Date taken',
                'Location from',
                'Confirmed',
                'Status'
              ],
              widths: const [2.4, 2, 3, 2.2, 2.6, 1.7, 2],
              rightAligned: const {5},
              rows: [
                for (final record in records)
                  [
                    Text(record.recordId),
                    Text(record.encounter),
                    Text(record.site),
                    Text(record.dateTaken),
                    Text(record.locationFrom),
                    Text('${record.confirmed}'),
                    Text(record.status),
                  ],
              ],
            ),
          if (modelComparison != null) ...[
            _heading('Model comparison'),
            _ReportTable(
              headers: ModelComparison.headers,
              widths: const [2, 2, 2, 3],
              rows: [
                for (final model in modelComparison!)
                  [for (final cell in model.cells) Text(cell)]
              ],
            ),
            const SizedBox(height: 8),
            _note(ModelComparison.note),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(report.footnote,
              style: const TextStyle(
                  fontSize: 11, height: 1.5, color: AdminColors.muted)),
        ],
      ),
    );
  }

  static Widget _tile(String label, String value) => Container(
        width: 190,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AdminColors.contentBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: AdminColors.muted)),
            const SizedBox(height: 2),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  static Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AdminColors.headerTitle)),
      );

  static Widget _note(String text) => Text(text,
      style: const TextStyle(fontSize: 12.5, color: AdminColors.muted));

  static Widget _levelChip(String? level) {
    if (level == null) {
      return const Text('No records',
          style: TextStyle(fontSize: 12, color: AdminColors.muted));
    }
    final color = switch (level) {
      'High' => AdminColors.statRed,
      'Moderate' => const Color(0xFFB26A00),
      _ => AdminColors.statGreen,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(level,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

/// A bordered table that scrolls sideways on narrow screens.
class _ReportTable extends StatelessWidget {
  const _ReportTable({
    required this.headers,
    required this.widths,
    required this.rows,
    this.rightAligned = const {},
  });

  final List<String> headers;
  final List<double> widths;
  final List<List<Widget>> rows;
  final Set<int> rightAligned;

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget child, int column, {bool header = false}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Align(
            alignment: rightAligned.contains(column)
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: header ? FontWeight.w700 : FontWeight.w400),
              child: child,
            ),
          ),
        );

    return LayoutBuilder(builder: (context, c) {
      final width = c.maxWidth < 620 ? 620.0 : c.maxWidth;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Table(
            border: TableBorder.all(color: const Color(0xFFD0D7E2), width: 0.6),
            columnWidths: {
              for (var i = 0; i < widths.length; i++)
                i: FlexColumnWidth(widths[i]),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(color: AdminColors.contentBg),
                children: [
                  for (var i = 0; i < headers.length; i++)
                    cell(Text(headers[i]), i, header: true),
                ],
              ),
              for (final row in rows)
                TableRow(children: [
                  for (var i = 0; i < row.length; i++) cell(row[i], i),
                ]),
            ],
          ),
        ),
      );
    });
  }
}
