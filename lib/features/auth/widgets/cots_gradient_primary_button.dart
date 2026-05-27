import 'package:flutter/material.dart';

import 'auth_layout.dart';

/// Full-width gradient CTA used on auth screens.
class CotsGradientPrimaryButton extends StatefulWidget {
  const CotsGradientPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  State<CotsGradientPrimaryButton> createState() =>
      _CotsGradientPrimaryButtonState();
}

class _CotsGradientPrimaryButtonState extends State<CotsGradientPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final desktop = authUseDesktopFields(context);
    final radius = desktop ? AuthTokens.buttonRadius : 16.0;
    final height = desktop ? AuthTokens.buttonHeight : null;
    final vPad = desktop ? 0.0 : 16.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            colors: [
              AuthTokens.gradientStart.withValues(
                alpha: widget.isLoading ? 0.65 : 1,
              ),
              AuthTokens.gradientEnd.withValues(
                alpha: widget.isLoading ? 0.65 : 1,
              ),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: _hover && desktop && !widget.isLoading
              ? [
                  BoxShadow(
                    color: AuthTokens.gradientStart.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AuthTokens.gradientStart.withValues(alpha: 0.25),
                    blurRadius: desktop ? 12 : 8,
                    offset: Offset(0, desktop ? 6 : 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: vPad),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: widget.isLoading
                      ? const SizedBox(
                          key: ValueKey('loading'),
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          widget.label,
                          key: const ValueKey('label'),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: desktop ? 16 : 16,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
