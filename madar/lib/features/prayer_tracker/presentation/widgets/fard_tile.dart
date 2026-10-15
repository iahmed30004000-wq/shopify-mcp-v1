import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion.dart';
import '../../../orbit/data/orbit_providers.dart' show prayerScheduleProvider;
import '../../domain/tracker_day.dart';
import '../../domain/tracker_prayers.dart';
import '../../domain/tracker_timing.dart';
import '../tracker_actions.dart';
import '../tracker_labels.dart';
import 'status_orb.dart';

/// One obligatory prayer of a day, with its sunnah rātibah grouped under it.
///
/// * Tap → cycles prayed on time → late → missed → no log (undo toast).
/// * Swipe right → prayed on time. Swipe left → late / missed.
/// * Long-press → every status, jamaah, mosque, made up, clear.
/// * The jamaah and mosque marks toggle on their own; the sunnah row
///   toggles the rawatib.
/// * Before its time the row is dimmed and a tap only says "not yet".
class FardPrayerTile extends ConsumerStatefulWidget {
  const FardPrayerTile({super.key, required this.view, required this.prayer});

  final TrackerDayView view;
  final Prayer prayer;

  @override
  ConsumerState<FardPrayerTile> createState() => _FardPrayerTileState();
}

class _FardPrayerTileState extends ConsumerState<FardPrayerTile> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: MadarMotion.medium);

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _notYet() {
    TrackerActions.notYet();
    if (!context.reducedMotion) _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final view = widget.view;
    final prayer = widget.prayer;
    final day = view.day;
    final slot = view[prayer];
    final sunnahPrayer = TrackerPrayers.sunnahOf(prayer);
    final sunnah = sunnahPrayer == null ? null : view[sunnahPrayer];
    final actions = TrackerActions(context, ref);
    final status = slot.status;
    final canLog = slot.canLog;
    final name = l.trackerPrayerName(prayer);
    final clock = TrackerClock.of(context, ref.watch(prayerScheduleProvider));
    final time = clock(slot.window.start);

    final (String statusText, Color statusColor) = switch ((status, slot.timing)) {
      (final PrayerStatus s, _) => (l.trackerStatusName(s), c.status(s)),
      (null, SlotTiming.open) => (l.trackerDueNow(fmt.formatDurationWords(l, slot.window.untilEnd(view.now))), c.due),
      (null, SlotTiming.upcoming) => (
        l.trackerUpcomingIn(fmt.formatDurationWords(l, slot.window.untilStart(view.now))),
        t.textTertiary,
      ),
      (null, SlotTiming.closed) => (l.trackerStatusUnlogged, t.textTertiary),
    };
    final marksEnabled = canLog && status != PrayerStatus.missed;

    final semantic = l.trackerSlotSemantics(name, time, statusText);
    final head = MadarPressable(
      onTap: canLog ? () async => actions.toast(await actions.cycle(day, prayer)) : _notYet,
      sfx: null,
      semanticLabel: semantic,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            StatusOrb(slot: slot),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The time follows the name, or drops under it when a large
                  // text size leaves no room beside it.
                  Wrap(
                    spacing: Space.s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium!.copyWith(
                          color: canLog ? t.textPrimary : t.textSecondary,
                          height: 1.25,
                        ),
                      ),
                      Text(time, maxLines: 1, style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.25)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium!.copyWith(color: statusColor, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final marks = canLog
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MarkToggle(
                icon: TrackerIcons.jamaah,
                label: l.trackerJamaah,
                semanticLabel: l.trackerValueOf(name, l.trackerJamaah),
                value: slot.prayed && slot.inJamaah,
                color: c.jamaah,
                enabled: marksEnabled,
                onChanged: (v) async => actions.toast(await actions.setJamaah(day, prayer, v)),
              ),
              const SizedBox(width: Space.xs),
              _MarkToggle(
                icon: TrackerIcons.mosque,
                label: l.trackerMosque,
                semanticLabel: l.trackerValueOf(name, l.trackerMosque),
                value: slot.prayed && slot.atMosque,
                color: c.mosque,
                enabled: marksEnabled,
                onChanged: (v) async => actions.toast(await actions.setMosque(day, prayer, v)),
              ),
            ],
          )
        : null;

    final prayedGlow = slot.prayed && status == PrayerStatus.prayed;
    // A prayer whose time has not come sits recessed – a fainter hairline,
    // a dimmed orb, secondary ink – but its text keeps full contrast (fading
    // the whole card took the countdown below 3:1 in every theme).
    Widget card = GlassCard(
      // The sunnah row brings its own 48 dp of height (a full tap target).
      padding: EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, sunnah == null ? Space.m : 0),
      glow: prayedGlow,
      glowColor: prayedGlow ? c.onTime.withValues(alpha: 0.35) : null,
      borderColor: switch (status) {
        PrayerStatus.prayed => c.onTime.withValues(alpha: 0.55),
        PrayerStatus.late => c.late.withValues(alpha: 0.45),
        PrayerStatus.qada => c.qada.withValues(alpha: 0.45),
        PrayerStatus.missed => c.missed.withValues(alpha: 0.4),
        null =>
          slot.isDue
              ? c.due.withValues(alpha: 0.55)
              : canLog
              ? null
              : t.glassBorder.withValues(alpha: t.glassBorder.a * 0.5),
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: head),
              ?marks,
            ],
          ),
          if (sunnah != null) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.s),
              child: Divider(height: 1, thickness: 1, color: t.glassBorder.withValues(alpha: 0.5)),
            ),
            SunnahRow(
              slot: sunnah,
              onTap: sunnah.canLog
                  ? () async => actions.toast(await actions.toggleVoluntary(day, sunnah.prayer))
                  : _notYet,
            ),
          ],
        ],
      ),
    );

    card = AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final v = _shake.value;
        if (v == 0 || v == 1) return child!;
        final dx = math.sin(v * math.pi * 5) * 7 * (1 - v);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: card,
    );

    return ActionableItem(
      semanticLabel: name,
      enabled: canLog,
      swipeEnabled: canLog && status != PrayerStatus.prayed,
      onCompleteSwipe: () => actions.setStatus(day, prayer, PrayerStatus.prayed, feedback: false),
      completeIcon: TrackerIcons.prayed,
      completeLabel: l.trackerSwipePrayed,
      quickActions: [
        if (status != PrayerStatus.late)
          QuickAction(
            icon: TrackerIcons.late,
            label: l.trackerStatusLate,
            tone: ActionTone.warning,
            onPressed: () => actions.setStatus(day, prayer, PrayerStatus.late),
          ),
        if (status != PrayerStatus.missed)
          QuickAction(
            icon: TrackerIcons.missed,
            label: l.trackerStatusMissed,
            tone: ActionTone.danger,
            onPressed: () => actions.setStatus(day, prayer, PrayerStatus.missed),
          ),
        if (status == PrayerStatus.missed)
          QuickAction(
            icon: TrackerIcons.qada,
            label: l.trackerActionMadeUp,
            tone: ActionTone.info,
            onPressed: () => actions.makeUp(day, prayer),
          ),
      ],
      actions: ItemActions(extra: fardMenu(actions, l, view, prayer)),
      child: card,
    );
  }
}

