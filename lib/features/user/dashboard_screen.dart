import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:intl/intl.dart';
import '../../core/cots_colors.dart';
import '../../providers/auth_provider.dart';
import 'cots_map_page.dart';
import 'profile_page.dart';
import 'records_page.dart';
import '../../services/scan_record_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_bottom_nav.dart';

/// Semicircle risk gauge: green (low) → amber (moderate) → red (high).
/// [needleT] is 0..1 across the arc (0 = low end, 1 = high end).
class RiskGaugePainter extends CustomPainter {
  const RiskGaugePainter({this.needleT = 0.52});

  /// Normalized position along the arc (moderate ≈ mid yellow band).
  final double needleT;

  static const double _stroke = 10;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Anchor the hub a little above the canvas bottom so the round caps and
    // hub circle never poke past the canvas edges. The arc + caps + hub all
    // fit within `size` regardless of aspect ratio.
    const bottomInset = 8.0;
    final centerY = h - bottomInset;
    final maxR = math.min(
      (w - _stroke - 6) / 2,
      centerY - _stroke / 2 - 2,
    );
    final r = math.max(0.0, maxR);
    final center = Offset(w / 2, centerY);
    final rect = Rect.fromCircle(center: center, radius: r);

    // Upper semicircle: start at π (left), sweep −π (counter‑clockwise to right).
    void drawSegment(double start, double sweep, Color color) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    drawSegment(math.pi, -math.pi / 3, kSuccessGreen);
    drawSegment(math.pi - math.pi / 3, -math.pi / 3, const Color(0xFFE8B339));
    drawSegment(math.pi - 2 * math.pi / 3, -math.pi / 3, kDangerRed);

    // Needle: angle interpolates along the arc from π → 0
    final t = needleT.clamp(0.0, 1.0);
    final needleAngle = math.pi * (1 - t);
    final needleLen = r - _stroke * 1.2;
    final tip = Offset(
      center.dx + needleLen * math.cos(needleAngle),
      center.dy + needleLen * math.sin(needleAngle),
    );

    const hubR = 5.0;
    final needlePaint = Paint()
      ..color = kSuccessGreen
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(
        center.dx + hubR * math.cos(needleAngle),
        center.dy + hubR * math.sin(needleAngle),
      ),
      tip,
      needlePaint,
    );

    canvas.drawCircle(center, hubR, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      hubR,
      Paint()
        ..color = kSuccessGreen
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant RiskGaugePainter oldDelegate) =>
      oldDelegate.needleT != needleT;
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subLabel,
  });

  final String title;
  final String value;
  final String subLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderGray),
        boxShadow: kSoftCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: kTextNavy,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: kTextNavy,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subLabel,
            style: const TextStyle(
              fontSize: 12,
              color: kMutedGray,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityItem extends StatelessWidget {
  const ActivityItem({
    super.key,
    required this.dotColor,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.time,
  });

  final Color dotColor;
  final String title;
  final String subtitle;
  final String date;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextNavy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: kMutedGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kTextNavy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: kMutedGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const double _horizontalPad = 18;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBody: true,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded, color: kTextNavy, size: 24),
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              await auth.signOut();
            },
          ),
        ],
        centerTitle: true,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'COTS Monitor',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: kTextNavy,
                height: 1.15,
              ),
            ),
            Text(
              'Crown-of-Thorns Starfish Monitoring',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: kMutedGray,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: userShellScanFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: UserBottomNavBar(
        active: UserNavDestination.dashboard,
        mapPageBuilder: () => const CotsMapPage(),
        recordsPageBuilder: () => const RecordsPage(),
        profilePageBuilder: () => const ProfilePage(),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            _horizontalPad,
            8,
            _horizontalPad,
            100,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OutbreakStatusCard(),
              const SizedBox(height: 18),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: ScanRecordService.statsStream(),
                builder: (context, snapshot) {
                  // Fallbacks to default constants if database document is empty
                  var totalCots = '1,248';
                  var activeZones = '12';
                  var clearedZones = '5';
                  var avgDensity = '3.6';

                  if (snapshot.hasData && snapshot.data!.exists) {
                    final data = snapshot.data!.data();
                    if (data != null) {
                      if (data['total_cots_detected'] != null) {
                        totalCots = NumberFormat('#,##0').format(data['total_cots_detected']);
                      }
                      if (data['total_scans'] != null) {
                        activeZones = data['total_scans'].toString();
                      }
                      final totalScans = data['total_scans'] as num? ?? 1;
                      final cotsVal = data['total_cots_detected'] as num? ?? 0;
                      if (totalScans > 0) {
                        avgDensity = (cotsVal / totalScans).toStringAsFixed(1);
                      }
                    }
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final maxW = constraints.maxWidth;
                      const spacing = 12.0;
                      final half = (maxW - spacing) / 2;
                      return Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: half,
                                child: StatCard(
                                  title: 'TOTAL COTS DETECTED',
                                  value: totalCots,
                                  subLabel: 'Starfish',
                                ),
                              ),
                              const SizedBox(width: spacing),
                              SizedBox(
                                width: half,
                                child: StatCard(
                                  title: 'TOTAL SCANS (LIVE)',
                                  value: activeZones,
                                  subLabel: 'Submissions',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: spacing),
                          Row(
                            children: [
                              SizedBox(
                                width: half,
                                child: StatCard(
                                  title: 'CLEARED ZONES',
                                  value: clearedZones,
                                  subLabel: 'Zones',
                                ),
                              ),
                              const SizedBox(width: spacing),
                              SizedBox(
                                width: half,
                                child: StatCard(
                                  title: 'DENSITY (AVG.)',
                                  value: avgDensity,
                                  subLabel: 'COTS / scan',
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kBorderGray),
                  boxShadow: kSoftCardShadow,
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECENT ACTIVITY',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: kTextNavy,
                      ),
                    ),
                    SizedBox(height: 4),
                    ActivityItem(
                      dotColor: kDangerRed,
                      title: 'Panabo Reef Zone A',
                      subtitle: '25 COTS detected',
                      date: 'May 18, 2024',
                      time: '8:30 AM',
                    ),
                    Divider(height: 1, thickness: 1, color: kBorderGray),
                    ActivityItem(
                      dotColor: kWarningOrange,
                      title: 'Samal Reef Zone B',
                      subtitle: '8 COTS detected',
                      date: 'May 18, 2024',
                      time: '7:15 AM',
                    ),
                    Divider(height: 1, thickness: 1, color: kBorderGray),
                    ActivityItem(
                      dotColor: kSuccessGreen,
                      title: 'Island Garden Zone C',
                      subtitle: '0 COTS detected (Cleared)',
                      date: 'May 17, 2024',
                      time: '4:45 PM',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutbreakStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: kDarkTeal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kDarkTeal.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OUTBREAK STATUS',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'MODERATE RISK',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: kWarningOrange,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Continue monitoring the areas.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Transform.translate(
                    offset: const Offset(0, -43),
                    child: SizedBox(
                      width: 110,
                      height: 64,
                      child: CustomPaint(
                        painter: RiskGaugePainter(needleT: 0.48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
