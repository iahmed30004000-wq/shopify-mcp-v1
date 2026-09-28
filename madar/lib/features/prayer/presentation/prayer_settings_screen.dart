import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../application/prayer_providers.dart';
import '../application/prayer_settings_controller.dart';
import '../domain/prayer_clock.dart';
import '../domain/prayer_day.dart';
import '../domain/settings_changes.dart';
import 'location_sheet.dart';
import 'prayer_labels.dart';
import 'widgets/prayer_widgets.dart';

/// Prayer time settings: location, calculation method (with custom angles),
/// Asr, high latitudes, per-prayer minute adjustments, the Hijri date
/// (offset and Maghrib rollover) and the 12/24-hour clock – with today's
/// times updating live at the top.
class PrayerSettingsScreen extends ConsumerWidget {
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final s = ref.watch(prayerSettingsControllerProvider);
    final c = ref.read(prayerSettingsControllerProvider.notifier);
    final lang = Localizations.localeOf(context).languageCode;
    final cities = ref.watch(cityDatabaseProvider).value;
    final now = ref.watch(prayerClockProvider)();
    final power = ref.watch(appSettingsProvider.select((a) => a.powerMode));
    final custom = s.method == PrayerMethod.custom;
    final useInterval = custom && (s.ishaIntervalMin ?? 0) > 0;

    final source = switch (s.locationSource) {
      PrayerLocationSource.gps => l.ptSourceGps,
      PrayerLocationSource.city => l.ptSourceCity,
      PrayerLocationSource.defaultCity => l.ptSourceDefault,
    };

