import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../application/prayer_providers.dart';
import '../application/prayer_settings_controller.dart';
import '../domain/prayer_day.dart';
import '../domain/settings_changes.dart';
import 'prayer_labels.dart';
import 'widgets/prayer_widgets.dart';

/// The adjustment key of a moment (null for moments without one).
String? adjustmentKeyOf(PrayerMoment m) => switch (m) {
  PrayerMoment.fajr => PrayerAdjustmentKeys.fajr,
  PrayerMoment.sunrise => PrayerAdjustmentKeys.sunrise,
  PrayerMoment.dhuhr => PrayerAdjustmentKeys.dhuhr,
  PrayerMoment.asr => PrayerAdjustmentKeys.asr,
  PrayerMoment.maghrib => PrayerAdjustmentKeys.maghrib,
  PrayerMoment.isha => PrayerAdjustmentKeys.isha,
  _ => null,
};

/// Long-press on a prayer time: nudge it by minutes to match the mosque,
/// seeing the resulting time live; closing after a change offers undo.
/// [date] is the location date whose time is shown (today when null).
Future<void> showPrayerAdjustmentSheet(BuildContext context, PrayerMoment moment, {DateTime? date}) async {
  final key = adjustmentKeyOf(moment);
  if (key == null) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final before = container.read(prayerSettingsControllerProvider);
  await showInteractionSheet<void>(
    context,
    builder: (_) => _AdjustmentSheet(moment: moment, adjustmentKey: key, date: date),
  );
  if (!context.mounted) return;
  final after = container.read(prayerSettingsControllerProvider);
  if ((after.adjustmentsMin[key] ?? 0) == (before.adjustmentsMin[key] ?? 0)) return;
  final l = L10n.of(context);
  unawaited(
    showUndoToast(
      context,
      UndoableAction(
        label: l.ptAdjusted(l.momentName(moment)),
        undo: () => container.read(prayerSettingsControllerProvider.notifier).restore(before),
      ),
    ),
  );
}

class _AdjustmentSheet extends ConsumerWidget {
  const _AdjustmentSheet({required this.moment, required this.adjustmentKey, this.date});

  final PrayerMoment moment;
  final String adjustmentKey;
  final DateTime? date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final s = ref.watch(prayerSettingsControllerProvider);
    final schedule = ref.watch(prayerLiveScheduleProvider);
    final now = ref.watch(prayerClockProvider)();
    final day = PrayerTimesDay.of(schedule, date ?? schedule.dateOf(now));
    final v = s.adjustmentsMin[adjustmentKey] ?? 0;
    final clock = prayerClockOf(context, s);
    final at = day.timeOf(moment);
    final time = clock.format(schedule.wallClock(at));
    final calculated = clock.format(schedule.wallClock(at.subtract(Duration(minutes: v))));
    final name = l.momentName(moment);
    return InteractionSheetFrame(
      title: l.ptAdjustTitle(name),
      subtitle: l.ptAdjustmentsNote,
      icon: momentIcon(moment),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: Space.s),
          Center(child: PrayerTimeText(time, size: 44, color: t.gold)),
          const SizedBox(height: Space.xxs),
          Text(
            l.ptAdjustCalculated(calculated.joined),
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(color: t.textTertiary),
          ),
          const SizedBox(height: Space.l),
          Center(
            child: ValueStepper(
              value: l.ptMinutesSigned(l.signedMinutes(v, fmt)),
              valueAfter: (d) => l.ptMinutesSigned(l.signedMinutes(v + d, fmt)),
              label: l.ptAdjustTitle(name),
              minWidth: 110,
              canDecrement: v > -PrayerSettingsChanges.maxAdjustment,
              canIncrement: v < PrayerSettingsChanges.maxAdjustment,
              onChanged: (d) => ref.read(prayerSettingsControllerProvider.notifier).setAdjustment(adjustmentKey, v + d),
            ),
          ),
          const SizedBox(height: Space.m),
        ],
      ),
      footer: SheetButton(label: l.ptAdjustDone, primary: true, onPressed: () => Navigator.of(context).pop()),
    );
  }
}
