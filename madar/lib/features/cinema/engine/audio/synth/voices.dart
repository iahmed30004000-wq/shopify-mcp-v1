import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../../core/sound/synth/oscillators.dart';
import '../../../../../core/sound/synth/rng.dart';
import '../../core/era_skin.dart';
import '../music/score.dart';
import '../music/theory.dart';
import 'dsp.dart';

/// Pitch trajectory of a sustained voice: scoop, glide, vibrato and fall,
/// evaluated in blocks (cheap) and returned as a phase increment.
final class PitchPath {
  PitchPath(
    this.sr,
    this.freq,
    NoteEvent e,
    this.holdSec, {
    double vibCents = 0,
    this.vibRate = 5.2,
    this.vibDelay = 0.22,
    double scoopCents = -110,
    this.glideTau = 0.05,
    this.fallSemis = -6,
    this.fallSec = 0.22,
  }) : _scoop = e.has(Art.scoop) ? scoopCents / 100 : 0,
       _glide = e.has(Art.glide) ? e.glideFrom - e.pitch : 0,
       _vib = e.has(Art.vibrato) ? math.max(vibCents, 14.0) / 100 : vibCents / 100,
       _fall = e.has(Art.fall);

  final int sr;
  final double freq;
  final double holdSec;
  final double vibRate;
  final double vibDelay;
  final double glideTau;
  final double fallSemis;
  final double fallSec;
  final double _scoop;
  final double _glide;
  final double _vib;
  final bool _fall;

  bool get isStatic => _scoop == 0 && _glide == 0 && _vib == 0 && !_fall;

  /// Phase increment (cycles / sample) at time [t] seconds.
  double incAt(double t) {
    var s = 0.0;
    if (_scoop != 0) s += _scoop * math.exp(-t / 0.045);
    if (_glide != 0) s += _glide * math.exp(-t / glideTau);
    if (_vib != 0 && t > vibDelay) {
      final ramp = math.min(1.0, (t - vibDelay) / 0.35);
      s += _vib * ramp * SineTable.at(vibRate * t);
    }
    if (_fall) {
      final ft = t - (holdSec - 0.03);
      if (ft > 0) {
        final u = math.min(1.0, ft / fallSec);
        s += fallSemis * u * u;
      }
    }
    return s == 0 ? freq / sr : freq * math.pow(2.0, s / 12.0) / sr;
  }
}

/// Renders single notes of every [Inst] as mono buffers (release included).
///
/// Timbres follow the cue's [style] (a 1930s bass drum is a felt boom, a
/// 1980s one a pitched thump with a click).
final class VoiceBox {
  VoiceBox(this.sr, this.style, int seed) : rng = SynthRandom(seed);

  final int sr;
  final MusicStyle style;
  final SynthRandom rng;

  bool get _vintage => style == MusicStyle.ragtime || style == MusicStyle.swing;

  Float64List render(NoteEvent e, double holdSec) {
    final vel = e.has(Art.ghost) ? e.vel * 0.35 : e.vel;
    final hold = math.max(0.02, holdSec);
    final f = midiToHz(e.pitch);
    return switch (e.inst) {
      Inst.piano => _piano(e, f, hold, vel, honky: false),
      Inst.honkyPiano => _piano(e, f, hold, vel, honky: true),
      Inst.theatreOrgan => _organ(e, f, hold, vel),
      Inst.rhodes => _rhodes(e, f, hold, vel),
      Inst.vibes => _vibes(e, f, hold, vel),
      Inst.xylophone => _mallet(f, hold, vel, const [1.0, 3.93, 9.24], const [1.0, 0.32, 0.1], const [1.0, 0.3, 0.1], 0.5),
      Inst.marimba => _mallet(f, hold, vel, const [1.0, 3.99, 10.0], const [1.0, 0.18, 0.04], const [1.0, 0.35, 0.12], 1.1),
      Inst.celesta => _mallet(f, hold, vel, const [1.0, 2.0, 3.0, 5.4], const [1.0, 0.16, 0.07, 0.03], const [1.0, 0.6, 0.4, 0.2], 1.5),
      Inst.uprightBass => _upright(e, f, hold, vel),
      Inst.tuba => _tuba(e, f, hold, vel),
      Inst.electricBass => _eBass(e, f, hold, vel),
      Inst.synthBass => _synthBass(e, f, hold, vel),
      Inst.banjo => _banjo(f, hold, vel),
      Inst.wahGuitar => _wahGuitar(e, f, hold, vel),
      Inst.clav => _clav(f, hold, vel),
      Inst.violin => _violin(e, f, hold, vel),
      Inst.strings => _strings(e, f, hold, vel),
      Inst.clarinet => _clarinet(e, f, hold, vel),
      Inst.mutedTrumpet => _mutedTrumpet(e, f, hold, vel),
      Inst.trumpet => _brass(e, f, hold, vel, bright: 7.5, attack: 0.018),
      Inst.trombone => _brass(e, f, hold, vel, bright: 4.8, attack: 0.03),
      Inst.altoSax => _sax(e, f, hold, vel, tenor: false),
      Inst.tenorSax => _sax(e, f, hold, vel, tenor: true),
      Inst.flute => _flute(e, f, hold, vel),
      Inst.synthLead => _synthLead(e, f, hold, vel),
      Inst.synthArp => _synthArp(f, hold, vel),
      Inst.synthPad => _synthPad(e, f, hold, vel),
      Inst.synthBrass => _synthBrass(e, f, hold, vel),
      Inst.kick => _kick(e, vel),
      Inst.snare => _snare(e, vel, gated: false),
      Inst.gatedSnare => _snare(e, vel, gated: true),
      Inst.brushTap => _brushTap(vel),
      Inst.brushSweep => _brushSweep(hold, vel),
      Inst.hatClosed => _metal(vel, t60: 0.055, hp: 7000, level: 0.55, tune: e.pitch),
      Inst.hatOpen => _metal(vel, t60: 0.42, hp: 6500, level: 0.5, tune: e.pitch),
      Inst.hatPedal => _metal(vel * 0.7, t60: 0.07, hp: 5500, level: 0.4, tune: e.pitch),
      Inst.ride => _ride(e, vel),
      Inst.crash => _crash(vel, t60: _vintage ? 1.3 : 2.2),
      Inst.choke => _crash(vel, t60: 0.14),
      Inst.rimClick => _rim(vel),
      Inst.woodblock => _block(vel, 880 * semitoneRatio(e.pitch), 0.11),
      Inst.templeBlock => _block(vel, 470 * semitoneRatio(e.pitch), 0.2),
      Inst.tomLow => _tom(vel, 92 * semitoneRatio(e.pitch)),
      Inst.tomHigh => _tom(vel, 150 * semitoneRatio(e.pitch)),
      Inst.conga => _hand(e, vel, 215 * semitoneRatio(e.pitch), 0.34),
      Inst.bongo => _hand(e, vel, 430 * semitoneRatio(e.pitch), 0.16),
      Inst.clave => _clave(vel),
      Inst.cowbell => _cowbell(vel),
      Inst.shaker => _shaker(vel, hold),
      Inst.timpani => _timpani(e, f, vel),
      Inst.clap => _clap(vel),
      Inst.tambourine => _tambourine(vel),
      Inst.gong => _gong(vel),
    };
  }

