import 'dart:math' as math;
import 'dart:typed_data';

import 'rng.dart';

/// Parsed canonical RIFF/WAVE header (PCM only).
final class WavInfo {
  const WavInfo({
    required this.channels,
    required this.sampleRate,
    required this.bitsPerSample,
    required this.frames,
    required this.dataOffset,
  });

  final int channels;
  final int sampleRate;
  final int bitsPerSample;
  final int frames;

  /// Byte offset of the first sample in the file.
  final int dataOffset;

  Duration get duration => Duration(microseconds: (frames * 1000000 / sampleRate).round());
}

/// Minimal PCM16 WAV encoder/decoder.
///
/// flutter_soloud loads these bytes straight from memory (`loadMem`), so the
/// header must be byte-exact: 44-byte canonical header, little endian.
abstract final class Wav {
  static const int headerBytes = 44;

  /// Encodes one (mono) or two (stereo) channels of float samples in
  /// `[-1, 1]` as 16-bit PCM. Samples are clamped; when [dither] is given a
  /// ±1 LSB triangular (TPDF) dither decorrelates quantisation from the
  /// signal so long reverb tails fade out smoothly instead of "crunching".
  static Uint8List encodePcm16(
    List<Float64List> channels, {
    required int sampleRate,
    SynthRandom? dither,
    int? frames,
  }) {
    if (channels.isEmpty || channels.length > 2) {
      throw ArgumentError.value(channels.length, 'channels', 'must be 1 or 2');
    }
    final n = frames ?? channels.first.length;
    for (final c in channels) {
      if (c.length < n) throw ArgumentError('channel shorter than $n frames');
    }
    final ch = channels.length;
    final dataBytes = n * ch * 2;
    final bytes = Uint8List(headerBytes + dataBytes);
    final bd = ByteData.sublistView(bytes);
    _writeAscii(bytes, 0, 'RIFF');
    bd.setUint32(4, 36 + dataBytes, Endian.little);
    _writeAscii(bytes, 8, 'WAVE');
    _writeAscii(bytes, 12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // PCM fmt chunk size
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, ch, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, sampleRate * ch * 2, Endian.little); // byte rate
    bd.setUint16(32, ch * 2, Endian.little); // block align
    bd.setUint16(34, 16, Endian.little); // bits per sample
    _writeAscii(bytes, 36, 'data');
    bd.setUint32(40, dataBytes, Endian.little);

    final pcm = Int16List(n * ch);
    const scale = 32767.0;
    const lsb = 1.0 / 32768.0;
    for (var c = 0; c < ch; c++) {
      final src = channels[c];
      var o = c;
      for (var i = 0; i < n; i++) {
        var x = src[i];
        if (dither != null) x += (dither.nextDouble() - dither.nextDouble()) * lsb;
        var s = (x * scale).round();
        if (s > 32767) {
          s = 32767;
        } else if (s < -32768) {
          s = -32768;
        }
        pcm[o] = s;
        o += ch;
      }
    }
    // Int16List uses host endianness; every Android ABI is little endian, but
    // write explicitly so the output is identical everywhere.
    var p = headerBytes;
    for (var i = 0; i < pcm.length; i++) {
      bd.setInt16(p, pcm[i], Endian.little);
      p += 2;
    }
    return bytes;
  }

  /// Parses and validates a canonical PCM header. Throws [FormatException]
  /// when [bytes] are not a PCM WAV file this encoder could have produced.
  static WavInfo parse(Uint8List bytes) {
    if (bytes.length < headerBytes) throw const FormatException('WAV too short');
    final bd = ByteData.sublistView(bytes);
    String ascii(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
    if (ascii(0) != 'RIFF' || ascii(8) != 'WAVE' || ascii(12) != 'fmt ' || ascii(36) != 'data') {
      throw const FormatException('Not a canonical RIFF/WAVE file');
    }
    final riffSize = bd.getUint32(4, Endian.little);
    if (riffSize != bytes.length - 8) throw const FormatException('RIFF size mismatch');
    if (bd.getUint16(20, Endian.little) != 1) throw const FormatException('Not PCM');
    final ch = bd.getUint16(22, Endian.little);
    final sr = bd.getUint32(24, Endian.little);
    final bits = bd.getUint16(34, Endian.little);
    final blockAlign = bd.getUint16(32, Endian.little);
    if (blockAlign != ch * bits ~/ 8) throw const FormatException('Bad block align');
    if (bd.getUint32(28, Endian.little) != sr * blockAlign) throw const FormatException('Bad byte rate');
    final dataBytes = bd.getUint32(40, Endian.little);
    if (dataBytes != bytes.length - headerBytes) throw const FormatException('Data size mismatch');
    return WavInfo(
      channels: ch,
      sampleRate: sr,
      bitsPerSample: bits,
      frames: dataBytes ~/ blockAlign,
      dataOffset: headerBytes,
    );
  }

  /// Decodes PCM16 samples of [channel] back to floats (tests, analysis).
  static Float64List decodeChannel(Uint8List bytes, int channel) {
    final info = parse(bytes);
    final bd = ByteData.sublistView(bytes);
    final out = Float64List(info.frames);
    final stride = info.channels * 2;
    var p = info.dataOffset + channel * 2;
    for (var i = 0; i < info.frames; i++) {
      out[i] = math.max(-1.0, bd.getInt16(p, Endian.little) / 32767.0);
      p += stride;
    }
    return out;
  }

  static void _writeAscii(Uint8List b, int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      b[offset + i] = s.codeUnitAt(i);
    }
  }
}
