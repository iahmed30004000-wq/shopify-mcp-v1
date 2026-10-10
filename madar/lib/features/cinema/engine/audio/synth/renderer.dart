import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../../core/sound/synth/buffer.dart';
import '../../../../../core/sound/synth/dynamics.dart';
import '../../../../../core/sound/synth/filters.dart';
import '../../../../../core/sound/synth/reverb.dart';
import '../../../../../core/sound/synth/rng.dart';
import '../../core/audio.dart';
import '../../core/era_skin.dart';
import '../music/score.dart';
import 'dsp.dart';
import 'voices.dart';

/// Where the chords of a rendered cue fall (for stinger harmonisation).
final class ChordMark {
  const ChordMark(this.beat, this.rootPc, this.minor);

  /// Beat from the loop start (negative inside the intro).
  final double beat;

  /// Absolute pitch class 0..11 (C = 0).
  final int rootPc;
  final bool minor;
}

/// Timing and mix facts the director needs about a rendered cue.
final class CueInfo {
  const CueInfo({
    required this.style,
    required this.mood,
    required this.sampleRate,
    required this.beatsPerBar,
    required this.introSeconds,
    required this.introBeats,
    required this.loopSeconds,
    required this.loopBeats,
    required this.loops,
    required this.stems,
    required this.chords,
    required this.keyPc,
  });

  final MusicStyle style;
  final MusicMood mood;
  final int sampleRate;
  final int beatsPerBar;

  /// Intro length (loop start offset). The intro clips carry a release
  /// tail beyond this.
  final double introSeconds;
  final double introBeats;

  /// Exact loop length (an integer number of samples / [sampleRate]).
  final double loopSeconds;
  final double loopBeats;
  final bool loops;
  final List<StemSpec> stems;
  final List<ChordMark> chords;
  final int keyPc;

  double get beatSeconds => loopSeconds / loopBeats;
  double get barSeconds => beatSeconds * beatsPerBar;

  /// Chord at [beat] measured from the loop start (wraps inside the loop;
  /// negative = intro).
  ChordMark? chordAt(double beat) {
    if (chords.isEmpty) return null;
    var b = beat;
    if (b >= 0 && loopBeats > 0) b = b % loopBeats;
    ChordMark? best;
    for (final c in chords) {
      if (c.beat <= b + 1e-6 && (b >= 0 ? c.beat >= 0 : c.beat < 0)) best = c;
    }
    return best ?? chords.first;
  }
}

/// One stem's audio: the intro clip (with its tail; null when the cue has
/// no intro) and the seamless loop clip.
final class RenderedStem {
  const RenderedStem(this.spec, this.intro, this.loop);

  final StemSpec spec;
  final Uint8List? intro;
  final Uint8List loop;

  int get bytes => (intro?.length ?? 0) + loop.length;
}

/// A cue ready for the mixer.
final class RenderedCue {
  const RenderedCue(this.info, this.stems, {this.renderMs = 0});

  final CueInfo info;
  final List<RenderedStem> stems;
  final int renderMs;

  int get bytes => stems.fold(0, (a, s) => a + s.bytes);

  /// Approximate native memory once decoded by SoLoud (float32).
  int get decodedBytes => bytes * 2;
}

/// Offline renderer: composes a [CueScore]'s notes into per-stem buffers,
/// wraps the loop circularly (tails fold back to the start, so the loop is
/// periodic and click-free), adds the room and the period colour, levels
/// the full mix and encodes PCM16 WAVs.
final class CueRenderer {
  CueRenderer({this.targetRmsDb = -20, this.ceilingDb = -1.5, this.introTailSeconds = 2.5});

  /// Speaker-weighted RMS of the full-intensity loop.
  final double targetRmsDb;

  /// Peak ceiling of the full mix.
  final double ceilingDb;
  final double introTailSeconds;

  /// Speaker-weighted RMS of the last [render] before levelling
  /// (diagnostics: compares parts of an arrangement).
  double lastRawRmsDb = double.negativeInfinity;

  /// Milliseconds spent per phase in the last [render] (diagnostics).
  final Map<String, int> profile = {};

  RenderedCue render(CueScore score, {int seed = 1}) {
    final watch = Stopwatch()..start();
    final stems = [for (var i = 0; i < score.stems.length; i++) renderStem(score, i, seed: seed)];
    profile['stems'] = (profile['stems'] ?? 0) + watch.elapsedMilliseconds;
    final lap = watch.elapsedMilliseconds;
    final cue = finish(score, stems, seed: seed, renderMs: 0);
    profile['finish'] = (profile['finish'] ?? 0) + watch.elapsedMilliseconds - lap;
    return RenderedCue(cue.info, cue.stems, renderMs: watch.elapsedMilliseconds);
  }

