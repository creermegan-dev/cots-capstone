import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/cots_colors.dart';
import 'auth_layout.dart';

/// Rounded auth field — mobile styling below 768px, premium desktop styling above.
class CotsAuthTextField extends StatelessWidget {
  const CotsAuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.inputFormatters,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onFieldSubmitted;

  static OutlineInputBorder _border(Color color, double radius) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: 1),
      );

  @override
  Widget build(BuildContext context) {
    final desktop = authUseDesktopFields(context);
    final radius = desktop ? AuthTokens.fieldRadius : 14.0;
    final fill = desktop ? AuthTokens.inputFill : Colors.white;
    final borderColor = desktop ? AuthTokens.inputBorder : kBorderGray;
    final focusColor = desktop ? AuthTokens.focusTeal : kPrimaryTeal;
    final labelColor = desktop ? AuthTokens.titleNavy : kDarkTeal;
    final iconSize = desktop ? 20.0 : 22.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: desktop ? 14 : 13,
            fontWeight: FontWeight.w600,
            color: labelColor,
          ),
        ),
        SizedBox(height: desktop ? 10 : 8),
        SizedBox(
          height: desktop ? AuthTokens.fieldHeight : null,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            onFieldSubmitted: onFieldSubmitted,
            validator: validator,
            style: TextStyle(
              fontSize: desktop ? 15 : 16,
              fontWeight: FontWeight.w500,
              color: AuthTokens.titleNavy,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AuthTokens.subtitleGray.withValues(alpha: 0.75),
                fontWeight: FontWeight.w400,
              ),
              filled: true,
              fillColor: fill,
              prefixIcon: Icon(prefixIcon, color: focusColor, size: iconSize),
              contentPadding: EdgeInsets.symmetric(
                horizontal: desktop ? 16 : 4,
                vertical: desktop ? 0 : 14,
              ),
              border: _border(borderColor, radius),
              enabledBorder: _border(borderColor, radius),
              focusedBorder: _border(focusColor, radius),
              errorBorder: _border(kDangerRed, radius),
              focusedErrorBorder: _border(kDangerRed, radius),
            ),
          ),
        ),
      ],
    );
  }
}
