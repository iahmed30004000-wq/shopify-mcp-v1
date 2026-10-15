import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../orbit/data/orbit_pulses.dart';
import '../domain/quran_meta.dart';
import '../domain/quran_prefs.dart';
import '../domain/reading_tracker.dart';

/// Reader settings and the last-read position in KeyValues.
class QuranPrefsStore {
  QuranPrefsStore(this._kv);

  final KeyValueRepository _kv;

  static final KvKey<QuranReaderPrefs> prefsKey = KvKey.json(
    QuranReaderPrefs.storageKey,
    fromJson: QuranReaderPrefs.fromJson,
    toJson: (v) => v.toJson(),
  );

  static final KvKey<QuranLastRead> lastReadKey = KvKey.json(
    QuranLastRead.storageKey,
    fromJson: (json) => QuranLastRead.fromJson(json) ?? (throw FormatException('bad last-read', json)),
    toJson: (v) => v.toJson(),
  );

  Stream<QuranReaderPrefs> watchPrefs() => _kv.watch(prefsKey).map((v) => v ?? const QuranReaderPrefs());

  Future<QuranReaderPrefs> prefs() async => await _kv.get(prefsKey) ?? const QuranReaderPrefs();

  Future<void> savePrefs(QuranReaderPrefs prefs) => _kv.set(prefsKey, prefs);

  Future<QuranReaderPrefs> updatePrefs(QuranReaderPrefs Function(QuranReaderPrefs) change) async {
    final next = change(await prefs());
    await savePrefs(next);
    return next;
  }

  Stream<QuranLastRead?> watchLastRead() => _kv.watch(lastReadKey);

  Future<QuranLastRead?> lastRead() => _kv.get(lastReadKey);

  Future<void> saveLastRead(QuranLastRead value) => _kv.set(lastReadKey, value);
}

/// Bookmarks (colour / label / note) on ayat, user-ordered.
class QuranBookmarkService {
  QuranBookmarkService(this._repos);

  final Repositories _repos;

  Stream<List<QuranBookmarkRow>> watchAll() => _repos.quranBookmarks.watchAll();

  Future<List<QuranBookmarkRow>> all() => _repos.quranBookmarks.getAll();

  Future<QuranBookmarkRow?> forAyah(AyahRef ref) async {
    final rows = await _repos.quranBookmarks.getAll(where: (t) => t.surah.equals(ref.surah) & t.ayah.equals(ref.ayah));
    return rows.isEmpty ? null : rows.first;
  }

  Future<QuranBookmarkRow> add(AyahRef ref, {String? label, String? note, int? color}) =>
      _repos.quranBookmarks.insert(
        QuranBookmarksCompanion.insert(
          surah: ref.surah,
          ayah: ref.ayah,
          label: Value(_blank(label)),
          note: Value(_blank(note)),
          color: Value(color),
        ),
      );

  Future<void> edit(String id, {String? label, String? note, int? color}) => _repos.quranBookmarks.update(
    QuranBookmarksCompanion(id: Value(id), label: Value(_blank(label)), note: Value(_blank(note)), color: Value(color)),
  );

  /// Deletes and returns the row (restore it with [restore] to undo).
  Future<QuranBookmarkRow?> delete(String id) => _repos.quranBookmarks.delete(id);

  Future<void> restore(QuranBookmarkRow row) => _repos.quranBookmarks.restore(row);

  Future<void> reorder(List<String> ids) => _repos.quranBookmarks.reorder(ids);

  static String? _blank(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
}

/// Writes finished reading sessions: a QuranSessions row plus an activity
/// entry `quran.read` on the Faith planet (through the orbit's pulse hub).
class QuranSessionRecorder {
  QuranSessionRecorder(this._repos, this._hub);

  final Repositories _repos;
  final OrbitPulseHub _hub;

  static const String planetKey = 'faith';
  static const String readKind = 'quran.read';

  /// Records [summary]; returns the stored row.
  Future<QuranSessionRow> record(ReadingSummary summary, QuranMeta meta) async {
    final from = meta.refAt(summary.firstIndex);
    final to = meta.refAt(summary.lastIndex);
    final byPage = <int, int>{};
    for (final i in summary.seen) {
      final page = meta.pageOf(meta.refAt(i));
      byPage[page] = (byPage[page] ?? 0) + 1;
    }
    var pages = 0.0;
    byPage.forEach((page, seen) => pages += meta.pageShare(page, seen));
    final start = summary.startedAt;
    final row = await _repos.quranSessions.insert(
      QuranSessionsCompanion.insert(
        day: DateTime(start.year, start.month, start.day),
        mode: const Value(QuranSessionMode.read),
        fromSurah: from.surah,
        fromAyah: from.ayah,
        toSurah: to.surah,
        toAyah: to.ayah,
        ayahCount: Value(summary.seen.length),
        pages: Value(double.parse(pages.toStringAsFixed(2))),
        seconds: Value(summary.seconds),
      ),
    );
    await _hub.recordCompletion(
      planetKey,
      readKind,
      _repos.quranSessions.tableName,
      row.id,
      at: summary.endedAt,
      value: summary.seconds / 60,
      payload: {'from': '$from', 'to': '$to', 'ayat': summary.seen.length, 'pages': row.pages},
    );
    return row;
  }
}

/// Copy / share (behind an interface for tests).
abstract interface class QuranShareService {
  Future<void> copy(String text);
  Future<void> share(String text, {String? subject});
}

class PlatformQuranShareService implements QuranShareService {
  const PlatformQuranShareService();

  @override
  Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  @override
  Future<void> share(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}

/// Records what would have been copied / shared.
class RecordingQuranShareService implements QuranShareService {
  final List<String> copied = [];
  final List<String> shared = [];

  @override
  Future<void> copy(String text) async => copied.add(text);

  @override
  Future<void> share(String text, {String? subject}) async => shared.add(text);
}