  /// Renders stem [index] of [score]: its notes, echo, room and period
  /// colour (the bed also carries the surface noise). Independent of the
  /// other stems, so stems can render on parallel isolates; [finish] then
  /// levels and encodes them together.
  StemAudio renderStem(CueScore score, int index, {int seed = 1}) {
    final sr = score.sound.sampleRate;
    final loopN = math.max(1, (score.loopSeconds * sr).round());
    final introN = (score.introSeconds * sr).round();
    final tailN = introN > 0 ? (introTailSeconds * sr).round() : 0;
    final rng = SynthRandom(seed * 7919 + score.mood.index * 131 + score.style.index * 17 + index * 104729);
    final voices = VoiceBox(sr, score.style, seed ^ 0x5eed ^ (index * 977));
    // Voices are rendered once per (instrument, pitch, length, velocity,
    // articulation) and reused; the record key is exact, so no two notes
    // can ever share a buffer by hash collision.
    final cache = <(Inst, int, int, int, int, int), Float64List>{};
    final stem = StemAudio._(score.stems[index], introN + tailN, loopN, sr);
    final introSec = score.introSeconds;
    final loopSec = loopN / sr;
    final trims = [for (final i in Inst.values) math.pow(10.0, instTrimDb(i) / 20.0).toDouble()];
    final last = score.stems.length - 1;
    for (final e in score.events) {
      if (e.stem.clamp(0, last) != index) continue;
      final start = score.beatToSeconds(e.beat, straight: e.straight);
      final end = score.beatToSeconds(e.beat + e.dur, straight: e.straight);
      final jitter = _jitter(e.inst) * (rng.nextDouble() - rng.nextDouble()) * (1 + score.sound.lofi * 0.6);
      final vel = (e.vel * (1 + 0.07 * rng.bipolar())).clamp(0.02, 1.0);
      final velQ = (vel * 20).round() / 20;
      final hold = math.max(0.015, end - start);
      final holdQ = (hold * 100).round() / 100;
      final key = (e.inst, (e.pitch * 100).round(), (holdQ * 100).round(), (velQ * 20).round(), e.fx, (e.glideFrom * 100).round());
      final voice = cache[key] ??= voices.render(NoteEvent(0, e.dur, e.pitch, velQ, e.inst, fx: e.fx, glideFrom: e.glideFrom), holdQ);
      final t = math.max(0.0, start + jitter);
      final pan = _eventPan(e, stem.spec);
      final trim = trims[e.inst.index] * e.gain;
      if (e.beat < score.introBeats - 1e-6) {
        stem.addLinear(voice, (t * sr).round(), pan, trim);
      } else {
        final lt = (t - introSec) % loopSec;
        stem.addCircular(voice, (lt * sr).round() % loopN, pan, trim);
      }
    }
    // Echo, room and period colour (identical for every stem, so the sum
    // behaves like one processed mix).
    final lofi = _Lofi(score.sound, sr, loopN, introN, seed);
    final room = ReverbSpec(roomSize: score.sound.roomSize, damping: score.sound.damping, preDelayMs: 12, width: 0.9);
    final primeN = math.min(loopN, (2.0 * sr).round());
    if (stem.spec.delayBeats > 0) {
      stem.applyDelay((stem.spec.delayBeats * score.secondsPerBeat * sr).round(), stem.spec.delayFeedback, primeN);
    }
    if (stem.spec.reverb > 0 && score.sound.wet > 0) stem.applyReverb(room, sr, stem.spec.reverb * score.sound.wet, primeN);
    lofi.apply(stem, primeN);
    if (index == 0 && (score.sound.crackle > 0 || score.sound.lofi > 0.3)) lofi.addSurface(stem);
    return stem;
  }

