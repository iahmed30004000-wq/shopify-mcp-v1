import 'dart:typed_data';

import '../sound_api.dart';
import '../synth/synth.dart';
import 'profile_base.dart';

/// Lapis – glass bells and crystal FM in maqam Rast on D5.
///
/// Rast's neutral third (≈350 cents, "E half-flat") is the signature: it is
/// the middle note of the completion chime and the tierce of the prayer bell,
/// so the default theme sounds unmistakably Arabic yet crystalline.
final class LapisProfile extends SoundProfile {
  const LapisProfile();

  @override
  String get id => 'lapis';
  @override
  Maqam get maqam => Maqam.rast;
  @override
  double get tonicHz => 587.33; // D5
  @override
  ReverbSpec get room => const ReverbSpec(roomSize: 0.55, damping: 0.25, preDelayMs: 12);

  Float64List _glass(SfxCanvas c, double hz, {double t60 = 0.7, double amp = 1, double brightness = 1, double maxSec = 0.9}) =>
      Instruments.modal(c.sampleRate, freq: hz, modes: Modes.glass, t60: t60, amp: amp, brightness: brightness, maxSec: maxSec);

  Float64List _crystal(SfxCanvas c, double hz, {double t60 = 0.3, double index = 1.1, double amp = 1, double glideCents = 0}) =>
      Instruments.fmBell(c.sampleRate, freq: hz, ratio: 3.5, index: index, indexT60: t60 * 0.35, t60: t60, amp: amp, glideCents: glideCents);

