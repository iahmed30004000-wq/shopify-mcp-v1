import 'dart:typed_data';

/// Reads the playing time of an audio file from its headers – WAV, MP3
/// (Xing / Info / VBRI or a frame walk), Ogg Vorbis / Opus, FLAC and
/// MP4 / M4A. Pure Dart; returns null for anything it cannot read (the adhan
/// screen then assumes a typical adhan length).
abstract final class AudioLength {
  static Duration? of(Uint8List bytes, {String? extension}) {
    if (bytes.length < 12) return null;
    try {
      if (_ascii(bytes, 0, 4) == 'RIFF' && _ascii(bytes, 8, 4) == 'WAVE') return _wav(bytes);
      if (_ascii(bytes, 0, 4) == 'fLaC') return _flac(bytes);
      if (_ascii(bytes, 0, 4) == 'OggS') return _ogg(bytes);
      if (_ascii(bytes, 4, 4) == 'ftyp') return _mp4(bytes);
      if (_ascii(bytes, 0, 3) == 'ID3' || _isMp3Sync(bytes, 0)) return _mp3(bytes);
    } on RangeError {
      return null;
    }
    return null;
  }

  static String _ascii(Uint8List b, int o, int n) {
    if (o + n > b.length) return '';
    return String.fromCharCodes(b.sublist(o, o + n));
  }

  static Duration _secs(num s) => Duration(microseconds: (s * 1e6).round());

  // WAV ---------------------------------------------------------------------

  static Duration? _wav(Uint8List b) {
    final bd = ByteData.sublistView(b);
    var p = 12;
    int? byteRate;
    while (p + 8 <= b.length) {
      final id = _ascii(b, p, 4);
      final size = bd.getUint32(p + 4, Endian.little);
      if (id == 'fmt ' && p + 16 <= b.length) byteRate = bd.getUint32(p + 8 + 8, Endian.little);
      if (id == 'data') {
        if (byteRate == null || byteRate == 0) return null;
        final available = b.length - (p + 8);
        return _secs((size > available ? available : size) / byteRate);
      }
      p += 8 + size + (size.isOdd ? 1 : 0);
    }
    return null;
  }

  // FLAC --------------------------------------------------------------------

  static Duration? _flac(Uint8List b) {
    // STREAMINFO is the first metadata block: 4-byte header, then
    // min/max block (2+2), min/max frame (3+3), then 20 bits sample rate,
    // 3 bits channels, 5 bits depth, 36 bits total samples.
    const o = 4 + 4 + 10;
    if (b.length < o + 8) return null;
    final rate = (b[o] << 12) | (b[o + 1] << 4) | (b[o + 2] >> 4);
    final total = ((b[o + 3] & 0x0f) << 32) | (b[o + 4] << 24) | (b[o + 5] << 16) | (b[o + 6] << 8) | b[o + 7];
    if (rate == 0 || total == 0) return null;
    return _secs(total / rate);
  }

  // Ogg ---------------------------------------------------------------------

  static Duration? _ogg(Uint8List b) {
    // Codec from the first packet (page header 27 bytes + segment table).
    final segments = b[26];
    final first = 27 + segments;
    int rate;
    var preSkip = 0;
    if (_ascii(b, first, 7) == '\x01vorbis') {
      rate = ByteData.sublistView(b).getUint32(first + 12, Endian.little);
    } else if (_ascii(b, first, 8) == 'OpusHead') {
      rate = 48000; // Opus granules always count 48 kHz samples.
      preSkip = ByteData.sublistView(b).getUint16(first + 10, Endian.little);
    } else {
      return null;
    }
    // The last page's granule position = total samples.
    for (var p = b.length - 27; p >= 0; p--) {
      if (b[p] == 0x4f && _ascii(b, p, 4) == 'OggS') {
        final granule = ByteData.sublistView(b).getInt64(p + 6, Endian.little);
        if (granule <= 0 || rate == 0) return null;
        return _secs((granule - preSkip) / rate);
      }
    }
    return null;
  }

  // MP4 / M4A -----------------------------------------------------------------

  static Duration? _mp4(Uint8List b) {
    final bd = ByteData.sublistView(b);
    Duration? walk(int start, int end) {
      var p = start;
      while (p + 8 <= end) {
        var size = bd.getUint32(p);
        final type = _ascii(b, p + 4, 4);
        var header = 8;
        if (size == 1) {
          size = bd.getUint64(p + 8);
          header = 16;
        } else if (size == 0) {
          size = end - p;
        }
        if (size < header || p + size > end) return null;
        if (type == 'moov') return walk(p + header, p + size);
        if (type == 'mvhd') {
          final v = b[p + header];
          final int timescale, duration;
          if (v == 1) {
            timescale = bd.getUint32(p + header + 4 + 16);
            duration = bd.getUint64(p + header + 4 + 20);
          } else {
            timescale = bd.getUint32(p + header + 4 + 8);
            duration = bd.getUint32(p + header + 4 + 12);
          }
          if (timescale == 0) return null;
          return _secs(duration / timescale);
        }
        p += size;
      }
      return null;
    }

    return walk(0, b.length);
  }