  /// Levels [stems] together (the full-intensity sum hits the loudness
  /// target; one shared limiter gain curve keeps every layer combination
  /// under the ceiling), trims the intro tail and encodes the WAVs.
  RenderedCue finish(CueScore score, List<StemAudio> stems, {int seed = 1, int renderMs = 0}) {
    final sr = score.sound.sampleRate;
    final introN = (score.introSeconds * sr).round();
    final tailN = introN > 0 ? (introTailSeconds * sr).round() : 0;
    final loopSec = stems.first.loopL.length / sr;
    final measure = score.loops || introN == 0 ? _Region.loop : _Region.intro;
    final mixL = _sum(stems, measure, left: true);
    final mixR = _sum(stems, measure, left: false);
    final rms = _weightedRmsDb(mixL, mixR, sr);
    lastRawRmsDb = rms;
    final gain = rms.isFinite ? math.pow(10.0, (targetRmsDb - rms) / 20.0).toDouble() : 1.0;
    for (final s in stems) {
      s.scale(gain);
    }
    final ceiling = math.pow(10.0, ceilingDb / 20.0).toDouble();
    _limit(stems, _Region.loop, ceiling, sr);
    if (introN > 0) _limit(stems, _Region.intro, ceiling, sr);

    // Trim the intro tail to what is audible.
    var introLen = 0;
    if (introN > 0) {
      introLen = introN;
      for (final s in stems) {
        introLen = math.max(introLen, s.audibleIntroEnd(ceiling * 0.0005));
      }
      introLen = math.min(introLen + (0.05 * sr).round(), introN + tailN);
    }

    final out = <RenderedStem>[];
    for (var si = 0; si < stems.length; si++) {
      final s = stems[si];
      Uint8List? intro;
      if (introN > 0) {
        s.fadeIntroTail(introLen, introN, sr);
        intro = s.encodeIntro(introLen, seed + si * 17);
      }
      out.add(RenderedStem(s.spec, intro, s.encodeLoop(seed + si * 31)));
    }

    final chords = <ChordMark>[];
    for (final slot in score.chart.slots) {
      final b = slot.beat - score.introBeats;
      chords.add(ChordMark(b, (score.keyMidi + slot.chord.root) % 12, slot.chord.isMinor));
    }
    final info = CueInfo(
      style: score.style,
      mood: score.mood,
      sampleRate: sr,
      beatsPerBar: score.beatsPerBar,
      introSeconds: introN / sr,
      introBeats: score.introBeats,
      loopSeconds: loopSec,
      loopBeats: score.loopBeats,
      loops: score.loops,
      stems: score.stems,
      chords: chords,
      keyPc: score.keyMidi % 12,
    );
    return RenderedCue(info, out, renderMs: renderMs);
  }

  static double _jitter(Inst i) {
    if (i.isDrum) return 0.003;
    return switch (i) {
      Inst.uprightBass || Inst.tuba || Inst.electricBass => 0.005,
      Inst.synthBass || Inst.synthArp || Inst.synthPad || Inst.synthLead || Inst.synthBrass => 0.0,
      Inst.piano || Inst.honkyPiano || Inst.banjo => 0.006,
      _ => 0.01,
    };
  }

  static double _eventPan(NoteEvent e, StemSpec s) {
    if (!s.stereo) return 0;
    // Stereo stems: spread by pitch (pads, arps) around the stem pan.
    final spread = ((e.pitch - 60) / 24).clamp(-0.7, 0.7);
    return (s.pan + spread).clamp(-1.0, 1.0);
  }

  static Float64List _sum(List<StemAudio> stems, _Region r, {required bool left}) {
    final n = r == _Region.loop ? stems.first.loopL.length : stems.first.introL.length;
    final out = Float64List(n);
    for (final s in stems) {
      final useLeft = left || !s.stereo;
      final src = r == _Region.loop ? (useLeft ? s.loopL : s.loopR) : (useLeft ? s.introL : s.introR);
      final g = s.spec.gain * (s.spec.stereo ? 1.0 : _panGain(s.spec.pan, left));
      for (var i = 0; i < n; i++) {
        out[i] += src[i] * g;
      }
    }
    return out;
  }

  /// SoLoud's per-channel gain for a mono voice at [pan] (≤ 1).
  static double _panGain(double pan, bool left) {
    final a = (pan.clamp(-1.0, 1.0) + 1) * math.pi / 4;
    return left ? math.cos(a) : math.sin(a);
  }

  static double _weightedRmsDb(Float64List l, Float64List r, int sr) {
    if (l.isEmpty) return double.negativeInfinity;
    final hl = Float64List.fromList(l), hr = Float64List.fromList(r);
    Biquad(BiquadType.highPass, frequency: 150, sampleRate: sr).processBuffer(hl);
    Biquad(BiquadType.highPass, frequency: 150, sampleRate: sr).processBuffer(hr);
    var e = 0.0;
    for (var i = 0; i < hl.length; i++) {
      e += 0.5 * (hl[i] * hl[i] + hr[i] * hr[i]);
    }
    e /= hl.length;
    return e <= 0 ? double.negativeInfinity : 10 * math.log(e) / math.ln10;
  }

