/// «التسميع» · every read and write of the recitation log (Part 13, step 1).
///
/// The engine itself is pure Dart in `domain/`; this is the only part that
/// touches the database. Every write returns a [TasmeeUndo] that restores
/// the exact prior state, exactly as `SufraService` and `ListService` do.
///
/// **No audio reaches this layer, ever.** There is no parameter, column or
/// field for a recording anywhere between the microphone and here: the
/// recogniser hands the engine words, the engine hands this service a
/// [TasmeeSessionDraft] of words, and that is all there is to write. So
/// there is nothing to delete after scoring.
library;

import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../quran/data/quran_store.dart';
import '../../quran/domain/quran_text.dart';
import '../domain/alignment.dart';
import '../domain/ayah_words.dart';
import '../domain/mistake_export.dart';
import '../domain/mistake_log.dart';
import '../domain/recite_to_find.dart';
import '../domain/recogniser.dart';
import '../domain/tasmee_settings.dart';

/// Reverses one change (the UI wraps it in an undo toast).
typedef TasmeeUndo = Future<void> Function();

/// Row → pure model, and back.
abstract final class TasmeeRows {
  static RecitationCounts sessionCounts(TasmeeSessionRow r) => RecitationCounts(
    words: r.wordCount,
    right: r.rightCount,
    wrong: r.wrongCount,
    skipped: r.skippedCount,
    unsure: r.unsureCount,
    pending: r.pendingCount,
    extras: r.extraCount,
    hints: r.hintCount,
    tashkeelDifferent: r.tashkeelDiffCount,
  );

  static RecitationCounts ayahCounts(TasmeeAyahRow r) => RecitationCounts(
    words: r.wordCount,
    right: r.rightCount,
    wrong: r.wrongCount,
    skipped: r.skippedCount,
    unsure: r.unsureCount,
    pending: r.pendingCount,
    extras: r.extraCount,
    hints: r.hintCount,
    tashkeelDifferent: r.tashkeelDiffCount,
  );

  static TasmeeAyahResult ayah(TasmeeAyahRow r) => TasmeeAyahResult(
    id: r.id,
    sessionId: r.sessionId,
    day: r.day,
    ref: AyahRef(r.surah, r.ayah),
    counts: ayahCounts(r),
  );

  static TasmeeMistake mistake(TasmeeMistakeRow r) => TasmeeMistake(
    id: r.id,
    sessionId: r.sessionId,
    at: r.at,
    day: r.day,
    ref: AyahRef(r.surah, r.ayah),
    wordIndex: r.wordIndex,
    kind: r.kind,
    expected: r.expected,
    start: r.spanStart,
    end: r.spanEnd,
    heard: r.heard,
    hinted: r.hinted,
    confidence: r.confidence,
    tashkeelOnly: r.tashkeelOnly,
  );

  static TasmeeSession session(
    TasmeeSessionRow r, {
    Iterable<TasmeeAyahRow> ayat = const [],
    Iterable<TasmeeMistakeRow> mistakes = const [],
  }) => TasmeeSession(
    id: r.id,
    startedAt: r.startedAt,
    day: r.day,
    mode: r.mode,
    range: AyahRange(AyahRef(r.fromSurah, r.fromAyah), AyahRef(r.toSurah, r.toAyah)),
    counts: sessionCounts(r),
    seconds: r.seconds,
    recogniserId: r.recogniserId,
    recogniserVersion: r.recogniserVersion,
    textSource: r.textSource,
    tashkeelChecked: r.tashkeelChecked,
    seed: r.seed,
    note: r.note,
    ayat: [
      for (final a in ayat)
        if (a.sessionId == r.id) ayah(a),
    ],
    mistakes: [
      for (final m in mistakes)
        if (m.sessionId == r.id) mistake(m),
    ],
  );

  /// Every session with its own ayat and mistakes, newest first (one pass).
  static List<TasmeeSession> sessions(
    Iterable<TasmeeSessionRow> rows,
    Iterable<TasmeeAyahRow> ayat,
    Iterable<TasmeeMistakeRow> mistakes,
  ) {
    final byAyah = <String, List<TasmeeAyahRow>>{};
    for (final a in ayat) {
      (byAyah[a.sessionId] ??= []).add(a);
    }
    final byMistake = <String, List<TasmeeMistakeRow>>{};
    for (final m in mistakes) {
      (byMistake[m.sessionId] ??= []).add(m);
    }
    final out = [
      for (final r in rows) session(r, ayat: byAyah[r.id] ?? const [], mistakes: byMistake[r.id] ?? const []),
    ];
    out.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return out;
  }
}

