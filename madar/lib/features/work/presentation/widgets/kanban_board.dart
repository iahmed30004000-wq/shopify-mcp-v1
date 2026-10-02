import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/work_models.dart';
import '../../domain/board_columns.dart';
import '../../domain/card_filter.dart';
import '../../domain/kanban.dart';
import '../work_actions.dart';
import '../work_labels.dart';
import 'kanban_card.dart';
import 'work_widgets.dart';

/// The kanban: a strip of column tabs (with counts; drop targets while
/// dragging) above horizontally scrolling columns that snap into place and
/// flow in the reading direction (the first column on the right in Arabic).
/// Cards drag between columns and within one (long-press), with edge
/// auto-scroll, a drop gap and haptics.
class KanbanBoard extends ConsumerStatefulWidget {
  const KanbanBoard({
    super.key,
    required this.board,
    required this.cards,
    required this.today,
    this.filter = CardFilter.all,
    this.windowDays = const {},
    this.controller,
    this.onVisibleColumn,
  });

  final WorkBoard board;

  /// The board's cards in their stored order.
  final List<BoardCardRow> cards;
  final DateTime today;
  final CardFilter filter;

  /// Card id → day of its prayer-window placement.
  final Map<String, DateTime?> windowDays;
  final ScrollController? controller;

  /// The column most in view changed (for "add card" defaults).
  final ValueChanged<String>? onVisibleColumn;

  @override
  ConsumerState<KanbanBoard> createState() => KanbanBoardState();
}

class _Drag {
  _Drag(this.card, this.from, this.height);

  final BoardCardRow card;
  final String from;
  final double height;
  String? column;
  int? index;
  Offset pointer = Offset.zero;
}

class KanbanBoardState extends ConsumerState<KanbanBoard> with SingleTickerProviderStateMixin {
  late ScrollController _h = widget.controller ?? ScrollController();
  final Map<String, ScrollController> _v = {};
  final GlobalKey _viewport = GlobalKey();
  final Map<String, GlobalKey> _columnKeys = {};
  final Map<String, GlobalKey> _tabKeys = {};
  final Map<String, GlobalKey> _cardKeys = {};
  _Drag? _drag;
  late final Ticker _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;
  double _extent = 300;
  String? _visible;

  static const double _gap = Space.m;

