import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../../core/sound/synth/buffer.dart';
import '../../../../../core/sound/synth/canvas.dart';
import '../../../../../core/sound/synth/dynamics.dart';
import '../../../../../core/sound/synth/filters.dart';
import '../../../../../core/sound/synth/instruments.dart' show Instruments, Modes;
import '../../../../../core/sound/synth/oscillators.dart';
import '../../../../../core/sound/synth/reverb.dart';
import '../../../../../core/sound/synth/rng.dart';
import '../../core/audio.dart';
import '../../core/era.dart';
import '../../core/era_skin.dart';
import '../era_scores.dart';
import '../music/score.dart';
import '../synth/dsp.dart';
import '../synth/renderer.dart' show encodeWav16;
import '../synth/voices.dart';

/// Extra sound effects beyond the core [CinemaSound] palette (theatre and
/// sports sounds several games share). Play them with
/// `CinemaSfxBank.playExtra` (see sfx_bank.dart).
enum CinemaSfx { crowdCheer, crowdAww, applause, whistle, slideWhistle, cymbalCrash, gong, drumroll }

/// Every SFX key the kit renders: `sound:<name>` / `extra:<name>`.
String sfxKey(CinemaSound s) => 'sound:${s.name}';
String extraKey(CinemaSfx s) => 'extra:${s.name}';

/// Procedural, era-voiced sound-effect kit. Pure Dart (runs in an isolate).
///
/// Each era re-voices the palette: a 1930s jump is a slide whistle, a
/// 1950s one a xylophone flourish, a 1980s one a square-wave sweep; old
/// eras are band-limited like an optical soundtrack.
final class SfxSynth {
  SfxSynth(this.era, {this.seed = 1})
    : style = eraScore(era).style,
      sr = switch (era) {
        Era.silent || Era.rubberHose => 22050,
        _ => 32000,
      };

  final Era era;
  final MusicStyle style;
  final int sr;
  final int seed;

  bool get _old => era == Era.silent || era == Era.rubberHose;

  /// Renders the whole kit as mono PCM16 WAVs keyed by [sfxKey]/[extraKey].
  Map<String, Uint8List> renderKit() => {
    for (final s in CinemaSound.values) sfxKey(s): renderSound(s),
    for (final s in CinemaSfx.values) extraKey(s): renderExtra(s),
  };

  /// Target momentary loudness (dBFS, 30 ms windows, speaker-weighted).
  static double loudnessOf(CinemaSound s) => switch (s) {
    CinemaSound.explosion => -12,
    CinemaSound.hit || CinemaSound.hurt => -14,
    CinemaSound.powerUp || CinemaSound.coin || CinemaSound.splat || CinemaSound.zap => -16,
    CinemaSound.jump || CinemaSound.boing || CinemaSound.honk || CinemaSound.bell => -17,
    CinemaSound.slideUp || CinemaSound.slideDown || CinemaSound.pop || CinemaSound.land => -19,
    CinemaSound.whoosh || CinemaSound.diceRoll || CinemaSound.piecePlace => -20,
    CinemaSound.cardFlip || CinemaSound.cardDeal || CinemaSound.tap || CinemaSound.typewriter || CinemaSound.projector => -22,
    CinemaSound.tick => -25,
  };

  static double extraLoudness(CinemaSfx s) => switch (s) {
    CinemaSfx.cymbalCrash || CinemaSfx.gong => -15,
    CinemaSfx.whistle => -16,
    _ => -18,
  };

  Uint8List renderSound(CinemaSound s) {
    final c = _canvas(s.index + 1, _maxLen(s));
    _compose(s, c);
    return _finish(c, loudnessOf(s), dry: _dry(s));
  }

  /// Small, frequent interface-like effects stay nearly dry.
  static bool _dry(CinemaSound s) => switch (s) {
    CinemaSound.tap || CinemaSound.tick || CinemaSound.typewriter || CinemaSound.cardFlip || CinemaSound.cardDeal => true,
    CinemaSound.piecePlace || CinemaSound.diceRoll || CinemaSound.pop || CinemaSound.land => true,
    _ => false,
  };