  /// Look-ahead limiter gain shared by every stem (circular for the loop).
  void _limit(List<StemAudio> stems, _Region region, double ceiling, int sr) {
    final l = _sum(stems, region, left: true);
    final r = _sum(stems, region, left: false);
    final n = l.length;
    if (n == 0) return;
    final circular = region == _Region.loop;
    final req = Float64List(n);
    var any = false;
    for (var i = 0; i < n; i++) {
      final p = math.max(l[i].abs(), r[i].abs());
      if (p > ceiling) {
        req[i] = ceiling / p;
        any = true;
      } else {
        req[i] = 1;
      }
    }
    if (!any) return;
    final w = math.max(1, (0.002 * sr).round());
    // ext[k] = req[k - w] (wrapped when circular, 1 outside otherwise).
    final m = n + 2 * w;
    final ext = Float64List(m);
    for (var k = 0; k < m; k++) {
      final j = k - w;
      ext[k] = circular ? req[(j % n + n) % n] : (j >= 0 && j < n ? req[j] : 1.0);
    }
    // Forward sliding minimum over [k, k + w) with a monotonic deque.
    final minFwd = Float64List(m);
    final dq = Int32List(m);
    var head = 0, tail = 0;
    for (var k = m - 1; k >= 0; k--) {
      while (tail > head && ext[dq[tail - 1]] >= ext[k]) {
        tail--;
      }
      dq[tail++] = k;
      while (dq[head] > k + w - 1) {
        head++;
      }
      minFwd[k] = ext[dq[head]];
    }
    // Box average of the w minima that cover sample i: always <= req[i].
    final prefix = Float64List(m + 1);
    for (var k = 0; k < m; k++) {
      prefix[k + 1] = prefix[k] + minFwd[k];
    }
    final smooth = Float64List(n);
    for (var i = 0; i < n; i++) {
      final k = i + w;
      smooth[i] = (prefix[k + 1] - prefix[k + 1 - w]) / w;
    }
    // Release: one-pole recovery, run twice around a loop so the curve is
    // periodic.
    final rel = 1.0 - math.exp(-1.0 / (0.08 * sr));
    final gain = Float64List(n);
    var g = 1.0;
    final passes = circular ? 2 : 1;
    for (var p = 0; p < passes; p++) {
      for (var i = 0; i < n; i++) {
        final s = smooth[i];
        g = s < g ? s : g + (s - g) * rel;
        gain[i] = g;
      }
    }
    for (final s in stems) {
      s._applyGain(region, gain);
    }
  }
}

enum _Region { intro, loop }

/// One stem's float buffers between [CueRenderer.renderStem] and
/// [CueRenderer.finish] (transferable between isolates).
final class StemAudio {
  StemAudio._(this.spec, int introN, int loopN, this.sr)
    : introL = Float64List(introN),
      introR = spec.stereo ? Float64List(introN) : Float64List(0),
      loopL = Float64List(loopN),
      loopR = spec.stereo ? Float64List(loopN) : Float64List(0);

  final StemSpec spec;
  final int sr;
  final Float64List introL, introR, loopL, loopR;

  bool get stereo => spec.stereo;

  void addLinear(Float64List v, int at, double pan, double g) {
    final n = math.min(v.length, introL.length - at);
    if (n <= 0) return;
    if (!stereo) {
      for (var i = 0; i < n; i++) {
        introL[at + i] += v[i] * g;
      }
      return;
    }
    final a = (pan + 1) * math.pi / 4;
    final gl = math.cos(a) * math.sqrt2 * g, gr = math.sin(a) * math.sqrt2 * g;
    for (var i = 0; i < n; i++) {
      introL[at + i] += v[i] * gl;
      introR[at + i] += v[i] * gr;
    }
  }

  void addCircular(Float64List v, int at, double pan, double g) {
    final n = loopL.length;
    final m = math.min(v.length, n); // a voice longer than the loop is cut
    var j = at;
    if (!stereo) {
      for (var i = 0; i < m; i++) {
        loopL[j] += v[i] * g;
        if (++j >= n) j = 0;
      }
      return;
    }
    final a = (pan + 1) * math.pi / 4;
    final gl = math.cos(a) * math.sqrt2 * g, gr = math.sin(a) * math.sqrt2 * g;
    for (var i = 0; i < m; i++) {
      loopL[j] += v[i] * gl;
      loopR[j] += v[i] * gr;
      if (++j >= n) j = 0;
    }
  }