/// Builds a [RecitationTarget] and the recite-to-find index out of the
/// app's own verified Quran data. Nothing is fetched and nothing is
/// generated: it reads the bundled text and cuts it into words.
abstract final class TasmeeTargets {
  /// The words of [range], with the basmala allowed before them.
  ///
  /// The offsets of every word are code units of the **ayah's own text**
  /// (`QuranText.ayahText`), which is the ayah without the header basmala –
  /// the same string the reader highlights.
  static Future<RecitationTarget> range(QuranStore store, AyahRange range, {bool allowBasmala = true}) async {
    final meta = await store.meta();
    final text = await store.text();
    final from = meta.indexOf(range.first);
    final to = meta.indexOf(range.last);
    if (to < from) throw ArgumentError.value(range, 'range', 'The range runs backwards');
    final ayat = [for (var i = from; i <= to; i++) (meta.refAt(i), text.ayahText(i))];
    final prelude = <List<String>>[];
    if (allowBasmala) {
      // Always the verified spelling: the sura's own header basmala, or
      // 1:1's for the two suras that have no header (al-Fatihah, at-Tawbah).
      final header = text.basmalaOf(meta.surah(range.first.surah)) ?? QuranText.openingBasmala;
      prelude.add(header.split(' '));
    }
    return RecitationTarget.of(ayat, prelude: prelude);
  }

  /// One ayah.
  static Future<RecitationTarget> ayah(QuranStore store, AyahRef ref, {bool allowBasmala = true}) =>
      range(store, AyahRange.single(ref), allowBasmala: allowBasmala);

  /// The n-gram index of the whole verified text, for «شازام القرآن».
  ///
  /// Built from `QuranText.ayahText`, so the basmala that heads a sura is
  /// not indexed as part of its first ayah and a search never lands on 114
  /// surahs at once.
  static Future<ReciteIndex> reciteIndex(QuranStore store, {int gram = 2}) async {
    final meta = await store.meta();
    final text = await store.text();
    return ReciteIndex.build([
      for (var i = 0; i < meta.ayahCount; i++) (meta.refAt(i), text.ayahText(i)),
    ], gram: gram);
  }
}

