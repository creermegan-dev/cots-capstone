import 'package:cots_monitor/widgets/app_back_icon_button.dart';
import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';
import 'auth_brand_panel.dart';
import 'auth_layout.dart';
import 'cots_auth_logo_badge.dart';
import 'ocean_background.dart';

/// Responsive shell for login / signup — preserves mobile layout below 768px.
class AuthResponsiveScaffold extends StatelessWidget {
  const AuthResponsiveScaffold({
    super.key,
    required this.formChild,
    this.mobileAppBarTitle,
    this.showMobileBackButton = false,
    this.desktopHeader,
    this.footer,
    this.mobileHeader,
  });

  final Widget formChild;
  final String? mobileAppBarTitle;
  final bool showMobileBackButton;
  final Widget? desktopHeader;
  final Widget? footer;
  /// Extra content above the card on mobile only (logo + titles).
  final Widget? mobileHeader;

  @override
  Widget build(BuildContext context) {
    final mode = authLayoutModeOf(context);
    if (mode == AuthLayoutMode.mobile) {
      return _MobileAuthScaffold(
        appBarTitle: mobileAppBarTitle,
        showBack: showMobileBackButton,
        header: mobileHeader,
        formChild: formChild,
        footer: footer,
      );
    }
    return _DesktopTabletScaffold(
      mode: mode,
      desktopHeader: desktopHeader,
      formChild: formChild,
      footer: footer,
    );
  }
}

class _MobileAuthScaffold extends StatelessWidget {
  const _MobileAuthScaffold({
    required this.formChild,
    this.appBarTitle,
    this.showBack = false,
    this.header,
    this.footer,
  });

  final Widget formChild;
  final String? appBarTitle;
  final bool showBack;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBarTitle == null
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: showBack
                  ? AppBackIconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      iconColor: kDarkTeal,
                    )
                  : null,
              title: Text(
                appBarTitle!,
                style: const TextStyle(
                  color: kDarkTeal,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),
      body: OceanBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[header!, const SizedBox(height: 28)],
                formChild,
                if (footer != null) ...[const SizedBox(height: 22), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopTabletScaffold extends StatelessWidget {
  const _DesktopTabletScaffold({
    required this.mode,
    required this.formChild,
    this.desktopHeader,
    this.footer,
  });

  final AuthLayoutMode mode;
  final Widget formChild;
  final Widget? desktopHeader;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final card = AuthFormCard(
      header: desktopHeader,
      footer: footer,
      child: formChild,
    );

    return Scaffold(
      body: OceanBackground(
        child: SafeArea(
          child: mode == AuthLayoutMode.desktop
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: AuthBreakpoints.pageMaxWidth,
                          maxHeight: constraints.maxHeight,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 20,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 4,
                                child: SizedBox(
                                  height: constraints.maxHeight - 40,
                                  child: const Center(
                                    child: SingleChildScrollView(
                                      child: AuthBrandPanel(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 6,
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: card,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                    child: card,
                  ),
                ),
        ),
      ),
    );
  }
}

/// White auth card — desktop/tablet styling.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.child,
    this.header,
    this.footer,
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final isDesktop = authLayoutModeOf(context) == AuthLayoutMode.desktop;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AuthBreakpoints.cardMaxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AuthTokens.cardRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: AuthTokens.cardShadow,
          ),
          child: Padding(
          padding: EdgeInsets.all(
            isDesktop ? AuthTokens.cardPaddingDesktop : 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (header != null) ...[header!, const SizedBox(height: 24)],
              child,
              if (footer != null) ...[const SizedBox(height: 20), footer!],
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// Standard desktop/tablet auth page header inside the card.
class AuthCardHeader extends StatelessWidget {
  const AuthCardHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AuthTokens.focusTeal.withValues(alpha: 0.1),
          ),
          child: const Padding(
            padding: EdgeInsets.all(5),
            child: CotsAuthLogoBadge(size: 34),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AuthTokens.titleNavy,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AuthTokens.subtitleGray.withValues(alpha: 0.95),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Mobile-only header block (unchanged from original auth screens).
class AuthMobileHeader extends StatelessWidget {
  const AuthMobileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const CotsAuthLogoBadge(),
        const SizedBox(height: 16),
        Text(
          'COTS Monitor',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: kDarkTeal,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Crown-of-Thorns Starfish Monitoring',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: kMutedGray,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

/// Mobile card wrapper (original 22px radius card).
class AuthMobileFormCard extends StatelessWidget {
  const AuthMobileFormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: child,
      ),
    );
  }
}
