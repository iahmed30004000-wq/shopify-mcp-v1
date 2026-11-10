import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/ai_bridge_providers.dart';
import '../ai_bridge_texts.dart';

/// The plan's list on the home panel: the one line he meets again.
///
/// It is **where the whole feature pays off**, so it sits in the home
/// glass panel beside the Neglect Radar – the one surface he sees every
/// time he opens Madar. It shows the newest plan that still has an
/// unticked line, its name, «٢ من ٤», and the next thing on it; tapping it
/// opens that plan's list.
///
/// When nothing is open it renders nothing at all (a zero-height box), so
/// a fresh install and a finished plan both leave the panel exactly as it
/// was.
class PlanChecklistStrip extends ConsumerWidget {
  const PlanChecklistStrip({super.key, required this.onOpen});

  /// How much room the line takes in the peeking home panel, so the panel
  /// can make space for it (and only when there is one to show).
  static const double peekHeight = 42;

  /// Opens the plan's checklist.
  final void Function(String planId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = AiBridgeTexts.of(context);
    final open = ref.watch(openPlanChecklistProvider).value;
    if (open == null) return const SizedBox.shrink();
    final name = tx.planName(open.plan);
    final next = tx.checklistLine(open.next.title);
    final counter = tx.progress(open.progress);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 0),
      child: Semantics(
        button: true,
        label: [l.aiPlanHomeTitle, name, counter, next].join(l.recordListSeparator),
        hint: l.aiPlanHomeOpenHint,
        excludeSemantics: true,
        onTap: () => onOpen(open.plan.id),
        child: MadarPressable(
          onTap: () => onOpen(open.plan.id),
          sfx: Sfx.navigate,
          focusRadius: BorderRadius.circular(t.radiusM),
          minTapTarget: MadarPressable.minTouchTarget,
          child: Container(
            key: const ValueKey('aiPlan.homeStrip'),
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.xs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusM),
              color: t.glassFill,
              border: Border.all(color: t.success.withValues(alpha: 0.32)),
            ),
            child: Row(
              children: [
                Icon(Icons.checklist_rounded, size: 15, color: t.success),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    next,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: BidiIsolate.directionOf(next),
                    textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                    style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.3),
                  ),
                ),
                const SizedBox(width: Space.s),
                Text(
                  counter,
                  maxLines: 1,
                  style: text.labelSmall?.copyWith(color: t.success, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
