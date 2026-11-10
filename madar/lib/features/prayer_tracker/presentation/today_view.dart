import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/tracker_providers.dart';
import '../domain/tracker_day.dart';
import '../domain/tracker_days.dart';
import '../domain/tracker_prayers.dart';
import '../domain/tracker_stats.dart';
import 'charts/segment_ring.dart';
import 'tracker_actions.dart';
import 'tracker_labels.dart';
import 'widgets/fard_tile.dart';
import 'widgets/nafl_tiles.dart';

/// Celebrates the moment all five prayers of a day are prayed: an orbital
/// ring of light around [ringKey]'s widget, a stardust burst and the
/// level-up chime. Fires only on the transition (never on first build or
/// when another day is shown).
void celebrateCompletion(BuildContext ringContext) {
  Celebrate.burstFrom(ringContext, kind: CelebrationKind.orbitalRing, sfx: Sfx.levelUp);
  Celebrate.burstFrom(ringContext, kind: CelebrationKind.stardust, intensity: 0.8);
}

/// Whether [next] is the moment [previous]'s day became complete.
bool becameComplete(TrackerDayView? previous, TrackerDayView next) =>
    previous != null && TrackerDays.sameDay(previous.day, next.day) && !previous.complete && next.complete;

/// The Today tab: a header with the day's ring of five, the next prayer and
/// the streak; the five obligatory prayers with their rawatib; Duha, Witr
/// and the night prayer.
class TrackerTodayView extends ConsumerStatefulWidget {
  const TrackerTodayView({
    super.key,
    this.padding = const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
  });

  final EdgeInsetsGeometry padding;

  @override
  ConsumerState<TrackerTodayView> createState() => _TrackerTodayViewState();
}

class _TrackerTodayViewState extends ConsumerState<TrackerTodayView> {
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
    final history = ref.watch(trackerHistoryProvider).value;
    if (view == null) {
      return const Center(child: OrbitLoader(size: 40));
    }
    final l = L10n.of(context);
    return ListView(
      padding: widget.padding,
      children: [
        StaggerItem(
          index: 0,
          child: TodayHeader(view: view, streaks: history?.streaks ?? TrackerStreaks.zero, ringKey: _ringKey),
        ),
        SectionHeader(
          title: l.trackerObligatory,
          subtitle: l.trackerObligatoryHint,
          padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
        ),
        for (final (i, p) in TrackerPrayers.obligatory.indexed)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Space.s),
            child: StaggerItem(
              index: i + 1,
              child: FardPrayerTile(key: ValueKey(p), view: view, prayer: p),
            ),
          ),
        SectionHeader(
          title: l.trackerVoluntary,
          padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.m),
        ),
        StaggerItem(index: 7, child: NaflTiles(view: view)),
      ],
    );
  }
}

/// The day at a glance: the ring of five (gold arcs for the prayers prayed),
/// the date, the next prayer's countdown, the streak and today's jamaah.
class TodayHeader extends StatelessWidget {
  const TodayHeader({super.key, required this.view, required this.streaks, this.ringKey});

  final TrackerDayView view;
  final TrackerStreaks streaks;
  final GlobalKey? ringKey;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final done = view.prayedCount;
    final total = TrackerPrayers.obligatory.length;
    final next = view.nextUpcoming;
    final complete = view.complete;

    final String line;
    if (complete) {
      line = l.trackerAllDone;
    } else if (next != null) {
      line = l.trackerNextIn(
        l.trackerPrayerName(next.prayer),
        fmt.formatDurationWords(l, next.window.untilStart(view.now)),
      );
    } else {
      line = l.trackerNightLeft;
    }

    return GlassCard(
      padding: const EdgeInsetsDirectional.all(Space.l),
      glow: complete,
      glowColor: complete ? c.onTime.withValues(alpha: 0.4) : null,
      borderColor: complete ? c.onTime.withValues(alpha: 0.6) : null,
      child: Row(
        children: [
          Semantics(
            label: l.trackerProgress(fmt.formatInt(done), fmt.formatInt(total)),
            excludeSemantics: true,
            child: KeyedSubtree(
              key: ringKey,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: context.motion(MadarMotion.long),
                curve: MadarMotion.decelerate,
                builder: (context, sweep, _) => SizedBox.square(
                  dimension: 112,
                  child: CustomPaint(
                    painter: SegmentRingPainter(
                      segments: RingSegment.ofDay(view, c),
                      track: t.textTertiary.withValues(alpha: t.isDark ? 0.2 : 0.18),
                      glowColor: c.onTime,
                      strokeWidth: 9,
                      gapDegrees: 8,
                      sweep: sweep,
                      complete: complete,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fmt.formatInt(done),
                            style: text.displaySmall!.copyWith(
                              color: complete ? c.onTime : t.textPrimary,
                              height: 1.0,
                              fontSize: 34,
                            ),
                          ),
                          Text(
                            l.trackerOfTotal(fmt.formatInt(total)),
                            style: text.labelMedium!.copyWith(color: t.textSecondary, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fmt.formatDate(view.day, style: MadarDateStyle.weekdayDayMonth),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium!.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  l.trackerTodayPrayed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall!.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium!.copyWith(color: complete ? c.onTime : t.textSecondary, height: 1.35),
                ),
                const SizedBox(height: Space.m),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.xs,
                  children: [
                    TrackerPill(
                      icon: TrackerIcons.streak,
                      label: fmt.localizeDigits(l.trackerStreakChip(streaks.current)),
                      color: streaks.current > 0 ? c.onTime : t.textTertiary,
                    ),
                    if (view.jamaahCount > 0)
                      TrackerPill(
                        icon: TrackerIcons.jamaah,
                        label: l.trackerJamaahCount(fmt.formatInt(view.jamaahCount)),
                        color: c.jamaah,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tinted capsule with an icon (streak, jamaah count …).
class TrackerPill extends StatelessWidget {
  const TrackerPill({super.key, required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: color.withValues(alpha: t.isDark ? 0.14 : 0.1),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.s, 3, Space.m, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: Space.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium!.copyWith(color: color, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
