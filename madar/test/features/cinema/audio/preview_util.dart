import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:madar/core/sound/synth/rng.dart';
import 'package:madar/core/sound/synth/wav.dart';
import 'package:madar/features/cinema/engine/audio/music/score.dart';
import 'package:madar/features/cinema/engine/audio/synth/renderer.dart';

import 'audio_analysis.dart';

/// Mixes a rendered cue as a listener would hear it: the intro, then the
/// loop [loops] times, every stem at its layer gain for [intensity].
Pcm mixdown(RenderedCue cue, {int loops = 2, double intensity = 1}) {
  final sr = cue.info.sampleRate;
  final introN = (cue.info.introSeconds * sr).round();
  final loopN = (cue.info.loopSeconds * sr).round();
  final total = introN + loopN * loops;
  final l = Float64List(total), r = Float64List(total);
  for (final s in cue.stems) {
    final g = s.spec.gain * s.spec.layerGain(intensity);
    if (g <= 0) continue;
    final a = (s.spec.pan + 1) * math.pi / 4;
    final gl = math.cos(a) * g, gr = math.sin(a) * g;
    void add(Pcm p, int at) {
      final st = p.channels.length == 2;
      for (var i = 0; i < p.frames && at + i < total; i++) {
        l[at + i] += (st ? p.channels[0][i] * g : p.channels[0][i] * gl);
        r[at + i] += (st ? p.channels[1][i] * g : p.channels[0][i] * gr);
      }
    }

    if (s.intro != null) add(Pcm.decode(s.intro!), 0);
    final loop = Pcm.decode(s.loop);
    for (var k = 0; k < loops; k++) {
      add(loop, introN + k * loopN);
    }
  }
  return Pcm(sr, [l, r]);
}

void writePreview(String name, Pcm p) {
  final bytes = Wav.encodePcm16(p.channels, sampleRate: p.sampleRate, dither: SynthRandom(3));
  File('${previewDir().path}/$name.wav').writeAsBytesSync(bytes);
}

/// Writes a log-frequency spectrogram (50 Hz – 8 kHz, dB colour) of [p] as a
/// PNG so the arrangement can be inspected visually.
void writeSpectrogram(String name, Pcm p, {double seconds = 12, int width = 1200, int height = 300}) {
  final x = p.mono;
  final sr = p.sampleRate;
  final n = math.min(x.length, (seconds * sr).round());
  const size = 2048;
  final hop = math.max(1, (n - size) ~/ width);
  final img = Uint8List(width * height * 3);
  final win = Float64List(size);
  for (var i = 0; i < size; i++) {
    win[i] = 0.5 - 0.5 * math.cos(2 * math.pi * i / (size - 1));
  }
  final re = Float64List(size), im = Float64List(size);
  final fMin = 50.0, fMax = math.min(8000.0, sr / 2);
  for (var col = 0; col < width; col++) {
    final s = col * hop;
    if (s + size > x.length) break;
    for (var i = 0; i < size; i++) {
      re[i] = x[s + i] * win[i];
      im[i] = 0;
    }
    fftInPlace(re, im);
    for (var row = 0; row < height; row++) {
      final f = fMin * math.pow(fMax / fMin, 1 - row / (height - 1));
      final k = (f * size / sr).round().clamp(1, size ~/ 2 - 1);
      final mag = math.sqrt(re[k] * re[k] + im[k] * im[k]) / (size / 4);
      final db = toDb(mag);
      final t = ((db + 90) / 80).clamp(0.0, 1.0);
      final o = (row * width + col) * 3;
      img[o] = (255 * math.min(1.0, t * 1.6)).round();
      img[o + 1] = (255 * math.max(0.0, t * 1.6 - 0.6)).round();
      img[o + 2] = (255 * math.max(0.0, 0.5 - t) * t * 4).round().clamp(0, 255);
    }
  }
  File('${previewDir().path}/$name.png').writeAsBytesSync(encodePng(width, height, img));
}

/// Minimal RGB PNG encoder.
Uint8List encodePng(int w, int h, Uint8List rgb) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    raw.add(Uint8List.sublistView(rgb, y * w * 3, (y + 1) * w * 3));
  }
  final out = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    final len = ByteData(4)..setUint32(0, data.length);
    out.add(len.buffer.asUint8List());
    final td = [...type.codeUnits, ...data];
    out.add(td);
    final crc = ByteData(4)..setUint32(0, _crc32(td));
    out.add(crc.buffer.asUint8List());
  }

  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8)
    ..setUint8(9, 2)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  chunk('IHDR', ihdr.buffer.asUint8List());
  chunk('IDAT', ZLibCodec().encode(raw.toBytes()));
  chunk('IEND', const []);
  return out.toBytes();
}

int _crc32(List<int> data) {
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}

/// Piano roll of a composed cue (x = beats, y = pitch 24–100; bar lines
/// grey, the loop start red; one colour per stem, drums as ticks at the
/// bottom).
void writePianoRoll(String name, CueScore s, {int pxPerBeat = 18, int pxPerSemi = 5}) {
  final beats = (s.introBeats + s.loopBeats).ceil();
  final w = beats * pxPerBeat + 1;
  const lo = 24, hi = 100;
  final h = (hi - lo) * pxPerSemi + 40;
  final img = Uint8List(w * h * 3)..fillRange(0, w * h * 3, 18);
  void px(int x, int y, List<int> c) {
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final o = (y * w + x) * 3;
    img[o] = c[0];
    img[o + 1] = c[1];
    img[o + 2] = c[2];
  }

  for (var b = 0; b <= beats; b++) {
    final isBar = b % s.beatsPerBar == 0;
    final c = b == s.introBeats.round() ? [200, 40, 40] : (isBar ? [70, 70, 70] : [34, 34, 34]);
    for (var y = 0; y < h; y++) {
      px(b * pxPerBeat, y, c);
    }
  }
  // C lines.
  for (var p = lo; p <= hi; p += 12) {
    final y = (hi - p) * pxPerSemi;
    for (var x = 0; x < w; x += 2) {
      px(x, y, [45, 45, 60]);
    }
  }
  const colours = [
    [90, 170, 255],
    [255, 200, 60],
    [120, 230, 120],
    [240, 110, 200],
  ];
  for (final e in s.events) {
    final c = colours[e.stem % colours.length];
    final x0 = (e.beat * pxPerBeat).round();
    if (e.inst.isDrum && e.inst != Inst.timpani) {
      final lane = h - 36 + (e.inst.index % 8) * 4;
      for (var x = x0; x < x0 + 3; x++) {
        for (var y = lane; y < lane + 3; y++) {
          px(x, y, c);
        }
      }
      continue;
    }
    final x1 = math.max(x0 + 2, ((e.beat + e.dur) * pxPerBeat).round());
    final y0 = ((hi - e.pitch) * pxPerSemi).round();
    final shade = 0.45 + 0.55 * e.vel;
    for (var x = x0; x < x1; x++) {
      for (var y = y0 - pxPerSemi ~/ 2; y < y0 + pxPerSemi ~/ 2; y++) {
        px(x, y, [for (final v in c) (v * shade).round()]);
      }
    }
  }
  File('${previewDir().path}/$name.roll.png').writeAsBytesSync(encodePng(w, h, img));
}
