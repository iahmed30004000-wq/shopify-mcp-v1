import 'dart:typed_data';

import '../sound_api.dart';
import '../synth/synth.dart';
import 'profile_base.dart';

/// Desert – oud plucks (Karplus–Strong, doubled courses) and a soft frame
/// drum in maqam Hijaz on D4.
///
/// The Hijaz augmented second (E♭→F♯) is used as a grace note into the
/// completion chime and in the level-up run; the error is a Hijaz half-step
/// sigh. Drums speak in the classic *dum* (centre) and *tek* (rim) strokes.
final class DesertProfile extends SoundProfile {
  const DesertProfile();

  @override
  String get id => 'desert';
  @override
  Maqam get maqam => Maqam.hijaz;
  @override
  double get tonicHz => 293.66; // D4
  @override
  ReverbSpec get room => const ReverbSpec(roomSize: 0.5, damping: 0.5, preDelayMs: 18);

  Float64List _oud(SfxCanvas c, double hz, {double t60 = 0.8, double brightness = 0.55, double amp = 1}) => Instruments.pluck(
        c.sampleRate,
        freq: hz,
        rng: c.rng,
        t60: t60,
        brightness: brightness,
        pluckPos: 0.16,
        amp: amp,
        bodyHz: 230,
        bodyGainDb: 5,
        courses: 2,
        courseCents: 4,
      );

  Float64List _tek(SfxCanvas c, {double freq = 200, double t60 = 0.07, double amp = 1}) =>
      Instruments.frameDrum(c.sampleRate, rng: c.rng, freq: freq, t60: t60, tone: 0.9, amp: amp);

  Float64List _dum(SfxCanvas c, {double freq = 88, double t60 = 0.35, double amp = 1}) =>
      Instruments.frameDrum(c.sampleRate, rng: c.rng, freq: freq, t60: t60, tone: 0.05, amp: amp);