  /// Runs [process] over the loop so the result is its periodic steady
  /// state: the effect is primed with the last [primeN] samples, then run
  /// over the whole loop.
  static void _periodic(Float64List loop, int primeN, void Function(Float64List x) process) {
    final n = loop.length;
    final p = math.min(primeN, n);
    final buf = Float64List(p + n);
    buf.setRange(0, p, loop, n - p);
    buf.setRange(p, p + n, loop);
    process(buf);
    loop.setRange(0, n, buf, p);
  }

  void applyDelay(int delayN, double feedback, int primeN) {
    if (delayN <= 0) return;
    void run(Float64List l, Float64List? r) {
      // Ping-pong when stereo: echoes alternate sides.
      final lineL = Float64List(delayN), lineR = Float64List(delayN);
      var idx = 0;
      final lp = OnePole(sr, 5000);
      for (var i = 0; i < l.length; i++) {
        final dl = lineL[idx], dr = lineR[idx];
        final inL = l[i], inR = r == null ? inL : r[i];
        if (r == null) {
          lineL[idx] = inL + lp.lp(dl) * feedback;
          l[i] = inL + dl * 0.55;
        } else {
          lineL[idx] = (inL + inR) * 0.5 + dr * feedback;
          lineR[idx] = dl * feedback;
          l[i] = inL + dl * 0.6;
          r[i] = inR + dr * 0.6;
        }
        if (++idx >= delayN) idx = 0;
      }
    }

    if (stereo) {
      final n = loopL.length, p = math.min(primeN, n);
      final bl = Float64List(p + n)..setRange(0, p, loopL, n - p);
      bl.setRange(p, p + n, loopL);
      final br = Float64List(p + n)..setRange(0, p, loopR, n - p);
      br.setRange(p, p + n, loopR);
      run(bl, br);
      loopL.setRange(0, n, bl, p);
      loopR.setRange(0, n, br, p);
      if (introL.isNotEmpty) run(introL, introR);
    } else {
      _periodic(loopL, primeN, (x) => run(x, null));
      if (introL.isNotEmpty) run(introL, null);
    }
  }

  void applyReverb(ReverbSpec room, int sr, double send, int primeN) {
    void wetInto(Float64List l, Float64List? r) {
      final n = l.length;
      final s = Float64List(n);
      for (var i = 0; i < n; i++) {
        s[i] = (r == null ? l[i] : 0.5 * (l[i] + r[i])) * send;
      }
      final (wl, wr) = halfRateReverb(s, sr, room);
      if (r == null) {
        for (var i = 0; i < n; i++) {
          l[i] += 0.5 * (wl[i] + wr[i]);
        }
      } else {
        for (var i = 0; i < n; i++) {
          l[i] += wl[i];
          r[i] += wr[i];
        }
      }
    }

    final n = loopL.length, p = math.min(primeN, n);
    if (stereo) {
      final bl = Float64List(p + n)..setRange(0, p, loopL, n - p);
      bl.setRange(p, p + n, loopL);
      final br = Float64List(p + n)..setRange(0, p, loopR, n - p);
      br.setRange(p, p + n, loopR);
      wetInto(bl, br);
      loopL.setRange(0, n, bl, p);
      loopR.setRange(0, n, br, p);
      if (introL.isNotEmpty) wetInto(introL, introR);
    } else {
      _periodic(loopL, primeN, (x) => wetInto(x, null));
      if (introL.isNotEmpty) wetInto(introL, null);
    }
  }

  void scale(double g) {
    for (final b in [introL, introR, loopL, loopR]) {
      for (var i = 0; i < b.length; i++) {
        b[i] *= g;
      }
    }
  }

  void _applyGain(_Region r, Float64List gain) {
    final bufs = r == _Region.loop ? [loopL, loopR] : [introL, introR];
    for (final b in bufs) {
      if (b.isEmpty) continue;
      for (var i = 0; i < b.length; i++) {
        b[i] *= gain[i];
      }
    }
  }

  int audibleIntroEnd(double threshold) {
    for (var i = introL.length - 1; i >= 0; i--) {
      if (introL[i].abs() > threshold || (stereo && introR[i].abs() > threshold)) return i + 1;
    }
    return 0;
  }

