import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../application/recitation_actions.dart';
import '../application/recitation_providers.dart';
import '../domain/recitation_settings.dart';
import '../domain/recitation_state.dart';
import 'recitation_labels.dart';
import 'widgets/recitation_dial.dart';
import 'widgets/reciter_row.dart';

/// Opens the full player over the current screen.
Future<void> showNowPlayingSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const NowPlayingSheet());

/// The full player: the astrolabe dial (passage progress, the ayah's own
/// progress, one bead per ayah), surah and ayah, the ayah's text,
/// previous / play-pause / next, repetitions of the ayah and the passage,
/// speed, sleep timer and the reciter. Closes itself when the recitation
/// ends.
class NowPlayingSheet extends ConsumerWidget {
  const NowPlayingSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final state = ref.watch(recitationStateProvider);
    final catalog = ref.watch(recitationCatalogProvider).value;
    ref.listen(recitationStateProvider.select((s) => s.active), (was, now) {
      if (was == true && !now) unawaited(Navigator.of(context).maybePop());
    });
    final player = ref.read(recitationPlayerProvider);
    final range = state.range;
    String where(AyahRef a) => '${recitationSurahName(catalog, a.surah, l, fmt)} ${fmt.formatInt(a.ayah)}';
    return InteractionSheetFrame(
      title: l.recitationNowPlaying,
      subtitle: range == null
          ? null
          : range.first == range.last
          ? where(range.first)
          : range.first.surah == range.last.surah
          ? l.recitationRangeInSurah(
              recitationSurahName(catalog, range.first.surah, l, fmt),
              fmt.formatInt(range.first.ayah),
              fmt.formatInt(range.last.ayah),
            )
          : l.recitationRangeLabel(where(range.first), where(range.last)),
      icon: Icons.graphic_eq_rounded,
      footer: SheetButton(
        label: l.recitationStop,
        icon: Icons.stop_rounded,
        sfx: Sfx.sheetClose,
        onPressed: () {
          unawaited(player.stop());
          unawaited(Navigator.of(context).maybePop());
        },
      ),
      body: !state.active
          ? const SizedBox(height: 120)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: Space.s),
                Center(child: _LiveDial(state: state)),
                _AyahText(state: state),
                const SizedBox(height: Space.m),
                _Transport(state: state),
                _Note(state: state),
                const SizedBox(height: Space.l),
                _RepeatControls(state: state),
                const SizedBox(height: Space.l),
                _Label(l.recitationSpeed, Icons.speed_rounded),
                ChoicePills<double>.single(
                  options: [
                    for (final s in RecitationSettings.speedChoices)
                      ChoiceOption(value: s, label: RecitationLabels.speed(l, fmt, s)),
                  ],
                  selected: state.speed,
                  onChanged: (v) {
                    if (v != null) unawaited(RecitationActions.setSpeed(ref, v));
                  },
                  dense: true,
                ),
                const SizedBox(height: Space.m),
                _SleepChoice(state: state),
                const SizedBox(height: Space.m),
                _ReciterTile(state: state),
                const SizedBox(height: Space.s),
                _SourceLine(state: state),
              ],
            ),
    );
  }
}

class _LiveDial extends ConsumerWidget {
  const _LiveDial({required this.state});

  final RecitationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final catalog = ref.watch(recitationCatalogProvider).value;
    final saver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final player = ref.read(recitationPlayerProvider);
    final item = state.item!;
    final q = state.queue!;
    final size = (MediaQuery.sizeOf(context).width - 2 * Space.gutter).clamp(180.0, 248.0);

