import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Web/desktop [RawScrollbar] on a horizontal [SingleChildScrollView] often paints as a
/// tall grey strip inside stretched columns; skip the wrapper for admin data tables.
class _AdminTableHorizontalScrollBehavior extends MaterialScrollBehavior {
  const _AdminTableHorizontalScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

const _kAdminTableHorizontalScrollBehavior = _AdminTableHorizontalScrollBehavior();

/// Design tokens shared by every admin data table (list screens, modals, cards).
abstract final class AdminDataTableTokens {
  static const double rowHeight = 56;
  static const double rowGap = 6;
  static const double cornerRadius = 10;
  static const EdgeInsets cellPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 0);
  static const Color headerFill = Color(0xFFF3F6FB);
  static const Duration hoverDuration = Duration(milliseconds: 160);
  static const Curve hoverCurve = Curves.easeOutCubic;

  static TextStyle get headerTextStyle =>
      const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AdminColors.muted);

  static TextStyle bodyTextStyle({Color? color, FontWeight? weight, double fontSize = 12.5}) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: weight ?? FontWeight.w600,
        color: color ?? AdminColors.headerTitle.withValues(alpha: 0.88),
        height: 1.2,
      );

  static List<BoxShadow> get rowShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];
}

Alignment adminDataTableAlign(TextAlign t) => switch (t) {
      TextAlign.right => Alignment.centerRight,
      TextAlign.center => Alignment.center,
      _ => Alignment.centerLeft,
    };

/// Column metadata for [AdminDataTableHeader] and [AdminDataTableColumn.widthsMap].
class AdminDataTableColumn {
  const AdminDataTableColumn(this.label, this.width, {this.headerAlign = TextAlign.left});
  final String label;
  final double width;
  final TextAlign headerAlign;

  static Map<int, TableColumnWidth> widthsMap(List<AdminDataTableColumn> columns) => {
        for (var i = 0; i < columns.length; i++) i: FixedColumnWidth(columns[i].width),
      };

  static double totalWidth(List<AdminDataTableColumn> columns) =>
      columns.fold<double>(0, (a, c) => a + c.width);
}

/// Rounded header strip with a single header row; widths must match body [Table] columns.
class AdminDataTableHeader extends StatelessWidget {
  const AdminDataTableHeader({super.key, required this.columns});

  final List<AdminDataTableColumn> columns;

