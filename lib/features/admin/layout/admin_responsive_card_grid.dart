import 'package:flutter/material.dart';

/// Masonry-style responsive grid: 1 / 2 / N columns from [minTileWidth].
class ResponsiveCardGrid extends StatelessWidget {
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.minTileWidth = 320,
    this.spacing = 14,
    this.runSpacing = 14,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = (w / (minTileWidth + spacing)).floor().clamp(1, 4);
        if (cols == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _withSpacing(children, runSpacing),
          );
        }
        final tileW = (w - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((e) => SizedBox(width: tileW, child: e)).toList(),
        );
      },
    );
  }

  static List<Widget> _withSpacing(List<Widget> items, double gap) {
    if (items.isEmpty) return items;
    final out = <Widget>[items.first];
    for (var i = 1; i < items.length; i++) {
      out..add(SizedBox(height: gap))..add(items[i]);
    }
    return out;
  }
}