  Uint8List renderExtra(CinemaSfx s) {
    final c = _canvas(100 + s.index, s == CinemaSfx.gong ? 4.5 : 3.0);
    _composeExtra(s, c);
    return _finish(c, extraLoudness(s));
  }

  double _maxLen(CinemaSound s) => switch (s) {
    CinemaSound.explosion || CinemaSound.bell => 2.2,
    CinemaSound.projector || CinemaSound.powerUp => 1.6,
    _ => 1.0,
  };

  SfxCanvas _canvas(int salt, double maxSec) => SfxCanvas(
    sampleRate: sr,
    maxSeconds: maxSec,
    seed: seed * 97 + salt * 13 + era.index * 1009,
    room: switch (era) {
      Era.silent || Era.rubberHose => const ReverbSpec(roomSize: 0.3, damping: 0.6, preDelayMs: 6, width: 0.5),
      Era.noir => const ReverbSpec(roomSize: 0.55, damping: 0.5, preDelayMs: 12, width: 0.8),
      Era.vhs => const ReverbSpec(roomSize: 0.7, damping: 0.3, preDelayMs: 18, width: 1),
      _ => const ReverbSpec(roomSize: 0.45, damping: 0.45, preDelayMs: 10, width: 0.8),
    },
  );

  Uint8List _finish(SfxCanvas c, double loudness, {bool dry = false}) {
    var out = c.finish(loudnessDb: loudness, wet: dry ? 0.12 : (_old ? 0.35 : 0.45));
    // Keep effects tight: trim the tail 48 dB below the peak.
    final pk = out.peak();
    if (pk > 0) {
      final end = out.audibleEnd(pk * dbToGain(-48));
      final keep = math.min(out.frames, end + (0.01 * sr).round());
      if (keep < out.frames) out = out.truncated(keep)..fadeOut(math.min(keep ~/ 4, (0.03 * sr).round()));
    }
    // Period colour: optical-track band-limit for the old eras.
    final lofi = eraScore(era).lofi;
    if (lofi > 0.25) {
      final lp = 16000 * math.pow(0.3, lofi).toDouble();
      for (final ch in [out.left, out.right]) {
        Biquad(BiquadType.highPass, frequency: 90 + 90 * lofi, sampleRate: sr, q: 0.6).processBuffer(ch);
        Biquad(BiquadType.lowPass, frequency: math.min(lp, sr * 0.45), sampleRate: sr, q: 0.6).processBuffer(ch);
      }
      final loud = Loudness.momentaryDb(out);
      if (loud.isFinite) out.scale(dbToGain(loudness - loud));
      const SoftLimiter(ceilingDb: -1).process(out);
    }
    final mono = Float64List(out.frames);
    for (var i = 0; i < mono.length; i++) {
      mono[i] = 0.5 * (out.left[i] + out.right[i]);
    }
    fadeEdges(mono, 8, math.min(mono.length ~/ 3, (0.012 * sr).round()));
    return encodeWav16([mono], sr, seed: seed);
  }

  VoiceBox get _box => VoiceBox(sr, style, seed);

  Float64List _note(Inst inst, double pitch, double hold, double vel, {int fx = 0, double glideFrom = 0}) =>
      _box.render(NoteEvent(0, hold, pitch, vel, inst, fx: fx, glideFrom: glideFrom), hold);

  // ---------------------------------------------------------------------------
  // The palette

