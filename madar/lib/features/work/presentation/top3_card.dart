import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/work_providers.dart';
import '../domain/top3.dart';
import 'top3_sheet.dart';
import 'widgets/work_widgets.dart';
import 'work_actions.dart';
import 'work_labels.dart';

/// Today's Top 3: a calm card with three numbered slots across boards and
/// tasks – tap (or swipe) to finish one, the last of the three celebrates
/// with particles and a chime; long-press for its menu; empty slots open
/// the picker. The next morning it first asks whether to carry yesterday's
/// unfinished focus over or start fresh.
class Top3Card extends ConsumerStatefulWidget {
  const Top3Card({super.key, this.compact = false});

  /// Tighter paddings for hub pages.
  final bool compact;

  @override
  ConsumerState<Top3Card> createState() => _Top3CardState();
}

class _Top3CardState extends ConsumerState<Top3Card> {
  final _ring = GlobalKey();
  DateTime? _settledFor;

  void _settle(Top3State s) {
    if (!s.needsRollover || s.needsCarryOver || _settledFor == s.today) return;
    _settledFor = s.today;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(workServiceProvider).settleTop3());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(workCardTaskSyncProvider);
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(workTop3Provider);
    final state = async.value;
    if (state != null) _settle(state);

    final done = state?.doneCount ?? 0;
    final total = state?.items.length ?? 0;
    final allDone = state?.allDone ?? false;

    final header = Row(
      children: [
        IslamicStar(size: 20, color: t.gold, glow: true),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.workTop3Title, style: text.titleMedium),
              Text(
                allDone ? l.workTop3AllDone : l.workTop3Subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: allDone ? t.success : t.textSecondary),
              ),
            ],
          ),
        ),
        if (state != null && !state.needsCarryOver && total > 0) ...[
          const SizedBox(width: Space.s),
          ProgressRing(
            key: _ring,
            value: done / Top3Rules.max,
            size: 46,
            strokeWidth: 4,
            color: allDone ? t.success : t.gold,
            glow: allDone,
            semanticLabel: l.workTop3Title,
            semanticValue: l.workTop3Progress(texts.n(done), texts.n(Top3Rules.max)),
            child: allDone
                ? Icon(Icons.check_rounded, color: t.success, size: 22)
                : Text(
                    '${texts.n(done)}/${texts.n(Top3Rules.max)}',
                    style: text.labelMedium!.copyWith(color: t.textPrimary),
                  ),
          ),
        ],
      ],
    );

    Widget body;
    if (state == null) {
      body = const SizedBox(height: 72, child: Center(child: OrbitLoader(size: 28)));
    } else if (state.needsCarryOver) {
      body = _CarryOver(state: state);
    } else if (state.isEmpty) {
      body = Row(
        children: [
          Expanded(child: Text(l.workTop3Empty, style: text.bodyMedium)),
          const SizedBox(width: Space.m),
          MadarButton(
            label: l.workTop3Choose,
            icon: Icons.add_rounded,
            size: MadarButtonSize.small,
            sfx: Sfx.sheetOpen,
            onPressed: () => showTop3Sheet(context),
          ),
        ],
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < Top3Rules.max; i++)
            Padding(
              padding: EdgeInsetsDirectional.only(top: i == 0 ? 0 : Space.s),
              child: i < state.items.length
                  ? _Top3Row(
                      key: ValueKey('top3-${state.items[i].key}'),
                      item: state.items[i],
                      number: i + 1,
                      ring: _ring,
                    )
                  : _EmptySlot(number: i + 1),
            ),
        ],
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      borderColor: allDone ? t.success.withValues(alpha: 0.45) : t.gold.withValues(alpha: 0.35),
      glowColor: allDone ? t.success.withValues(alpha: 0.3) : t.gold.withValues(alpha: 0.18),
      padding: EdgeInsetsDirectional.fromSTEB(
        Space.l,
        widget.compact ? Space.m : Space.l,
        Space.l,
        widget.compact ? Space.m : Space.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          SizedBox(height: widget.compact ? Space.m : Space.l),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            switchInCurve: MadarMotion.emphasized,
            child: KeyedSubtree(
              key: ValueKey(state == null ? 'loading' : (state.needsCarryOver ? 'carry' : (state.isEmpty ? 'empty' : 'items'))),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _Top3Row extends ConsumerWidget {
  const _Top3Row({super.key, required this.item, required this.number, required this.ring});

  final FocusItem item;
  final int number;
  final GlobalKey ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final today = ref.watch(workTodayProvider);
    final card = item.kind == FocusKind.card
        ? ref.watch(workCardsProvider).value?.where((c) => c.id == item.id).firstOrNull
        : null;

    Future<void> toggle() => WorkActions.toggleFocusDone(context, ref, item, celebrateFrom: ring.currentContext);

    final subtitle = <Widget>[
      if (item.kind == FocusKind.card && item.boardName != null)
        WorkPill(label: item.boardName!, leading: ColorOrb(color: workColor(t, item.color), size: 7, glow: false))
      else if (item.kind == FocusKind.task)
        WorkPill(label: l.workKindTask, icon: Icons.check_box_outlined),
      if (item.window != null) WindowPill(window: item.window!, day: item.date, today: today),
      if (item.kind == FocusKind.card && item.dueDate != null && !item.done)
        DueBadge(due: item.dueDate!, today: today),
    ];

    return ActionableItem(
      onTap: toggle,
      onCompleteSwipe: item.done
          ? null
          : () async {
              await toggle();
              return null;
            },
      completeLabel: l.actionComplete,
      borderRadius: BorderRadius.circular(t.radiusM),
      semanticLabel: '${texts.n(number)}. ${item.title}',
      actions: ItemActions(
        onEdit: card == null ? null : () => WorkActions.editCard(context, ref, card),
        extra: [
          ItemAction(
            icon: Icons.star_outline_rounded,
            label: l.workTop3Remove,
            onSelected: () => WorkActions.setTop3(context, ref, item, false, showToast: false),
          ),
          if (card != null)
            ItemAction(
              icon: Icons.mosque_rounded,
              label: l.workPlaceInWindow,
              onSelected: () => WorkActions.placeInWindow(context, ref, card),
            ),
        ],
      ),
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.short),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.m, Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          color: item.done ? t.success.withValues(alpha: 0.07) : t.glassFill,
          border: Border.all(color: item.done ? t.success.withValues(alpha: 0.35) : t.glassBorder),
        ),
        child: Row(
          children: [
            _Numeral(number: number, done: item.done),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: context.motion(MadarMotion.short),
                    style: text.titleSmall!.copyWith(
                      color: item.done ? t.textSecondary : t.textPrimary,
                      decoration: item.done ? TextDecoration.lineThrough : null,
                      decorationColor: t.textTertiary,
                    ),
                    child: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: Space.xs),
                    Wrap(spacing: Space.xs, runSpacing: Space.xs, children: subtitle),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            _Check(done: item.done),
          ],
        ),
      ),
    );
  }
}

