import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Satellite-style zone overview with mock polygons (static mock data).
class ZoneMapOverviewCard extends StatelessWidget {
  const ZoneMapOverviewCard({super.key});

  static const _zones = <_ZoneMock>[
    _ZoneMock('A', AdminColors.zoneActive, [
      Offset(0.08, 0.55),
      Offset(0.22, 0.28),
      Offset(0.38, 0.35),
      Offset(0.32, 0.72),
    ]),
    _ZoneMock('B', AdminColors.zoneScheduled, [
      Offset(0.38, 0.22),
      Offset(0.55, 0.18),
      Offset(0.62, 0.42),
      Offset(0.45, 0.48),
    ]),
    _ZoneMock('C', AdminColors.zoneCleared, [
      Offset(0.58, 0.48),
      Offset(0.78, 0.38),
      Offset(0.88, 0.62),
      Offset(0.68, 0.78),
    ]),
    _ZoneMock('D', AdminColors.zoneActive, [
      Offset(0.18, 0.78),
      Offset(0.35, 0.72),
      Offset(0.42, 0.92),
      Offset(0.12, 0.95),
    ]),
    _ZoneMock('E', AdminColors.zoneCleared, [
      Offset(0.42, 0.52),
      Offset(0.58, 0.55),
      Offset(0.52, 0.88),
      Offset(0.28, 0.82),
    ]),
    _ZoneMock('F', AdminColors.zoneScheduled, [
      Offset(0.72, 0.22),
      Offset(0.92, 0.28),
      Offset(0.95, 0.48),
      Offset(0.78, 0.42),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Zone Map Overview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.headerTitle,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.open_in_full_rounded, size: 18),
                label: const Text('Expand Map'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _OceanPainter()),
                  CustomPaint(painter: _ZonesPainter(zones: _zones)),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _zoomBtn(Icons.remove),
                        const SizedBox(height: 6),
                        _zoomBtn(Icons.add),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _legendRow('Active', AdminColors.zoneActive),
                          _legendRow('Scheduled', AdminColors.zoneScheduled),
                          _legendRow('Cleared', AdminColors.zoneCleared),
                        ],
                      ),
                    ),
                  ),
                  ..._zones.map((z) {
                    final mx = z.normPoints.map((e) => e.dx).reduce((a, b) => a + b) /
                        z.normPoints.length;
                    final my = z.normPoints.map((e) => e.dy).reduce((a, b) => a + b) /
                        z.normPoints.length;
                    return Align(
                      alignment: Alignment(2 * mx - 1, 2 * my - 1),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 28),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          'Zone ${z.id}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _zoomBtn(IconData icon) {
    return Material(
      color: Colors.white.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: AdminColors.headerTitle),
        ),
      ),
    );
  }

  static Widget _legendRow(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ZoneMock {
  const _ZoneMock(this.id, this.color, this.normPoints);

  final String id;
  final Color color;
  final List<Offset> normPoints;
}

class _OceanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final ocean = Paint()
      ..shader = ui.Gradient.linear(
        rect.topLeft,
        rect.bottomRight,
        const [
          Color(0xFF0D47A1),
          Color(0xFF0277BD),
          Color(0xFF006064),
          Color(0xFF004D40),
        ],
        const [0.0, 0.35, 0.7, 1.0],
      );
    canvas.drawRect(rect, ocean);

    final foam = Paint()..color = Colors.white.withValues(alpha: 0.06);
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.15 + i * 0.11);
      canvas.drawCircle(Offset(size.width * 0.2, y), 40 + i * 6.0, foam);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ZonesPainter extends CustomPainter {
  _ZonesPainter({required this.zones});

  final List<_ZoneMock> zones;

  @override
  void paint(Canvas canvas, Size size) {
    for (final z in zones) {
      final path = Path();
      for (var i = 0; i < z.normPoints.length; i++) {
        final p = Offset(z.normPoints[i].dx * size.width, z.normPoints[i].dy * size.height);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = z.color
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