  void _compose(CinemaSound s, SfxCanvas c) {
    final rng = c.rng;
    switch (s) {
      case CinemaSound.tap:
        switch (era) {
          case Era.vhs:
            c.place(_tone(1320, 1320, 0.05, wave: _Wave.square, decay: 0.03), 0, gain: 0.5, send: 0.05);
          case Era.technicolor:
            c.place(_note(Inst.vibes, 88, 0.05, 0.6, fx: Art.staccato), 0, send: 0.1);
          case Era.grindhouse:
            c.place(_note(Inst.clav, 76, 0.05, 0.7), 0, send: 0.05);
          default:
            c.place(_note(Inst.woodblock, 3, 0.05, 0.7), 0, send: 0.05);
        }
      case CinemaSound.jump:
        switch (era) {
          case Era.silent || Era.rubberHose:
            c.place(_slideWhistle(700, 1500, 0.24), 0, send: 0.12);
          case Era.noir:
            c.place(_note(Inst.mutedTrumpet, 67, 0.16, 0.7, fx: Art.glide, glideFrom: 60), 0, send: 0.2);
          case Era.technicolor:
            for (var i = 0; i < 4; i++) {
              c.place(_note(Inst.xylophone, 79.0 + const [0, 4, 7, 12][i], 0.05, 0.6), i * 0.035, send: 0.12);
            }
          case Era.grindhouse:
            c.place(_note(Inst.wahGuitar, 64, 0.18, 0.8), 0, send: 0.1);
            c.place(_tone(300, 900, 0.18, wave: _Wave.saw, decay: 0.2, filter: 1800), 0, gain: 0.35, send: 0.1);
          case Era.vhs:
            c.place(_tone(220, 880, 0.2, wave: _Wave.square, decay: 0.25, filter: 3000), 0, gain: 0.55, send: 0.2);
        }
      case CinemaSound.land:
        c.place(_thud(rng, 95, 0.16), 0, send: 0.05);
        c.place(Instruments.noiseSweep(sr, rng: rng, durSec: 0.12, fromHz: 1200, toHz: 400, amp: 0.25, peakAt: 0.1), 0.004, send: 0.05);
        if (_old) c.place(_note(Inst.templeBlock, -9, 0.05, 0.5), 0, gain: 0.5, send: 0.05);
      case CinemaSound.hit:
        c.place(_thud(rng, 70, 0.22), 0, send: 0.08);
        c.place(_note(era == Era.vhs ? Inst.gatedSnare : Inst.snare, 0, 0.1, 0.9), 0.003, gain: 0.8, send: 0.12);
        if (_old) c.place(_note(Inst.woodblock, -7, 0.06, 0.8), 0, gain: 0.7, send: 0.1);
        if (era == Era.vhs) c.place(_tone(900, 120, 0.12, wave: _Wave.square, decay: 0.1), 0, gain: 0.3, send: 0.1);
        if (era == Era.grindhouse) c.place(_note(Inst.choke, 0, 0.1, 0.7), 0.01, gain: 0.4, send: 0.1);
      case CinemaSound.hurt:
        switch (era) {
          case Era.silent || Era.rubberHose || Era.technicolor:
            c.place(_note(Inst.mutedTrumpet, 62, 0.28, 0.8, fx: Art.wah | Art.fall), 0.02, send: 0.15);
            c.place(_note(Inst.tuba, 38, 0.2, 0.7, fx: Art.fall), 0.02, gain: 0.7, send: 0.1);
          case Era.noir:
            for (final p in const [48, 49, 54, 55]) {
              c.place(_note(Inst.piano, p.toDouble(), 0.3, 0.8), 0.01, gain: 0.5, send: 0.2);
            }
          case Era.grindhouse:
            c.place(_note(Inst.trumpet, 70, 0.25, 0.8, fx: Art.fall), 0.01, send: 0.15);
            c.place(_note(Inst.tenorSax, 58, 0.25, 0.7, fx: Art.fall), 0.01, gain: 0.7, send: 0.15);
          case Era.vhs:
            c.place(_tone(600, 90, 0.35, wave: _Wave.square, decay: 0.4, filter: 2500), 0, gain: 0.6, send: 0.2);
        }
        c.place(_thud(rng, 80, 0.2), 0, gain: 0.8, send: 0.05);
      case CinemaSound.coin:
        switch (era) {
          case Era.vhs:
            c.place(_fm(1568, 0.25, ratio: 3.5, index: 2.5), 0, gain: 0.6, send: 0.25);
            c.place(_fm(2637, 0.35, ratio: 3.5, index: 2.0), 0.06, gain: 0.55, send: 0.25);
          case Era.technicolor || Era.grindhouse:
            for (final (i, p) in const [84.0, 88.0, 91.0].indexed) {
              c.place(_note(Inst.celesta, p, 0.08, 0.7), i * 0.045, gain: 0.7, send: 0.2);
            }
          default:
            // Cash-register "ka-ching": a clack and a bright bell.
            c.place(_note(Inst.woodblock, 7, 0.04, 0.6), 0, gain: 0.5, send: 0.05);
            c.place(Instruments.fmBell(sr, freq: 2093, ratio: 2.76, index: 2.2, t60: 0.6, amp: 0.7), 0.05, send: 0.15);
            c.place(Instruments.fmBell(sr, freq: 2637, ratio: 2.76, index: 1.8, t60: 0.5, amp: 0.4), 0.06, send: 0.15);
        }
      case CinemaSound.powerUp:
        final inst = switch (era) {
          Era.vhs => Inst.synthArp,
          Era.noir => Inst.vibes,
          Era.grindhouse => Inst.clav,
          _ => Inst.xylophone,
        };
        const steps = [0, 4, 7, 12, 16, 19, 24, 28];
        for (var i = 0; i < steps.length; i++) {
          c.place(_note(inst, 67.0 + steps[i], 0.07, 0.5 + i * 0.05), i * 0.055, gain: 0.8, send: 0.2);
        }
        c.place(Instruments.noiseSweep(sr, rng: rng, durSec: 0.6, fromHz: 800, toHz: 6000, amp: 0.25, peakAt: 0.8), 0, send: 0.2);
        if (era != Era.vhs) c.place(_note(Inst.crash, 0, 0.3, 0.4), 0.44, gain: 0.35, send: 0.1);
      case CinemaSound.whoosh:
        c.place(
          Instruments.noiseSweep(sr, rng: rng, durSec: 0.32, fromHz: _old ? 400 : 300, toHz: _old ? 2500 : 4000, amp: 0.9, peakAt: 0.45, q: 1.2),
          0,
          send: 0.1,
        );
      case CinemaSound.boing:
        if (era == Era.vhs) {
          c.place(_tone(180, 180, 0.45, wave: _Wave.square, decay: 0.5, wobble: 0.35, filter: 2200), 0, gain: 0.6, send: 0.15);
        } else {
          c.place(_jawHarp(160, 0.5), 0, send: 0.12);
        }
      case CinemaSound.pop:
        c.place(_tone(900, 300, 0.07, wave: _Wave.sine, decay: 0.05), 0, gain: 0.8, send: 0.1);
        c.place(Instruments.click(sr, rng: rng, centerHz: 1800, durMs: 6, amp: 0.9), 0, send: 0.05);
      case CinemaSound.explosion:
        c.place(_boom(rng, 1.6), 0, send: 0.3);
      case CinemaSound.bell:
        switch (era) {
          case Era.vhs:
            c.place(_fm(1046, 1.4, ratio: 3.5, index: 3), 0, send: 0.3);
          case Era.technicolor:
            c.place(_note(Inst.celesta, 84, 0.5, 0.8), 0, send: 0.2);
            c.place(_note(Inst.celesta, 91, 0.5, 0.6), 0.002, gain: 0.5, send: 0.2);
          default:
            // Hotel desk bell.
            c.place(Instruments.modal(sr, freq: 1760, modes: Modes.bell(), t60: 1.4, maxSec: 1.8, amp: 0.8), 0, send: 0.2);
        }
      case CinemaSound.honk:
        c.place(_horn(era), 0, send: 0.1);
      case CinemaSound.slideUp:
        c.place(_slideWhistle(600, 1700, 0.45), 0, send: 0.15);
      case CinemaSound.slideDown:
        c.place(_slideWhistle(1700, 520, 0.45), 0, send: 0.15);
      case CinemaSound.splat:
        c.place(Instruments.noiseSweep(sr, rng: rng, durSec: 0.25, fromHz: 2500, toHz: 250, amp: 0.9, peakAt: 0.08, q: 0.8), 0, send: 0.08);
        c.place(_tone(260, 70, 0.2, wave: _Wave.sine, decay: 0.2), 0.01, gain: 0.7, send: 0.05);
      case CinemaSound.zap:
        switch (era) {
          case Era.vhs || Era.grindhouse:
            c.place(_tone(2400, 300, 0.25, wave: _Wave.square, decay: 0.25, wobble: 0.2, filter: 5000), 0, gain: 0.55, send: 0.25);
          case Era.technicolor || Era.noir:
            // 1950s ray gun: a theremin-ish swoop with fast vibrato.
            c.place(_tone(1800, 500, 0.3, wave: _Wave.sine, decay: 0.3, wobble: 0.5), 0, gain: 0.7, send: 0.3);
          default:
            c.place(_tone(1400, 400, 0.22, wave: _Wave.saw, decay: 0.2, filter: 3000), 0, gain: 0.5, send: 0.2);
            c.place(Instruments.noiseSweep(sr, rng: rng, durSec: 0.2, fromHz: 3000, toHz: 1000, amp: 0.3), 0, send: 0.1);
        }
      case CinemaSound.tick:
        c.place(_note(Inst.woodblock, 10, 0.03, 0.6), 0, send: 0.02);
      case CinemaSound.cardFlip:
        c.place(Instruments.noiseSweep(sr, rng: rng, durSec: 0.06, fromHz: 5000, toHz: 2000, amp: 0.8, peakAt: 0.2), 0, send: 0.03);
        c.place(Instruments.click(sr, rng: rng, centerHz: 1500, durMs: 8, amp: 0.6), 0.05, send: 0.03);
      case CinemaSound.cardDeal:
        c.place(Instruments.noiseSweep(sr, rng: rng, durSec: 0.12, fromHz: 1500, toHz: 5000, amp: 0.7, peakAt: 0.6), 0, send: 0.03);
        c.place(Instruments.click(sr, rng: rng, centerHz: 900, durMs: 12, amp: 0.8), 0.11, send: 0.05);
      case CinemaSound.diceRoll:
        var t = 0.0;
        for (var i = 0; i < 7; i++) {
          c.place(Instruments.modal(sr, freq: 1400 + rng.range(-300, 500), modes: Modes.woodBlock, t60: 0.05, maxSec: 0.08, amp: 0.7 - i * 0.07), t, send: 0.05);
          t += 0.04 + rng.nextDouble() * 0.07;
        }
      case CinemaSound.piecePlace:
        c.place(Instruments.modal(sr, freq: 720, modes: Modes.wood, t60: 0.08, maxSec: 0.12), 0, send: 0.06);
        c.place(_thud(rng, 140, 0.06), 0, gain: 0.5, send: 0.02);
      case CinemaSound.typewriter:
        c.place(Instruments.click(sr, rng: rng, centerHz: 2600, durMs: 7, amp: 1.0), 0, send: 0.03);
        c.place(Instruments.modal(sr, freq: 1900, modes: Modes.woodBlock, t60: 0.04, maxSec: 0.06, amp: 0.5), 0.002, send: 0.03);
        c.place(_thud(rng, 180, 0.04), 0.004, gain: 0.4, send: 0.02);
      case CinemaSound.projector:
        c.place(_projector(rng, 1.4), 0, send: 0.05);
    }
  }