  @override
  void didUpdateWidget(KanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && widget.controller != _h) _h = widget.controller!;
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (widget.controller == null) _h.dispose();
    for (final c in _v.values) {
      c.dispose();
    }
    super.dispose();
  }

  ScrollController _vc(String col) => _v.putIfAbsent(col, ScrollController.new);
  GlobalKey _key(Map<String, GlobalKey> m, String id) => m.putIfAbsent(id, GlobalKey.new);

  Rect? _rect(GlobalKey? k) {
    final box = k?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  List<BoardCardRow> _visibleIn(String col) => [
    for (final c in widget.cards)
      if (widget.board.columnOf(c) == col &&
          widget.filter.matches(
            assignee: c.assignee,
            dueDate: c.dueDate,
            done: widget.board.isDone(c),
            today: widget.today,
          ))
        c,
  ];

  /// Scrolls the strip so [columnId] is in view.
  Future<void> showColumn(String columnId) async {
    final i = BoardColumns.indexOf(widget.board.columns, columnId);
    if (i < 0 || !_h.hasClients) return;
    final target = (i * (_extent + _gap)).clamp(_h.position.minScrollExtent, _h.position.maxScrollExtent);
    if (context.reducedMotion) {
      _h.jumpTo(target);
    } else {
      await _h.animateTo(target, duration: MadarMotion.medium, curve: MadarMotion.emphasized);
    }
  }

  void _onScroll() {
    if (!_h.hasClients) return;
    final cols = widget.board.columns;
    final i = (_h.offset / (_extent + _gap)).round().clamp(0, cols.length - 1);
    final id = cols[i].id;
    if (id != _visible) {
      setState(() => _visible = id);
      widget.onVisibleColumn?.call(id);
    }
  }

  // ------------------------------------------------------------- drag ----

  void _start(BoardCardRow card, double height) {
    setState(() {
      final d = _Drag(card, widget.board.columnOf(card), height);
      d.column = d.from;
      d.index = _originIndex(d);
      _drag = d;
    });
    _lastTick = Duration.zero;
    if (!_ticker.isActive) unawaited(_ticker.start());
  }

  /// Where the dragged card sits in its own column (cards before it).
  int _originIndex(_Drag d) {
    final i = _visibleIn(d.from).indexWhere((c) => c.id == d.card.id);
    return i < 0 ? 0 : i;
  }

  void _update(Offset global) {
    final d = _drag;
    if (d == null) return;
    d.pointer = global;
    _hover(global);
  }

  void _hover(Offset g) {
    final d = _drag;
    if (d == null) return;
    String? col;
    int? index;
    for (final e in _tabKeys.entries) {
      final r = _rect(e.value);
      if (r != null && r.inflate(4).contains(g)) {
        col = e.key;
        index = _visibleIn(col).where((c) => c.id != d.card.id).length;
        if (col != _visible) unawaited(showColumn(col));
        break;
      }
    }
    if (col == null) {
      final viewport = _rect(_viewport);
      if (viewport == null || g.dy < viewport.top - 8) return;
      for (final e in _columnKeys.entries) {
        final r = _rect(e.value);
        if (r != null && g.dx >= r.left && g.dx <= r.right) {
          col = e.key;
          break;
        }
      }
      if (col == null) return;
      final mids = <double>[
        for (final c in _visibleIn(col))
          if (c.id != d.card.id) ?_rect(_cardKeys[c.id])?.center.dy,
      ];
      index = KanbanMath.insertionIndex(g.dy, mids);
    }
    if (col != d.column || index != d.index) {
      if (col != d.column) Fx.fire(Sfx.countTick);
      setState(() {
        d.column = col;
        d.index = index;
      });
    }
  }

  void _tick(Duration now) {
    final d = _drag;
    if (d == null) {
      _ticker.stop();
      return;
    }
    final dt = _lastTick == Duration.zero ? 0.0 : (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (dt <= 0 || dt > 0.1) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    var scrolled = false;
    final viewport = _rect(_viewport);
    if (viewport != null && _h.hasClients) {
      final speed = KanbanMath.autoScrollSpeed(d.pointer.dx, start: viewport.left, end: viewport.right, edge: 44);
      if (speed != 0) {
        final p = _h.position;
        final next = (p.pixels + (rtl ? -speed : speed) * dt).clamp(p.minScrollExtent, p.maxScrollExtent);
        if (next != p.pixels) {
          _h.jumpTo(next);
          scrolled = true;
        }
      }
    }
    final col = d.column;
    final list = col == null ? null : _rect(_columnKeys[col]);
    final vc = col == null ? null : _v[col];
    if (list != null && vc != null && vc.hasClients) {
      final speed = KanbanMath.autoScrollSpeed(d.pointer.dy, start: list.top, end: list.bottom, edge: 40, maxSpeed: 700);
      if (speed != 0) {
        final p = vc.position;
        final next = (p.pixels + speed * dt).clamp(p.minScrollExtent, p.maxScrollExtent);
        if (next != p.pixels) {
          vc.jumpTo(next);
          scrolled = true;
        }
      }
    }
    if (scrolled) _hover(d.pointer);
  }

  Future<bool> _end() async {
    final d = _drag;
    _ticker.stop();
    if (d == null) return false;
    final col = d.column, index = d.index;
    final fromIndex = _originIndex(d);
    if (col == null ||
        index == null ||
        KanbanMath.isNoop(d.from, fromIndex, CardMove(cardId: d.card.id, columnId: col, index: index))) {
      setState(() => _drag = null);
      Fx.fire(Sfx.drop);
      return false;
    }
    final orders = {for (final c in widget.board.columns) c.id: [for (final x in _visibleIn(c.id)) x.id]};
    final next = KanbanMath.apply(orders, CardMove(cardId: d.card.id, columnId: col, index: index));
    final pointer = d.pointer;
    final action = await WorkActions.moveToColumn(
      context,
      ref,
      widget.board,
      d.card,
      col,
      order: next[col],
      celebrateAt: pointer,
    );
    if (mounted) setState(() => _drag = null);
    if (action != null && mounted) unawaited(showUndoToast(context, action));
    return true;
  }

  // ------------------------------------------------------------ build ----

  @override
  Widget build(BuildContext context) {
    final texts = WorkTexts.of(context);
    final cols = widget.board.columns;
    return LayoutBuilder(
      builder: (context, constraints) {
        _extent = KanbanMath.columnExtent(constraints.maxWidth);
        final hooks = KanbanDragHooks(onStart: _start, onUpdate: _update, onEnd: _end);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ColumnTabs(
              board: widget.board,
              counts: {for (final c in cols) c.id: _visibleIn(c.id).length},
              visible: _visible ?? cols.first.id,
              dropColumn: _drag?.column,
              keyOf: (id) => _key(_tabKeys, id),
              onTap: (id) {
                Fx.fire(Sfx.tap);
                unawaited(showColumn(id));
              },
            ),
            const SizedBox(height: Space.s),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.metrics.axis == Axis.horizontal && n.depth == 0) _onScroll();
                  return false;
                },
                child: ListView.separated(
                  key: _viewport,
                  controller: _h,
                  scrollDirection: Axis.horizontal,
                  physics: _ColumnSnapPhysics(extent: _extent + _gap),
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.l),
                  itemCount: cols.length,
                  separatorBuilder: (_, _) => const SizedBox(width: _gap),
                  itemBuilder: (context, i) {
                    final c = cols[i];
                    return SizedBox(
                      width: _extent,
                      child: _KanbanColumn(
                        board: widget.board,
                        column: c,
                        cards: _visibleIn(c.id),
                        total: widget.cards.where((x) => widget.board.columnOf(x) == c.id).length,
                        filtered: widget.filter.isActive,
                        today: widget.today,
                        windowDays: widget.windowDays,
                        listKey: _key(_columnKeys, c.id),
                        cardKey: (id) => _key(_cardKeys, id),
                        controller: _vc(c.id),
                        width: _extent,
                        hooks: hooks,
                        drag: _drag,
                        label: texts.column(c),
                        onAdd: () => WorkActions.newCard(context, ref, widget.board, columnId: c.id),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ColumnTabs extends StatelessWidget {
  const _ColumnTabs({
    required this.board,
    required this.counts,
    required this.visible,
    required this.dropColumn,
    required this.keyOf,
    required this.onTap,
  });

  final WorkBoard board;
  final Map<String, int> counts;
  final String visible;
  final String? dropColumn;
  final GlobalKey Function(String id) keyOf;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
        children: [
          for (final c in board.columns)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.s),
              child: MadarPressable(
                key: keyOf(c.id),
                onTap: () => onTap(c.id),
                sfx: null,
                selected: c.id == visible,
                semanticLabel: '${texts.column(c)}، ${texts.cards(counts[c.id] ?? 0)}',
                child: AnimatedContainer(
                  duration: context.motion(MadarMotion.short),
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs, Space.s, Space.xs),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: dropColumn == c.id
                        ? t.accent.withValues(alpha: 0.28)
                        : c.id == visible
                        ? t.accentSoft
                        : t.glassFill,
                    border: Border.all(
                      color: dropColumn == c.id || c.id == visible ? t.accent.withValues(alpha: 0.7) : t.glassBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.isDone) ...[Icon(Icons.task_alt_rounded, size: 14, color: t.success), const SizedBox(width: 4)],
                      Text(
                        texts.column(c),
                        style: text.labelLarge!.copyWith(color: c.id == visible ? t.textPrimary : t.textSecondary),
                      ),
                      const SizedBox(width: Space.xs + 2),
                      CountPill(text: texts.n(counts[c.id] ?? 0), color: c.isDone ? t.success : null),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.board,
    required this.column,
    required this.cards,
    required this.total,
    required this.filtered,
    required this.today,
    required this.windowDays,
    required this.listKey,
    required this.cardKey,
    required this.controller,
    required this.width,
    required this.hooks,
    required this.drag,
    required this.label,
    required this.onAdd,
  });

  final WorkBoard board;
  final BoardColumn column;
  final List<BoardCardRow> cards;
  final int total;
  final bool filtered;
  final DateTime today;
  final Map<String, DateTime?> windowDays;
  final GlobalKey listKey;
  final GlobalKey Function(String id) cardKey;
  final ScrollController controller;
  final double width;
  final KanbanDragHooks hooks;
  final _Drag? drag;
  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final texts = WorkTexts.of(context);
    final l = texts.l;
    final text = Theme.of(context).textTheme;
    final hovering = drag != null && drag!.column == column.id;
    final accent = column.isDone ? t.success : workColor(t, board.color);

    final children = <Widget>[];
    var others = 0;
    Widget gap() => _DropGap(key: const ValueKey('drop-gap'), height: drag?.height ?? 72, label: l.workDropHere);
    for (final c in cards) {
      final isDragged = drag?.card.id == c.id;
      if (hovering && !isDragged && others == drag!.index) children.add(gap());
      children.add(
        Padding(
          key: ValueKey('card-${c.id}'),
          padding: EdgeInsetsDirectional.only(bottom: isDragged ? 0 : Space.s),
          child: KeyedSubtree(
            key: cardKey(c.id),
            child: KanbanCard(
              card: c,
              board: board,
              today: today,
              windowDay: windowDays[c.id],
              width: width - Space.s * 2,
              drag: hooks,
              dragging: isDragged,
            ),
          ),
        ),
      );
      if (!isDragged) others++;
    }
    if (hovering && drag!.index != null && drag!.index! >= others) children.add(gap());
    final empty = children.isEmpty;

    return AnimatedContainer(
      duration: context.motion(MadarMotion.short),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusL),
        color: hovering ? t.accent.withValues(alpha: 0.06) : t.glassFill.withValues(alpha: t.glassFill.a * 0.6),
        border: Border.all(color: hovering ? t.accent.withValues(alpha: 0.5) : t.glassBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: name, count, done marker.
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.s, Space.s),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                ),
                if (column.isDone)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: Space.xs),
                    child: Tooltip(
                      message: l.workDoneColumn,
                      child: Icon(Icons.task_alt_rounded, size: 16, color: t.success),
                    ),
                  ),
                CountPill(
                  text: filtered ? '${texts.n(cards.length)}/${texts.n(total)}' : texts.n(total),
                  color: column.isDone ? t.success : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: empty
                ? Center(
                    key: listKey,
                    child: Padding(
                      padding: const EdgeInsets.all(Space.l),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IslamicStar(size: 22, color: t.textTertiary.withValues(alpha: 0.6), filled: false),
                          const SizedBox(height: Space.s),
                          Text(
                            filtered && total > 0 ? l.workFilterNoMatch : l.workColumnEmpty,
                            textAlign: TextAlign.center,
                            style: text.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    key: listKey,
                    controller: controller,
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.xs, Space.s, Space.s),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                  ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 0, Space.s, Space.s),
            child: MadarButton(
              label: l.workAddCard,
              icon: Icons.add_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              expand: true,
              sfx: Sfx.sheetOpen,
              onPressed: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropGap extends StatelessWidget {
  const _DropGap({super.key, required this.height, required this.label});

  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: context.motion(MadarMotion.short),
      curve: MadarMotion.emphasized,
      builder: (context, v, child) => SizedBox(height: (height + Space.s) * v, child: child),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Space.s),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: t.accent.withValues(alpha: 0.08),
            border: Border.all(color: t.accent.withValues(alpha: 0.55), width: 1.2),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: t.accent)),
          ),
        ),
      ),
    );
  }
}

/// Snaps the column strip to column starts.
class _ColumnSnapPhysics extends ScrollPhysics {
  const _ColumnSnapPhysics({required this.extent, super.parent});

  final double extent;

  @override
  _ColumnSnapPhysics applyTo(ScrollPhysics? ancestor) => _ColumnSnapPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var page = position.pixels / extent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    final target = (page.roundToDouble() * extent).clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(spring, position.pixels, target, velocity, tolerance: tolerance);
  }

  @override
  bool get allowImplicitScrolling => false;
}
