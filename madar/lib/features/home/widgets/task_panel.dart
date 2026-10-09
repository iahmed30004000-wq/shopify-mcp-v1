import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/routing/route_pages.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../work/work.dart' show FocusItem, FocusKind, WorkActions;
import '../home_providers.dart';
import 'neglect_radar_card.dart';
import 'task_actions.dart';
import 'task_tile.dart';
import 'window_chips.dart';

/// Content of the home screen's bottom glass panel: the six window chips,
/// the Neglect Radar (one line while the panel peeks, its cards once it is
/// [expanded]), the focused window's header (title + progress), its
/// reorderable task list and the quick-add bar (the panel's one "+").
/// [dragArea] wraps the top part so the screen can turn vertical drags into
/// panel expansion; the grabber toggles it ([onToggle]).
class TaskPanel extends ConsumerWidget {
  const TaskPanel({super.key, this.dragArea, this.onOpenPlanet, this.expanded, this.expansion, this.onToggle});

  final Widget Function(Widget child)? dragArea;

  /// Opens a planet page (from the Neglect Radar).
  final OpenPlanet? onOpenPlanet;

  /// Whether the panel is expanded (null: always expanded).
  final ValueListenable<bool>? expanded;

  /// How far the panel is expanded (0 peeking … 1 open): the task list
  /// fades in with it (a peeking panel never shows a sliver of a row).
  final Animation<double>? expansion;

  /// Expands / collapses the panel (the grabber is a button then).
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final times = ref.watch(prayerDayProvider);
    final focused = ref.watch(homeFocusedWindowProvider);
    final current = ref.watch(homeCurrentWindowProvider);
    final day = ref.watch(homeDayProvider);
    final tasks = ref.watch(homeTasksProvider((window: focused, day: day))).value;
    final now = ref.watch(homeNowProvider);
    final next = times.nextPrayer(now);
    final nextWindow = _windowOf(next.prayer);
    final total = tasks?.length ?? 0;
    final done = tasks?.where((x) => x.done).length ?? 0;

