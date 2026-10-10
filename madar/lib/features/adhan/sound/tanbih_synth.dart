import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../../core/sound/synth/synth.dart';
import '../domain/adhan_sound.dart';

/// Madar's procedural "tanbih" (alert) tones: struck singing bowls, bells,
/// glass and crystal in a room – calm, respectful signals that it is time,
/// never a voice and never a melody imitating the adhan.
///
/// Pure Dart and deterministic (seeded), so the same bytes come out of
/// `dart run tool/generate_adhan_tones.dart` (the notification sounds in
/// `android/app/src/main/res/raw/`) and of the in-app preview.
abstract final class TanbihSynth {
  /// 22.05 kHz mono 16-bit: bells up to 11 kHz, ~44 KB per second.
  static const sampleRate = 22050;

  static double _hz(num midi) => midiHz(midi);

  /// Renders [tone] as a stereo buffer (levelled, limited to −1 dBFS).
  static StereoBuffer render(TanbihTone tone, {int sampleRate = sampleRate}) {
    final c = SfxCanvas(
      sampleRate: sampleRate,
      maxSeconds: tone.length.inMilliseconds / 1000 + 4,
      seed: _seed(tone),
      room: switch (tone) {
        TanbihTone.chime || TanbihTone.sunrise => const ReverbSpec(roomSize: 0.62, damping: 0.45, preDelayMs: 14),
        _ => const ReverbSpec(roomSize: 0.82, damping: 0.5, preDelayMs: 22, width: 0.9),
      },
      minSeconds: 1,
    );
    final sr = c.sampleRate;
    switch (tone) {
      case TanbihTone.dawn:
        // A warm drone opening like first light, a bowl beneath, and four
        // crystal glints rising slowly above it.
        final drone = Instruments.pad(
          sr,
          freq: _hz(50),
          durSec: 12.5,
          rng: c.rng,
          voices: 3,
          detuneCents: 7,
          cutoffFrom: 220,
          cutoffTo: 1300,
          q: 0.6,
          env: const Adsr(attack: 3.2, decay: 2.0, sustain: 0.75, release: 4.0),
          amp: 0.22,
          sineOctaveMix: 0.4,
        );
        c.place(drone, 0, gain: 0.8, send: 0.35);
        c.place(_bowl(sr, _hz(50), t60: 7.5), 0.15, gain: 0.55, send: 0.4);
        const glints = [74.0, 77.5, 81.0, 86.0]; // D5, neutral F5, A5, D6 (Rast colour)
        for (var i = 0; i < glints.length; i++) {
          c.place(
            _crystal(sr, _hz(glints[i]), t60: 3.2 - i * 0.3),
            1.6 + i * 2.1,
            gain: 0.34 - i * 0.03,
            pan: i.isEven ? -0.25 : 0.25,
            send: 0.55,
          );
        }
        c.place(_bowl(sr, _hz(57), t60: 6.5), 9.4, gain: 0.45, pan: 0.1, send: 0.45);
      case TanbihTone.brass:
        // Two neutral-third bell pairs like a quiet tower clock, then one
        // long low bell.
        for (final start in [0.2, 3.4]) {
          c.place(_bell(sr, _hz(62), t60: 4.4), start, gain: 0.8, pan: -0.1, send: 0.35);
          c.place(_bell(sr, _hz(57), t60: 5.0), start + 1.05, gain: 0.8, pan: 0.1, send: 0.35);
        }
        c.place(_bell(sr, _hz(50), t60: 7.8), 6.8, gain: 0.95, send: 0.45);
        c.place(
          Instruments.fmBell(sr, freq: _hz(86), ratio: 3.5, index: 0.4, indexT60: 0.4, t60: 2.4, maxSec: 3),
          6.82,
          gain: 0.08,
          send: 0.6,
        );
      case TanbihTone.bowl:
        // Three singing-bowl strikes, each settling before the next.
        const strikes = [(0.1, 50.0, 10.0), (4.0, 57.0, 9.0), (7.9, 62.0, 8.0)];
        for (final (at, midi, t60) in strikes) {
          c.place(_bowl(sr, _hz(midi), t60: t60), at, gain: 0.85, pan: (midi - 56) / 20, send: 0.4);
          c.place(Instruments.click(sr, centerHz: 2400, amp: 0.2, rng: c.rng), at, gain: 0.25, send: 0.1);
        }
      case TanbihTone.chime:
        c.place(_glass(sr, _hz(81), t60: 1.6), 0.05, gain: 0.8, pan: -0.15, send: 0.4);
        c.place(_glass(sr, _hz(86), t60: 1.9), 0.42, gain: 0.8, pan: 0.15, send: 0.45);
      case TanbihTone.sunrise:
        const rise = [74.0, 81.0, 86.0];
        for (var i = 0; i < rise.length; i++) {
          c.place(_crystal(sr, _hz(rise[i]), t60: 1.5), 0.05 + i * 0.2, gain: 0.55, pan: -0.3 + i * 0.3, send: 0.5);
        }
    }
    final loudness = switch (tone) {
      TanbihTone.chime || TanbihTone.sunrise => -11.0,
      _ => -9.0,
    };
    return c.finish(loudnessDb: loudness, wet: 0.9);
  }

  /// [render] as 16-bit PCM WAV; mono by default (the phone speaker is mono
  /// and the notification sound is half the size).
  static Uint8List renderWav(TanbihTone tone, {int sampleRate = sampleRate, bool mono = true}) {
    final b = render(tone, sampleRate: sampleRate);
    final dither = SynthRandom(_seed(tone) ^ 0x5eed);
    if (!mono) return Wav.encodePcm16([b.left, b.right], sampleRate: b.sampleRate, dither: dither);
    final m = Float64List(b.frames);
    for (var i = 0; i < m.length; i++) {
      m[i] = 0.5 * (b.left[i] + b.right[i]);
    }
    return Wav.encodePcm16([m], sampleRate: b.sampleRate, dither: dither);
  }

  /// [renderWav] on a background isolate (in-app previews).
  static Future<Uint8List> renderWavInBackground(TanbihTone tone) => Isolate.run(() => renderWav(tone));

  static int _seed(TanbihTone t) => 0x7a4b1 + t.index * 7919;

  // Voices -------------------------------------------------------------------

  static Float64List _bowl(int sr, double f, {required double t60}) =>
      Instruments.modal(sr, freq: f, modes: Modes.bowl, t60: t60, attackMs: 4, maxSec: t60 * 1.4, brightness: 0.8);

  static Float64List _bell(int sr, double f, {required double t60}) => Instruments.modal(
    sr,
    freq: f,
    modes: Modes.bell(tierceCents: 350),
    t60: t60,
    attackMs: 2,
    maxSec: t60 * 1.4,
    brightness: 0.85,
  );

  static Float64List _glass(int sr, double f, {required double t60}) =>
      Instruments.modal(sr, freq: f, modes: Modes.glass, t60: t60, attackMs: 1.5, maxSec: t60 * 1.4, brightness: 0.7);

  static Float64List _crystal(int sr, double f, {required double t60}) =>
      Instruments.modal(sr, freq: f, modes: Modes.crystal, t60: t60, attackMs: 3, maxSec: math.max(0.5, t60 * 1.4));
}
