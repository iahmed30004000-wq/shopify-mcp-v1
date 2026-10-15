import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../domain/plan_preview.dart';

/// The small bits every plan screen shares: the state pills, the section
/// labels inside a card, and the plain bullet list that carries a
/// suggestion's lines.
///
/// Nothing here decides anything: a pill is the colour of a state the
/// engine already settled, and a bullet is one sentence
/// `AiBridgeTexts` already wrote.

/// The colour of one suggestion's state, from the theme's tokens only.
Color planStatusColor(MadarTokens t, PlanItemStatus status) => switch (status) {
  PlanItemStatus.ready => t.success,
  PlanItemStatus.needsEdit => t.warning,
  PlanItemStatus.blocked => t.info,
  PlanItemStatus.deferred => t.textTertiary,
  PlanItemStatus.rejected => t.danger,
};

IconData planStatusIcon(PlanItemStatus status) => switch (status) {
  PlanItemStatus.ready => Icons.check_circle_outline_rounded,
  PlanItemStatus.needsEdit => Icons.edit_note_rounded,
  PlanItemStatus.blocked => Icons.lock_clock_rounded,
  PlanItemStatus.deferred => Icons.schedule_rounded,
  PlanItemStatus.rejected => Icons.block_rounded,
};

/// A small rounded label («عادة»، «جاهز لموافقتك»).
class PlanPill extends StatelessWidget {
  const PlanPill({super.key, required this.label, required this.color, this.icon, this.dense = true});

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(dense ? 6 : Space.s, dense ? 2 : 3, dense ? 8 : Space.s + 2, dense ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: color), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label over a block inside a card («شو بيصير لو وافقت»).
class PlanLabel extends StatelessWidget {
  const PlanLabel(this.text, {super.key, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textTertiary;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: c), const SizedBox(width: Space.xs)],
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sentences of one block, one short line each, each with its own dot.
/// Every line reads in its own script's direction but aligns with the UI,
/// so an English food name inside an Arabic line keeps its own order.
class PlanLines extends StatelessWidget {
  const PlanLines({super.key, required this.lines, this.color, this.bullet = true});

  final List<String> lines;
  final Color? color;
  final bool bullet;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = color ?? t.textSecondary;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bullet)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 6, end: Space.s),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: 0.6)),
                    ),
                  ),
                Expanded(
                  child: Text(
                    line,
                    textDirection: BidiIsolate.directionOf(line),
                    textAlign: rtl ? TextAlign.right : TextAlign.left,
                    style: text.bodySmall?.copyWith(color: c, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
