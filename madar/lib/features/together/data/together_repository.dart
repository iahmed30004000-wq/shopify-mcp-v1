import 'dart:convert';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/key_value_repository.dart';
import '../domain/head_to_head.dart';
import '../domain/match_record.dart';
import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import '../domain/together_bounds.dart';
import '../domain/trophies.dart';

/// Together Mode storage: bounded JSON values in the encrypted KeyValues
/// table – no schema of its own.
///
/// | key                 | value                                          |
/// |---------------------|------------------------------------------------|
/// | `together.profiles` | both players ([TogetherProfiles])              |
/// | `together.settings` | [TogetherSettings]                             |
/// | `together.history`  | the last [TogetherBounds.maxHistory] matches   |
/// | `together.ledger`   | lifetime tallies and streaks ([TogetherLedger]) |
/// | `together.trophies` | the Hall of Fame ([TrophyShelf])               |
class TogetherRepository {
  TogetherRepository(this.db) : keyValues = KeyValueRepository(db);

  static const String profilesKey = 'together.profiles';
  static const String settingsKey = 'together.settings';
  static const String historyKey = 'together.history';
  static const String ledgerKey = 'together.ledger';
  static const String trophiesKey = 'together.trophies';

  /// Every key this feature writes.
  static const List<String> allKeys = [profilesKey, settingsKey, historyKey, ledgerKey, trophiesKey];

  final MadarDatabase db;
  final KeyValueRepository keyValues;

  // ------------------------------------------------------------------ reads

  /// The raw JSON text of [key], re-emitted only when it changes (other
  /// features' KeyValues writes do not wake Together listeners).
  Stream<String?> _watchRaw(String key) =>
      (db.select(db.keyValues)..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value).distinct();

  Stream<T> _watch<T>(String key, T Function(Object? json) decode) =>
      _watchRaw(key).map((raw) => decode(_decode(raw)));

  static Object? _decode(String? raw) {
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<Object?> _read(String key) async {
    final row = await (db.select(db.keyValues)..where((t) => t.key.equals(key))).getSingleOrNull();
    return _decode(row?.value);
  }

  Stream<TogetherProfiles> watchProfiles() => _watch(profilesKey, TogetherProfiles.fromJson);

  Future<TogetherProfiles> profiles() async => TogetherProfiles.fromJson(await _read(profilesKey));

  Stream<TogetherSettings> watchSettings() => _watch(settingsKey, TogetherSettings.fromJson);

  Future<TogetherSettings> settings() async => TogetherSettings.fromJson(await _read(settingsKey));

  /// Matches, newest first.
  Stream<List<MatchRecord>> watchHistory() => _watch(historyKey, (j) => _newestFirst(historyFromJson(j)));

  Future<List<MatchRecord>> history() async => _newestFirst(historyFromJson(await _read(historyKey)));

  Stream<TogetherLedger> watchLedger() => _watch(ledgerKey, TogetherLedger.fromJson);

  Future<TogetherLedger> ledger() async => TogetherLedger.fromJson(await _read(ledgerKey));

  Stream<TrophyShelf> watchTrophies() =>
      _watch(trophiesKey, (j) => TrophyShelf.fromJson(j, max: TogetherBounds.maxTrophies));

  Future<TrophyShelf> trophies() async =>
      TrophyShelf.fromJson(await _read(trophiesKey), max: TogetherBounds.maxTrophies);

  /// Stored matches in storage order (oldest first), unusable entries and
  /// duplicate ids dropped, at most [TogetherBounds.maxHistory].
  static List<MatchRecord> historyFromJson(Object? json) {
    if (json is! Map || json['matches'] is! List) return const [];
    final seen = <String>{};
    final list = <MatchRecord>[];
    for (final item in json['matches'] as List) {
      final r = MatchRecord.fromJson(item);
      if (r != null && seen.add(r.id)) list.add(r);
    }
    return list.length > TogetherBounds.maxHistory ? list.sublist(list.length - TogetherBounds.maxHistory) : list;
  }

  static List<MatchRecord> _newestFirst(List<MatchRecord> list) =>
      list.toList()..sort((a, b) => b.endedAt.compareTo(a.endedAt));

  // ----------------------------------------------------------------- writes

  Future<void> saveProfile(TogetherProfile profile) => db.transaction(() async {
    final current = await profiles();
    await keyValues.setJson(profilesKey, current.withProfile(profile).toJson());
  });

  Future<void> saveProfiles(TogetherProfiles profiles) => keyValues.setJson(profilesKey, profiles.toJson());

  Future<void> saveSettings(TogetherSettings settings) => keyValues.setJson(settingsKey, settings.toJson());

  /// Records a finished match: appends it to the history (dropping the
  /// oldest beyond the bound), updates the lifetime ledger and puts newly
  /// earned trophies on the shelf – atomically. Recording an id that is
  /// already in the history changes nothing (two phones, resent results).
  Future<RecordedMatch> recordMatch(MatchRecord record) {
    final r = record.bounded();
    if (!r.isValid) throw ArgumentError.value(record, 'record', 'invalid match or game id');
    return db.transaction(() async {
      final stored = historyFromJson(await _read(historyKey));
      if (stored.any((m) => m.id == r.id)) return RecordedMatch(record: r, duplicate: true);
      final ledger = (await this.ledger()).apply(r);
      final shelf = await trophies();
      final fresh = <EarnedTrophy>[];
      for (final key in TrophyRules.satisfied(ledger, r)) {
        if (!shelf.has(key) && !fresh.any((t) => t.key == key)) {
          fresh.add(EarnedTrophy(key: key, earnedAt: r.endedAt, matchId: r.id));
        }
      }
      var history = [...stored, r];
      if (history.length > TogetherBounds.maxHistory) {
        history = history.sublist(history.length - TogetherBounds.maxHistory);
      }
      var onShelf = [...shelf.trophies, ...fresh];
      if (onShelf.length > TogetherBounds.maxTrophies) {
        onShelf = onShelf.sublist(onShelf.length - TogetherBounds.maxTrophies);
      }
      await keyValues.setJson(historyKey, {
        'v': 1,
        'matches': [for (final m in history) m.toJson()],
      });
      await keyValues.setJson(ledgerKey, ledger.toJson());
      if (fresh.isNotEmpty) await keyValues.setJson(trophiesKey, TrophyShelf(onShelf).toJson());
      return RecordedMatch(record: r, duplicate: false, newTrophies: fresh);
    });
  }

  /// Clears the history, tallies and trophies (profiles and settings stay).
  /// Returns an undo that restores exactly what was there.
  Future<Future<void> Function()> resetRecords() => db.transaction(() async {
    final saved = <String, String?>{};
    for (final key in const [historyKey, ledgerKey, trophiesKey]) {
      final row = await (db.select(db.keyValues)..where((t) => t.key.equals(key))).getSingleOrNull();
      saved[key] = row?.value;
      await keyValues.remove(key);
    }
    return () => db.transaction(() async {
      for (final e in saved.entries) {
        if (e.value == null) {
          await keyValues.remove(e.key);
        } else {
          await keyValues.setJson(e.key, _decode(e.value));
        }
      }
    });
  });
}
