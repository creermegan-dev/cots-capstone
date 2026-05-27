import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/auth_routes.dart';
import '../auth/login_screen.dart';
import 'landing_theme.dart';
import 'widgets/landing_contour_painter.dart';
import 'widgets/landing_glow_button.dart';
import 'widgets/landing_scan_hud.dart';

/// Public marketing landing page — desktop-first, responsive for web & mobile.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const _tabletBreakpoint = 900.0;
  static const _desktopBreakpoint = 1100.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandingColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final isDesktop = width >= _desktopBreakpoint;
          final isTablet =
              width >= _tabletBreakpoint && width < _desktopBreakpoint;
          final isMobile = width < _tabletBreakpoint;

          return Stack(
            fit: StackFit.expand,
            children: [
              const _LandingBackground(),
              SafeArea(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : isTablet ? 32 : 48,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          _LandingHeader(isCompact: isMobile),
                          SizedBox(height: isMobile ? 28 : 48),
                          if (isDesktop)
                            _DesktopHero()
                          else
                            _StackedHero(isMobile: isMobile),
                          SizedBox(height: isMobile ? 36 : 56),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: LandingColors.backgroundGradient)),
        CustomPaint(
          painter: LandingContourPainter(opacity: 0.14),
          size: Size.infinite,
        ),
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LandingColors.teal.withValues(alpha: 0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: -40,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  LandingColors.cyan.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        const _ParticleField(),
      ],
    );
  }
}

class _ParticleField extends StatelessWidget {
  const _ParticleField();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ParticlePainter(),
      size: Size.infinite,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final paint = Paint()..color = LandingColors.teal.withValues(alpha: 0.35);
    for (var i = 0; i < 28; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.8 + 0.4;
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader({required this.isCompact});

  final bool isCompact;

  void _goLogin(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _LandingLogo(),
        const Spacer(),
        LandingGlowButton(
          label: 'LOGIN',
          icon: Icons.person_outline_rounded,
          compact: true,
          onPressed: () => _goLogin(context),
        ),
      ],
    );
  }
}

class _LandingLogo extends StatelessWidget {
  const _LandingLogo();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = MediaQuery.sizeOf(context).width < LandingPage._tabletBreakpoint;
        final iconSize = compact ? 36.0 : 42.0;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: LandingColors.teal.withValues(alpha: 0.7), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: LandingColors.teal.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(
                Icons.hub_outlined,
                color: LandingColors.teal,
                size: iconSize * 0.52,
              ),
            ),
            SizedBox(width: compact ? 10 : 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                    children: const [
                      TextSpan(text: 'COTS ', style: TextStyle(color: Colors.white)),
                      TextSpan(text: 'MONITOR', style: TextStyle(color: LandingColors.teal)),
                    ],
                  ),
                ),
                if (compact) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Crown-of-Thorns Starfish\nMonitoring System',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: LandingColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DesktopHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(child: _HeroCopyColumn()),
          SizedBox(width: 40),
          Expanded(child: _HeroImagePanel()),
        ],
      ),
    );
  }
}

class _StackedHero extends StatelessWidget {
  const _StackedHero({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _HeroCopyColumn(),
        SizedBox(height: isMobile ? 28 : 36),
        const _HeroImagePanel(),
      ],
    );
  }
}

class _HeroCopyColumn extends StatelessWidget {
  const _HeroCopyColumn();

  void _goSignup(BuildContext context) {
    Navigator.of(context).pushNamed(AuthRoutes.signup);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < LandingPage._tabletBreakpoint;
    final headlineSize = isMobile
        ? (width < 400 ? 36.0 : 42.0)
        : width >= LandingPage._desktopBreakpoint
            ? 56.0
            : 48.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroHeadline(fontSize: headlineSize),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 580),
          child: Text(
            'AI-powered Crown-of-Thorns Starfish monitoring, mapping, and reef protection.',
            style: GoogleFonts.inter(
              color: LandingColors.textMuted,
              fontSize: isMobile ? 13.5 : 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 56,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LandingColors.heroGradient,
            boxShadow: [
              BoxShadow(
                color: LandingColors.teal.withValues(alpha: 0.6),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 24 : 32),
        LandingGlowButton(
          label: 'GET STARTED →',
          onPressed: () => _goSignup(context),
        ),
        SizedBox(height: isMobile ? 32 : 40),
        const _FeatureList(),
      ],
    );
  }
}

