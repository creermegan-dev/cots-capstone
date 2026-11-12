import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../widgets/cots_logo.dart';

import '../auth/auth_routes.dart';
import '../auth/login_screen.dart';
import 'landing_theme.dart';
import 'widgets/landing_hero_image.dart';

/// Responsive marine-themed landing page matching the COTS Monitor reference mockup.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  /// Breakpoint between single-column mobile/tablet and split-screen desktop.
  static const _tabletBreakpoint = 860.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandingColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final isDesktop = width >= _tabletBreakpoint;

          if (isDesktop) {
            return _DesktopLanding(width: width, height: height);
          }
          return _MobileLanding(width: width, height: height);
        },
      ),
    );
  }
}

// ─── Desktop Layout ──────────────────────────────────────────────────────────

class _DesktopLanding extends StatelessWidget {
  const _DesktopLanding({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isCompactDesktop = width < 1100;
    final horizontalPadding = isCompactDesktop ? 40.0 : 64.0;
    final contentWidth = math.min(1060.0, width - horizontalPadding * 2);
    final imageWidth = math.min(440.0, contentWidth * 0.43);
    final heroHeight = (height - 104).clamp(460.0, 760.0);
    final mistHeight = math.max(260.0, height * 0.42);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Soft marine seafoam base gradient from Login/Auth
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LandingColors.backgroundGradient,
          ),
        ),

        // 2. Decorative ocean orbs, arc contour, and coral line art
        const CustomPaint(
          painter: _LandingOceanDecorPainter(isDesktop: true),
          size: Size.infinite,
        ),

        // 2. Underwater ambient cyan/mint mist rising from bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: mistHeight,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LandingColors.bottomMistGradient,
              ),
            ),
          ),
        ),

        // 3. Foreground content — vertically centered with graceful scrolling
        SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    const _LandingHeader(),

                    // Centered hero split content
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: contentWidth),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Left column: Headline, Subtitle, CTA
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 440,
                                    ),
                                    child: _HeroCopy(
                                      isMobile: false,
                                      fontSize: isCompactDesktop ? 44.0 : 52.0,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(width: isCompactDesktop ? 48 : 96),

                              // Right column: COTS image card
                              SizedBox(
                                width: imageWidth,
                                height: heroHeight,
                                child: const LandingHeroImage(
                                  fullBleed: true,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(36),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Mobile / Tablet Layout ──────────────────────────────────────────────────

class _MobileLanding extends StatelessWidget {
  const _MobileLanding({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isTabletPortrait = width >= 600;
    final isVerySmall = width < 360;
    final horizontalPadding =
        isVerySmall ? 16.0 : (isTabletPortrait ? 36.0 : 24.0);
    final mistHeight = math.max(280.0, height * 0.40);
    final headlineSize = isTabletPortrait ? 38.0 : (isVerySmall ? 28.0 : 32.0);

    final availableWidth = width - (horizontalPadding * 2);
    final cardWidth =
        math.min(availableWidth, isTabletPortrait ? 340.0 : 270.0);
    final cardHeight = cardWidth / 0.74;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Soft marine seafoam base gradient from Login/Auth
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LandingColors.backgroundGradient,
          ),
        ),

        // 2. Decorative ocean orbs, arc contour, and coral line art
        const CustomPaint(
          painter: _LandingOceanDecorPainter(isDesktop: false),
          size: Size.infinite,
        ),

        // Underwater ambient cyan/mint mist rising from bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: mistHeight,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LandingColors.bottomMistGradient,
              ),
            ),
          ),
        ),

        SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 18,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LandingHeader(),
                    SizedBox(height: isTabletPortrait ? 32 : 24),
                    _HeroCopy(
                      isMobile: true,
                      fontSize: headlineSize,
                    ),
                    SizedBox(height: isTabletPortrait ? 32 : 24),
                    Center(
                      child: SizedBox(
                        width: cardWidth,
                        height: cardHeight,
                        child: const LandingHeroImage(),
                      ),
                    ),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _LandingHeader extends StatelessWidget {
  const _LandingHeader();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _BrandLogo(compact: compact)),
        const SizedBox(width: 8),
        _ProfileAvatarButton(compact: compact),
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 32 : 36,
          height: compact ? 32 : 36,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: LandingColors.logoCircleBg,
          ),
          alignment: Alignment.center,
          child: CotsLogo(size: compact ? 32 : 36),
        ),
        SizedBox(width: compact ? 8 : 12),
        Flexible(
          child: Text(
            'COTS Monitor',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 16 : 19,
              fontWeight: FontWeight.w600,
              color: LandingColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  const _ProfileAvatarButton({this.compact = false});

  final bool compact;

  void _onTap(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 40.0;

    return Tooltip(
      message: 'Log In',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => _onTap(context),
          customBorder: const CircleBorder(),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LandingColors.avatarBg,
              boxShadow: [
                BoxShadow(
                  color: LandingColors.avatarBg.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: compact ? 19 : 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero Copy & Action ──────────────────────────────────────────────────────

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.isMobile,
    required this.fontSize,
  });

  final bool isMobile;
  final double fontSize;

  void _onStartMonitoring(BuildContext context) {
    Navigator.of(context).pushNamed(AuthRoutes.signup);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Headline
        Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: isMobile ? 1.10 : 1.02,
              letterSpacing: fontSize >= 40 ? -1.0 : -0.5,
            ),
            children: const [
              TextSpan(
                text: 'Monitor.\nProtect.\n',
                style: TextStyle(color: LandingColors.textPrimary),
              ),
              TextSpan(
                text: 'Restore our\nreefs.',
                style: TextStyle(color: LandingColors.teal),
              ),
            ],
          ),
        ),

        SizedBox(height: isMobile ? 14 : 18),

        // Subtitle
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? 440 : 360),
          child: Text(
            'Detect crown-of-thorns starfish, map reef activity, and verify removals with expert support.',
            style: TextStyle(
              color: LandingColors.textMuted,
              fontSize: isMobile ? 13.5 : 17.0,
              height: isMobile ? 1.5 : 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),

        SizedBox(height: isMobile ? 22 : 36),

        // "Start monitoring" Button
        _StartMonitoringButton(onPressed: () => _onStartMonitoring(context)),
      ],
    );
  }
}

