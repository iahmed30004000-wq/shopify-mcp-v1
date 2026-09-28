import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../home/home_providers.dart' show homeNowProvider;
import '../../settings/widgets/settings_widgets.dart';
import '../application/adhan_providers.dart';
import '../data/adhan_permissions.dart';
import '../data/adhan_texts.dart';
import '../domain/adhan_plan.dart';
import '../domain/adhan_settings.dart';
import '../domain/adhan_slot.dart';
import '../domain/adhan_sound.dart';
import 'adhan_permissions_card.dart';
import 'muezzin_picker_sheet.dart';
import 'widgets/adhan_halo.dart';

/// Icon of a prayer / sunrise row.
IconData adhanSlotIcon(AdhanSlot s) => switch (s) {
  AdhanSlot.fajr => Icons.wb_twilight_rounded,
  AdhanSlot.sunrise => Icons.wb_sunny_outlined,
  AdhanSlot.dhuhr => Icons.wb_sunny_rounded,
  AdhanSlot.asr => Icons.light_mode_outlined,
  AdhanSlot.maghrib => Icons.nights_stay_outlined,
  AdhanSlot.isha => Icons.dark_mode_rounded,
};

/// Adhan settings: permissions status, the next adhan, per-prayer adhan and
/// reminder, the sunrise alert, the muezzin of Fajr and of the other
/// prayers (with preview), vibration, the full-screen view, prayer quiet,
/// snooze length, the alarm volume and "test adhan now".
///
/// Route widget (`/settings/adhan` is the lead's to register).
class AdhanSettingsScreen extends ConsumerWidget {
  const AdhanSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final battery = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final settings = ref.watch(adhanSettingsProvider).value;
    return MadarScaffold(
      title: l.adhanSettingsTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: !battery,
      backdropSeed: 0.71,
      body: settings == null
          ? const Center(child: OrbitLoader())
          : SettingsListView(
              children: [
                StaggerIn(
                  id: 'adhan-settings',
                  fade: false,
                  children: [
                    const SizedBox(height: Space.s),
                    const AdhanPermissionsCard(),
                    const SizedBox(height: Space.m),
                    const _NextAdhanCard(),
                    _PrayersSection(settings: settings),
                    _MuezzinSection(settings: settings),
                    _AlertSection(settings: settings),
                    const _TrySection(),
                  ],
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NextAdhanCard extends ConsumerWidget {
  const _NextAdhanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final sync = ref.watch(adhanSyncProvider);
    final texts = ref.watch(adhanTextsProvider);
    // Ticks every minute, so "in 1 h 39 min" counts down and the next adhan
    // moves on once this one has come.
    final now = ref.watch(homeNowProvider);
    final plan = sync.last?.plan;
    final next = plan == null ? null : AdhanPlanner.nextCall(plan, now);
    final report = sync.last?.report;
    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      glowColor: t.accentGlow,
      child: Row(
        children: [
          if (next != null)
            AdhanHalo(at: ref.watch(adhanWallClockProvider)(next.prayerAt), size: 76, dim: true)
          else
            SizedBox.square(
              dimension: 76,
              child: Center(child: IslamicStar(size: 34, color: t.textTertiary)),
            ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.adhanNextTitle, style: text.labelMedium!.copyWith(color: t.textTertiary)),
                if (next == null)
                  Text(l.adhanNextNone, style: text.titleLarge)
                else ...[
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: Space.s,
                    children: [
                      Text(texts.prayer(next.slot), style: text.headlineMedium!.copyWith(color: t.gold, height: 1.25)),
                      Text(
                        texts.time(next.prayerAt),
                        style: MadarTypography.numerals(t, size: 18, color: t.textPrimary).copyWith(height: 1.6),
                      ),
                    ],
                  ),
                  Text(
                    l.adhanNextIn(fmt.formatDurationWords(l, next.at.difference(now))),
                    style: text.bodyMedium!.copyWith(color: t.textSecondary),
                  ),
                ],
                if (report != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(
                    fmt.localizeDigits(l.adhanScheduledCount(report.pending)),
                    style: text.bodySmall!.copyWith(color: t.textTertiary),
                  ),
                  if (report.inexactFallback > 0)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: Space.xs),
                      child: Text(l.adhanScheduleInexact, style: text.bodySmall!.copyWith(color: t.warning)),
                    )
                  else if (report.pending > 0)
                    Text(l.adhanScheduleWeek, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PrayersSection extends ConsumerWidget {
  const _PrayersSection({required this.settings});

  final AdhanSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final texts = ref.watch(adhanTextsProvider);
    final times = ref.watch(adhanTimesProvider);
    final now = ref.watch(homeNowProvider);
    final today = times.timesFor(times.localDayOf(now));
    final controller = ref.read(adhanSettingsProvider.notifier);

    String subtitle(AdhanSlot slot) {
      final alert = settings.alertOf(slot);
      final at = today[slot];
      final parts = <String>[
        if (at != null) texts.time(at),
        if (!alert.adhan) l.adhanPrayerOff,
        if (alert.hasReminder) l.adhanPrayerReminder(texts.minutes(alert.preMinutes)),
      ];
      return parts.join(' · ');
    }

    return SettingsSection(
      title: l.adhanSectionPrayers,
      subtitle: l.adhanSectionPrayersHint,
      seed: 0.2,
      children: [
        for (final slot in AdhanSlot.prayers)
          ActionableItem(
            key: ValueKey('prayer-${slot.name}'),
            onTap: () => unawaited(_editPrayer(context, ref, slot)),
            swipeEnabled: false,
            semanticLabel: texts.prayer(slot),
            actions: ItemActions(
              onEdit: () => _editPrayer(context, ref, slot),
              extra: [
                ItemAction(
                  icon: Icons.play_circle_outline_rounded,
                  label: l.adhanTestThis,
                  onSelected: () async {
                    await _scheduleTest(context, ref, slot);
                    return null;
                  },
                ),
              ],
            ),
            child: SettingsTile(
              icon: adhanSlotIcon(slot),
              title: texts.prayer(slot),
              subtitle: subtitle(slot),
              trailing: MadarSwitch(
                value: settings.alertOf(slot).adhan,
                semanticLabel: l.adhanPrayerToggle(texts.prayer(slot)),
                onChanged: (v) =>
                    unawaited(controller.change((s) => s.withAlert(slot, s.alertOf(slot).copyWith(adhan: v)))),
              ),
            ),
          ),
        SettingsTile(
          icon: adhanSlotIcon(AdhanSlot.sunrise),
          title: l.adhanSunrise,
          subtitle: settings.sunriseAlert
              ? [
                  if (today[AdhanSlot.sunrise] != null) texts.time(today[AdhanSlot.sunrise]!),
                  settings.sunriseMinutesBefore == 0
                      ? l.adhanSunriseAt
                      : l.adhanSunriseBefore(texts.minutes(settings.sunriseMinutesBefore)),
                ].join(' · ')
              : l.adhanSunriseHint,
          onTap: () => unawaited(_editSunrise(context, ref, settings, texts)),
          trailing: MadarSwitch(
            value: settings.sunriseAlert,
            semanticLabel: l.adhanSunrise,
            onChanged: (v) => unawaited(controller.change((s) => s.copyWith(sunriseAlert: v))),
          ),
        ),
      ],
    );
  }

  static Future<void> _editPrayer(BuildContext context, WidgetRef ref, AdhanSlot slot) async {
    final l = L10n.of(context);
    final texts = ref.read(adhanTextsProvider);
    final current = (ref.read(adhanSettingsProvider).value ?? const AdhanSettings()).alertOf(slot);
    final values = await showEditSheet(
      context,
      title: l.adhanAlertSheetTitle(texts.prayer(slot)),
      icon: adhanSlotIcon(slot),
      fields: [
        FieldSpec.toggle('adhan', l.adhanAlertCall, icon: Icons.campaign_rounded),
        FieldSpec.singleSelect(
          'pre',
          l.adhanAlertReminder,
          icon: Icons.notifications_none_rounded,
          options: [
            for (final m in AdhanSettings.reminderChoices)
              SelectOption(id: '$m', label: m == 0 ? l.adhanReminderNone : texts.minutesShort(m)),
          ],
        ),
      ],
      initial: {'adhan': current.adhan, 'pre': '${current.preMinutes}'},
    );
    if (values == null) return;
    final adhan = values['adhan'] as bool? ?? current.adhan;
    final pre = int.tryParse('${values['pre']}') ?? current.preMinutes;
    await ref
        .read(adhanSettingsProvider.notifier)
        .change((s) => s.withAlert(slot, PrayerAlert(adhan: adhan, preMinutes: pre)));
  }

  static Future<void> _editSunrise(
    BuildContext context,
    WidgetRef ref,
    AdhanSettings settings,
    AdhanTexts texts,
  ) async {
    final l = L10n.of(context);
    final values = await showEditSheet(
      context,
      title: l.adhanSunrise,
      subtitle: l.adhanSunriseHint,
      icon: adhanSlotIcon(AdhanSlot.sunrise),
      fields: [
        FieldSpec.toggle('on', l.adhanSunrise, icon: Icons.wb_twilight_rounded),
        FieldSpec.singleSelect(
          'before',
          l.adhanAlertReminder,
          icon: Icons.schedule_rounded,
          options: [
            for (final m in AdhanSettings.sunriseChoices)
              SelectOption(id: '$m', label: m == 0 ? l.adhanSunriseAt : l.adhanSunriseBefore(texts.minutesShort(m))),
          ],
        ),
      ],
      initial: {'on': settings.sunriseAlert, 'before': '${settings.sunriseMinutesBefore}'},
    );
    if (values == null) return;
    await ref
        .read(adhanSettingsProvider.notifier)
        .change(
          (s) => s.copyWith(
            sunriseAlert: values['on'] as bool? ?? s.sunriseAlert,
            sunriseMinutesBefore: int.tryParse('${values['before']}') ?? s.sunriseMinutesBefore,
          ),
        );
  }
}

// ---------------------------------------------------------------------------

class _MuezzinSection extends ConsumerWidget {
  const _MuezzinSection({required this.settings});

  final AdhanSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final texts = ref.watch(adhanTextsProvider);
    final audio = ref.watch(adhanAudioProvider);

    Widget row({required bool fajr}) {
      final slot = fajr ? AdhanSlot.fajr : AdhanSlot.dhuhr;
      final sound = settings.resolve(settings.soundFor(slot), slot);
      final m = settings.muezzinById(sound.fileId);
      final previewable = sound.kind != AdhanSoundKind.silent && (m == null || m.playableInApp);
      return SettingsTile(
        icon: fajr ? Icons.wb_twilight_rounded : Icons.record_voice_over_rounded,
        title: fajr ? l.adhanMuezzinFajr : l.adhanMuezzinOthers,
        subtitle: texts.soundName(sound, muezzin: m),
        navigates: true,
        onTap: () => unawaited(showMuezzinPicker(context, fajr: fajr)),
        trailing: previewable
            ? ValueListenableBuilder<AdhanSoundRef?>(
                valueListenable: audio.playing,
                builder: (context, playing, _) {
                  final on = playing == sound;
                  return MadarButton.icon(
                    icon: on ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    semanticLabel: on ? l.adhanListenStop : l.adhanListen,
                    variant: on ? MadarButtonVariant.primary : MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    onPressed: () => unawaited(on ? audio.stop() : audio.play(sound, muezzin: m)),
                  );
                },
              )
            : null,
      );
    }

    return SettingsSection(
      title: l.adhanSectionMuezzin,
      subtitle: l.adhanSectionMuezzinHint,
      seed: 0.4,
      children: [row(fajr: true), row(fajr: false)],
    );
  }
}

// ---------------------------------------------------------------------------

class _AlertSection extends ConsumerWidget {
  const _AlertSection({required this.settings});

  final AdhanSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final texts = ref.watch(adhanTextsProvider);
    final controller = ref.read(adhanSettingsProvider.notifier);
    final status = ref.watch(adhanPermissionStatusProvider).value ?? AdhanPermissionStatus.unknown;
    final volume = status.alarmVolume;
    return SettingsSection(
      title: l.adhanSectionAlert,
      seed: 0.6,
      children: [
        SettingsSwitchTile(
          icon: Icons.vibration_rounded,
          title: l.adhanVibrate,
          subtitle: l.adhanVibrateHint,
          value: settings.vibrate,
          onChanged: (v) => unawaited(controller.change((s) => s.copyWith(vibrate: v))),
        ),
        SettingsSwitchTile(
          icon: Icons.fullscreen_rounded,
          title: l.adhanFullScreen,
          subtitle: l.adhanFullScreenHint,
          value: settings.fullScreen,
          onChanged: (v) => unawaited(controller.change((s) => s.copyWith(fullScreen: v))),
        ),
        SettingsChoiceTile<int>(
          icon: Icons.music_off_rounded,
          title: l.adhanQuiet,
          subtitle: l.adhanQuietHint,
          options: [
            for (final m in AdhanSettings.quietChoices)
              ChoiceOption(value: m, label: m == 0 ? l.adhanQuietAdhanOnly : texts.minutesShort(m)),
          ],
          selected: settings.quietMinutes,
          onChanged: (v) => unawaited(controller.change((s) => s.copyWith(quietMinutes: v))),
        ),
        SettingsChoiceTile<int>(
          icon: Icons.snooze_rounded,
          title: l.adhanSnoozeLength,
          options: [for (final m in AdhanSettings.snoozeChoices) ChoiceOption(value: m, label: texts.minutesShort(m))],
          selected: settings.snoozeMinutes,
          onChanged: (v) => unawaited(controller.change((s) => s.copyWith(snoozeMinutes: v))),
        ),
        SettingsTile(
          icon: status.alarmMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          iconColor: status.alarmMuted ? t.warning : null,
          title: l.adhanAlarmVolume,
          subtitle: status.alarmMuted ? l.adhanAlarmMuted : l.adhanAlarmVolumeHint,
          trailing: volume == null
              ? null
              : Text(
                  fmt.formatPercent(volume.fraction),
                  style: Theme.of(context).textTheme.labelLarge!
                      .copyWith(color: status.alarmMuted ? t.warning : t.accent),
                ),
          navigates: true,
          onTap: () => unawaited(ref.read(adhanSystemProvider).openSoundSettings()),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _TrySection extends ConsumerStatefulWidget {
  const _TrySection();

  @override
  ConsumerState<_TrySection> createState() => _TrySectionState();
}

class _TrySectionState extends ConsumerState<_TrySection> {
  String? _note;
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    return SettingsSection(
      title: l.adhanSectionTry,
      seed: 0.8,
      children: [
        SettingsTile(
          icon: Icons.play_circle_fill_rounded,
          iconColor: t.gold,
          title: l.adhanTestNow,
          subtitle: l.adhanTestHint,
          onTap: () async {
            final note = await _scheduleTest(context, ref, null);
            if (mounted) {
              setState(() {
                _note = note;
                _failed = note == null;
              });
            }
          },
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          child: _note == null && !_failed
              ? const SizedBox(width: double.infinity)
              : SettingsNote(
                  _failed ? l.adhanTestFailed : _note!,
                  icon: _failed ? Icons.error_outline_rounded : Icons.notifications_active_rounded,
                ),
        ),
      ],
    );
  }
}

/// Schedules a real adhan of [slot] (the next prayer when null) in a few
/// seconds; returns the confirmation text, or null if it could not be
/// scheduled.
Future<String?> _scheduleTest(BuildContext context, WidgetRef ref, AdhanSlot? slot) async {
  final l = L10n.of(context);
  final fmt = MadarFormatter.of(context);
  const delay = Duration(seconds: 10);
  final settings = ref.read(adhanSettingsProvider).value ?? const AdhanSettings();
  final now = ref.read(adhanClockProvider)();
  final plan = ref.read(adhanSyncProvider).last?.plan;
  final pick = slot ?? (plan == null ? null : AdhanPlanner.nextCall(plan, now)?.slot) ?? AdhanSlot.maghrib;
  final event = await ref
      .read(adhanSchedulerProvider)
      .scheduleTest(settings: settings, texts: ref.read(adhanTextsProvider), slot: pick, delay: delay);
  Fx.fire(event != null ? Sfx.notify : Sfx.error);
  if (event == null) return null;
  ref.read(adhanEventProvider.notifier).presentWhenDue(event);
  return l.adhanTestScheduled(fmt.localizeDigits(l.adhanSeconds(delay.inSeconds)));
}
