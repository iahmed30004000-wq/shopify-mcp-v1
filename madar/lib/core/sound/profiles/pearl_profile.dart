import 'dart:typed_data';

import '../sound_api.dart';
import '../synth/synth.dart';
import 'profile_base.dart';

/// Pearl – delicate crystal pings in maqam Nahawand on C5.
///
/// The light theme's sounds are the smallest and airiest. Completion is a
/// resolution rather than a triad: G → B (Nahawand's leading tone) → C.
final class PearlProfile extends SoundProfile {
  const PearlProfile();

  @override
  String get id => 'pearl';
  @override
  Maqam get maqam => Maqam.nahawand;
  @override
  double get tonicHz => 523.25; // C5
  @override
  ReverbSpec get room => const ReverbSpec(roomSize: 0.6, damping: 0.15, preDelayMs: 14);

  Float64List _ping(SfxCanvas c, double hz, {double t60 = 0.45, double amp = 1, double brightness = 1}) =>
      Instruments.modal(c.sampleRate, freq: hz, modes: Modes.crystal, t60: t60, amp: amp, brightness: brightness, attackMs: 0.8);

  Float64List _sine(SfxCanvas c, double hz, {double dur = 0.3, double t60 = 0.3, double amp = 1}) =>
      Instruments.glide(c.sampleRate, fromHz: hz, toHz: hz, durSec: dur, t60: t60, amp: amp, attackMs: 6, harmonics: const [0.08]);

