import 'package:flutter/material.dart';

import 'auth_layout.dart';

/// Full-width primary action with shared auth sizing and feedback.
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
    const radius = AuthTokens.buttonRadius;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: AuthTokens.buttonHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: AuthTokens.focusTeal.withValues(
            alpha: widget.isLoading ? 0.60 : (_hover ? 0.92 : 1),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: 0,
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
