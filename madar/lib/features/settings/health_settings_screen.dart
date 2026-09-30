import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/interaction/interaction.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/notifications/notifications.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/sound_api.dart';
import '../health/meds/meds.dart'
    show MealSlot, MedsActions, MedsSettings, MedsTexts, medsServiceProvider, medsSettingsProvider;
import '../health/record/record.dart'
    show
        RecordActions,
        RecordIcons,
        RecordSettings,
        RecordContext,
        ReportPeriod,
        ReportSection,
        recordServiceProvider,
        recordSettingsProvider,
        recordSettingsValueProvider;
import '../health/wellbeing/wellbeing.dart'
    show
        WellbeingSettings,
        showWellbeingSettingsSheet,
        showWorryWindowSheet,
        wellbeingServiceProvider,
        wellbeingSettingsProvider;
import '../lock/application/lock_controller.dart';
import 'widgets/settings_widgets.dart';

/// Health reminders switched on – doses, appointments, the worry window
/// (Settings' Health entry shows the count).
final healthRemindersOnProvider = Provider<int>((ref) {
  final meds = ref.watch(medsSettingsProvider).value ?? const MedsSettings();
  final record = ref.watch(recordSettingsProvider).value ?? const RecordSettings();
  final worry = (ref.watch(wellbeingSettingsProvider).value ?? const WellbeingSettings()).worry;
  return HealthSettingsSummary.remindersOn(meds: meds, record: record, worryOn: worry.enabled && worry.remind);
});

/// Settings › Health's small decisions (pure – unit-tested).
abstract final class HealthSettingsSummary {
  /// The borderline margins offered (percent of a range's width).
  static const List<int> marginChoices = [0, 5, 10, 15, 20];

  static int remindersOn({required MedsSettings meds, required RecordSettings record, required bool worryOn}) =>
      (meds.notify ? 1 : 0) + (record.remindersEnabled ? 1 : 0) + (worryOn ? 1 : 0);

  /// The margin choices, with the stored one kept when the record's own
  /// sheet set another value (7 %).
  static List<int> marginsWith(double margin) {
    final current = (margin * 100).round();
    return {...marginChoices, current}.toList()..sort();
  }
}

/// Settings › Health: everything the health packages keep as preferences,
/// on one page – each saved through its package's own service, so the
/// reminders re-plan at once:
///
/// * **medications** – dose reminders (Taken / Snooze / Skip), the
///   notification's snooze, and the meal times the "with breakfast" slots
///   and food rules follow (with the rest of the dose timing, in the
///   medications' own sheet);
/// * **appointments & labs** – appointment reminders and when they arrive,
///   and the "borderline" margin of the lab flags;
/// * **doctor summary** – the report's usual period, sections and the name
///   in its header (kept only when the user saves one);
/// * **wellbeing** – the worry window, the emergency number of the support
///   note and the breathing sound.
///
/// Switching a reminder on asks for notification permission once; a
/// refusal keeps the choice and says why nothing will arrive.
class HealthSettingsScreen extends ConsumerStatefulWidget {
  const HealthSettingsScreen({super.key});

  @override
  ConsumerState<HealthSettingsScreen> createState() => _HealthSettingsScreenState();
}

class _HealthSettingsScreenState extends ConsumerState<HealthSettingsScreen> {
  bool _denied = false;

  /// True when notifications may be shown (asks once, under the app lock's
  /// suspension so the system dialog never trips it).
  Future<bool> _ensurePermission() async {
    final notifications = ref.read(notificationServiceProvider);
    try {
      if (await notifications.notificationsEnabled()) return true;
      final allowed = await ref
          .read(lockControllerProvider.notifier)
          .whileSuspended(notifications.requestNotifications);
      if (!allowed) Fx.fire(Sfx.notify);
      return allowed;
    } catch (e) {
      debugPrint('Health settings: notification permission: $e');
      return false;
    }
  }

  Future<void> _reminderSwitched(bool on, Future<void> Function() save) async {
    try {
      await save();
      if (on) {
        final allowed = await _ensurePermission();
        if (mounted) setState(() => _denied = !allowed);
      }
    } catch (e) {
      Fx.fire(Sfx.error);
      debugPrint('Health settings: saving failed: $e');
    }
  }

  Future<void> _saveMeds(MedsSettings next) => ref.read(medsServiceProvider).saveSettings(next);

  Future<void> _saveRecord(RecordSettings next) async {
    await ref.read(recordServiceProvider).saveSettings(next);
  }