    return MadarScaffold(
      title: l.ptSettingsTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: power != PowerMode.batterySaver,
      backdropSeed: 0.41,
      body: SettingsListView(
        children: [
          StaggerIn(
            id: 'prayer-settings',
            fade: false,
            children: [
              const _LivePreview(),
              SettingsSection(
                title: l.ptSectionLocation,
                seed: 0.12,
                children: [
                  SettingsTile(
                    icon: s.locationSource == PrayerLocationSource.gps
                        ? Icons.my_location_rounded
                        : Icons.location_on_rounded,
                    title: l.placeLabel(s, lang, cities: cities),
                    subtitle: '$source\n${l.zoneLabel(s, now, fmt)}',
                    navigates: true,
                    onTap: () => showPrayerLocationSheet(context),
                  ),
                ],
              ),
              SettingsSection(
                title: l.ptSectionMethod,
                subtitle: l.ptSectionMethodHint,
                seed: 0.24,
                children: [
                  SettingsTile(
                    icon: Icons.architecture_rounded,
                    title: l.methodName(s.method),
                    subtitle: l.methodSummary(s, fmt),
                    navigates: true,
                    onTap: () async {
                      final m = await showMethodSheet(context, current: s.method, countryCode: s.countryCode);
                      if (m == null || m == s.method) return;
                      final before = await c.setMethod(m);
                      if (!context.mounted) return;
                      unawaited(
                        showUndoToast(
                          context,
                          UndoableAction(label: l.ptMethodChanged(l.methodName(m)), undo: () => c.restore(before)),
                        ),
                      );
                    },
                  ),
                  if (custom) ...[
                    _StepperTile(
                      icon: Icons.wb_twilight_rounded,
                      title: l.ptCustomFajrAngle,
                      value: l.degrees(s.fajrAngle, fmt),
                      valueAfter: (d) => l.degrees(s.fajrAngle + d * PrayerSettingsChanges.angleStep, fmt),
                      canDecrement: s.fajrAngle > PrayerSettingsChanges.minAngle,
                      canIncrement: s.fajrAngle < PrayerSettingsChanges.maxAngle,
                      onChanged: (d) => c.setFajrAngle(s.fajrAngle + d * PrayerSettingsChanges.angleStep),
                    ),
                    SettingsSwitchTile(
                      icon: Icons.timelapse_rounded,
                      title: l.ptCustomIshaByInterval,
                      value: useInterval,
                      onChanged: (v) => c.setIshaInterval(v ? 90 : null),
                    ),
                    if (useInterval)
                      _StepperTile(
                        icon: Icons.dark_mode_rounded,
                        title: l.ptCustomIshaInterval,
                        value: l.ptMinutesSigned(fmt.formatInt(s.ishaIntervalMin!)),
                        valueAfter: (d) => l.ptMinutesSigned(fmt.formatInt(s.ishaIntervalMin! + d * 5)),
                        canDecrement: s.ishaIntervalMin! > PrayerSettingsChanges.minIshaInterval,
                        canIncrement: s.ishaIntervalMin! < PrayerSettingsChanges.maxIshaInterval,
                        onChanged: (d) => c.setIshaInterval(s.ishaIntervalMin! + d * 5),
                      )
                    else
                      _StepperTile(
                        icon: Icons.dark_mode_rounded,
                        title: l.ptCustomIshaAngle,
                        value: l.degrees(s.ishaAngle, fmt),
                        valueAfter: (d) => l.degrees(s.ishaAngle + d * PrayerSettingsChanges.angleStep, fmt),
                        canDecrement: s.ishaAngle > PrayerSettingsChanges.minAngle,
                        canIncrement: s.ishaAngle < PrayerSettingsChanges.maxAngle,
                        onChanged: (d) => c.setIshaAngle(s.ishaAngle + d * PrayerSettingsChanges.angleStep),
                      ),
                  ],
                ],
              ),
              SettingsSection(
                title: l.ptSectionAsr,
                seed: 0.36,
                children: [
                  SettingsChoiceTile<bool>(
                    icon: Icons.brightness_5_rounded,
                    title: l.ptAsrRule,
                    options: [
                      ChoiceOption(value: false, label: l.ptAsrStandard),
                      ChoiceOption(value: true, label: l.ptAsrHanafi),
                    ],
                    selected: s.hanafiAsr,
                    onChanged: c.setHanafiAsr,
                    footer: SettingsNote(l.ptAsrNote),
                  ),
                ],
              ),
              SettingsSection(
                title: l.ptSectionAdjustments,
                subtitle: l.ptAdjustmentsNote,
                seed: 0.48,
                children: [
                  for (final key in PrayerAdjustmentKeys.all) _AdjustmentTile(adjustmentKey: key),
                  if (s.adjustmentsMin.values.any((v) => v != 0))
                    SettingsTile(
                      icon: Icons.restart_alt_rounded,
                      title: l.ptResetAdjustments,
                      iconColor: context.tokens.warning,
                      onTap: () async {
                        final before = await c.resetAdjustments();
                        Fx.fire(Sfx.delete);
                        if (!context.mounted) return;
                        unawaited(
                          showUndoToast(
                            context,
                            UndoableAction(label: l.ptAdjustmentsReset, undo: () => c.restore(before)),
                          ),
                        );
                      },
                    ),
                ],
              ),
              SettingsSection(
                title: l.ptSectionHijri,
                seed: 0.6,
                children: [
                  _StepperTile(
                    icon: Icons.nightlight_round,
                    title: l.ptHijriOffset,
                    subtitle: l.hijriDate(ref.watch(hijriDateProvider(now)), fmt),
                    value: _dayOffset(l, fmt, s.hijriOffsetDays),
                    valueAfter: (d) => _dayOffset(l, fmt, s.hijriOffsetDays + d),
                    canDecrement: s.hijriOffsetDays > -PrayerSettingsChanges.maxHijriOffset,
                    canIncrement: s.hijriOffsetDays < PrayerSettingsChanges.maxHijriOffset,
                    onChanged: (d) => c.setHijriOffset(s.hijriOffsetDays + d),
                  ),
                  SettingsNote(l.ptHijriOffsetNote),
                  SettingsSwitchTile(
                    icon: Icons.nights_stay_outlined,
                    title: l.ptHijriAtMaghrib,
                    subtitle: l.ptHijriAtMaghribHint,
                    value: s.hijriAtMaghrib,
                    onChanged: c.setHijriAtMaghrib,
                  ),
                ],
              ),
              SettingsSection(
                title: l.ptSectionHighLat,
                seed: 0.72,
                children: [
                  SettingsChoiceTile<HighLatitudeMode>(
                    icon: Icons.public_rounded,
                    title: l.ptHighLatRule,
                    options: [
                      for (final m in HighLatitudeMode.values) ChoiceOption(value: m, label: l.highLatitudeName(m)),
                    ],
                    selected: s.highLatitude,
                    onChanged: c.setHighLatitude,
                    footer: SettingsNote(l.ptHighLatNote(l.degrees(48, fmt))),
                  ),
                ],
              ),
              SettingsSection(
                title: l.ptSectionDisplay,
                seed: 0.84,
                children: [
                  SettingsChoiceTile<bool>(
                    icon: Icons.schedule_rounded,
                    title: l.ptClockFormat,
                    options: [
                      ChoiceOption(value: false, label: l.ptClockHours(fmt.formatInt(12))),
                      ChoiceOption(value: true, label: l.ptClockHours(fmt.formatInt(24))),
                    ],
                    selected: s.clock24h,
                    onChanged: c.setClock24h,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _dayOffset(L10n l, MadarFormatter fmt, int days) =>
    days == 0 ? l.ptNoAdjustment : l.ptDayUnit(l.signedMinutes(days, fmt));

/// Today's six times, updating the moment a setting changes.
class _LivePreview extends ConsumerWidget {
  const _LivePreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final s = ref.watch(prayerSettingsControllerProvider);
    final schedule = ref.watch(prayerLiveScheduleProvider);
    final now = ref.watch(prayerClockProvider)();
    final day = PrayerTimesDay.of(schedule, schedule.dateOf(now));
    final clock = prayerClockOf(context, s);
    const shown = [
      PrayerMoment.fajr,
      PrayerMoment.sunrise,
      PrayerMoment.dhuhr,
      PrayerMoment.asr,
      PrayerMoment.maghrib,
      PrayerMoment.isha,
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.m),
      child: GlassPanel(
        seed: 0.05,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IslamicStar(size: 14, color: t.gold, glow: true),
                const SizedBox(width: Space.s),
                Expanded(child: Text(l.ptPreviewTitle, style: text.titleMedium)),
                Flexible(
                  child: HijriDateText(
                    style: text.bodySmall!.copyWith(color: t.gold),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            Text(l.ptPreviewHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
            const SizedBox(height: Space.m),
            LayoutBuilder(
              builder: (context, box) {
                final w = (box.maxWidth - 2 * Space.s) / 3;
                return Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (final m in shown)
                      SizedBox(
                        width: w,
                        child: _PreviewCell(
                          icon: momentIcon(m),
                          label: l.momentName(m),
                          time: clock.format(schedule.wallClock(day.timeOf(m))),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({required this.icon, required this.label, required this.time});

  final IconData icon;
  final String label;
  final PrayerClockText time;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s, horizontal: Space.s),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusS),
        color: t.space2.withValues(alpha: t.isDark ? 0.35 : 0.5),
        border: Border.all(color: t.glassBorder.withValues(alpha: 0.5), width: 0.6),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: t.textTertiary),
              const SizedBox(width: Space.xxs),
              Flexible(
                child: Text(label, style: text.labelSmall!.copyWith(color: t.textSecondary), maxLines: 1),
              ),
            ],
          ),
          const SizedBox(height: Space.xxs),
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.medium),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: FittedBox(key: ValueKey(time.joined), fit: BoxFit.scaleDown, child: PrayerTimeText(time, size: 17)),
          ),
        ],
      ),
    );
  }
}

/// A settings row with a [ValueStepper] at its end.
class _StepperTile extends StatelessWidget {
  const _StepperTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.canDecrement = true,
    this.canIncrement = true,
    this.valueAfter,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String value;
  final String Function(int delta)? valueAfter;
  final ValueChanged<int> onChanged;
  final bool canDecrement;
  final bool canIncrement;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final t = context.tokens;
    final stepper = ValueStepper(
      value: value,
      valueAfter: valueAfter,
      label: title,
      canDecrement: canDecrement,
      canIncrement: canIncrement,
      onChanged: onChanged,
    );
    final heading = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: text.titleMedium!.copyWith(height: 1.3)),
          if (subtitle != null) Text(subtitle!, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.35)),
        ],
      ),
    );
    // Large text: the stepper no longer fits beside the title – it moves
    // under it, to the row's end.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.s, Space.s),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SettingsIcon(icon),
                    const SizedBox(width: Space.m),
                    heading,
                  ],
                ),
                const SizedBox(height: Space.xs),
                Align(alignment: AlignmentDirectional.centerEnd, child: stepper),
              ],
            )
          : Row(
              children: [
                SettingsIcon(icon),
                const SizedBox(width: Space.m),
                heading,
                stepper,
              ],
            ),
    );
  }
}

