import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voice_player.dart';
import '../domain/voice_story.dart';
import 'voice_providers.dart';

enum PlaybackProblem { none, cannotPlay }

@immutable
class PlaybackState {
  const PlaybackState({
    this.storyId,
    this.playing = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.problem = PlaybackProblem.none,
  });

  final String? storyId;
  final bool playing;
  final Duration position;
  final Duration duration;
  final PlaybackProblem problem;

  /// 0..1 through the story.
  double get progress => duration.inMilliseconds <= 0 ? 0 : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  PlaybackState copyWith({
    String? storyId,
    bool? playing,
    Duration? position,
    Duration? duration,
    PlaybackProblem? problem,
  }) => PlaybackState(
    storyId: storyId ?? this.storyId,
    playing: playing ?? this.playing,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    problem: problem ?? this.problem,
  );
}

final voicePlaybackProvider = NotifierProvider.autoDispose<VoicePlaybackController, PlaybackState>(
  VoicePlaybackController.new,
);

/// The child's player: one story at a time, from a file on the device. It
/// needs no network and keeps working with the phone in flight mode.
class VoicePlaybackController extends Notifier<PlaybackState> {
  final List<StreamSubscription<Object?>> _subs = [];
  bool _wired = false;

  late VoicePlayer _player;

  @override
  PlaybackState build() {
    // Watching keeps the player alive with this controller; disposing it
    // (leaving the screen) stops the sound.
    _player = ref.watch(voicePlayerProvider);
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
    });
    return const PlaybackState();
  }

  void _wire() {
    if (_wired) return;
    _wired = true;
    final p = _player;
    _subs
      ..add(p.position.listen((d) {
        if (ref.mounted) state = state.copyWith(position: d);
      }))
      ..add(p.duration.listen((d) {
        if (ref.mounted && d != null) state = state.copyWith(duration: d);
      }))
      ..add(p.playing.listen((v) {
        if (ref.mounted) state = state.copyWith(playing: v);
      }))
      ..add(p.completed.listen((_) {
        if (ref.mounted) state = state.copyWith(playing: false, position: Duration.zero);
        unawaited(p.pause().catchError((Object _) {}));
        unawaited(p.seek(Duration.zero).catchError((Object _) {}));
      }));
  }

  List<VoiceStory> get _list => ref.read(voiceStoriesProvider).playable;

  /// Opens a story and plays it from the start.
  Future<void> play(String id) async {
    _wire();
    final story = ref.read(voiceStoriesProvider).byId(id);
    final path = story == null ? null : await ref.read(voiceStoriesProvider.notifier).pathOf(story);
    if (story == null || path == null) {
      state = PlaybackState(storyId: id, problem: PlaybackProblem.cannotPlay);
      return;
    }
    final p = _player;
    state = PlaybackState(storyId: id, duration: story.duration);
    try {
      await p.load(path);
      await p.play();
    } on Object catch (e) {
      debugPrint('voice playback: cannot play $id: $e');
      if (ref.mounted) state = PlaybackState(storyId: id, problem: PlaybackProblem.cannotPlay);
    }
  }

  /// Play or pause the open story (opens the first one when none is open).
  Future<void> toggle() async {
    final id = state.storyId;
    if (id == null) {
      final list = _list;
      if (list.isNotEmpty) await play(list.first.id);
      return;
    }
    if (state.problem != PlaybackProblem.none) return play(id);
    final p = _player;
    if (state.playing) {
      await p.pause();
    } else {
      await p.play();
    }
  }

  Future<void> next() => _step(1);
  Future<void> previous() => _step(-1);

  Future<void> _step(int by) async {
    final list = _list;
    if (list.isEmpty) return;
    final i = list.indexWhere((s) => s.id == state.storyId);
    final target = i < 0 ? 0 : (i + by) % list.length;
    await play(list[target < 0 ? target + list.length : target].id);
  }

  Future<void> stop() async {
    final p = _player;
    try {
      await p.stop();
    } on Object catch (_) {}
    if (ref.mounted) state = const PlaybackState();
  }
}