class _HeroHeadline extends StatelessWidget {
  const _HeroHeadline({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      height: 1.08,
      letterSpacing: -0.5,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monitor.', style: base.copyWith(color: Colors.white)),
        Text('Detect.', style: base.copyWith(color: Colors.white)),
        ShaderMask(
          shaderCallback: (bounds) => LandingColors.heroGradient.createShader(bounds),
          child: Text(
            'Protect Our Reefs.',
            style: base.copyWith(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _HeroImagePanel extends StatelessWidget {
  const _HeroImagePanel();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < LandingPage._tabletBreakpoint;
    final aspect = isMobile ? 16 / 12 : 5 / 4;

    return AspectRatio(
      aspectRatio: aspect,
      child: Container(
        padding: EdgeInsets.all(isMobile ? 12 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: LandingColors.glassFill.withValues(alpha: 0.62),
          border: Border.all(color: LandingColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: LandingColors.teal.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ShowcaseHeader(isMobile: isMobile),
            SizedBox(height: isMobile ? 10 : 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/landing_hero.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerRight,
                      errorBuilder: (_, __, ___) => const _HeroImageFallback(),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            LandingColors.background.withValues(alpha: 0.08),
                            LandingColors.background.withValues(alpha: 0.28),
                          ],
                        ),
                      ),
                    ),
                    const LandingScanHud(),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _OverlayTag(
                        icon: Icons.waves_rounded,
                        text: 'Live Reef Feed',
                        compact: isMobile,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0.86, -0.72),
                      child: _FloatingMetricCard(
                        title: 'COTS Detected',
                        value: '42',
                        compact: isMobile,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(-0.85, 0.08),
                      child: _FloatingMetricCard(
                        title: 'Detection Accuracy',
                        value: '92%',
                        compact: isMobile,
                      ),
                    ),
                    Align(
                      alignment: const Alignment(0.86, 0.64),
                      child: _FloatingMetricCard(
                        title: 'Active Zones',
                        value: '12',
                        compact: isMobile,
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _OverlayTag(
                        icon: Icons.hub_outlined,
                        text: 'Coral nodes online',
                        compact: isMobile,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isMobile ? 10 : 12),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(icon: Icons.auto_awesome, label: 'AI Detection Active'),
                _StatusChip(icon: Icons.map_outlined, label: 'GIS Monitoring Enabled'),
                _StatusChip(icon: Icons.bolt_rounded, label: 'Real-Time Analysis'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowcaseHeader extends StatelessWidget {
  const _ShowcaseHeader({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: isMobile ? 26 : 30,
          height: isMobile ? 26 : 30,
          decoration: BoxDecoration(
            color: LandingColors.teal.withValues(alpha: 0.16),
            shape: BoxShape.circle,
            border: Border.all(color: LandingColors.teal.withValues(alpha: 0.5)),
          ),
          child: Icon(
            Icons.radar_rounded,
            size: isMobile ? 15 : 17,
            color: LandingColors.teal,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'COTS MONITOR',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: isMobile ? 12 : 13,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _OverlayTag extends StatelessWidget {
  const _OverlayTag({
    required this.icon,
    required this.text,
    required this.compact,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: LandingColors.background.withValues(alpha: 0.36),
            border: Border.all(color: LandingColors.teal.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: compact ? 12 : 14, color: LandingColors.cyan),
              const SizedBox(width: 6),
              Text(
                text,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: compact ? 10 : 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingMetricCard extends StatelessWidget {
  const _FloatingMetricCard({
    required this.title,
    required this.value,
    required this.compact,
  });

  final String title;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          constraints: BoxConstraints(minWidth: compact ? 106 : 122),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 7 : 9,
          ),
          decoration: BoxDecoration(
            color: const Color(0xCC042638),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: LandingColors.teal.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: LandingColors.teal.withValues(alpha: 0.16),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: LandingColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: compact ? 9.5 : 10.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 17 : 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: LandingColors.background.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LandingColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: LandingColors.cyan),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroImageFallback extends StatelessWidget {
  const _HeroImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2840), Color(0xFF062032)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.waves_rounded, color: LandingColors.teal, size: 64),
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _items = [
    _FeatureItem(
      icon: Icons.photo_library_outlined,
      title: 'Image Analysis',
      description: 'Upload GoPro images and detect COTS instantly.',
    ),
    _FeatureItem(
      icon: Icons.map_outlined,
      title: 'GIS Mapping',
      description: 'Visualize detections on interactive maps.',
    ),
    _FeatureItem(
      icon: Icons.bar_chart_rounded,
      title: 'Data & Reports',
      description: 'Generate monitoring reports and analytics.',
    ),
    _FeatureItem(
      icon: Icons.groups_outlined,
      title: 'Community Driven',
      description: 'Support conservation teams and marine protection.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: LandingColors.glassFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: LandingColors.glassBorder),
          ),
          child: Column(
            children: [
              for (var i = 0; i < _items.length; i++) ...[
                _FeatureRow(item: _items[i]),
                if (i < _items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: LandingColors.divider,
                    indent: 56,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.item});

  final _FeatureItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: LandingColors.teal.withValues(alpha: 0.55)),
              boxShadow: [
                BoxShadow(
                  color: LandingColors.teal.withValues(alpha: 0.15),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(item.icon, color: LandingColors.teal, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: GoogleFonts.inter(
                    color: LandingColors.textMuted,
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
