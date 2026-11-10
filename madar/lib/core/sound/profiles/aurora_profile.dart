import 'dart:typed_data';

import '../sound_api.dart';
import '../synth/synth.dart';
import 'profile_base.dart';

/// Aurora – airy, detuned synth shimmer in maqam 'Ajam on A4.
///
/// Soft polyBLEP saw ensembles breathe through sweeping low-passes; sine
/// "blips" glide into pitch. A large, bright room gives the polar-sky width.
final class AuroraProfile extends SoundProfile {
  const AuroraProfile();

  @override
  String get id => 'aurora';
  @override
  Maqam get maqam => Maqam.ajam;
  @override
  double get tonicHz => 440.0; // A4
  @override
  ReverbSpec get room => const ReverbSpec(roomSize: 0.68, damping: 0.2, preDelayMs: 20);

  Float64List _blip(SfxCanvas c, double from, double to, {double dur = 0.12, double t60 = 0.12, double glide = 0.03, double amp = 1}) =>
      Instruments.glide(c.sampleRate,
          fromHz: from, toHz: to, durSec: dur, glideSec: glide, t60: t60, amp: amp, harmonics: const [0.18, 0.05], attackMs: 3);

  Float64List _pad(
    SfxCanvas c,
    double hz, {
    double dur = 0.35,
    double from = 700,
    double to = 4200,
    Adsr env = const Adsr(attack: 0.03, decay: 0.15, sustain: 0.6, release: 0.18),
    double amp = 1,
  }) =>
      Instruments.pad(c.sampleRate,
          freq: hz, durSec: dur, rng: c.rng, voices: 3, detuneCents: 16, cutoffFrom: from, cutoffTo: to, env: env, amp: amp);

  Float64List _bell(SfxCanvas c, double hz, {double t60 = 0.6, double amp = 1}) =>
      Instruments.modal(c.sampleRate, freq: hz, modes: Modes.crystal, t60: t60, amp: amp, attackMs: 2);

