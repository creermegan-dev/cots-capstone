import 'package:flutter/material.dart';

/// Global search for the admin shell — used in the sidebar and mobile drawer only
/// (not in top app bars).
class AdminShellSearchBar extends StatelessWidget {
  const AdminShellSearchBar({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 12),
  });

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 40,
        child: TextField(
          readOnly: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Global search (demo).')),
            );
          },
          style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: 0.92)),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            isDense: true,
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.55),
              size: 22,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          ),
        ),
      ),
    );
  }
}
