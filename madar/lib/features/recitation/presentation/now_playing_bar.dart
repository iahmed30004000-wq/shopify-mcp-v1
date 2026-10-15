import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../application/recitation_providers.dart';
import '../domain/recitation_state.dart';
import 'now_playing_sheet.dart';
import 'recitation_labels.dart';

/// The mini player: a glass pill with the passage's progress ring around
/// play / pause, the surah and ayah being recited, the reciter (or why it
/// is paused), next ayah and stop. Tapping it opens [NowPlayingSheet].
///
/// Takes no space while nothing is recited – place it above the home panel
/// and at the bottom of Quran screens.
class NowPlayingBar extends ConsumerWidget {
  const NowPlayingBar({super.key, this.margin = const EdgeInsetsDirectional.fromSTEB(Space.m, 0, Space.m, Space.s)});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recitationStateProvider);
    final visible = state.active;
    return AnimatedSwitcher(
      duration: context.motion(MadarMotion.medium),
      switchInCurve: MadarMotion.decelerate,
      switchOutCurve: MadarMotion.accelerate,
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        alignment: AlignmentDirectional.bottomCenter,
        child: FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
      ),
      child: visible
          ? Padding(
              key: const ValueKey('now-playing-bar'),
              padding: margin,
              child: _Bar(state: state),
            )
          : const SizedBox(key: ValueKey('now-playing-none'), width: double.infinity),
    );
  }
}

class _Bar extends ConsumerWidget {
  const _Bar({required this.state});

  final RecitationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final player = ref.read(recitationPlayerProvider);
    final catalog = ref.watch(recitationCatalogProvider).value;
    final item = state.item!;
    final surah = recitationSurahName(catalog, item.ayah.surah, l, fmt);
    final where = item.isBasmala ? l.recitationBasmalaNow : l.recitationAyahNumber(fmt.formatInt(item.ayah.ayah));
    final note = RecitationLabels.playerNote(l, state);
    final warn = state.error != null || state.pausedBy == RecitationPause.prayer;
    final sounding = state.playing || (state.loading && state.pausedBy == null);
    final progress = state.queue!.passProgress(state.index);
    final repeats = state.ayahPasses > 1 && item.isAyah
        ? fmt.localizeDigits('${state.ayahPass}/${state.ayahPasses}')
        : null;

    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.xs, Space.s),
      borderRadius: BorderRadius.circular(t.radiusXL),
      glowColor: state.playing ? t.accentGlow : null,
      seed: 0.37,
      child: Row(
        children: [
          _PlayRing(
            progress: progress,
            playing: sounding,
            loading: state.loading && state.pausedBy == null,
            error: state.error != null,
            label: state.error != null ? l.recitationRetry : (sounding ? l.recitationPause : l.recitationPlay),
            onTap: () => unawaited(player.toggle()),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: MadarPressable(
              onTap: () => unawaited(showNowPlayingSheet(context)),
              sfx: Sfx.sheetOpen,
              semanticLabel: '${recitationItemTitle(item, catalog, l, fmt)}، ${l.recitationOpenPlayer}',
              excludeChildSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          surah,
                          style: text.titleMedium!.copyWith(height: 1.25),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      Text(where, style: text.labelLarge!.copyWith(color: t.gold, height: 1.25)),
                      if (repeats != null) ...[const SizedBox(width: Space.s), _Badge(repeats)],
                    ],
                  ),
                  const SizedBox(height: 1),
                  AnimatedSwitcher(
                    duration: context.motion(MadarMotion.short),
                    child: Text(
                      note ?? state.reciter.name(arabic: fmt.isArabic),
                      key: ValueKey(note ?? state.reciter.id),
                      style: text.bodySmall!.copyWith(color: warn ? t.warning : t.textTertiary, height: 1.3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          MadarButton.icon(
            icon: Icons.skip_next_rounded,
            onPressed: () => unawaited(player.next()),
            semanticLabel: l.recitationNextAyah,
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
          ),
          MadarButton.icon(
            icon: Icons.close_rounded,
            onPressed: () => unawaited(player.stop()),
            semanticLabel: l.recitationStop,
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: Sfx.sheetClose,
          ),
        ],
      ),
    );
  }
}

/// Play / pause inside the passage's progress ring.
class _PlayRing extends StatelessWidget {
  const _PlayRing({
    required this.progress,
    required this.playing,
    required this.loading,
    required this.error,
    required this.label,
    required this.onTap,
  });

  final double progress;
  final bool playing;
  final bool loading;
  final bool error;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final icon = error ? Icons.refresh_rounded : (playing ? Icons.pause_rounded : Icons.play_arrow_rounded);
    return MadarPressable(
      onTap: onTap,
      sfx: playing ? Sfx.toggleOff : Sfx.toggleOn,
      semanticLabel: label,
      child: SizedBox.square(
        dimension: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ProgressRing(
              value: progress,
              size: 46,
              strokeWidth: 3,
              color: t.metalGold,
              gradientEnd: t.accent,
              trackColor: t.brassDark.withValues(alpha: 0.4),
              glow: playing,
            ),
            if (loading)
              const SizedBox.square(dimension: 22, child: OrbitLoader(size: 22))
            else
              AnimatedSwitcher(
                duration: context.motion(MadarMotion.short),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: Icon(icon, key: ValueKey(icon), size: 26, color: error ? t.warning : t.textPrimary),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: t.accentSoft,
        borderRadius: BorderRadius.circular(t.radiusS),
        border: Border.all(color: t.accent.withValues(alpha: 0.4), width: 0.6),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: t.textPrimary, height: 1.3)),
    );
  }
}
