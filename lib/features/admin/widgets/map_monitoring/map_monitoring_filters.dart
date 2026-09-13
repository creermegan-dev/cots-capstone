import 'package:flutter/material.dart';

import '../../theme/admin_theme.dart';

class MapMonitoringFilters extends StatelessWidget {
  const MapMonitoringFilters({
    super.key,
    required this.zoneFilter,
    required this.statusFilter,
    required this.riskFilter,
    required this.densityFilter,
    required this.onZoneChanged,
    required this.onStatusChanged,
    required this.onRiskChanged,
    required this.onDensityChanged,
    this.trailing,
  });

  final String zoneFilter;
  final String statusFilter;
  final String riskFilter;
  final String densityFilter;
  final ValueChanged<String?> onZoneChanged;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onRiskChanged;
  final ValueChanged<String?> onDensityChanged;
  /// Optional actions shown after the filter dropdowns (wide layout).
  final List<Widget>? trailing;

  static const _zones = ['All Zones', 'Zone A', 'Zone B', 'Zone C', 'Zone D'];
  static const _status = ['All Status', 'Active', 'Scheduled', 'Stable', 'Watch'];
  static const _risk = ['All Risk Levels', 'High', 'Moderate', 'Low'];
  static const _density = ['All Density Levels', '> 50 COTS/ha', '25–50', '< 25'];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth.isFinite
            ? c.maxWidth
            : MediaQuery.sizeOf(context).width;
        final cards = [
          _FilterCard(
            label: 'Select Zone',
            value: zoneFilter,
            items: _zones,
            onChanged: onZoneChanged,
          ),
          _FilterCard(
            label: 'Status',
            value: statusFilter,
            items: _status,
            onChanged: onStatusChanged,
          ),
          _FilterCard(
            label: 'Infestation Level',
            value: riskFilter,
            items: _risk,
            onChanged: onRiskChanged,
          ),
          _FilterCard(
            label: 'Density',
            value: densityFilter,
            items: _density,
            onChanged: onDensityChanged,
          ),
        ];
        if (maxW < 900) {
          final colW = maxW < 480 ? maxW : (maxW - 12) / 2;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map((card) => SizedBox(width: colW, child: card))
                    .toList(),
              ),
              if (trailing != null && trailing!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.start,
                  children: trailing!,
                ),
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            ),
            if (trailing != null && trailing!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var j = 0; j < trailing!.length; j++) ...[
                      if (j > 0) const SizedBox(width: 10),
                      trailing![j],
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterCard extends StatefulWidget {
  const _FilterCard({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  State<_FilterCard> createState() => _FilterCardState();
}

class _FilterCardState extends State<_FilterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Transform.translate(
        offset: Offset(0, _hover ? -2 : 0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.10 : 0.06),
                blurRadius: _hover ? 22 : 18,
                offset: Offset(0, _hover ? 8 : 6),
              ),
            ],
            border: Border.all(color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.05)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: AdminColors.muted.withValues(alpha: 0.85),
                ),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: widget.items.contains(widget.value) ? widget.value : widget.items.first,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(12),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AdminColors.headerTitle),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AdminColors.headerTitle,
                  ),
                  items: widget.items
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ),
                      )
                      .toList(),
                  onChanged: widget.onChanged,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
