import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/stories/application/voice_playback.dart';
import 'package:madar/features/kids/stories/application/voice_providers.dart';
import 'package:madar/features/kids/stories/application/voice_recording.dart';
import 'package:madar/features/kids/stories/domain/voice_story.dart';

import 'voice_fakes.dart';

Future<VoiceStory> _newStory(ProviderContainer c, {String title = 'حكاية قبل النوم'}) async {
  final lib = c.read(voiceStoriesProvider.notifier);
  await lib.ready;
  return lib.create(title: title, narrator: 'بصوت بابا', colorIndex: 2);
}

/// Records [story] for [seconds] and presses stop.
Future<void> _recordFor(Phone phone, ProviderContainer c, VoiceStory story, int seconds) async {
  final rec = c.read(voiceRecordingProvider.notifier);
  await rec.start(story.id);
  expect(c.read(voiceRecordingProvider).isRecording, isTrue);
  phone.now = phone.now.add(Duration(seconds: seconds));
  await rec.stopAndSave();
}

void main() {
  group('the library', () {
    test('create, edit and delete; titles are the parent\'s own, trimmed and capped', () async {
      final phone = Phone();
      final c = phone.start();
      final lib = c.read(voiceStoriesProvider.notifier);
      await lib.ready;
      final s = await lib.create(title: '   حكاية   الفانوس  ', narrator: ' بصوت ماما ', colorIndex: 9);
      expect(s.title, 'حكاية الفانوس');
      expect(s.narrator, 'بصوت ماما');
      expect(s.colorIndex, 9 % VoiceStory.coverColours);
      expect(c.read(voiceStoriesProvider).stories.single.hasRecording, isFalse);

      await lib.edit(s.id, title: 'x' * 200, colorIndex: 1);
      expect(c.read(voiceStoriesProvider).byId(s.id)!.title.length, VoiceStory.maxTitleLength);
      expect(c.read(voiceStoriesProvider).byId(s.id)!.colorIndex, 1);

      await lib.delete(s.id);
      expect(c.read(voiceStoriesProvider).stories, isEmpty);
    });

    test('fresh install is empty (nothing hard-coded)', () async {
      final c = Phone().start();
      await c.read(voiceStoriesProvider.notifier).ready;
      expect(c.read(voiceStoriesProvider).loaded, isTrue);
      expect(c.read(voiceStoriesProvider).stories, isEmpty);
    });

    test('a recorded story survives an app restart, file and all', () async {
      final phone = Phone();
      var c = phone.start();
      final s = await _newStory(c);
      await _recordFor(phone, c, s, 90);
      expect(phone.files.files, contains('${MemoryVoiceFiles.root}/${s.id}.m4a'));
      c.dispose();

      c = phone.start();
      await c.read(voiceStoriesProvider.notifier).ready;
      final back = c.read(voiceStoriesProvider).byId(s.id)!;
      expect(back.title, 'حكاية قبل النوم');
      expect(back.hasRecording, isTrue);
      expect(back.duration, const Duration(seconds: 90));
    });

    test('deleting removes the file; a half recording and orphans are swept at the next start', () async {
      final phone = Phone();
      var c = phone.start();
      final s = await _newStory(c);
      await _recordFor(phone, c, s, 30);
      await c.read(voiceStoriesProvider.notifier).delete(s.id);
      expect(phone.files.files, isEmpty);

      // A crash left a half recording and a file nobody knows.
      phone.files.files.addAll(['${MemoryVoiceFiles.root}/zz.rec.m4a', '${MemoryVoiceFiles.root}/old.m4a']);
      c.dispose();
      c = phone.start();
      await c.read(voiceStoriesProvider.notifier).ready;
      expect(phone.files.files, isEmpty);
    });

    test('a story whose file has vanished shows as empty but keeps its title', () async {
      final phone = Phone();
      var c = phone.start();
      final s = await _newStory(c);
      await _recordFor(phone, c, s, 30);
      phone.files.files.clear();
      c.dispose();
      c = phone.start();
      await c.read(voiceStoriesProvider.notifier).ready;
      final back = c.read(voiceStoriesProvider).byId(s.id)!;
      expect(back.hasRecording, isFalse);
      expect(back.title, s.title);
    });

    test('a file name that could leave the private folder is refused', () {
      expect(VoiceStory.isSafeFileName('a.m4a'), isTrue);
      expect(VoiceStory.isSafeFileName('../../x.m4a'), isFalse);
      expect(VoiceStory.isSafeFileName('/sdcard/DCIM/x.m4a'), isFalse);
      expect(VoiceStory.isSafeFileName(r'a\b.m4a'), isFalse);
      final s = VoiceStory.fromJson({'id': 'a', 'title': 't', 'file': '../evil.m4a'});
      expect(s!.fileName, isNull);
      expect(VoiceStory.fromJson({'title': 'no id'}), isNull);
      expect(decodeVoiceStories('junk'), isEmpty);
    });

    test('the waveform is steady and unique per story, always within 0..1', () {
      final a = pseudoWaveform('s1', 48);
      expect(pseudoWaveform('s1', 48), a);
      expect(pseudoWaveform('s2', 48), isNot(a));
      expect(a.every((v) => v > 0 && v <= 1), isTrue);
    });
  });

  group('recording', () {
    test('microphone permission denied: a calm note, nothing recorded, nothing broken', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      phone.recorder.permission = false;
      await c.read(voiceRecordingProvider.notifier).start(s.id);
      final st = c.read(voiceRecordingProvider);
      expect(st.phase, RecordingPhase.idle);
      expect(st.note, RecordingNote.permissionDenied);
      expect(st.noteStoryId, s.id);
      expect(phone.recorder.recordingTo, isNull);
      expect(phone.files.files, isEmpty);
    });

    test('no microphone at all (start throws): failed note, back to idle', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      phone.recorder.startThrows = true;
      await c.read(voiceRecordingProvider.notifier).start(s.id);
      expect(c.read(voiceRecordingProvider).note, RecordingNote.failed);
      expect(c.read(voiceRecordingProvider).isBusy, isFalse);
    });

    test('record then save: the story gets its recording and the length', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      await _recordFor(phone, c, s, 48);
      expect(c.read(voiceRecordingProvider).note, RecordingNote.saved);
      final back = c.read(voiceStoriesProvider).byId(s.id)!;
      expect(back.hasRecording, isTrue);
      expect(back.duration, const Duration(seconds: 48));
      expect(phone.files.files, {'${MemoryVoiceFiles.root}/${s.id}.m4a'}, reason: 'the temp file is gone');
    });

    test('the live loudness and the timer follow the recording', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      final rec = c.read(voiceRecordingProvider.notifier);
      await rec.start(s.id);
      phone.recorder.level.add(0.4);
      phone.recorder.level.add(0.7);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(voiceRecordingProvider).levels, [0.4, 0.7]);
      phone.now = phone.now.add(const Duration(seconds: 12));
      rec.debugTick();
      expect(c.read(voiceRecordingProvider).elapsed, const Duration(seconds: 12));
      await rec.stopAndSave();
    });

    test('a re-recording replaces the old one only when it ends well', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      await _recordFor(phone, c, s, 60);
      final path = '${MemoryVoiceFiles.root}/${s.id}.m4a';

      // The disk fails while saving the new take: the old story is untouched.
      phone.files.failReplace = true;
      await _recordFor(phone, c, s, 20);
      expect(c.read(voiceRecordingProvider).note, RecordingNote.failed);
      expect(phone.files.files, {path}, reason: 'old recording intact, failed take removed');
      expect(c.read(voiceStoriesProvider).byId(s.id)!.duration, const Duration(seconds: 60));

      // A good second take replaces it.
      phone.files.failReplace = false;
      await _recordFor(phone, c, s, 25);
      expect(c.read(voiceStoriesProvider).byId(s.id)!.duration, const Duration(seconds: 25));
      expect(phone.files.files, {path});
    });

    test('cancel throws the new take away and leaves the old recording', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      await _recordFor(phone, c, s, 60);
      final rec = c.read(voiceRecordingProvider.notifier);
      await rec.start(s.id);
      await rec.cancel();
      expect(c.read(voiceRecordingProvider).isBusy, isFalse);
      expect(phone.recorder.cancelled, 1);
      expect(c.read(voiceStoriesProvider).byId(s.id)!.duration, const Duration(seconds: 60));
      expect(phone.files.files, {'${MemoryVoiceFiles.root}/${s.id}.m4a'});
    });

    test('a stray tap (stopped under two seconds) is not kept', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      await _recordFor(phone, c, s, 1);
      expect(c.read(voiceRecordingProvider).note, RecordingNote.tooShort);
      expect(c.read(voiceStoriesProvider).byId(s.id)!.hasRecording, isFalse);
      expect(phone.files.files, isEmpty);
    });

    test('a phone call (audio focus lost) after 10 s ends cleanly and KEEPS what was said', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      await c.read(voiceRecordingProvider.notifier).start(s.id);
      phone.now = phone.now.add(const Duration(seconds: 10));
      phone.recorder.interrupt.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final st = c.read(voiceRecordingProvider);
      expect(st.phase, RecordingPhase.idle, reason: 'ended, not stuck');
      expect(st.note, RecordingNote.interruptedKept);
      final back = c.read(voiceStoriesProvider).byId(s.id)!;
      expect(back.hasRecording, isTrue);
      expect(back.duration, const Duration(seconds: 10));
      expect(phone.files.files, {'${MemoryVoiceFiles.root}/${s.id}.m4a'});
    });

    test('a call in the first second: the few moments are thrown away, and the parent is told', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      await c.read(voiceRecordingProvider.notifier).start(s.id);
      phone.now = phone.now.add(const Duration(milliseconds: 800));
      phone.recorder.interrupt.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(voiceRecordingProvider).note, RecordingNote.interruptedDiscarded);
      expect(c.read(voiceStoriesProvider).byId(s.id)!.hasRecording, isFalse);
      expect(phone.files.files, isEmpty);
    });

    test('two interruptions, or an interruption right after stop, finish once', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      await c.read(voiceRecordingProvider.notifier).start(s.id);
      phone.now = phone.now.add(const Duration(seconds: 5));
      phone.recorder.interrupt
        ..add(null)
        ..add(null);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(voiceStoriesProvider).stories, hasLength(1));
      expect(c.read(voiceRecordingProvider).note, RecordingNote.interruptedKept);
    });

    test('a recording stops by itself at the longest length and is kept', () async {
      final phone = Phone();
      final c = phone.start();
      final s = await _newStory(c);
      final rec = c.read(voiceRecordingProvider.notifier);
      await rec.start(s.id);
      phone.now = phone.now.add(VoiceRecordingController.maxLength + const Duration(seconds: 1));
      rec.debugTick();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.read(voiceRecordingProvider).note, RecordingNote.maxLength);
      expect(c.read(voiceStoriesProvider).byId(s.id)!.hasRecording, isTrue);
    });

    test('only one recording at a time', () async {
      final phone = Phone();
      final c = phone.start();
      final a = await _newStory(c, title: 'أ');
      final b = await _newStory(c, title: 'ب');
      final rec = c.read(voiceRecordingProvider.notifier);
      await rec.start(a.id);
      await rec.start(b.id);
      expect(c.read(voiceRecordingProvider).storyId, a.id);
      await rec.stopAndSave();
    });
  });

  group('playback (the child, offline)', () {
    Future<(Phone, ProviderContainer, List<VoiceStory>)> setup() async {
      final phone = Phone();
      final c = phone.start();
      final a = await _newStory(c, title: 'أ');
      final b = await _newStory(c, title: 'ب');
      final empty = await _newStory(c, title: 'فاضية');
      await _recordFor(phone, c, a, 30);
      await _recordFor(phone, c, b, 60);
      return (phone, c, [a, b, empty]);
    }

    test('play opens the file and plays; an empty story is never offered', () async {
      final (phone, c, s) = await setup();
      expect(c.read(voiceStoriesProvider).playable.map((e) => e.title), ['أ', 'ب']);
      await c.read(voicePlaybackProvider.notifier).play(s[0].id);
      expect(phone.player.loaded, '${MemoryVoiceFiles.root}/${s[0].id}.m4a');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(voicePlaybackProvider).playing, isTrue);
      expect(c.read(voicePlaybackProvider).storyId, s[0].id);
    });

    test('pause and resume, position and progress follow the player', () async {
      final (phone, c, s) = await setup();
      final p = c.read(voicePlaybackProvider.notifier);
      await p.play(s[1].id);
      phone.player.pos.add(const Duration(seconds: 90));
      await Future<void>.delayed(Duration.zero);
      expect(c.read(voicePlaybackProvider).progress, closeTo(0.5, 1e-9), reason: 'the fake reports 3 minutes');
      await p.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(voicePlaybackProvider).playing, isFalse);
      await p.toggle();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(voicePlaybackProvider).playing, isTrue);
    });

    test('next and previous walk the recorded stories and wrap round', () async {
      final (_, c, s) = await setup();
      final p = c.read(voicePlaybackProvider.notifier);
      await p.play(s[0].id);
      await p.next();
      expect(c.read(voicePlaybackProvider).storyId, s[1].id);
      await p.next();
      expect(c.read(voicePlaybackProvider).storyId, s[0].id, reason: 'wraps');
      await p.previous();
      expect(c.read(voicePlaybackProvider).storyId, s[1].id);
    });

    test('toggle with nothing open starts the first story', () async {
      final (_, c, s) = await setup();
      await c.read(voicePlaybackProvider.notifier).toggle();
      expect(c.read(voicePlaybackProvider).storyId, s[0].id);
    });

    test('the end of a story stops it at the start, ready to play again', () async {
      final (phone, c, s) = await setup();
      await c.read(voicePlaybackProvider.notifier).play(s[0].id);
      phone.player.done.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final st = c.read(voicePlaybackProvider);
      expect(st.playing, isFalse);
      expect(st.position, Duration.zero);
    });

    test('a file that cannot be played gives a calm problem state, never an exception', () async {
      final (phone, c, s) = await setup();
      phone.player.loadThrows = true;
      await c.read(voicePlaybackProvider.notifier).play(s[0].id);
      expect(c.read(voicePlaybackProvider).problem, PlaybackProblem.cannotPlay);
      expect(c.read(voicePlaybackProvider).playing, isFalse);
    });

    test('no stories at all: next and toggle do nothing', () async {
      final phone = Phone();
      final c = phone.start();
      await c.read(voiceStoriesProvider.notifier).ready;
      final p = c.read(voicePlaybackProvider.notifier);
      await p.toggle();
      await p.next();
      expect(c.read(voicePlaybackProvider).storyId, isNull);
    });
  });
}