  void _composeExtra(CinemaSfx s, SfxCanvas c) {
    final rng = c.rng;
    switch (s) {
      case CinemaSfx.crowdCheer:
        c.place(_crowd(rng, 2.4, rising: true), 0, send: 0.35);
      case CinemaSfx.crowdAww:
        c.place(_crowd(rng, 1.8, rising: false), 0, send: 0.35);
      case CinemaSfx.applause:
        c.place(_applause(rng, 2.6), 0, send: 0.3);
      case CinemaSfx.whistle:
        c.place(_peaWhistle(rng, 0.55), 0, send: 0.15);
      case CinemaSfx.slideWhistle:
        final up = _slideWhistle(600, 1600, 0.35);
        final down = _slideWhistle(1600, 700, 0.4);
        c.place(up, 0, send: 0.15);
        c.place(down, 0.34, send: 0.15);
      case CinemaSfx.cymbalCrash:
        c.place(_note(Inst.crash, 0, 1.5, 1.0), 0, send: 0.2);
        c.place(_note(Inst.kick, 0, 0.2, 0.6), 0, gain: 0.4, send: 0.05);
      case CinemaSfx.gong:
        c.place(_note(Inst.gong, 0, 3.5, 1.0), 0, send: 0.25);
      case CinemaSfx.drumroll:
        for (var i = 0; i < 28; i++) {
          c.place(_note(Inst.snare, 0, 0.05, 0.25 + 0.6 * i / 28, fx: i.isOdd ? Art.ghost : 0), i * 0.05, gain: 0.8, send: 0.1);
        }
        c.place(_note(Inst.crash, 0, 1.0, 0.9), 1.42, send: 0.2);
        c.place(_note(Inst.kick, 0, 0.2, 0.8), 1.42, send: 0.05);
    }
  }

