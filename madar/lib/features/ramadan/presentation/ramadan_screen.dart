import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../prayer/application/prayer_settings_controller.dart' show prayerSettingsControllerProvider;
import '../../settings/widgets/settings_widgets.dart';
import '../application/ramadan_providers.dart';
import '../domain/khatmah_plan.dart';
import '../domain/last_ten_nights.dart';
import '../domain/ramadan_config.dart';
import '../domain/ramadan_today.dart';
import 'ramadan_compare_tab.dart';
import 'ramadan_countdown.dart';
import 'ramadan_hub_card.dart' show ramadanUndoToast;
import 'ramadan_khatmah_tab.dart';
import 'ramadan_last_ten_tab.dart';
import 'ramadan_taraweeh_tab.dart';

enum RamadanTab { today, taraweeh, khatmah, lastTen, compare }

/// «رمضان»: the month in one place (Part 19), under the Faith planet.
///
/// Five tabs: **today** (the countdown to iftar or suhoor, tonight's Taraweeh,
/// today's portion, and the atmosphere and reminder settings), the **Taraweeh**
/// log, the **khatmah** plan, the **last ten nights** with the supplication
/// slot, and **this year beside last**. Every write shows an undo toast.
/// Route widget: `/faith/ramadan`.
class RamadanScreen extends ConsumerStatefulWidget {
  const RamadanScreen({super.key, this.initialTab = RamadanTab.today, this.animateBackdrop = true});

  final RamadanTab initialTab;
  final bool animateBackdrop;

