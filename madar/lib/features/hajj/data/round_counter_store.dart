import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/round_counter.dart';

/// Where the counter's JSON lives between runs. Local only, no network.
abstract interface class RoundCounterStore {
  /// The saved JSON, or null when nothing was saved (or it is unreadable).
  Future<Object?> read();

  Future<void> write(Map<String, Object?> json);
}

/// Over the app's existing encrypted key/value table, like the tasbeeh's
/// saved state (`TasbeehStore.saveState`).
class KeyValueRoundCounterStore implements RoundCounterStore {
  KeyValueRoundCounterStore(this._kv);

  static const String key = 'hajj.roundCounter';

  final KeyValueRepository _kv;

  @override
  Future<Object?> read() async {
    try {
      return await _kv.getJson(key);
    } on FormatException {
      return null; // damaged value: start empty rather than crash
    }
  }

  @override
  Future<void> write(Map<String, Object?> json) => _kv.setJson(key, json);
}

/// In-memory store (tests, previews). Keeps the JSON as TEXT so a restore
/// proves the counter survives a real encode/decode, and can fail on demand.
class MemoryRoundCounterStore implements RoundCounterStore {
  MemoryRoundCounterStore([String? initial]) : _text = initial;

  String? _text;

  /// Every successful write, oldest first.
  final List<String> writes = [];

  /// While true, writes throw (a full disk, a locked database).
  bool failWrites = false;

  String? get text => _text;

  @override
  Future<Object?> read() async {
    final t = _text;
    if (t == null) return null;
    try {
      return jsonDecode(t);
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, Object?> json) async {
    if (failWrites) throw StateError('write failed');
    _text = jsonEncode(json);
    writes.add(_text!);
  }
}

/// Saves a [RoundCounter] after every change without ever blocking a tap and
/// without two writes racing: at most one write is in flight, and whatever
/// changed meanwhile is written next. A failed write is retried by the next
/// change (and by [flush]); the in-memory count is never touched.
class RoundCounterPersister {
  RoundCounterPersister(this.store);

  final RoundCounterStore store;

  Map<String, Object?>? _pending;
  Future<void>? _running;

  /// Last write error, for a quiet "not saved" hint; cleared on success.
  final ValueNotifier<Object?> lastError = ValueNotifier<Object?>(null);

  /// Loads the saved counter (empty when none/unreadable).
  Future<RoundCounter> load({
    Duration debounce = RoundCounter.defaultDebounce,
    Duration Function()? monotonic,
    DateTime Function()? wallClock,
    String Function()? newId,
  }) async {
    Object? json;
    try {
      json = await store.read();
    } on Object {
      json = null;
    }
    return RoundCounter.fromJson(json, debounce: debounce, monotonic: monotonic, wallClock: wallClock, newId: newId);
  }

  /// Queue the counter's current state for writing.
  void save(RoundCounter counter) {
    _pending = counter.toJson();
    _running ??= _drain();
  }

  /// Completes when everything queued so far is written (or has failed).
  Future<void> flush() async {
    // A previous failure leaves its state pending: try it once more now.
    if (_pending != null) _running ??= _drain();
    while (_running != null) {
      await _running;
    }
  }

  Future<void> _drain() async {
    try {
      // Yield once so a burst of changes in the same turn becomes one write.
      await Future<void>.value();
      while (_pending != null) {
        final json = _pending!;
        _pending = null;
        try {
          await store.write(json);
          lastError.value = null;
        } on Object catch (e) {
          lastError.value = e;
          // Keep the newest state for the next attempt, unless a newer one
          // already arrived.
          _pending ??= json;
          return;
        }
      }
    } finally {
      _running = null;
    }
  }

  void dispose() => lastError.dispose();
}
