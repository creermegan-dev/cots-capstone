import 'package:flutter/material.dart';

class AdminNavItemData {
  const AdminNavItemData({
    required this.icon,
    required this.label,
    required this.index,
    this.badge,
  });

  final IconData icon;
  final String label;
  final int index;
  final int? badge;
}

class AdminNavSectionHeader {
  const AdminNavSectionHeader(this.title);

  final String title;
}

typedef AdminNavEntry = Object;
