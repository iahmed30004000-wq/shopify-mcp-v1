import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/work_models.dart';
import '../../domain/board_columns.dart';
import '../../domain/countdown.dart';
import '../../domain/kanban.dart';
import '../work_actions.dart';
import '../work_labels.dart';
import 'work_widgets.dart';

/// The look of a kanban card: Top 3 star, title, a line of notes, and its
/// due / prayer-window / assignee chips.
class KanbanCardView extends StatelessWidget {
  const KanbanCardView({
    super.key,
    required this.card,
    required this.board,
    required this.today,
    this.windowDay,
    this.lifted = false,
  });

  final BoardCardRow card;
  final WorkBoard board;
  final DateTime today;
  final DateTime? windowDay;

  /// Drawn as the dragged copy (raised, glowing).
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final done = board.isDone(card);
    final due = card.dueDate;
    final status = DueRules.of(due, today, done: done);
    final accent = workColor(t, board.color);
    final notes = card.notes?.trim() ?? '';
    final chips = <Widget>[
      if (due != null) DueBadge(due: due, today: today, done: done),
      if (card.window != null) WindowPill(window: card.window!, day: windowDay, today: today),
      if ((card.assignee ?? '').trim().isNotEmpty) AssigneePill(name: card.assignee!),
    ];
    final border = card.isTop3
        ? t.gold.withValues(alpha: 0.6)
        : status == DueStatus.overdue
        ? t.danger.withValues(alpha: 0.45)
        : null;
    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: lifted ? t.accent.withValues(alpha: 0.8) : border,
      glow: lifted || card.isTop3,
      glowColor: lifted ? t.accentGlow : (card.isTop3 ? t.gold.withValues(alpha: 0.35) : null),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Board colour on the reading-start edge.
            Container(
              width: 3,
              margin: const EdgeInsetsDirectional.symmetric(vertical: Space.m),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: done ? 0.35 : 0.9),
                borderRadius: const BorderRadiusDirectional.horizontal(end: Radius.circular(3)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (card.isTop3) ...[
                          Padding(
                            padding: const EdgeInsetsDirectional.only(top: 2),
                            child: IslamicStar(size: 14, color: t.gold, glow: true),
                          ),
                          const SizedBox(width: Space.xs + 2),
                        ],
                        Expanded(
                          child: Text(
                            card.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleSmall!.copyWith(
                              color: done ? t.textSecondary : t.textPrimary,
                              decoration: done ? TextDecoration.lineThrough : null,
                              decorationColor: t.textTertiary,
                            ),
                          ),
                        ),
                        if (done) ...[
                          const SizedBox(width: Space.xs),
                          Icon(Icons.check_circle_rounded, size: 16, color: t.success),
                        ],
                      ],
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: Space.s),
                      Wrap(spacing: Space.xs, runSpacing: Space.xs, children: chips),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Callbacks a card gives its board while it is dragged.
class KanbanDragHooks {
  const KanbanDragHooks({required this.onStart, required this.onUpdate, required this.onEnd});

  final void Function(BoardCardRow card, double height) onStart;
  final void Function(Offset global) onUpdate;

  /// Returns whether the drop moved the card (a drop in place does not).
  final Future<bool> Function() onEnd;
}

/// An interactive kanban card: tap to edit; long-press to lift and drag it
/// (released in place, the long-press menu opens: edit, duplicate, move to
/// board, Top 3, prayer window, due date, move to column, forward / back,
/// delete); swipe toward the next column to advance it or the previous one
/// to send it back.
class KanbanCard extends ConsumerStatefulWidget {
  const KanbanCard({
    super.key,
    required this.card,
    required this.board,
    required this.today,
    required this.width,
    required this.drag,
    this.windowDay,
    this.dragging = false,
  });

  final BoardCardRow card;
  final WorkBoard board;
  final DateTime today;
  final DateTime? windowDay;
  final double width;
  final KanbanDragHooks drag;

  /// This card is the one being dragged (drawn collapsed in place).
  final bool dragging;

  @override
  ConsumerState<KanbanCard> createState() => _KanbanCardState();
}

class _KanbanCardState extends ConsumerState<KanbanCard> {
  final _item = GlobalKey<ActionableItemState>();
  double _moved = 0;

  BoardCardRow get card => widget.card;
  WorkBoard get board => widget.board;

  Future<UndoableAction?> _move(String columnId) =>
      WorkActions.moveToColumn(context, ref, board, card, columnId);

