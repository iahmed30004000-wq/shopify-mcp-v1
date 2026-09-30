import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/runtime/music_director.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

import 'fake_mixer.dart';

CinemaAudioContext _ctx() => CinemaAudioContext(sound: SilentSoundService(), era: Era.rubberHose, score: eraScore(Era.rubberHose), seed: 7);

Duration _s(double seconds) => Duration(microseconds: (seconds * 1e6).round());

void main() {
  late FakeCinemaMixer mixer;
  late FakeCueSource source;
  late ProceduralMusicDirector director;

  Future<void> start(MusicMood mood, {bool prefetch = false, int? budget}) async {
    mixer = FakeCinemaMixer();
    source = FakeCueSource();
    director = ProceduralMusicDirector(_ctx(), mixer: mixer, source: source, prefetch: prefetch, budgetBytes: budget ?? 24 << 20);
    director.cue(mood);
    await director.prepare();
    await pumpEventQueue();
  }

  tearDown(() async => director.dispose());

  test('stays silent and renders nothing without the SoLoud service', () async {
    final src = FakeCueSource();
    director = ProceduralMusicDirector(_ctx(), source: src);
    await director.prepare();
    expect(director.isReady, isTrue);
    director
      ..cue(MusicMood.action, intensity: 0.8)
      ..stinger(Stinger.hit)
      ..update(1 / 60);
    expect(director.mood, MusicMood.action);
    expect(director.intensity, 0.8);
    expect(src.requests, isEmpty);
  });

  test('renders the cued mood first, then prefetches the rest', () async {
    await start(MusicMood.title, prefetch: true);
    expect(director.isReady, isTrue);
    expect(source.requests.first, anyOf('stingers', 'cue title'));
    expect(source.requests.take(2), contains('cue title'));
    for (var i = 0; i < 20; i++) {
      await pumpEventQueue();
    }
    expect(director.loadedMoods.toSet(), MusicMood.values.toSet());
  });

  test('the first cue starts at once, intro then a sample-locked loop', () async {
    await start(MusicMood.title);
    expect(director.playingMood, MusicMood.title);
    final t0 = const Duration(seconds: 10) + ProceduralMusicDirector.lead;
    final intros = mixer.active('intro');
    final loops = mixer.active('loop');
    expect(intros, hasLength(3));
    expect(loops, hasLength(3));
    for (final v in intros) {
      expect(v.at, t0);
      expect(v.loop, isFalse);
      expect(v.protect, isTrue);
    }
    for (final v in loops) {
      expect(v.at, t0 + _s(2));
      expect(v.loop, isTrue);
    }
    // Default intensity 0.5: bed and lead on, the hot layer off.
    double target(String stem) => mixer.active('$stem-loop').single.target;
    expect(target('bed'), closeTo(ProceduralMusicDirector.level, 1e-9));
    expect(target('lead'), closeTo(ProceduralMusicDirector.level, 1e-9));
    expect(target('hot'), 0);
  });

  test('a new mood waits for the next bar line and cross-fades', () async {
    await start(MusicMood.title);
    mixer.advance(_s(0.7));
    director.cue(MusicMood.action, fade: const Duration(milliseconds: 600));
    await pumpEventQueue();
    director.update(1 / 60);
    // Title intro started at 10.06 s, its loop (and bar grid) at 12.06 s.
    final loopAt = const Duration(seconds: 10) + ProceduralMusicDirector.lead + _s(2);
    final actionLoops = mixer.active('action-');
    expect(actionLoops, hasLength(3), reason: 'gameplay moods enter straight into the loop');
    for (final v in actionLoops) {
      expect(v.at, loopAt);
    }
    final old = mixer.voices.values.where((v) => mixer.nameOf(v.source).contains('title'));
    expect(old.every((v) => v.stopping), isTrue);
    expect(old.first.fades.last.at, loopAt - _s(0.3));
    expect(director.playingMood, MusicMood.action);
  });

  test('jingles start on the next beat and swallow their own stinger', () async {
    await start(MusicMood.adventure);
    director.cue(MusicMood.victory);
    await pumpEventQueue();
    mixer.advance(_s(0.2));
    director
      ..stinger(Stinger.victory)
      ..cue(MusicMood.victory)
      ..update(1 / 60);
    expect(director.playingMood, MusicMood.victory);
    final intro = mixer.active('victory-bed-intro').single;
    final beat = _s(0.5);
    final origin = const Duration(seconds: 10) + ProceduralMusicDirector.lead;
    expect((intro.at! - origin).inMicroseconds % beat.inMicroseconds, 0);
    expect(mixer.active('stinger'), isEmpty);
    expect(director.log.any((l) => l.contains('stinger victory (in jingle)')), isTrue);
  });

  test('intensity fades the layers in and out', () async {
    await start(MusicMood.adventure);
    double target(String stem) => mixer.active('adventure-$stem-loop').single.target;
    director.setIntensity(1);
    expect(target('hot'), closeTo(ProceduralMusicDirector.level * 0.8, 1e-9));
    director.setIntensity(0);
    expect(target('hot'), 0);
    expect(target('lead'), 0);
    expect(target('bed'), closeTo(ProceduralMusicDirector.level, 1e-9));
  });

  test('ducking, the games volume and prayer mute follow the bus', () async {
    await start(MusicMood.adventure);
    double bed() => mixer.active('adventure-bed-loop').single.target;
    director.setDucked(true);
    expect(bed(), closeTo(ProceduralMusicDirector.level * ProceduralMusicDirector.duckGain, 1e-9));
    director.setDucked(false);
    mixer.gain = 0.5;
    director.update(1 / 60);
    expect(bed(), closeTo(ProceduralMusicDirector.level * 0.5, 1e-9));
    director.setPrayerMuted(true);
    expect(bed(), 0);
    director
      ..stinger(Stinger.hit)
      ..update(1 / 60);
    expect(mixer.active('stinger'), isEmpty, reason: 'no stingers during prayer');
    director.setPrayerMuted(false);
    expect(bed(), closeTo(ProceduralMusicDirector.level * 0.5, 1e-9), reason: 'the bed resumes where it is');
  });

  test('stingers land on the next beat, transposed onto the sounding chord', () async {
    await start(MusicMood.adventure);
    // The scene's first cue plays its 1-bar intro: loop at 12.06 s; the
    // loop's bar 2 holds V.
    final loopAt = const Duration(seconds: 10) + ProceduralMusicDirector.lead + _s(2);
    mixer.clock = loopAt + _s(2.1);
    director
      ..stinger(Stinger.pickup)
      ..update(1 / 60);
    final tonal = mixer.active('stinger-pickup-maj').single;
    final drums = mixer.active('stinger-pickup-drums').single;
    expect(tonal.at, loopAt + _s(2.5));
    expect(drums.at, tonal.at);
    expect(tonal.speed, closeTo(math.pow(2, -5 / 12), 1e-9), reason: 'V is 7 semitones up = 5 down');
    expect(drums.speed, 1);
    expect(tonal.volume, closeTo(ProceduralMusicDirector.stingerLevel, 1e-9));
  });

  test('pause stops the bed; resume re-enters the loop without the intro', () async {
    await start(MusicMood.title);
    director.pause();
    expect(mixer.active(), isEmpty);
    director.update(1 / 60);
    expect(director.playingMood, isNull, reason: 'nothing restarts while paused');
    director.resume();
    expect(director.playingMood, MusicMood.title);
    expect(mixer.active('intro'), isEmpty);
    expect(mixer.active('title-bed-loop'), hasLength(1));
  });

  test('stop fades out; dispose releases every source', () async {
    await start(MusicMood.adventure);
    director.stop();
    expect(director.mood, isNull);
    expect(mixer.active(), isEmpty);
    await director.dispose();
    expect(mixer.sources, isEmpty);
  });

  test('the LRU keeps loaded audio under the budget and never evicts the playing cue', () async {
    final probe = FakeCueSource();
    final bytes = (await probe.renderCue(eraScore(Era.rubberHose), MusicMood.adventure, 1)).bytes;
    await start(MusicMood.adventure, prefetch: true, budget: (bytes * 2.5).round());
    for (var i = 0; i < 20; i++) {
      await pumpEventQueue();
    }
    expect(director.loadedBytes, lessThanOrEqualTo((bytes * 2.5).round()));
    expect(director.loadedMoods, contains(MusicMood.adventure));
    director.cue(MusicMood.boss);
    for (var i = 0; i < 20; i++) {
      await pumpEventQueue();
    }
    director.update(1 / 60);
    expect(director.playingMood, MusicMood.boss);
    expect(director.loadedBytes, lessThanOrEqualTo((bytes * 2.5).round()));
  });
}