    Widget dial(double within) {
      final progress = q.passProgress(state.index, within: within);
      final pass = state.rangePasses == 0
          ? l.recitationRangePassEndless(fmt.formatInt(state.rangePass))
          : state.rangePasses > 1
          ? l.recitationRangePass(fmt.formatInt(state.rangePass), fmt.formatInt(state.rangePasses))
          : null;
      final repeat = state.ayahPasses > 1 && item.isAyah
          ? l.recitationAyahPass(fmt.formatInt(state.ayahPass), fmt.formatInt(state.ayahPasses))
          : null;
      return RecitationDial(
        size: size,
        progress: progress,
        ayahProgress: item.isGap ? 1 : within,
        beads: q.ayatPerPass,
        bead: item.ayahIndex,
        spinning: state.playing && !saver,
        semanticLabel: l.recitationProgress(fmt.formatPercent(progress)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                recitationSurahName(catalog, item.ayah.surah, l, fmt),
                style: text.headlineMedium!.copyWith(color: t.gold),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: Space.xxs),
            Text(
              item.isBasmala ? l.recitationBasmalaNow : l.recitationAyahNumber(fmt.formatInt(item.ayah.ayah)),
              style: text.titleMedium,
            ),
            if (repeat != null || pass != null) ...[
              const SizedBox(height: Space.xxs),
              Text(
                [?repeat, ?pass].join(l.commonFactSeparator),
                style: text.labelMedium!.copyWith(color: t.textTertiary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    if (saver || !state.playing) return dial(0);
    return StreamBuilder<Duration>(
      stream: player.position,
      builder: (context, snap) {
        final duration = player.currentDuration;
        final pos = snap.data ?? Duration.zero;
        final within = duration == null || duration.inMilliseconds == 0
            ? 0.0
            : (pos.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
        return dial(within);
      },
    );
  }
}

/// The ayah being recited, in the mushaf's script (when the Quran text is
/// available).
class _AyahText extends ConsumerWidget {
  const _AyahText({required this.state});

  final RecitationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final catalog = ref.watch(recitationCatalogProvider).value;
    final item = state.item!;
    if (catalog == null) return const SizedBox.shrink();
    final ayah = item.isBasmala ? const AyahRef(1, 1) : item.ayah;
    return FutureBuilder<String>(
      key: ValueKey(ayah),
      future: catalog.ayahText(ayah).catchError((Object _) => ''),
      builder: (context, snap) {
        final text = snap.data ?? '';
        return AnimatedSwitcher(
          duration: context.motion(MadarMotion.medium),
          child: text.isEmpty
              ? const SizedBox(height: Space.s)
              : Padding(
                  key: ValueKey(text),
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.s, 0),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: MadarTypography.quran(t, size: 22).copyWith(height: 1.9),
                  ),
                ),
        );
      },
    );
  }
}

/// Previous / play-pause / next. Media controls keep their universal
/// left-to-right order in every language (as on the lock screen).
class _Transport extends ConsumerWidget {
  const _Transport({required this.state});

  final RecitationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final player = ref.read(recitationPlayerProvider);
    final sounding = state.playing || (state.loading && state.pausedBy == null);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MadarButton.icon(
            icon: Icons.skip_previous_rounded,
            onPressed: () => unawaited(player.previous()),
            semanticLabel: l.recitationPreviousAyah,
            variant: MadarButtonVariant.secondary,
          ),
          const SizedBox(width: Space.xl),
          MadarButton.icon(
            icon: state.error != null
                ? Icons.refresh_rounded
                : (sounding ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed: () => unawaited(player.toggle()),
            semanticLabel: state.error != null ? l.recitationRetry : (sounding ? l.recitationPause : l.recitationPlay),
            variant: MadarButtonVariant.primary,
            size: MadarButtonSize.large,
            loading: state.loading && state.pausedBy == null,
            sfx: sounding ? Sfx.toggleOff : Sfx.toggleOn,
          ),
          const SizedBox(width: Space.xl),
          MadarButton.icon(
            icon: Icons.skip_next_rounded,
            onPressed: () => unawaited(player.next()),
            semanticLabel: l.recitationNextAyah,
            variant: MadarButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.state});

  final RecitationState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final note = state.loading ? null : RecitationLabels.playerNote(l, state);
    final warn = state.error != null || state.pausedBy == RecitationPause.prayer;
    return AnimatedSize(
      duration: context.motion(MadarMotion.short),
      child: note == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.m),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    state.pausedBy == RecitationPause.prayer ? Icons.mosque_outlined : Icons.info_outline_rounded,
                    size: 16,
                    color: warn ? t.warning : t.textTertiary,
                  ),
                  const SizedBox(width: Space.s),
                  Flexible(
                    child: Text(
                      note,
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: warn ? t.warning : t.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label, this.icon);

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.s, start: Space.xxs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: t.gold),
          const SizedBox(width: Space.s),
          Text(label, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: t.textSecondary)),
        ],
      ),
    );
  }
}