/// Every read and write of «التسميع»'s log.
class TasmeeService {
  TasmeeService(this.repos, {DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() clock;

  MadarDatabase get _db => repos.db;

  EntityRepository<$TasmeeSessionsTable, TasmeeSessionRow> get _sessions => repos.tasmeeSessions;
  EntityRepository<$TasmeeAyatTable, TasmeeAyahRow> get _ayat => repos.tasmeeAyat;
  EntityRepository<$TasmeeMistakesTable, TasmeeMistakeRow> get _mistakes => repos.tasmeeMistakes;

  /// Today as a calendar day.
  DateTime get today {
    final now = clock();
    return DateTime(now.year, now.month, now.day);
  }

  // ------------------------------------------------------------ settings ----

  static const _settingsKey = KvKey<TasmeeSettings>(
    TasmeeSettings.storageKey,
    decode: TasmeeSettings.fromJson,
    encode: _encodeSettings,
  );

  static Object? _encodeSettings(TasmeeSettings s) => s.toJson();

  Future<TasmeeSettings> settings() async => await repos.keyValues.get(_settingsKey) ?? const TasmeeSettings();

  Stream<TasmeeSettings> watchSettings() =>
      repos.keyValues.watch(_settingsKey).map((s) => s ?? const TasmeeSettings()).distinct();

  Future<TasmeeUndo> setSettings(TasmeeSettings settings) async {
    final had = await repos.keyValues.contains(TasmeeSettings.storageKey);
    final before = await repos.keyValues.getJson(TasmeeSettings.storageKey);
    await repos.keyValues.set(_settingsKey, settings);
    return () async {
      if (had) {
        await repos.keyValues.setJson(TasmeeSettings.storageKey, before);
      } else {
        await repos.keyValues.remove(TasmeeSettings.storageKey);
      }
    };
  }

  // --------------------------------------------------------------- reads ----

  Future<List<TasmeeSessionRow>> sessionRows() => _sessions.getAll();

  Future<List<TasmeeAyahRow>> ayahRows({String? sessionId}) =>
      _ayat.getAll(where: sessionId == null ? null : (t) => t.sessionId.equals(sessionId));

  Future<List<TasmeeMistakeRow>> mistakeRows({String? sessionId}) =>
      _mistakes.getAll(where: sessionId == null ? null : (t) => t.sessionId.equals(sessionId));

  /// The whole log, newest session first, each with its ayat and its
  /// mistakes.
  Future<List<TasmeeSession>> log() async =>
      TasmeeRows.sessions(await sessionRows(), await ayahRows(), await mistakeRows());

  Stream<List<TasmeeSession>> watchLog() =>
      _combine3(_sessions.watchAll(), _ayat.watchAll(), _mistakes.watchAll(), TasmeeRows.sessions);

  /// One session with its children, or null once it is gone.
  Future<TasmeeSession?> session(String id) async {
    final row = await _sessions.byId(id);
    if (row == null) return null;
    return TasmeeRows.session(row, ayat: await ayahRows(sessionId: id), mistakes: await mistakeRows(sessionId: id));
  }

  /// Every session that touched [ref], newest first.
  Future<List<TasmeeSession>> sessionsOf(AyahRef ref) async {
    final rows = await _ayat.getAll(where: (t) => t.surah.equals(ref.surah) & t.ayah.equals(ref.ayah));
    final ids = {for (final r in rows) r.sessionId};
    final all = await log();
    return [for (final s in all) if (ids.contains(s.id)) s];
  }

  /// The statistics, read off the log and nothing else.
  Future<TasmeeStats> stats() async => TasmeeStats.of(await log(), today: today);

  Stream<TasmeeStats> watchStats() => watchLog().map((log) => TasmeeStats.of(log, today: today));

  /// The weak words of one ayah, worst first (what Part 14 reads).
  Future<List<WeakWord>> weakWordsOf(AyahRef ref) async => (await stats()).weakWordsOf(ref);

  // -------------------------------------------------------------- writes ----

  /// Writes one finished recitation: the session, its ayat and the words
  /// that went wrong, in a single transaction.
  ///
  /// Returns the session as it was written and the undo that takes all
  /// three tables back.
  Future<(TasmeeSession, TasmeeUndo)> record(TasmeeSessionDraft draft) async {
    final keepHeard = (await settings()).keepHeardWords;
    final id = newId();
    final now = clock();
    final ayahIds = [for (var i = 0; i < draft.ayat.length; i++) newId()];
    final mistakeIds = [for (var i = 0; i < draft.mistakes.length; i++) newId()];
    await _db.transaction(() async {
      await _db.into(_db.tasmeeSessions).insert(
        TasmeeSessionsCompanion.insert(
          id: Value(id),
          startedAt: draft.startedAt,
          day: draft.day,
          mode: Value(draft.mode),
          fromSurah: draft.range.first.surah,
          fromAyah: draft.range.first.ayah,
          toSurah: draft.range.last.surah,
          toAyah: draft.range.last.ayah,
          wordCount: Value(draft.counts.words),
          rightCount: Value(draft.counts.right),
          wrongCount: Value(draft.counts.wrong),
          skippedCount: Value(draft.counts.skipped),
          unsureCount: Value(draft.counts.unsure),
          pendingCount: Value(draft.counts.pending),
          extraCount: Value(draft.counts.extras),
          hintCount: Value(draft.counts.hints),
          tashkeelDiffCount: Value(draft.counts.tashkeelDifferent),
          seconds: Value(draft.seconds),
          recogniserId: Value(draft.recogniserId),
          recogniserVersion: Value(draft.recogniserVersion),
          textSource: Value(draft.textSource),
          tashkeelChecked: Value(draft.tashkeelChecked),
          seed: Value(draft.seed),
          note: Value(draft.note),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _db.batch((b) {
        for (var i = 0; i < draft.ayat.length; i++) {
          final a = draft.ayat[i];
          b.insert(
            _db.tasmeeAyat,
            TasmeeAyatCompanion.insert(
              id: Value(ayahIds[i]),
              sessionId: id,
              day: a.day,
              surah: a.ref.surah,
              ayah: a.ref.ayah,
              wordCount: Value(a.counts.words),
              rightCount: Value(a.counts.right),
              wrongCount: Value(a.counts.wrong),
              skippedCount: Value(a.counts.skipped),
              unsureCount: Value(a.counts.unsure),
              pendingCount: Value(a.counts.pending),
              extraCount: Value(a.counts.extras),
              hintCount: Value(a.counts.hints),
              tashkeelDiffCount: Value(a.counts.tashkeelDifferent),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
        for (var i = 0; i < draft.mistakes.length; i++) {
          final m = draft.mistakes[i];
          b.insert(
            _db.tasmeeMistakes,
            TasmeeMistakesCompanion.insert(
              id: Value(mistakeIds[i]),
              sessionId: id,
              at: m.at,
              day: m.day,
              surah: m.ref.surah,
              ayah: m.ref.ayah,
              wordIndex: m.wordIndex,
              kind: m.kind,
              expected: m.expected,
              spanStart: m.start,
              spanEnd: m.end,
              heard: Value(keepHeard ? m.heard : null),
              hinted: Value(m.hinted),
              confidence: Value(m.confidence),
              tashkeelOnly: Value(m.tashkeelOnly),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
        }
      });
    });
    final written = await session(id);
    return (written!, () => _deleteSession(id));
  }

  /// Scores [check] and writes it in one step – the usual way a screen
  /// finishes a recitation.
  Future<(TasmeeSession, TasmeeUndo)> recordCheck(
    RecitationCheck check, {
    required TasmeeMode mode,
    required RecogniserInfo recogniser,
    DateTime? startedAt,
    int? seed,
    String? note,
  }) => record(
    TasmeeSessionDraft.ofCheck(
      check,
      startedAt: startedAt ?? clock(),
      mode: mode,
      recogniser: recogniser,
      seed: seed,
      note: note,
    ),
  );

  /// Deletes one session with everything that hangs on it; the undo puts
  /// all three tables back exactly as they were.
  Future<TasmeeUndo> deleteSession(String id) async {
    final row = await _sessions.byId(id);
    if (row == null) return () async {};
    final ayat = await ayahRows(sessionId: id);
    final mistakes = await mistakeRows(sessionId: id);
    await _deleteSession(id);
    return () async {
      await _sessions.restore(row);
      await _ayat.restoreAll(ayat);
      await _mistakes.restoreAll(mistakes);
    };
  }

  /// Clears the whole log (his own «امسح السجل»). The undo restores every
  /// row of all three tables.
  Future<TasmeeUndo> clearLog() async {
    final sessions = await sessionRows();
    final ayat = await ayahRows();
    final mistakes = await mistakeRows();
    await _db.transaction(() async {
      await _mistakes.deleteWhere((t) => const Constant(true));
      await _ayat.deleteWhere((t) => const Constant(true));
      await _sessions.deleteWhere((t) => const Constant(true));
    });
    return () async {
      await _sessions.restoreAll(sessions);
      await _ayat.restoreAll(ayat);
      await _mistakes.restoreAll(mistakes);
    };
  }

  Future<void> _deleteSession(String id) => _db.transaction(() async {
    await _mistakes.deleteWhere((t) => t.sessionId.equals(id));
    await _ayat.deleteWhere((t) => t.sessionId.equals(id));
    await _sessions.delete(id);
  });

  // -------------------------------------------------------------- export ----

  /// The log as the documented JSON «فلك» reads (see [TasmeeExport]).
  Future<Map<String, Object?>> exportJson({DateTime? exportedAt, bool? includeHeard}) async {
    final keep = includeHeard ?? (await settings()).keepHeardWords;
    return TasmeeExport.build(
      await log(),
      exportedAt: exportedAt ?? clock(),
      today: today,
      includeHeard: keep,
    );
  }

  static Stream<R> _combine3<A, B, C, R>(
    Stream<A> a,
    Stream<B> b,
    Stream<C> c,
    R Function(A, B, C) build,
  ) {
    late StreamController<R> out;
    StreamSubscription<A>? sa;
    StreamSubscription<B>? sb;
    StreamSubscription<C>? sc;
    A? lastA;
    B? lastB;
    C? lastC;
    var hasA = false, hasB = false, hasC = false;
    void emit() {
      if (hasA && hasB && hasC) out.add(build(lastA as A, lastB as B, lastC as C));
    }

    out = StreamController<R>(
      onListen: () {
        sa = a.listen((v) {
          lastA = v;
          hasA = true;
          emit();
        }, onError: out.addError);
        sb = b.listen((v) {
          lastB = v;
          hasB = true;
          emit();
        }, onError: out.addError);
        sc = c.listen((v) {
          lastC = v;
          hasC = true;
          emit();
        }, onError: out.addError);
      },
      onCancel: () async {
        await sa?.cancel();
        await sb?.cancel();
        await sc?.cancel();
      },
    );
    return out.stream;
  }
}
