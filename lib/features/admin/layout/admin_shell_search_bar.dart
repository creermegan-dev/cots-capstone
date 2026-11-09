import 'package:flutter/material.dart';

/// Global search for the admin shell — used in the sidebar and mobile drawer only
/// (not in top app bars).
class AdminShellSearchBar extends StatelessWidget {
  const AdminShellSearchBar({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