  @override
  Widget build(BuildContext context) {
    final map = AdminDataTableColumn.widthsMap(columns);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminDataTableTokens.cornerRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AdminDataTableTokens.headerFill,
          borderRadius: BorderRadius.circular(AdminDataTableTokens.cornerRadius),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Table(
          columnWidths: map,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                for (final c in columns)
                  TableCell(
                    child: SizedBox(
                      height: AdminDataTableTokens.rowHeight,
                      child: Padding(
                        padding: AdminDataTableTokens.cellPadding,
                        child: Align(
                          alignment: adminDataTableAlign(c.headerAlign),
                          child: Text(
                            c.label,
                            textAlign: c.headerAlign,
                            style: AdminDataTableTokens.headerTextStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Standard status / risk / role pill used across admin tables.
class AdminDataTableBadge extends StatelessWidget {
  const AdminDataTableBadge({
    super.key,
    required this.label,
    required this.foreground,
    this.background,
    this.centerInCell = true,
  });

  final String label;
  final Color foreground;
  final Color? background;
  final bool centerInCell;

  static const double pillHeight = 28;

  @override
  Widget build(BuildContext context) {
    final bg = background ?? foreground.withValues(alpha: 0.13);
    final pill = Container(
      height: pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: foreground, fontSize: 10.5, fontWeight: FontWeight.w800),
      ),
    );
    if (!centerInCell) return pill;
    return SizedBox(
      height: AdminDataTableTokens.rowHeight,
      child: Align(alignment: Alignment.center, child: pill),
    );
  }
}

/// Table cell with fixed row height, padding, and alignment.
abstract final class AdminDataTableCells {
  static TableCell cell({
    required Widget child,
    TextAlign align = TextAlign.left,
    double height = AdminDataTableTokens.rowHeight,
  }) {
    return TableCell(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: AdminDataTableTokens.cellPadding,
          child: Align(
            alignment: adminDataTableAlign(align),
            child: child,
          ),
        ),
      ),
    );
  }

  static TableCell text(
    String value, {
    TextAlign align = TextAlign.left,
    TextStyle? style,
    int maxLines = 1,
  }) {
    return cell(
      align: align,
      child: Text(
        value,
        textAlign: align,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: style ?? AdminDataTableTokens.bodyTextStyle(),
      ),
    );
  }
}

/// One data row with optional tap + hover; [cells] must align with [columnWidths].
class AdminDataTableClickableRow extends StatefulWidget {
  const AdminDataTableClickableRow({
    super.key,
    required this.columnWidths,
    required this.cells,
    this.onTap,
    this.showShadow = true,
  });

  final Map<int, TableColumnWidth> columnWidths;
  final List<TableCell> cells;
  final VoidCallback? onTap;
  final bool showShadow;

  @override
  State<AdminDataTableClickableRow> createState() => _AdminDataTableClickableRowState();
}

class _AdminDataTableClickableRowState extends State<AdminDataTableClickableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final table = Table(
      columnWidths: widget.columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [TableRow(children: widget.cells)],
    );
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.only(top: AdminDataTableTokens.rowGap),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AdminDataTableTokens.cornerRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(AdminDataTableTokens.cornerRadius),
              hoverColor: const Color(0xFFF8FBFF).withValues(alpha: 0.75),
              child: AnimatedContainer(
                duration: AdminDataTableTokens.hoverDuration,
                curve: AdminDataTableTokens.hoverCurve,
                decoration: BoxDecoration(
                  color: _hover ? const Color(0xFFF8FBFF) : Colors.white,
                  borderRadius: BorderRadius.circular(AdminDataTableTokens.cornerRadius),
                  border: Border.all(color: Colors.black.withValues(alpha: _hover ? 0.1 : 0.06)),
                  boxShadow: widget.showShadow ? AdminDataTableTokens.rowShadow : const [],
                ),
                child: table,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-tappable row with the same geometry and hover background as data rows.
class AdminDataTableStaticRow extends StatefulWidget {
  const AdminDataTableStaticRow({
    super.key,
    required this.columnWidths,
    required this.cells,
    this.showShadow = true,
  });

  final Map<int, TableColumnWidth> columnWidths;
  final List<TableCell> cells;
  final bool showShadow;

  @override
  State<AdminDataTableStaticRow> createState() => _AdminDataTableStaticRowState();
}

class _AdminDataTableStaticRowState extends State<AdminDataTableStaticRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.only(top: AdminDataTableTokens.rowGap),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AdminDataTableTokens.cornerRadius),
          child: AnimatedContainer(
            duration: AdminDataTableTokens.hoverDuration,
            curve: AdminDataTableTokens.hoverCurve,
            decoration: BoxDecoration(
              color: _hover ? const Color(0xFFF8FBFF) : Colors.white,
              borderRadius: BorderRadius.circular(AdminDataTableTokens.cornerRadius),
              border: Border.all(color: Colors.black.withValues(alpha: _hover ? 0.1 : 0.06)),
              boxShadow: widget.showShadow ? AdminDataTableTokens.rowShadow : const [],
            ),
            child: Table(
              columnWidths: widget.columnWidths,
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [TableRow(children: widget.cells)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal scroll region with consistent padding; [tableWidth] must match column sum.
class AdminDataTableScrollArea extends StatelessWidget {
  const AdminDataTableScrollArea({
    super.key,
    required this.tableWidth,
    required this.child,
    this.horizontalPadding = 12,
  });

  final double tableWidth;
  final Widget child;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    // Do not wrap in [Align] without width/height factors: inside a stretched [Column]
    // that would expand to the parent's full height and the horizontal scroll viewport
    // would paint a tall empty strip (often read as a "gray bar") on web/desktop.
    //
    // [IntrinsicHeight] ties the viewport's cross-axis (vertical for horizontal scroll)
    // to the table block's intrinsic height so nested vertical [SingleChildScrollView]
    // parents do not leave the scroll view with unbounded max height.
    return ScrollConfiguration(
      behavior: _kAdminTableHorizontalScrollBehavior,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        primary: false,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: IntrinsicHeight(
          child: SizedBox(width: tableWidth, child: child),
        ),
      ),
    );
  }
}

/// Footer: summary (left), page controls (center), optional trailing e.g. rows-per-page (right).
class AdminDataTablePaginationBar extends StatelessWidget {
  const AdminDataTablePaginationBar({
    super.key,
    required this.summaryText,
    required this.pageIndex,
    required this.pageCount,
    required this.onPageSelected,
    this.trailing,
    this.narrowBreakpoint = 720,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 10),
    this.maxPageButtons = 6,
  });

  final String summaryText;
  final int pageIndex;
  final int pageCount;
  final ValueChanged<int> onPageSelected;
  final Widget? trailing;
  final double narrowBreakpoint;
  final EdgeInsets padding;
  final int maxPageButtons;

  @override
  Widget build(BuildContext context) {
    final summaryStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AdminColors.muted.withValues(alpha: 0.9),
    );
    final summary = Text(summaryText, style: summaryStyle);
    final pages = _buildPageControls();
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < narrowBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                summary,
                const SizedBox(height: 12),
                Center(child: pages),
                if (trailing != null) ...[
                  const SizedBox(height: 10),
                  Center(child: trailing!),
                ],
              ],
            );
          }
          return SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: summary)),
                Expanded(flex: 3, child: Center(child: pages)),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: trailing ?? const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageControls() {
    if (pageCount <= 0) {
      return const SizedBox.shrink();
    }
    final window = _pageWindow();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PageArrow(
          icon: Icons.chevron_left_rounded,
          enabled: pageIndex > 0,
          onTap: () => onPageSelected(pageIndex - 1),
        ),
        const SizedBox(width: 6),
        for (var i = 0; i < window.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _PageNum(
            label: '${window[i] + 1}',
            active: window[i] == pageIndex,
            onTap: () => onPageSelected(window[i]),
          ),
        ],
        const SizedBox(width: 6),
        _PageArrow(
          icon: Icons.chevron_right_rounded,
          enabled: pageIndex < pageCount - 1,
          onTap: () => onPageSelected(pageIndex + 1),
        ),
      ],
    );
  }

  /// Up to [maxPageButtons] contiguous page indices sliding with [pageIndex].
  List<int> _pageWindow() {
    final cap = maxPageButtons.clamp(1, 32);
    if (pageCount <= cap) {
      return List<int>.generate(pageCount, (i) => i);
    }
    var start = pageIndex - cap ~/ 2;
    if (start < 0) start = 0;
    if (start + cap > pageCount) start = pageCount - cap;
    return List<int>.generate(cap, (i) => start + i);
  }
}

class _PageArrow extends StatelessWidget {
  const _PageArrow({required this.icon, required this.enabled, required this.onTap});
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.white : const Color(0xFFF3F6FB),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 20, color: enabled ? AdminColors.headerTitle : AdminColors.muted),
        ),
      ),
    );
  }
}

class _PageNum extends StatelessWidget {
  const _PageNum({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AdminColors.statBlue : Colors.white,
            border: Border.all(color: const Color(0xFFDCE5F3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: active ? Colors.white : AdminColors.headerTitle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Standard “Rows per page” control used in list screens.
class AdminDataTableRowsPerPage extends StatelessWidget {
  const AdminDataTableRowsPerPage({
    super.key,
    this.value = 10,
    this.onChanged,
    this.options = const [10, 25, 50],
  });

  final int value;
  final ValueChanged<int?>? onChanged;
  final List<int> options;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rows per page:',
          style: TextStyle(fontSize: 12, color: AdminColors.muted.withValues(alpha: 0.9)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              items: [for (final o in options) DropdownMenuItem(value: o, child: Text('$o'))],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