  void fadeIntroTail(int len, int introN, int sr) {
    // The tail past the loop start fades out smoothly over its length.
    final start = introN;
    final n = len - start;
    if (n <= 0) return;
    for (final b in [introL, introR]) {
      if (b.isEmpty) continue;
      for (var i = 0; i < n; i++) {
        final u = i / n;
        b[start + i] *= 0.5 + 0.5 * math.cos(math.pi * u);
      }
    }
  }

  Uint8List encodeIntro(int len, int seed) =>
      encodeWav16(stereo ? [introL, introR] : [introL], sr, seed: seed, frames: math.min(len, introL.length));

  Uint8List encodeLoop(int seed) => encodeWav16(stereo ? [loopL, loopR] : [loopL], sr, seed: seed);
}

/// Period playback colour: band-limit, gentle saturation, wow & flutter
/// and (in the bed stem only) surface noise and crackle – all periodic
/// with the loop.
final class _Lofi {
  _Lofi(this.sound, this.sr, this.loopN, this.introN, this.seed);

  final CueSound sound;
  final int sr;
  final int loopN;
  final int introN;
  final int seed;

  Float64List? _wowLoop, _wowIntro;

  void apply(StemAudio s, int primeN) {
    final lofi = sound.lofi.clamp(0.0, 1.0);
    final lpHz = 16000 * math.pow(0.24, lofi).toDouble(); // 16 kHz → ~3.8 kHz
    final hpHz = 40 + 130 * lofi;
    final drive = 1 + 1.6 * lofi;
    void tone(Float64List x) {
      if (x.isEmpty) return;
      Biquad(BiquadType.highPass, frequency: hpHz, sampleRate: sr, q: 0.6).processBuffer(x);
      if (lpHz < sr * 0.42) Biquad(BiquadType.lowPass, frequency: lpHz, sampleRate: sr, q: 0.6).processBuffer(x);
      if (lofi > 0.3) Biquad(BiquadType.lowPass, frequency: math.min(lpHz * 1.2, sr * 0.45), sampleRate: sr, q: 0.6).processBuffer(x);
      if (lofi > 0.4) Biquad(BiquadType.peaking, frequency: 1500, sampleRate: sr, q: 0.8, gainDb: 3.0 * lofi).processBuffer(x);
      if (lofi > 0.05) {
        final inv = 1 / drive;
        for (var i = 0; i < x.length; i++) {
          final v = x[i] * drive;
          // Cheap soft clip (rational tanh approximation).
          x[i] = (v > 3 ? 1.0 : (v < -3 ? -1.0 : v * (27 + v * v) / (27 + 9 * v * v))) * inv;
        }
      }
    }

    for (final b in [s.loopL, s.loopR]) {
      if (b.isNotEmpty) StemAudio._periodic(b, primeN, tone);
    }
    tone(s.introL);
    if (s.stereo) tone(s.introR);
    if (sound.wow > 0.02) {
      final wl = _wowLoop ??= _wowCurve(loopN, 0);
      for (final b in [s.loopL, s.loopR]) {
        if (b.isNotEmpty) _warp(b, wl, circular: true);
      }
      if (s.introL.isNotEmpty) {
        final wi = _wowIntro ??= _wowCurve(s.introL.length, -introN);
        _warp(s.introL, wi, circular: false);
        if (s.stereo) _warp(s.introR, wi, circular: false);
      }
    }
  }

