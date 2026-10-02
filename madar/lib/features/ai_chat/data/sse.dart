/// Server-sent events (the `text/event-stream` format both AI services
/// stream replies in): bytes → events.
library;

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

@immutable
class SseEvent {
  const SseEvent({this.event, required this.data, this.id});

  /// The `event:` field (null when the stream doesn't name events).
  final String? event;

  /// The `data:` lines joined with '\n'.
  final String data;
  final String? id;

  @override
  bool operator ==(Object other) => other is SseEvent && other.event == event && other.data == data && other.id == id;

  @override
  int get hashCode => Object.hash(event, data, id);

  @override
  String toString() => 'SseEvent(${event ?? 'message'}, ${data.length} chars)';
}

/// Decodes a UTF-8 byte stream of server-sent events. Handles CRLF / LF /
/// CR line ends, multi-line data, comments (`: ping`) and events split
/// anywhere across network chunks (even inside a multi-byte character).
///
/// Cancelling the subscription cancels [bytes] at once – also while the
/// stream is idle (which an `async*` generator would not do).
Stream<SseEvent> decodeSse(Stream<List<int>> bytes) {
  final lines = bytes.transform(const Utf8Decoder(allowMalformed: true)).transform(const LineSplitter());
  StreamSubscription<String>? sub;
  late final StreamController<SseEvent> out;
  String? event;
  String? id;
  final data = <String>[];
  var hasData = false;

  void dispatch() {
    if (hasData) out.add(SseEvent(event: event, data: data.join('\n'), id: id));
    event = null;
    data.clear();
    hasData = false;
  }

  void onLine(String line) {
    if (line.isEmpty) {
      dispatch();
      return;
    }
    if (line.startsWith(':')) return; // comment / keep-alive
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        event = value;
      case 'data':
        data.add(value);
        hasData = true;
      case 'id':
        id = value;
    }
  }

  out = StreamController<SseEvent>(
    onListen: () {
      sub = lines.listen(
        onLine,
        onError: out.addError,
        onDone: () {
          dispatch(); // a last event without its blank line
          out.close();
        },
      );
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () {
      final s = sub;
      sub = null;
      return s?.cancel();
    },
  );
  return out.stream;
}
