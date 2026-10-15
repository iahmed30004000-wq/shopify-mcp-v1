import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/adhkar_providers.dart';
import '../domain/adhkar_models.dart';
import '../domain/adhkar_reminders.dart';
import '../domain/adhkar_session.dart';
import '../domain/tasbeeh.dart';
import 'adhkar_labels.dart';
import 'adhkar_navigation.dart';
import 'widgets/tasbeeh_ring.dart';

/// The adhkar home: today's progress with the set that fits the moment,
/// the five sets (tap to read; swipe or long-press to mark done or start
/// over, with undo), the tasbeeh, and the morning / evening reminders.
///
/// [onOpenSet] and [onOpenTasbeeh] let the host route; by default the
/// screens are pushed with [AdhkarNavigation].
class AdhkarHomeScreen extends ConsumerWidget {
  const AdhkarHomeScreen({super.key, this.onOpenSet, this.onOpenTasbeeh});

  final AdhkarOpenSet? onOpenSet;
  final AdhkarOpenScreen? onOpenTasbeeh;

  void _open(BuildContext context, AdhkarCategoryId c, Prayer? prayer) => onOpenSet != null
      ? onOpenSet!(context, c, prayer)
      : unawaited(AdhkarNavigation.openSet(context, c, prayer: prayer));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final summary = ref.watch(adhkarDaySummaryProvider);
    final library = ref.watch(adhkarLibraryProvider).value;
    return MadarScaffold(
      title: l.adhkarTitle,
      body: switch ((summary, library)) {
        (AsyncData(:final value), final AdhkarLibrary lib) => EntranceChoreo(
          id: 'adhkar-home',
          child: ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxl),
            children: [
              StaggerItem(
                index: 0,
                child: _Hero(summary: value, onOpen: (c, p) => _open(context, c, p)),
              ),
              const SizedBox(height: Space.l),
              for (final (i, c) in lib.categories.indexed)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.m),
                  child: StaggerItem(
                    index: i + 1,
                    child: _SetCard(category: c, summary: value, onOpen: (p) => _open(context, c.id, p)),
                  ),
                ),
              const SizedBox(height: Space.s),
              StaggerItem(
                index: 7,
                child: _TasbeehCard(
                  onOpen: () => onOpenTasbeeh != null
                      ? onOpenTasbeeh!(context)
                      : unawaited(AdhkarNavigation.openTasbeeh(context)),
                ),
              ),
              StaggerItem(
                index: 8,
                child: SectionHeader(
                  title: l.adhkarRemindersTitle,
                  padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
                ),
              ),
              const StaggerItem(index: 9, child: _RemindersCard()),
              const SizedBox(height: Space.xl),
              StaggerItem(
                index: 10,
                child: Text(
                  l.adhkarSourceCredit,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(color: context.tokens.textTertiary),
                ),
              ),
            ],
          ),
        ),
        (AsyncError(), _) => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.adhkarLoadError, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.summary, required this.onOpen});

  final AdhkarDaySummary summary;
  final void Function(AdhkarCategoryId category, Prayer? prayer) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final total = AdhkarCategoryId.values.length;
    final done = summary.setsDone;
    final all = done == total;
    final suggested = summary.suggested;
    final prayer = summary.suggestedPrayer;
    final suggestedDone = summary.suggestedDone;
    final started = summary.started.contains(suggested) && !suggestedDone;
    final line = l.adhkarMoment(summary);
    final calm = all || suggestedDone;
    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      glowColor: t.accentGlow,
      child: Row(
        children: [
          ProgressRing(
            value: done / total,
            size: 104,
            strokeWidth: 8,
            color: all ? t.success : t.accent,
            semanticLabel: l.adhkarTodayTitle,
            semanticValue: l.adhkarSetsDoneOf(fmt.formatInt(done), fmt.formatInt(total)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${fmt.formatInt(done)}/${fmt.formatInt(total)}',
                  textDirection: TextDirection.ltr,
                  style: MadarTypography.numerals(t, size: 24).copyWith(fontWeight: FontWeight.w600, height: 1.1),
                ),
                Text(l.adhkarSetsDoneCaption, style: text.labelSmall),
              ],
            ),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.adhkarTodayTitle, style: text.headlineSmall),
                const SizedBox(height: Space.xs),
                Row(
                  children: [
                    Icon(
                      all
                          ? Icons.auto_awesome_rounded
                          : suggestedDone
                          ? Icons.check_circle_rounded
                          : adhkarCategoryIcon(suggested),
                      size: 16,
                      color: calm ? t.success : t.accent,
                    ),
                    const SizedBox(width: Space.xs),
                    Expanded(
                      child: Text(line, style: text.bodyMedium!.copyWith(color: calm ? t.success : t.accent)),
                    ),
                  ],
                ),
                if (!calm) ...[
                  const SizedBox(height: Space.m),
                  MadarButton(
                    label: started ? l.adhkarContinue : l.adhkarStart,
                    icon: Icons.menu_book_rounded,
                    size: MadarButtonSize.small,
                    sfx: Sfx.navigate,
                    onPressed: () => onOpen(suggested, suggested == AdhkarCategoryId.afterPrayer ? prayer : null),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetCard extends ConsumerWidget {
  const _SetCard({required this.category, required this.summary, required this.onOpen});

  final AdhkarCategory category;
  final AdhkarDaySummary summary;
  final ValueChanged<Prayer?> onOpen;

  AdhkarSetKey get _key =>
      AdhkarSetKey(category.id, category.id == AdhkarCategoryId.afterPrayer ? summary.suggestedPrayer : null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = category.id;
    final afterPrayer = c == AdhkarCategoryId.afterPrayer;
    final progress = summary.progress[c] ?? 0;
    final done = summary.isDone(c);
    final suggested = summary.suggested == c && !summary.suggestedDone;
    final name = l.adhkarCategoryName(c);
    final prayer = afterPrayer ? summary.suggestedPrayer : null;
    final String meta;
    // Before any is said, the after-prayer card counts its adhkar like the
    // others (a lone «٠ من ٥» reads as a stray dot).
    if (afterPrayer && summary.afterPrayerDone.isNotEmpty) {
      meta = l.adhkarAfterPrayerProgress(
        fmt.formatInt(summary.afterPrayerDone.length),
        fmt.formatInt(kObligatoryPrayers.length),
      );
    } else if (done) {
      meta = l.adhkarDoneToday;
    } else if (summary.resumeIndex[c] case final int position?) {
      meta = l.adhkarContinueAt(fmt.formatInt(position));
    } else {
      meta = fmt.localizeDigits(l.adhkarItemsCount(category.items.length));
    }
    final service = ref.read(adhkarSetServiceProvider);
    Future<UndoableAction?> markDone() async {
      Fx.fire(Sfx.complete);
      final undo = await service.markDone(_key);
      return UndoableAction(label: l.adhkarMarkedDone(name), undo: undo);
    }

    Future<UndoableAction?> restart() async {
      final undo = await service.restart(_key);
      return UndoableAction(label: l.adhkarRestarted(name), undo: undo);
    }

    return ActionableItem(
      semanticLabel: '$name, $meta',
      onTap: () => onOpen(prayer),
      completeIcon: Icons.done_all_rounded,
      completeLabel: l.adhkarMarkDone,
      onCompleteSwipe: done && !afterPrayer ? null : markDone,
      borderRadius: BorderRadius.circular(t.radiusL),
      actions: ItemActions(
        extra: [
          ItemAction(
            icon: Icons.done_all_rounded,
            label: l.adhkarMarkDone,
            tone: ActionTone.success,
            enabled: !done || afterPrayer,
            onSelected: markDone,
          ),
          ItemAction(icon: Icons.restart_alt_rounded, label: l.adhkarRestart, onSelected: restart),
        ],
      ),
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        glow: suggested,
        glowColor: t.accentGlow,
        borderColor: suggested ? t.accent.withValues(alpha: 0.55) : null,
        seed: c.index * 0.17,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [t.accentSoft, t.accentSoft.withValues(alpha: 0)],
                  stops: const [0.55, 1],
                ),
                border: Border.all(color: t.accent.withValues(alpha: 0.45)),
              ),
              child: Icon(adhkarCategoryIcon(c), color: t.accent, size: 24),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: text.titleMedium),
                  Text(l.adhkarCategoryHint(c), style: text.bodySmall),
                  const SizedBox(height: Space.xxs),
                  Row(
                    children: [
                      if (done) ...[
                        Icon(Icons.check_circle_rounded, size: 14, color: t.success),
                        const SizedBox(width: Space.xxs),
                      ],
                      Flexible(
                        child: Text(
                          meta,
                          style: text.labelMedium!.copyWith(
                            color: done ? t.success : (suggested ? t.accent : t.textSecondary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            ProgressRing(
              value: progress,
              size: 46,
              strokeWidth: 4.5,
              color: done ? t.success : t.accent,
              glow: progress > 0,
              child: done
                  ? Icon(Icons.check_rounded, size: 20, color: t.success)
                  : progress <= 0
                  ? const SizedBox.shrink()
                  : Text(
                      fmt.formatPercent(progress),
                      style: text.labelSmall!.copyWith(color: t.textSecondary, fontSize: 10),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TasbeehCard extends ConsumerWidget {
  const _TasbeehCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(tasbeehTodayCountProvider);
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () {
        Fx.fire(Sfx.navigate);
        onOpen();
      },
      semanticLabel: l.adhkarTasbeehTitle,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
      child: Row(
        children: [
          const IgnorePointer(child: TasbeehBeadRing(counter: TasbeehCounter(target: 33, count: 11), size: 76)),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.adhkarTasbeehTitle, style: text.titleMedium),
                Text(l.adhkarTasbeehCardSubtitle, style: text.bodySmall),
                // A bare "Today: 0" reads as a stray dot in Arabic (٠).
                if (today > 0) ...[
                  const SizedBox(height: Space.xxs),
                  Text(l.adhkarTasbeehToday(fmt.formatInt(today)), style: text.labelMedium!.copyWith(color: t.accent)),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textTertiary),
        ],
      ),
    );
  }
}

class _RemindersCard extends ConsumerStatefulWidget {
  const _RemindersCard();

  @override
  ConsumerState<_RemindersCard> createState() => _RemindersCardState();
}

class _RemindersCardState extends ConsumerState<_RemindersCard> {
  /// Notifications were refused when a reminder was switched on.
  bool _denied = false;

  Future<void> _save(AdhkarReminderSettings next, AdhkarReminderSettings before, L10n l) async {
    final service = ref.read(adhkarReminderServiceProvider);
    final turningOn = (next.morning && !before.morning) || (next.evening && !before.evening);
    if (turningOn) {
      // Android 13+: the system asks once; a refusal keeps the choice saved
      // and says why nothing will arrive.
      final allowed = await service.ensurePermission();
      if (!allowed) Fx.fire(Sfx.notify);
      if (mounted) setState(() => _denied = !allowed);
    } else if (!next.anyEnabled && mounted) {
      setState(() => _denied = false);
    }
    await service.update(next, l);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(adhkarReminderSettingsProvider).value ?? const AdhkarReminderSettings();
    void save(AdhkarReminderSettings s) => unawaited(_save(s, settings, l));
    Widget row(IconData icon, String label, bool value, ValueChanged<bool> onChanged) => Row(
      children: [
        Icon(icon, size: 20, color: t.accent),
        const SizedBox(width: Space.m),
        Expanded(child: Text(label, style: text.bodyLarge)),
        MadarSwitch(value: value, onChanged: onChanged, semanticLabel: label),
      ],
    );
    Widget offsets(int value, ValueChanged<int> onChanged) => Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.s, start: Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.adhkarReminderOffsetCaption, style: text.labelMedium!.copyWith(color: t.textTertiary)),
          const SizedBox(height: Space.xs),
          ChoicePills<int>.single(
            options: [
              for (final m in AdhkarReminderSettings.offsets)
                ChoiceOption(value: m, label: fmt.localizeDigits(l.adhkarReminderOffset(m))),
            ],
            selected: value,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            dense: true,
          ),
        ],
      ),
    );
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      glow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            Icons.wb_sunny_rounded,
            l.adhkarReminderMorningLabel,
            settings.morning,
            (v) => save(settings.copyWith(morning: v)),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            alignment: AlignmentDirectional.topStart,
            child: settings.morning
                ? offsets(settings.morningOffsetMin, (m) => save(settings.copyWith(morningOffsetMin: m)))
                : const SizedBox(width: double.infinity),
          ),
          const MadarDivider(ornament: false, height: 24),
          row(
            Icons.nights_stay_rounded,
            l.adhkarReminderEveningLabel,
            settings.evening,
            (v) => save(settings.copyWith(evening: v)),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            alignment: AlignmentDirectional.topStart,
            child: settings.evening
                ? offsets(settings.eveningOffsetMin, (m) => save(settings.copyWith(eveningOffsetMin: m)))
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: Space.m),
          if (_denied && settings.anyEnabled)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 2),
                    child: Icon(Icons.notifications_off_rounded, size: 18, color: t.warning),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      l.adhkarReminderPermissionDenied,
                      style: text.bodySmall!.copyWith(color: t.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          Text(l.adhkarReminderNote, style: text.bodySmall!.copyWith(color: t.textTertiary)),
        ],
      ),
    );
  }
}
