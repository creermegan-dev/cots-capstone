import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';
import 'auth_layout.dart';

/// Password field with visibility toggle and matching [CotsAuthTextField] styling.
class CotsAuthPasswordField extends StatefulWidget {
  const CotsAuthPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints = const [AutofillHints.newPassword],
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<CotsAuthPasswordField> createState() => _CotsAuthPasswordFieldState();
}

class _CotsAuthPasswordFieldState extends State<CotsAuthPasswordField> {
  bool _obscure = true;

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
          widget.label,
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
            controller: widget.controller,
            obscureText: _obscure,
            textInputAction: widget.textInputAction,
            onFieldSubmitted: widget.onFieldSubmitted,
            validator: widget.validator,
            autofillHints: widget.autofillHints,
            style: TextStyle(
              fontSize: desktop ? 15 : 16,
              fontWeight: FontWeight.w500,
              color: AuthTokens.titleNavy,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: AuthTokens.subtitleGray.withValues(alpha: 0.75),
              ),
              filled: true,
              fillColor: fill,
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: focusColor,
                size: iconSize,
              ),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AuthTokens.subtitleGray,
                  size: iconSize,
                ),
              ),
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
