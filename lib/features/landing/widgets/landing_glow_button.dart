import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../landing_theme.dart';

/// Pill-shaped gradient CTA with hover glow (web-friendly).
class LandingGlowButton extends StatefulWidget {
  const LandingGlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool compact;

  @override
  State<LandingGlowButton> createState() => _LandingGlowButtonState();
}

class _LandingGlowButtonState extends State<LandingGlowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final vPad = widget.compact ? 10.0 : 14.0;
    final hPad = widget.compact ? 18.0 : 28.0;
    final fontSize = widget.compact ? 13.0 : 15.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LandingColors.buttonGradient,
          boxShadow: [
            BoxShadow(
              color: LandingColors.teal.withValues(alpha: _hovered ? 0.35 : 0.2),
              blurRadius: _hovered ? 18 : 12,
              spreadRadius: _hovered ? 1 : 0,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: fontSize + 2),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: fontSize,
                      letterSpacing: 0.6,
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
