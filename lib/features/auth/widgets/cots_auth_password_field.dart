import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';

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

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: 1),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kDarkTeal,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          validator: widget.validator,
          autofillHints: widget.autofillHints,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(color: kMutedGray.withValues(alpha: 0.85)),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: kPrimaryTeal, size: 22),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: kMutedGray,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            border: _border(kBorderGray),
            enabledBorder: _border(kBorderGray),
            focusedBorder: _border(kPrimaryTeal),
            errorBorder: _border(kDangerRed),
            focusedErrorBorder: _border(kDangerRed),
          ),
        ),
      ],
    );
  }
}