  /// Wow & flutter delay curve (whole LFO cycles per loop, so the loop
  /// stays periodic), in samples.
  Float64List _wowCurve(int n, int offset) {
    final loopSec = loopN / sr;
    final wowHz = math.max(1, (0.55 * loopSec).round()) / loopSec;
    final flutHz = math.max(1, (6.5 * loopSec).round()) / loopSec;
    final depth = sound.wow * 0.0016 * sr;
    final base = depth * 2 + 2;
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = (i + offset) / sr;
      out[i] = base + depth * math.sin(twoPi * wowHz * t) + depth * 0.08 * math.sin(twoPi * flutHz * t);
    }
    return out;
  }

  static void _warp(Float64List x, Float64List delay, {required bool circular}) {
    final n = x.length;
    final src = Float64List.fromList(x);
    for (var i = 0; i < n; i++) {
      final pos = i - delay[i];
      var i0 = pos.floor();
      final fr = pos - i0;
      double a, b;
      if (circular) {
        i0 %= n;
        if (i0 < 0) i0 += n;
        final i1 = i0 + 1 == n ? 0 : i0 + 1;
        a = src[i0];
        b = src[i1];
      } else {
        a = i0 < 0 || i0 >= n ? 0.0 : src[i0];
        b = i0 + 1 < 0 || i0 + 1 >= n ? 0.0 : src[i0 + 1];
      }
      x[i] = a + (b - a) * fr;
    }
  }

  /// Surface hiss + crackle into the bed stem (loop: periodic).
  void addSurface(StemAudio bed) {
    final rng = SynthRandom(seed ^ 0xC4AC);
    final level = 0.004 + 0.02 * sound.crackle;
    void run(Float64List x, bool circular) {
      if (x.isEmpty) return;
      final n = x.length;
      final hiss = OnePole(sr, 2500);
      final hissLevel = 0.0025 * sound.lofi;
      for (var i = 0; i < n; i++) {
        x[i] += hiss.lp(rng.bipolar()) * hissLevel;
      }
      if (sound.crackle <= 0) return;
      final rate = 4 + 26 * sound.crackle; // clicks per second
      final count = (rate * n / sr).round();
      final bp = Biquad(BiquadType.bandPass, frequency: 2600, sampleRate: sr, q: 0.7);
      final click = Float64List(48);
      for (var c = 0; c < count; c++) {
        final at = rng.nextInt(n);
        final amp = level * math.pow(rng.nextDouble(), 3) * 6 * (rng.nextDouble() < 0.5 ? -1 : 1);
        bp.reset();
        for (var k = 0; k < click.length; k++) {
          click[k] = bp.process(k == 0 ? 1.0 : 0.0) * amp * math.exp(-k / 9);
        }
        for (var k = 0; k < click.length; k++) {
          final j = at + k;
          if (circular) {
            x[j % n] += click[k];
          } else if (j < n) {
            x[j] += click[k];
          }
        }
      }
    }

    run(bed.loopL, true);
    run(bed.introL, false);
    if (bed.stereo) {
      run(bed.loopR, true);
      run(bed.introR, false);
    }
  }
}

/// Reverb at half the sample rate (the tail is damped above sr/4 anyway):
/// half the cost, returned at the full rate.
(Float64List, Float64List) halfRateReverb(Float64List send, int sr, ReverbSpec room) {
  final n = send.length;
  final h = (n + 1) >> 1;
  final dec = Float64List(h);
  final aa = OnePole(sr, sr * 0.2);
  for (var j = 0; j < h; j++) {
    final a = aa.lp(send[2 * j]);
    final b = 2 * j + 1 < n ? aa.lp(send[2 * j + 1]) : a;
    dec[j] = 0.5 * (a + b);
  }
  final wl = Float64List(h), wr = Float64List(h);
  Reverb(sr ~/ 2, room).process(dec, wl, wr);
  final ol = Float64List(n), or = Float64List(n);
  for (var i = 0; i < n; i++) {
    final j = i >> 1;
    if (i.isEven) {
      ol[i] = wl[j];
      or[i] = wr[j];
    } else {
      final k = j + 1 < h ? j + 1 : j;
      ol[i] = 0.5 * (wl[j] + wl[k]);
      or[i] = 0.5 * (wr[j] + wr[k]);
    }
  }
  return (ol, or);
}

/// Fast PCM16 WAV encoder (canonical 44-byte header, TPDF dither from an
/// inline xorshift so the output is identical on every platform).
Uint8List encodeWav16(List<Float64List> channels, int sampleRate, {int seed = 1, int? frames}) {
  final ch = channels.length;
  final n = frames ?? channels.first.length;
  final dataBytes = n * ch * 2;
  final bytes = Uint8List(44 + dataBytes);
  final bd = ByteData.sublistView(bytes);
  void ascii(int o, String s) {
    for (var i = 0; i < 4; i++) {
      bytes[o + i] = s.codeUnitAt(i);
    }
  }

  ascii(0, 'RIFF');
  bd.setUint32(4, 36 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little);
  bd.setUint16(22, ch, Endian.little);
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * ch * 2, Endian.little);
  bd.setUint16(32, ch * 2, Endian.little);
  bd.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  bd.setUint32(40, dataBytes, Endian.little);
  final little = Endian.host == Endian.little;
  final pcm = little ? Int16List.view(bytes.buffer, 44, n * ch) : Int16List(n * ch);
  var x = (seed * 0x9E3779B1 + 0x6D2B79F5) & 0xFFFFFFFF;
  if (x == 0) x = 1;
  const lsb = 1.0 / 32768.0 / 4294967296.0;
  for (var c = 0; c < ch; c++) {
    final src = channels[c];
    var o = c;
    for (var i = 0; i < n; i++) {
      x ^= (x << 13) & 0xFFFFFFFF;
      x ^= x >> 17;
      x ^= (x << 5) & 0xFFFFFFFF;
      final r1 = x;
      x ^= (x << 13) & 0xFFFFFFFF;
      x ^= x >> 17;
      x ^= (x << 5) & 0xFFFFFFFF;
      final v = src[i] + (r1 - x) * lsb;
      var q = (v * 32767.0).round();
      if (q > 32767) {
        q = 32767;
      } else if (q < -32768) {
        q = -32768;
      }
      pcm[o] = q;
      o += ch;
    }
  }
  if (!little) {
    for (var i = 0; i < pcm.length; i++) {
      bd.setInt16(44 + i * 2, pcm[i], Endian.little);
    }
  }
  return bytes;
}

