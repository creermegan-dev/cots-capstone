import 'package:flutter/material.dart';

/// Stage 5 (claude/agreed_workflow_decisions.md): a monthly visit made within
/// 2 days after an injection in the zone is allowed but flagged. The
/// database writes the note; this only shows it.
class EarlyVisitFlag extends StatelessWidget {
  const EarlyVisitFlag({super.key, required this.note});

  final String note;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 6, bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF9A825)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 20, color: Color(0xFFE65100)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(note,
                  style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5D4037))),
            ),
          ],
        ),
      );
}
