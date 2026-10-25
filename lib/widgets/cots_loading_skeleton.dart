import 'package:flutter/material.dart';

import '../core/cots_colors.dart';

enum CotsSkeletonLayout {
  dashboard,
  analytics,
  table,
  list,
  detail,
  profile,
  section,
  image
}

/// Non-interactive placeholders shown only while the first records are loading.
class CotsLoadingSkeleton extends StatefulWidget {
  const CotsLoadingSkeleton({super.key, required this.layout, this.label});
  final CotsSkeletonLayout layout;
  final String? label;

  @override
  State<CotsLoadingSkeleton> createState() => _CotsLoadingSkeletonState();
}

class _CotsLoadingSkeletonState extends State<CotsLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final Animation<double> _opacity =
      Tween<double>(begin: .45, end: .9).animate(_controller);
  bool _animate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (_animate) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = switch (widget.layout) {
      CotsSkeletonLayout.table => _table(),
      CotsSkeletonLayout.list => _list(),
      CotsSkeletonLayout.section => _section(),
      CotsSkeletonLayout.image => LayoutBuilder(
          builder: (context, constraints) => SizedBox(
              width: constraints.hasBoundedWidth ? constraints.maxWidth : 160,
              height:
                  constraints.hasBoundedHeight ? constraints.maxHeight : 160,
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: kBorderGray,
                      borderRadius: BorderRadius.circular(12))))),
      CotsSkeletonLayout.detail || CotsSkeletonLayout.profile => _details(),
      _ => LayoutBuilder(builder: (context, constraints) {
          final dashboard = widget.layout == CotsSkeletonLayout.dashboard;
          final columns = dashboard
              ? 2
              : constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 600
                      ? 2
                      : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _bar(height: 24, fraction: .55),
                const SizedBox(height: 12),
                _bar(height: 14, fraction: .8),
                const SizedBox(height: 22),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (var i = 0; i < (dashboard ? 4 : 6); i++)
                    SizedBox(
                        width: width,
                        child: _card(Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _bar(height: 12, fraction: .8),
                            const SizedBox(height: 14),
                            _bar(height: 28, fraction: .45),
                            const SizedBox(height: 14),
                            _bar(height: 10, fraction: .7),
                          ],
                        ))),
                ]),
                const SizedBox(height: 18),
                _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _bar(height: 16, fraction: .5),
                      const SizedBox(height: 18),
                      _bar(height: 160),
                    ])),
              ]);
        }),
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.label ??
          switch (widget.layout) {
            CotsSkeletonLayout.dashboard => 'Loading dashboard',
            CotsSkeletonLayout.analytics => 'Loading analytics',
            CotsSkeletonLayout.table => 'Loading recent submissions',
            CotsSkeletonLayout.list => 'Loading records',
            CotsSkeletonLayout.detail => 'Loading details',
            CotsSkeletonLayout.profile => 'Loading profile',
            CotsSkeletonLayout.section => 'Loading details',
            CotsSkeletonLayout.image => 'Loading image',
          },
      excludeSemantics: true,
      child: IgnorePointer(
          child: _animate
              ? FadeTransition(opacity: _opacity, child: content)
              : content),
    );
  }

  Widget _section() => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bar(height: 14, fraction: .8),
            const SizedBox(height: 12),
            _bar(height: 14, fraction: .55),
          ]);

  Widget _list() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < 3; i++) ...[
          _card(Row(children: [
            SizedBox(width: 40, child: _bar(height: 40)),
            const SizedBox(width: 12),
            Expanded(child: _section())
          ])),
          const SizedBox(height: 12),
        ],
      ]);

  Widget _details() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (widget.layout == CotsSkeletonLayout.profile) ...[
            Center(child: SizedBox(width: 64, child: _bar(height: 64))),
            const SizedBox(height: 18),
          ],
          _section(),
          const SizedBox(height: 18),
          _bar(height: 120),
        ])),
        const SizedBox(height: 16),
        _list(),
      ]);

  Widget _table() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _bar(height: 16, fraction: .7),
        const SizedBox(height: 18),
        for (var i = 0; i < 4; i++) ...[
          _bar(height: 34),
          const SizedBox(height: 16),
        ],
      ]);

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorderGray)),
        child: child,
      );

  Widget _bar({required double height, double fraction = 1}) => Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
                height: height,
                decoration: BoxDecoration(
                    color: kBorderGray,
                    borderRadius: BorderRadius.circular(6)))),
      );
}

/// Scrollable, padded skeleton for an existing page-level loading branch.
class CotsPageLoading extends StatelessWidget {
  const CotsPageLoading(
      {super.key, this.layout = CotsSkeletonLayout.list, this.label});
  final CotsSkeletonLayout layout;
  final String? label;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: CotsLoadingSkeleton(layout: layout, label: label),
      );
}
