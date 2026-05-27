import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import 'admin_record_details_dialogs.dart';

Future<bool> showMarkInProgressConfirmDialog(BuildContext context) async {
  final r = await showAdminBlurredDialogForResult<bool>(
    context: context,
    maxWidthPx: 520,
    child: Material(
      color: Colors.transparent,
      child: _ConfirmModalFrame(
        accent: AdminColors.statBlue,
        topIcon: Icons.schedule_rounded,
        title: 'Mark as In Progress?',
        description:
            'This will update the status of this alert to "In Progress".\nThe diver who reported this detection will be the one who resolves it.',
        infoText: 'The alert status will change to In Progress and the diver (reporter) will be notified.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Mark as In Progress',
        confirmIcon: Icons.schedule_rounded,
        filledButtonColor: AdminColors.statBlue,
        onCancel: (ctx) => Navigator.of(ctx).pop(false),
        onConfirm: (ctx) => Navigator.of(ctx).pop(true),
      ),
    ),
  );
  return r == true;
}

Future<bool> showMarkResolvedConfirmDialog(BuildContext context) async {
  final r = await showAdminBlurredDialogForResult<bool>(
    context: context,
    maxWidthPx: 520,
    child: Material(
      color: Colors.transparent,
      child: _ConfirmModalFrame(
        accent: AdminColors.statGreen,
        topIcon: Icons.check_rounded,
        title: 'Mark as Resolved?',
        description:
            'This will mark this alert as "Resolved".\nThe diver who reported this detection will be the one who resolves it.',
        infoText: '',
        showInfoBox: false,
        showDividerAboveActions: true,
        cancelLabel: 'Cancel',
        confirmLabel: 'Mark as Resolved',
        confirmIcon: Icons.check_rounded,
        filledButtonColor: AdminColors.statGreen,
        onCancel: (ctx) => Navigator.of(ctx).pop(false),
        onConfirm: (ctx) => Navigator.of(ctx).pop(true),
      ),
    ),
  );
  return r == true;
}

typedef _PopFn = void Function(BuildContext ctx);

class _ConfirmModalFrame extends StatelessWidget {
  const _ConfirmModalFrame({
    required this.accent,
    required this.topIcon,
    required this.title,
    required this.description,
    required this.infoText,
    this.showInfoBox = true,
    this.showDividerAboveActions = false,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.filledButtonColor,
    required this.onCancel,
    required this.onConfirm,
  });

  final Color accent;
  final IconData topIcon;
  final String title;
  final String description;
  final String infoText;
  final bool showInfoBox;
  final bool showDividerAboveActions;
  final String cancelLabel;
  final String confirmLabel;
  final IconData confirmIcon;
  final Color filledButtonColor;
  final _PopFn onCancel;
  final _PopFn onConfirm;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(26, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => onCancel(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(foregroundColor: AdminColors.muted),
              ),
            ),
            Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(topIcon, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AdminColors.headerTitle),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: AdminColors.muted.withValues(alpha: 0.95)),
            ),
            if (showInfoBox && infoText.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        infoText,
                        style: TextStyle(fontSize: 13, height: 1.4, color: accent.withValues(alpha: 0.95), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (showDividerAboveActions) ...[
              const SizedBox(height: 22),
              Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _HoverOutlinedButton(
                    label: cancelLabel,
                    onPressed: () => onCancel(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HoverFilledButton(
                    label: confirmLabel,
                    icon: confirmIcon,
                    color: filledButtonColor,
                    onPressed: () => onConfirm(context),
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

class _HoverOutlinedButton extends StatefulWidget {
  const _HoverOutlinedButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  State<_HoverOutlinedButton> createState() => _HoverOutlinedButtonState();
}

class _HoverOutlinedButtonState extends State<_HoverOutlinedButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: OutlinedButton(
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          foregroundColor: AdminColors.headerTitle,
          side: BorderSide(color: Colors.black.withValues(alpha: _hover ? 0.22 : 0.14)),
          backgroundColor: _hover ? const Color(0xFFF3F6FB) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _HoverFilledButton extends StatefulWidget {
  const _HoverFilledButton({required this.label, required this.icon, required this.color, required this.onPressed});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  State<_HoverFilledButton> createState() => _HoverFilledButtonState();
}

class _HoverFilledButtonState extends State<_HoverFilledButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = Color.lerp(widget.color, Colors.black, _hover ? 0.08 : 0)!;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: FilledButton.icon(
        onPressed: widget.onPressed,
        icon: Icon(widget.icon, size: 18, color: Colors.white),
        label: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: c,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