  // MP3 ---------------------------------------------------------------------

  static bool _isMp3Sync(Uint8List b, int p) =>
      p + 4 <= b.length && b[p] == 0xff && (b[p + 1] & 0xe0) == 0xe0 && _frame(b, p) != null;

  static const _bitrates = {
    // (mpeg1?, layer) → kbps by index 1..14
    'v1l1': [32, 64, 96, 128, 160, 192, 224, 256, 288, 320, 352, 384, 416, 448],
    'v1l2': [32, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 384],
    'v1l3': [32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320],
    'v2l1': [32, 48, 56, 64, 80, 96, 112, 128, 144, 160, 176, 192, 224, 256],
    'v2l23': [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160],
  };

  /// (frame length in bytes, samples per frame, sample rate, side-info
  /// size, is MPEG-1) of the frame header at [p], or null.
  static (int, int, int, int, bool)? _frame(Uint8List b, int p) {
    if (p + 4 > b.length || b[p] != 0xff || (b[p + 1] & 0xe0) != 0xe0) return null;
    final versionBits = (b[p + 1] >> 3) & 3; // 0: 2.5, 2: 2, 3: 1
    final layerBits = (b[p + 1] >> 1) & 3; // 1: III, 2: II, 3: I
    final bitrateIndex = b[p + 2] >> 4;
    final rateIndex = (b[p + 2] >> 2) & 3;
    final padding = (b[p + 2] >> 1) & 1;
    final mono = (b[p + 3] >> 6) == 3;
    if (versionBits == 1 || layerBits == 0 || bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) return null;
    final v1 = versionBits == 3;
    final layer = 4 - layerBits;
    final baseRates = [44100, 48000, 32000];
    final rate = baseRates[rateIndex] ~/ (v1 ? 1 : (versionBits == 2 ? 2 : 4));
    final table = v1 ? 'v1l$layer' : (layer == 1 ? 'v2l1' : 'v2l23');
    final kbps = _bitrates[table]![bitrateIndex - 1];
    final int samples;
    final int length;
    if (layer == 1) {
      samples = 384;
      length = (12 * kbps * 1000 ~/ rate + padding) * 4;
    } else {
      samples = (layer == 3 && !v1) ? 576 : 1152;
      length = samples ~/ 8 * kbps * 1000 ~/ rate + padding;
    }
    final side = v1 ? (mono ? 17 : 32) : (mono ? 9 : 17);
    if (length < 4) return null;
    return (length, samples, rate, side, v1);
  }

  static Duration? _mp3(Uint8List b) {
    var p = 0;
    if (_ascii(b, 0, 3) == 'ID3' && b.length > 10) {
      final size = (b[6] << 21) | (b[7] << 14) | (b[8] << 7) | b[9];
      p = 10 + size + ((b[5] & 0x10) != 0 ? 10 : 0);
    }
    // Find the first frame (tolerate junk after the tag).
    final limit = b.length < p + 65536 ? b.length : p + 65536;
    while (p < limit && !(_isMp3Sync(b, p) && _followedByFrame(b, p))) {
      p++;
    }
    final first = _frame(b, p);
    if (first == null) return null;
    final (_, samples, rate, side, _) = first;
    // Xing / Info (VBR) header in the first frame.
    final xing = p + 4 + side;
    final tag = _ascii(b, xing, 4);
    if ((tag == 'Xing' || tag == 'Info') && xing + 12 <= b.length) {
      final flags = ByteData.sublistView(b).getUint32(xing + 4);
      if (flags & 1 == 1) {
        final frames = ByteData.sublistView(b).getUint32(xing + 8);
        if (frames > 0) return _secs(frames * samples / rate);
      }
    }
    // VBRI header (Fraunhofer) at a fixed offset.
    if (_ascii(b, p + 36, 4) == 'VBRI' && p + 36 + 18 <= b.length) {
      final frames = ByteData.sublistView(b).getUint32(p + 36 + 14);
      if (frames > 0) return _secs(frames * samples / rate);
    }
    // Walk the frames.
    var frames = 0;
    var totalSamples = 0.0;
    while (true) {
      final f = _frame(b, p);
      if (f == null) break;
      final (length, s, r, _, _) = f;
      if (p + length > b.length) {
        if (b.length - p > length ~/ 2) {
          frames++;
          totalSamples += s / r;
        }
        break;
      }
      frames++;
      totalSamples += s / r;
      p += length;
    }
    return frames == 0 ? null : _secs(totalSamples);
  }

  static bool _followedByFrame(Uint8List b, int p) {
    final f = _frame(b, p);
    if (f == null) return false;
    final next = p + f.$1;
    return next + 4 > b.length || _frame(b, next) != null;
  }
}
