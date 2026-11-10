import 'dart:typed_data';

/// Audio formats the player (flutter_soloud / miniaudio, built without the
/// Ogg/Opus libraries) can decode.
enum DhikrAudioFormat {
  mp3('mp3'),
  wav('wav'),
  flac('flac');

  const DhikrAudioFormat(this.extension);

  final String extension;

  static const List<String> extensions = ['mp3', 'wav', 'flac'];
}

/// Reads the format and length of an audio file from its bytes (no
/// decoding). Pure Dart.
abstract final class AudioProbe {
  /// The format by its magic bytes, or null when it is not a supported one.
  static DhikrAudioFormat? sniff(Uint8List b) {
    if (b.length < 12) return null;
    if (_ascii(b, 0, 'RIFF') && _ascii(b, 8, 'WAVE')) return DhikrAudioFormat.wav;
    if (_ascii(b, 0, 'fLaC')) return DhikrAudioFormat.flac;
    if (_ascii(b, 0, 'ID3')) return DhikrAudioFormat.mp3;
    final start = _mp3FrameStart(b, 0);
    return start == null ? null : DhikrAudioFormat.mp3;
  }

  /// The playing time, or null when it cannot be read from the headers.
  static Duration? duration(Uint8List b) => switch (sniff(b)) {
    DhikrAudioFormat.wav => _wav(b),
    DhikrAudioFormat.flac => _flac(b),
    DhikrAudioFormat.mp3 => _mp3(b),
    null => null,
  };

  static bool _ascii(Uint8List b, int at, String s) {
    if (at + s.length > b.length) return false;
    for (var i = 0; i < s.length; i++) {
      if (b[at + i] != s.codeUnitAt(i)) return false;
    }
    return true;
  }

  static int _u32le(Uint8List b, int at) => b[at] | (b[at + 1] << 8) | (b[at + 2] << 16) | (b[at + 3] << 24);

  static int _u32be(Uint8List b, int at) => (b[at] << 24) | (b[at + 1] << 16) | (b[at + 2] << 8) | b[at + 3];

  static Duration? _micros(double seconds) =>
      seconds.isFinite && seconds > 0 ? Duration(microseconds: (seconds * 1e6).round()) : null;

  // ------------------------------------------------------------------ WAV --
  static Duration? _wav(Uint8List b) {
    var at = 12;
    int? byteRate;
    while (at + 8 <= b.length) {
      final size = _u32le(b, at + 4);
      if (_ascii(b, at, 'fmt ') && at + 16 <= b.length) {
        byteRate = _u32le(b, at + 16);
      } else if (_ascii(b, at, 'data')) {
        if (byteRate == null || byteRate == 0) return null;
        // Streams written without a final size carry 0 or 0xFFFFFFFF.
        final dataSize = size == 0 || size == 0xFFFFFFFF ? b.length - at - 8 : size;
        return _micros(dataSize / byteRate);
      }
      at += 8 + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  // ----------------------------------------------------------------- FLAC --
  static Duration? _flac(Uint8List b) {
    // The first metadata block is STREAMINFO (34 bytes after its header).
    const s = 8; // "fLaC" + 4-byte block header
    if (b.length < s + 18 || (b[4] & 0x7F) != 0) return null;
    final sampleRate = (b[s + 10] << 12) | (b[s + 11] << 4) | (b[s + 12] >> 4);
    final totalSamples = ((b[s + 13] & 0x0F) * 4294967296) + _u32be(b, s + 14);
    if (sampleRate == 0 || totalSamples == 0) return null;
    return _micros(totalSamples / sampleRate);
  }

  // ------------------------------------------------------------------ MP3 --
  static const _bitratesV1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
  static const _bitratesV2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
  static const _rates = {
    3: [44100, 48000, 32000], // MPEG 1
    2: [22050, 24000, 16000], // MPEG 2
    0: [11025, 12000, 8000], // MPEG 2.5
  };

  static int _id3Size(Uint8List b) {
    if (!_ascii(b, 0, 'ID3') || b.length < 10) return 0;
    final size = (b[6] << 21) | (b[7] << 14) | (b[8] << 7) | b[9];
    final footer = (b[5] & 0x10) != 0 ? 10 : 0;
    return 10 + size + footer;
  }

  static int? _mp3FrameStart(Uint8List b, int from) {
    final end = b.length - 4;
    for (var i = from; i < end && i < from + 65536; i++) {
      if (b[i] == 0xFF && (b[i + 1] & 0xE0) == 0xE0 && _header(b, i) != null) return i;
    }
    return null;
  }

  static ({int version, int bitrate, int sampleRate, bool mono})? _header(Uint8List b, int at) {
    final version = (b[at + 1] >> 3) & 3;
    final layer = (b[at + 1] >> 1) & 3;
    final bitrateIndex = b[at + 2] >> 4;
    final rateIndex = (b[at + 2] >> 2) & 3;
    if (version == 1 || layer != 1 || bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) return null;
    final bitrate = (version == 3 ? _bitratesV1 : _bitratesV2)[bitrateIndex] * 1000;
    return (version: version, bitrate: bitrate, sampleRate: _rates[version]![rateIndex], mono: (b[at + 3] >> 6) == 3);
  }

  static Duration? _mp3(Uint8List b) {
    final start = _mp3FrameStart(b, _id3Size(b).clamp(0, b.length));
    if (start == null) return null;
    final h = _header(b, start)!;
    final samplesPerFrame = h.version == 3 ? 1152 : 576;
    final sideInfo = h.version == 3 ? (h.mono ? 17 : 32) : (h.mono ? 9 : 17);
    final xing = start + 4 + sideInfo;
    if (xing + 12 <= b.length && (_ascii(b, xing, 'Xing') || _ascii(b, xing, 'Info'))) {
      final flags = _u32be(b, xing + 4);
      if (flags & 1 != 0) return _micros(_u32be(b, xing + 8) * samplesPerFrame / h.sampleRate);
    }
    final vbri = start + 4 + 32;
    if (vbri + 18 <= b.length && _ascii(b, vbri, 'VBRI')) {
      return _micros(_u32be(b, vbri + 14) * samplesPerFrame / h.sampleRate);
    }
    // Constant bit rate: the audio bytes over the bit rate.
    return _micros((b.length - start) * 8 / h.bitrate);
  }
}
