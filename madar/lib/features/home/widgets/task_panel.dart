import 'package:flutter/material.dart';
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
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../home_providers.dart';
import 'task_actions.dart';
import 'task_tile.dart';
import 'window_chips.dart';

/// Content of the home screen's bottom glass panel: the six window chips,
/// the focused window's header (progress + add), its reorderable task list
/// and the quick-add bar. [dragArea] wraps the top part so the screen can
/// turn vertical drags into panel expansion.
class TaskPanel extends ConsumerWidget {
  const TaskPanel({super.key, this.dragArea});

  final Widget Function(Widget child)? dragArea;

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
    final total = tasks?.length ?? 0;
    final done = tasks?.where((x) => x.done).length ?? 0;

    final top = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Grabber(),
        WindowChips(
          times: times,
          focused: focused,
          current: current,
          onSelected: (w) => ref.read(homeWindowProvider.notifier).focus(w == current ? null : w),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.l, Space.s),
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
                          : '${fmt.localizeDigits(l.homeTasksCount(total))} · '
                                '${l.homeTasksProgress(fmt.formatInt(done), fmt.formatInt(total))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall!.copyWith(color: t.textTertiary),
                    ),
                  ],
                ),
              ),
              if (total > 0) ...[
                ProgressRing(
                  value: done / total,
                  size: 38,
                  strokeWidth: 3.5,
                  color: t.success,
                  glow: done == total,
                  semanticLabel: l.homeTasksProgress(fmt.formatInt(done), fmt.formatInt(total)),
                  child: Text(fmt.formatInt(done), style: text.labelMedium!.copyWith(color: t.textPrimary, height: 1)),
                ),
                const SizedBox(width: Space.m),
              ],
              MadarButton.icon(
                icon: Icons.add_rounded,
                semanticLabel: l.homeAddTask,
                variant: MadarButtonVariant.primary,
                sfx: Sfx.sheetOpen,
                onPressed: () => TaskActions(ref, context).add(window: focused, day: day),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dragArea?.call(top) ?? top,
        Expanded(
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
                        onReorder: (order) => ref.read(homeTasksServiceProvider).reorder([for (final x in order) x.id]),
                        itemBuilder: (context, task, index, handle) => _TaskItem(task: task, dragHandle: handle),
                      ),
                    ),
            ),
          ),
        ),
        Padding(
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
      ],
    );
  }
}

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
        final edge = rect.height <= 0 ? 0.0 : (Space.l / rect.height).clamp(0.0, 0.2);
        final white = context.tokens.textPrimary.withValues(alpha: 1);
        final clear = white.withValues(alpha: 0);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [clear, white, white, clear],
          stops: [0, edge * 0.5, 1 - edge * 1.5, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
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
        );
      },
    );
  }
}

/// One task row with every interaction wired (tap = edit, long-press menu,
/// swipe right = complete / reopen with a stardust burst, swipe left =
/// reminder / move).
class _TaskItem extends ConsumerStatefulWidget {
  const _TaskItem({required this.task, required this.dragHandle});

  final TaskRow task;
  final Widget dragHandle;

  @override
  ConsumerState<_TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends ConsumerState<_TaskItem> {
  final GlobalKey _tileKey = GlobalKey();

  static String? _localized(BuildContext context, String? text) =>
      text == null ? null : MadarFormatter.of(context).localizeDigits(text);

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
    final label = task.done ? '${task.title}. ${l.homeTaskDone}' : task.title;
    return ActionableItem(
      key: ValueKey('item-${task.id}'),
      semanticLabel: label,
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
      ),
      child: TaskTile(
        key: _tileKey,
        task: task,
        dragHandle: widget.dragHandle,
        planet: planet,
        planetName: planet == null ? null : (arabic ? planet.nameAr : planet.nameEn),
        // The kit formats with Western digits; follow the user's digit style.
        reminder: rule == null ? null : _localized(context, describeReminder(context, rule)),
      ),
    );
  }
}
