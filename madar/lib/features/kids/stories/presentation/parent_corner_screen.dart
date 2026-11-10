import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../rewards/presentation/play_kit.dart';
import '../application/voice_playback.dart';
import '../application/voice_providers.dart';
import '../application/voice_recording.dart';
import '../domain/voice_story.dart';
import 'voice_widgets.dart';

/// «ركن الأهل» (design 09b): the parent records, plays, re-records and
/// deletes stories. Opened only after the parent gate said yes. The
/// recordings stay in the app's private folder on this phone.
class ParentCornerScreen extends ConsumerStatefulWidget {
  const ParentCornerScreen({super.key});

  @override
  ConsumerState<ParentCornerScreen> createState() => _ParentCornerScreenState();
}

class _ParentCornerScreenState extends ConsumerState<ParentCornerScreen> {
  Future<void> _add() async {
    final draft = await showVoiceStoryDialog(context);
    if (draft == null) return;
    await ref
        .read(voiceStoriesProvider.notifier)
        .create(title: draft.title, narrator: draft.narrator, colorIndex: draft.colorIndex);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final library = ref.watch(voiceStoriesProvider);
    final rec = ref.watch(voiceRecordingProvider);
    // While the microphone is on, leaving is done with «وقّف واحفظ» or «ألغِ».
    return PopScope(
      canPop: !rec.isBusy,
      child: Scaffold(
        backgroundColor: KidsColors.night900,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
                child: Row(
                  children: [
                    RoundPlayButton(
                      icon: Icons.home_rounded,
                      tooltip: l.kidsPlayBackToStories,
                      background: KidsColors.teal700,
                      foreground: Colors.white,
                      onPressed: rec.isBusy ? null : () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: KidsColors.night800,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    l.kidsPlayParentCorner,
                                    overflow: TextOverflow.ellipsis,
                                    style: KidsText.small.copyWith(
                                      color: KidsColors.sun300,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.lock_rounded, size: 18, color: KidsColors.sun300),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.kidsPlayMyStoriesTitle,
                            style: KidsText.title.copyWith(color: Colors.white, fontSize: 28),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 24),
                  children: [
                    Text(l.kidsPlayCornerIntro, style: KidsText.body.copyWith(color: KidsColors.night100)),
                    const SizedBox(height: 14),
                    if (library.loaded && library.stories.isEmpty) const _CornerEmpty(),
                    for (final s in library.stories) _StoryCard(story: s),
                    const SizedBox(height: 4),
                    BigPlayButton(
                      label: l.kidsPlayAddStory,
                      icon: Icons.add_rounded,
                      background: KidsColors.night700,
                      foreground: Colors.white,
                      onPressed: rec.isBusy ? null : _add,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.verified_user_rounded, color: KidsColors.teal200),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.kidsPlayCornerPrivacy,
                            style: KidsText.small.copyWith(color: KidsColors.night300),
                          ),
                        ),
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

class _CornerEmpty extends StatelessWidget {
  const _CornerEmpty();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: KidsColors.night800, borderRadius: BorderRadius.circular(28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.kidsPlayCornerEmptyTitle, style: KidsText.subtitle.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text(l.kidsPlayCornerEmptyBody, style: KidsText.small.copyWith(color: KidsColors.night100)),
        ],
      ),
    );
  }
}

/// One story in the corner: empty, being recorded, or recorded.
class _StoryCard extends ConsumerWidget {
  const _StoryCard({required this.story});

  final VoiceStory story;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final rec = ref.watch(voiceRecordingProvider);
    final playback = ref.watch(voicePlaybackProvider);
    final recordingThis = rec.isRecording && rec.storyId == story.id;
    final busyElsewhere = rec.isBusy && rec.storyId != story.id;
    final playingThis = playback.storyId == story.id && playback.playing;
    final recCtl = ref.read(voiceRecordingProvider.notifier);
    final note = rec.noteStoryId == story.id ? rec.note : RecordingNote.none;

    Future<void> record() async {
      await ref.read(voicePlaybackProvider.notifier).stop();
      await recCtl.start(story.id);
    }

    Future<void> remove() async {
      if (await confirmDeleteStory(context, story.title)) {
        if (playback.storyId == story.id) await ref.read(voicePlaybackProvider.notifier).stop();
        await ref.read(voiceStoriesProvider.notifier).delete(story.id);
      }
    }

    Future<void> edit() async {
      final draft = await showVoiceStoryDialog(context, existing: story);
      if (draft == null) return;
      await ref
          .read(voiceStoriesProvider.notifier)
          .edit(story.id, title: draft.title, narrator: draft.narrator, colorIndex: draft.colorIndex);
    }

    final status = recordingThis
        ? l.kidsPlayRecordingNow
        : story.hasRecording
        ? voiceMinutes(context, story.duration)
        : l.kidsPlayEmptyStory;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsColors.night800.withValues(alpha: .85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: KidsColors.night300.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 40,
                decoration: BoxDecoration(color: voiceCover(story.colorIndex), borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: KidsText.subtitle.copyWith(color: Colors.white),
                    ),
                    Text(
                      status,
                      style: KidsText.small.copyWith(color: recordingThis ? KidsColors.rose300 : KidsColors.night300),
                    ),
                  ],
                ),
              ),
              RoundPlayButton(
                icon: Icons.edit_rounded,
                tooltip: l.kidsPlayEditStoryTitle,
                background: KidsColors.night700,
                foreground: Colors.white,
                size: 56,
                iconSize: 26,
                onPressed: rec.isBusy ? null : edit,
              ),
            ],
          ),
          if (story.hasRecording || recordingThis) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: recordingThis
                      ? BarsPainter(
                          bars: _liveBars(rec.levels),
                          progress: 1,
                          color: KidsColors.rose300,
                          dim: KidsColors.night500,
                          rtl: rtl,
                        )
                      : BarsPainter(
                          bars: pseudoWaveform(story.id, 40),
                          progress: playback.storyId == story.id ? playback.progress : 0,
                          color: KidsColors.sun300,
                          dim: KidsColors.night500,
                          rtl: rtl,
                        ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (recordingThis)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _Action(
                    label: l.kidsPlayStopSave,
                    icon: Icons.stop_rounded,
                    background: KidsColors.rose500,
                    foreground: Colors.white,
                    size: 72,
                    iconSize: 40,
                    onPressed: recCtl.stopAndSave,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _Action(
                    label: l.kidsPlayDiscard,
                    icon: Icons.close_rounded,
                    background: KidsColors.night500,
                    foreground: Colors.white,
                    onPressed: recCtl.cancel,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        kidsClock(context, rec.elapsed),
                        style: KidsText.display.copyWith(color: KidsColors.rose300, fontSize: 30),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else if (story.hasRecording)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Action(
                    label: playingThis ? l.kidsPlayPauseStory : l.kidsPlayPlayStory,
                    icon: playingThis ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    background: KidsColors.sun300,
                    onPressed: rec.isBusy
                        ? null
                        : () {
                            final c = ref.read(voicePlaybackProvider.notifier);
                            playback.storyId == story.id ? c.toggle() : c.play(story.id);
                          },
                  ),
                ),
                Expanded(
                  child: _Action(
                    label: l.kidsPlayRerecord,
                    icon: Icons.replay_rounded,
                    background: KidsColors.teal500,
                    foreground: Colors.white,
                    onPressed: rec.isBusy ? null : record,
                  ),
                ),
                Expanded(
                  child: _Action(
                    label: l.kidsPlayDelete,
                    icon: Icons.delete_rounded,
                    background: KidsColors.rose300,
                    onPressed: rec.isBusy ? null : remove,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: BigPlayButton(
                    label: l.kidsPlayRecordWithVoice,
                    icon: Icons.mic_rounded,
                    background: KidsColors.rose300,
                    height: 72,
                    onPressed: busyElsewhere || rec.isBusy ? null : record,
                  ),
                ),
                const SizedBox(width: 10),
                RoundPlayButton(
                  icon: Icons.delete_rounded,
                  tooltip: l.kidsPlayDelete,
                  background: KidsColors.night700,
                  foreground: Colors.white,
                  onPressed: rec.isBusy ? null : remove,
                ),
              ],
            ),
          if (note != RecordingNote.none) _NoteBanner(note: note, onClose: recCtl.clearNote),
        ],
      ),
    );
  }

  static List<double> _liveBars(List<double> levels) {
    const n = VoiceRecordingController.levelBars;
    if (levels.length >= n) return levels;
    // Newest on the leading side: pad the quiet history with small bars.
    return [...List<double>.filled(n - levels.length, 0.05), ...levels];
  }
}