class _StartMonitoringButton extends StatefulWidget {
  const _StartMonitoringButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_StartMonitoringButton> createState() => _StartMonitoringButtonState();
}

class _StartMonitoringButtonState extends State<_StartMonitoringButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: _hover
              ? LandingColors.buttonTeal.withValues(alpha: 0.92)
              : LandingColors.buttonTeal,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 360 ? 14 : 22,
                vertical: 14,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_center_focus_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Start monitoring',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.0,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Background Ocean Decor ──────────────────────────────────────────────────

class _LandingOceanDecorPainter extends CustomPainter {
  const _LandingOceanDecorPainter({required this.isDesktop});

  final bool isDesktop;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final alpha = isDesktop ? 0.08 : 0.10;

    // 1. Soft decorative cyan / teal orbs (matching Login/Auth background)
    final blobPaint = Paint()
      ..color = const Color(0xFF00B8B0).withValues(alpha: alpha);

    // Top-left orb (behind title branding)
    canvas.drawCircle(
      Offset(w * 0.08, h * 0.20),
      math.min(w * 0.085, 95.0),
      blobPaint,
    );
    // Lower-left large orb
    canvas.drawCircle(
      Offset(w * 0.16, h * 0.74),
      math.min(w * 0.095, 115.0),
      blobPaint,
    );
    // Lower-left companion orb
    canvas.drawCircle(
      Offset(w * 0.28, h * 0.82),
      math.min(w * 0.045, 55.0),
      blobPaint,
    );
    // Top-right orb
    canvas.drawCircle(
      Offset(w * 0.92, h * 0.24),
      math.min(w * 0.065, 80.0),
      blobPaint,
    );
    // Lower-right orb
    canvas.drawCircle(
      Offset(w * 0.86, h * 0.68),
      math.min(w * 0.075, 95.0),
      blobPaint,
    );

    // 2. Upper contour arc
    final arcPaint = Paint()
      ..color =
          const Color(0xFF00B8B0).withValues(alpha: isDesktop ? 0.07 : 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawArc(
      Rect.fromLTWH(-w * 0.05, -h * 0.02, w * 0.7, h * 0.28),
      0.3,
      1.0,
      false,
      arcPaint,
    );

    // 3. Abstract coral branches and wave lines on lower-left (from photo 1)
    final linePaint = Paint()
      ..color =
          const Color(0xFF00B8B0).withValues(alpha: isDesktop ? 0.16 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final base = Offset(w * 0.14, h * 0.86);
    canvas.drawLine(base, Offset(w * 0.17, h * 0.70), linePaint);
    canvas.drawLine(
      Offset(w * 0.17, h * 0.78),
      Offset(w * 0.24, h * 0.73),
      linePaint,
    );
    canvas.drawLine(
      Offset(w * 0.17, h * 0.74),
      Offset(w * 0.22, h * 0.67),
      linePaint,
    );

    // Soft wave contour path
    final wave = Path()
      ..moveTo(0, h * 0.88)
      ..quadraticBezierTo(w * 0.28, h * 0.78, w * 0.58, h * 0.87)
      ..quadraticBezierTo(w * 0.82, h * 0.94, w, h * 0.85);
    canvas.drawPath(wave, linePaint..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(covariant _LandingOceanDecorPainter oldDelegate) =>
      oldDelegate.isDesktop != isDesktop;
}
