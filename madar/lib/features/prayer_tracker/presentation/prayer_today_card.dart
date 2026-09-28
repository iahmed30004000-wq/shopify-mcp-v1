import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../../orbit/data/orbit_providers.dart' show prayerScheduleProvider;
import '../data/tracker_providers.dart';
import '../domain/tracker_day.dart';
import '../domain/tracker_prayers.dart';
import '../domain/tracker_stats.dart';
import 'charts/segment_ring.dart';
import 'today_view.dart';
import 'tracker_actions.dart';
import 'tracker_labels.dart';
import 'widgets/fard_tile.dart' show fardMenu;
import 'widgets/status_orb.dart';

/// Today's five prayers in one compact glass card (for the Faith planet
/// page): the ring of five with the count, the streak, and the five prayers
/// as orbs – tap one to cycle its status (undo toast), long-press for every
/// option. [onOpen] (e.g. push the tracker route) is offered from the
/// header.
class PrayerTodayCard extends ConsumerStatefulWidget {
  const PrayerTodayCard({super.key, this.onOpen});

  /// Opens the full tracker; the header is not tappable when null.
  final VoidCallback? onOpen;

  @override
  ConsumerState<PrayerTodayCard> createState() => _PrayerTodayCardState();
}

class _PrayerTodayCardState extends ConsumerState<PrayerTodayCard> {
  final GlobalKey _ringKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<TrackerDayView>>(trackerTodayViewProvider, (previous, next) {
      final now = next.value;
      if (now == null || !becameComplete(previous?.value, now)) return;
      final ring = _ringKey.currentContext;
      if (ring != null) celebrateCompletion(ring);
    });
    final view = ref.watch(trackerTodayViewProvider).value;
    final streaks = ref.watch(trackerHistoryProvider).value?.streaks ?? TrackerStreaks.zero;
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    if (view == null) {
      return const GlassCard(
        child: SizedBox(height: 120, child: Center(child: OrbitLoader(size: 32))),
      );
    }
    final done = view.prayedCount;
    final total = TrackerPrayers.obligatory.length;
    final progress = l.trackerProgress(fmt.formatInt(done), fmt.formatInt(total));
    final actions = TrackerActions(context, ref);
    final clock = TrackerClock.of(context, ref.watch(prayerScheduleProvider));

    final header = Row(
      children: [
        Semantics(
          label: progress,
          excludeSemantics: true,
          child: SegmentRing(
            key: _ringKey,
            segments: RingSegment.ofDay(view, c),
            size: 48,
            strokeWidth: 4.5,
            complete: view.complete,
            child: Text(
              fmt.formatInt(done),
              style: text.titleMedium!.copyWith(color: view.complete ? c.onTime : t.textPrimary, height: 1),
            ),
          ),
        ),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.trackerTodayPrayed, style: text.titleMedium!.copyWith(color: t.textPrimary, height: 1.25)),
              Text(
                view.complete ? l.trackerAllDone : progress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: view.complete ? c.onTime : t.textSecondary),
              ),
            ],
          ),
        ),
        TrackerPill(
          icon: TrackerIcons.streak,
          label: fmt.formatInt(streaks.current),
          color: streaks.current > 0 ? c.onTime : t.textTertiary,
        ),
        if (widget.onOpen != null) ...[
          const SizedBox(width: Space.xs),
          // "Forward": chevron_right mirrors itself in RTL (matchTextDirection)
          // and points left in Arabic.
          Icon(Icons.chevron_right_rounded, color: t.textSecondary),
        ],
      ],
    );

    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      glow: view.complete,
      glowColor: view.complete ? c.onTime.withValues(alpha: 0.35) : null,
      borderColor: view.complete ? c.onTime.withValues(alpha: 0.55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.onOpen != null)
            MadarPressable(
              onTap: widget.onOpen,
              sfx: Sfx.navigate,
              semanticLabel: l.trackerMarks(progress, l.trackerCardOpen),
              focusRadius: BorderRadius.circular(t.radiusS),
              child: header,
            )
          else
            header,
          const SizedBox(height: Space.m),
          Row(
            children: [
              for (final p in TrackerPrayers.obligatory)
                Expanded(
                  child: _CardPrayer(view: view, prayer: p, actions: actions, clock: clock),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardPrayer extends StatelessWidget {
  const _CardPrayer({required this.view, required this.prayer, required this.actions, required this.clock});

  final TrackerDayView view;
  final Prayer prayer;
  final TrackerActions actions;
  final TrackerClock clock;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final slot = view[prayer];
    final name = l.trackerPrayerName(prayer);
    final time = clock(slot.window.start);
    final status = l.trackerSlotStatus(slot);
    return ActionableItem(
      enabled: slot.canLog,
      swipeEnabled: false,
      actions: ItemActions(extra: fardMenu(actions, l, view, prayer)),
      borderRadius: BorderRadius.circular(t.radiusS),
      child: MadarPressable(
        onTap: slot.canLog ? () async => actions.toast(await actions.cycle(view.day, prayer)) : TrackerActions.notYet,
        sfx: null,
        semanticLabel: l.trackerSlotSemantics(name, time, status),
        excludeChildSemantics: true,
        focusRadius: BorderRadius.circular(t.radiusS),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatusOrb(slot: slot, size: 40),
              const SizedBox(height: Space.xs),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium!.copyWith(color: slot.canLog ? t.textPrimary : t.textTertiary, height: 1.2),
              ),
              Text(
                time,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelSmall!.copyWith(color: t.textTertiary, height: 1.2, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
