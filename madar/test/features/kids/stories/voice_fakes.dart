import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart' show Finder, WidgetTester, addTearDown, find;

import '../rewards/kids_fakes.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:madar/features/kids/stories/application/voice_playback.dart';
import 'package:madar/features/kids/stories/application/voice_providers.dart';
import 'package:madar/features/kids/stories/application/voice_recording.dart';
import 'package:madar/features/kids/stories/data/voice_files.dart';
import 'package:madar/features/kids/stories/data/voice_player.dart';
import 'package:madar/features/kids/stories/data/voice_recorder.dart';

/// A folder in memory: path to "file exists". No disk, so widget tests run in
/// fake-async.
class MemoryVoiceFiles implements VoiceFiles {
  final Set<String> files = {};
  bool failReplace = false;

  static const root = '/private/kids_voice_stories';

  @override
  Future<String> finalPath(String id) async => '$root/$id.m4a';

  @override
  Future<String> tempPath(String id) async => '$root/$id.rec.m4a';

  @override
  Future<String> resolve(String fileName) async => '$root/$fileName';

  @override
  Future<bool> exists(String path) async => files.contains(path);

  @override
  Future<void> replace(String from, String to) async {
    if (failReplace) throw StateError('disk full');
    if (!files.remove(from)) throw StateError('no such file $from');
    files.add(to);
  }

  @override
  Future<void> delete(String path) async => files.remove(path);

  @override
  Future<int> sweep(Set<String> keep) async {
    final doomed = files.where((p) => !keep.contains(p.split('/').last)).toList();
    files.removeAll(doomed);
    return doomed.length;
  }
}

class FakeVoiceRecorder implements VoiceRecorder {
  FakeVoiceRecorder(this.files);

  final MemoryVoiceFiles files;

  bool permission = true;
  bool startThrows = false;
  String? recordingTo;
  int cancelled = 0;
  bool disposed = false;

  final StreamController<double> level = StreamController<double>.broadcast();
  final StreamController<void> interrupt = StreamController<void>.broadcast();

  @override
  Future<bool> ensurePermission() async => permission;

  @override
  Future<void> start(String path) async {
    if (startThrows) throw StateError('no microphone');
    recordingTo = path;
    files.files.add(path);
  }

  @override
  Stream<double> get levels => level.stream;

  @override
  Stream<void> get interruptions => interrupt.stream;

  @override
  Future<String?> stop() async {
    final p = recordingTo;
    recordingTo = null;
    return p;
  }

  @override
  Future<void> cancel() async {
    cancelled++;
    final p = recordingTo;
    recordingTo = null;
    if (p != null) files.files.remove(p);
  }

  @override
  Future<void> dispose() async => disposed = true;
}

class FakeVoicePlayer implements VoicePlayer {
  String? loaded;
  bool loadThrows = false;
  bool isPlaying = false;
  int stops = 0;

  final StreamController<Duration> pos = StreamController<Duration>.broadcast();
  final StreamController<Duration?> dur = StreamController<Duration?>.broadcast();
  final StreamController<bool> play$ = StreamController<bool>.broadcast();
  final StreamController<void> done = StreamController<void>.broadcast();

  @override
  Future<void> load(String path) async {
    if (loadThrows) throw StateError('cannot decode');
    loaded = path;
    dur.add(const Duration(minutes: 3));
  }

  @override
  Future<void> play() async {
    isPlaying = true;
    play$.add(true);
  }

  @override
  Future<void> pause() async {
    isPlaying = false;
    play$.add(false);
  }

  @override
  Future<void> seek(Duration position) async => pos.add(position);

  @override
  Future<void> stop() async {
    stops++;
    isPlaying = false;
  }

  @override
  Stream<Duration> get position => pos.stream;

  @override
  Stream<Duration?> get duration => dur.stream;

  @override
  Stream<bool> get playing => play$.stream;

  @override
  Stream<void> get completed => done.stream;

  @override
  Future<void> dispose() async {}
}

/// A parent's phone: storage that survives a "restart", a recorder, a player
/// and a clock the test moves.
class Phone {
  final MemoryKidsStore kv = MemoryKidsStore();
  final MemoryVoiceFiles files = MemoryVoiceFiles();
  late FakeVoiceRecorder recorder = FakeVoiceRecorder(files);
  final FakeVoicePlayer player = FakeVoicePlayer();
  DateTime now = DateTime(2026, 11, 10, 10);
  int ids = 0;

  List<Override> overrides() => [
    voiceKeyStoreProvider.overrideWithValue(kv),
    voiceFilesProvider.overrideWithValue(files),
    voiceRecorderProvider.overrideWithValue(recorder),
    voicePlayerProvider.overrideWithValue(player),
    voiceClockProvider.overrideWithValue(() => now),
    voiceIdProvider.overrideWithValue(() => 's${++ids}'),
  ];

  /// An app start. [fresh] makes new device objects like a real restart does.
  ProviderContainer start({bool freshRecorder = true}) {
    if (freshRecorder) recorder = FakeVoiceRecorder(files);
    final c = ProviderContainer(overrides: overrides());
    addTearDown(c.dispose);
    // The screens keep these alive; so does the test.
    c.listen(voiceStoriesProvider, (_, _) {});
    c.listen(voiceRecordingProvider, (_, _) {});
    c.listen(voicePlaybackProvider, (_, _) {});
    return c;
  }
}

/// A microphone that only listens, driven by the test.
class FakeSoundMeter implements SoundMeter {
  bool granted = true;
  bool askedWithRequest = false;
  bool grantOnRequest = true;
  int starts = 0;
  int stops = 0;
  bool listening = false;

  final StreamController<double> level = StreamController<double>.broadcast();

  @override
  Future<bool> hasPermission({bool request = false}) async {
    if (request) {
      askedWithRequest = true;
      if (grantOnRequest) granted = true;
    }
    return granted;
  }

  @override
  Future<void> start() async {
    starts++;
    listening = true;
  }

  @override
  Stream<double> get levels => level.stream;

  @override
  Future<void> stop() async {
    stops++;
    listening = false;
  }

  @override
  Future<void> dispose() async {}
}

/// Scrolls [scrollable] until [target] is really on screen (a lazy list may
/// not have built it yet, and `ensureVisible` alone does not wait for that).
Future<void> scrollTo(WidgetTester tester, Finder target, Finder scrollable) async {
  for (var i = 0; i < 30 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -200));
    await tester.pump();
  }
}