  @override
  void voice(Sfx sfx, SfxCanvas c) {
    switch (sfx) {
      case Sfx.tap:
        // A glass bead: short crystal FM with a whisper of room.
        c.place(Instruments.fmBell(c.sampleRate, freq: note(7), ratio: 2.76, index: 0.9, indexT60: 0.03, t60: 0.1), 0, send: 0.08);
      case Sfx.toggleOn:
        c.place(_glass(c, note(4), t60: 0.32, amp: 0.8), 0, pan: 0.1, send: 0.2);
        c.place(_glass(c, note(7), t60: 0.4), 0.06, pan: -0.1, send: 0.25);
      case Sfx.toggleOff:
        c.place(_glass(c, note(7), t60: 0.22, amp: 0.7, brightness: 0.8), 0, pan: -0.1, send: 0.15);
        c.place(_glass(c, note(4), t60: 0.28, brightness: 0.7), 0.055, pan: 0.1, send: 0.2);
      case Sfx.sheetOpen:
        Gestures.whoosh(c, dur: 0.3, fromHz: 350, toHz: 2600, amp: 0.9, peakAt: 0.55, pan: -0.2, panTo: 0.2);
        c.place(_crystal(c, note(4, octave: 1), t60: 0.3, index: 0.6), 0.17, gain: 0.22, send: 0.6);
      case Sfx.sheetClose:
        Gestures.whoosh(c, dur: 0.24, fromHz: 2400, toHz: 420, amp: 0.9, peakAt: 0.3, pan: 0.2, panTo: -0.15);
        c.place(_glass(c, note(0), t60: 0.25, amp: 0.25, brightness: 0.6), 0.12, send: 0.3);
      case Sfx.complete:
        // Rising Rast chime: tonic → neutral third → fifth.
        c.place(_glass(c, note(0), t60: 0.9), 0, pan: -0.22, send: 0.35);
        c.place(_glass(c, note(2), t60: 0.9), 0.085, pan: 0, send: 0.4);
        c.place(_glass(c, note(4), t60: 1.0), 0.17, pan: 0.22, send: 0.45);
        c.place(_crystal(c, note(4, octave: 1), t60: 0.5, index: 0.7), 0.17, gain: 0.22, pan: 0.3, send: 0.6);
      case Sfx.levelUp:
        // Crystal arpeggio up the scale, landing on a ringing glass chord.
        for (var i = 0; i < 7; i++) {
          c.place(_crystal(c, note(i, octave: 0), t60: 0.22, index: 0.8), i * 0.036,
              gain: 0.45 + 0.07 * i, pan: -0.5 + i / 6, send: 0.35);
        }
        const land = 0.27;
        c.place(_glass(c, note(7), t60: 1.1), land, pan: -0.15, send: 0.45);
        c.place(_glass(c, note(9), t60: 1.0, amp: 0.7), land + 0.012, pan: 0.15, send: 0.45);
        c.place(_glass(c, note(11), t60: 0.9, amp: 0.55), land + 0.024, pan: 0, send: 0.5);
        Gestures.scatter(c,
            freqs: [note(14), note(16), note(18)],
            count: 4,
            spanSec: 0.3,
            start: land + 0.05,
            gain: 0.18,
            voice: (hz) => _crystal(c, hz, t60: 0.18, index: 0.5));
      case Sfx.delete:
        // Glass dissolving: a falling crystal note and fine dust.
        c.place(_crystal(c, note(0), t60: 0.28, index: 1.4, glideCents: 500), 0, send: 0.3);
        Gestures.whoosh(c, at: 0.02, dur: 0.26, fromHz: 2200, toHz: 320, amp: 0.35, peakAt: 0.2, send: 0.2);
      case Sfx.undo:
        c.place(
            Instruments.fmBell(c.sampleRate, freq: note(4), ratio: 3.5, index: 0.8, indexT60: 0.08, t60: 0.2, attackMs: 22, glideCents: -300),
            0,
            send: 0.25);
        c.place(_glass(c, note(7), t60: 0.2, amp: 0.45), 0.07, pan: -0.1, send: 0.3);
      case Sfx.swipe:
        Gestures.whoosh(c, dur: 0.14, fromHz: 900, toHz: 4200, q: 1.1, peakAt: 0.35, pan: 0.25, panTo: -0.25, send: 0.12);
      case Sfx.pickUp:
        c.place(_crystal(c, note(4), t60: 0.15, index: 0.6, glideCents: -200), 0, send: 0.15);
        c.place(Instruments.click(c.sampleRate, rng: c.rng, centerHz: 4200, durMs: 3), 0, gain: 0.2);
      case Sfx.drop:
        // Glass set down on velvet.
        c.place(Instruments.fmBell(c.sampleRate, freq: note(0, octave: -1), ratio: 2.0, index: 0.5, indexT60: 0.04, t60: 0.14), 0, send: 0.12);
        c.place(Instruments.frameDrum(c.sampleRate, rng: c.rng, freq: 140, t60: 0.12, tone: 0.3, amp: 0.45), 0, send: 0.05);
        c.place(_glass(c, note(0), t60: 0.08, amp: 0.3, brightness: 0.6), 0.004, send: 0.1);
      case Sfx.error:
        // Gentle, low: a neutral third settling down onto the tonic.
        // FM index gives the low tones enough overtones to speak on a phone.
        c.place(Instruments.fmBell(c.sampleRate, freq: note(2, octave: -1), ratio: 1.0, index: 1.5, indexT60: 0.2, t60: 0.35, attackMs: 6), 0,
            send: 0.2);
        c.place(Instruments.fmBell(c.sampleRate, freq: note(0, octave: -1), ratio: 1.0, index: 1.4, indexT60: 0.22, t60: 0.45, attackMs: 6),
            0.14,
            send: 0.25);
      case Sfx.notify:
        c.place(_glass(c, note(4), t60: 0.7), 0, pan: 0.15, send: 0.35);
        c.place(_glass(c, note(7), t60: 0.8), 0.12, pan: -0.15, send: 0.4);
        c.place(_crystal(c, note(7, octave: 1), t60: 0.3, index: 0.5), 0.12, gain: 0.18, send: 0.5);
      case Sfx.navigate:
        c.place(Instruments.modal(c.sampleRate, freq: note(7), modes: Modes.crystal, t60: 0.05), 0, send: 0.1);
      case Sfx.back:
        c.place(Instruments.modal(c.sampleRate, freq: note(4), modes: Modes.crystal, t60: 0.05), 0, send: 0.1);
      case Sfx.prayerLit:
        // Light gathering (rising air + glint) into a Rast-tuned bell.
        Gestures.whoosh(c, dur: 0.26, fromHz: 300, toHz: 5200, amp: 0.45, peakAt: 0.92, q: 0.7, send: 0.5);
        c.place(Instruments.fmBell(c.sampleRate, freq: note(4, octave: 1), ratio: 3.5, index: 0.5, indexT60: 0.1, t60: 0.2, attackMs: 90), 0.1,
            gain: 0.2, send: 0.6);
        c.place(Instruments.modal(c.sampleRate, freq: note(0, octave: -1), modes: Modes.bell(tierceCents: 350), t60: 1.8, attackMs: 3), 0.24,
            send: 0.5);
        c.place(_glass(c, note(7), t60: 1.2, amp: 0.4), 0.245, pan: 0.2, send: 0.6);
        c.place(_crystal(c, note(4, octave: 1), t60: 0.6, index: 0.4), 0.26, gain: 0.15, pan: -0.25, send: 0.7);
      case Sfx.sparkle:
        Gestures.scatter(c,
            freqs: [note(7), note(9), note(11), note(14)],
            count: 5,
            spanSec: 0.3,
            voice: (hz) => _crystal(c, hz, t60: 0.2, index: 0.6));
      case Sfx.countTick:
        c.place(Instruments.modal(c.sampleRate, freq: note(4, octave: 1), modes: Modes.crystal, t60: 0.022, maxSec: 0.06), 0, send: 0.03);
    }
  }
}
