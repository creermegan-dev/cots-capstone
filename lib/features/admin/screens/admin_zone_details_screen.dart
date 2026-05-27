import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cots_monitor/providers/auth_provider.dart';
import '../layout/admin_breakpoints.dart';
import '../layout/admin_responsive_chrome.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/admin_back_icon_button.dart';
import '../widgets/admin_dashboard_header.dart';
import 'admin_shell_screen.dart';

const _kLabelGrey = Color(0xFF6B7280);
const _kBodyGrey = Color(0xFF374151);

String _statusPillFromAlert(String alertStatus) {
  final s = alertStatus.trim();
  if (s == 'Active (Outbreak)') return '● Active (Detected)';
  if (s.toLowerCase().contains('active')) return '● $s';
  return '● $s';
}

class AdminZoneDetailsData {
  const AdminZoneDetailsData({
    required this.zoneName,
    required this.location,
    required this.riskLevel,
    required this.density,
    required this.totalDetected,
    required this.lastMonitoring,
    required this.zoneInitials,
    required this.alertStatus,
  });

  final String zoneName;
  final String location;
  final String riskLevel;
  final double density;
  final int totalDetected;
  final String lastMonitoring;
  final String zoneInitials;
  /// Raw status from zones list (e.g. `Active (Outbreak)`), used for the summary pill.
  final String alertStatus;
}

class AdminZoneDetailsScreen extends StatefulWidget {
  const AdminZoneDetailsScreen({
    super.key,
    required this.zone,
  });

  final AdminZoneDetailsData zone;

  @override
  State<AdminZoneDetailsScreen> createState() => _AdminZoneDetailsScreenState();
}

class _AdminZoneDetailsScreenState extends State<AdminZoneDetailsScreen> {
  static const List<AdminDataTableColumn> _monitoringRecordColumns = [
    AdminDataTableColumn('Date & Time', 176),
    AdminDataTableColumn('Submitted By', 168),
    AdminDataTableColumn('COTS Count', 88, headerAlign: TextAlign.right),
    AdminDataTableColumn('Density (COTS/ha)', 132, headerAlign: TextAlign.right),
    AdminDataTableColumn('Notes', 320),
  ];

  Future<void> _logout() async {
    if (!context.mounted) return;
    await context.read<AuthProvider>().signOut();
  }