  // ---------------------------------------------------------------------------
  // Building blocks

  Float64List _tone(
    double fromHz,
    double toHz,
    double dur, {
    required _Wave wave,
    double decay = 0.2,
    double wobble = 0,
    double filter = 0,
  }) {
    final n = framesFor(sr, dur + 0.03);
    final out = Float64List(n);
    final o = Osc();
    final lp = filter > 0 ? Filter(sr, cutoff: filter, q: 0.8) : null;
    final k = t60Factor(math.max(0.02, decay * 2.5), sr);
    var amp = 1.0;
    for (var i = 0; i < n; i++) {
      final t = i / n;
      var f = fromHz * math.pow(toHz / fromHz, t);
      if (wobble > 0) f *= 1 + wobble * 0.25 * math.sin(twoPi * 14 * i / sr) * (1 - t);
      final inc = f / sr;
      var s = switch (wave) {
        _Wave.sine => o.sine(inc),
        _Wave.square => o.pulse(inc, 0.5),
        _Wave.saw => o.saw(inc),
      };
      if (lp != null) s = lp.lp(s);
      out[i] = s * amp;
      amp *= k;
    }
    fadeEdges(out, 16, framesFor(sr, 0.015));
    return out;
  }

  Float64List _fm(double f, double dur, {double ratio = 3.5, double index = 2}) =>
      Instruments.fmBell(sr, freq: f, ratio: ratio, index: index, t60: dur, amp: 0.8, maxSec: dur * 1.3);

