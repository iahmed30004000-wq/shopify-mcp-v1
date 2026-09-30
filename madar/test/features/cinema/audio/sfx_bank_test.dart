import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/audio/era_scores.dart';
import 'package:madar/features/cinema/engine/audio/runtime/sfx_bank.dart';
import 'package:madar/features/cinema/engine/audio/sfx/sfx_synth.dart';
import 'package:madar/features/cinema/engine/core/audio.dart';
import 'package:madar/features/cinema/engine/core/era.dart';

import 'fake_mixer.dart';

CinemaAudioContext _ctx() => CinemaAudioContext(sound: SilentSoundService(), era: Era.vhs, score: eraScore(Era.vhs), seed: 3);

void main() {
  late FakeCinemaMixer mixer;
  late FakeCueSource source;
  late ProceduralSfxBank bank;
  var now = Duration.zero;

  Future<void> start() async {
    mixer = FakeCinemaMixer();
    source = FakeCueSource();
    now = Duration.zero;
    bank = ProceduralSfxBank(_ctx(), mixer: mixer, source: source, clock: () => now);
    await bank.prepare();
  }

  test('is silent and renders nothing without the SoLoud service', () async {
    final src = FakeCueSource();
    final b = ProceduralSfxBank(_ctx(), source: src);
    await b.prepare();
    expect(b.isReady, isTrue);
    b.play(CinemaSound.coin);
    b.playExtra(CinemaSfx.whistle);
    expect(src.requests, isEmpty);
    await b.dispose();
  });

  test('loads every sound and every extra of the era kit', () async {
    await start();
    expect(source.requests, ['sfx vhs']);
    expect(bank.loadedKeys.length, CinemaSound.values.length + CinemaSfx.values.length);
    expect(mixer.sources.values.every((s) => !s.$3), isTrue, reason: 'effects are decoded up front for low latency');
  });

  test('plays on the games bus with a little pitch variation', () async {
    await start();
    mixer.gain = 0.5;
    final speeds = <double>{};
    for (var i = 0; i < 12; i++) {
      now += const Duration(milliseconds: 100);
      bank.play(CinemaSound.jump, volume: 0.8, pitch: 1.2, pan: 2);
    }
    final voices = mixer.voices.values.toList();
    expect(voices, isNotEmpty);
    for (final v in voices) {
      expect(v.volume, closeTo(0.5 * ProceduralSfxBank.level * 0.8, 1e-9));
      expect(v.speed, inInclusiveRange(1.2 * (1 - ProceduralSfxBank.pitchSpread), 1.2 * (1 + ProceduralSfxBank.pitchSpread)));
      expect(v.pan, 1, reason: 'pan is clamped');
      speeds.add(v.speed);
    }
    expect(speeds.length, greaterThan(3), reason: 'repeats are not machine-gunned');
  });

  test('caps polyphony per sound and drops retriggers that come too fast', () async {
    await start();
    bank.play(CinemaSound.hit);
    bank.play(CinemaSound.hit); // same instant: dropped
    expect(mixer.voices, hasLength(1));
    for (var i = 0; i < 4; i++) {
      now += const Duration(milliseconds: 30);
      bank.play(CinemaSound.hit);
    }
    expect(mixer.active('hit'), hasLength(3), reason: 'the oldest voice fades out');
    expect(mixer.voices.values.first.fades.single.thenStop, isTrue);
  });

  test('prayer mute and the sound switch silence effects', () async {
    await start();
    bank.play(CinemaSound.explosion);
    bank.setPrayerMuted(true);
    expect(mixer.active(), isEmpty, reason: 'ringing effects are cut');
    now += const Duration(seconds: 1);
    bank.play(CinemaSound.coin);
    expect(mixer.voices, hasLength(1));
    bank.setPrayerMuted(false);
    mixer.gain = 0; // switch off / games volume 0
    bank.play(CinemaSound.coin);
    expect(mixer.voices, hasLength(1));
    mixer.gain = 1;
    bank.play(CinemaSound.coin);
    expect(mixer.voices, hasLength(2));
  });

  test('extras play through the SfxBank extension; dispose unloads', () async {
    await start();
    final SfxBank asBank = bank;
    asBank.playExtra(CinemaSfx.crowdCheer);
    expect(mixer.active('extra:crowdCheer'), hasLength(1));
    await bank.dispose();
    expect(mixer.sources, isEmpty);
    bank.play(CinemaSound.coin);
    expect(mixer.voices, hasLength(1));
  });
}
