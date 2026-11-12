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
    this.onBackToLanding,
  });

  final Widget formChild;
  final String? mobileAppBarTitle;
  final bool showMobileBackButton;
  final Widget? desktopHeader;
  final Widget? footer;

  /// Extra content above the card on mobile only (logo + titles).
  final Widget? mobileHeader;
  final VoidCallback? onBackToLanding;

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
        onBackToLanding: onBackToLanding,
      );
    }
    return _DesktopTabletScaffold(
      mode: mode,
      desktopHeader: desktopHeader,
      formChild: formChild,
      footer: footer,
      onBackToLanding: onBackToLanding,
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
    this.onBackToLanding,
  });

  final Widget formChild;
  final String? appBarTitle;
  final bool showBack;
  final Widget? header;
  final Widget? footer;
  final VoidCallback? onBackToLanding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: (appBarTitle == null && onBackToLanding == null)
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
              title: appBarTitle == null
                  ? null
                  : Text(
                      appBarTitle!,
                      style: const TextStyle(
                        color: kDarkTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
              centerTitle: true,
              actions: [
                if (onBackToLanding != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: AuthSmallBackButton(onPressed: onBackToLanding!),
                  ),
              ],
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
    this.onBackToLanding,
  });

  final AuthLayoutMode mode;
  final Widget formChild;
  final Widget? desktopHeader;
  final Widget? footer;
  final VoidCallback? onBackToLanding;

  @override
  Widget build(BuildContext context) {
    final card = AuthFormCard(
      header: desktopHeader,
      footer: footer,
      onBackToLanding: onBackToLanding,
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
                                child: SizedBox(
                                  height: constraints.maxHeight - 40,
                                  child: SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight - 40,
                                      ),
                                      child: Center(child: card),
                                    ),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 40),
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
    this.onBackToLanding,
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;
  final VoidCallback? onBackToLanding;

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
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(
                  isDesktop ? AuthTokens.cardPaddingDesktop : 36,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (header != null) ...[
                      header!,
                      const SizedBox(height: 24)
                    ],
                    child,
                    if (footer != null) ...[
                      const SizedBox(height: 20),
                      footer!
                    ],
                  ],
                ),
              ),
              if (onBackToLanding != null)
                Positioned(
                  top: 18,
                  right: 18,
                  child: AuthSmallBackButton(onPressed: onBackToLanding!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small `<` back button matching the requested navigation to landing.
class AuthSmallBackButton extends StatelessWidget {
  const AuthSmallBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back to Landing',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          hoverColor: AuthTokens.focusTeal.withValues(alpha: 0.12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 15,
              color: Color(0xFF334155),
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
    this.showLogo = true,
  });

  final String title;
  final String subtitle;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLogo) ...[
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
        ],
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
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
        const CotsAuthLogoBadge(size: 72),
        const SizedBox(height: 16),
        Text(
          'COTS Monitor',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: kDarkTeal,
                fontWeight: FontWeight.w600,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthTokens.inputBorder, width: 0.75),
        boxShadow: AuthTokens.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: child,
      ),
    );
  }
}
