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
import '../../settings/widgets/settings_widgets.dart';
import '../application/recitation_actions.dart';
import '../application/recitation_providers.dart';
import '../domain/recitation_settings.dart';
import '../domain/reciters.dart';
import 'now_playing_bar.dart';
import 'recitation_downloads_screen.dart';
import 'recitation_labels.dart';
import 'widgets/reciter_row.dart';

/// Recitation settings: the reciter (with a sample and the full picker),
/// repetition defaults, pause between repetitions, speed, the basmala, and
/// offline downloads (whole mushaf or chosen surahs, Wi-Fi only, storage
/// used, other reciters' downloads).
///
/// Route widget (`/settings/recitation` is the lead's to register).
class RecitationSettingsScreen extends ConsumerWidget {
  const RecitationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final battery = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final settings = ref.watch(recitationSettingsProvider).value;
    return MadarScaffold(
      title: l.recitationTitle,
      extendBodyBehindAppBar: true,
      animateBackdrop: !battery,
      backdropSeed: 0.53,
      bottomBar: const NowPlayingBar(),
      body: settings == null
          ? const Center(child: OrbitLoader())
          : SettingsListView(
              children: [
                StaggerIn(
                  id: 'recitation-settings',
                  fade: false,
                  children: [
                    const SizedBox(height: Space.s),
                    _ReciterHero(settings: settings),
                    _PlaybackSection(settings: settings),
                    _DownloadsSection(settings: settings),
                    SettingsNote(l.recitationSourceCredit, icon: Icons.volunteer_activism_outlined),
                  ],
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ReciterHero extends ConsumerWidget {
  const _ReciterHero({required this.settings});

  final RecitationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    ref.watch(recitationStateProvider);
    ref.watch(recitationDownloadsTickProvider);
    final reciter = settings.reciter;
    final player = ref.read(recitationPlayerProvider);
    final sampling = player.isSampleOf(reciter);
    final downloads = ref.read(recitationDownloadsProvider).summaryOf(reciter.id);
    final name = reciter.name(arabic: fmt.isArabic);
    return GlassPanel(
      glowColor: t.accentGlow,
      seed: 0.12,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Seal(style: reciter.style, active: sampling),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.recitationReciterLabel, style: text.labelMedium!.copyWith(color: t.textTertiary)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(name, style: text.headlineSmall!.copyWith(color: t.gold), maxLines: 1),
                    ),
                    const SizedBox(height: Space.xxs),
                    Text(
                      [
                        RecitationLabels.style(l, reciter.style),
                        RecitationLabels.bitrate(l, fmt, reciter),
                      ].join(l.commonFactSeparator),
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                    ),
                    Text(
                      downloads.wholeMushaf
                          ? l.recitationWholeMushafDownloaded
                          : fmt.localizeDigits(l.recitationSurahsDownloaded(downloads.completeSurahs)),
                      style: text.bodySmall!.copyWith(color: downloads.completeSurahs > 0 ? t.success : t.textTertiary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Text(
            RecitationLabels.styleHint(l, reciter.style),
            style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.4),
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(
                child: MadarButton(
                  label: sampling ? l.recitationSampleStop : l.recitationSample,
                  icon: sampling ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  onPressed: () => unawaited(RecitationActions.toggleSample(ref, reciter)),
                  variant: sampling ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
                  size: MadarButtonSize.small,
                  semanticLabel: sampling ? l.recitationSampleStop : l.recitationSampleOf(name),
                ),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: MadarButton(
                  label: l.recitationChangeReciter,
                  icon: Icons.record_voice_over_rounded,
                  onPressed: () => unawaited(_pick(context)),
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) =>
      showInteractionSheet<void>(context, builder: (_) => const _ReciterSheet());
}

/// The reciter picker from settings: samples on.
class _ReciterSheet extends ConsumerWidget {
  const _ReciterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final chosen = ref.watch(recitationReciterProvider);
    return InteractionSheetFrame(
      title: l.recitationSectionReciters,
      subtitle: l.recitationSectionRecitersHint,
      icon: Icons.record_voice_over_rounded,
      footer: SheetButton(label: l.actionDone, primary: true, onPressed: () => Navigator.of(context).maybePop()),
      body: ReciterList(selected: chosen, onSelect: (r) => unawaited(RecitationActions.chooseReciter(ref, r))),
    );
  }
}

/// A small astrolabe seal: an engraved ring around an eight-pointed star,
/// turning while the sample plays.
class _Seal extends StatelessWidget {
  const _Seal({required this.style, required this.active});

  final ReciterStyle style;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduced = context.reducedMotion;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: active && !reduced ? 1 : 0),
      duration: context.motion(MadarMotion.cinematic),
      curve: MadarMotion.orbital,
      builder: (context, turn, _) => AstrolabeRing(
        size: 84,
        rotation: turn * 3.14159,
        showNumerals: false,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.accentSoft,
            border: Border.all(color: t.brass.withValues(alpha: 0.6), width: 0.8),
          ),
          child: Icon(RecitationLabels.styleIcon(style), color: t.gold, size: 22),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PlaybackSection extends ConsumerWidget {
  const _PlaybackSection({required this.settings});

  final RecitationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    Future<void> change(RecitationSettings Function(RecitationSettings) f) => RecitationActions.changeSettings(ref, f);
    return SettingsSection(
      title: l.recitationSectionPlayback,
      subtitle: l.recitationSectionPlaybackHint,
      seed: 0.3,
      children: [
        SettingsChoiceTile<int>(
          icon: Icons.repeat_one_rounded,
          title: l.recitationRepeatAyah,
          options: [
            for (final n in RecitationSettings.repeatChoices)
              ChoiceOption(value: n, label: RecitationLabels.times(l, fmt, n)),
          ],
          selected: settings.repeatAyah,
          onChanged: (v) => unawaited(change((s) => s.copyWith(repeatAyah: v))),
        ),
        SettingsChoiceTile<int>(
          icon: Icons.repeat_rounded,
          title: l.recitationRepeatRange,
          options: [
            for (final n in RecitationSettings.rangeRepeatChoices)
              ChoiceOption(value: n, label: RecitationLabels.times(l, fmt, n)),
          ],
          selected: settings.repeatRange,
          onChanged: (v) => unawaited(change((s) => s.copyWith(repeatRange: v))),
        ),
        SettingsChoiceTile<int>(
          icon: Icons.hourglass_bottom_rounded,
          title: l.recitationGap,
          subtitle: l.recitationGapHint,
          options: [
            for (final n in RecitationSettings.gapChoices)
              ChoiceOption(value: n, label: n == 0 ? l.recitationGapNone : fmt.localizeDigits(l.recitationSeconds(n))),
          ],
          selected: settings.gapSeconds,
          onChanged: (v) => unawaited(change((s) => s.copyWith(gapSeconds: v))),
        ),
        SettingsChoiceTile<double>(
          icon: Icons.speed_rounded,
          title: l.recitationSpeed,
          options: [
            for (final s in RecitationSettings.speedChoices)
              ChoiceOption(value: s, label: RecitationLabels.speed(l, fmt, s)),
          ],
          selected: settings.speed,
          onChanged: (v) => unawaited(RecitationActions.setSpeed(ref, v)),
        ),
        SettingsSwitchTile(
          icon: Icons.auto_awesome_outlined,
          title: l.recitationBasmala,
          subtitle: l.recitationBasmalaHint,
          value: settings.basmala,
          onChanged: (v) => unawaited(change((s) => s.copyWith(basmala: v))),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _DownloadsSection extends ConsumerWidget {
  const _DownloadsSection({required this.settings});

  final RecitationSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    ref.watch(recitationDownloadsTickProvider);
    final downloads = ref.read(recitationDownloadsProvider);
    final reciter = settings.reciter;
    final others = [
      for (final id in downloads.reciterIds)
        if (id != reciter.id) Reciters.byId(id),
    ];
    return SettingsSection(
      title: l.recitationSectionDownloads,
      subtitle: l.recitationSectionDownloadsHint,
      seed: 0.6,
      children: [
        _MushafTile(reciter: reciter),
        SettingsTile(
          icon: Icons.format_list_numbered_rtl_rounded,
          title: l.recitationChooseSurahs,
          subtitle: l.recitationDownloadsTitle(reciter.name(arabic: fmt.isArabic)),
          navigates: true,
          onTap: () => unawaited(openRecitationDownloads(context, reciter)),
        ),
        SettingsSwitchTile(
          icon: Icons.wifi_rounded,
          title: l.recitationWifiOnly,
          subtitle: l.recitationWifiOnlyHint,
          value: settings.wifiOnly,
          onChanged: (v) => unawaited(RecitationActions.changeSettings(ref, (s) => s.copyWith(wifiOnly: v))),
        ),
        SettingsTile(
          icon: Icons.sd_storage_outlined,
          title: l.recitationStorageUsed(RecitationLabels.size(l, fmt, downloads.totalBytes)),
          subtitle: others.isEmpty ? null : l.recitationOtherDownloads,
        ),
        for (final other in others) _OtherReciterTile(reciter: other),
      ],
    );
  }
}

/// The whole mushaf of the chosen reciter: download / pause / resume, with
/// progress in surahs and bytes.
class _MushafTile extends ConsumerWidget {
  const _MushafTile({required this.reciter});

  final Reciter reciter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    ref.watch(recitationDownloadsTickProvider);
    final downloads = ref.read(recitationDownloadsProvider);
    final s = downloads.summaryOf(reciter.id);
    final name = reciter.name(arabic: fmt.isArabic);
    final progress = s.completeSurahs / 114;
    final lines = <String>[
      if (s.completeSurahs == 0 && s.active == 0)
        [
          l.recitationAbout(RecitationLabels.size(l, fmt, reciter.approxMushafBytes)),
          RecitationLabels.bitrate(l, fmt, reciter),
        ].join(l.commonFactSeparator)
      else
        [
          l.recitationSurahProgress(fmt.formatInt(s.completeSurahs), fmt.formatInt(114)),
          RecitationLabels.size(l, fmt, s.bytes),
        ].join(l.commonFactSeparator),
      if (s.active > 0) l.recitationStatusDownloading else if (s.paused > 0) l.recitationStatusPaused,
    ];

    final Widget action;
    if (s.wholeMushaf) {
      action = Icon(Icons.download_done_rounded, color: t.success);
    } else if (s.active > 0) {
      action = MadarButton.icon(
        icon: Icons.pause_rounded,
        onPressed: () => unawaited(downloads.pauseAll()),
        semanticLabel: l.recitationPauseDownloads,
        variant: MadarButtonVariant.secondary,
        size: MadarButtonSize.small,
      );
    } else {
      action = MadarButton(
        label: s.paused > 0 ? l.recitationResumeDownloads : l.recitationDownloadMushaf,
        icon: s.paused > 0 ? Icons.play_arrow_rounded : Icons.download_rounded,
        onPressed: () =>
            unawaited(s.paused > 0 ? downloads.resumeAll(reciter: reciter) : downloads.downloadMushaf(reciter)),
        size: MadarButtonSize.small,
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          ProgressRing(
            value: progress,
            size: 40,
            strokeWidth: 3,
            color: t.metalGold,
            gradientEnd: t.accent,
            trackColor: t.brassDark.withValues(alpha: 0.4),
            glow: s.active > 0,
            child: Icon(Icons.menu_book_rounded, size: 18, color: t.gold),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.recitationMushafFor(name), style: text.titleMedium!.copyWith(height: 1.3)),
                for (final line in lines)
                  Text(line, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          action,
        ],
      ),
    );
  }
}

class _OtherReciterTile extends ConsumerWidget {
  const _OtherReciterTile({required this.reciter});

  final Reciter reciter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final downloads = ref.read(recitationDownloadsProvider);
    final s = downloads.summaryOf(reciter.id);
    final name = reciter.name(arabic: fmt.isArabic);
    return SettingsTile(
      icon: RecitationLabels.styleIcon(reciter.style),
      title: '$name (${RecitationLabels.style(l, reciter.style)})',
      subtitle: [
        fmt.localizeDigits(l.recitationSurahsDownloaded(s.completeSurahs)),
        RecitationLabels.size(l, fmt, s.bytes),
      ].join(l.commonFactSeparator),
      onTap: () => unawaited(openRecitationDownloads(context, reciter)),
      trailing: MadarButton.icon(
        icon: Icons.delete_outline_rounded,
        onPressed: () => unawaited(confirmDeleteReciter(context, ref, reciter)),
        semanticLabel: l.recitationDeleteDownloads,
        variant: MadarButtonVariant.ghost,
        size: MadarButtonSize.small,
        sfx: Sfx.delete,
      ),
    );
  }
}

/// Asks, then deletes all of [reciter]'s downloads.
Future<void> confirmDeleteReciter(BuildContext context, WidgetRef ref, Reciter reciter) async {
  final l = L10n.of(context);
  final fmt = MadarFormatter.of(context);
  final downloads = ref.read(recitationDownloadsProvider);
  final ok = await confirmRecitationDelete(
    context,
    title: l.recitationDeleteConfirm(reciter.name(arabic: fmt.isArabic)),
    body: l.recitationDeleteConfirmHint(RecitationLabels.size(l, fmt, downloads.summaryOf(reciter.id).bytes)),
  );
  if (ok) {
    Fx.fire(Sfx.delete);
    await downloads.delete(reciter);
  }
}

/// A small confirmation sheet for deleting downloads.
Future<bool> confirmRecitationDelete(BuildContext context, {required String title, required String body}) async {
  final result = await showInteractionSheet<bool>(
    context,
    builder: (context) {
      final t = context.tokens;
      final l = L10n.of(context);
      return InteractionSheetFrame(
        title: title,
        icon: Icons.delete_outline_rounded,
        body: Text(body, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.textSecondary)),
        footer: Row(
          children: [
            Expanded(
              child: SheetButton(
                label: l.actionCancel,
                sfx: Sfx.back,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: SheetButton(
                label: l.actionDelete,
                primary: true,
                tone: t.danger,
                icon: Icons.delete_outline_rounded,
                sfx: null,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      );
    },
  );
  return result ?? false;
}
