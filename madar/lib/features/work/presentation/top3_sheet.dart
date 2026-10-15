import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../../home/widgets/window_chips.dart' show windowIcon;
import '../data/work_providers.dart';
import '../domain/top3.dart';
import 'widgets/work_widgets.dart';
import 'work_actions.dart';
import 'work_labels.dart';

/// Picks today's Top 3: the chosen ones first (tap to remove), then open
/// cards and tasks, the urgent ones first (tap to add; when full, choose
/// which one it replaces).
Future<void> showTop3Sheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const Top3Sheet());

class Top3Sheet extends ConsumerWidget {
  const Top3Sheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final state = ref.watch(workTop3Provider).value;
    final candidates = ref.watch(workTop3CandidatesProvider).value ?? const <FocusItem>[];
    final chosen = state?.items ?? const <FocusItem>[];
    return InteractionSheetFrame(
      title: l.workTop3ChooseTitle,
      subtitle: texts.d(l.workTop3SlotsLeft(state?.openSlots ?? Top3Rules.max)),
      icon: Icons.star_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in chosen)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: _FocusRow(
                key: ValueKey('top3-in-${item.key}'),
                item: item,
                chosen: true,
                onTap: () => WorkActions.setTop3(context, ref, item, false),
              ),
            ),
          if (chosen.isNotEmpty && candidates.isNotEmpty) const MadarDivider(),
          if (candidates.isEmpty && chosen.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xl),
              child: Text(
                l.workTop3NoCandidates,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          for (final (i, item) in candidates.take(40).indexed)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: StaggerItem(
                index: i,
                child: _FocusRow(
                  key: ValueKey('top3-cand-${item.key}'),
                  item: item,
                  chosen: false,
                  onTap: () => WorkActions.setTop3(context, ref, item, true),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FocusRow extends ConsumerWidget {
  const _FocusRow({super.key, required this.item, required this.chosen, required this.onTap});

  final FocusItem item;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(workTodayProvider);
    final color = workColor(t, item.color);
    final subtitle = item.kind == FocusKind.card ? item.boardName : texts.l.workKindTask;
    return GlassCard(
      onTap: () {
        Fx.fire(chosen ? Sfx.toggleOff : Sfx.toggleOn);
        onTap();
      },
      semanticLabel: '${chosen ? texts.l.workTop3Remove : texts.l.workTop3Add}: ${item.title}',
      borderColor: chosen ? t.gold.withValues(alpha: 0.55) : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
      child: Row(
        children: [
          IslamicStar(size: 20, color: chosen ? t.gold : t.textTertiary, filled: chosen, glow: chosen),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                const SizedBox(height: 2),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (subtitle != null)
                      WorkPill(
                        label: subtitle,
                        leading: item.kind == FocusKind.card ? ColorOrb(color: color, size: 7, glow: false) : null,
                        icon: item.kind == FocusKind.task ? Icons.check_box_outlined : null,
                      ),
                    if (item.window != null)
                      WorkPill(label: texts.window(item.window!), icon: windowIcon(item.window!), color: t.highlight),
                    if (item.kind == FocusKind.card && item.dueDate != null)
                      DueBadge(due: item.dueDate!, today: today, done: item.done),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            chosen ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
            size: 20,
            color: chosen ? t.textSecondary : t.accent,
          ),
        ],
      ),
    );
  }
}