  Future<void> _editSections(RecordSettings s) async {
    final l = L10n.of(context);
    final texts = context.recordTexts;
    final values = await showEditSheet(
      context,
      title: l.healthHubSettingsReportSections,
      icon: RecordIcons.report,
      saveLabel: l.recordSave,
      initial: {
        'sections': [for (final x in s.sectionsOrDefault) x.name],
      },
      fields: [
        FieldSpec.multiSelect(
          'sections',
          l.recordReportSectionsField,
          minCount: 1,
          options: [for (final x in ReportSection.values) SelectOption(id: x.name, label: texts.section(x))],
        ),
      ],
    );
    if (values == null) return;
    final ids = ((values['sections'] as List?) ?? const []).cast<String>().toSet();
    final picked = {
      for (final x in ReportSection.values)
        if (ids.contains(x.name)) x,
    };
    if (picked.isEmpty) return;
    await _saveRecord(s.copyWith(reportSections: picked));
    Fx.fire(Sfx.complete);
  }

  Future<void> _editName(RecordSettings s) async {
    final l = L10n.of(context);
    final values = await showEditSheet(
      context,
      title: l.recordReportNameField,
      icon: Icons.badge_outlined,
      saveLabel: l.recordSave,
      subtitle: l.recordReportRememberHint,
      initial: {'name': s.reportName ?? ''},
      fields: [FieldSpec.text('name', l.recordReportNameLabel, hint: l.healthHubSettingsReportNameHint, maxLength: 80)],
    );
    if (values == null) return;
    final name = (values['name'] as String?)?.trim() ?? '';
    await _saveRecord(name.isEmpty ? s.copyWith(clearReportName: true) : s.copyWith(reportName: name));
    Fx.fire(Sfx.complete);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final tx = MedsTexts(l, fmt);
    final saver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final meds = ref.watch(medsSettingsProvider).value;
    final record = ref.watch(recordSettingsValueProvider);
    final wellbeing = ref.watch(wellbeingSettingsProvider).value ?? const WellbeingSettings();
    final worry = wellbeing.worry;

    // A sentence: "Breakfast 8:00 AM, lunch 2:00 PM, dinner …" – the meal
    // words after the first are the running ones, which in Arabic say
    // «وجبة العشاء» so dinner never reads as the Isha prayer.
    final meals = [
      for (final m in MealSlot.values)
        '${m == MealSlot.values.first ? tx.mealTitle(m) : tx.meal(m)} '
            '${tx.clock((meds ?? const MedsSettings()).mealTime(m))}',
    ].join(l.recordListSeparator);
    final offsets = record.remindersEnabled && record.effectiveOffsets.isNotEmpty
        ? [for (final o in record.effectiveOffsets) texts.reminderOffset(o)].join(l.recordListSeparator)
        : l.healthHubSettingsOff;
    final sections = record.sectionsOrDefault;
    final number = BidiIsolate.ltr(fmt.localizeDigits(wellbeing.supportNumber));
    final worrySummary = worry.enabled
        ? fmt.localizeDigits(
            l.healthHubSettingsWorrySummary(
              fmt.formatClock(worry.hour, worry.minute),
              l.wbMinutes(worry.durationMinutes, fmt.formatInt(worry.durationMinutes)),
            ),
          )
        : l.wbWorryWindowOff;

    return MadarScaffold(
      title: l.healthHubSettingsTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: !saver,
      backdropSeed: 0.61,
      body: SettingsListView(
        children: [
          StaggerIn(
            id: 'health-settings',
            fade: false,
            children: [
              if (_denied)
                Padding(
                  padding: const EdgeInsetsDirectional.only(top: Space.s),
                  child: SettingsNote(l.healthHubSettingsDenied, icon: Icons.notifications_off_outlined),
                ),
              SettingsSection(
                title: l.medsTitle,
                seed: 0.15,
                children: [
                  SettingsSwitchTile(
                    icon: Icons.notifications_active_rounded,
                    title: l.medsReminders,
                    subtitle: l.medsRemindersHint,
                    value: meds?.notify ?? true,
                    onChanged: meds == null
                        ? null
                        : (on) => unawaited(_reminderSwitched(on, () => _saveMeds(meds.copyWith(notify: on)))),
                  ),
                  if (meds != null)
                    SettingsChoiceTile<int>(
                      icon: Icons.snooze_rounded,
                      title: l.medsSnoozeDefault,
                      selected: meds.snoozeMinutes,
                      options: [
                        for (final m in MedsSettings.snoozeChoices) ChoiceOption(value: m, label: tx.duration(m)),
                      ],
                      onChanged: (m) => unawaited(_saveMeds(meds.copyWith(snoozeMinutes: m))),
                    ),
                  SettingsTile(
                    icon: Icons.restaurant_rounded,
                    iconColor: t.gold,
                    title: l.medsMealTimes,
                    subtitle: meds == null ? l.medsMealTimesHint : meals,
                    navigates: true,
                    onTap: meds == null ? null : () => unawaited(MedsActions.openSettings(context, ref)),
                  ),
                  SettingsNote(l.medsMealTimesHint, icon: Icons.schedule_rounded),
                ],
              ),
              SettingsSection(
                title: l.healthHubSettingsRecordSection,
                seed: 0.3,
                children: [
                  SettingsSwitchTile(
                    icon: RecordIcons.appointments,
                    title: l.recordSettingsReminders,
                    subtitle: l.recordSettingsRemindersHint,
                    value: record.remindersEnabled,
                    onChanged: (on) =>
                        unawaited(_reminderSwitched(on, () => _saveRecord(record.copyWith(remindersEnabled: on)))),
                  ),
                  SettingsTile(
                    icon: Icons.alarm_rounded,
                    title: l.recordSettingsReminderTimes,
                    subtitle: offsets,
                    navigates: true,
                    onTap: () => unawaited(RecordActions(context, ref).openSettings()),
                  ),
                  SettingsChoiceTile<int>(
                    icon: Icons.straighten_rounded,
                    title: l.recordSettingsMargin,
                    subtitle: l.healthHubSettingsMarginHint,
                    selected: (record.borderlineMargin * 100).round(),
                    options: [
                      for (final p in HealthSettingsSummary.marginsWith(record.borderlineMargin))
                        ChoiceOption(value: p, label: fmt.formatPercent(p / 100)),
                    ],
                    onChanged: (p) => unawaited(_saveRecord(record.copyWith(borderlineMargin: p / 100))),
                  ),
                ],
              ),
              SettingsSection(
                title: l.healthHubSettingsReportSection,
                subtitle: l.recordReportPrivacyNote,
                seed: 0.45,
                children: [
                  SettingsChoiceTile<ReportPeriod>(
                    icon: Icons.date_range_rounded,
                    title: l.healthHubSettingsReportPeriod,
                    selected: record.reportPeriod,
                    options: [
                      for (final p in ReportPeriod.values) ChoiceOption(value: p, label: texts.reportPeriod(p)),
                    ],
                    onChanged: (p) => unawaited(_saveRecord(record.copyWith(reportPeriod: p))),
                  ),
                  SettingsTile(
                    icon: Icons.checklist_rounded,
                    title: l.healthHubSettingsReportSections,
                    subtitle: sections.length == ReportSection.values.length
                        ? l.healthHubSettingsReportSectionsAll
                        : [for (final s in ReportSection.values.where(sections.contains)) texts.section(s)]
                              .join(l.recordListSeparator),
                    navigates: true,
                    onTap: () => unawaited(_editSections(record)),
                  ),
                  SettingsTile(
                    icon: Icons.badge_outlined,
                    title: l.recordReportNameField,
                    subtitle: record.reportName == null
                        ? l.healthHubSettingsReportNameNone
                        : l.healthHubSettingsReportNameKept(BidiIsolate.isolate(record.reportName!)),
                    navigates: true,
                    onTap: () => unawaited(_editName(record)),
                  ),
                ],
              ),
              SettingsSection(
                title: l.wbTitle,
                seed: 0.6,
                children: [
                  SettingsTile(
                    icon: Icons.hourglass_empty_rounded,
                    title: l.wbWorryWindowTitle,
                    subtitle: worrySummary,
                    navigates: true,
                    onTap: () => unawaited(showWorryWindowSheet(context)),
                  ),
                  SettingsTile(
                    icon: Icons.call_outlined,
                    iconColor: t.gold,
                    title: l.wbSettingsSupportNumber,
                    subtitle: l.healthHubSettingsEmergencyHint(number),
                    navigates: true,
                    onTap: () => unawaited(showWellbeingSettingsSheet(context)),
                  ),
                  SettingsSwitchTile(
                    icon: Icons.air_rounded,
                    title: l.wbSettingsBreathingSound,
                    subtitle: l.wbSettingsBreathingSoundHint,
                    value: wellbeing.breathingSound,
                    onChanged: (on) => unawaited(
                      ref.read(wellbeingServiceProvider).updateSettings((s) => s.copyWith(breathingSound: on)),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.m),
                child: SettingsNote(l.healthHubSettingsPrivacy, icon: Icons.lock_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
