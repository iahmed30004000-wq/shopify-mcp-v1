import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../home/domain/prayer_day.dart';
import '../../../home/home_providers.dart';
import '../../../home/widgets/task_actions.dart';
import '../../../home/widgets/task_panel.dart';
import '../../domain/neglect_text.dart';
import '../../domain/scene_snapshot.dart';
import '../../domain/score_sources.dart';
import '../../render/astrolabe/astrolabe_geometry.dart';
import '../../render/astrolabe/astrolabe_state.dart';
import '../prayer/prayer_sheet.dart';

/// Faith's own module on its page: today's five prayers on a small dial
/// (lit star-points for the prayed ones, the current time as a hand, the
/// count in the middle) beside the list of them – each opens its prayer
/// sheet – and the wird / adhkar progress when those sources feed the
/// world.
class FaithTodayModule extends ConsumerWidget {
  const FaithTodayModule({super.key, required this.snapshot, required this.planet});

  final SceneSnapshot snapshot;
  final OrbitPlanet planet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final now = ref.watch(homeNowProvider);
    final labels = AstrolabeLabels.of(context);
    final state = AstrolabeState.fromPrayerState(snapshot.prayer, now: now, labels: labels, balance: snapshot.balance);
    final prayers = AstrolabeGeometry.prayers;
    final done = state.prayedCount;
    final summary = l.orbitUiPrayersProgress(fmt.formatInt(done), fmt.formatInt(prayers.length));
    final wird = [
      for (final key in const [ScoreSources.quran, ScoreSources.adhkar])
        if (planet.score.sources[key] case final v?) (label: scoreSourceLabel(l, key), value: v),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: summary,
                excludeSemantics: true,
                child: SizedBox.square(
                  dimension: 112,
                  child: CustomPaint(
                    painter: _PrayerDialPainter(
                      fractions: state.fractions,
                      statuses: {for (final p in prayers) p: state.statusOf(p)},
                      now: PrayerDayTimes.dialFraction(PrayerDayTimes.sinceMidnight(now)),
                      ring: t.brass,
                      lit: planet.palette.glow,
                      due: t.accent,
                      missed: t.danger,
                      dim: t.textTertiary,
                      hand: t.textSecondary,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.l),
                        child: Text(
                          summary,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: text.labelMedium!.copyWith(color: t.textPrimary, height: 1.2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final p in prayers)
                      _PrayerLine(
                        name: labels.prayerName(p),
                        time: labels.time(state.timeOf(p)),
                        status: state.statusOf(p),
                        onTap: () => showPrayerSheet(context, ref, p),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (wird.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            Row(
              children: [
                for (var i = 0; i < wird.length; i++) ...[
                  if (i > 0) const SizedBox(width: Space.m),
                  Expanded(
                    child: GlassCard(
                      glow: false,
                      padding: const EdgeInsetsDirectional.all(Space.m),
                      child: Row(
                        children: [
                          ProgressRing(
                            value: wird[i].value.clamp(0.0, 1.0),
                            size: 40,
                            strokeWidth: 4,
                            color: planet.palette.glow,
                            semanticLabel: l.orbitUiSourceSemantics(wird[i].label, fmt.formatPercent(wird[i].value)),
                            child: Text(
                              fmt.formatPercent(wird[i].value),
                              style: text.labelSmall!.copyWith(color: t.textPrimary, fontSize: 10, height: 1),
                            ),
                          ),
                          const SizedBox(width: Space.s),
                          Expanded(
                            child: Text(
                              wird[i].label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall!.copyWith(color: t.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PrayerLine extends StatelessWidget {
  const _PrayerLine({required this.name, required this.time, required this.status, required this.onTap});

  final String name;
  final String time;
  final AstrolabePrayerStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final (label, color) = switch (status) {
      AstrolabePrayerStatus.prayed => (l.orbitUiPrayerStatusPrayed, t.success),
      AstrolabePrayerStatus.due => (l.orbitUiPrayerStatusDue, t.accent),
      AstrolabePrayerStatus.missed => (l.orbitUiPrayerStatusMissed, t.danger),
      AstrolabePrayerStatus.upcoming => (l.orbitUiPrayerStatusUpcoming, t.textSecondary),
    };
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.sheetOpen,
      semanticLabel: l.orbitUiListSeparator(l.orbitUiListSeparator(name, time), label),
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusS),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium!.copyWith(color: t.textPrimary, height: 1.2),
              ),
            ),
            Text(time, style: text.labelSmall!.copyWith(color: t.textSecondary, height: 1.2)),
            const SizedBox(width: Space.s),
            SizedBox(
              width: 64,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: text.labelSmall!.copyWith(color: color, height: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small 24-hour dial: a brass ring, the five prayers as star-points at
/// their times (lit gold when prayed, an accent ring when due, dim red when
/// missed, outlined when still to come) and the current time as a hand.
class _PrayerDialPainter extends CustomPainter {
  _PrayerDialPainter({
    required this.fractions,
    required this.statuses,
    required this.now,
    required this.ring,
    required this.lit,
    required this.due,
    required this.missed,
    required this.dim,
    required this.hand,
  });

  final Map<Prayer, double> fractions;
  final Map<Prayer, AstrolabePrayerStatus> statuses;
  final double now;
  final Color ring, lit, due, missed, dim, hand;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ring.withValues(alpha: 0.7),
    );
    for (var h = 0; h < 24; h++) {
      final a = AstrolabeGeometry.angleForFraction(h / 24);
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        c + d * (r - (h % 6 == 0 ? 5 : 2.5)),
        c + d * r,
        Paint()
          ..strokeWidth = h % 6 == 0 ? 1.4 : 0.8
          ..color = ring.withValues(alpha: 0.6),
      );
    }
    // the current time
    final an = AstrolabeGeometry.angleForFraction(now);
    canvas.drawLine(
      c + Offset(math.cos(an), math.sin(an)) * (r * 0.62),
      c + Offset(math.cos(an), math.sin(an)) * (r + 3),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = hand,
    );
    for (final e in fractions.entries) {
      final a = AstrolabeGeometry.angleForFraction(e.value);
      final p = c + Offset(math.cos(a), math.sin(a)) * r;
      final status = statuses[e.key] ?? AstrolabePrayerStatus.upcoming;
      final star = _star(p, 6.5, a);
      switch (status) {
        case AstrolabePrayerStatus.prayed:
          canvas
            ..drawCircle(p, 9, Paint()..color = lit.withValues(alpha: 0.25))
            ..drawPath(star, Paint()..color = lit);
        case AstrolabePrayerStatus.due:
          canvas
            ..drawPath(star, Paint()..color = due.withValues(alpha: 0.35))
            ..drawPath(
              star,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = due,
            );
        case AstrolabePrayerStatus.missed:
          canvas.drawPath(
            star,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = missed.withValues(alpha: 0.8),
          );
        case AstrolabePrayerStatus.upcoming:
          canvas.drawPath(
            star,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = dim,
          );
      }
    }
  }

  static Path _star(Offset c, double r, double a) {
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final ang = a + i * math.pi / 8;
      final rr = i.isEven ? r : r * 0.48;
      final p = c + Offset(math.cos(ang), math.sin(ang)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_PrayerDialPainter old) =>
      old.now != now || old.lit != lit || !_sameMap(old.fractions, fractions) || !_sameStatuses(old.statuses, statuses);

  static bool _sameMap(Map<Prayer, double> a, Map<Prayer, double> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  static bool _sameStatuses(Map<Prayer, AstrolabePrayerStatus> a, Map<Prayer, AstrolabePrayerStatus> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}

/// Every world's page: today's tasks attached to it (complete one with a
/// swipe – the world flares behind the page), or a calm line with a way to
/// plan one.
class WorldTasksModule extends ConsumerWidget {
  const WorldTasksModule({super.key, required this.planetKey});

  final String planetKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final tasks = ref.watch(planetTasksTodayProvider(planetKey)).value;
    if (tasks == null) return const SizedBox(height: 48);
    if (tasks.isEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
        child: Row(
          children: [
            Icon(Icons.wb_twilight_rounded, size: 18, color: t.accent),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text(l.orbitUiWorldTasksNone, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            ),
            MadarButton.icon(
              icon: Icons.add_rounded,
              semanticLabel: l.homeAddTask,
              size: MadarButtonSize.small,
              sfx: Sfx.sheetOpen,
              onPressed: () => TaskActions(
                ref,
                context,
              ).add(window: ref.read(homeCurrentWindowProvider), day: ref.read(homeDayProvider), planetKey: planetKey),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final task in tasks)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.s),
            child: TaskItem(key: ValueKey('world-task-${task.id}'), task: task),
          ),
      ],
    );
  }
}
