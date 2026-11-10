import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/db/repositories/key_value_repository.dart';
import '../../../../core/providers.dart';
import '../../rewards/data/rewards_store.dart' show KeyValueKidsStore, KidsKeyStore;
import '../data/voice_files.dart';
import '../data/voice_player.dart';
import '../data/voice_recorder.dart';
import '../domain/voice_story.dart';

// ----------------------------------------------------------- plumbing ----

final voiceFilesProvider = Provider<VoiceFiles>((ref) => PrivateVoiceFiles());

final voiceRecorderProvider = Provider.autoDispose<VoiceRecorder>((ref) {
  final r = RecordPackageRecorder();
  ref.onDispose(() => unawaited(r.dispose()));
  return r;
});

final voicePlayerProvider = Provider.autoDispose<VoicePlayer>((ref) {
  final p = JustAudioVoicePlayer();
  ref.onDispose(() => unawaited(p.dispose()));
  return p;
});

final voiceKeyStoreProvider = Provider<KidsKeyStore>(
  (ref) => KeyValueKidsStore(KeyValueRepository(ref.watch(databaseProvider))),
);

/// The clock recordings are timed with (tests drive it).
final voiceClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final voiceIdProvider = Provider<String Function()>((ref) {
  const uuid = Uuid();
  return () => uuid.v4().substring(0, 12);
});

/// Asks the parent (PIN or fingerprint) before the corner opens. The kids
/// shell's own gate is the real one; until the integrator overrides this it
/// answers **no**, so the parent corner stays closed rather than open.
final kidsParentAskProvider = Provider<Future<bool> Function()>((ref) => () async => false);

// ------------------------------------------------------------ library ----

@immutable
class VoiceLibraryState {
  const VoiceLibraryState({this.loaded = false, this.stories = const []});

  final bool loaded;
  final List<VoiceStory> stories;

  List<VoiceStory> get playable => [
    for (final s in stories)
      if (s.hasRecording) s,
  ];

  VoiceStory? byId(String id) {
    for (final s in stories) {
      if (s.id == id) return s;
    }
    return null;
  }
}

final voiceStoriesProvider = NotifierProvider<VoiceStoriesNotifier, VoiceLibraryState>(VoiceStoriesNotifier.new);

/// The parent's stories: their titles and recordings, kept on the device.
/// Every change is written first and shown after.
class VoiceStoriesNotifier extends Notifier<VoiceLibraryState> {
  static const String storageKey = 'kids.voice_stories';

  late Future<void> _loaded;
  Future<void> _queue = Future<void>.value();

  KidsKeyStore get _store => ref.read(voiceKeyStoreProvider);
  VoiceFiles get _files => ref.read(voiceFilesProvider);

  @override
  VoiceLibraryState build() {
    _loaded = _load();
    return const VoiceLibraryState();
  }

  Future<void> get ready => _loaded;

  Future<void> _load() async {
    try {
      var stories = decodeVoiceStories(await _store.read(storageKey));
      // A story whose file has gone keeps its title and shows as empty.
      final fixed = <VoiceStory>[];
      var changed = false;
      for (final s in stories) {
        final f = s.fileName;
        if (f != null && !await _files.exists(await _files.resolve(f))) {
          fixed.add(s.copyWith(clearRecording: true));
          changed = true;
        } else {
          fixed.add(s);
        }
      }
      stories = fixed;
      if (changed) await _store.write(storageKey, encodeVoiceStories(stories));
      // Half recordings and files of deleted stories.
      await _files.sweep({
        for (final s in stories)
          if (s.fileName != null) s.fileName!,
      });
      if (ref.mounted) state = VoiceLibraryState(loaded: true, stories: stories);
    } on Object catch (e) {
      debugPrint('voice stories: cannot load: $e');
      if (ref.mounted) state = const VoiceLibraryState(loaded: true);
    }
  }

  Future<T> _run<T>(Future<T> Function() job) {
    final done = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        await _loaded;
        done.complete(await job());
      } on Object catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<void> _commit(List<VoiceStory> next) async {
    await _store.write(storageKey, encodeVoiceStories(next));
    if (ref.mounted) state = VoiceLibraryState(loaded: true, stories: next);
  }

  /// A new, empty story.
  Future<VoiceStory> create({required String title, String narrator = '', int colorIndex = 0}) => _run(() async {
    final clean = VoiceStory.cleanTitle(title);
    final story = VoiceStory(
      id: ref.read(voiceIdProvider)(),
      title: clean,
      narrator: VoiceStory.cleanNarrator(narrator),
      colorIndex: colorIndex % VoiceStory.coverColours,
      createdAtMs: ref.read(voiceClockProvider)().millisecondsSinceEpoch,
    );
    await _commit([...state.stories, story]);
    return story;
  });

  /// Changes the typed parts of a story.
  Future<void> edit(String id, {String? title, String? narrator, int? colorIndex}) => _run(() async {
    final next = [
      for (final s in state.stories)
        if (s.id == id)
          s.copyWith(
            title: title == null ? null : VoiceStory.cleanTitle(title),
            narrator: narrator == null ? null : VoiceStory.cleanNarrator(narrator),
            colorIndex: colorIndex == null ? null : colorIndex % VoiceStory.coverColours,
          )
        else
          s,
    ];
    await _commit(next);
  });

  /// Removes the story and its recording. The list is written first, so a
  /// crash in between leaves at worst a file that the next start sweeps.
  Future<void> delete(String id) => _run(() async {
    final story = state.byId(id);
    if (story == null) return;
    await _commit([
      for (final s in state.stories)
        if (s.id != id) s,
    ]);
    final f = story.fileName;
    if (f != null) await _files.delete(await _files.resolve(f));
    await _files.delete(await _files.tempPath(id));
  });

  /// Puts a finished capture at [tempPath] in place of the story's recording.
  /// The old recording is replaced only now, so a re-recording that fails
  /// leaves the old one untouched. Returns false when it could not be saved.
  Future<bool> commitRecording(String id, String tempPath, Duration length) => _run(() async {
    final story = state.byId(id);
    if (story == null) return false;
    try {
      final target = await _files.finalPath(id);
      await _files.replace(tempPath, target);
      final name = target.split(RegExp(r'[\\/]')).last;
      await _commit([
        for (final s in state.stories)
          if (s.id == id) s.copyWith(fileName: name, durationMs: length.inMilliseconds) else s,
      ]);
      return true;
    } on Object catch (e) {
      debugPrint('voice stories: cannot save a recording: $e');
      return false;
    }
  });

  /// Where story [id] is captured into.
  Future<String> tempPathFor(String id) => _files.tempPath(id);

  Future<void> discardTemp(String id) async {
    try {
      await _files.delete(await _files.tempPath(id));
    } on Object catch (e) {
      debugPrint('voice stories: cannot remove a half recording: $e');
    }
  }

  /// Full path of a story's recording, or null.
  Future<String?> pathOf(VoiceStory s) async {
    final f = s.fileName;
    return f == null ? null : _files.resolve(f);
  }
}