  // ---------------------------------------------------------------------------
  // Keys and mallets

  Float64List _piano(NoteEvent e, double f, double hold, double vel, {required bool honky}) {
    final midi = e.pitch;
    final t60 = (8.5 * math.pow(261.6 / f, 0.6)).clamp(0.9, 15.0).toDouble();
    final damper = f > 1500 ? t60 : (0.1 + 0.06 * (261.6 / f)).clamp(0.08, 0.4).toDouble();
    final relSec = e.has(Art.staccato) ? damper * 0.6 : damper;
    final total = math.min(hold + relSec * 1.2, t60 * 1.2);
    final n = framesFor(sr, total);
    final out = Float64List(n);
    final holdN = framesFor(sr, hold);
    final maxP = (midi < 48
        ? 14
        : midi < 72
        ? 10
        : 6);
    final b = 0.00018 * math.pow(2.0, (midi - 60) / 16.0);
    final bright = 0.35 + 0.9 * vel;
    final tilt = 2.1 - 1.1 * bright;
    final freqs = <double>[], gains = <double>[], t60s = <double>[], damps = <double>[];
    final detune = honky ? 1.0072 : 1.0006;
    for (var p = 1; p <= maxP; p++) {
      final fp = f * p * math.sqrt(1 + b * p * p);
      if (fp > sr * 0.45) break;
      final g = (math.sin(math.pi * p * 0.119).abs() + 0.05) / math.pow(p, tilt) * vel;
      final tp = t60 / (1 + 0.55 * (p - 1) + 0.03 * (p - 1) * (p - 1));
      final dp = math.min(tp, relSec / (1 + 0.25 * (p - 1)));
      // Two strings per note: slow beating (honky-tonk: a lot of it).
      final strings = (honky || p <= 3) ? 2 : 1;
      for (var s = 0; s < strings; s++) {
        final df = strings == 1 ? 1.0 : (s == 0 ? detune : 1 / detune);
        freqs.add(fp * df);
        gains.add(g / strings);
        t60s.add(tp);
        damps.add(dp);
      }
    }
    addModes(out, sr, freqs: freqs, gains: gains, t60s: t60s, dampT60s: damps, holdN: holdN);
    // Hammer thump.
    final hn = framesFor(sr, 0.006);
    final lp = OnePole(sr, 1800);
    for (var i = 0; i < hn && i < n; i++) {
      final env = 1 - i / hn;
      out[i] += lp.lp(rng.bipolar()) * env * 0.12 * vel;
    }
    fadeEdges(out, framesFor(sr, 0.0012), framesFor(sr, 0.004));
    _normalize(out, 0.55 * (0.25 + 0.75 * vel));
    return out;
  }

  Float64List _organ(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: 0.03, decay: 0.2, sustain: 0.92, release: 0.12, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    const ratios = [0.5, 1.0, 2.0, 3.0, 4.0, 6.0, 8.0];
    const weights = [0.35, 1.0, 0.55, 0.22, 0.28, 0.08, 0.1];
    final phases = List<double>.filled(ratios.length, 0);
    final incs = [for (final r in ratios) f * r / sr];
    final tremRate = 6.3 / sr;
    var tp = 0.0;
    for (var i = 0; i < n; i++) {
      final trem = SineTable.wrapped(tp);
      tp += tremRate;
      if (tp >= 1) tp -= 1;
      final fm = 1 + 0.0045 * trem;
      var s = 0.0;
      for (var k = 0; k < ratios.length; k++) {
        final inc = incs[k] * fm;
        if (inc >= 0.45) continue;
        s += weights[k] * SineTable.wrapped(phases[k]);
        var p = phases[k] + inc;
        if (p >= 1) p -= 1;
        phases[k] = p;
      }
      out[i] = s * env.next() * (1 - 0.22 * (0.5 + 0.5 * trem));
    }
    _normalize(out, 0.4 * (0.4 + 0.6 * vel));
    return out;
  }

