import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/orbit_providers.dart';
import '../../render/astrolabe/astrolabe_geometry.dart';
import 'prayer_log_service.dart';

/// What the prayer sheet asks for.
enum PrayerChoice { prayed, late, missed, clear }

/// The prayer log service of the running app.
final prayerLogServiceProvider = Provider<PrayerLogService>(
  (ref) => PrayerLogService(
    ref.watch(repositoriesProvider),
    hub: ref.watch(orbitPulseHubProvider),
    clock: ref.watch(orbitClockProvider),
  ),
);

/// Tap on a prayer pointer of the astrolabe: log it as prayed (its pointer
/// ignites with golden fire and the Faith world pulses), prayed late,
/// missed, or clear the log – with undo.
Future<void> showPrayerSheet(BuildContext context, WidgetRef ref, Prayer prayer) async {
  final schedule = ref.read(prayerScheduleProvider);
  final now = ref.read(orbitClockProvider)();
  final day = schedule.prayerDayOf(now);
  final at = AstrolabeGeometry.timeOf(prayer, schedule.timesFor(day));
  final service = ref.read(prayerLogServiceProvider);
  final existing = await service.logOf(day, prayer);
  if (!context.mounted) return;
  final choice = await showInteractionSheet<PrayerChoice>(
    context,
    builder: (sheetContext) => _PrayerSheet(
      prayer: prayer,
      at: at,
      upcoming: at.isAfter(now),
      current: existing?.status,
      loggedAt: PrayerLogService.plausibleLoggedAt(existing?.loggedAt, at),
    ),
  );
  if (choice == null || !context.mounted) return;
  final l = L10n.of(context);
  final name = _prayerName(l, prayer);
  final PrayerUndo undo;
  final String label;
  switch (choice) {
    case PrayerChoice.clear:
      undo = await service.clear(day, prayer);
      label = l.orbitUiPrayerCleared(name);
      Fx.fire(Sfx.toggleOff);
    case PrayerChoice.prayed || PrayerChoice.late || PrayerChoice.missed:
      final status = switch (choice) {
        PrayerChoice.prayed => PrayerStatus.prayed,
        PrayerChoice.late => PrayerStatus.late,
        _ => PrayerStatus.missed,
      };
      undo = await service.log(day, prayer, status);
      label = l.orbitUiPrayerLogged(name);
  }
  if (!context.mounted) return;
  unawaited(showUndoToast(context, UndoableAction(label: label, undo: undo)));
}

String _prayerName(L10n l, Prayer p) => switch (p) {
  Prayer.fajr => l.prayerFajr,
  Prayer.dhuhr => l.prayerDhuhr,
  Prayer.asr => l.prayerAsr,
  Prayer.maghrib => l.prayerMaghrib,
  Prayer.isha => l.prayerIsha,
  _ => l.prayerSunrise,
};

class _PrayerSheet extends StatelessWidget {
  const _PrayerSheet({
    required this.prayer,
    required this.at,
    required this.upcoming,
    required this.current,
    this.loggedAt,
  });

  final Prayer prayer;
  final DateTime at;
  final bool upcoming;
  final PrayerStatus? current;

  /// When it was logged (only a believable time – see
  /// [PrayerLogService.plausibleLoggedAt]).
  final DateTime? loggedAt;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    void pick(PrayerChoice c) => Navigator.of(context).pop(c);
    return InteractionSheetFrame(
      title: _prayerName(l, prayer),
      subtitle: l.orbitUiPrayerAt(fmt.formatTime(at)),
      icon: Icons.mosque_outlined,
      body: upcoming
          ? Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.l),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: t.accent, size: 20),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(l.orbitUiPrayerNotYet, style: text.bodyLarge!.copyWith(color: t.textSecondary)),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Already prayed: the achievement in gold, not a greyed-out
                // button.
                if (current == PrayerStatus.prayed || current == PrayerStatus.late)
                  _Prayed(
                    label: switch ((current == PrayerStatus.late, loggedAt)) {
                      (true, final DateTime t) => l.orbitUiPrayerLateAt(fmt.formatTime(t)),
                      (true, null) => l.orbitUiPrayerLateDone,
                      (false, final DateTime t) => l.orbitUiPrayerPrayedAt(fmt.formatTime(t)),
                      (false, null) => l.orbitUiPrayerDone,
                    },
                  )
                else
                  SheetButton(
                    label: l.orbitUiPrayerPrayed,
                    icon: Icons.local_fire_department_rounded,
                    primary: true,
                    sfx: null,
                    onPressed: () => pick(PrayerChoice.prayed),
                  ),
                if (current == PrayerStatus.late) ...[
                  const SizedBox(height: Space.s),
                  SheetButton(
                    label: l.orbitUiPrayerPrayed,
                    icon: Icons.local_fire_department_rounded,
                    sfx: null,
                    onPressed: () => pick(PrayerChoice.prayed),
                  ),
                ],
                const SizedBox(height: Space.s),
                if (current != PrayerStatus.late)
                  SheetButton(
                    label: l.orbitUiPrayerLate,
                    icon: Icons.history_rounded,
                    onPressed: () => pick(PrayerChoice.late),
                  ),
                const SizedBox(height: Space.s),
                SheetButton(
                  label: l.orbitUiPrayerMissed,
                  icon: Icons.nights_stay_outlined,
                  tone: t.warning,
                  enabled: current != PrayerStatus.missed,
                  onPressed: () => pick(PrayerChoice.missed),
                ),
                if (current != null) ...[
                  const SizedBox(height: Space.s),
                  SheetButton(
                    label: l.orbitUiPrayerClear,
                    icon: Icons.undo_rounded,
                    tone: t.textSecondary,
                    onPressed: () => pick(PrayerChoice.clear),
                  ),
                ],
              ],
            ),
    );
  }
}

/// A logged prayer: a lit flame, the time it was prayed and a check, in
/// gold – the achieved state.
class _Prayed extends StatelessWidget {
  const _Prayed({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [t.gold.withValues(alpha: 0.26), t.gold.withValues(alpha: 0.1)],
          ),
          border: Border.all(color: t.gold.withValues(alpha: 0.7), width: 1),
          boxShadow: [BoxShadow(color: t.gold.withValues(alpha: 0.25), blurRadius: 18)],
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.m),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                color: t.gold,
                size: 22,
                shadows: [Shadow(color: t.warning.withValues(alpha: 0.8), blurRadius: 12)],
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(label, style: text.titleMedium!.copyWith(color: t.gold, height: 1.2)),
              ),
              Icon(Icons.check_circle_rounded, color: t.gold, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
