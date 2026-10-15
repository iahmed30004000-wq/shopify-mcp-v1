import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/synth/synth.dart';

String _ascii(Uint8List b, int o) => String.fromCharCodes(b.sublist(o, o + 4));

void main() {
  group('Wav.encodePcm16', () {
    test('writes a canonical 44-byte stereo PCM16 header', () {
      final l = Float64List(1000);
      final r = Float64List(1000);
      final bytes = Wav.encodePcm16([l, r], sampleRate: 44100);
      final bd = ByteData.sublistView(bytes);

      expect(bytes.length, 44 + 1000 * 2 * 2);
      expect(_ascii(bytes, 0), 'RIFF');
      expect(bd.getUint32(4, Endian.little), bytes.length - 8);
      expect(_ascii(bytes, 8), 'WAVE');
      expect(_ascii(bytes, 12), 'fmt ');
      expect(bd.getUint32(16, Endian.little), 16);
      expect(bd.getUint16(20, Endian.little), 1, reason: 'PCM');
      expect(bd.getUint16(22, Endian.little), 2, reason: 'channels');
      expect(bd.getUint32(24, Endian.little), 44100);
      expect(bd.getUint32(28, Endian.little), 44100 * 4, reason: 'byte rate');
      expect(bd.getUint16(32, Endian.little), 4, reason: 'block align');
      expect(bd.getUint16(34, Endian.little), 16, reason: 'bits');
      expect(_ascii(bytes, 36), 'data');
      expect(bd.getUint32(40, Endian.little), 4000);
    });

    test('mono header and length', () {
      final bytes = Wav.encodePcm16([Float64List(777)], sampleRate: 24000);
      final info = Wav.parse(bytes);
      expect(info.channels, 1);
      expect(info.sampleRate, 24000);
      expect(info.bitsPerSample, 16);
      expect(info.frames, 777);
      expect(bytes.length, 44 + 777 * 2);
      expect(info.duration.inMicroseconds, closeTo(777 / 24000 * 1e6, 1));
    });

    test('round-trips samples within one LSB and interleaves channels', () {
      final l = Float64List.fromList([0, 0.5, -0.5, 0.25, -1.0]);
      final r = Float64List.fromList([0.1, -0.1, 0.9, -0.9, 0.0]);
      final bytes = Wav.encodePcm16([l, r], sampleRate: 8000);
      final dl = Wav.decodeChannel(bytes, 0);
      final dr = Wav.decodeChannel(bytes, 1);
      for (var i = 0; i < l.length; i++) {
        expect(dl[i], closeTo(l[i], 0.5 / 32767 + 1e-9));
        expect(dr[i], closeTo(r[i], 0.5 / 32767 + 1e-9));
      }
    });

    test('clamps out-of-range samples instead of wrapping', () {
      final bytes = Wav.encodePcm16([Float64List.fromList([2.0, -3.0])], sampleRate: 8000);
      final d = Wav.decodeChannel(bytes, 0);
      expect(d[0], 1.0);
      expect(d[1], -1.0);
    });

    test('dither is deterministic for a given seed', () {
      final x = Float64List.fromList(List.generate(500, (i) => i / 5000));
      final a = Wav.encodePcm16([x], sampleRate: 8000, dither: SynthRandom(3));
      final b = Wav.encodePcm16([x], sampleRate: 8000, dither: SynthRandom(3));
      expect(a, b);
    });

    test('rejects invalid channel counts', () {
      expect(() => Wav.encodePcm16([], sampleRate: 8000), throwsArgumentError);
      expect(
        () => Wav.encodePcm16([Float64List(1), Float64List(1), Float64List(1)], sampleRate: 8000),
        throwsArgumentError,
      );
    });
  });

  group('Wav.parse', () {
    test('rejects truncated or foreign data', () {
      final good = Wav.encodePcm16([Float64List(10)], sampleRate: 8000);
      expect(() => Wav.parse(Uint8List(10)), throwsFormatException);
      expect(() => Wav.parse(Uint8List.fromList(good.sublist(0, good.length - 2))), throwsFormatException);
      final bad = Uint8List.fromList(good)..[0] = 0x58; // 'XIFF'
      expect(() => Wav.parse(bad), throwsFormatException);
    });
  });
}