/// A round button with its word under it; the word is part of the target.
class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.background = KidsColors.paper,
    this.foreground = KidsColors.night800,
    this.size = 64,
    this.iconSize = 32,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color background, foreground;
  final double size, iconSize;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onPressed,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RoundPlayButton(
          icon: icon,
          tooltip: label,
          background: background,
          foreground: foreground,
          size: size,
          iconSize: iconSize,
          onPressed: onPressed,
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: KidsText.small.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ],
    ),
  );
}

/// What happened to the last recording, in calm words.
class _NoteBanner extends StatelessWidget {
  const _NoteBanner({required this.note, required this.onClose});

  final RecordingNote note;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final (text, good) = switch (note) {
      RecordingNote.saved => (l.kidsPlayNoteSaved, true),
      RecordingNote.interruptedKept => (l.kidsPlayNoteInterruptedKept, true),
      RecordingNote.maxLength => (l.kidsPlayNoteMaxLength, true),
      RecordingNote.interruptedDiscarded => (l.kidsPlayNoteInterruptedDiscarded, false),
      RecordingNote.tooShort => (l.kidsPlayNoteTooShort, false),
      RecordingNote.permissionDenied => (l.kidsPlayNoteNoMic, false),
      RecordingNote.failed => (l.kidsPlayNoteFailed, false),
      RecordingNote.none => ('', true),
    };
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 6, 10),
      decoration: BoxDecoration(
        color: good ? KidsColors.teal100 : KidsColors.retryFill,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(
            good ? Icons.check_circle_rounded : Icons.info_rounded,
            color: good ? KidsColors.teal700 : KidsColors.retryText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: KidsText.small.copyWith(
                color: good ? KidsColors.teal700 : KidsColors.retryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: onClose,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: Icon(Icons.close_rounded, color: good ? KidsColors.teal700 : KidsColors.retryText),
          ),
        ],
      ),
    );
  }
}
