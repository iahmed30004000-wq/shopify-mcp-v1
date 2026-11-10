import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart';

import '../../rewards/presentation/play_kit.dart';
import '../application/voice_playback.dart';
import '../application/voice_providers.dart';
import '../domain/voice_story.dart';
import 'parent_corner_screen.dart';
import 'voice_widgets.dart';

/// «حكايات بصوت الأهل» (design 09a): the child listens to the stories the
/// parent recorded. No network, no recording here: recording lives in the
/// parent corner behind the gate.
class VoiceStoriesScreen extends ConsumerStatefulWidget {
  const VoiceStoriesScreen({super.key});

  @override
  ConsumerState<VoiceStoriesScreen> createState() => _VoiceStoriesScreenState();
}

class _VoiceStoriesScreenState extends ConsumerState<VoiceStoriesScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  Future<void> _openCorner() async {
    final ask = ref.read(kidsParentAskProvider);
    if (!await ask() || !mounted) return;
    await ref.read(voicePlaybackProvider.notifier).stop();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ParentCornerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final library = ref.watch(voiceStoriesProvider);
    final playback = ref.watch(voicePlaybackProvider);
    final playable = library.playable;

    // The gentle breathing only runs while a story plays and motion is allowed.
    final breathe = playback.playing && !context.reducedMotion;
    if (breathe && !_breath.isAnimating) _breath.repeat();
    if (!breathe && _breath.isAnimating) _breath.stop();

    final current = (playback.storyId == null ? null : library.byId(playback.storyId!)) ??
        (playable.isEmpty ? null : playable.first);

    return Scaffold(
      backgroundColor: KidsColors.night100,
      body: SafeArea(
        child: Column(
          children: [
            PlayHeader(title: l.kidsPlayVoiceTitle),
            Expanded(
              child: !library.loaded
                  ? const SizedBox.shrink()
                  : playable.isEmpty
                  ? _EmptyState(onParent: _openCorner)
                  : SingleChildScrollView(
                      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (current != null)
                            _PlayerCard(story: current, playback: playback, breath: breathe ? _breath : null),
                          const SizedBox(height: 12),
                          if (playback.problem == PlaybackProblem.cannotPlay) const _CalmProblem(),
                          _Progress(playback: playback),
                          const SizedBox(height: 8),
                          _Controls(playback: playback, many: playable.length > 1),
                          const SizedBox(height: 20),
                          for (final s in playable)
                            _StoryRow(
                              story: s,
                              active: s.id == playback.storyId,
                              playing: s.id == playback.storyId && playback.playing,
                              onTap: () => ref.read(voicePlaybackProvider.notifier).play(s.id),
                            ),
                          const SizedBox(height: 12),
                          _ParentButton(onTap: _openCorner),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.story, required this.playback, required this.breath});

  final VoiceStory story;
  final PlaybackState playback;
  final Animation<double>? breath;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final cover = voiceCover(story.colorIndex);
    final active = playback.storyId == story.id;
    final bars = pseudoWaveform(story.id, 48);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: cover,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [BoxShadow(color: KidsColors.night900.withValues(alpha: .3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          if (story.narrator.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: KidsColors.sun500, borderRadius: BorderRadius.circular(24)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        story.narrator,
                        overflow: TextOverflow.ellipsis,
                        style: KidsText.small.copyWith(color: KidsColors.night900, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.mic_rounded, size: 20, color: KidsColors.night900),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: 230,
            height: 230,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: RingWaveformPainter(bars: bars, progress: active ? playback.progress : 0, breath: breath),
                child: const Center(child: KhatamStarIcon(size: 96, core: KidsColors.night800)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            label: l.kidsPlayStoryByLabel(story.title),
            excludeSemantics: true,
            child: Text(
              story.title,
              textAlign: TextAlign.center,
              style: KidsText.display.copyWith(color: Colors.white, fontSize: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.playback});
  final PlaybackState playback;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 14,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: KidsColors.sand2)),
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                child: FractionallySizedBox(
                  widthFactor: playback.progress.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [KidsColors.sun500, KidsColors.teal500])),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(kidsClock(context, playback.position), style: KidsText.small),
          Text(kidsClock(context, playback.duration), style: KidsText.small),
        ],
      ),
    ],
  );
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.playback, required this.many});
  final PlaybackState playback;
  final bool many;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final c = ref.read(voicePlaybackProvider.notifier);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RoundPlayButton(
          icon: rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          tooltip: l.kidsPlayPrevious,
          onPressed: many ? c.previous : null,
        ),
        const SizedBox(width: 20),
        RoundPlayButton(
          icon: playback.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          tooltip: playback.playing ? l.kidsPlayPauseStory : l.kidsPlayPlayStory,
          background: KidsColors.sun500,
          size: 88,
          iconSize: 48,
          onPressed: c.toggle,
        ),
        const SizedBox(width: 20),
        RoundPlayButton(
          icon: rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          tooltip: l.kidsPlayNext,
          onPressed: many ? c.next : null,
        ),
      ],
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.story, required this.active, required this.playing, required this.onTap});

  final VoiceStory story;
  final bool active, playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        selected: active,
        label: l.kidsPlayStoryRowLabel(story.title, voiceMinutes(context, story.duration)),
        excludeSemantics: true,
        child: Material(
          color: active ? KidsColors.sun100 : KidsColors.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: active ? KidsColors.sun500 : Colors.transparent, width: 2.5),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 80),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 8),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? KidsColors.sun500 : KidsColors.night100,
                      ),
                      child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: KidsColors.night800, size: 32),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(story.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: KidsText.subtitle),
                    ),
                    const SizedBox(width: 8),
                    Text(voiceMinutes(context, story.duration), style: KidsText.small),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalmProblem extends StatelessWidget {
  const _CalmProblem();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: KidsColors.retryFill, borderRadius: BorderRadius.circular(22)),
    child: Text(
      L10n.of(context).kidsPlayCannotPlay,
      style: KidsText.small.copyWith(color: KidsColors.retryText, fontWeight: FontWeight.w700),
      textAlign: TextAlign.center,
    ),
  );
}

class _ParentButton extends StatelessWidget {
  const _ParentButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    child: TextButton.icon(
      style: TextButton.styleFrom(minimumSize: const Size(64, 64), foregroundColor: KidsColors.night700),
      onPressed: onTap,
      icon: const Icon(Icons.lock_rounded),
      label: Text(L10n.of(context).kidsPlayParentCorner, style: KidsText.small.copyWith(fontWeight: FontWeight.w700)),
    ),
  );
}

/// No story recorded yet: say what this is and who can fill it.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onParent});
  final VoidCallback onParent;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(color: KidsColors.night800, shape: BoxShape.circle),
              child: const Center(child: KhatamStarIcon(size: 84, core: KidsColors.night800)),
            ),
            const SizedBox(height: 20),
            Text(l.kidsPlayVoiceEmptyTitle, style: KidsText.title, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l.kidsPlayVoiceEmptyBody, style: KidsText.body, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            BigPlayButton(
              label: l.kidsPlayParentCorner,
              icon: Icons.lock_rounded,
              background: KidsColors.night800,
              foreground: Colors.white,
              onPressed: onParent,
            ),
          ],
        ),
      ),
    );
  }
}
