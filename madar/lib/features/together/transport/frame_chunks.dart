/// Splitting a frame across Nearby payloads and putting it back together.
///
/// A Nearby BYTES payload holds at most 32 KiB, a Together frame up to
/// [TogetherProtocol.maxFrameBytes]. A frame is sent as its UTF-8 bytes cut
/// into payloads of exactly the payload size; the first shorter payload ends
/// it. A frame whose length is an exact multiple of the payload size ends
/// with one space – JSON whitespace, so the payloads still carry nothing but
/// the frame's JSON: no header, no framing bytes.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../protocol/envelope.dart';

abstract final class FrameChunks {
  /// The largest Nearby BYTES payload (`ConnectionsClient.MAX_BYTES_DATA_SIZE`).
  static const int nearbyMaxPayload = 32 * 1024;

  /// Cuts [bytes] into payloads of at most [max] bytes (see the library
  /// comment for the rule that ends a frame).
  static List<Uint8List> split(List<int> bytes, int max) {
    if (max < 2) throw ArgumentError.value(max, 'max');
    final out = <Uint8List>[];
    var i = 0;
    while (bytes.length - i >= max) {
      out.add(Uint8List.fromList(bytes.sublist(i, i + max)));
      i += max;
    }
    out.add(i < bytes.length ? Uint8List.fromList(bytes.sublist(i)) : Uint8List.fromList(const [0x20]));
    return out;
  }

  /// Every payload of [text].
  static List<Uint8List> ofText(String text, int max) => split(utf8.encode(text), max);
}

/// Collects payloads until a frame is complete.
class FrameReassembler {
  FrameReassembler({
    this.chunkSize = FrameChunks.nearbyMaxPayload,
    this.maxFrameBytes = TogetherProtocol.maxFrameBytes,
  });

  final int chunkSize;

  /// Anything longer is not a Together frame: dropped.
  final int maxFrameBytes;

  final BytesBuilder _buffer = BytesBuilder();

  /// Bytes waiting for the end of a frame.
  int get pending => _buffer.length;

  /// Adds one payload; returns the frame's text when it completes it, null
  /// while more is expected or when the bytes are not a valid frame (too
  /// long, not UTF-8) – those are dropped and the session's sync recovers.
  String? add(Uint8List payload) {
    if (payload.isEmpty || payload.length > chunkSize) {
      reset();
      return null;
    }
    _buffer.add(payload);
    if (_buffer.length > maxFrameBytes + 1) {
      reset();
      return null;
    }
    if (payload.length == chunkSize) return null;
    final bytes = _buffer.takeBytes();
    try {
      return utf8.decode(bytes).trimRight();
    } on FormatException {
      return null;
    }
  }

  void reset() => _buffer.clear();
}
