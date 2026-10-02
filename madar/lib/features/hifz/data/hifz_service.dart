import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../wird/data/wird_service.dart' show WirdActivityRecorder;
import '../domain/hadith_collection.dart';
import '../domain/hifz_models.dart';
import '../domain/hifz_session.dart';
import '../domain/sm2.dart';

/// Undoes one Hifz change exactly.
typedef HifzUndo = Future<void> Function();

/// How Hifz shows up in the activity stream (the Faith planet's `quran`
/// score source counts kinds containing `quran`).
abstract final class HifzActivity {
  static const String planetKey = 'faith';
  static const String kind = 'quran.hifz';
  static const String refTable = 'hifz_reviews';
}

/// The user's Hifz preferences (`key_values` `hifz.settings`).
@immutable
class HifzSettings {
  const HifzSettings({this.newPerDay = 3, this.listenRepeat = 3, this.chunkSize = 5});

  static const List<int> newPerDayChoices = [1, 2, 3, 5, 7, 10];
  static const List<int> repeatChoices = [1, 2, 3, 5, 7, 10];
  static const List<int> chunkChoices = [3, 5, 7, 10];

  /// New items introduced per day.
  final int newPerDay;

  /// Times each ayah is recited in a listening drill.
  final int listenRepeat;

  /// Ayat per chunk when adding a range.
  final int chunkSize;

  HifzSettings copyWith({int? newPerDay, int? listenRepeat, int? chunkSize}) => HifzSettings(
    newPerDay: newPerDay ?? this.newPerDay,
    listenRepeat: listenRepeat ?? this.listenRepeat,
    chunkSize: chunkSize ?? this.chunkSize,
  );

  Map<String, Object?> toJson() => {'newPerDay': newPerDay, 'listenRepeat': listenRepeat, 'chunkSize': chunkSize};