  /// Slide whistle: a pure, breathy tone gliding with a smooth S-curve.
  Float64List _slideWhistle(double fromHz, double toHz, double dur) {
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    final o = Osc();
    final breath = Filter(sr, cutoff: 2000, q: 1.5);
    final rng = SynthRandom(seed + fromHz.round());
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final u = t * t * (3 - 2 * t);
      final f = fromHz * math.pow(toHz / fromHz, u) * (1 + 0.012 * math.sin(twoPi * 6 * i / sr));
      breath.set(f * 1.4, 1.5);
      final env = math.min(1.0, t * 12) * math.min(1.0, (1 - t) * 8);
      out[i] = (o.sine(f / sr) + breath.bp(rng.bipolar()) * 0.25) * env;
    }
    return out;
  }

  /// Jaw-harp / door-stop spring "boing": a twangy tone whose pitch wobbles
  /// and settles.
  Float64List _jawHarp(double f0, double dur) {
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    final o = Osc();
    final bp = Filter(sr, cutoff: 900, q: 3);
    final k = t60Factor(dur * 0.9, sr);
    var amp = 1.0;
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final wob = 1 + 0.3 * math.exp(-t / 0.18) * math.sin(twoPi * 9 * t);
      bp.set(700 + 900 * (0.5 + 0.5 * math.sin(twoPi * 5 * t)), 3);
      final s = o.saw(f0 * wob / sr);
      out[i] = (bp.bp(s) * 1.4 + s * 0.15) * amp;
      amp *= k;
    }
    fadeEdges(out, 12, framesFor(sr, 0.02));
    return out;
  }

  Float64List _thud(SynthRandom rng, double f0, double dur) {
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    final k = t60Factor(dur * 0.8, sr);
    final lp = OnePole(sr, 500);
    var amp = 1.0, ph = 0.0;
    for (var i = 0; i < n; i++) {
      final f = f0 * (1 + 0.8 * math.exp(-i / sr / 0.02));
      ph += f / sr;
      if (ph >= 1) ph -= 1;
      out[i] = (SineTable.wrapped(ph) + lp.lp(rng.bipolar()) * 0.6 * math.exp(-i / sr / 0.01)) * amp;
      amp *= k;
    }
    fadeEdges(out, 6, framesFor(sr, 0.01));
    return out;
  }

  Float64List _boom(SynthRandom rng, double dur) {
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    final lp = Filter(sr, cutoff: 3000, q: 0.7);
    final k = t60Factor(dur * 0.7, sr);
    var amp = 1.0, ph = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      if (i & 31 == 0) lp.set(200 + 5000 * math.exp(-t / 0.12), 0.7);
      final f = 38 + 90 * math.exp(-t / 0.08);
      ph += f / sr;
      if (ph >= 1) ph -= 1;
      var s = lp.lp(rng.bipolar()) * 1.1 + SineTable.wrapped(ph) * 1.2;
      // Debris crackle.
      if (t > 0.1 && rng.nextDouble() < 0.002) s += rng.bipolar() * 2;
      out[i] = soft(s * amp * 1.4);
      amp *= k;
    }
    fadeEdges(out, 8, framesFor(sr, 0.2));
    return out;
  }

  Float64List _horn(Era e) {
    final (f, dur, two) = switch (e) {
      Era.silent || Era.rubberHose || Era.technicolor => (330.0, 0.32, false), // bulb horn
      Era.noir || Era.grindhouse => (392.0, 0.4, true), // car horn
      Era.vhs => (440.0, 0.35, true),
    };
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    final a = Osc(), b = Osc();
    final bp = Filter(sr, cutoff: 1400, q: 2.2);
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final drop = e == Era.rubberHose || e == Era.silent ? 1 - 0.12 * t : 1.0;
      var s = a.saw(f * drop / sr);
      if (two) s += b.saw(f * 1.26 / sr);
      final env = math.min(1.0, t * 30) * math.min(1.0, (1 - t) * 10);
      out[i] = (bp.bp(s) * 1.3 + s * 0.2) * env;
    }
    return out;
  }

  Float64List _projector(SynthRandom rng, double dur) {
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    final hum = Osc();
    final fan = OnePole(sr, 900);
    final period = sr / 24.0;
    final click = Filter(sr, cutoff: 2600, q: 2.5);
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final env = math.min(1.0, t * 6) * math.min(1.0, (1 - t) * 6);
      final ph = (i % period) / period;
      final impulse = ph < 0.02 ? (1 - ph / 0.02) * (rng.nextDouble() * 0.4 + 0.8) : 0.0;
      final s = click.bp(impulse * 3 + rng.bipolar() * 0.02) * 1.2 + hum.sine(96 / sr) * 0.12 + fan.lp(rng.bipolar()) * 0.18;
      out[i] = s * env;
    }
    return out;
  }

  /// Crowd: dozens of formant-filtered voices with rising ("yay") or
  /// falling ("aww") contours over a roar.
  Float64List _crowd(SynthRandom rng, double dur, {required bool rising}) {
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    const voices = 28;
    for (var v = 0; v < voices; v++) {
      final start = framesFor(sr, rng.nextDouble() * 0.35);
      final len = math.min(n - start, framesFor(sr, dur * (0.55 + 0.4 * rng.nextDouble())));
      if (len <= 0) continue;
      final f0 = rng.range(140, 330);
      final vowel = rng.nextInt(3);
      final f1 = Filter(sr, cutoff: const [800.0, 420.0, 500.0][vowel], q: 4);
      final f2 = Filter(sr, cutoff: const [1250.0, 2000.0, 850.0][vowel], q: 5);
      final o = Osc(rng.nextDouble());
      final vib = rng.range(4, 7);
      for (var i = 0; i < len; i++) {
        final t = i / len;
        final contour = rising ? 1 + 0.35 * math.sin(math.pi * math.min(1.0, t * 1.4)) : 1.25 - 0.4 * t;
        final f = f0 * contour * (1 + 0.02 * math.sin(twoPi * vib * i / sr));
        final s = o.pulse(f / sr, 0.3);
        final env = math.min(1.0, t * 10) * math.pow(1 - t, 1.3);
        out[start + i] += (f1.bp(s) + f2.bp(s) * 0.6) * env * 0.35;
      }
    }
    final roar = Filter(sr, cutoff: 900, q: 0.6);
    for (var i = 0; i < n; i++) {
      final t = i / n;
      final env = math.min(1.0, t * 5) * math.pow(1 - t, 1.5);
      out[i] += roar.bp(rng.bipolar()) * 0.5 * env;
    }
    fadeEdges(out, 64, framesFor(sr, 0.3));
    return out;
  }

  Float64List _applause(SynthRandom rng, double dur) {
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    final clapN = framesFor(sr, 0.012);
    final bp = Filter(sr, cutoff: 1500, q: 1.3);
    var t = 0.0;
    while (t < dur) {
      final u = t / dur;
      final rate = 90 * math.sin(math.pi * math.min(1.0, u * 1.2)) + 8;
      t += -math.log(1 - rng.nextDouble() * 0.999) / rate;
      final at = framesFor(sr, t);
      if (at >= n) break;
      bp.set(rng.range(900, 2600), 1.3);
      final g = rng.range(0.3, 1.0) * math.pow(1 - u, 0.8);
      for (var i = 0; i < clapN && at + i < n; i++) {
        out[at + i] += bp.bp(rng.bipolar()) * g * math.exp(-i / (clapN * 0.25));
      }
    }
    fadeEdges(out, 64, framesFor(sr, 0.25));
    return out;
  }

  Float64List _peaWhistle(SynthRandom rng, double dur) {
    final n = framesFor(sr, dur);
    final out = Float64List(n);
    final o = Osc();
    final breath = Filter(sr, cutoff: 3000, q: 2);
    for (var i = 0; i < n; i++) {
      final t = i / n;
      // The pea rattles: a fast, slightly irregular frequency trill.
      final trill = math.sin(twoPi * 38 * i / sr) + 0.3 * math.sin(twoPi * 53 * i / sr);
      final f = 2900 * (1 + 0.035 * trill);
      final env = math.min(1.0, t * 25) * math.min(1.0, (1 - t) * 12);
      out[i] = (o.sine(f / sr) * (0.75 + 0.25 * trill.abs()) + breath.bp(rng.bipolar()) * 0.2) * env;
    }
    return out;
  }
}

enum _Wave { sine, square, saw }

/// Renders a stereo [StereoBuffer] down to one channel (tests, analysis).
Float64List downmix(StereoBuffer b) {
  final out = Float64List(b.frames);
  for (var i = 0; i < out.length; i++) {
    out[i] = 0.5 * (b.left[i] + b.right[i]);
  }
  return out;
}
