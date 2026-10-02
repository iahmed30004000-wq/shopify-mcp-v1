import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../orbit/data/orbit_providers.dart' show prayerScheduleProvider;
import '../../domain/tracker_day.dart';
import '../../domain/tracker_timing.dart';
import '../tracker_actions.dart';
import '../tracker_labels.dart';

/// Duha, Witr and the night prayer as three glass tiles that light up in
/// gold when prayed. A tap toggles (with undo); before its time a tile is
/// dimmed and shows when it opens.
class NaflTiles extends ConsumerWidget {
  const NaflTiles({super.key, required this.view});

  final TrackerDayView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = TrackerActions(context, ref);
    final clock = TrackerClock.of(context, ref.watch(prayerScheduleProvider));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, slot) in view.nawafil.indexed) ...[
            if (i > 0) const SizedBox(width: Space.s),
            Expanded(
              child: NaflTile(
                slot: slot,
                now: view.now,
                clock: clock,
                onTap: slot.canLog
                    ? () async => actions.toast(await actions.toggleVoluntary(view.day, slot.prayer))
                    : TrackerActions.notYet,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NaflTile extends StatelessWidget {
  const NaflTile({super.key, required this.slot, required this.now, required this.clock, required this.onTap});

  final TrackerSlot slot;
  final DateTime now;

  /// Formats the time the tile's window closes.
  final TrackerClock clock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final on = slot.prayed;
    final name = l.trackerPrayerName(slot.prayer);
    final String hint;
    if (on) {
      hint = l.trackerStatusVoluntaryDone;
    } else {
      hint = switch (slot.timing) {
        SlotTiming.upcoming => l.trackerUpcomingIn(fmt.formatDurationWords(l, slot.window.untilStart(now))),
        SlotTiming.open => l.trackerUntil(clock(slot.window.end)),
        // Its time has passed: "not logged" (it can still be logged late).
        SlotTiming.closed => l.trackerStatusUnlogged,
      };
    }
    // Not yet due: the tile sits recessed (fainter glass, a dimmed icon) but
    // its words keep full contrast.
    final dim = !slot.canLog;
    return MadarPressable(
      onTap: onTap,
      sfx: null,
      toggled: on,
      semanticLabel: l.trackerMarks(name, hint),
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.medium),
        curve: MadarMotion.standard,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.s, Space.m),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: on
                ? [
                    c.onTime.withValues(alpha: t.isDark ? 0.28 : 0.22),
                    c.onTime.withValues(alpha: t.isDark ? 0.08 : 0.06),
                  ]
                : [
                    t.glassFill.withValues(alpha: t.glassFill.a * (dim ? 0.6 : 1)),
                    t.glassFill.withValues(alpha: t.glassFill.a * (dim ? 0.3 : 0.6)),
                  ],
          ),
          border: Border.all(
            color: on
                ? c.onTime.withValues(alpha: 0.7)
                : t.glassBorder.withValues(alpha: t.glassBorder.a * (dim ? 0.55 : 1)),
            width: on ? 1.2 : 1,
          ),
          boxShadow: on && t.isDark ? [BoxShadow(color: c.onTime.withValues(alpha: 0.22), blurRadius: 16)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: context.motion(MadarMotion.medium),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? c.onTime : t.textTertiary.withValues(alpha: dim ? 0.06 : 0.1),
                boxShadow: on && t.isDark ? [BoxShadow(color: c.onTime.withValues(alpha: 0.5), blurRadius: 12)] : null,
              ),
              child: Icon(
                on ? Icons.check_rounded : TrackerIcons.of(slot.prayer),
                size: 20,
                color: on ? t.space0 : (dim ? t.textTertiary.withValues(alpha: 0.7) : t.textSecondary),
              ),
            ),
            const SizedBox(height: Space.s),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.labelLarge!.copyWith(
                color: on
                    ? c.onTime
                    : dim
                    ? t.textSecondary
                    : t.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.labelSmall!.copyWith(color: on ? c.onTime : t.textTertiary, height: 1.25),
            ),
          ],
        ),
      ),
    );
  }
}