  void _onSidebarSelect(int index) {
    if (index == 2) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => AdminShellScreen(initialIndex: index),
      ),
    );
  }

  void _onZoneDetailsHeaderRefresh() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Zone details refreshed (demo).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final z = widget.zone;
    return adminThemedSubtree(
      context,
      child: AdminResponsiveChrome(
        selectedNavIndex: 2,
        onNavSelect: _onSidebarSelect,
        onLogout: _logout,
        pageTitle: 'Zone Details',
        showBackButton: false,
        onBack: null,
        body: LayoutBuilder(
          builder: (context, c) {
            return SingleChildScrollView(
              padding: AdminBreakpoints.pagePadding(c.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminDashboardHeader(
                    leading: AdminBackIconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    title: 'Zone Details',
                    subtitle:
                        'Review density trends, risk assessment, and recent monitoring records for this zone.',
                    onRefreshTap: _onZoneDetailsHeaderRefresh,
                  ),
                  const SizedBox(height: 16),
                  _topSection(z),
                  const SizedBox(height: 16),
                  _middleSection(z),
                  const SizedBox(height: 16),
                  _recordsTable(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _zoneInfoSummaryCard(AdminZoneDetailsData z) {
    return _card(
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final tight = w < 360;
          final compact = w < 480;
          final zoneTitleSize = compact ? 20.0 : (w < 560 ? 22.0 : 24.0);
          final avatar = tight ? 44.0 : 52.0;
          final initialsSize = tight ? 16.0 : 18.0;

          Widget riskPill() {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AdminColors.statRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                z.riskLevel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OctagonAvatar(size: avatar, letter: z.zoneInitials, fontSize: initialsSize),
                  SizedBox(width: tight ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              z.zoneName,
                              style: TextStyle(
                                fontSize: zoneTitleSize,
                                fontWeight: FontWeight.w800,
                                color: AdminColors.headerTitle,
                                height: 1.15,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: tight ? 9 : 11,
                                vertical: tight ? 4 : 5,
                              ),
                              decoration: BoxDecoration(
                                color: AdminColors.statRed,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _statusPillFromAlert(z.alertStatus),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                z.location,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: compact ? 12.5 : 13,
                                  height: 1.35,
                                  color: _kLabelGrey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _summaryLrRow(
                label: 'Risk Level',
                trailing: riskPill(),
              ),
              _summaryLrRow(
                label: 'Average Density',
                trailing: Text(
                  '${z.density.toStringAsFixed(2)} COTS/ha',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: z.density > 50 ? AdminColors.statRed : _kBodyGrey,
                  ),
                ),
              ),
              _summaryLrRow(
                label: 'Total COTS Detected',
                trailing: Text(
                  '${z.totalDetected}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _kBodyGrey,
                  ),
                ),
              ),
              _summaryLrRow(
                label: 'Last Monitoring',
                trailing: Text(
                  z.lastMonitoring.replaceAll('\n', ' '),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _kBodyGrey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryLrRow({
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _kLabelGrey,
              height: 1.25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _topSection(AdminZoneDetailsData z) {
    final infoCard = _zoneInfoSummaryCard(z);

    final mapCard = _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Zone Location',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AdminColors.headerTitle,
                  ),
                ),
              ),
              AdminBackIconButton(onPressed: () => Navigator.of(context).pop()),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _OceanMapPainter()),
                  CustomPaint(
                    painter: _ZonePolygonPainter(
                      zoneName: z.zoneName,
                      densityLabel: '${z.density.toStringAsFixed(2)} COTS/ha',
                      riskLabel: z.riskLevel,
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _MapZoom(icon: Icons.add_rounded),
                        const SizedBox(height: 6),
                        const _MapZoom(icon: Icons.remove_rounded),
                        const SizedBox(height: 6),
                        _MapZoom(icon: Icons.layers_outlined),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(color: AdminColors.statRed),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            z.zoneName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _kBodyGrey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              infoCard,
              const SizedBox(height: 14),
              mapCard,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 34, child: infoCard),
            const SizedBox(width: 14),
            Expanded(flex: 66, child: mapCard),
          ],
        );
      },
    );
  }

  Widget _middleSection(AdminZoneDetailsData z) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 44,
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'COTS Density Trend',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AdminColors.headerTitle,
                      ),
                    ),
                    Spacer(),
                    _TinyDrop(text: 'This Week'),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (v) => FlLine(
                          color: Colors.black.withValues(alpha: 0.06),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          color: const Color(0xFF3A8FB7),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          spots: const [
                            FlSpot(0, 32),
                            FlSpot(1, 45),
                            FlSpot(2, 28),
                            FlSpot(3, 67),
                            FlSpot(4, 50),
                            FlSpot(5, 78),
                            FlSpot(6, 48),
                          ],
                        ),
                      ],
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 25,
                            getTitlesWidget: (v, meta) => Text(
                              v.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AdminColors.muted.withValues(alpha: 0.88),
                              ),
                            ),
                          ),
                        ),
                        topTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles:
                            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (v, meta) {
                              const labels = ['May 12', 'May 13', 'May 14', 'May 15', 'May 16', 'May 17', 'May 18'];
                              final i = v.toInt();
                              if (i < 0 || i >= labels.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[i],
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.muted.withValues(alpha: 0.9),
                                  ),
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      minY: 0,
                      maxY: 100,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 28,
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Density Level',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AdminColors.headerTitle,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final gaugeH = (w * 0.42 + 52).clamp(138.0, 188.0);
                    return SizedBox(
                      height: gaugeH,
                      child: ClipRect(
                        child: CustomPaint(
                          painter: _GaugePainter(value: z.density, max: 100),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 26),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    z.density.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: AdminColors.headerTitle,
                                      height: 1.05,
                                    ),
                                  ),
                                  Text(
                                    'COTS/ha',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                      height: 1.15,
                                      color: AdminColors.muted.withValues(alpha: 0.92),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'High',
                                    style: TextStyle(
                                      color: AdminColors.statRed,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5,
                                      height: 1.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    _LegendDot(color: AdminColors.statGreen, text: 'Low (<20)'),
                    SizedBox(width: 8),
                    _LegendDot(color: AdminColors.statYellow, text: 'Moderate (20-50)'),
                    SizedBox(width: 8),
                    _LegendDot(color: AdminColors.statRed, text: 'High (>50)'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 28,
          child: _card(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk Assessment',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AdminColors.headerTitle,
                  ),
                ),
                SizedBox(height: 12),
                _RiskMeta(label: 'Risk Level', value: 'High'),
                SizedBox(height: 8),
                _RiskMeta(label: 'Status', value: 'Active'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _recordsTable() {
    const rows = [
      ('May 18, 2026 09:15 AM', 'Juan Dela Cruz', 67, 78.40, 'High density observed'),
      ('May 17, 2026 08:50 AM', 'Pedro Reyes', 51, 60.90, 'Increasing trend'),
      ('May 16, 2026 10:10 AM', 'Maria Santos', 27, 32.10, 'Moderate density'),
      ('May 15, 2026 09:25 AM', 'Ana Garcia', 22, 26.40, 'Stable'),
      ('May 14, 2026 08:30 AM', 'Luis Mendoza', 18, 18.90, 'Low density'),
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Recent Monitoring Records',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AdminColors.headerTitle,
            ),
          ),
          const SizedBox(height: 10),
          AdminDataTableScrollArea(
            tableWidth: AdminDataTableColumn.totalWidth(_monitoringRecordColumns),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AdminDataTableHeader(columns: _monitoringRecordColumns),
                for (final r in rows)
                  AdminDataTableStaticRow(
                    columnWidths: AdminDataTableColumn.widthsMap(_monitoringRecordColumns),
                    cells: [
                      AdminDataTableCells.text(r.$1),
                      AdminDataTableCells.text(r.$2),
                      AdminDataTableCells.text('${r.$3}', align: TextAlign.right),
                      AdminDataTableCells.text(r.$4.toStringAsFixed(2), align: TextAlign.right),
                      AdminDataTableCells.text(r.$5),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('View All Records'),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TinyDrop extends StatelessWidget {
  const _TinyDrop({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
        ],
      ),
    );
  }
}

class _RiskMeta extends StatelessWidget {
  const _RiskMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
              height: 1.2,
              color: AdminColors.muted.withValues(alpha: 0.95),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: AdminColors.statRed.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: AdminColors.statRed,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _MapZoom extends StatelessWidget {
  const _MapZoom({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

Path _octagonPath(Size size) {
  final w = size.width;
  final h = size.height;
  final corner = w * 0.2;
  return Path()
    ..moveTo(corner, 0)
    ..lineTo(w - corner, 0)
    ..lineTo(w, corner)
    ..lineTo(w, h - corner)
    ..lineTo(w - corner, h)
    ..lineTo(corner, h)
    ..lineTo(0, h - corner)
    ..lineTo(0, corner)
    ..close();
}

class _OctagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _octagonPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _OctagonOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _octagonPath(size),
      Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _OctagonAvatar extends StatelessWidget {
  const _OctagonAvatar({
    required this.size,
    required this.letter,
    required this.fontSize,
  });

  final double size;
  final String letter;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipPath(
            clipper: _OctagonClipper(),
            child: ColoredBox(
              color: const Color(0xFFFFEBEB),
              child: SizedBox(width: size, height: size),
            ),
          ),
          CustomPaint(
            size: Size(size, size),
            painter: _OctagonOutlinePainter(),
          ),
          Text(
            letter,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              color: const Color(0xFFC62828),
            ),
          ),
        ],
      ),
    );
  }
}

class _OceanMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ocean = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [
          Color(0xFF0D47A1),
          Color(0xFF01579B),
          Color(0xFF1B5E20),
        ],
        const [0.0, 0.56, 1.0],
      );
    canvas.drawRect(rect, ocean);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZonePolygonPainter extends CustomPainter {
  const _ZonePolygonPainter({
    required this.zoneName,
    required this.densityLabel,
    required this.riskLabel,
  });

  final String zoneName;
  final String densityLabel;
  final String riskLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.22, size.height * 0.18)
      ..lineTo(size.width * 0.78, size.height * 0.15)
      ..lineTo(size.width * 0.84, size.height * 0.72)
      ..lineTo(size.width * 0.30, size.height * 0.80)
      ..lineTo(size.width * 0.18, size.height * 0.45)
      ..close();

    canvas.drawShadow(path, Colors.redAccent.withValues(alpha: 0.45), 16, false);
    canvas.drawPath(
      path,
      Paint()..color = const Color(0xCCEF5350),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final overlay = '$zoneName\n$densityLabel\n$riskLabel';
    final tp = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: overlay,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, height: 1.25),
      ),
    )..layout(maxWidth: 220);
    tp.paint(canvas, Offset(size.width * 0.47, size.height * 0.36) - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ZonePolygonPainter oldDelegate) {
    return oldDelegate.zoneName != zoneName ||
        oldDelegate.densityLabel != densityLabel ||
        oldDelegate.riskLabel != riskLabel;
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({required this.value, required this.max});

  final double value;
  final double max;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 18.0;
    final center = Offset(size.width / 2, size.height);
    // Keep the arc inside the box: wide columns used width-based radius that
    // overflowed upward and drew over the card title.
    final radiusFromWidth = size.width * 0.42;
    final radiusFromHeight = (size.height - stroke * 0.5 - 6).clamp(36.0, size.width * 0.48);
    final radius = radiusFromWidth < radiusFromHeight ? radiusFromWidth : radiusFromHeight;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    void arc(Color c, double start, double sweep) {
      base.color = c;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        base,
      );
    }

    arc(AdminColors.statGreen, 3.14, 1.04);
    arc(AdminColors.statYellow, 4.18, 1.04);
    arc(AdminColors.statRed, 5.22, 1.04);

    final n = (value / max).clamp(0.0, 1.0);
    final p = Offset(
      center.dx + radius * 0.85 * (ui.lerpDouble(-1, 1, n) ?? 0),
      center.dy - radius * 0.85 * (1 - (ui.lerpDouble(0, 1, n) ?? 0)).abs(),
    );
    canvas.drawCircle(p, 5, Paint()..color = Colors.black54);
    canvas.drawCircle(p, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.max != max;
  }
}