  ItemActions _actions(WorkTexts texts) {
    final l = texts.l;
    final column = board.columnOf(card);
    final next = BoardColumns.nextId(board.columns, column);
    final prev = BoardColumns.previousId(board.columns, column);
    String name(String id) => texts.name(texts.column(BoardColumns.byId(board.columns, id)!));
    return ItemActions(
      onEdit: () => WorkActions.editCard(context, ref, card),
      onDuplicate: () => WorkActions.duplicateCard(context, ref, card),
      onMove: () => WorkActions.moveToBoard(context, ref, card),
      onDelete: () => WorkActions.deleteCard(context, ref, card),
      extra: [
        ItemAction(
          icon: card.isTop3 ? Icons.star_outline_rounded : Icons.star_rounded,
          label: card.isTop3 ? l.workTop3Remove : l.workTop3Add,
          tone: ActionTone.accent,
          onSelected: () => WorkActions.toggleCardTop3(context, ref, card),
        ),
        ItemAction(
          icon: Icons.mosque_rounded,
          label: l.workPlaceInWindow,
          tone: ActionTone.info,
          onSelected: () => WorkActions.placeInWindow(context, ref, card),
        ),
        ItemAction(icon: Icons.event_rounded, label: l.workCardDue, onSelected: () => WorkActions.setDue(context, ref, card)),
        if (next != null)
          ItemAction(
            icon: Icons.arrow_forward_rounded,
            label: l.workMoveForward(name(next)),
            tone: ActionTone.success,
            onSelected: () => _move(next),
          ),
        if (prev != null)
          ItemAction(icon: Icons.arrow_back_rounded, label: l.workMoveBack(name(prev)), onSelected: () => _move(prev)),
        if (board.columns.length > 3)
          ItemAction(
            icon: Icons.view_column_rounded,
            label: l.workMoveToColumn,
            onSelected: () => WorkActions.pickColumn(context, ref, board, card),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final texts = WorkTexts.of(context);
    final t = context.tokens;
    final reduced = context.reducedMotion;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final column = BoardColumns.byId(board.columns, board.columnOf(card));
    final view = KanbanCardView(card: card, board: board, today: widget.today, windowDay: widget.windowDay);
    final radius = BorderRadius.circular(t.radiusM);

    final interactive = ActionableItem(
      key: _item,
      onTap: () => WorkActions.editCard(context, ref, card),
      actions: _actions(texts),
      swipeEnabled: false,
      borderRadius: radius,
      semanticLabel: texts.l.workCardSemantics(card.title, column == null ? '' : texts.column(column)),
      child: _SwipeToMove(
        columns: board.columns,
        columnId: board.columnOf(card),
        rtl: rtl,
        labelOf: (id) => texts.column(BoardColumns.byId(board.columns, id)!),
        onMove: (id) async {
          final action = await _move(id);
          if (action != null && context.mounted) unawaited(showUndoToast(context, action));
        },
        child: view,
      ),
    );

    return Semantics(
      hint: texts.l.workSwipeHint,
      child: LongPressDraggable<String>(
        data: card.id,
        delay: const Duration(milliseconds: 280),
        hapticFeedbackOnStart: false,
        maxSimultaneousDrags: 1,
        feedback: _Feedback(
          width: widget.width,
          rtl: rtl,
          reduced: reduced,
          child: KanbanCardView(
            card: card,
            board: board,
            today: widget.today,
            windowDay: widget.windowDay,
            lifted: true,
          ),
        ),
        childWhenDragging: const SizedBox(width: double.infinity),
        onDragStarted: () {
          _moved = 0;
          Fx.fire(Sfx.pickUp);
          final box = context.findRenderObject() as RenderBox?;
          widget.drag.onStart(card, box?.size.height ?? 72);
        },
        onDragUpdate: (d) {
          _moved += d.delta.distance;
          widget.drag.onUpdate(d.globalPosition);
        },
        onDragEnd: (_) async {
          final moved = await widget.drag.onEnd();
          // Lifted and released in place: the long-press menu.
          if (!moved && _moved < 12 && mounted) await _item.currentState?.openMenu();
        },
        child: widget.dragging ? const SizedBox(width: double.infinity) : interactive,
      ),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.width, required this.rtl, required this.reduced, required this.child});

  final double width;
  final bool rtl;
  final bool reduced;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: SizedBox(
          width: width,
          child: reduced
              ? child
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: MadarMotion.short,
                  curve: MadarMotion.decelerate,
                  builder: (context, v, child) => Transform.rotate(
                    angle: (rtl ? 1 : -1) * 0.035 * v,
                    child: Transform.scale(scale: 1 + 0.04 * v, child: child),
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}

/// Horizontal swipe that moves a card to the neighbouring column it points
/// at (forward = toward the next column: left in RTL, right in LTR). A
/// track behind the card names the target; crossing the threshold ticks,
/// releasing past it moves the card.
class _SwipeToMove extends StatefulWidget {
  const _SwipeToMove({
    required this.child,
    required this.columns,
    required this.columnId,
    required this.rtl,
    required this.labelOf,
    required this.onMove,
  });

  final Widget child;
  final List<BoardColumn> columns;
  final String columnId;
  final bool rtl;
  final String Function(String columnId) labelOf;
  final Future<void> Function(String columnId) onMove;

  @override
  State<_SwipeToMove> createState() => _SwipeToMoveState();
}

class _SwipeToMoveState extends State<_SwipeToMove> with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(vsync: this, duration: MadarMotion.medium)
    ..addListener(() => setState(() => _dx = _from * (1 - _settle.value) + _to * _settle.value));
  double _dx = 0, _from = 0, _to = 0, _width = 1;
  bool _armed = false, _busy = false;

  static const double _threshold = 0.3;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  String? _target(double dx) {
    if (dx == 0) return null;
    return KanbanMath.swipeTarget(widget.columns, widget.columnId, dx < 0 ? SwipeSide.left : SwipeSide.right, rtl: widget.rtl);
  }

  void _update(DragUpdateDetails d) {
    if (_busy) return;
    _settle.stop();
    var dx = _dx + d.delta.dx;
    // Rubber band where there is no column to go to.
    if (_target(dx) == null) dx = _dx + d.delta.dx * 0.25;
    dx = dx.clamp(-_width, _width);
    final armed = _target(dx) != null && dx.abs() >= _width * _threshold;
    if (armed != _armed) Fx.fire(Sfx.countTick);
    setState(() {
      _dx = dx;
      _armed = armed;
    });
  }

  Future<void> _end(DragEndDetails d) async {
    if (_busy) return;
    final v = d.primaryVelocity ?? 0;
    final flung = v.abs() > 900 && v.sign == _dx.sign && _dx.abs() > _width * 0.12;
    final target = _target(_dx);
    if (target != null && (_armed || flung)) {
      _busy = true;
      Fx.fire(Sfx.swipe);
      final reduced = context.reducedMotion;
      if (!reduced) {
        _animateTo(_dx.sign * _width * 1.05, MadarMotion.short);
        await _settle.forward(from: 0).orCancel.catchError((_) {});
      }
      await widget.onMove(target);
      if (mounted) {
        setState(() {
          _dx = 0;
          _armed = false;
          _busy = false;
        });
      }
      return;
    }
    _armed = false;
    _animateTo(0, MadarMotion.medium);
    unawaited(_settle.forward(from: 0).orCancel.catchError((_) {}));
  }

  void _animateTo(double to, Duration duration) {
    _from = _dx;
    _to = to;
    _settle.duration = context.motion(duration);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final target = _target(_dx);
    final forward = _dx != 0 && KanbanMath.isForward(_dx < 0 ? SwipeSide.left : SwipeSide.right, rtl: widget.rtl);
    final color = forward ? t.success : t.info;
    final progress = (_dx.abs() / (_width * _threshold)).clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = math.max(1, constraints.maxWidth);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _update,
          onHorizontalDragEnd: _end,
          onHorizontalDragCancel: () => _end(DragEndDetails()),
          child: Stack(
            children: [
              if (_dx != 0 && target != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.35 + 0.65 * progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(t.radiusM),
                        color: color.withValues(alpha: _armed ? 0.22 : 0.1),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: Space.l),
                      // The label sits on the side the card uncovers.
                      alignment: _dx < 0 ? Alignment.centerRight : Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        textDirection: TextDirection.ltr,
                        children: [
                          if (_dx < 0) Icon(Icons.west_rounded, size: 18, color: color),
                          if (_dx < 0) const SizedBox(width: Space.xs),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: _width * 0.45),
                            child: Text(
                              widget.labelOf(target),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: widget.rtl ? TextDirection.rtl : TextDirection.ltr,
                              style: text.labelLarge!.copyWith(color: color),
                            ),
                          ),
                          if (_dx > 0) const SizedBox(width: Space.xs),
                          if (_dx > 0) Icon(Icons.east_rounded, size: 18, color: color),
                        ],
                      ),
                    ),
                  ),
                ),
              Transform.translate(offset: Offset(_dx, 0), child: widget.child),
            ],
          ),
        );
      },
    );
  }
}
