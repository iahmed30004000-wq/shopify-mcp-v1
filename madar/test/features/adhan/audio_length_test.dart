import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/synth/wav.dart';
import 'package:madar/features/adhan/domain/audio_length.dart';

Uint8List _bytes(List<int> b) => Uint8List.fromList(b);
List<int> _ascii(String s) => s.codeUnits;
List<int> _le32(int v) => [v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff];
List<int> _be32(int v) => [(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff];
List<int> _le64(int v) => [..._le32(v & 0xffffffff), ..._le32(v >> 32)];

/// MPEG-1 Layer III, 128 kbps, 44.1 kHz, stereo: 417-byte frames of 1152
/// samples.
List<int> _mp3Frame({List<int>? body}) {
  final f = List<int>.filled(417, 0);
  f.setAll(0, [0xff, 0xfb, 0x90, 0x00]);
  if (body != null) f.setAll(4, body);
  return f;
}

List<int> _oggPage(int granule, List<int> packet) => [
  ..._ascii('OggS'),
  0,
  2,
  ..._le64(granule),
  ..._le32(1),
  ..._le32(0),
  ..._le32(0),
  1,
  packet.length,
  ...packet,
];

void main() {
  Duration secs(double s) => Duration(microseconds: (s * 1e6).round());
  Matcher about(double seconds) => predicate<Duration?>(
    (d) => d != null && (d - secs(seconds)).abs() < const Duration(milliseconds: 5),
    '≈ $seconds s',
  );

  test('wav (canonical and with extra chunks)', () {
    final wav = Wav.encodePcm16([Float64List(22050 * 3)], sampleRate: 22050);
    expect(AudioLength.of(wav), about(3));
    // RIFF with a LIST chunk before data (common in exported files).
    final body = wav.sublist(44);
    final list = [..._ascii('LIST'), ..._le32(4), ..._ascii('INFO')];
    final fmt = wav.sublist(12, 36);
    final riff = [
      ..._ascii('RIFF'),
      ..._le32(4 + fmt.length + list.length + 8 + body.length),
      ..._ascii('WAVE'),
      ...fmt,
      ...list,
      ..._ascii('data'),
      ..._le32(body.length),
      ...body,
    ];
    expect(AudioLength.of(_bytes(riff)), about(3));
  });

  test('mp3 by walking frames, after an ID3 tag', () {
    final frames = [for (var i = 0; i < 100; i++) ..._mp3Frame()];
    expect(AudioLength.of(_bytes(frames)), about(100 * 1152 / 44100));
    final id3 = [..._ascii('ID3'), 4, 0, 0, 0, 0, 0, 20, ...List.filled(20, 0)];
    expect(AudioLength.of(_bytes([...id3, ...frames])), about(100 * 1152 / 44100));
  });

  test('mp3 with a Xing header (VBR)', () {
    final xing = [...List.filled(32, 0), ..._ascii('Xing'), ..._be32(1), ..._be32(500)];
    final bytes = [..._mp3Frame(body: xing), for (var i = 0; i < 3; i++) ..._mp3Frame()];
    expect(AudioLength.of(_bytes(bytes)), about(500 * 1152 / 44100));
  });

  test('ogg vorbis and opus', () {
    final vorbisId = [1, ..._ascii('vorbis'), ..._le32(0), 2, ..._le32(48000), ...List.filled(12, 0)];
    final vorbis = [
      ..._oggPage(0, vorbisId),
      ..._oggPage(480000, [0, 0, 0]),
    ];
    expect(AudioLength.of(_bytes(vorbis)), about(10));
    final opusHead = [..._ascii('OpusHead'), 1, 2, 312 & 0xff, 312 >> 8, ..._le32(48000), 0, 0, 0];
    final opus = [
      ..._oggPage(0, opusHead),
      ..._oggPage(48000 * 5 + 312, [0, 0]),
    ];
    expect(AudioLength.of(_bytes(opus)), about(5));
  });

  test('flac STREAMINFO', () {
    const rate = 44100, total = 441000;
    final info = [
      0, 16, 0, 16, 0, 0, 0, 0, 0, 0, // block sizes, frame sizes
      rate >> 12, (rate >> 4) & 0xff, ((rate & 0xf) << 4) | (1 << 1), (15 << 4) | ((total >> 32) & 0xf),
      ..._be32(total & 0xffffffff),
      ...List.filled(16, 0), // md5
    ];
    final flac = [..._ascii('fLaC'), 0x80, 0, 0, 34, ...info];
    expect(AudioLength.of(_bytes(flac)), about(10));
  });

  test('m4a (mvhd, version 0 and 1)', () {
    final ftyp = [..._be32(16), ..._ascii('ftyp'), ..._ascii('M4A '), ..._be32(0)];
    List<int> mvhd0(int timescale, int duration) {
      final body = [
        0,
        0,
        0,
        0,
        ..._be32(0),
        ..._be32(0),
        ..._be32(timescale),
        ..._be32(duration),
        ...List.filled(80, 0),
      ];
      return [..._be32(8 + body.length), ..._ascii('mvhd'), ...body];
    }

    final mvhd = mvhd0(1000, 183500);
    final moov = [..._be32(8 + mvhd.length), ..._ascii('moov'), ...mvhd];
    final mdat = [..._be32(16), ..._ascii('mdat'), ...List.filled(8, 0)];
    expect(AudioLength.of(_bytes([...ftyp, ...mdat, ...moov])), about(183.5));

    final body1 = [
      1,
      0,
      0,
      0,
      ...List.filled(16, 0),
      ..._be32(600),
      ...[0, 0, 0, 0],
      ..._be32(600 * 90),
      ...List.filled(80, 0),
    ];
    final mvhd1 = [..._be32(8 + body1.length), ..._ascii('mvhd'), ...body1];
    final moov1 = [..._be32(8 + mvhd1.length), ..._ascii('moov'), ...mvhd1];
    expect(AudioLength.of(_bytes([...ftyp, ...moov1])), about(90));
  });

  test('anything else is unknown, never a crash', () {
    expect(AudioLength.of(_bytes(List.filled(8, 1))), isNull);
    expect(AudioLength.of(_bytes(_ascii('hello there, not audio'))), isNull);
    expect(AudioLength.of(_bytes([..._ascii('RIFF'), ..._le32(4), ..._ascii('WAVE')])), isNull);
    expect(AudioLength.of(_bytes([..._ascii('OggS'), ...List.filled(40, 0)])), isNull);
    expect(() => AudioLength.of(_bytes([0xff, 0xfb, 0x90, 0x00, 1, 2])), returnsNormally);
  });
}