  @override
  void voice(Sfx sfx, SfxCanvas c) {
    switch (sfx) {
      case Sfx.tap:
        c.place(_tek(c, freq: 190, t60: 0.06), 0, send: 0.05);
      case Sfx.toggleOn:
        c.place(_oud(c, note(4), t60: 0.5, amp: 0.8), 0, pan: 0.1, send: 0.15);
        c.place(_oud(c, note(7), t60: 0.6), 0.055, pan: -0.1, send: 0.2);
      case Sfx.toggleOff:
        c.place(_oud(c, note(7), t60: 0.25, brightness: 0.4, amp: 0.7), 0, pan: -0.1, send: 0.1);
        c.place(_oud(c, note(4), t60: 0.3, brightness: 0.4), 0.05, pan: 0.1, send: 0.12);
      case Sfx.sheetOpen:
        // Desert wind, a riq's breath at the end.
        Gestures.whoosh(c, dur: 0.34, fromHz: 300, toHz: 1800, q: 0.6, lowMix: 0.5, peakAt: 0.6, pan: -0.2, panTo: 0.2);
        c.place(Instruments.zills(c.sampleRate, rng: c.rng, amp: 0.5, hits: 2, t60: 0.15), 0.24, gain: 0.25, send: 0.4);
      case Sfx.sheetClose:
        Gestures.whoosh(c, dur: 0.26, fromHz: 1600, toHz: 260, q: 0.6, lowMix: 0.5, peakAt: 0.3, pan: 0.2, panTo: -0.15);
      case Sfx.complete:
        // D → (E♭ grace) → F♯ → A over a soft dum.
        c.place(_dum(c, amp: 0.32), 0, send: 0.1);
        c.place(_oud(c, note(0), t60: 0.9), 0, pan: -0.2, send: 0.25);
        c.place(_oud(c, note(1), t60: 0.12, amp: 0.4, brightness: 0.45), 0.07, pan: -0.05, send: 0.15);
        c.place(_oud(c, note(2), t60: 0.9), 0.1, pan: 0, send: 0.3);
        c.place(_oud(c, note(4), t60: 1.1), 0.19, pan: 0.2, send: 0.35);
      case Sfx.levelUp:
        // Hijaz run, a double-stop landing and a risha tremolo with riq.
        const run = [0, 1, 2, 3, 4];
        for (var i = 0; i < run.length; i++) {
          c.place(_oud(c, note(run[i]), t60: 0.4, brightness: 0.6), i * 0.045, gain: 0.55 + 0.08 * i, pan: -0.4 + 0.2 * i, send: 0.2);
        }
        const land = 0.25;
        c.place(_dum(c, amp: 0.45), land, send: 0.15);
        c.place(Instruments.zills(c.sampleRate, rng: c.rng, amp: 0.8, hits: 3), land, gain: 0.35, pan: 0.2, send: 0.3);
        c.place(_oud(c, note(7), t60: 1.0), land, pan: -0.1, send: 0.35);
        c.place(_oud(c, note(4), t60: 1.0, amp: 0.7), land + 0.012, pan: 0.1, send: 0.35);
        for (var i = 1; i <= 3; i++) {
          c.place(_oud(c, note(7), t60: 0.6, amp: 0.55 - 0.1 * i), land + 0.07 * i, pan: -0.1, send: 0.35);
        }
      case Sfx.delete:
        c.place(_dum(c, t60: 0.3, amp: 0.3), 0, send: 0.1);
        c.place(_oud(c, note(0), t60: 0.22, brightness: 0.35, amp: 0.9), 0.01, send: 0.12);
      case Sfx.undo:
        c.place(_tek(c, amp: 0.6), 0, pan: 0.1, send: 0.08);
        c.place(_tek(c, freq: 215, amp: 0.9), 0.06, pan: -0.1, send: 0.1);
        c.place(_oud(c, note(4), t60: 0.2, amp: 0.35), 0.06, send: 0.15);
      case Sfx.swipe:
        Gestures.whoosh(c, dur: 0.13, fromHz: 1200, toHz: 3800, q: 1.0, peakAt: 0.35, pan: 0.25, panTo: -0.25, send: 0.1);
      case Sfx.pickUp:
        c.place(_tek(c, freq: 210, t60: 0.05), 0, send: 0.06);
        c.place(_oud(c, note(7), t60: 0.18, amp: 0.3, brightness: 0.7), 0.004, send: 0.12);
      case Sfx.drop:
        c.place(Instruments.frameDrum(c.sampleRate, rng: c.rng, freq: 104, t60: 0.25, tone: 0.3), 0, send: 0.08);
      case Sfx.error:
        // A Hijaz half-step sigh: E♭ settling onto D, low and dark.
        c.place(_oud(c, note(1), t60: 0.45, brightness: 0.35), 0, send: 0.15);
        c.place(_oud(c, note(0), t60: 0.6, brightness: 0.35), 0.15, send: 0.2);
      case Sfx.notify:
        c.place(_oud(c, note(4), t60: 0.7), 0, pan: 0.15, send: 0.25);
        c.place(_oud(c, note(7), t60: 0.8), 0.12, pan: -0.15, send: 0.3);
        c.place(Instruments.zills(c.sampleRate, rng: c.rng, amp: 0.5, hits: 2, t60: 0.16), 0.12, gain: 0.2, send: 0.3);
      case Sfx.navigate:
        c.place(_tek(c, freq: 220, t60: 0.045, amp: 0.8), 0, send: 0.04);
      case Sfx.back:
        c.place(_tek(c, freq: 170, t60: 0.045, amp: 0.7), 0, send: 0.04);
      case Sfx.prayerLit:
        // Night wind rising into a warm brass bell, oud harmonics above.
        Gestures.whoosh(c, dur: 0.3, fromHz: 220, toHz: 3000, q: 0.6, lowMix: 0.6, amp: 0.45, peakAt: 0.9, send: 0.4);
        c.place(Instruments.modal(c.sampleRate, freq: note(0), modes: Modes.bell(tierceCents: 390), t60: 1.7, attackMs: 4), 0.24,
            send: 0.45);
        c.place(_dum(c, t60: 0.6, amp: 0.45), 0.24, send: 0.2);
        c.place(_oud(c, note(7), t60: 1.0, amp: 0.45, brightness: 0.7), 0.27, pan: -0.2, send: 0.45);
        c.place(_oud(c, note(11), t60: 0.9, amp: 0.3, brightness: 0.7), 0.33, pan: 0.2, send: 0.5);
      case Sfx.sparkle:
        c.place(Instruments.zills(c.sampleRate, rng: c.rng, amp: 0.7, hits: 4, t60: 0.25, spreadMs: 30), 0, pan: -0.2, panTo: 0.2, send: 0.4);
        Gestures.scatter(c,
            freqs: [note(14), note(16), note(18)],
            count: 3,
            spanSec: 0.25,
            start: 0.05,
            gain: 0.3,
            voice: (hz) => _oud(c, hz, t60: 0.25, brightness: 0.8));
      case Sfx.countTick:
        c.place(_tek(c, freq: 240, t60: 0.03, amp: 0.8), 0, send: 0.02);
    }
  }
}