  factory HifzSettings.fromJson(Object? json) {
    if (json is! Map) return const HifzSettings();
    int pick(Object? v, int min, int max, int fallback) => v is num && v >= min && v <= max ? v.toInt() : fallback;
    return HifzSettings(
      newPerDay: pick(json['newPerDay'], 0, 50, 3),
      listenRepeat: pick(json['listenRepeat'], 1, 20, 3),
      chunkSize: pick(json['chunkSize'], 1, 50, 5),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HifzSettings &&
      other.newPerDay == newPerDay &&
      other.listenRepeat == listenRepeat &&
      other.chunkSize == chunkSize;

  @override
  int get hashCode => Object.hash(newPerDay, listenRepeat, chunkSize);
}

/// Reads and writes Hifz items (`hifz_items`) and their review log
/// (`hifz_reviews`). Every write returns a [HifzUndo] that restores the
/// exact prior state.
class HifzService {
  HifzService(this.repos, {required this.clock, this.recorder});

  final Repositories repos;
  final DateTime Function() clock;
  final WirdActivityRecorder? recorder;

  static const String settingsKey = 'hifz.settings';

  // ---------------------------------------------------------------- reads --

  Stream<List<HifzCard>> watchCards() =>
      repos.hifzItems.watchAll().map((rows) => [for (final r in rows) HifzCard.fromRow(r)]);

  Stream<List<HifzReviewLog>> watchReviews() =>
      repos.hifzReviews.watchAll().map((rows) => [for (final r in rows) HifzReviewLog.fromRow(r)]);

  Future<List<HifzCard>> cards() async => [for (final r in await repos.hifzItems.getAll()) HifzCard.fromRow(r)];

  Stream<HifzSettings> watchSettings() => repos.keyValues.watchJson(settingsKey).map(HifzSettings.fromJson);

  Future<HifzSettings> settings() async => HifzSettings.fromJson(await repos.keyValues.getJson(settingsKey));

  Future<HifzUndo> saveSettings(HifzSettings s) async {
    final before = await repos.keyValues.getJson(settingsKey);
    await repos.keyValues.setJson(settingsKey, s.toJson());
    return () async {
      if (before == null) {
        await repos.keyValues.remove(settingsKey);
      } else {
        await repos.keyValues.setJson(settingsKey, before);
      }
    };
  }

  // ----------------------------------------------------------------- adds --

  HifzUndo _deleteAll(List<String> ids) => () async {
    for (final id in ids) {
      await repos.hifzItems.delete(id);
    }
  };

  /// Adds [range] split into chunks of at most [chunkSize] ayat (per surah).
  /// Chunks already in Hifz are skipped. Returns the new items.
  Future<(List<HifzCard>, HifzUndo)> addAyahRange(
    AyahRange range, {
    required int Function(int surah) ayahCount,
    int chunkSize = 5,
  }) async {
    final existing = {
      for (final c in await cards())
        if (c.range != null) c.range!,
    };
    final added = <HifzCard>[];
    for (final chunk in HifzChunker.chunks(range, ayahCount, chunkSize)) {
      if (existing.contains(chunk)) continue;
      final row = await repos.hifzItems.insert(
        HifzItemsCompanion.insert(
          kind: const Value(HifzKind.ayat),
          surah: Value(chunk.first.surah),
          ayahFrom: Value(chunk.first.ayah),
          ayahTo: Value(chunk.last.ayah),
        ),
      );
      added.add(HifzCard.fromRow(row));
    }
    return (added, _deleteAll([for (final c in added) c.id]));
  }

  /// Adds hadith [entry] of [collection] (null when it is already in Hifz).
  Future<(HifzCard, HifzUndo)?> addHadith(HadithCollection collection, HadithEntry entry) async {
    final key = collection.keyOf(entry);
    if ((await cards()).any((c) => c.kind == HifzKind.hadith && c.source == key)) return null;
    final row = await repos.hifzItems.insert(
      HifzItemsCompanion.insert(kind: const Value(HifzKind.hadith), body: Value(entry.text), source: Value(key)),
    );
    return (HifzCard.fromRow(row), _deleteAll([row.id]));
  }

  Future<(HifzCard, HifzUndo)> addCustom({required String title, required String body, String? source}) async {
    final t = title.trim(), s = source?.trim();
    final row = await repos.hifzItems.insert(
      HifzItemsCompanion.insert(
        kind: const Value(HifzKind.custom),
        title: Value(t.isEmpty ? null : t),
        body: Value(body.trim()),
        source: Value(s == null || s.isEmpty ? null : s),
      ),
    );
    return (HifzCard.fromRow(row), _deleteAll([row.id]));
  }

  // ---------------------------------------------------------------- edits --

  Future<HifzUndo> _change(String id, HifzItemRow Function(HifzItemRow row) change) async {
    final before = await repos.hifzItems.byId(id);
    if (before == null) return () async {};
    await repos.hifzItems.update(change(before));
    return () => repos.hifzItems.restore(before);
  }

  /// Edits a custom item's texts or an ayat item's range (its schedule is
  /// kept).
  Future<HifzUndo> edit(HifzCard card, {String? title, String? body, String? source, AyahRange? range}) =>
      _change(card.id, (r) {
        String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
        return r.copyWith(
          title: title == null ? const Value.absent() : Value(clean(title)),
          body: body == null ? const Value.absent() : Value(clean(body)),
          source: source == null ? const Value.absent() : Value(clean(source)),
          surah: range == null ? const Value.absent() : Value(range.first.surah),
          ayahFrom: range == null ? const Value.absent() : Value(range.first.ayah),
          ayahTo: range == null ? const Value.absent() : Value(range.last.ayah),
        );
      });

  Future<HifzUndo> setSuspended(HifzCard card, bool suspended) =>
      _change(card.id, (r) => r.copyWith(suspended: suspended));

  /// Makes [card] new again (its review log stays for the statistics).
  Future<HifzUndo> resetProgress(HifzCard card) => _change(
    card.id,
    (r) => r.copyWith(
      easeFactor: Sm2.initialEase,
      intervalDays: 0,
      repetitions: 0,
      lapses: 0,
      due: const Value(null),
      lastReviewedAt: const Value(null),
    ),
  );

  /// Deletes [card] and its reviews.
  Future<HifzUndo> delete(HifzCard card) async {
    final row = await repos.hifzItems.delete(card.id);
    final reviews = await repos.hifzReviews.deleteWhere((t) => t.itemId.equals(card.id));
    return () async {
      if (row != null) await repos.hifzItems.restore(row);
      await repos.hifzReviews.restoreAll(reviews);
    };
  }

  Future<void> reorder(List<String> ids) => repos.hifzItems.reorder(ids);

  // --------------------------------------------------------------- review --

  /// Persists a grade: the rescheduled item and a review row (nothing for a
  /// same-day re-drill). Returns the undo.
  Future<HifzUndo> applyGrade(HifzGradeOutcome outcome) async {
    final after = outcome.after;
    if (after == null) return () async {};
    final before = await repos.hifzItems.byId(after.id);
    if (before == null) return () async {};
    await repos.hifzItems.update(
      before.copyWith(
        easeFactor: after.sm2.easeFactor,
        intervalDays: after.sm2.intervalDays,
        repetitions: after.sm2.repetitions,
        lapses: after.sm2.lapses,
        due: Value(after.due),
        lastReviewedAt: Value(after.lastReviewedAt),
      ),
    );
    final review = await repos.hifzReviews.insert(
      HifzReviewsCompanion.insert(
        itemId: after.id,
        at: after.lastReviewedAt ?? clock(),
        grade: outcome.grade,
        intervalBefore: outcome.before.sm2.intervalDays,
        intervalAfter: after.sm2.intervalDays,
        easeAfter: after.sm2.easeFactor,
      ),
    );
    return () async {
      await repos.hifzReviews.delete(review.id);
      await repos.hifzItems.restore(before);
    };
  }

  /// Logs a finished (or left) session as one `quran.hifz` activity.
  Future<void> recordSession(String sessionId, HifzSessionSummary summary) async {
    if (summary.reviewed == 0) return;
    final payload = <String, Object?>{
      'reviewed': summary.reviewed,
      'new': summary.learnedNew,
      'redrills': summary.redrills,
      if (summary.recalled != null) 'recalled': summary.recalled,
    };
    final r = recorder;
    if (r != null) {
      await r(
        kind: HifzActivity.kind,
        refTable: HifzActivity.refTable,
        refId: sessionId,
        at: clock(),
        value: summary.reviewed.toDouble(),
        payload: payload,
      );
    } else {
      await repos.activity.log(
        planetKey: HifzActivity.planetKey,
        kind: HifzActivity.kind,
        refTable: HifzActivity.refTable,
        refId: sessionId,
        at: clock(),
        value: summary.reviewed.toDouble(),
        payload: payload,
      );
    }
  }
}