/// Renders short one-shots (stingers) made of several [parts] that play
/// together (e.g. a tonal part the director transposes and a drum part it
/// does not). All parts share one gain so their balance is kept; the sum
/// hits [loudnessDb] (momentary, speaker-weighted) under a −1.5 dBFS peak.
List<Uint8List> renderParts(
  List<List<NoteEvent>> parts, {
  required MusicStyle style,
  required double bpm,
  required CueSound sound,
  double loudnessDb = -16,
  int seed = 1,
  double maxSeconds = 4,
  List<int>? measure,
}) {
  final sr = sound.sampleRate;
  final n = (maxSeconds * sr).round();
  final voices = VoiceBox(sr, style, seed);
  final spb = 60.0 / bpm;
  final bufs = <Float64List>[];
  final room = ReverbSpec(roomSize: sound.roomSize, damping: sound.damping, preDelayMs: 10, width: 0.8);
  for (final part in parts) {
    final x = Float64List(n);
    for (final e in part) {
      final v = voices.render(e, math.max(0.02, e.dur * spb));
      final at = (e.beat * spb * sr).round();
      final m = math.min(v.length, n - at);
      final g = math.pow(10.0, instTrimDb(e.inst) / 20.0).toDouble() * e.gain;
      for (var i = 0; i < m; i++) {
        x[at + i] += v[i] * g;
      }
    }
    if (sound.wet > 0) {
      final send = Float64List(n);
      for (var i = 0; i < n; i++) {
        send[i] = x[i] * sound.wet;
      }
      final (wl, wr) = halfRateReverb(send, sr, room);
      for (var i = 0; i < n; i++) {
        x[i] += 0.5 * (wl[i] + wr[i]);
      }
    }
    final lofi = sound.lofi;
    Biquad(BiquadType.highPass, frequency: 30 + 140 * lofi, sampleRate: sr, q: 0.6).processBuffer(x);
    final lp = 16000 * math.pow(0.24, lofi).toDouble();
    if (lp < sr * 0.42) Biquad(BiquadType.lowPass, frequency: lp, sampleRate: sr, q: 0.6).processBuffer(x);
    bufs.add(x);
  }
  // Shared level, measured on the parts that sound together.
  final sum = Float64List(n);
  for (final k in measure ?? [for (var i = 0; i < bufs.length; i++) i]) {
    final b = bufs[k];
    for (var i = 0; i < n; i++) {
      sum[i] += b[i];
    }
  }
  final loud = Loudness.momentaryDb(StereoBuffer.fromChannels(sr, sum, sum));
  var g = loud.isFinite ? math.pow(10.0, (loudnessDb - loud) / 20.0).toDouble() : 1.0;
  var pk = 0.0;
  for (final v in sum) {
    if (v.abs() > pk) pk = v.abs();
  }
  final ceiling = math.pow(10.0, -1.5 / 20.0).toDouble();
  if (pk * g > ceiling) g = ceiling / pk;
  // Common length: until the sum falls 50 dB under its peak.
  var end = n;
  final thr = pk * g * 0.00316;
  while (end > 1 && (sum[end - 1] * g).abs() < thr) {
    end--;
  }
  end = math.min(n, end + (0.01 * sr).round());
  final out = <Uint8List>[];
  for (var k = 0; k < bufs.length; k++) {
    final b = Float64List(end);
    for (var i = 0; i < end; i++) {
      b[i] = bufs[k][i] * g;
    }
    fadeEdges(b, 4, math.min(end ~/ 4, (0.04 * sr).round()));
    out.add(encodeWav16([b], sr, seed: seed + k));
  }
  return out;
}
