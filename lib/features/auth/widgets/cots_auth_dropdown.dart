import 'package:flutter/material.dart';

import '../../../core/cots_colors.dart';
import 'auth_layout.dart';

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
          child: DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            validator: validator,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AuthTokens.subtitleGray,
              size: iconSize,
            ),
            style: TextStyle(
              fontSize: desktop ? 15 : 16,
              fontWeight: FontWeight.w500,
              color: AuthTokens.titleNavy,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: AuthTokens.subtitleGray.withValues(alpha: 0.75),
              ),
              filled: true,
              fillColor: fill,
              prefixIcon: Icon(prefixIcon, color: focusColor, size: iconSize),
              contentPadding: EdgeInsets.symmetric(
                horizontal: desktop ? 16 : 4,
                vertical: desktop ? 0 : 8,
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
