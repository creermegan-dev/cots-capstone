import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/cots_colors.dart';

/// Rounded outlined field with teal prefix icon and optional suffix.
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
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kDarkTeal,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: kMutedGray.withValues(alpha: 0.85)),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(prefixIcon, color: kPrimaryTeal, size: 22),
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
