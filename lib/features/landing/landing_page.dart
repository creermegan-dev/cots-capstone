import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../auth/auth_routes.dart';
import '../auth/login_screen.dart';
import 'landing_theme.dart';
import 'widgets/landing_bottom_wave.dart';
import 'widgets/landing_coral_decor.dart';
import 'widgets/landing_hero_image.dart';
import '../auth/widgets/cots_auth_logo_badge.dart';

/// Public marketing landing — split-screen hero matching marine SaaS reference.
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
          final isMobile = width < _tabletBreakpoint;

          if (isDesktop) {
            return _DesktopLanding(height: constraints.maxHeight);
          }
          return _MobileLanding(isMobile: isMobile);
        },
      ),
    );
  }
}

// ─── Desktop ─────────────────────────────────────────────────────────────────

class _DesktopLanding extends StatelessWidget {
  const _DesktopLanding({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: LandingColors.backgroundGradient),
        ),
        const Positioned.fill(
          child: LandingHeroImage(fullBleed: true),
        ),
        const Positioned(
          left: 0,
          bottom: 72,
          width: 420,
          height: 280,
          child: LandingCoralDecor(),
        ),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 16, 48, 0),
                child: _LandingHeader(),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 46,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(48, 24, 24, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: const _HeroCopy(showFeatures: false),
                          ),
                        ),
                      ),
                    ),
                    const Expanded(flex: 54, child: SizedBox()),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: LandingBottomWave(),
        ),
      ],
    );
  }
}

// ─── Mobile / Tablet ───────────────────────────────────────────────────────

class _MobileLanding extends StatelessWidget {
  const _MobileLanding({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: LandingColors.backgroundGradient),
        ),
        SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 20 : 32, 12, isMobile ? 20 : 32, 0),
                  child: _LandingHeader(),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(isMobile ? 20 : 32, 28, isMobile ? 20 : 32, 0),
                  child: _HeroCopy(showFeatures: true),
                ),
                SizedBox(height: isMobile ? 24 : 32),
                SizedBox(
                  height: isMobile ? 260 : 340,
                  child: LandingHeroImage(
                    borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
        const Align(
          alignment: Alignment.bottomCenter,
          child: LandingBottomWave(),
        ),
      ],
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────

class _LandingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < LandingPage._tabletBreakpoint;

    return Row(
      children: [
        const _BrandLogo(),
        const Spacer(),
        _LoginButton(compact: compact),
      ],
    );
  }
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < LandingPage._tabletBreakpoint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 44,
          height: compact ? 38 : 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LandingColors.teal.withValues(alpha: 0.1),
            border: Border.all(
              color: LandingColors.teal.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: ClipOval(
              child: Image.asset(
                kCotsLogoAsset,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        SizedBox(width: compact ? 10 : 12),
        Text(
          'COTS Monitor',
          style: GoogleFonts.inter(
            fontSize: compact ? 17 : 20,
            fontWeight: FontWeight.w800,
            color: LandingColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          );
        },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LandingColors.buttonGradient,
            boxShadow: [
              BoxShadow(
                color: LandingColors.teal.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 16 : 22,
              vertical: compact ? 10 : 12,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_outline_rounded, color: Colors.white, size: compact ? 18 : 20),
                SizedBox(width: compact ? 6 : 8),
                Text(
                  'Log In',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 13 : 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Hero copy ─────────────────────────────────────────────────────────────

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.showFeatures});

  final bool showFeatures;

  void _goSignup(BuildContext context) {
    Navigator.of(context).pushNamed(AuthRoutes.signup);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < LandingPage._tabletBreakpoint;
    final isDesktop = width >= LandingPage._desktopBreakpoint;
    final headlineSize = isMobile
        ? (width < 400 ? 34.0 : 40.0)
        : isDesktop
            ? 52.0
            : 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _HeroBadge(),
        SizedBox(height: isMobile ? 20 : 28),
        _HeroHeadline(fontSize: headlineSize),
        SizedBox(height: isMobile ? 16 : 20),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 480),
          child: Text(
            'COTS Monitor is an AI-powered platform that helps detect and track Crown-of-Thorns Starfish (COTS) to protect coral reefs and marine ecosystems.',
            style: GoogleFonts.inter(
              color: LandingColors.textMuted,
              fontSize: isMobile ? 14 : 15.5,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        SizedBox(height: isMobile ? 28 : 36),
        _GetStartedButton(onPressed: () => _goSignup(context)),
        if (showFeatures) ...[
          const SizedBox(height: 36),
          const _FeatureList(),
        ],
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < LandingPage._tabletBreakpoint;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 7 : 9,
      ),
      decoration: BoxDecoration(
        color: LandingColors.badgeFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LandingColors.badgeBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.trending_up_rounded,
            size: compact ? 14 : 16,
            color: LandingColors.teal,
          ),
          SizedBox(width: compact ? 8 : 10),
          Flexible(
            child: Text(
              'AI-POWERED • CITIZEN DRIVEN • REEF FOCUSED',
              style: GoogleFonts.inter(
                color: LandingColors.teal,
                fontSize: compact ? 9.5 : 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
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
      height: 1.12,
      letterSpacing: -0.8,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monitor. Protect.', style: base.copyWith(color: LandingColors.textPrimary)),
        Text.rich(
          TextSpan(
            style: base,
            children: const [
              TextSpan(
                text: 'Restore Our Reefs.',
                style: TextStyle(color: LandingColors.teal),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GetStartedButton extends StatefulWidget {
  const _GetStartedButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_GetStartedButton> createState() => _GetStartedButtonState();
}

class _GetStartedButtonState extends State<_GetStartedButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < LandingPage._tabletBreakpoint;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LandingColors.buttonGradient,
          boxShadow: [
            BoxShadow(
              color: LandingColors.teal.withValues(alpha: _hover ? 0.38 : 0.25),
              blurRadius: _hover ? 20 : 14,
              offset: Offset(0, _hover ? 8 : 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 24 : 28,
                vertical: compact ? 14 : 16,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.rocket_launch_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Get Started',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 15 : 16,
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

// ─── Features (mobile / tablet only) ───────────────────────────────────────

class _FeatureList extends StatelessWidget {
  const _FeatureList();

  static const _items = [
    _FeatureItem(Icons.photo_library_outlined, 'GoPro Image Analysis',
        'Upload underwater images and detect COTS instantly.'),
    _FeatureItem(Icons.map_outlined, 'GIS Mapping',
        'Visualize detections on interactive reef maps.'),
    _FeatureItem(Icons.groups_outlined, 'Citizen Science',
        'Contribute removal monitoring data as a diver.'),
    _FeatureItem(Icons.bar_chart_rounded, 'Reports & Analytics',
        'Generate monitoring reports for research teams.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LandingColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            _FeatureRow(item: _items[i]),
            if (i < _items.length - 1)
              const Divider(height: 1, thickness: 1, color: LandingColors.divider, indent: 56),
          ],
        ],
      ),
    );
  }
}

class _FeatureItem {
  const _FeatureItem(this.icon, this.title, this.description);
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LandingColors.teal.withValues(alpha: 0.1),
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
                    color: LandingColors.textPrimary,
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
