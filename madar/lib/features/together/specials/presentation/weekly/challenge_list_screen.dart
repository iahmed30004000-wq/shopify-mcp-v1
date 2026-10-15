import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../../data/together_providers.dart';
import '../../data/specials_providers.dart';
import '../../domain/specials_bounds.dart';
import '../../domain/weekly_challenge.dart';
import '../specials_texts.dart';
import '../specials_visuals.dart';

/// The weekly challenges in rotation order: reword any of them, add the
/// couple's own, take defaults out of the rotation (and back), delete their
/// own (with undo) and drag to change the order.
class ChallengeListScreen extends ConsumerWidget {
  const ChallengeListScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  /// A refused change (a text that cleans to nothing) only buzzes.
  static Future<void> _safely(Future<Object?> change) async {
    try {
      await change;
    } on ChallengeEditException {
      Fx.fire(Sfx.error);
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref, ChallengeList list) async {
    final l = SpecialsTexts.of(context).l;
    if (list.isFull) {
      Fx.fire(Sfx.error);
      return;
    }
    final values = await showEditSheet(
      context,
      title: l.togetherWeeklyAdd,
      icon: Icons.add_task_rounded,
      fields: [
        FieldSpec.multiline(
          'text',
          l.togetherWeeklyField,
          required: true,
          hint: l.togetherWeeklyFieldHint,
          maxLength: SpecialsBounds.maxChallengeLength,
        ),
      ],
    );
    final text = values?['text'];
    if (text is! String) return;
    await _safely(ref.read(specialsRepositoryProvider).updateChallenges((c) => c.add(id: SpecialsBounds.newId('w'), text: text)));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Challenge c) async {
    final st = SpecialsTexts.of(context);
    final values = await showEditSheet(
      context,
      title: st.l.togetherWeeklyEdit,
      icon: SpecialsLook.challengeIcon(c.iconKey),
      fields: [
        FieldSpec.multiline(
          'text',
          st.l.togetherWeeklyField,
          required: true,
          hint: st.l.togetherWeeklyFieldHint,
          maxLength: SpecialsBounds.maxChallengeLength,
        ),
      ],
      initial: {'text': st.challenge(c)},
    );
    final text = values?['text'];
    if (text is! String || text.trim() == st.challenge(c).trim()) return;
    await _safely(ref.read(specialsRepositoryProvider).updateChallenges((list) => list.edit(c.id, text)));
  }

  Future<UndoableAction?> _remove(BuildContext context, WidgetRef ref, ChallengeList list, Challenge c) async {
    final l = SpecialsTexts.of(context).l;
    if (!c.hidden && list.pool.length <= 1) {
      Fx.fire(Sfx.error);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l.togetherWeeklyLastActive)));
      return null;
    }
    // This week's challenge, once one of the two has done it, stays.
    final week = ref.read(weeklyViewProvider).value?.record;
    if (!c.isDefault && week != null && week.challengeId == c.id && week.anyDone) {
      Fx.fire(Sfx.error);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l.togetherWeeklySwapLocked)));
      return null;
    }
    final repo = ref.read(specialsRepositoryProvider);
    final undo = await repo.updateChallenges((x) => x.delete(c.id));
    // A week not started yet moves on to the next challenge.
    await repo.ensureWeek(ref.read(togetherClockProvider)());
    return UndoableAction(label: c.isDefault ? l.togetherWeeklyHiddenDone : l.togetherWeeklyDeleted, undo: undo);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final list = ref.watch(challengeListProvider).value;
    final repo = ref.read(specialsRepositoryProvider);
    return MadarScaffold(
      title: l.togetherWeeklyList,
      backdropSeed: 8.9,
      animateBackdrop: animateBackdrop,
      floatingAction: list == null
          ? null
          : MadarButton.icon(
              key: const ValueKey('challenges-add'),
              icon: Icons.add_rounded,
              onPressed: list.isFull ? null : () => unawaited(_add(context, ref, list)),
              semanticLabel: l.togetherWeeklyAdd,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
            ),
      body: list == null
          ? const Center(child: OrbitLoader(size: 40))
          : ReorderableGlassList<Challenge>(
              items: list.items,
              itemKey: (c) => c.id,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 96),
              header: Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.m),
                child: Text(
                  st.tx.facts([l.togetherWeeklyListHint, l.togetherWeeklyInRotation(st.n(list.pool.length))]),
                  style: text.bodySmall?.copyWith(color: t.textSecondary),
                ),
              ),
              onReorder: (items) => unawaited(repo.updateChallenges((x) => x.reorder([for (final c in items) c.id]))),
              itemBuilder: (context, c, index, grip) {
                final tag = c.hidden
                    ? l.togetherWeeklyHidden
                    : c.isEdited
                    ? l.togetherKnowMeEdited
                    : !c.isDefault
                    ? l.togetherKnowMeOwn
                    : null;
                return ActionableItem(
                  key: ValueKey('challenge-${c.id}'),
                  onTap: () => unawaited(_edit(context, ref, c)),
                  swipeEnabled: false,
                  semanticLabel: st.challenge(c),
                  actions: ItemActions(
                    onEdit: () => _edit(context, ref, c),
                    onDelete: c.isDefault && c.hidden ? null : () => _remove(context, ref, list, c),
                    extra: [
                      if (c.isDefault && c.hidden)
                        ItemAction(
                          icon: Icons.visibility_rounded,
                          label: l.togetherWeeklyShow,
                          onSelected: () async {
                            await repo.updateChallenges((x) => x.setHidden(c.id, false));
                            return null;
                          },
                        ),
                      if (c.isEdited)
                        ItemAction(
                          icon: Icons.format_quote_rounded,
                          label: l.togetherKnowMeResetWording,
                          onSelected: () async {
                            final undo = await repo.updateChallenges((x) => x.resetText(c.id));
                            return UndoableAction(label: st.tx.l.itemSaved, undo: undo);
                          },
                        ),
                    ],
                  ),
                  child: Opacity(
                    opacity: c.hidden ? 0.55 : 1,
                    child: GlassCard(
                      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.xs, Space.s),
                      child: Row(
                        children: [
                          SpecialsBadge(icon: SpecialsLook.challengeIcon(c.iconKey), size: 36),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(st.challenge(c), style: text.bodyLarge?.copyWith(color: t.textPrimary, height: 1.3)),
                                if (tag != null)
                                  Text(tag, style: text.labelSmall?.copyWith(color: c.hidden ? t.textTertiary : t.gold)),
                              ],
                            ),
                          ),
                          if (c.isDefault)
                            MadarButton.icon(
                              key: ValueKey('challenge-toggle-${c.id}'),
                              icon: c.hidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              semanticLabel: c.hidden ? l.togetherWeeklyShow : l.togetherWeeklyHide,
                              variant: MadarButtonVariant.ghost,
                              size: MadarButtonSize.small,
                              sfx: c.hidden ? Sfx.toggleOn : Sfx.toggleOff,
                              onPressed: !c.hidden && list.pool.length <= 1
                                  ? null
                                  : () => unawaited(_safely(repo.updateChallenges((x) => x.setHidden(c.id, !c.hidden)))),
                            ),
                          grip,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