  @override
  void voice(Sfx sfx, SfxCanvas c) {
    switch (sfx) {
      case Sfx.tap:
        c.place(_blip(c, note(7) * 1.06, note(7), dur: 0.07, t60: 0.05, glide: 0.012), 0, send: 0.1);
      case Sfx.toggleOn:
        c.place(_blip(c, note(4) * 0.94, note(4), t60: 0.15, amp: 0.8), 0, pan: 0.1, send: 0.25);
        c.place(_blip(c, note(7) * 0.94, note(7), dur: 0.2, t60: 0.2), 0.06, pan: -0.1, send: 0.3);
      case Sfx.toggleOff:
        c.place(_blip(c, note(7) * 1.05, note(7), t60: 0.1, amp: 0.7), 0, pan: -0.1, send: 0.2);
        c.place(_blip(c, note(4) * 1.05, note(4), dur: 0.16, t60: 0.14), 0.055, pan: 0.1, send: 0.25);
      case Sfx.sheetOpen:
        Gestures.whoosh(c, dur: 0.32, fromHz: 500, toHz: 5000, q: 0.7, peakAt: 0.55, amp: 0.8, pan: -0.25, panTo: 0.25, send: 0.35);
        c.place(_pad(c, note(4), dur: 0.34, from: 600, to: 5000, env: const Adsr(attack: 0.12, decay: 0.1, sustain: 0.8, release: 0.16)), 0.02,
            gain: 0.35, send: 0.4);
      case Sfx.sheetClose:
        Gestures.whoosh(c, dur: 0.26, fromHz: 4000, toHz: 420, q: 0.7, peakAt: 0.3, amp: 0.8, pan: 0.25, panTo: -0.2, send: 0.3);
        c.place(_pad(c, note(0), dur: 0.22, from: 3000, to: 500), 0, gain: 0.25, send: 0.3);
      case Sfx.complete:
        // Rising 'Ajam triad of shimmering pads, crowned with sine bells.
        const steps = [0, 2, 4];
        for (var i = 0; i < 3; i++) {
          c.place(_pad(c, note(steps[i]), dur: 0.32, from: 900, to: 5200), i * 0.09, gain: 0.5, pan: -0.25 + 0.25 * i, send: 0.4);
          c.place(_bell(c, note(steps[i], octave: 1), t60: 0.7, amp: 0.5), i * 0.09, pan: -0.25 + 0.25 * i, send: 0.5);
        }
      case Sfx.levelUp:
        const run = [0, 2, 4, 6, 7, 9, 11];
        for (var i = 0; i < run.length; i++) {
          c.place(_blip(c, note(run[i]) * 0.97, note(run[i]), dur: 0.14, t60: 0.12, glide: 0.015), i * 0.034,
              gain: 0.45 + 0.06 * i, pan: -0.5 + i / 6, send: 0.4);
        }
        const land = 0.26;
        for (final (i, d) in const [7, 9, 11].indexed) {
          c.place(_pad(c, note(d), dur: 0.55, from: 800, to: 6000, env: const Adsr(attack: 0.02, decay: 0.3, sustain: 0.5, release: 0.25)),
              land + i * 0.01,
              gain: 0.4, pan: -0.2 + 0.2 * i, send: 0.5);
        }
        c.place(_bell(c, note(14), t60: 0.8, amp: 0.4), land, send: 0.6);
      case Sfx.delete:
        // A descending filtered "fwoop".
        c.place(_pad(c, note(0, octave: -1), dur: 0.3, from: 3200, to: 300, env: const Adsr(attack: 0.01, decay: 0.2, sustain: 0.4, release: 0.1)),
            0,
            send: 0.25);
        c.place(_blip(c, note(0), note(0, octave: -1), dur: 0.25, t60: 0.2, glide: 0.2, amp: 0.5), 0, send: 0.2);
      case Sfx.undo:
        // Reverse-shaped shimmer: swells in, stops short.
        c.place(_pad(c, note(4), dur: 0.22, from: 400, to: 3200, env: const Adsr(attack: 0.16, decay: 0.02, sustain: 1, release: 0.05)), 0,
            send: 0.25);
        c.place(_bell(c, note(7), t60: 0.2, amp: 0.4), 0.16, send: 0.3);
      case Sfx.swipe:
        Gestures.whoosh(c, dur: 0.15, fromHz: 1200, toHz: 4800, q: 0.9, peakAt: 0.35, pan: 0.3, panTo: -0.3, send: 0.2);
      case Sfx.pickUp:
        c.place(_blip(c, note(4), note(7), dur: 0.14, t60: 0.12, glide: 0.06), 0, send: 0.2);
      case Sfx.drop:
        c.place(_blip(c, note(4), note(0), dur: 0.16, t60: 0.1, glide: 0.05, amp: 0.7), 0, send: 0.15);
        c.place(Instruments.glide(c.sampleRate, fromHz: 180, toHz: 70, durSec: 0.14, glideSec: 0.08, t60: 0.1, harmonics: const [0.35, 0.15]), 0,
            gain: 0.5);
      case Sfx.error:
        // Two soft, low, hollow tones stepping down.
        c.place(
            Instruments.glide(c.sampleRate,
                fromHz: note(1), toHz: note(1), durSec: 0.2, t60: 0.3, attackMs: 8, harmonics: const [0.12, 0.18, 0, 0.06]),
            0,
            send: 0.2);
        c.place(
            Instruments.glide(c.sampleRate,
                fromHz: note(0), toHz: note(0), durSec: 0.3, t60: 0.4, attackMs: 8, harmonics: const [0.12, 0.18, 0, 0.06]),
            0.16,
            send: 0.25);
      case Sfx.notify:
        c.place(_bell(c, note(4), t60: 0.7), 0, pan: 0.15, send: 0.45);
        c.place(_bell(c, note(7), t60: 0.8), 0.12, pan: -0.15, send: 0.5);
        c.place(_pad(c, note(7), dur: 0.45, from: 700, to: 3500), 0.12, gain: 0.25, send: 0.45);
      case Sfx.navigate:
        c.place(_blip(c, note(7) * 1.04, note(7), dur: 0.06, t60: 0.04, glide: 0.01, amp: 0.8), 0, send: 0.1);
      case Sfx.back:
        c.place(_blip(c, note(4) * 1.04, note(4), dur: 0.06, t60: 0.04, glide: 0.01, amp: 0.8), 0, send: 0.1);
      case Sfx.prayerLit:
        // A slow shimmering bloom resolving into a luminous major-third bell.
        for (final (i, d) in const [0, 4, 9].indexed) {
          c.place(
              _pad(c, note(d), dur: 0.8, from: 500, to: 5200, env: const Adsr(attack: 0.3, decay: 0.3, sustain: 0.6, release: 0.3), amp: 0.8),
              i * 0.02,
              gain: 0.35, pan: -0.3 + 0.3 * i, send: 0.5);
        }
        c.place(Instruments.modal(c.sampleRate, freq: note(0), modes: Modes.bell(tierceCents: 400), t60: 1.6, attackMs: 4), 0.28, send: 0.55);
        c.place(_bell(c, note(14), t60: 0.8, amp: 0.3), 0.3, pan: 0.25, send: 0.6);
      case Sfx.sparkle:
        Gestures.scatter(c,
            freqs: [note(7), note(9), note(11), note(14)],
            count: 5,
            spanSec: 0.3,
            voice: (hz) => _blip(c, hz * 1.03, hz, dur: 0.1, t60: 0.08, glide: 0.01));
      case Sfx.countTick:
        c.place(Instruments.glide(c.sampleRate, fromHz: note(4, octave: 2), toHz: note(4, octave: 2), durSec: 0.03, t60: 0.02, attackMs: 1), 0,
            send: 0.03);
    }
  }
}
