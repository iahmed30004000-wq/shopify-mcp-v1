import 'dart:typed_data';

import '../sound_api.dart';
import '../synth/synth.dart';
import 'profile_base.dart';

/// Emerald – warm wood and kalimba in maqam Bayati on G4.
///
/// Bayati's neutral second (≈150 cents) appears as a passing tone in the
/// level-up run and in the error sigh; everything else rests on open fifths
/// and octaves, so the warmth never turns melancholic.
final class EmeraldProfile extends SoundProfile {
  const EmeraldProfile();

  @override
  String get id => 'emerald';
  @override
  Maqam get maqam => Maqam.bayati;
  @override
  double get tonicHz => 392.0; // G4
  @override
  ReverbSpec get room => const ReverbSpec(roomSize: 0.42, damping: 0.6, preDelayMs: 9);

  Float64List _kalimba(SfxCanvas c, double hz, {double t60 = 0.6, double amp = 1}) {
    final v = Instruments.modal(c.sampleRate, freq: hz, modes: Modes.kalimba, t60: t60, amp: amp, attackMs: 0.8);
    // The tine's metallic "tang" at the strike.
    final k = Instruments.click(c.sampleRate, rng: c.rng, centerHz: hz * 7, durMs: 3, amp: amp * 0.25);
    for (var i = 0; i < k.length && i < v.length; i++) {
      v[i] += k[i];
    }
    return v;
  }

  Float64List _wood(SfxCanvas c, double hz, {double t60 = 0.3, double amp = 1, double brightness = 0.8}) =>
      Instruments.modal(c.sampleRate, freq: hz, modes: Modes.wood, t60: t60, amp: amp, brightness: brightness, attackMs: 1.2);

  Float64List _block(SfxCanvas c, double hz, {double t60 = 0.08, double amp = 1}) =>
      Instruments.modal(c.sampleRate, freq: hz, modes: Modes.woodBlock, t60: t60, amp: amp, attackMs: 0.4);