/// The long-press menu entries of an obligatory prayer (shared by the rows
/// and the compact card).
List<ItemAction> fardMenu(TrackerActions actions, L10n l, TrackerDayView view, Prayer prayer) {
  final slot = view[prayer];
  final day = view.day;
  final status = slot.status;
  if (!slot.canLog) return const [];
  return [
    if (status != PrayerStatus.prayed)
      ItemAction(
        icon: TrackerIcons.prayed,
        label: l.trackerActionPrayed,
        tone: ActionTone.accent,
        onSelected: () => actions.setStatus(day, prayer, PrayerStatus.prayed),
      ),
    if (status != PrayerStatus.late)
      ItemAction(
        icon: TrackerIcons.late,
        label: l.trackerActionLate,
        tone: ActionTone.warning,
        onSelected: () => actions.setStatus(day, prayer, PrayerStatus.late),
      ),
    if (status != PrayerStatus.missed && status != PrayerStatus.qada)
      ItemAction(
        icon: TrackerIcons.missed,
        label: l.trackerActionMissed,
        tone: ActionTone.danger,
        onSelected: () => actions.setStatus(day, prayer, PrayerStatus.missed),
      ),
    if (status == PrayerStatus.missed)
      ItemAction(
        icon: TrackerIcons.qada,
        label: l.trackerActionMadeUp,
        tone: ActionTone.info,
        onSelected: () => actions.makeUp(day, prayer),
      ),
    if (status != PrayerStatus.missed) ...[
      ItemAction(
        icon: TrackerIcons.jamaah,
        label: slot.inJamaah ? l.trackerActionJamaahOff : l.trackerActionJamaahOn,
        tone: ActionTone.success,
        onSelected: () => actions.setJamaah(day, prayer, !slot.inJamaah),
      ),
      ItemAction(
        icon: TrackerIcons.mosque,
        label: slot.atMosque ? l.trackerActionMosqueOff : l.trackerActionMosqueOn,
        tone: ActionTone.info,
        onSelected: () => actions.setMosque(day, prayer, !slot.atMosque),
      ),
    ],
    if (status != null)
      ItemAction(icon: TrackerIcons.clear, label: l.trackerActionClear, onSelected: () => actions.clear(day, prayer)),
  ];
}

