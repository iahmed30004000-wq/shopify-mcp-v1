import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../orbit/data/orbit_providers.dart' show orbitTodayProvider;
import '../../prayer/application/prayer_settings_controller.dart' show prayerSettingsControllerProvider;
import '../../prayer/presentation/prayer_labels.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../../wird/domain/calendar_days.dart';
import '../application/fasting_providers.dart';
import '../domain/fasting_log.dart';
import '../domain/fasting_models.dart';
import '../domain/fasting_overview.dart';
import '../domain/fasting_rules.dart';

/// «صيامي»: the voluntary fasts in one place (Part 9b).
///
/// * the **coming reminders** (the next ten, in both calendars, with the
///   kind and what he answered);
/// * the **log** of the days he fasted - this Hijri month and year, the six
///   of Shawwal as "n of 6", the white days on their own - logged by hand
///   with «سجّل صيام اليوم» and removable;
/// * the **settings**: the three groups of reminders and the Muharram /
///   Sha'ban nudge, the Hijri day shift (the prayer settings' own setting),
///   and the first of the six of Shawwal.
///
/// Every write shows an undo toast. Route widget: `/faith/fasting`.
class FastingScreen extends ConsumerWidget {
  const FastingScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final battery = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    // Watching the sync keeps the reminders planned while this screen is
    // open (the app shell watches it too).
    ref.watch(fastingSyncProvider);
    return MadarScaffold(
      title: l.fastRemTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: animateBackdrop && !battery,
      backdropSeed: 0.63,
      body: SettingsListView(
        children: [
          StaggerIn(
            id: 'fasting-screen',
            fade: false,
            children: const [
              SizedBox(height: Space.s),
              _ConfirmSection(),
              _UpcomingSection(),
              _LogSection(),
              _SettingsSection(),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows the undo toast of a change that was just written.
void _undoToast(BuildContext context, String label, FastingUndo undo) {
  if (!context.mounted) return;
  unawaited(showUndoToast(context, UndoableAction(label: label, undo: undo)));
}

// ---------------------------------------------------------------------------

/// «نويت تصوم؟ سجّله»: days he said «ناوي» to that the log does not hold.
class _ConfirmSection extends ConsumerWidget {
  const _ConfirmSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final texts = ref.watch(fastingTextsProvider);
    final config = ref.watch(fastingConfigProvider);
    final today = CalendarDays.dateOnly(ref.watch(orbitTodayProvider));
    final days = FastingOverview.toConfirm(
      today: today,
      intentions: ref.watch(fastingIntentionsProvider).value ?? const [],
      log: ref.watch(fastingLogProvider).value ?? const [],
    ).take(3).toList();
    if (days.isEmpty) return const SizedBox.shrink();
    return SettingsSection(
      title: l.fastRemConfirmTitle,
      seed: 0.1,
      children: [
        for (final d in days)
          SettingsTile(
            key: ValueKey('fasting.confirm.${CalendarDays.key(d)}'),
            icon: Icons.check_circle_outline_rounded,
            title: texts.when(d, FastingRules.hijriOf(d, config)),
            trailing: MadarButton(
              label: l.fastRemConfirmDone,
              semanticLabel: l.fastRemConfirmDoneSemantics(texts.gregorian(d)),
              onPressed: () => unawaited(_confirm(context, ref, d)),
            ),
          ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, DateTime day) async {
    final l = L10n.of(context);
    final undo = await ref.read(fastingServiceProvider).logFasted(day, source: FastLogSource.reminded);
    if (context.mounted) _undoToast(context, l.fastRemLogged, undo);
  }
}

// ---------------------------------------------------------------------------

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final texts = ref.watch(fastingTextsProvider);
    final today = CalendarDays.dateOnly(ref.watch(orbitTodayProvider));
    final upcoming = ref.watch(fastingUpcomingProvider);

    String? relative(DateTime d) => switch (CalendarDays.between(today, d)) {
      0 => l.fastRemToday,
      1 => l.fastRemTomorrow,
      _ => null,
    };

    return SettingsSection(
      title: l.fastRemSectionUpcoming,
      subtitle: l.fastRemSectionUpcomingHint,
      seed: 0.2,
      children: [
        if (upcoming.isEmpty)
          AnimatedEmptyState(
            key: const ValueKey('fasting.upcoming.empty'),
            kind: EmptyStateKind.noData,
            title: l.fastRemSectionUpcoming,
            body: l.fastRemUpcomingEmptyBody,
            illustrationSize: 88,
          )
        else
          for (final u in upcoming)
            SettingsTile(
              key: ValueKey('fasting.upcoming.${CalendarDays.key(u.reminder.day)}'),
              icon: u.logged ? Icons.check_circle_rounded : Icons.nightlight_round,
              iconColor: u.logged ? t.success : null,
              title: [?relative(u.reminder.day), texts.kind(u.reminder.kind)].join(l.commonFactSeparator),
              subtitle: [
                texts.when(u.reminder.day, u.reminder.hijri),
                if (u.reminder.alsoKinds.isNotEmpty)
                  l.fastRemAlso(u.reminder.alsoKinds.map(texts.kind).join(l.commonFactSeparator)),
              ].join('\n'),
              trailing: switch (u.answer) {
                FastIntentionChoice.yes => _Tag(l.fastRemAnsweredYes, color: t.success),
                FastIntentionChoice.no => _Tag(l.fastRemAnsweredNo, color: t.textTertiary),
                null => null,
              },
            ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: color, fontWeight: FontWeight.w700));
}

// ---------------------------------------------------------------------------

class _LogSection extends ConsumerWidget {
  const _LogSection();

  static const int shown = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final texts = ref.watch(fastingTextsProvider);
    final config = ref.watch(fastingConfigProvider);
    final today = CalendarDays.dateOnly(ref.watch(orbitTodayProvider));
    final log = ref.watch(fastingLogProvider).value ?? const <FastLogEntry>[];
    final fasted = [
      for (final e in log)
        if (e.fasted) e,
    ]..sort((a, b) => b.day.compareTo(a.day));
    final stats = FastingStats(log, config);
    final hijriToday = FastingRules.hijriOf(today, config);
    final fmt = texts.fmt;
    final loggedToday = fasted.any((e) => CalendarDays.same(e.day, today));

    String days(int n) => fmt.localizeDigits(l.fastRemStatDays(n));

    final six = stats.sixShawwalProgress(hijriToday.year);
    return SettingsSection(
      title: l.fastRemSectionLog,
      subtitle: l.fastRemSectionLogHint,
      seed: 0.35,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
          child: MadarButton(
            key: const ValueKey('fasting.log.today'),
            label: loggedToday ? l.fastRemLogTodayDone : l.fastRemLogToday,
            icon: loggedToday ? Icons.check_rounded : Icons.add_rounded,
            expand: true,
            onPressed: loggedToday ? null : () => unawaited(_logToday(context, ref, today)),
          ),
        ),
        SettingsTile(
          key: const ValueKey('fasting.stat.month'),
          icon: Icons.calendar_month_rounded,
          title: l.fastRemStatMonth,
          subtitle: l.hijriMonth(hijriToday.month),
          trailing: _Value(days(stats.fastedInHijriMonth(hijriToday.year, hijriToday.month))),
        ),
        SettingsTile(
          key: const ValueKey('fasting.stat.year'),
          icon: Icons.event_available_rounded,
          title: l.fastRemStatYear,
          subtitle: fmt.formatInt(hijriToday.year, grouping: false),
          trailing: _Value(days(stats.fastedInHijriYear(hijriToday.year))),
        ),
        SettingsTile(
          key: const ValueKey('fasting.stat.six'),
          icon: Icons.nights_stay_rounded,
          title: l.fastKindSix,
          trailing: _Value(l.fastRemSixProgress(fmt.formatInt(six.done), fmt.formatInt(six.goal))),
        ),
        SettingsTile(
          key: const ValueKey('fasting.stat.white'),
          icon: Icons.brightness_5_rounded,
          title: l.fastRemWhiteCounted,
          subtitle: [
            '${l.fastRemStatMonth}: ${days(stats.whiteDaysFastedInMonth(hijriToday.year, hijriToday.month))}',
            '${l.fastRemStatYear}: ${days(stats.whiteDaysFastedInYear(hijriToday.year))}',
          ].join(l.commonFactSeparator),
        ),
        if (fasted.isEmpty)
          AnimatedEmptyState(
            key: const ValueKey('fasting.log.empty'),
            kind: EmptyStateKind.emptyList,
            title: l.fastRemLogEmptyTitle,
            body: l.fastRemLogEmptyBody,
            illustrationSize: 88,
          )
        else
          for (final e in fasted.take(shown))
            SettingsTile(
              key: ValueKey('fasting.log.${CalendarDays.key(e.day)}'),
              icon: Icons.check_circle_rounded,
              iconColor: t.success,
              title: texts.when(e.day, FastingRules.hijriOf(e.day, config)),
              subtitle: e.kind == null ? null : texts.kind(e.kind!),
              trailing: MadarButton.icon(
                key: ValueKey('fasting.log.remove.${CalendarDays.key(e.day)}'),
                icon: Icons.delete_outline_rounded,
                semanticLabel: l.fastRemLogRemove,
                variant: MadarButtonVariant.ghost,
                onPressed: () => unawaited(_remove(context, ref, e.day)),
              ),
            ),
      ],
    );
  }

  Future<void> _logToday(BuildContext context, WidgetRef ref, DateTime today) async {
    final l = L10n.of(context);
    final undo = await ref.read(fastingServiceProvider).logFasted(today);
    if (context.mounted) _undoToast(context, l.fastRemLogged, undo);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, DateTime day) async {
    final l = L10n.of(context);
    final undo = await ref.read(fastingServiceProvider).removeLog(day);
    if (context.mounted) _undoToast(context, l.fastRemLogRemoved, undo);
  }
}

class _Value extends StatelessWidget {
  const _Value(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Text(
      text,
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.accent, fontWeight: FontWeight.w700),
    );
  }
}

// ---------------------------------------------------------------------------

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final config = ref.watch(fastingConfigProvider);
    final texts = ref.watch(fastingTextsProvider);
    final fmt = texts.fmt;
    final service = ref.read(fastingServiceProvider);
    // The shift is the prayer settings' own: watching the controller shows
    // it the instant it changes there too.
    final shift = ref.watch(prayerSettingsControllerProvider.select((s) => s.hijriOffsetDays));
    final now = CalendarDays.dateOnly(ref.watch(orbitTodayProvider));

    Widget group(FastKindGroup g, {required IconData icon, required String title, required String hint}) {
      return SettingsSwitchTile(
        key: ValueKey('fasting.switch.${g.name}'),
        icon: icon,
        title: title,
        subtitle: hint,
        value: g.isOn(config),
        onChanged: (on) => unawaited(_change(context, ref, (c) => g.set(c, on))),
      );
    }

    String shiftLabel(int d) => switch (d) {
      0 => l.fastRemShiftNone,
      1 => l.fastRemShiftAhead,
      -1 => l.fastRemShiftBehind,
      _ => l.fastRemShiftOther(fmt.formatInt(d)),
    };
    final shiftChoices = {-1, 0, 1, shift}.toList()..sort();
    final shawwalChoices = {2, 3, 4, 5, 6, 7, 8, config.effectiveShawwalStart}.toList()..sort();

    return SettingsSection(
      title: l.fastRemSectionSettings,
      subtitle: l.fastRemSectionSettingsHint,
      seed: 0.5,
      children: [
        group(FastKindGroup.weekly, icon: Icons.date_range_rounded, title: l.fastRemGroupWeekly, hint: l.fastRemGroupWeeklyHint),
        group(FastKindGroup.white, icon: Icons.brightness_5_rounded, title: l.fastRemGroupWhite, hint: l.fastRemGroupWhiteHint),
        group(FastKindGroup.yearly, icon: Icons.event_repeat_rounded, title: l.fastRemGroupYearly, hint: l.fastRemGroupYearlyHint),
        group(FastKindGroup.nudge, icon: Icons.notifications_none_rounded, title: l.fastRemNudge, hint: l.fastRemNudgeHint),
        SettingsChoiceTile<int>(
          key: const ValueKey('fasting.shawwalStart'),
          icon: Icons.nights_stay_rounded,
          title: l.fastRemShawwalStart,
          subtitle: l.fastRemShawwalStartHint,
          options: [
            for (final d in shawwalChoices) ChoiceOption(value: d, label: l.fastRemShawwalDay(fmt.formatInt(d))),
          ],
          selected: config.effectiveShawwalStart,
          onChanged: (d) => unawaited(_change(context, ref, (c) => c.copyWith(shawwalStartDay: d))),
        ),
        SettingsChoiceTile<int>(
          key: const ValueKey('fasting.shift'),
          icon: Icons.nightlight_round,
          title: l.fastRemShift,
          subtitle: texts.hijriFull(FastingRules.hijriOf(now, config)),
          options: [for (final d in shiftChoices) ChoiceOption(value: d, label: shiftLabel(d))],
          selected: shift,
          onChanged: (d) => unawaited(_shift(context, ref, service, d)),
        ),
        SettingsNote(l.fastRemShiftNote),
        SettingsNote(l.fastRemNeverNote, icon: Icons.block_rounded),
      ],
    );
  }

  Future<void> _change(BuildContext context, WidgetRef ref, FastingConfig Function(FastingConfig) change) async {
    final l = L10n.of(context);
    final undo = await ref.read(fastingServiceProvider).changeConfig(change);
    if (context.mounted) _undoToast(context, l.fastRemSettingChanged, undo);
  }

  Future<void> _shift(BuildContext context, WidgetRef ref, FastingService service, int days) async {
    final l = L10n.of(context);
    final undo = await service.setHijriShift(days);
    if (context.mounted) _undoToast(context, l.fastRemShiftChanged, undo);
  }
}