/// Repetitions of each ayah and of the passage, changed live.
class _RepeatControls extends ConsumerWidget {
  const _RepeatControls({required this.state});

  final RecitationState state;

  static int _step(int value, int delta, {required bool endless}) {
    if (endless) {
      // … 9, 10, ∞ (0) and back.
      if (value == 0) return delta < 0 ? 10 : 0;
      if (value + delta > 10 && delta > 0) return 0;
    }
    return (value + delta).clamp(1, RecitationSettings.maxRepeat);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final player = ref.read(recitationPlayerProvider);
    final q = state.queue!;
    return Row(
      children: [
        Expanded(
          child: _Stepper(
            icon: Icons.repeat_one_rounded,
            label: l.recitationRepeatAyahShort,
            value: RecitationLabels.times(l, fmt, q.repeatAyah),
            canLess: q.repeatAyah > 1,
            canMore: q.repeatAyah < RecitationSettings.maxRepeat,
            onLess: () => unawaited(player.setRepeats(repeatAyah: _step(q.repeatAyah, -1, endless: false))),
            onMore: () => unawaited(player.setRepeats(repeatAyah: _step(q.repeatAyah, 1, endless: false))),
          ),
        ),
        const SizedBox(width: Space.m),
        Expanded(
          child: _Stepper(
            icon: Icons.repeat_rounded,
            label: l.recitationRepeatRangeShort,
            value: RecitationLabels.times(l, fmt, q.repeatRange),
            canLess: q.repeatRange != 1,
            canMore: q.repeatRange != 0,
            onLess: () => unawaited(player.setRepeats(repeatRange: _step(q.repeatRange, -1, endless: true))),
            onMore: () => unawaited(player.setRepeats(repeatRange: _step(q.repeatRange, 1, endless: true))),
          ),
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.icon,
    required this.label,
    required this.value,
    required this.canLess,
    required this.canMore,
    required this.onLess,
    required this.onMore,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool canLess, canMore;
  final VoidCallback onLess, onMore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.s, Space.xs, Space.xs),
      decoration: BoxDecoration(
        color: t.glassFill,
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(color: t.glassBorder, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: t.gold),
              const SizedBox(width: Space.xs),
              Flexible(
                child: Text(
                  label,
                  style: text.labelMedium!.copyWith(color: t.textTertiary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              MadarButton.icon(
                icon: Icons.remove_rounded,
                onPressed: canLess ? onLess : null,
                semanticLabel: '${l.recitationLess} – $label',
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
              ),
              Expanded(
                child: Semantics(
                  label: '$label: $value',
                  liveRegion: true,
                  excludeSemantics: true,
                  child: AnimatedSwitcher(
                    duration: context.motion(MadarMotion.short),
                    // Shrinks to fit (larger text sizes) rather than cut the
                    // count («مرة وا…»).
                    child: FittedBox(
                      key: ValueKey(value),
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: text.titleMedium!.copyWith(height: 1.3),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
              ),
              MadarButton.icon(
                icon: Icons.add_rounded,
                onPressed: canMore ? onMore : null,
                semanticLabel: '${l.recitationMore} – $label',
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Sleep { off, afterAyah, m15, m30, m60 }

class _SleepChoice extends ConsumerWidget {
  const _SleepChoice({required this.state});

  final RecitationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final player = ref.read(recitationPlayerProvider);
    final sleep = state.sleep;
    final current = sleep == null
        ? _Sleep.off
        : sleep.afterAyah
        ? _Sleep.afterAyah
        : switch (sleep.length?.inMinutes) {
            15 => _Sleep.m15,
            30 => _Sleep.m30,
            60 => _Sleep.m60,
            _ => null,
          };
    String minutes(int m) => fmt.localizeDigits(l.recitationMinutes(m));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(
          sleep?.at == null
              ? l.recitationSleepTimer
              : '${l.recitationSleepTimer} – ${l.recitationSleepUntil(fmt.formatTime(sleep!.at!))}',
          Icons.bedtime_outlined,
        ),
        ChoicePills<_Sleep>.single(
          options: [
            ChoiceOption(value: _Sleep.off, label: l.recitationSleepOff),
            ChoiceOption(value: _Sleep.afterAyah, label: l.recitationSleepAfterAyah),
            ChoiceOption(value: _Sleep.m15, label: minutes(15)),
            ChoiceOption(value: _Sleep.m30, label: minutes(30)),
            ChoiceOption(value: _Sleep.m60, label: minutes(60)),
          ],
          selected: current,
          allowDeselect: true,
          dense: true,
          onChanged: (v) {
            switch (v) {
              case null || _Sleep.off:
                player.setSleepTimer(null);
              case _Sleep.afterAyah:
                player.setSleepAfterAyah();
              case _Sleep.m15:
                player.setSleepTimer(const Duration(minutes: 15));
              case _Sleep.m30:
                player.setSleepTimer(const Duration(minutes: 30));
              case _Sleep.m60:
                player.setSleepTimer(const Duration(minutes: 60));
            }
          },
        ),
      ],
    );
  }
}

class _ReciterTile extends StatelessWidget {
  const _ReciterTile({required this.state});

  final RecitationState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final r = state.reciter;
    return MadarPressable(
      onTap: () => unawaited(showReciterPickerSheet(context)),
      sfx: Sfx.sheetOpen,
      semanticLabel: '${l.recitationReciterLabel}: ${r.name(arabic: fmt.isArabic)}، ${l.recitationChangeReciter}',
      excludeChildSemantics: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        decoration: BoxDecoration(
          color: t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: t.glassBorder, width: 0.8),
        ),
        child: Row(
          children: [
            IslamicStar(size: 22, color: t.gold),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.recitationReciterLabel, style: text.labelMedium!.copyWith(color: t.textTertiary)),
                  Text(r.name(arabic: fmt.isArabic), style: text.titleMedium!.copyWith(height: 1.3)),
                  Text(
                    [
                      RecitationLabels.style(l, r.style),
                      RecitationLabels.bitrate(l, fmt, r),
                    ].join(l.commonFactSeparator),
                    style: text.bodySmall!.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
            ),
            Text(l.recitationChangeReciter, style: text.labelLarge!.copyWith(color: t.accent)),
            const SizedBox(width: Space.xs),
            Icon(Icons.chevron_right_rounded, color: t.accent, size: 20, textDirection: Directionality.of(context)),
          ],
        ),
      ),
    );
  }
}

class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.state});

  final RecitationState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme.labelMedium!.copyWith(color: t.textTertiary);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Space.m,
      runSpacing: Space.xs,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.localFile ? Icons.download_done_rounded : Icons.cloud_outlined,
              size: 14,
              color: state.localFile ? t.success : t.textTertiary,
            ),
            const SizedBox(width: Space.xs),
            Text(state.localFile ? l.recitationOffline : l.recitationStreaming, style: text),
          ],
        ),
        if (!state.background) Text(l.recitationBackgroundOff, style: text),
      ],
    );
  }
}