class _Numeral extends StatelessWidget {
  const _Numeral({required this.number, required this.done});

  final int number;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IslamicStar(size: 34, color: (done ? t.success : t.gold).withValues(alpha: 0.9), filled: false, strokeWidth: 1.1),
          Text(
            texts.n(number),
            style: Theme.of(context).textTheme.labelLarge!.copyWith(color: done ? t.success : t.gold, height: 1),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.done});

  final bool done;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedContainer(
      duration: context.motion(MadarMotion.short),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? t.success : Colors.transparent,
        border: Border.all(color: done ? t.success : t.textTertiary, width: 1.6),
        boxShadow: done ? [BoxShadow(color: t.success.withValues(alpha: 0.5), blurRadius: 8)] : null,
      ),
      child: done ? Icon(Icons.check_rounded, size: 17, color: t.textOnAccent) : null,
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    return MadarPressable(
      onTap: () => showTop3Sheet(context),
      sfx: null,
      semanticLabel: texts.l.workTop3Choose,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.m, Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: t.glassBorder.withValues(alpha: 0.9)),
        ),
        child: Row(
          children: [
            Opacity(opacity: 0.5, child: _Numeral(number: number, done: false)),
            const SizedBox(width: Space.m),
            Icon(Icons.add_rounded, size: 18, color: t.accent),
            const SizedBox(width: Space.xs),
            Text(texts.l.workTop3Choose, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.accent)),
          ],
        ),
      ),
    );
  }
}

class _CarryOver extends ConsumerWidget {
  const _CarryOver({required this.state});

  final Top3State state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.all(Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        color: t.gold.withValues(alpha: 0.06),
        border: Border.all(color: t.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.wb_twilight_rounded, size: 18, color: t.gold),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.workCarryTitle, style: text.titleSmall!.copyWith(color: t.gold))),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(texts.d(l.workCarryBody(state.leftovers.length)), style: text.bodyMedium),
          const SizedBox(height: Space.s),
          for (final i in state.leftovers.take(Top3Rules.max))
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.xs),
              child: Row(
                children: [
                  IslamicStar(size: 10, color: t.gold.withValues(alpha: 0.8)),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(i.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall)),
                ],
              ),
            ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: MadarButton(
                  label: l.workCarryOver,
                  icon: Icons.arrow_forward_rounded,
                  size: MadarButtonSize.small,
                  sfx: Sfx.complete,
                  onPressed: () => WorkActions.carryOver(context, ref),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: MadarButton(
                  label: l.workStartFresh,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.swipe,
                  onPressed: () => WorkActions.startFresh(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