  Float64List _rhodes(NoteEvent e, double f, double hold, double vel) {
    final t60 = (3.2 * math.pow(261.6 / f, 0.35)).clamp(1.0, 6.0).toDouble();
    final holdN = framesFor(sr, hold);
    final relN = framesFor(sr, 0.28);
    final n = math.min(holdN + relN, framesFor(sr, t60 * 1.2));
    final out = Float64List(n);
    final kA = t60Factor(t60, sr), kR = t60Factor(0.22, sr);
    final kI = t60Factor(0.45, sr);
    var amp = 1.0, idx = 0.35 + 1.6 * vel;
    final dc = f / sr;
    var pc = 0.0, pm = 0.0, pt = 0.0;
    final tineInc = f * 13.8 / sr;
    var tineAmp = tineInc < 0.45 ? 0.12 * vel : 0.0;
    final kT = t60Factor(0.03, sr);
    for (var i = 0; i < n; i++) {
      final mod = SineTable.wrapped(pm) * (idx + 0.18) / twoPi;
      var s = SineTable.at(pc + mod) * amp;
      if (tineAmp > 1e-5) {
        s += SineTable.wrapped(pt) * tineAmp;
        pt += tineInc;
        if (pt >= 1) pt -= 1;
        tineAmp *= kT;
      }
      out[i] = s;
      pc += dc;
      if (pc >= 1) pc -= 1;
      pm += dc;
      if (pm >= 1) pm -= 1;
      amp *= i < holdN ? kA : kR;
      idx *= kI;
    }
    fadeEdges(out, framesFor(sr, 0.002), framesFor(sr, 0.01));
    _normalize(out, 0.45 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _vibes(NoteEvent e, double f, double hold, double vel) {
    final damped = e.has(Art.staccato);
    final t60 = 3.6;
    final rel = damped ? 0.18 : 1.4;
    final n = framesFor(sr, math.min(hold + rel, t60 * 1.2));
    final out = Float64List(n);
    addModes(
      out,
      sr,
      freqs: [f, f * 4.0, f * 10.0],
      gains: [1.0, 0.22 * vel + 0.05, 0.05 * vel],
      t60s: [t60, t60 * 0.28, t60 * 0.07],
      dampT60s: [rel, rel * 0.5, rel * 0.3],
      holdN: framesFor(sr, hold),
    );
    // Motor tremolo.
    final rate = 5.4 / sr;
    var p = rng.nextDouble();
    for (var i = 0; i < n; i++) {
      out[i] *= 1 - 0.34 * (0.5 + 0.5 * SineTable.wrapped(p));
      p += rate;
      if (p >= 1) p -= 1;
    }
    fadeEdges(out, framesFor(sr, 0.0015), framesFor(sr, 0.01));
    _normalize(out, 0.5 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _mallet(double f, double hold, double vel, List<double> ratios, List<double> gains, List<double> decays, double t60) {
    final n = framesFor(sr, t60 * 1.2);
    final out = Float64List(n);
    addModes(
      out,
      sr,
      freqs: [for (final r in ratios) f * r],
      gains: [for (var i = 0; i < gains.length; i++) gains[i] * (i == 0 ? 1 : 0.4 + 0.8 * vel)],
      t60s: [for (final d in decays) t60 * d],
      dampT60s: [for (final d in decays) t60 * d],
    );
    fadeEdges(out, framesFor(sr, 0.0008), framesFor(sr, 0.01));
    _normalize(out, 0.5 * (0.3 + 0.7 * vel));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Bass

  Float64List _upright(NoteEvent e, double f, double hold, double vel) {
    final t60 = (1.9 * math.pow(55 / f, 0.25)).clamp(0.8, 2.4).toDouble();
    final rel = e.has(Art.staccato) ? 0.06 : 0.13;
    final n = framesFor(sr, math.min(hold + rel * 1.3, t60 * 1.3));
    final out = Float64List(n);
    final freqs = <double>[], gains = <double>[], t60s = <double>[], damps = <double>[];
    for (var p = 1; p <= 9; p++) {
      final fp = f * p * (1 + 0.0006 * p * p);
      freqs.add(fp);
      gains.add((math.sin(math.pi * p * 0.21).abs() + 0.04) / math.pow(p, 1.25 - 0.3 * vel));
      t60s.add(t60 / (1 + 0.9 * (p - 1)));
      damps.add(rel / (1 + 0.3 * (p - 1)));
    }
    addModes(out, sr, freqs: freqs, gains: gains, t60s: t60s, dampT60s: damps, holdN: framesFor(sr, hold));
    // Finger thump on the fingerboard.
    final tn = framesFor(sr, 0.03);
    final lp = OnePole(sr, 420);
    for (var i = 0; i < tn && i < n; i++) {
      final env = math.exp(-i / (tn * 0.3));
      out[i] += lp.lp(rng.bipolar()) * env * 0.9 * vel;
    }
    fadeEdges(out, framesFor(sr, 0.002), framesFor(sr, 0.008));
    _normalize(out, 0.62 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _tuba(NoteEvent e, double f, double hold, double vel) {
    final st = e.has(Art.staccato);
    final env = Env(sr, attack: 0.028, decay: 0.14, sustain: st ? 0.55 : 0.78, release: st ? 0.06 : 0.09, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final path = PitchPath(sr, f, e, hold, vibCents: 0);
    final osc = Osc();
    final flt = Filter(sr, cutoff: f * 3, q: 0.85);
    final breath = OnePole(sr, 700);
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      final a = env.next();
      if (i & 31 == 0) {
        inc = path.incAt(i / sr);
        flt.set(f * (1.4 + 4.2 * vel * a) + 120, 0.85);
      }
      var s = osc.saw(inc) * 0.8;
      if (i < 800) s += breath.lp(rng.bipolar()) * 0.35 * (1 - i / 800);
      out[i] = flt.lp(s) * a;
    }
    _normalize(out, 0.6 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _eBass(NoteEvent e, double f, double hold, double vel) {
    final slap = e.has(Art.slap);
    final holdN = framesFor(sr, hold);
    final relN = framesFor(sr, 0.05);
    final n = holdN + relN;
    final out = Float64List(n);
    final osc = Osc(), osc2 = Osc(0.25);
    final flt = Filter(sr, cutoff: 800, q: 0.9);
    final path = PitchPath(sr, f, e, hold, glideTau: 0.06);
    final kA = t60Factor(1.6, sr);
    var amp = 1.0;
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) {
        final t = i / sr;
        inc = path.incAt(t);
        final pluck = math.exp(-t / (slap ? 0.035 : 0.07));
        flt.set(f * 2.2 + 260 + (slap ? 4800 : 1900) * vel * pluck, slap ? 1.6 : 0.9);
      }
      final s = osc.saw(inc) * 0.55 + osc2.tri(inc) * 0.6;
      final r = i < holdN ? 1.0 : 0.5 + 0.5 * math.cos(math.pi * (i - holdN) / relN);
      out[i] = flt.lp(s) * amp * r;
      amp *= kA;
    }
    fadeEdges(out, framesFor(sr, 0.0015), 8);
    _normalize(out, 0.62 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _synthBass(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: 0.003, decay: 0.25, sustain: 0.75, release: 0.05, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final a = Osc(), b = Osc(0.5), sub = Osc();
    final flt = Filter(sr, cutoff: 800, q: 2.2);
    final path = PitchPath(sr, f, e, hold, glideTau: 0.04);
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) {
        final t = i / sr;
        inc = path.incAt(t);
        flt.set(f * 1.6 + 180 + 2600 * vel * math.exp(-t / 0.11), 2.2);
      }
      final s = a.saw(inc) * 0.6 + b.pulse(inc * 1.003, 0.5) * 0.35;
      out[i] = (flt.lp(s) + sub.sine(inc * 0.5) * 0.45) * env.next();
    }
    _normalize(out, 0.6 * (0.35 + 0.65 * vel));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Plucked / bowed

  Float64List _banjo(double f, double hold, double vel) {
    final t60 = 0.75;
    final n = framesFor(sr, math.min(hold + 0.12, t60 * 1.2));
    final out = Float64List(n);
    final freqs = <double>[], gains = <double>[], t60s = <double>[], damps = <double>[];
    for (var p = 1; p <= 12; p++) {
      final fp = f * p * (1 + 0.0004 * p);
      if (fp > sr * 0.45) break;
      freqs.add(fp);
      gains.add((math.sin(math.pi * p * 0.13).abs() + 0.03) / math.pow(p, 0.55));
      t60s.add(t60 / (1 + 0.3 * (p - 1)));
      damps.add(0.08);
    }
    // Drum-head body.
    freqs.addAll([395, 610]);
    gains.addAll([0.35, 0.15]);
    t60s.addAll([0.05, 0.04]);
    damps.addAll([0.05, 0.04]);
    addModes(out, sr, freqs: freqs, gains: gains, t60s: t60s, dampT60s: damps, holdN: framesFor(sr, hold));
    final pick = framesFor(sr, 0.003);
    for (var i = 0; i < pick && i < n; i++) {
      out[i] += rng.bipolar() * 0.25 * (1 - i / pick);
    }
    fadeEdges(out, 6, framesFor(sr, 0.006));
    _normalize(out, 0.5 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _wahGuitar(NoteEvent e, double f, double hold, double vel) {
    final ghost = e.has(Art.ghost);
    final holdN = framesFor(sr, ghost ? 0.03 : hold);
    final relN = framesFor(sr, 0.03);
    final n = holdN + relN;
    final out = Float64List(n);
    final a = Osc(), b = Osc(0.3);
    final wah = Filter(sr, cutoff: 500, q: 3.2);
    final kA = t60Factor(0.9, sr);
    var amp = 1.0;
    final inc = f / sr;
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) {
        final t = i / sr;
        final sweep = t < 0.04 ? t / 0.04 : math.exp(-(t - 0.04) / 0.16);
        wah.set(420 + 1900 * sweep * (0.5 + 0.5 * vel), 3.2);
      }
      var s = a.saw(inc) * 0.5 + b.pulse(inc * 2.001, 0.4) * 0.35;
      if (ghost) s = s * 0.25 + rng.bipolar() * 0.8;
      final r = i < holdN ? 1.0 : 0.5 + 0.5 * math.cos(math.pi * (i - holdN) / relN);
      out[i] = wah.bp(s) * amp * r;
      amp *= kA;
    }
    fadeEdges(out, 12, 8);
    _normalize(out, 0.45 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _clav(double f, double hold, double vel) {
    final holdN = framesFor(sr, hold);
    final relN = framesFor(sr, 0.025);
    final n = holdN + relN;
    final out = Float64List(n);
    final o = Osc();
    final lp = Filter(sr, cutoff: 3000, q: 1.1);
    final hp = OnePole(sr, 160);
    final kA = t60Factor(0.9, sr);
    var amp = 1.0;
    final inc = f / sr;
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) lp.set(f * 2 + 900 + 5200 * vel * math.exp(-i / sr / 0.07), 1.1);
      final r = i < holdN ? 1.0 : 0.5 + 0.5 * math.cos(math.pi * (i - holdN) / relN);
      out[i] = lp.lp(hp.hp(o.pulse(inc, 0.22))) * amp * r;
      amp *= kA;
    }
    fadeEdges(out, 6, 6);
    _normalize(out, 0.45 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _violin(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: e.has(Art.staccato) ? 0.02 : 0.08, decay: 0.3, sustain: 0.85, release: 0.14, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final path = PitchPath(sr, f, e, hold, vibCents: 18, vibRate: 5.8, vibDelay: 0.12);
    final o = Osc();
    final body1 = Filter(sr, cutoff: 480, q: 1.6), body2 = Filter(sr, cutoff: 1250, q: 1.8), body3 = Filter(sr, cutoff: 2900, q: 2.2);
    final lp = OnePole(sr, 5200);
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) inc = path.incAt(i / sr);
      final s = o.saw(inc);
      final shaped = body1.bp(s) * 0.9 + body2.bp(s) * 1.0 + body3.bp(s) * 0.6 + s * 0.12;
      out[i] = lp.lp(shaped) * env.next();
    }
    _normalize(out, 0.42 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _strings(NoteEvent e, double f, double hold, double vel) {
    final stab = e.has(Art.staccato) || e.has(Art.accent);
    final env = Env(
      sr,
      attack: stab ? 0.018 : 0.16,
      decay: 0.25,
      sustain: stab ? 0.55 : 0.9,
      release: stab ? 0.12 : 0.32,
      holdN: framesFor(sr, hold),
    );
    final n = env.length;
    final out = Float64List(n);
    final oscs = [Osc(0.1), Osc(0.43), Osc(0.77)];
    const det = [0.9948, 1.0, 1.0056];
    final lp = Filter(sr, cutoff: 2600, q: 0.7);
    final hp = OnePole(sr, 180);
    final trem = e.has(Art.trem);
    final tr = 11.5 / sr;
    var tp = 0.0, vp = rng.nextDouble();
    final vr = 5.1 / sr;
    final inc = f / sr;
    for (var i = 0; i < n; i++) {
      final vib = 1 + 0.0028 * SineTable.wrapped(vp);
      vp += vr;
      if (vp >= 1) vp -= 1;
      var s = 0.0;
      for (var k = 0; k < 3; k++) {
        s += oscs[k].saw(inc * det[k] * (k == 1 ? vib : 1 / vib));
      }
      var a = env.next();
      if (trem) {
        a *= 0.55 + 0.45 * SineTable.wrapped(tp);
        tp += tr;
        if (tp >= 1) tp -= 1;
      }
      out[i] = lp.lp(hp.hp(s)) * a;
    }
    _normalize(out, 0.4 * (0.35 + 0.65 * vel));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Winds and brass

  Float64List _clarinet(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: 0.032, decay: 0.2, sustain: 0.88, release: 0.06, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final path = PitchPath(sr, f, e, hold, vibCents: 7, vibRate: 5.0, glideTau: 0.07);
    final o = Osc();
    final lp = Filter(sr, cutoff: math.min(f * 7, 3600), q: 0.8);
    final breath = Filter(sr, cutoff: f * 3, q: 1.2);
    final growl = e.has(Art.growl);
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) inc = path.incAt(i / sr);
      var s = o.pulse(inc, 0.5) * 0.8 + breath.bp(rng.bipolar()) * 0.08;
      if (growl) s *= 0.75 + 0.25 * SineTable.at(i * 27.0 / sr);
      out[i] = lp.lp(s) * env.next();
    }
    _normalize(out, 0.42 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _mutedTrumpet(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: 0.022, decay: 0.2, sustain: 0.8, release: 0.06, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final path = PitchPath(sr, f, e, hold, vibCents: 8, vibRate: 5.6);
    final o = Osc();
    final hp = Filter(sr, cutoff: 520, q: 0.7);
    final nasal = Filter(sr, cutoff: 1750, q: 2.6);
    final nasal2 = Filter(sr, cutoff: 3300, q: 3.0);
    final plunger = Filter(sr, cutoff: 700, q: 2.2);
    final wah = e.has(Art.wah);
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      if (i & 15 == 0) {
        inc = path.incAt(t);
        if (wah) {
          final open = t < 0.14 ? t / 0.14 : 1.0;
          final close = t > hold - 0.08 ? math.max(0.0, 1 - (t - (hold - 0.08)) / 0.08) : 1.0;
          plunger.set(650 + 1100 * open * close, 2.2);
        }
      }
      final s = hp.hp(o.saw(inc));
      var y = nasal.bp(s) * 1.1 + nasal2.bp(s) * 0.45 + s * 0.15;
      if (wah) y = plunger.bp(y) * 1.6 + y * 0.15;
      out[i] = y * env.next();
    }
    _normalize(out, 0.4 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _brass(NoteEvent e, double f, double hold, double vel, {required double bright, required double attack}) {
    final env = Env(
      sr,
      attack: attack,
      decay: 0.18,
      sustain: e.has(Art.staccato) ? 0.5 : 0.8,
      release: e.has(Art.fall) ? 0.2 : 0.07,
      holdN: framesFor(sr, hold + (e.has(Art.fall) ? 0.12 : 0)),
    );
    final n = env.length;
    final out = Float64List(n);
    final path = PitchPath(sr, f, e, hold, vibCents: 0, vibRate: 5.4, glideTau: 0.08);
    final o = Osc(), o2 = Osc(0.37);
    final lp = Filter(sr, cutoff: f * 3, q: 0.9);
    final presence = Filter(sr, cutoff: 1300, q: 1.2);
    final growl = e.has(Art.growl);
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      final a = env.next();
      if (i & 15 == 0) {
        inc = path.incAt(i / sr);
        lp.set(f * (1.2 + bright * vel * a) + 250, 0.9);
      }
      var s = o.saw(inc) * 0.7 + o2.saw(inc * 1.0035) * 0.3;
      if (growl) s *= 0.7 + 0.3 * SineTable.at(i * 31.0 / sr);
      final y = lp.lp(s);
      out[i] = (y + presence.bp(y) * 0.6) * a;
    }
    _normalize(out, 0.42 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _sax(NoteEvent e, double f, double hold, double vel, {required bool tenor}) {
    final env = Env(sr, attack: 0.03, decay: 0.2, sustain: 0.85, release: 0.07, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final path = PitchPath(sr, f, e, hold, vibCents: 10, vibRate: 5.0, glideTau: 0.06);
    final o = Osc();
    final f1 = Filter(sr, cutoff: tenor ? 480 : 620, q: 1.4);
    final f2 = Filter(sr, cutoff: tenor ? 1350 : 1650, q: 2.0);
    final f3 = Filter(sr, cutoff: tenor ? 2600 : 3100, q: 2.5);
    final lp = Filter(sr, cutoff: style == MusicStyle.noirJazz ? 2600 : 4200, q: 0.7);
    final breath = Filter(sr, cutoff: 2800, q: 0.9);
    final growl = e.has(Art.growl);
    final air = style == MusicStyle.noirJazz ? 0.16 : 0.07;
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) inc = path.incAt(i / sr);
      var s = o.saw(inc);
      if (growl) s *= 0.72 + 0.28 * SineTable.at(i * 29.0 / sr);
      final y = f1.bp(s) * 0.9 + f2.bp(s) * 1.1 + f3.bp(s) * 0.45 + s * 0.2 + breath.bp(rng.bipolar()) * air;
      out[i] = lp.lp(y) * env.next();
    }
    _normalize(out, 0.42 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _flute(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: 0.06, decay: 0.2, sustain: 0.9, release: 0.09, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final path = PitchPath(sr, f, e, hold, vibCents: 12, vibRate: 5.2, vibDelay: 0.15);
    final o1 = Osc(), o2 = Osc(), o3 = Osc();
    final breath = Filter(sr, cutoff: math.min(f * 2, 5000), q: 2.5);
    final chiff = framesFor(sr, 0.035);
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) inc = path.incAt(i / sr);
      var s = o1.sine(inc) + o2.sine(inc * 2) * 0.16 + o3.sine(inc * 3) * 0.05;
      s += breath.bp(rng.bipolar()) * (0.12 + (i < chiff ? 0.5 * (1 - i / chiff) : 0));
      out[i] = s * env.next();
    }
    _normalize(out, 0.4 * (0.35 + 0.65 * vel));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Synths

  Float64List _synthLead(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: 0.008, decay: 0.3, sustain: 0.8, release: 0.14, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final path = PitchPath(sr, f, e, hold, vibCents: 0, vibRate: 5.6, vibDelay: 0.3, glideTau: 0.06);
    final a = Osc(), b = Osc(0.33), c = Osc(0.66);
    final lp = Filter(sr, cutoff: 3200, q: 1.1);
    var inc = path.incAt(0);
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) {
        final t = i / sr;
        inc = path.incAt(t);
        lp.set(1800 + 2600 * vel * (0.6 + 0.4 * math.exp(-t / 0.3)), 1.1);
      }
      final s = a.saw(inc * 0.9965) * 0.45 + b.saw(inc * 1.0035) * 0.45 + c.pulse(inc * 0.5, 0.5) * 0.25;
      out[i] = lp.lp(s) * env.next();
    }
    _normalize(out, 0.4 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _synthArp(double f, double hold, double vel) {
    final holdN = framesFor(sr, hold);
    final relN = framesFor(sr, 0.04);
    final n = holdN + relN;
    final out = Float64List(n);
    final a = Osc(), b = Osc(0.25);
    final lp = Filter(sr, cutoff: 3000, q: 1.6);
    final kA = t60Factor(0.45, sr);
    var amp = 1.0;
    final inc = f / sr;
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) lp.set(500 + f + 5200 * vel * math.exp(-i / sr / 0.08), 1.6);
      final r = i < holdN ? 1.0 : 0.5 + 0.5 * math.cos(math.pi * (i - holdN) / relN);
      out[i] = lp.lp(a.pulse(inc, 0.5) * 0.6 + b.saw(inc * 1.004) * 0.4) * amp * r;
      amp *= kA;
    }
    fadeEdges(out, 12, 6);
    _normalize(out, 0.38 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _synthPad(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: 0.38, decay: 0.6, sustain: 0.9, release: 0.7, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    const det = [0.9918, 0.9966, 1.0, 1.004, 1.0077];
    final oscs = [for (var k = 0; k < det.length; k++) Osc(rng.nextDouble())];
    final lp = Filter(sr, cutoff: 1400, q: 0.8);
    final inc = f / sr;
    for (var i = 0; i < n; i++) {
      if (i & 31 == 0) lp.set(900 + 1300 * math.min(1.0, i / sr / 1.2) + f, 0.8);
      var s = 0.0;
      for (var k = 0; k < det.length; k++) {
        s += oscs[k].saw(inc * det[k]);
      }
      out[i] = lp.lp(s * 0.3) * env.next();
    }
    _normalize(out, 0.34 * (0.35 + 0.65 * vel));
    return out;
  }

  Float64List _synthBrass(NoteEvent e, double f, double hold, double vel) {
    final env = Env(sr, attack: 0.014, decay: 0.3, sustain: 0.65, release: 0.16, holdN: framesFor(sr, hold));
    final n = env.length;
    final out = Float64List(n);
    final oscs = [Osc(0.1), Osc(0.5), Osc(0.8)];
    const det = [0.994, 1.0, 1.006];
    final lp = Filter(sr, cutoff: 1000, q: 1.0);
    final inc = f / sr;
    for (var i = 0; i < n; i++) {
      if (i & 15 == 0) {
        final t = i / sr;
        final c = t < 0.04 ? t / 0.04 : 0.45 + 0.55 * math.exp(-(t - 0.04) / 0.25);
        lp.set(350 + f + 4200 * vel * c, 1.0);
      }
      var s = 0.0;
      for (var k = 0; k < 3; k++) {
        s += oscs[k].saw(inc * det[k]);
      }
      out[i] = lp.lp(s * 0.4) * env.next();
    }
    _normalize(out, 0.42 * (0.35 + 0.65 * vel));
    return out;
  }

  // ---------------------------------------------------------------------------
  // Drums

  Float64List _kick(NoteEvent e, double vel) {
    final modern = style == MusicStyle.synthwave || style == MusicStyle.funk;
    final f0 = (modern ? 50.0 : 58.0) * semitoneRatio(e.pitch);
    final sweep = modern ? 2.8 : 1.6;
    final t60 = style == MusicStyle.synthwave ? 0.55 : (modern ? 0.32 : 0.42);
    final n = framesFor(sr, t60 * 1.1);
    final out = Float64List(n);
    final k = t60Factor(t60, sr);
    var amp = 1.0, ph = 0.0;
    final lp = OnePole(sr, modern ? 3500 : 900);
    for (var i = 0; i < n; i++) {
      final t = i / sr;
      final f = f0 * (1 + (sweep - 1) * math.exp(-t / 0.028));
      ph += f / sr;
      if (ph >= 1) ph -= 1;
      var s = SineTable.wrapped(ph) * amp;
      if (i < 90) s += lp.lp(rng.bipolar()) * (modern ? 0.5 : 0.35) * (1 - i / 90);
      out[i] = soft(s * 1.25);
      amp *= k;
    }
    fadeEdges(out, 4, framesFor(sr, 0.02));
    _normalize(out, 0.9 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _snare(NoteEvent e, double vel, {required bool gated}) {
    final vintage = _vintage;
    final t60 = vintage ? 0.16 : 0.22;
    final len = gated ? 0.42 : t60 * 1.2;
    final n = framesFor(sr, len);
    final out = Float64List(n);
    final kT = t60Factor(0.07, sr), kN = t60Factor(t60, sr);
    var at = 1.0, an = 1.0;
    final hp = Filter(sr, cutoff: vintage ? 1400 : 950, q: 0.7);
    final lp = OnePole(sr, vintage ? 5200 : 8000);
    final f1 = 185.0 * semitoneRatio(e.pitch), f2 = 330.0 * semitoneRatio(e.pitch);
    var p1 = 0.0, p2 = 0.0;
    final gateN = framesFor(sr, 0.3);
    for (var i = 0; i < n; i++) {
      final tone = (SineTable.wrapped(p1) + 0.6 * SineTable.wrapped(p2)) * at;
      p1 += f1 / sr;
      if (p1 >= 1) p1 -= 1;
      p2 += f2 / sr;
      if (p2 >= 1) p2 -= 1;
      final nz = lp.lp(hp.hp(rng.bipolar()));
      var s = tone * (vintage ? 0.35 : 0.55) + nz * an * 0.9;
      if (gated) {
        // A dense plate tail held flat, then shut: the 1980s gate.
        final g = i < gateN ? 0.55 * math.min(1.0, i / 300) : 0.55 * math.max(0.0, 1 - (i - gateN) / (sr * 0.03));
        s += nz * g;
      }
      out[i] = s;
      at *= kT;
      an *= kN;
    }
    if (e.has(Art.slap)) {
      for (var i = 0; i < 40 && i < n; i++) {
        out[i] += (i.isEven ? 0.6 : -0.6) * (1 - i / 40);
      }
    }
    fadeEdges(out, 3, framesFor(sr, 0.015));
    _normalize(out, 0.75 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _brushTap(double vel) {
    final n = framesFor(sr, 0.16);
    final out = Float64List(n);
    final bp = Filter(sr, cutoff: 3600, q: 0.8);
    final k = t60Factor(0.11, sr);
    var a = 1.0;
    for (var i = 0; i < n; i++) {
      out[i] = bp.bp(rng.bipolar()) * a;
      a *= k;
    }
    fadeEdges(out, framesFor(sr, 0.0015), framesFor(sr, 0.01));
    _normalize(out, 0.45 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _brushSweep(double hold, double vel) {
    final n = framesFor(sr, hold + 0.08);
    final out = Float64List(n);
    final bp = Filter(sr, cutoff: 2600, q: 0.6);
    for (var i = 0; i < n; i++) {
      final u = i / n;
      final env = math.sin(math.pi * math.pow(u, 0.8));
      if (i & 31 == 0) bp.set(2200 + 1400 * u, 0.6);
      out[i] = bp.bp(rng.bipolar()) * env;
    }
    _normalize(out, 0.22 * (0.3 + 0.7 * vel));
    return out;
  }

  static const _metalFreqs = [205.3, 304.4, 369.6, 522.7, 540.0, 800.0];

  Float64List _metal(double vel, {required double t60, required double hp, required double level, double tune = 0}) {
    final n = framesFor(sr, t60 * 1.25);
    final out = Float64List(n);
    final phases = [for (var i = 0; i < 6; i++) rng.nextDouble()];
    final scale = (_vintage ? 1.6 : 2.2) * semitoneRatio(tune);
    final incs = [for (final f in _metalFreqs) f * scale / sr];
    final h1 = Filter(sr, cutoff: math.min(hp, sr * 0.36), q: 0.7);
    final h2 = Filter(sr, cutoff: math.min(hp * 1.1, sr * 0.38), q: 0.7);
    final k = t60Factor(t60, sr);
    var a = 1.0;
    for (var i = 0; i < n; i++) {
      var s = 0.0;
      for (var j = 0; j < 6; j++) {
        s += phases[j] < 0.5 ? 1.0 : -1.0;
        var p = phases[j] + incs[j];
        if (p >= 1) p -= 1;
        phases[j] = p;
      }
      s = s * 0.16 + rng.bipolar() * 0.45;
      out[i] = h2.hp(h1.hp(s)) * a;
      a *= k;
    }
    fadeEdges(out, 3, framesFor(sr, 0.006));
    _normalize(out, level * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _ride(NoteEvent e, double vel) {
    final soft = e.has(Art.ghost) || style == MusicStyle.noirJazz && e.vel < 0.5;
    final base = _metal(vel, t60: soft ? 0.9 : 1.5, hp: 4200, level: 0.3);
    addModes(
      base,
      sr,
      freqs: [
        for (final r in const [1.0, 1.47, 2.09, 2.56]) r * (_vintage ? 2450.0 : 3050.0),
      ],
      gains: [0.06 * vel, 0.04 * vel, 0.025 * vel, 0.015 * vel],
      t60s: const [0.8, 0.6, 0.4, 0.3],
      dampT60s: const [0.8, 0.6, 0.4, 0.3],
    );
    fadeEdges(base, 3, framesFor(sr, 0.02));
    _normalize(base, 0.42 * (0.3 + 0.7 * vel));
    return base;
  }

  Float64List _crash(double vel, {required double t60}) {
    final n = framesFor(sr, t60 * 1.15);
    final out = Float64List(n);
    final phases = [for (var i = 0; i < 6; i++) rng.nextDouble()];
    final incs = [for (final f in _metalFreqs) f * 1.7 / sr];
    final hp = Filter(sr, cutoff: math.min(3200, sr * 0.3), q: 0.6);
    final lp = OnePole(sr, _vintage ? 6500 : 11000);
    final k = t60Factor(t60, sr);
    var a = 1.0;
    for (var i = 0; i < n; i++) {
      var s = 0.0;
      for (var j = 0; j < 6; j++) {
        s += phases[j] < 0.5 ? 1.0 : -1.0;
        var p = phases[j] + incs[j];
        if (p >= 1) p -= 1;
        phases[j] = p;
      }
      final attack = i < 200 ? 1.0 + (1 - i / 200) : 1.0;
      out[i] = lp.lp(hp.hp(s * 0.12 + rng.bipolar() * 0.6)) * a * attack;
      a *= k;
    }
    fadeEdges(out, 4, framesFor(sr, 0.03));
    _normalize(out, 0.55 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _rim(double vel) {
    final n = framesFor(sr, 0.09);
    final out = Float64List(n);
    addModes(
      out,
      sr,
      freqs: const [480, 1650, 2900],
      gains: const [0.6, 0.45, 0.2],
      t60s: const [0.05, 0.035, 0.02],
      dampT60s: const [0.05, 0.035, 0.02],
    );
    for (var i = 0; i < 24 && i < n; i++) {
      out[i] += rng.bipolar() * 0.5 * (1 - i / 24);
    }
    fadeEdges(out, 2, framesFor(sr, 0.01));
    _normalize(out, 0.5 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _block(double vel, double f, double t60) {
    final n = framesFor(sr, t60 * 1.3);
    final out = Float64List(n);
    addModes(
      out,
      sr,
      freqs: [f, f * 1.58, f * 2.4],
      gains: const [1.0, 0.45, 0.15],
      t60s: [t60, t60 * 0.6, t60 * 0.35],
      dampT60s: [t60, t60 * 0.6, t60 * 0.35],
    );
    fadeEdges(out, 2, framesFor(sr, 0.006));
    _normalize(out, 0.55 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _tom(double vel, double f0) {
    final n = framesFor(sr, 0.55);
    final out = Float64List(n);
    final k = t60Factor(0.45, sr);
    var a = 1.0, ph = 0.0;
    final lp = OnePole(sr, 1500);
    for (var i = 0; i < n; i++) {
      final f = f0 * (1 + 0.45 * math.exp(-i / sr / 0.05));
      ph += f / sr;
      if (ph >= 1) ph -= 1;
      var s = SineTable.wrapped(ph) * a;
      if (i < 400) s += lp.lp(rng.bipolar()) * 0.3 * (1 - i / 400);
      out[i] = s;
      a *= k;
    }
    fadeEdges(out, 3, framesFor(sr, 0.02));
    _normalize(out, 0.7 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _hand(NoteEvent e, double vel, double f0, double t60) {
    final slap = e.has(Art.slap);
    final t = slap ? t60 * 0.45 : t60;
    final n = framesFor(sr, t * 1.25);
    final out = Float64List(n);
    addModes(
      out,
      sr,
      freqs: [f0, f0 * 1.51, f0 * 1.99, f0 * 2.44],
      gains: const [1.0, 0.4, 0.2, 0.1],
      t60s: [t, t * 0.5, t * 0.35, t * 0.25],
      dampT60s: [t, t * 0.5, t * 0.35, t * 0.25],
    );
    final bp = Filter(sr, cutoff: slap ? 2400 : 900, q: 1.0);
    final nn = framesFor(sr, slap ? 0.025 : 0.01);
    for (var i = 0; i < nn && i < n; i++) {
      out[i] += bp.bp(rng.bipolar()) * (slap ? 1.4 : 0.6) * (1 - i / nn);
    }
    fadeEdges(out, 2, framesFor(sr, 0.01));
    _normalize(out, 0.6 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _clave(double vel) {
    final n = framesFor(sr, 0.12);
    final out = Float64List(n);
    addModes(out, sr, freqs: const [2450, 6600], gains: const [1.0, 0.18], t60s: const [0.09, 0.04], dampT60s: const [0.09, 0.04]);
    fadeEdges(out, 2, framesFor(sr, 0.005));
    _normalize(out, 0.45 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _cowbell(double vel) {
    final n = framesFor(sr, 0.4);
    final out = Float64List(n);
    final o1 = Osc(), o2 = Osc();
    final bp = Filter(sr, cutoff: 900, q: 1.4);
    final k1 = t60Factor(0.05, sr), k2 = t60Factor(0.32, sr);
    var a1 = 1.0, a2 = 0.35;
    for (var i = 0; i < n; i++) {
      final s = o1.pulse(562 / sr, 0.5) + o2.pulse(845 / sr, 0.5);
      out[i] = bp.bp(s) * (a1 + a2);
      a1 *= k1;
      a2 *= k2;
    }
    fadeEdges(out, 2, framesFor(sr, 0.01));
    _normalize(out, 0.45 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _shaker(double vel, double hold) {
    final n = framesFor(sr, 0.11);
    final out = Float64List(n);
    final hp = Filter(sr, cutoff: math.min(5200, sr * 0.35), q: 0.8);
    for (var i = 0; i < n; i++) {
      final u = i / n;
      final env = u < 0.18 ? u / 0.18 : math.exp(-(u - 0.18) * 7);
      out[i] = hp.hp(rng.bipolar()) * env;
    }
    fadeEdges(out, 2, framesFor(sr, 0.006));
    _normalize(out, 0.28 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _timpani(NoteEvent e, double f, double vel) {
    final roll = e.has(Art.trem);
    final t60 = 1.8;
    final hold = roll ? e.dur : 0.0;
    final n = framesFor(sr, hold + t60 * 1.1);
    final out = Float64List(n);
    final hits = roll ? math.max(1, (hold * 14).round()) : 1;
    for (var h = 0; h < hits; h++) {
      final at = roll ? framesFor(sr, h / 14.0) : 0;
      final g = roll ? (0.45 + 0.55 * h / hits) * (0.85 + 0.15 * rng.nextDouble()) : 1.0;
      addModes(
        out,
        sr,
        freqs: [f, f * 1.5, f * 1.98, f * 2.44, f * 2.9],
        gains: [g, 0.55 * g, 0.3 * g, 0.18 * g, 0.08 * g],
        t60s: [t60, t60 * 0.7, t60 * 0.5, t60 * 0.35, t60 * 0.25],
        dampT60s: [t60, t60 * 0.7, t60 * 0.5, t60 * 0.35, t60 * 0.25],
        start: at,
      );
      final lp = OnePole(sr, 600);
      for (var i = 0; i < 300 && at + i < n; i++) {
        out[at + i] += lp.lp(rng.bipolar()) * 0.5 * g * (1 - i / 300);
      }
    }
    fadeEdges(out, 3, framesFor(sr, 0.03));
    _normalize(out, 0.7 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _clap(double vel) {
    final n = framesFor(sr, 0.22);
    final out = Float64List(n);
    final bp = Filter(sr, cutoff: 1250, q: 1.1);
    final burst = framesFor(sr, 0.009);
    for (var i = 0; i < n; i++) {
      final b = i ~/ burst;
      final env = b < 3 ? math.exp(-(i % burst) / (burst * 0.35)) : math.exp(-(i - 3 * burst) / (sr * 0.05));
      out[i] = bp.bp(rng.bipolar()) * env;
    }
    fadeEdges(out, 2, framesFor(sr, 0.01));
    _normalize(out, 0.55 * (0.3 + 0.7 * vel));
    return out;
  }

  Float64List _tambourine(double vel) {
    final out = _metal(vel, t60: 0.2, hp: 6000, level: 0.35, tune: 7);
    final n = out.length;
    for (var i = 0; i < n; i++) {
      final u = i / n;
      out[i] *= u < 0.08 ? u / 0.08 : 1.0;
    }
    return out;
  }

  Float64List _gong(double vel) {
    const t60 = 4.5;
    final n = framesFor(sr, t60);
    final out = Float64List(n);
    const ratios = [1.0, 1.52, 2.03, 2.31, 2.77, 3.24, 3.9, 4.45, 5.1, 6.2];
    addModes(
      out,
      sr,
      freqs: [for (final r in ratios) 72.0 * r],
      gains: [for (var i = 0; i < ratios.length; i++) 1.0 / (1 + i * 0.4)],
      t60s: [for (var i = 0; i < ratios.length; i++) t60 / (1 + i * 0.15)],
      dampT60s: [for (var i = 0; i < ratios.length; i++) t60 / (1 + i * 0.15)],
    );
    final att = framesFor(sr, 0.05);
    for (var i = 0; i < n; i++) {
      out[i] *= i < att ? i / att : 1.0;
    }
    fadeEdges(out, 3, framesFor(sr, 0.2));
    _normalize(out, 0.7 * (0.3 + 0.7 * vel));
    return out;
  }

  /// Scales [x] so its peak is [target] (keeps relative voice levels sane
  /// across registers; velocity is folded into [target]).
  static void _normalize(Float64List x, double target) {
    var p = 0.0;
    for (var i = 0; i < x.length; i++) {
      final a = x[i].abs();
      if (a > p) p = a;
    }
    if (p <= 1e-9) return;
    final g = target / p;
    for (var i = 0; i < x.length; i++) {
      x[i] *= g;
    }
  }
}
