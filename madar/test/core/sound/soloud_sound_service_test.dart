import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/soloud_sound_service.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/core/sound/sound_kit.dart';

import 'sound_fakes.dart';

void main() {
  group('graceful fallback', () {
    test('in the test environment the default service is silent and never throws', () async {
      final s = SoloudSoundService();
      await s.init();
      expect(s.status, SoundEngineStatus.silent);
      expect(s.isSilent, isTrue);
      for (final sfx in Sfx.values) {
        s.play(sfx, pitch: 1.3);
      }
      await s.setProfile('desert');
      await s.startAmbient();
      s.swell(1);
      s.setPrayerMute(true);
      s.setVolume(SoundCategory.games, 0.3);
      expect(s.volumeOf(SoundCategory.games), 0.3);
      expect(await s.loadClip('x', tinyAmbient('x')), isNull);
      await s.stopAmbient();
      await s.dispose();
      expect(s.status, SoundEngineStatus.disposed);
    });

    test('an engine whose init throws degrades to silent', () async {
      final engine = FakeAudioEngine(initError: StateError('no libflutter_soloud_plugin.so'));
      final s = SoloudSoundService(engine: engine, nativeAudio: true, renderKit: (id) async => tinyKit(id));
      await s.init();
      expect(s.status, SoundEngineStatus.silent);
      s.play(Sfx.tap);
      expect(engine.voices, isEmpty);
      expect(engine.loaded, isEmpty);
      await s.dispose();
      expect(engine.shutDown, isFalse, reason: 'nothing to shut down');
    });

    test('an engine that never starts times out to silent', () async {
      final s = SoloudSoundService(
        engine: FakeAudioEngine(initHangs: true),
        nativeAudio: true,
        initTimeout: const Duration(milliseconds: 20),
      );
      await s.init();
      expect(s.status, SoundEngineStatus.silent);
    });
  });

  group('with an engine', () {
    late FakeAudioEngine engine;
    late FakeTime time;
    late Map<String, Completer<SoundKit>> pendingKits;
    late List<String> kitRenders;
    late List<String> ambientRenders;

    SoloudSoundService make({bool deferKits = false}) => SoloudSoundService(
          engine: engine,
          nativeAudio: true,
          clock: time.clock,
          timer: time.timer,
          renderKit: (id) {
            kitRenders.add(id);
            if (!deferKits) return Future.value(tinyKit(id));
            return (pendingKits[id] = Completer<SoundKit>()).future;
          },
          renderAmbient: (id) async {
            ambientRenders.add(id);
            return tinyAmbient(id);
          },
        );

    setUp(() {
      engine = FakeAudioEngine();
      time = FakeTime();
      pendingKits = {};
      kitRenders = [];
      ambientRenders = [];
    });

    test('init loads a complete kit and plays on the UI bus', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      expect(s.status, SoundEngineStatus.ready);
      expect(s.loadedProfile, 'lapis');
      expect(engine.loaded.length, Sfx.values.length);

      s.setVolume(SoundCategory.ui, 0.5);
      s.play(Sfx.complete, volume: 0.8, pitch: 3);
      final v = engine.voicesOf('complete').single;
      expect(v.volume, closeTo(0.4, 1e-9));
      expect(v.speed, 2.0, reason: 'pitch is clamped to 0.5..2');
    });

    test('global switch and zero volume silence UI sounds', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      s.enabled = false;
      s.play(Sfx.tap);
      expect(engine.voices, isEmpty);
      s.enabled = true;
      s.setVolume(SoundCategory.ui, 0);
      s.play(Sfx.tap);
      expect(engine.voices, isEmpty);
    });

    test('polyphony: taps are capped at 3 voices, oldest faded; fast retriggers dropped', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      for (var i = 0; i < 4; i++) {
        s.play(Sfx.tap);
        time.advance(const Duration(milliseconds: 30));
      }
      final taps = engine.voicesOf('tap').toList();
      expect(taps.length, 4);
      expect(taps.first.stopped, isTrue, reason: 'oldest voice stolen');
      expect(taps.first.fades.last.$1, 0);
      expect(taps.skip(1).every((v) => !v.stopped), isTrue);

      // Two taps 10 ms apart → the second is debounced.
      time.advance(const Duration(seconds: 1));
      s.play(Sfx.tap);
      time.advance(const Duration(milliseconds: 10));
      s.play(Sfx.tap);
      expect(engine.voicesOf('tap').length, 5);
    });

    test('finished voices free their polyphony slots', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      for (var i = 0; i < 6; i++) {
        s.play(Sfx.tap);
        time.advance(const Duration(milliseconds: 600)); // > 0.5 s tiny kit length
      }
      expect(engine.voicesOf('tap').where((v) => v.stopped), isEmpty);
    });

    test('profile switch swaps the kit atomically and releases old sources later', () async {
      final s = make(deferKits: true);
      final init = s.init();
      await init;
      pendingKits['lapis']!.complete(tinyKit('lapis'));
      await s.kitReady;
      final lapisSources = engine.loaded.keys.toSet();

      // Request emerald, then aurora before emerald finishes rendering.
      final f1 = s.setProfile('emerald');
      final f2 = s.setProfile('aurora');
      s.play(Sfx.tap);
      expect(engine.voicesOf('lapis/tap').length, 1, reason: 'old kit keeps playing meanwhile');

      pendingKits['emerald']!.complete(tinyKit('emerald'));
      pendingKits['aurora']!.complete(tinyKit('aurora'));
      await Future.wait([f1, f2]);
      expect(s.loadedProfile, 'aurora');
      expect(engine.calls.where((c) => c.contains('madar/emerald/')), isEmpty, reason: 'stale render discarded');

      time.advance(const Duration(milliseconds: 40));
      s.play(Sfx.tap);
      expect(engine.voicesOf('aurora/tap').length, 1);

      expect(engine.unloaded.toSet().intersection(lapisSources), isEmpty, reason: 'not yet – voices ring out');
      time.advance(const Duration(seconds: 2));
      await Future<void>.delayed(Duration.zero);
      expect(engine.unloaded.toSet(), containsAll(lapisSources));
    });

    test('reverting to the loaded profile cancels a pending switch without re-rendering', () async {
      final s = make(deferKits: true);
      await s.init();
      pendingKits['lapis']!.complete(tinyKit('lapis'));
      await s.kitReady;
      final pending = s.setProfile('emerald');
      await s.setProfile('lapis');
      pendingKits['emerald']!.complete(tinyKit('emerald'));
      await pending;
      expect(s.loadedProfile, 'lapis');
      expect(kitRenders, ['lapis', 'emerald']);
      expect(engine.calls.where((c) => c.contains('madar/emerald/')), isEmpty);
    });

    test('setProfile before init is honoured by init; unknown ids fall back', () async {
      final s = make();
      await s.setProfile('pearl');
      await s.init();
      await s.kitReady;
      expect(s.loadedProfile, 'pearl');
      await s.setProfile('???');
      expect(s.loadedProfile, 'lapis');
    });

    test('ambient: fades in on its bus, follows volume, stops with a fade', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      s.setVolume(SoundCategory.ambient, 0.5);
      await s.startAmbient();
      final amb = engine.voicesOf('ambient/lapis').single;
      expect(amb.looping, isTrue);
      expect(amb.protect, isTrue);
      expect(amb.lowPassHz, SoloudSoundService.ambientCutoffHz);
      expect(engine.lowPassSources, contains(amb.source));
      expect(amb.volume, closeTo(0.5 * SoloudSoundService.ambientLevel, 1e-9));
      expect(s.ambientPlaying, isTrue);

      s.setVolume(SoundCategory.ambient, 1);
      expect(amb.volume, closeTo(SoloudSoundService.ambientLevel, 1e-9));

      await s.stopAmbient();
      expect(amb.volume, 0);
      expect(amb.stopped, isTrue);
      expect(s.ambientPlaying, isFalse);
    });

    test('swell opens the filter and lifts the bed, then settles back', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      await s.startAmbient();
      final amb = engine.voicesOf('ambient').single;
      final base = amb.volume;
      s.swell(1);
      expect(amb.volume, greaterThan(base));
      expect(amb.lowPassHz, greaterThan(SoloudSoundService.ambientCutoffHz * 4));
      time.advance(const Duration(seconds: 2));
      expect(amb.volume, closeTo(base, 1e-9));
      expect(amb.lowPassHz, SoloudSoundService.ambientCutoffHz);
    });

    test('prayer mute silences ambient + games but not UI or the adhan', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      await s.startAmbient();
      final amb = engine.voicesOf('ambient').single;
      final game = (await s.loadClip('game-loop', tinyAmbient('g')))!;
      final adhan = (await s.loadClip('adhan', tinyAmbient('a')))!;
      final gv = s.playClip(game, loop: true)!;
      final av = s.playClip(adhan, category: SoundCategory.prayer)!;

      s.setPrayerMute(true);
      expect(s.prayerMuted, isTrue);
      expect(amb.volume, 0);
      time.advance(const Duration(seconds: 1));
      expect(amb.paused, isTrue, reason: 'paused once silent');
      expect(engine.voices[gv]!.volume, 0);
      expect(engine.voices[av]!.volume, greaterThan(0));
      s.play(Sfx.prayerLit);
      expect(engine.voicesOf('prayerLit').single.volume, greaterThan(0), reason: 'UI stays audible');

      s.setPrayerMute(false);
      expect(amb.paused, isFalse);
      expect(amb.volume, greaterThan(0));
      expect(engine.voices[gv]!.volume, greaterThan(0));
    });

    test('app lifecycle pauses the bed in background and pre-warms on return', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      await s.startAmbient();
      final amb = engine.voicesOf('ambient').single;
      s.onAppLifecycleChanged(foreground: false);
      time.advance(const Duration(seconds: 1));
      expect(amb.paused, isTrue);
      s.onAppLifecycleChanged(foreground: true);
      await Future<void>.delayed(Duration.zero);
      expect(amb.paused, isFalse);
      expect(amb.volume, greaterThan(0));
      expect(engine.prewarms, 1);
    });

    test('ambient follows the profile with a cross-fade', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      await s.startAmbient();
      final first = engine.voicesOf('ambient/lapis').single;
      await s.setProfile('desert');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      final second = engine.voicesOf('ambient/desert').single;
      expect(first.stopped, isTrue);
      expect(first.volume, 0);
      expect(second.volume, greaterThan(0));
      expect(ambientRenders, ['lapis', 'desert']);
    });

    test('dispose shuts the engine down and makes every call a no-op', () async {
      final s = make();
      await s.init();
      await s.kitReady;
      await s.dispose();
      expect(engine.shutDown, isTrue);
      s.play(Sfx.tap);
      await s.startAmbient();
      expect(engine.voices, isEmpty);
      expect(time.pending, 0);
    });
  });
}
