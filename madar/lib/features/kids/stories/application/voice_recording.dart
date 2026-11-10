import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/voice_recorder.dart';
import 'voice_providers.dart';

enum RecordingPhase { idle, askingPermission, recording, saving }

/// What the screen says after a recording ended (or could not start).
enum RecordingNote {
  none,

  /// Saved.
  saved,

  /// The microphone is not allowed.
  permissionDenied,

  /// A call (or another app) took the audio; what was said so far is kept.
  interruptedKept,

  /// A call took the audio almost at once; the few seconds were thrown away.
  interruptedDiscarded,

  /// Stopped by the parent after less than [VoiceRecordingController.minKeep].
  tooShort,

  /// The recording hit the longest allowed length and stopped; it is kept.
  maxLength,

  /// Something went wrong (storage full, no microphone).
  failed,
}

@immutable
class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.storyId,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.note = RecordingNote.none,
    this.noteStoryId,
  });

  final RecordingPhase phase;

  /// The story being recorded.
  final String? storyId;
  final Duration elapsed;

  /// The last few loudness values (0..1), oldest first, for the live bars.
  final List<double> levels;

  final RecordingNote note;

  /// The story the [note] is about.
  final String? noteStoryId;

  bool get isRecording => phase == RecordingPhase.recording;
  bool get isBusy => phase != RecordingPhase.idle;

  RecordingState copyWith({
    RecordingPhase? phase,
    String? storyId,
    bool clearStory = false,
    Duration? elapsed,
    List<double>? levels,
    RecordingNote? note,
    String? noteStoryId,
  }) => RecordingState(
    phase: phase ?? this.phase,
    storyId: clearStory ? null : (storyId ?? this.storyId),
    elapsed: elapsed ?? this.elapsed,
    levels: levels ?? this.levels,
    note: note ?? this.note,
    noteStoryId: noteStoryId ?? this.noteStoryId,
  );
}

final voiceRecordingProvider = NotifierProvider.autoDispose<VoiceRecordingController, RecordingState>(
  VoiceRecordingController.new,
);

/// Records one story at a time for the parent corner.
///
/// Rules, in plain words:
/// * the recording goes to a temporary file and replaces the story's
///   recording only when it ends well, so a failed re-recording never
///   destroys the old one;
/// * when a call (audio-focus loss) interrupts, the recording ends there and
///   **what was said is kept if it is at least [minKeep] long, otherwise it is
///   thrown away**; the parent is told which;
/// * a recording stops by itself at [maxLength] (and is kept).
class VoiceRecordingController extends Notifier<RecordingState> {
  /// Shorter than this is thrown away (a stray tap).
  static const Duration minKeep = Duration(seconds: 2);

  /// Longest recording (keeps the files and the phone's storage sane).
  static const Duration maxLength = Duration(minutes: 20);

  static const int levelBars = 40;

  StreamSubscription<double>? _levelSub;
  StreamSubscription<void>? _interruptSub;
  Timer? _tick;
  DateTime? _startedAt;
  String? _tempPath;
  bool _ending = false;

  late VoiceRecorder _recorder;

  @override
  RecordingState build() {
    // Watching keeps the recorder alive as long as this controller is, and
    // disposing it (leaving the screen) stops the microphone.
    _recorder = ref.watch(voiceRecorderProvider);
    ref.onDispose(_release);
    return const RecordingState();
  }

  DateTime _now() => ref.read(voiceClockProvider)();

  Duration get _elapsed => _startedAt == null ? Duration.zero : _now().difference(_startedAt!);

  void _release() {
    _levelSub?.cancel();
    _interruptSub?.cancel();
    _tick?.cancel();
    _levelSub = _interruptSub = null;
    _tick = null;
  }

  /// Starts recording [storyId] (a first recording or a re-recording).
  Future<void> start(String storyId) async {
    if (state.isBusy) return;
    state = RecordingState(phase: RecordingPhase.askingPermission, storyId: storyId);
    final recorder = _recorder;
    final library = ref.read(voiceStoriesProvider.notifier);
    try {
      if (!await recorder.ensurePermission()) {
        state = RecordingState(note: RecordingNote.permissionDenied, noteStoryId: storyId);
        return;
      }
      final path = await library.tempPathFor(storyId);
      await library.discardTemp(storyId);
      await recorder.start(path);
      _tempPath = path;
      _ending = false;
      _startedAt = _now();
      _levelSub = recorder.levels.listen(_onLevel, onError: (_) {});
      _interruptSub = recorder.interruptions.listen((_) => unawaited(_end(interrupted: true)));
      _tick = Timer.periodic(const Duration(milliseconds: 250), (_) => _onTick());
      state = RecordingState(phase: RecordingPhase.recording, storyId: storyId);
    } on Object catch (e) {
      debugPrint('voice recording: cannot start: $e');
      _release();
      state = RecordingState(note: RecordingNote.failed, noteStoryId: storyId);
    }
  }

  void _onLevel(double v) {
    if (!state.isRecording) return;
    final l = [...state.levels, v.clamp(0.0, 1.0)];
    if (l.length > levelBars) l.removeRange(0, l.length - levelBars);
    state = state.copyWith(levels: l);
  }

  void _onTick() {
    if (!state.isRecording) return;
    final e = _elapsed;
    if (e >= maxLength) {
      unawaited(_end(atMax: true));
      return;
    }
    state = state.copyWith(elapsed: e);
  }

  /// «وقّف واحفظ».
  Future<void> stopAndSave() => _end();

  /// «ألغِ»: stops and throws the capture away.
  Future<void> cancel() async {
    if (!state.isRecording || _ending) return;
    _ending = true;
    final id = state.storyId!;
    _release();
    try {
      await _recorder.cancel();
    } on Object catch (e) {
      debugPrint('voice recording: cancel failed: $e');
    }
    await ref.read(voiceStoriesProvider.notifier).discardTemp(id);
    state = RecordingState(noteStoryId: id);
  }

  /// Clears the message (the screen shows it once).
  void clearNote() {
    if (state.note != RecordingNote.none) state = state.copyWith(note: RecordingNote.none);
  }

  Future<void> _end({bool interrupted = false, bool atMax = false}) async {
    if (!state.isRecording || _ending) return;
    _ending = true;
    final id = state.storyId!;
    final length = _elapsed;
    _release();
    state = state.copyWith(phase: RecordingPhase.saving, elapsed: length);
    final library = ref.read(voiceStoriesProvider.notifier);
    var note = RecordingNote.failed;
    try {
      final path = await _recorder.stop() ?? _tempPath;
      if (path == null || length < minKeep) {
        await library.discardTemp(id);
        note = interrupted ? RecordingNote.interruptedDiscarded : RecordingNote.tooShort;
      } else if (await library.commitRecording(id, path, length)) {
        note = interrupted
            ? RecordingNote.interruptedKept
            : atMax
            ? RecordingNote.maxLength
            : RecordingNote.saved;
      } else {
        await library.discardTemp(id);
      }
    } on Object catch (e) {
      debugPrint('voice recording: cannot finish: $e');
      await library.discardTemp(id);
    }
    if (ref.mounted) state = RecordingState(note: note, noteStoryId: id);
  }
}