  @override
  void voice(Sfx sfx, SfxCanvas c) {
    switch (sfx) {
      case Sfx.tap:
        c.place(_ping(c, note(7), t60: 0.07), 0, send: 0.12);
        c.place(Instruments.click(c.sampleRate, rng: c.rng, centerHz: 5200, durMs: 2), 0, gain: 0.15);
      case Sfx.toggleOn:
        c.place(_ping(c, note(4), t60: 0.28, amp: 0.8), 0, pan: 0.1, send: 0.25);
        c.place(_ping(c, note(7), t60: 0.35), 0.06, pan: -0.1, send: 0.3);
      case Sfx.toggleOff:
        c.place(_ping(c, note(7), t60: 0.2, amp: 0.7, brightness: 0.7), 0, pan: -0.1, send: 0.2);
        c.place(_ping(c, note(4), t60: 0.25, brightness: 0.7), 0.055, pan: 0.1, send: 0.25);
      case Sfx.sheetOpen:
        Gestures.whoosh(c, dur: 0.3, fromHz: 600, toHz: 4000, q: 0.8, peakAt: 0.55, amp: 0.8, pan: -0.2, panTo: 0.2, send: 0.35);
        c.place(_ping(c, note(9), t60: 0.3), 0.18, gain: 0.25, send: 0.6);
      case Sfx.sheetClose:
        Gestures.whoosh(c, dur: 0.24, fromHz: 3500, toHz: 600, q: 0.8, peakAt: 0.3, amp: 0.8, pan: 0.2, panTo: -0.15, send: 0.3);
      case Sfx.complete:
        c.place(_ping(c, note(4), t60: 0.8), 0, pan: -0.22, send: 0.4);
        c.place(_ping(c, note(6), t60: 0.8), 0.085, pan: 0, send: 0.45);
        c.place(_ping(c, note(7), t60: 1.0), 0.17, pan: 0.22, send: 0.5);
        c.place(_ping(c, note(14), t60: 0.5, amp: 0.25), 0.18, pan: 0.3, send: 0.7);
      case Sfx.levelUp:
        const run = [0, 2, 4, 6, 7, 9, 11];
        for (var i = 0; i < run.length; i++) {
          c.place(_ping(c, note(run[i]), t60: 0.25), i * 0.035, gain: 0.45 + 0.07 * i, pan: -0.5 + i / 6, send: 0.4);
        }
        const land = 0.27;
        c.place(_ping(c, note(7), t60: 1.1), land, pan: -0.15, send: 0.5);
        c.place(_ping(c, note(11), t60: 1.0, amp: 0.6), land + 0.012, pan: 0.15, send: 0.5);
        c.place(_ping(c, note(14), t60: 0.9, amp: 0.45), land + 0.024, send: 0.6);
        Gestures.scatter(c,
            freqs: [note(16), note(18), note(21)],
            count: 4,
            spanSec: 0.3,
            start: land + 0.06,
            gain: 0.14,
            voice: (hz) => _ping(c, hz, t60: 0.15));
      case Sfx.delete:
        // Pearls rolling away down the scale.
        for (final (i, d) in const [4, 2, 0].indexed) {
          c.place(_ping(c, note(d), t60: 0.16, amp: 1 - 0.2 * i), i * 0.05, pan: 0.2 - 0.2 * i, send: 0.25);
        }
        Gestures.whoosh(c, at: 0.02, dur: 0.22, fromHz: 3000, toHz: 800, amp: 0.25, peakAt: 0.2, send: 0.2);
      case Sfx.undo:
        c.place(_ping(c, note(0), t60: 0.12, amp: 0.7), 0, send: 0.2);
        c.place(_ping(c, note(4), t60: 0.18), 0.055, send: 0.25);
      case Sfx.swipe:
        Gestures.whoosh(c, dur: 0.14, fromHz: 1400, toHz: 5200, q: 1.0, peakAt: 0.35, pan: 0.25, panTo: -0.25, send: 0.15);
      case Sfx.pickUp:
        c.place(Instruments.fmBell(c.sampleRate, freq: note(7), ratio: 2.0, index: 0.4, indexT60: 0.05, t60: 0.14, glideCents: -250), 0,
            send: 0.2);
      case Sfx.drop:
        c.place(_ping(c, note(0, octave: -1), t60: 0.14, brightness: 0.6), 0, send: 0.15);
        c.place(_ping(c, note(4, octave: -1), t60: 0.08, amp: 0.4), 0.003, send: 0.12);
        c.place(Instruments.frameDrum(c.sampleRate, rng: c.rng, freq: 150, t60: 0.1, tone: 0.3, amp: 0.3), 0, send: 0.05);
      case Sfx.error:
        // A soft half-step fall (A♭ → G) in round sines.
        c.place(_sine(c, note(5, octave: -1), dur: 0.2, t60: 0.3), 0, send: 0.25);
        c.place(_sine(c, note(4, octave: -1), dur: 0.32, t60: 0.4), 0.15, send: 0.3);
      case Sfx.notify:
        c.place(_ping(c, note(4), t60: 0.7), 0, pan: 0.15, send: 0.45);
        c.place(_ping(c, note(7), t60: 0.8), 0.12, pan: -0.15, send: 0.5);
      case Sfx.navigate:
        c.place(_ping(c, note(9), t60: 0.04, amp: 0.8), 0, send: 0.1);
      case Sfx.back:
        c.place(_ping(c, note(7), t60: 0.04, amp: 0.8), 0, send: 0.1);
      case Sfx.prayerLit:
        Gestures.whoosh(c, dur: 0.26, fromHz: 400, toHz: 6000, q: 0.7, amp: 0.4, peakAt: 0.92, send: 0.5);
        c.place(Instruments.modal(c.sampleRate, freq: note(0), modes: Modes.bell(tierceCents: 300), t60: 1.6, attackMs: 3), 0.24, send: 0.5);
        c.place(_ping(c, note(7), t60: 1.1, amp: 0.45), 0.25, pan: -0.2, send: 0.6);
        c.place(_ping(c, note(11), t60: 1.0, amp: 0.3), 0.3, pan: 0.2, send: 0.65);
        c.place(_ping(c, note(14), t60: 0.8, amp: 0.2), 0.34, pan: 0.05, send: 0.7);
      case Sfx.sparkle:
        Gestures.scatter(c,
            freqs: [note(9), note(11), note(14), note(16)],
            count: 6,
            spanSec: 0.32,
            voice: (hz) => _ping(c, hz, t60: 0.14));
      case Sfx.countTick:
        c.place(_ping(c, note(7, octave: 1), t60: 0.02), 0, send: 0.04);
    }
  }
}