  @override
  ConsumerState<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends ConsumerState<RamadanScreen> {
  late RamadanTab _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final battery = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    // Watching the sync keeps the reminders planned while this screen is open
    // (the app shell watches it too).
    ref.watch(ramadanSyncProvider);
    final labels = {
      RamadanTab.today: l.ramadanTabToday,
      RamadanTab.taraweeh: l.ramadanTabTaraweeh,
      RamadanTab.khatmah: l.ramadanTabKhatmah,
      RamadanTab.lastTen: l.ramadanTabLastTen,
      RamadanTab.compare: l.ramadanTabCompare,
    };
    return MadarScaffold(
      title: l.ramadanTitle,
      animateBackdrop: widget.animateBackdrop && !battery,
      backdropSeed: 0.71,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The tabs stay where they are while the page scrolls.
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, Space.s),
            child: SingleChildScrollView(
              key: const ValueKey('ramadan.tabs'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tab in RamadanTab.values) ...[
                    MadarChip(
                      key: ValueKey('ramadan.tab.${tab.name}'),
                      label: labels[tab]!,
                      selected: tab == _tab,
                      onSelected: (_) => setState(() => _tab = tab),
                    ),
                    const SizedBox(width: Space.s),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: SettingsListView(
              key: ValueKey('ramadan.page.${_tab.name}'),
              children: [
                StaggerIn(
                  id: 'ramadan-screen-${_tab.name}',
                  fade: false,
                  children: [
                    switch (_tab) {
                      RamadanTab.today => const _TodayTab(),
                      RamadanTab.taraweeh => const RamadanTaraweehTab(),
                      RamadanTab.khatmah => const RamadanKhatmahTab(),
                      RamadanTab.lastTen => const RamadanLastTenTab(),
                      RamadanTab.compare => const RamadanCompareTab(),
                    },
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

// ---------------------------------------------------------------------------

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(ramadanTodayProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (today.inRamadan) _InRamadan(today: today) else _OutsideRamadan(today: today),
        const _SettingsSection(),
      ],
    );
  }
}

class _InRamadan extends ConsumerWidget {
  const _InRamadan({required this.today});

  final RamadanToday today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final texts = ref.watch(ramadanTextsProvider);
    final calendar = ref.watch(ramadanCalendarProvider);
    final number = today.headlineNumber ?? 1;
    final headline = today.dayOfRamadan != null ? l.ramadanDayOf(texts.number(number)) : l.ramadanNightOf(texts.number(number));
    final tonight = today.tonight;
    final year = today.hijriYear;
    final done = tonight != null && year != null && (ref.watch(ramadanLogBookProvider).value?.of(year)?.taraweeh.isDone(tonight) ?? false);
    final k = ref.watch(ramadanKhatmahTodayProvider);
    final service = ref.read(ramadanServiceProvider);
    return SettingsSection(
      title: headline,
      subtitle: texts.hijriFull(calendar.hijriOf(today.date)),
      seed: 0.1,
      children: [
        Padding(
          key: const ValueKey('ramadan.today.countdown'),
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
          child: RamadanCountdownBlock(today: today),
        ),
        if (tonight != null && year != null)
          SettingsSwitchTile(
            key: const ValueKey('ramadan.today.tonight'),
            icon: Icons.mosque_rounded,
            title: l.ramadanTaraweehTonight(texts.number(tonight)),
            subtitle: done ? l.ramadanTaraweehLogged : l.ramadanTaraweehNotYet,
            value: done,
            onChanged: (_) async {
              final undo = await service.toggleTaraweeh(year, tonight);
              if (context.mounted) ramadanUndoToast(context, done ? l.ramadanTaraweehRemovedToast : l.ramadanTaraweehLoggedToast, undo);
            },
          ),
        if (k.status != KhatmahStatus.finished && !k.portion.isEmpty)
          SettingsTile(
            key: const ValueKey('ramadan.today.portion'),
            icon: k.todayDone ? Icons.check_circle_rounded : Icons.auto_stories_rounded,
            iconColor: k.todayDone ? t.success : null,
            title: k.todayDone ? l.ramadanKhatmahDoneToday : l.ramadanKhatmahPortion,
            subtitle: l.ramadanKhatmahPages(texts.number(k.portion.fromPage), texts.number(k.portion.toPage)),
          ),
        if (today.lastTenTonight && tonight != null)
          SettingsTile(
            key: const ValueKey('ramadan.today.lastTen'),
            icon: LastTenNights.isOddSought(tonight) ? Icons.star_rounded : Icons.star_outline_rounded,
            iconColor: t.gold,
            title: l.ramadanLastTenStrip(texts.number(tonight)),
            subtitle: LastTenNights.isOddSought(tonight) ? l.ramadanLastTenOdd : null,
          ),
      ],
    );
  }
}

/// Before Ramadan (or after the Eid): how long to the next one.
class _OutsideRamadan extends ConsumerWidget {
  const _OutsideRamadan({required this.today});

  final RamadanToday today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final texts = ref.watch(ramadanTextsProvider);
    final calendar = ref.watch(ramadanCalendarProvider);
    final first = calendar.nextSpanAfter(today.date).first;
    final days = today.daysUntilRamadan;
    return SettingsSection(
      title: days == 1 ? l.ramadanComingTomorrow : l.ramadanComingTitle(texts.days(days)),
      subtitle: l.ramadanComingDate(texts.when(first, calendar.hijriOf(first))),
      seed: 0.1,
      children: [
        SettingsNote(today.comingSoon ? l.ramadanComingHint : l.ramadanFarHint),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  static const List<int> iftarLeads = [5, 10, 15, 20, 30, 45, 60];
  static const List<int> suhoorLeads = [15, 30, 45, 60, 90, 120];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final config = ref.watch(ramadanConfigProvider);
    final texts = ref.watch(ramadanTextsProvider);
    final fmt = texts.fmt;
    final service = ref.read(ramadanServiceProvider);
    // The shift is the prayer settings' own: watching the controller shows it
    // the instant it changes there too.
    final shift = ref.watch(prayerSettingsControllerProvider.select((s) => s.hijriOffsetDays));

    Widget sw(String key, IconData icon, String title, String hint, bool value, RamadanConfig Function(RamadanConfig, bool) set) {
      return SettingsSwitchTile(
        key: ValueKey('ramadan.switch.$key'),
        icon: icon,
        title: title,
        subtitle: hint,
        value: value,
        onChanged: (on) => unawaited(_change(context, ref, (c) => set(c, on))),
      );
    }

    Widget lead(String key, IconData icon, String title, int value, List<int> choices, RamadanConfig Function(RamadanConfig, int) set) {
      final options = ({...choices, value}.toList()..sort());
      return SettingsChoiceTile<int>(
        key: ValueKey('ramadan.lead.$key'),
        icon: icon,
        title: title,
        subtitle: texts.minutes(value),
        options: [for (final m in options) ChoiceOption(value: m, label: texts.minutes(m))],
        selected: value,
        onChanged: (m) => unawaited(_change(context, ref, (c) => set(c, m))),
      );
    }

    String shiftLabel(int d) => switch (d) {
      0 => l.fastRemShiftNone,
      1 => l.fastRemShiftAhead,
      -1 => l.fastRemShiftBehind,
      _ => l.fastRemShiftOther(fmt.formatInt(d)),
    };
    final shiftChoices = {-1, 0, 1, shift}.toList()..sort();
    final calendar = ref.watch(ramadanCalendarProvider);
    final today = ref.watch(ramadanTodayProvider);

    return SettingsSection(
      title: l.ramadanSettingsSection,
      subtitle: l.ramadanSettingsHint,
      seed: 0.6,
      children: [
        sw('atmosphere', Icons.nightlight_round, l.ramadanAtmosphere, l.ramadanAtmosphereHint, config.atmosphere,
            (c, on) => c.copyWith(atmosphere: on)),
        sw('suhoor', Icons.wb_twilight_rounded, l.ramadanSuhoorReminder, l.ramadanSuhoorReminderHint, config.suhoorReminder,
            (c, on) => c.copyWith(suhoorReminder: on)),
        if (config.suhoorReminder)
          lead('suhoor', Icons.timer_outlined, l.ramadanSuhoorLead, config.effectiveSuhoorLead, suhoorLeads,
              (c, m) => c.copyWith(suhoorLeadMinutes: m)),
        sw('iftar', Icons.restaurant_rounded, l.ramadanIftarReminder, l.ramadanIftarReminderHint, config.iftarReminder,
            (c, on) => c.copyWith(iftarReminder: on)),
        if (config.iftarReminder)
          lead('iftar', Icons.timer_outlined, l.ramadanIftarLead, config.effectiveIftarLead, iftarLeads,
              (c, m) => c.copyWith(iftarLeadMinutes: m)),
        sw('taraweeh', Icons.mosque_rounded, l.ramadanTaraweehReminder, l.ramadanTaraweehReminderHint, config.taraweehReminder,
            (c, on) => c.copyWith(taraweehReminder: on)),
        sw('lastTen', Icons.star_outline_rounded, l.ramadanLastTenReminder, l.ramadanLastTenReminderHint, config.lastTenReminder,
            (c, on) => c.copyWith(lastTenReminder: on)),
        sw('khatmah', Icons.auto_stories_rounded, l.ramadanHubKhatmah, l.ramadanHubKhatmahHint, config.hubKhatmah,
            (c, on) => c.copyWith(hubKhatmah: on)),
        SettingsChoiceTile<int>(
          key: const ValueKey('ramadan.shift'),
          icon: Icons.nightlight_round,
          title: l.fastRemShift,
          subtitle: texts.hijriFull(calendar.hijriOf(today.date)),
          options: [for (final d in shiftChoices) ChoiceOption(value: d, label: shiftLabel(d))],
          selected: shift,
          onChanged: (d) => unawaited(_shift(context, service, d)),
        ),
        SettingsNote(l.fastRemShiftNote),
      ],
    );
  }

  Future<void> _change(BuildContext context, WidgetRef ref, RamadanConfig Function(RamadanConfig) change) async {
    final l = L10n.of(context);
    final undo = await ref.read(ramadanServiceProvider).changeConfig(change);
    if (context.mounted) ramadanUndoToast(context, l.ramadanSettingChanged, undo);
  }

  Future<void> _shift(BuildContext context, RamadanService service, int days) async {
    final l = L10n.of(context);
    final undo = await service.setHijriShift(days);
    if (context.mounted) ramadanUndoToast(context, l.fastRemShiftChanged, undo);
  }
}
