import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../domain/adhkar_timing.dart';
import '../domain/tasbeeh.dart';
import 'adhkar_activity.dart';

/// The tasbeeh's saved state: phrase, target, today's running count and the
/// activity-log row of the current session.
@immutable
class TasbeehSavedState {
  const TasbeehSavedState({required this.phraseId, required this.target, this.count = 0, this.sessionId, this.day});

  final String phraseId;
  final int target;
  final int count;

  /// Activity-log id of the session being counted (null before the first tap).
  final String? sessionId;

  /// `yyyy-MM-dd` the count belongs to.
  final String? day;

  Map<String, Object?> toJson() => {
    'phraseId': phraseId,
    'target': target,
    'count': count,
    'sessionId': ?sessionId,
    'day': ?day,
  };

  static TasbeehSavedState? fromJson(Object? json) {
    if (json is! Map) return null;
    final phraseId = json['phraseId'];
    final target = TasbeehCounter.parseTarget(json['target']);
    final count = json['count'];
    if (phraseId is! String || target == null) return null;
    return TasbeehSavedState(
      phraseId: phraseId,
      target: target,
      count: count is num && count >= 0 ? count.toInt() : 0,
      sessionId: json['sessionId'] as String?,
      day: json['day'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TasbeehSavedState &&
      other.phraseId == phraseId &&
      other.target == target &&
      other.count == count &&
      other.sessionId == sessionId &&
      other.day == day;

  @override
  int get hashCode => Object.hash(phraseId, target, count, sessionId, day);
}

/// Tasbeeh persistence: the phrase list and saved state in the encrypted
/// key/value store, sessions in the activity log (kind
/// [AdhkarActivity.tasbeehKind], value = count), so the Faith planet counts
/// the practice and the history survives.
class TasbeehStore {
  TasbeehStore(this.repos);

  static const String phrasesKey = 'tasbeeh.phrases';
  static const String stateKey = 'tasbeeh.state';

  final Repositories repos;

  KeyValueRepository get _kv => repos.keyValues;

  static List<TasbeehPhrase> _decodePhrases(Object? json) {
    if (json is! List) return TasbeehDefaults.phrases;
    final out = <TasbeehPhrase>[];
    final seen = <String>{};
    for (final p in json) {
      final phrase = TasbeehPhrase.fromJson(p);
      if (phrase != null && seen.add(phrase.id)) out.add(phrase);
    }
    return out;
  }

  /// The user's phrases (the defaults until the list is first edited). May
  /// be empty when the user removed them all.
  Future<List<TasbeehPhrase>> loadPhrases() async => _decodePhrases(await _kv.getJson(phrasesKey));

  Stream<List<TasbeehPhrase>> watchPhrases() => _kv.watchJson(phrasesKey).map(_decodePhrases);

  Future<void> savePhrases(List<TasbeehPhrase> phrases) =>
      _kv.setJson(phrasesKey, [for (final p in phrases) p.toJson()]);

  Future<TasbeehSavedState?> loadState() async => TasbeehSavedState.fromJson(await _kv.getJson(stateKey));

  Future<void> saveState(TasbeehSavedState state) => _kv.setJson(stateKey, state.toJson());

  /// Opens a session in the activity log; returns its row id.
  Future<String> startSession({
    required TasbeehPhrase phrase,
    required int target,
    required int count,
    required DateTime at,
  }) async {
    final row = await repos.activity.log(
      planetKey: AdhkarActivity.planetKey,
      kind: AdhkarActivity.tasbeehKind,
      refTable: AdhkarActivity.tasbeehRefTable,
      refId: const Uuid().v4(),
      at: at,
      value: count.toDouble(),
      payload: {'phrase': phrase.text, 'phraseId': phrase.id, 'target': target},
    );
    return row.id;
  }

  /// Writes the running [count] of session [id].
  Future<void> updateSession(String id, int count) => repos.activityLog.setColumns(id, {'value': count.toDouble()});

  /// Sessions since [since], newest first.
  Stream<List<TasbeehSession>> watchSessions(DateTime since) => repos.activity
      .watchSince(since, planetKey: AdhkarActivity.planetKey, kind: AdhkarActivity.tasbeehKind)
      .map((rows) => [for (final r in rows) ?sessionOf(r)]);

  /// Removes a session (returns the row for undo).
  Future<ActivityRow?> deleteSession(String id) => repos.activityLog.delete(id);

  Future<void> restoreSession(ActivityRow row) => repos.activityLog.restore(row);

  /// Today's (prayer-day) tasbeeh total.
  static int totalOn(List<TasbeehSession> sessions, DateTime dayStart, DateTime dayEnd) =>
      sessions.where((s) => !s.at.isBefore(dayStart) && s.at.isBefore(dayEnd)).fold(0, (sum, s) => sum + s.count);

  static TasbeehSession? sessionOf(ActivityRow r) {
    final count = (r.value ?? 0).round();
    if (count <= 0) return null;
    final target = TasbeehCounter.parseTarget(r.payload['target']) ?? TasbeehDefaults.defaultTarget;
    return TasbeehSession(id: r.id, phrase: '${r.payload['phrase'] ?? ''}', count: count, target: target, at: r.at);
  }

  static String dayKey(DateTime day) => AdhkarTiming.dayKey(day);
}