    final top = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Grabber(expanded: expanded, onToggle: onToggle),
        WindowChips(
          times: times,
          focused: focused,
          current: current,
          nextWindow: nextWindow,
          countdown: l.orbitUiInDuration(fmt.formatDurationWords(l, next.at.difference(now))),
          onSelected: (w) => ref.read(homeWindowProvider.notifier).focus(w == current ? null : w),
          onOpenTimes: () => FaithNav.prayerTimes(context),
        ),
        if (onOpenPlanet != null) ...[
          const SizedBox(height: Space.s + 2),
          _Radar(expansion: expansion, onOpen: onOpenPlanet!),
        ],
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.l, Space.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: context.motion(MadarMotion.short),
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                      child: Semantics(
                        key: ValueKey(focused),
                        header: true,
                        child: Text(
                          windowLabel(l, focused),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineSmall!.copyWith(
                            color: t.textPrimary,
                            fontFamilyFallback: const [MadarTypography.uiFamily],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      total == 0
                          ? fmt.localizeDigits(l.homeTasksCount(0))
                          : l.orbitUiListSeparator(
                              fmt.localizeDigits(l.homeTasksCount(total)),
                              l.homeTasksProgress(fmt.formatInt(done), fmt.formatInt(total)),
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              // The window's progress (the quick-add bar below is the
              // panel's one "+").
              if (total > 0)
                ProgressRing(
                  value: done / total,
                  size: 38,
                  strokeWidth: 3.5,
                  color: t.success,
                  glow: done == total,
                  semanticLabel: l.homeTasksProgress(fmt.formatInt(done), fmt.formatInt(total)),
                  child: Text(
                    l.orbitUiFraction(fmt.formatInt(done), fmt.formatInt(total)),
                    maxLines: 1,
                    style: text.labelSmall!.copyWith(color: t.textPrimary, height: 1, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    // The header on top, the quick-add bar at the bottom, the list between
    // them; a panel squeezed below its peek height (a keyboard, a drag
    // mid-flight) clips its header instead of overflowing.
    return CustomMultiChildLayout(
      delegate: _PanelLayout.instance,
      children: [
        LayoutId(
          id: _PanelSlot.top,
          child: ClipRect(
            child: OverflowBox(
              fit: OverflowBoxFit.deferToChild,
              maxHeight: double.infinity,
              alignment: AlignmentDirectional.topCenter,
              child: dragArea?.call(top) ?? top,
            ),
          ),
        ),
        LayoutId(
          id: _PanelSlot.list,
          child: _ListReveal(
            expansion: expansion,
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.medium),
              switchInCurve: MadarMotion.decelerate,
              switchOutCurve: MadarMotion.accelerate,
              child: KeyedSubtree(
                key: ValueKey((focused, tasks == null, total == 0)),
                child: tasks == null
                    ? const SizedBox.expand()
                    : tasks.isEmpty
                    ? _EmptyWindow(
                        onAdd: () => TaskActions(ref, context).add(window: focused, day: day),
                      )
                    : _EdgeFade(
                        child: ReorderableGlassList<TaskRow>(
                          items: tasks,
                          itemKey: (task) => task.id,
                          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xs, Space.l, Space.m),
                          onReorder: (order) =>
                              ref.read(homeTasksServiceProvider).reorder([for (final x in order) x.id]),
                          itemBuilder: (context, task, index, handle) => TaskItem(task: task, dragHandle: handle),
                          // The "add a task" affordance the empty state
                          // shows has to stay once the window has tasks
                          // (APK #15, B4). A footer is outside the
                          // reorderable range: it cannot be dragged and it
                          // does not shift any row's index.
                          footer: _AddTaskRow(
                            onAdd: () => TaskActions(ref, context).add(window: focused, day: day),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        LayoutId(
          id: _PanelSlot.bar,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.m),
            child: QuickAddBar(
              blur: false,
              clock: ref.read(homeClockProvider),
              onAdded: (intent) {
                final w = intent.window;
                final isTask = intent.kind == QuickAddKind.task || intent.kind == QuickAddKind.note;
                if (isTask && w != null && w != PrayerWindow.anytime && w != focused) {
                  ref.read(homeWindowProvider.notifier).focus(w == current ? null : w);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

enum _PanelSlot { top, list, bar }

/// [TaskPanel]'s layout: the header at its natural height (clipped when the
/// panel is shorter), the quick-add bar pinned to the bottom, the list in
/// between (possibly empty while the panel peeks).
class _PanelLayout extends MultiChildLayoutDelegate {
  _PanelLayout();

  static final _PanelLayout instance = _PanelLayout();

  @override
  void performLayout(Size size) {
    final w = size.width;
    final bar = layoutChild(_PanelSlot.bar, BoxConstraints(minWidth: w, maxWidth: w, maxHeight: size.height));
    positionChild(_PanelSlot.bar, Offset(0, math.max(0, size.height - bar.height)));
    final room = math.max(0.0, size.height - bar.height);
    final top = layoutChild(_PanelSlot.top, BoxConstraints(minWidth: w, maxWidth: w, maxHeight: room));
    positionChild(_PanelSlot.top, Offset.zero);
    final list = math.max(0.0, room - top.height);
    layoutChild(_PanelSlot.list, BoxConstraints.tightFor(width: w, height: list));
    positionChild(_PanelSlot.list, Offset(0, top.height));
  }

  @override
  bool shouldRelayout(_PanelLayout oldDelegate) => false;
}

PrayerWindow _windowOf(Prayer p) => switch (p) {
  Prayer.fajr => PrayerWindow.fajr,
  Prayer.dhuhr => PrayerWindow.dhuhr,
  Prayer.asr => PrayerWindow.asr,
  Prayer.maghrib => PrayerWindow.maghrib,
  _ => PrayerWindow.isha,
};

/// Softly fades the list into the glass at its top and bottom edges, so
/// rows slide under the header and the quick-add bar instead of being cut.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final edge = rect.height <= 0 ? 0.0 : (Space.l / rect.height).clamp(0.0, 0.18);
        final white = context.tokens.textPrimary.withValues(alpha: 1);
        final clear = white.withValues(alpha: 0);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [clear, white, white, clear],
          // a gentle top edge; a longer (~36 px) fade into the quick-add bar
          stops: [0, edge * 0.5, 1 - edge * 2.25, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

/// The panel's drag handle; a button that expands / collapses the panel
/// when [onToggle] is set.
class _Grabber extends StatelessWidget {
  const _Grabber({this.expanded, this.onToggle});

  final ValueListenable<bool>? expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bar = Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.s, bottom: Space.s),
      child: Center(
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: t.textTertiary.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
    final toggle = onToggle, open = expanded;
    if (toggle == null || open == null) return bar;
    final l = L10n.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: open,
      builder: (context, isOpen, child) => Semantics(
        button: true,
        label: isOpen ? l.orbitUiPanelCollapse : l.orbitUiPanelExpand,
        excludeSemantics: true,
        onTap: toggle,
        child: child,
      ),
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: toggle, child: bar),
    );
  }
}

/// The Neglect Radar: one calm line while the panel peeks, the three cards
/// once it is expanded – their heights blend with the panel's [expansion]
/// itself, so the radar never outgrows the panel mid-drag.
class _Radar extends StatelessWidget {
  const _Radar({required this.expansion, required this.onOpen});

  final Animation<double>? expansion;
  final OpenPlanet onOpen;

  /// 0 = the one-line radar … 1 = the cards (from 30 % to 70 % open).
  static double cardsFor(double expansion) {
    final x = ((expansion - 0.3) / 0.4).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  @override
  Widget build(BuildContext context) {
    final e = expansion;
    if (e == null) return NeglectRadarStrip(onOpen: onOpen);
    final line = NeglectRadarStrip(onOpen: onOpen, compact: true);
    final cards = NeglectRadarStrip(onOpen: onOpen);
    return AnimatedBuilder(
      animation: e,
      builder: (context, _) {
        final f = cardsFor(e.value);
        Widget part(Widget child, double factor) => ClipRect(
          child: Align(
            alignment: AlignmentDirectional.topCenter,
            heightFactor: factor,
            child: Opacity(opacity: factor, child: child),
          ),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (f < 1) part(line, 1 - f), if (f > 0) part(cards, f)],
        );
      },
    );
  }
}

/// "New task" at the end of the task list: the panel's always-present "+"
/// once the window is no longer empty. Not a list item, so it never takes
/// part in a reorder.
class _AddTaskRow extends StatelessWidget {
  const _AddTaskRow({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xs, 0, Space.xs),
      child: MadarPressable(
        onTap: onAdd,
        semanticLabel: l.homeAddTask,
        sfx: Sfx.sheetOpen,
        excludeChildSemantics: true,
        focusRadius: BorderRadius.circular(t.radiusM),
        minTapTarget: MadarPressable.minTouchTarget,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: t.glassFill,
            border: Border.all(color: t.accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 20, color: t.accent),
              const SizedBox(width: Space.s),
              Text(
                l.homeAddTask,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelLarge?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWindow extends StatelessWidget {
  const _EmptyWindow({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxHeight < 260;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Center(
              // The illustration settles after its entrance: its idle loop
              // would otherwise schedule a frame every vsync and keep the
              // whole home (the orbit included) off its 30 fps idle.
              child: _SettleTickers(
                after: context.motion(MadarMotion.long) + const Duration(milliseconds: 300),
                child: AnimatedEmptyState(
                  kind: EmptyStateKind.emptyList,
                  title: l.homeEmptyTitle,
                  // An empty body hides it (null would show the kit's generic text).
                  body: compact ? '' : l.homeEmptyBody,
                  actionLabel: l.homeAddTask,
                  actionIcon: Icons.add_rounded,
                  onAction: onAdd,
                  illustrationSize: compact ? 64 : 104,
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.xl, vertical: Space.s),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The task list, faded in as the panel expands (hidden while it peeks).
class _ListReveal extends StatelessWidget {
  const _ListReveal({required this.expansion, required this.child});

  final Animation<double>? expansion;
  final Widget child;

  static double _reveal(double t) {
    final x = ((t - 0.02) / 0.28).clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }

  @override
  Widget build(BuildContext context) {
    final e = expansion;
    if (e == null) return child;
    return AnimatedBuilder(
      animation: e,
      builder: (context, child) {
        final o = _reveal(e.value);
        // Hidden entirely (and not hit-testable) while the panel peeks.
        return Visibility(
          visible: o > 0.01,
          maintainState: true,
          child: Opacity(opacity: o, child: child),
        );
      },
      child: child,
    );
  }
}

/// Lets its subtree's tickers run for [after] (an entrance), then mutes
/// them for good.
class _SettleTickers extends StatefulWidget {
  const _SettleTickers({required this.after, required this.child});

  final Duration after;
  final Widget child;

  @override
  State<_SettleTickers> createState() => _SettleTickersState();
}

class _SettleTickersState extends State<_SettleTickers> {
  Timer? _timer;
  bool _live = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.after, () {
      if (mounted) setState(() => _live = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(enabled: _live, child: widget.child);
}

/// One task row with every interaction wired (tap = edit, long-press menu,
/// swipe right = complete / reopen with a stardust burst, swipe left =
/// reminder / move) – on home's panel and on a world's page.
class TaskItem extends ConsumerStatefulWidget {
  const TaskItem({super.key, required this.task, this.dragHandle});

  final TaskRow task;

  /// The reorder handle (home's list only).
  final Widget? dragHandle;

  @override
  ConsumerState<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends ConsumerState<TaskItem> {
  /// The task as a Top 3 item (its card when it carries one).
  static FocusItem _focusOf(TaskRow task) {
    final card = task.cardId;
    return card != null
        ? FocusItem(kind: FocusKind.card, id: card, title: task.title, flagged: task.isTop3, done: task.done)
        : FocusItem(kind: FocusKind.task, id: task.id, title: task.title, flagged: task.isTop3, done: task.done);
  }

  final GlobalKey _tileKey = GlobalKey();

  /// Stardust from the task's orb (at the reading start of the row).
  void _celebrate() {
    final box = _tileKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final orbX = rtl ? box.size.width - 30 : 30.0;
    Celebrate.burst(context, box.localToGlobal(Offset(orbX, box.size.height / 2)), intensity: 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final l = L10n.of(context);
    final arabic = ref.watch(appSettingsProvider.select((s) => s.isArabic));
    final planets = ref.watch(homePlanetsProvider).value ?? const <String, PlanetRow>{};
    final rule = ref.watch(homeTaskRemindersProvider.select((r) => r.value?[task.id]));
    final planet = task.planetKey == null ? null : planets[task.planetKey];
    final actions = TaskActions(ref, context);
    return ActionableItem(
      key: ValueKey('item-${task.id}'),
      // The tile's texts (title, window, planet) are read once each; only
      // the done state, shown by an icon, is said here.
      semanticLabel: task.done ? l.homeTaskDone : null,
      onTap: () => actions.edit(task),
      completeIcon: task.done ? Icons.replay_rounded : Icons.check_rounded,
      completeLabel: task.done ? l.homeTaskReopen : null,
      onCompleteSwipe: () async {
        final undo = await actions.toggleDone(task);
        if (!task.done && mounted) _celebrate();
        return undo;
      },
      quickActions: [
        QuickAction(
          icon: Icons.notifications_active_rounded,
          label: l.actionSetReminder,
          onPressed: () async {
            await actions.setReminder(task);
            return null;
          },
        ),
        QuickAction(
          icon: Icons.schedule_rounded,
          label: l.actionMove,
          tone: ActionTone.info,
          onPressed: () => actions.move(task),
        ),
      ],
      actions: ItemActions(
        onEdit: () => actions.edit(task),
        onDuplicate: () => actions.duplicate(task),
        onMove: () => actions.move(task),
        onSetReminder: () => actions.setReminder(task),
        onDelete: () => actions.delete(task),
        extra: [
          // Today's Top 3 is Work's: its limit of three, the swap sheet when
          // full, a card-linked task flags its card.
          if (!task.done || task.isTop3)
            ItemAction(
              icon: task.isTop3 ? Icons.star_rounded : Icons.star_outline_rounded,
              label: task.isTop3 ? l.workTop3Remove : l.workTop3Add,
              onSelected: () => WorkActions.setTop3(context, ref, _focusOf(task), !task.isTop3, showToast: false),
            ),
        ],
      ),
      child: TaskTile(
        key: _tileKey,
        task: task,
        dragHandle: widget.dragHandle,
        planet: planet,
        planetName: planet == null ? null : (arabic ? planet.nameAr : planet.nameEn),
        reminder: rule == null ? null : describeReminder(context, rule),
      ),
    );
  }
}
