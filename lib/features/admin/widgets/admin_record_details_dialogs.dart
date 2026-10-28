import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// Enterprise-style overlay: dim + light blur. Sidebar stays visible underneath.
Future<void> showAdminBlurredDialog({
  required BuildContext context,
  required Widget child,
  double maxWidthFraction = 0.74,
  double? maxWidthPx,
}) {
  final size = MediaQuery.sizeOf(context);
  final maxW = maxWidthPx ?? size.width * maxWidthFraction;

  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _BlurredBarrier(
        onDismiss: () => Navigator.of(ctx).pop(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: maxW.clamp(320, 1400), maxHeight: size.height * 0.92),
            child: child,
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Same overlay/animation as [showAdminBlurredDialog], but returns a result from [Navigator.pop].
Future<T?> showAdminBlurredDialogForResult<T>({
  required BuildContext context,
  required Widget child,
  double maxWidthFraction = 0.74,
  double? maxWidthPx,
}) {
  final size = MediaQuery.sizeOf(context);
  final maxW = maxWidthPx ?? size.width * maxWidthFraction;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _BlurredBarrier(
        onDismiss: () => Navigator.of(ctx).pop(),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: maxW.clamp(320, 1400), maxHeight: size.height * 0.92),
            child: child,
          ),
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _BlurredBarrier extends StatelessWidget {
  const _BlurredBarrier({required this.onDismiss, required this.child});

  final VoidCallback onDismiss;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withValues(alpha: 0.38)),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

// â”€â”€â”€ All Schedules â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Future<void> showAdminViewNotesDialog(
  BuildContext context, {
  required String userRemarksBody,
  required String submittedViaLine,
  required String submittedByLine,
  required String submittedOnLine,
}) {
  return showAdminBlurredDialog(
    context: context,
    maxWidthFraction: 0.5,
    maxWidthPx: 480,
    child: Material(
      color: Colors.transparent,
      child: _ViewNotesModal(
        userRemarksBody: userRemarksBody,
        submittedViaLine: submittedViaLine,
        submittedByLine: submittedByLine,
        submittedOnLine: submittedOnLine,
      ),
    ),
  );
}

class _ViewNotesModal extends StatefulWidget {
  const _ViewNotesModal({
    required this.userRemarksBody,
    required this.submittedViaLine,
    required this.submittedByLine,
    required this.submittedOnLine,
  });

  final String userRemarksBody;
  final String submittedViaLine;
  final String submittedByLine;
  final String submittedOnLine;

  @override
  State<_ViewNotesModal> createState() => _ViewNotesModalState();
}

class _ViewNotesModalState extends State<_ViewNotesModal> {
  bool _closeHover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 12, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'View Notes',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AdminColors.headerTitle),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Notes and remarks for this record.',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AdminColors.muted.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                        foregroundColor: AdminColors.headerTitle),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                thickness: 1,
                color: Colors.black.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'User Remarks',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.headerTitle),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.userRemarksBody,
                    style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AdminColors.headerTitle.withValues(alpha: 0.92)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.submittedViaLine,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.muted.withValues(alpha: 0.88)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Submitted By',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.headerTitle),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.submittedByLine,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.headerTitle),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Submitted On',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.headerTitle),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.submittedOnLine,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.headerTitle),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
              child: Align(
                alignment: Alignment.centerRight,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _closeHover = true),
                  onExit: (_) => setState(() => _closeHover = false),
                  cursor: SystemMouseCursors.click,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                      foregroundColor: AdminColors.headerTitle,
                      side: BorderSide(
                          color: Colors.black
                              .withValues(alpha: _closeHover ? 0.22 : 0.14)),
                      backgroundColor:
                          _closeHover ? const Color(0xFFF3F6FB) : Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Close',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
