import 'dart:async';
import 'dart:isolate';

import '../domain/search_doc.dart';
import '../domain/search_index.dart';

/// Where the index lives: a background isolate in the app
/// ([IsolateSearchWorker]), the calling isolate in widget tests
/// ([InlineSearchWorker]).
abstract interface class SearchWorker {
  Future<void> apply(SearchIndexDelta delta);
  Future<SearchIndexResult> search(SearchIndexQuery query);
  Future<SearchIndexStats> stats();
  Future<void> close();
}

/// Makes the worker (called once, on first use of the search).
typedef SearchWorkerFactory = Future<SearchWorker> Function();

/// The index on the calling isolate (tests, previews).
class InlineSearchWorker implements SearchWorker {
  InlineSearchWorker([SearchIndex? index]) : index = index ?? SearchIndex();

  final SearchIndex index;

  @override
  Future<void> apply(SearchIndexDelta delta) async => index.apply(delta);

  @override
  Future<SearchIndexResult> search(SearchIndexQuery query) async => index.search(query);

  @override
  Future<SearchIndexStats> stats() async => index.stats;

  @override
  Future<void> close() async => index.clear();
}

/// Thrown when the search isolate failed a request.
class SearchWorkerException implements Exception {
  SearchWorkerException(this.message);

  final String message;

  @override
  String toString() => 'SearchWorkerException: $message';
}

/// The index on its own isolate: building it and answering queries never
/// block the UI. Requests are answered in order.
class IsolateSearchWorker implements SearchWorker {
  IsolateSearchWorker._(this._isolate, this._requests, this._responses) {
    _responses.listen(_onResponse);
  }

  /// Starts the isolate with an empty index.
  static Future<IsolateSearchWorker> spawn({SearchIndexLimits limits = const SearchIndexLimits()}) async {
    final responses = ReceivePort('madar-search-responses');
    final handshake = Completer<SendPort>();
    late final StreamSubscription<Object?> sub;
    final broadcast = responses.asBroadcastStream();
    sub = broadcast.listen((message) {
      if (message is SendPort && !handshake.isCompleted) {
        handshake.complete(message);
        unawaited(sub.cancel());
      }
    });
    final isolate = await Isolate.spawn<(SendPort, SearchIndexLimits)>(
      _main,
      (responses.sendPort, limits),
      debugName: 'madar-search',
      errorsAreFatal: false,
    );
    final requests = await handshake.future;
    return IsolateSearchWorker._(isolate, requests, _PortStream(broadcast, responses));
  }

  final Isolate _isolate;
  final SendPort _requests;
  final _PortStream _responses;
  final Map<int, Completer<Object?>> _pending = {};
  int _next = 0;
  bool _closed = false;

  void _onResponse(Object? message) {
    if (message is! (int, bool, Object?)) return;
    final (id, ok, payload) = message;
    final c = _pending.remove(id);
    if (c == null) return;
    if (ok) {
      c.complete(payload);
    } else {
      c.completeError(SearchWorkerException('$payload'));
    }
  }

  Future<Object?> _call(String op, [Object? payload]) {
    if (_closed) return Future.error(StateError('Search worker closed'));
    final id = _next++;
    final c = _pending[id] = Completer<Object?>();
    _requests.send((id, op, payload));
    return c.future;
  }

  @override
  Future<void> apply(SearchIndexDelta delta) async {
    if (delta.isEmpty) return;
    await _call('apply', delta);
  }

  @override
  Future<SearchIndexResult> search(SearchIndexQuery query) async => (await _call('search', query))! as SearchIndexResult;

  @override
  Future<SearchIndexStats> stats() async => (await _call('stats'))! as SearchIndexStats;

  @override
  Future<void> close() async {
    if (_closed) return;
    try {
      await _call('close').timeout(const Duration(seconds: 2));
    } on Object {
      // The isolate is killed below either way.
    }
    _closed = true;
    for (final c in _pending.values) {
      c.completeError(StateError('Search worker closed'));
    }
    _pending.clear();
    _responses.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _main((SendPort, SearchIndexLimits) args) {
    final (reply, limits) = args;
    final index = SearchIndex(limits: limits);
    final inbox = ReceivePort('madar-search-requests');
    reply.send(inbox.sendPort);
    inbox.listen((message) {
      final (id, op, payload) = message as (int, String, Object?);
      try {
        final Object? result;
        switch (op) {
          case 'apply':
            index.apply(payload! as SearchIndexDelta);
            result = null;
          case 'search':
            result = index.search(payload! as SearchIndexQuery);
          case 'stats':
            result = index.stats;
          case 'close':
            index.clear();
            reply.send((id, true, null));
            inbox.close();
            return;
          default:
            throw ArgumentError('Unknown search op $op');
        }
        reply.send((id, true, result));
      } on Object catch (e, st) {
        reply.send((id, false, '$e\n$st'));
      }
    });
  }
}

/// The responses stream plus the port to close.
class _PortStream extends Stream<Object?> {
  _PortStream(this._stream, this._port);

  final Stream<Object?> _stream;
  final ReceivePort _port;

  void close() => _port.close();

  @override
  StreamSubscription<Object?> listen(
    void Function(Object? event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}
