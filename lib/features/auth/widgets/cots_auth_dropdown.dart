import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';

/// Dropdown form field aligned with auth text field visuals.
class CotsAuthDropdown<T> extends StatelessWidget {
  const CotsAuthDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.items,
    required this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final String hint;
  final IconData prefixIcon;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final void Function(T?) onChanged;
  final String? Function(T?)? validator;

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
        DropdownButtonFormField<T>(
          initialValue: value,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kMutedGray),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: kMutedGray.withValues(alpha: 0.85)),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: Icon(prefixIcon, color: kPrimaryTeal, size: 22),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