  @override
  void voice(Sfx sfx, SfxCanvas c) {
    switch (sfx) {
      case Sfx.tap:
        c.place(_wood(c, note(7), t60: 0.07), 0, send: 0.06);
        c.place(Instruments.click(c.sampleRate, rng: c.rng, centerHz: 2500, durMs: 3), 0, gain: 0.25);
      case Sfx.toggleOn:
        c.place(_kalimba(c, note(2), t60: 0.35, amp: 0.8), 0, pan: 0.1, send: 0.15);
        c.place(_kalimba(c, note(4), t60: 0.45), 0.06, pan: -0.1, send: 0.2);
      case Sfx.toggleOff:
        c.place(_kalimba(c, note(4), t60: 0.25, amp: 0.7), 0, pan: -0.1, send: 0.12);
        c.place(_kalimba(c, note(2), t60: 0.3), 0.055, pan: 0.1, send: 0.15);
      case Sfx.sheetOpen:
        Gestures.whoosh(c, dur: 0.32, fromHz: 260, toHz: 1600, q: 0.7, lowMix: 0.5, peakAt: 0.55, pan: -0.2, panTo: 0.2);
        c.place(_kalimba(c, note(4, octave: 1), t60: 0.35), 0.18, gain: 0.2, send: 0.4);
      case Sfx.sheetClose:
        Gestures.whoosh(c, dur: 0.26, fromHz: 1500, toHz: 280, q: 0.7, lowMix: 0.5, peakAt: 0.3, pan: 0.2, panTo: -0.15);
      case Sfx.complete:
        // Open, warm rise: tonic → fifth → octave, with a wooden bass.
        c.place(_kalimba(c, note(0), t60: 0.8), 0, pan: -0.2, send: 0.25);
        c.place(_kalimba(c, note(4), t60: 0.8), 0.09, pan: 0, send: 0.3);
        c.place(_kalimba(c, note(7), t60: 1.0), 0.18, pan: 0.2, send: 0.35);
        c.place(_wood(c, note(0, octave: -1), t60: 0.6, amp: 0.55, brightness: 0.6), 0.18, send: 0.2);
      case Sfx.levelUp:
        // Kalimba run through Bayati (neutral 2nd as a passing colour).
        const run = [0, 1, 2, 3, 4, 5, 7];
        for (var i = 0; i < run.length; i++) {
          c.place(_kalimba(c, note(run[i]), t60: 0.3), i * 0.038, gain: 0.5 + 0.06 * i, pan: -0.45 + 0.9 * i / 6, send: 0.25);
        }
        const land = 0.29;
        c.place(_kalimba(c, note(7), t60: 1.0), land, pan: -0.12, send: 0.35);
        c.place(_kalimba(c, note(11), t60: 0.9, amp: 0.6), land + 0.015, pan: 0.12, send: 0.35);
        c.place(_wood(c, note(0, octave: -1), t60: 0.7, amp: 0.6, brightness: 0.6), land, send: 0.25);
        Gestures.scatter(c,
            freqs: [note(14), note(16), note(18)],
            count: 3,
            spanSec: 0.25,
            start: land + 0.08,
            gain: 0.16,
            voice: (hz) => _kalimba(c, hz, t60: 0.2));
      case Sfx.delete:
        // Two hollow knocks falling away.
        c.place(_block(c, note(3), t60: 0.12), 0, pan: 0.1, send: 0.12);
        c.place(_block(c, note(0), t60: 0.16, amp: 0.9), 0.07, pan: -0.1, send: 0.15);
      case Sfx.undo:
        c.place(_block(c, note(4), t60: 0.07, amp: 0.7), 0, send: 0.1);
        c.place(_block(c, note(7), t60: 0.09), 0.055, send: 0.12);
      case Sfx.swipe:
        Gestures.whoosh(c, dur: 0.14, fromHz: 800, toHz: 2200, q: 0.7, peakAt: 0.35, pan: 0.25, panTo: -0.25, send: 0.1);
      case Sfx.pickUp:
        c.place(_kalimba(c, note(4), t60: 0.14), 0, send: 0.1);
        c.place(_block(c, note(4) * 2.2, t60: 0.03, amp: 0.3), 0, send: 0.05);
      case Sfx.drop:
        c.place(_block(c, note(0, octave: -1), t60: 0.12), 0, send: 0.08);
        c.place(_block(c, note(0), t60: 0.06, amp: 0.45), 0.003, send: 0.06);
        c.place(Instruments.frameDrum(c.sampleRate, rng: c.rng, freq: 110, t60: 0.15, tone: 0.1, amp: 0.4), 0, send: 0.05);
      case Sfx.error:
        // Low marimba sigh: the neutral second settling onto the tonic.
        c.place(_wood(c, note(1), t60: 0.35, brightness: 0.9), 0, send: 0.15);
        c.place(_wood(c, note(0), t60: 0.45, brightness: 0.9), 0.15, send: 0.2);
      case Sfx.notify:
        c.place(_kalimba(c, note(4), t60: 0.6), 0, pan: 0.15, send: 0.25);
        c.place(_kalimba(c, note(7), t60: 0.8), 0.12, pan: -0.15, send: 0.3);
        c.place(_wood(c, note(0), t60: 0.4, amp: 0.3, brightness: 0.6), 0.12, send: 0.2);
      case Sfx.navigate:
        c.place(_wood(c, note(7), t60: 0.04, amp: 0.8), 0, send: 0.05);
      case Sfx.back:
        c.place(_wood(c, note(4), t60: 0.04, amp: 0.8), 0, send: 0.05);
      case Sfx.prayerLit:
        // A warm bowl blooming under a canopy of kalimba light.
        Gestures.whoosh(c, dur: 0.3, fromHz: 200, toHz: 2400, q: 0.6, lowMix: 0.6, amp: 0.4, peakAt: 0.9, send: 0.4);
        c.place(Instruments.modal(c.sampleRate, freq: note(0, octave: -1), modes: Modes.bowl, t60: 2.2, attackMs: 70), 0.2, send: 0.4);
        c.place(Instruments.modal(c.sampleRate, freq: note(0), modes: Modes.bell(tierceCents: 300), t60: 1.4, amp: 0.5, attackMs: 4), 0.24,
            send: 0.45);
        c.place(_kalimba(c, note(7), t60: 1.0, amp: 0.5), 0.26, pan: -0.2, send: 0.5);
        c.place(_kalimba(c, note(11), t60: 0.9, amp: 0.35), 0.31, pan: 0.2, send: 0.55);
      case Sfx.sparkle:
        Gestures.scatter(c,
            freqs: [note(7), note(9), note(11), note(14)],
            count: 5,
            spanSec: 0.3,
            voice: (hz) => _kalimba(c, hz, t60: 0.18));
      case Sfx.countTick:
        c.place(_block(c, 1400, t60: 0.02), 0, send: 0.02);
    }
  }
}