/// One prayer's minute adjustment, with the adjusted time beside its name.
class _AdjustmentTile extends ConsumerWidget {
  const _AdjustmentTile({required this.adjustmentKey});

  final String adjustmentKey;

  PrayerMoment get _moment => switch (adjustmentKey) {
    PrayerAdjustmentKeys.fajr => PrayerMoment.fajr,
    PrayerAdjustmentKeys.sunrise => PrayerMoment.sunrise,
    PrayerAdjustmentKeys.dhuhr => PrayerMoment.dhuhr,
    PrayerAdjustmentKeys.asr => PrayerMoment.asr,
    PrayerAdjustmentKeys.maghrib => PrayerMoment.maghrib,
    _ => PrayerMoment.isha,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final s = ref.watch(prayerSettingsControllerProvider);
    final schedule = ref.watch(prayerLiveScheduleProvider);
    final now = ref.watch(prayerClockProvider)();
    final day = PrayerTimesDay.of(schedule, schedule.dateOf(now));
    final v = s.adjustmentsMin[adjustmentKey] ?? 0;
    final time = prayerClockOf(context, s).format(schedule.wallClock(day.timeOf(_moment)));
    return _StepperTile(
      icon: momentIcon(_moment),
      title: l.momentName(_moment),
      subtitle: time.joined,
      value: l.ptMinutesSigned(l.signedMinutes(v, fmt)),
      valueAfter: (d) => l.ptMinutesSigned(l.signedMinutes(v + d, fmt)),
      canDecrement: v > -PrayerSettingsChanges.maxAdjustment,
      canIncrement: v < PrayerSettingsChanges.maxAdjustment,
      onChanged: (d) => ref.read(prayerSettingsControllerProvider.notifier).setAdjustment(adjustmentKey, v + d),
    );
  }
}