/// A small round toggle with its caption: prayed in jamaah / at the mosque.
class _MarkToggle extends StatelessWidget {
  const _MarkToggle({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.value,
    required this.color,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String label;

  /// Names the prayer too ("العصر: جماعة"): five rows each have one.
  final String semanticLabel;
  final bool value;
  final Color color;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final on = value && enabled;
    final fg = on ? color : t.textTertiary.withValues(alpha: enabled ? 1 : 0.5);
    return MadarPressable(
      onTap: enabled ? () => onChanged(!value) : null,
      enabled: enabled,
      sfx: null,
      toggled: value,
      semanticLabel: semanticLabel,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusS),
      // The label may shrink under large text; the target never does.
      minTapTarget: MadarPressable.minTouchTarget,
      child: SizedBox(
        width: 52,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: context.motion(MadarMotion.short),
              curve: MadarMotion.standard,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? color.withValues(alpha: t.isDark ? 0.2 : 0.14) : Colors.transparent,
                border: Border.all(color: on ? color.withValues(alpha: 0.85) : fg.withValues(alpha: 0.45), width: 1.2),
                boxShadow: on && t.isDark ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)] : null,
              ),
              child: Icon(icon, size: 18, color: fg),
            ),
            const SizedBox(height: 3),
            // Shrinks rather than clips ("Jama…") under large text.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: text.labelSmall!.copyWith(color: on ? color : fg, height: 1.1, fontSize: 10.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sunnah rawatib under their fard: a check that lights gold, the name
/// and how many rak'ahs before / after.
class SunnahRow extends StatelessWidget {
  const SunnahRow({super.key, required this.slot, required this.onTap});

  final TrackerSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final c = TrackerColors.of(context);
    final on = slot.prayed;
    final due = slot.canLog;
    final rakah = l.trackerRakahText(slot.prayer, fmt);
    final title = l.trackerPrayerName(slot.prayer);
    return MadarPressable(
      onTap: onTap,
      sfx: null,
      toggled: on,
      semanticLabel: l.trackerMarks(title, rakah),
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusS),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 11),
        child: ConstrainedBox(
          // Android's 48 dp minimum tap target.
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              AnimatedContainer(
                duration: context.motion(MadarMotion.short),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? c.onTime : Colors.transparent,
                  border: Border.all(
                    color: on ? c.onTime : t.textTertiary.withValues(alpha: due ? 0.7 : 0.4),
                    width: 1.3,
                  ),
                  boxShadow: on && t.isDark ? [BoxShadow(color: c.onTime.withValues(alpha: 0.4), blurRadius: 8)] : null,
                ),
                child: on ? Icon(Icons.check_rounded, size: 16, color: t.space0) : null,
              ),
              const SizedBox(width: Space.m + 11),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: title,
                        style: text.labelLarge!.copyWith(
                          color: on
                              ? c.onTime
                              : due
                              ? t.textPrimary
                              : t.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  ',
                        style: text.bodySmall!.copyWith(color: t.textTertiary),
                      ),
                      TextSpan(
                        text: rakah,
                        style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
