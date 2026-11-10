import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../adhan/application/adhan_providers.dart' show adhanSettingsProvider, adhanTimesProvider;
import '../../adhan/domain/adhan_settings.dart';
import '../../adhan/domain/adhan_slot.dart';
import '../../adhan/domain/adhan_sound.dart';
import '../../adhan/presentation/adhan_settings_screen.dart' show adhanSlotIcon;
import '../../home/home_providers.dart' show homeNowProvider;
import '../../settings/widgets/settings_widgets.dart';
import '../application/iqama_providers.dart';
import '../data/iqama_texts.dart';
import '../domain/iqama_settings.dart';

/// «الإقامة»: for each prayer, how long after its adhan Madar calls
/// «قامت الصلاة», each one switchable on its own, Friday's Dhuhr with its
/// own offset, the iqama's own sound, its vibration and the length of the
/// single «بعد شوي».
///
/// Route widget (`/settings/iqama` is the lead's to register).
class IqamaSettingsScreen extends ConsumerWidget {
  const IqamaSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final battery = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    // Watching the sync keeps the iqamas planned while this screen is open
    // (the app shell watches it too).
    ref.watch(iqamaSyncProvider);
    final settings = ref.watch(iqamaSettingsProvider).value;
    final adhan = ref.watch(adhanSettingsProvider).value;
    return MadarScaffold(
      title: l.iqamaTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: !battery,
      backdropSeed: 0.37,
      body: settings == null || adhan == null
          ? const Center(child: OrbitLoader())
          : SettingsListView(
              children: [
                StaggerIn(
                  id: 'iqama-settings',
                  fade: false,
                  children: [
                    const SizedBox(height: Space.s),
                    _PrayersSection(settings: settings, adhan: adhan),
                    _SoundSection(settings: settings, adhan: adhan),
                  ],
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PrayersSection extends ConsumerWidget {
  const _PrayersSection({required this.settings, required this.adhan});

  final IqamaSettings settings;
  final AdhanSettings adhan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final texts = ref.watch(iqamaTextsProvider);
    final times = ref.watch(adhanTimesProvider);
    final now = ref.watch(homeNowProvider);
    final today = times.timesFor(times.localDayOf(now));
    final controller = ref.read(iqamaSettingsProvider.notifier);

    String subtitle(AdhanSlot slot, IqamaPrayer iqama) {
      final at = today[slot];
      final adhanOn = adhan.alertOf(slot).adhan;
      return <String>[
        if (at != null && iqama.on && adhanOn) texts.time(at.add(Duration(minutes: iqama.minutes))),
        if (!iqama.on) l.iqamaOff else if (!adhanOn) l.iqamaAdhanOff else texts.delay(iqama.minutes),
      ].join(l.commonFactSeparator);
    }

    Widget row({required AdhanSlot slot, required bool jumuah}) {
      final iqama = jumuah ? settings.jumuah : settings.of(slot);
      final title = jumuah ? l.iqamaJumuah : texts.prayer(slot);
      return SettingsTile(
        key: ValueKey(jumuah ? 'iqama-jumuah' : 'iqama-${slot.name}'),
        icon: jumuah ? Icons.mosque_rounded : adhanSlotIcon(slot),
        title: title,
        subtitle: jumuah ? '${l.iqamaJumuahHint}${l.commonFactSeparator}${texts.delay(iqama.minutes)}' : subtitle(slot, iqama),
        onTap: () => unawaited(_edit(context, ref, slot: slot, jumuah: jumuah, texts: texts)),
        trailing: MadarSwitch(
          value: iqama.on,
          semanticLabel: jumuah ? l.iqamaJumuah : l.iqamaPrayerLabel(texts.prayer(slot)),
          onChanged: (v) => unawaited(
            controller.change(
              (s) => jumuah ? s.copyWith(jumuah: s.jumuah.copyWith(on: v)) : s.withPrayer(slot, s.of(slot).copyWith(on: v)),
            ),
          ),
        ),
      );
    }

    return SettingsSection(
      title: l.iqamaSectionPrayers,
      subtitle: l.iqamaSectionPrayersHint,
      seed: 0.2,
      children: [
        for (final slot in AdhanSlot.prayers) row(slot: slot, jumuah: false),
        row(slot: AdhanSlot.dhuhr, jumuah: true),
        SettingsNote(l.iqamaNote),
      ],
    );
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required AdhanSlot slot,
    required bool jumuah,
    required IqamaTexts texts,
  }) async {
    final l = L10n.of(context);
    final settings = ref.read(iqamaSettingsProvider).value ?? const IqamaSettings();
    final current = jumuah ? settings.jumuah : settings.of(slot);
    final values = await showEditSheet(
      context,
      title: jumuah ? l.iqamaJumuah : l.iqamaPrayerLabel(texts.prayer(slot)),
      icon: jumuah ? Icons.mosque_rounded : adhanSlotIcon(slot),
      fields: [
        FieldSpec.toggle('on', l.iqamaFieldOn, icon: Icons.campaign_rounded),
        FieldSpec.singleSelect(
          'after',
          l.iqamaFieldOffset,
          icon: Icons.schedule_rounded,
          options: [
            for (final m in IqamaSettings.minuteChoices)
              SelectOption(id: '$m', label: m == 0 ? l.iqamaWithAdhan : texts.minutesShort(m)),
          ],
        ),
      ],
      initial: {'on': current.on, 'after': '${current.minutes}'},
    );
    if (values == null) return;
    final on = values['on'] as bool? ?? current.on;
    final minutes = int.tryParse('${values['after']}') ?? current.minutes;
    final next = IqamaPrayer(on: on, minutes: IqamaSettings.clampMinutes(minutes));
    await ref
        .read(iqamaSettingsProvider.notifier)
        .change((s) => jumuah ? s.copyWith(jumuah: next) : s.withPrayer(slot, next));
  }
}

// ---------------------------------------------------------------------------

class _SoundSection extends ConsumerWidget {
  const _SoundSection({required this.settings, required this.adhan});

  final IqamaSettings settings;
  final AdhanSettings adhan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final texts = ref.watch(iqamaTextsProvider);
    final controller = ref.read(iqamaSettingsProvider.notifier);
    final sound = settings.resolve(adhan.muezzins);
    final options = <ChoiceOption<String>>[
      for (final tone in TanbihTone.values)
        ChoiceOption(value: AdhanSoundRef.tone(tone).key, label: texts.toneName(tone)),
      for (final m in adhan.muezzins) ChoiceOption(value: AdhanSoundRef.file(m.id).key, label: m.name),
      ChoiceOption(value: const AdhanSoundRef.silent().key, label: texts.l10n.adhanSilent),
    ];
    return SettingsSection(
      title: l.iqamaSectionSound,
      subtitle: l.iqamaSectionSoundHint,
      seed: 0.5,
      children: [
        SettingsChoiceTile<String>(
          icon: Icons.campaign_rounded,
          title: l.iqamaSound,
          subtitle: texts.soundName(sound, muezzin: adhan.muezzinById(sound.fileId)),
          options: options,
          selected: sound.key,
          onChanged: (key) {
            final ref0 = AdhanSoundRef.parse(key);
            if (ref0 != null) unawaited(controller.change((s) => s.copyWith(sound: ref0)));
          },
        ),
        SettingsSwitchTile(
          icon: Icons.vibration_rounded,
          title: l.iqamaVibrate,
          value: settings.vibrate,
          onChanged: (v) => unawaited(controller.change((s) => s.copyWith(vibrate: v))),
        ),
        SettingsChoiceTile<int>(
          icon: Icons.snooze_rounded,
          title: l.iqamaSnoozeLength,
          subtitle: l.iqamaSnoozeHint,
          options: [for (final m in IqamaSettings.snoozeChoices) ChoiceOption(value: m, label: texts.minutesShort(m))],
          selected: settings.snoozeMinutes,
          onChanged: (v) => unawaited(controller.change((s) => s.copyWith(snoozeMinutes: v))),
        ),
      ],
    );
  }
}