/// The preset a location's country usually follows (null: none specific).
PrayerMethod? suggestedMethodFor(String? countryCode) => switch (countryCode) {
  'JO' => PrayerMethod.jordan,
  'SA' => PrayerMethod.ummAlQura,
  'EG' => PrayerMethod.egyptian,
  'AE' => PrayerMethod.dubai,
  'KW' => PrayerMethod.kuwait,
  'QA' => PrayerMethod.qatar,
  'TR' => PrayerMethod.turkiye,
  'SG' || 'MY' || 'BN' => PrayerMethod.singapore,
  'ID' => PrayerMethod.indonesian,
  'IR' => PrayerMethod.tehran,
  'PK' || 'IN' || 'BD' || 'AF' => PrayerMethod.karachi,
  'US' || 'CA' => PrayerMethod.northAmerica,
  'GB' || 'IE' => PrayerMethod.moonsightingCommittee,
  'DZ' => PrayerMethod.algerian,
  'MA' => PrayerMethod.morocco,
  'TN' => PrayerMethod.tunisia,
  'FR' => PrayerMethod.france,
  'RU' => PrayerMethod.russia,
  _ => null,
};

/// Picks a calculation method (the suggestion for the location's country
/// first, then the rest).
Future<PrayerMethod?> showMethodSheet(BuildContext context, {required PrayerMethod current, String? countryCode}) =>
    showInteractionSheet<PrayerMethod>(
      context,
      builder: (_) => _MethodSheet(current: current, suggested: suggestedMethodFor(countryCode)),
    );

class _MethodSheet extends StatelessWidget {
  const _MethodSheet({required this.current, required this.suggested});

  final PrayerMethod current;
  final PrayerMethod? suggested;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final ordered = [
      ?suggested,
      for (final m in PrayerMethod.values)
        if (m != suggested) m,
    ];
    return InteractionSheetFrame(
      title: l.ptMethodSheetTitle,
      subtitle: l.ptSectionMethodHint,
      icon: Icons.architecture_rounded,
      scrollable: false,
      bodyPadding: EdgeInsetsDirectional.zero,
      body: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.l),
          children: [
            for (final m in ordered)
              _MethodRow(
                method: m,
                selected: m == current,
                suggested: m == suggested,
                isDefault: m == PrayerMethod.jordan,
                onTap: () => Navigator.of(context).pop(m),
              ),
          ],
        ),
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.method,
    required this.selected,
    required this.suggested,
    required this.isDefault,
    required this.onTap,
  });

  final PrayerMethod method;
  final bool selected;
  final bool suggested;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final summary = method == PrayerMethod.custom
        ? l.ptMethodCustomHint
        : l.methodSummary(PrayerSettings(method: method), fmt);
    Widget badge(String label, Color color) => Container(
      margin: const EdgeInsetsDirectional.only(end: Space.xs, top: Space.xxs),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusS),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.7),
      ),
      child: Text(label, style: text.labelSmall!.copyWith(color: color)),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
      child: MadarPressable(
        onTap: onTap,
        sfx: Sfx.toggleOn,
        selected: selected,
        semanticLabel: '${l.methodName(method)}. $summary',
        excludeChildSemantics: true,
        pressScale: 0.985,
        focusRadius: BorderRadius.circular(t.radiusM),
        child: AnimatedContainer(
          duration: context.motion(MadarMotion.short),
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: selected ? t.accent.withValues(alpha: 0.12) : t.glassFill,
            border: Border.all(
              color: selected ? t.accent.withValues(alpha: 0.7) : t.glassBorder.withValues(alpha: 0.6),
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 2),
                child: Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: selected ? t.accent : t.textTertiary,
                ),
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.methodName(method), style: text.titleMedium),
                    const SizedBox(height: Space.xxs),
                    Text(summary, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.4)),
                    if (suggested || isDefault)
                      Wrap(
                        children: [
                          if (suggested) badge(l.ptMethodSuggested, t.success),
                          if (isDefault) badge(l.ptMethodDefault, t.gold),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
