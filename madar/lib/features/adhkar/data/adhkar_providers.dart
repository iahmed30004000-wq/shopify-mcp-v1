import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../orbit/data/orbit_providers.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../domain/adhkar_models.dart';
import '../domain/adhkar_reminders.dart';
import '../domain/adhkar_session.dart';
import '../domain/adhkar_timing.dart';
import '../domain/tasbeeh.dart';
import 'adhkar_activity.dart';
import 'adhkar_loader.dart';
import 'adhkar_notifications.dart';
import 'adhkar_progress_store.dart';
import 'dhikr_audio.dart';
import 'tasbeeh_store.dart';

// ------------------------------------------------------------ content ----

/// Where the bundled JSON is read from (overridable in tests).
final adhkarAssetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// The bundled Hisn al-Muslim library (validated on load).
final adhkarLibraryProvider = FutureProvider<AdhkarLibrary>(
  (ref) => AdhkarLoader(ref.watch(adhkarAssetBundleProvider)).load(),
);

// --------------------------------------------------------------- time ----

/// Wall clock (follows the orbit's, so tests freeze everything at once).
final adhkarClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// The prayer schedule the adhkar day and windows come from.
final adhkarScheduleProvider = Provider<PrayerSchedule>((ref) => ref.watch(prayerScheduleProvider));

/// "Now" for everything time-dependent in the adhkar (the day, the window,
/// the suggestion): read from [adhkarClockProvider] and refreshed at the
/// next boundary – the end of the prayer window, the night's middle and
/// last third, local midnight – and whenever the app returns to the
/// foreground, so an open screen moves on at Fajr, Asr … by itself.
final adhkarNowProvider = NotifierProvider<AdhkarNow, DateTime>(AdhkarNow.new);

class AdhkarNow extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.watch(orbitTodayProvider); // local midnight and returns to the foreground
    final clock = ref.watch(adhkarClockProvider);
    final schedule = ref.watch(adhkarScheduleProvider);
    ref.onDispose(() => _timer?.cancel());
    return _arm(clock, schedule);
  }

  DateTime _arm(DateTime Function() clock, PrayerSchedule schedule) {
    _timer?.cancel();
    final now = clock();
    final next = AdhkarTiming.nextBoundary(
      now,
      windowEnd: schedule.windowAt(now).end,
      night: adhkarNightOf(schedule, schedule.prayerDayOf(now)),
    );
    var delay = next.difference(now) + const Duration(seconds: 1);
    // A frozen (test) clock never reaches the boundary: poll gently instead.
    if (delay <= Duration.zero) delay = const Duration(minutes: 1);
    _timer = Timer(delay, () {
      final t = _arm(clock, schedule);
      if (t != state) state = t;
    });
    return now;
  }
}

/// The night (Maghrib → next Fajr) of prayer day [day].
AdhkarNight adhkarNightOf(PrayerSchedule schedule, DateTime day) => AdhkarNight(
  maghrib: schedule.timesFor(day).maghrib,
  fajr: schedule.timesFor(DateTime(day.year, day.month, day.day + 1)).fajr,
);

/// The prayer-anchored day progress belongs to (a new day starts at Fajr, so
/// the sleep adhkar said after midnight still count for the evening before).
/// The on-waking set has its own day: [adhkarSetDayProvider].
final adhkarDayProvider = Provider<DateTime>(
  (ref) => ref.watch(adhkarScheduleProvider).prayerDayOf(ref.watch(adhkarNowProvider)),
);

/// The night of today's prayer day.
final adhkarNightProvider = Provider<AdhkarNight>(
  (ref) => adhkarNightOf(ref.watch(adhkarScheduleProvider), ref.watch(adhkarDayProvider)),
);

/// The day [AdhkarCategoryId]'s progress belongs to now: the prayer day,
/// except for the on-waking set, which from the middle of the night belongs
/// to the coming day (see [AdhkarTiming.dayFor]).
final adhkarSetDayProvider = Provider.family<DateTime, AdhkarCategoryId>(
  (ref, category) => AdhkarTiming.dayFor(
    category,
    ref.watch(adhkarDayProvider),
    ref.watch(adhkarNowProvider),
    ref.watch(adhkarNightProvider),
  ),
);

/// The prayer window of "now".
final adhkarWindowProvider = Provider<PrayerWindow>(
  (ref) => ref.watch(adhkarScheduleProvider).windowAt(ref.watch(adhkarNowProvider)).window,
);

// ------------------------------------------------------------ progress ----

final adhkarProgressStoreProvider = Provider<AdhkarProgressStore>(
  (ref) => AdhkarProgressStore(ref.watch(repositoriesProvider).keyValues),
);

/// Today's (prayer-day) progress of every set.
final adhkarDayProgressProvider = StreamProvider.autoDispose<Map<AdhkarSetKey, AdhkarProgress>>(
  (ref) => ref.watch(adhkarProgressStoreProvider).watchDay(ref.watch(adhkarDayProvider)),
);

/// The kept days' progress (each set is read on its own day).
final adhkarProgressDaysProvider = StreamProvider.autoDispose<AdhkarProgressDays>(
  (ref) => ref.watch(adhkarProgressStoreProvider).watchDays(),
);

/// Writes set completions and tasbeeh sessions to the activity log through
/// the orbit's pulse hub (the Faith world pulses at once).
final adhkarCompletionRecorderProvider = Provider<AdhkarCompletionRecorder>((ref) {
  final hub = ref.watch(orbitPulseHubProvider);
  return ({required kind, required refTable, required refId, required at, value, payload = const {}}) =>
      hub.recordCompletion(AdhkarActivity.planetKey, kind, refTable, refId, at: at, value: value, payload: payload);
});

/// The reader's counter for one set (resumes today's progress).
final adhkarSessionProvider = AsyncNotifierProvider.autoDispose
    .family<AdhkarSessionController, AdhkarSession, AdhkarSetKey>(AdhkarSessionController.new);

/// Drives [AdhkarSession] and persists every change (today's progress in
/// the key/value store; a finished set in the activity log, once a day).
class AdhkarSessionController extends AsyncNotifier<AdhkarSession> {
  AdhkarSessionController(this.setKey);

  final AdhkarSetKey setKey;
  late DateTime _day;
  late AdhkarProgressStore _store;
  late DateTime Function() _clock;

  @override
  Future<AdhkarSession> build() async {
    final library = await ref.watch(adhkarLibraryProvider.future);
    // Read once: a set being read keeps its day even if the day turns.
    _day = ref.read(adhkarSetDayProvider(setKey.category));
    _store = ref.read(adhkarProgressStoreProvider);
    _clock = ref.read(adhkarClockProvider);
    final progress = await _store.load(_day, setKey);
    return AdhkarSession.start(library.category(setKey.category), prayer: setKey.prayer, resume: progress);
  }

  /// The day this session's progress is stored under.
  DateTime get day => _day;

  AdhkarSession? get _session => state.value;

  Future<void> _commit(AdhkarSession next) {
    state = AsyncData(next);
    return _store.save(_day, setKey, next.toProgress());
  }

  /// Counts one repetition of the current dhikr.
  Future<AdhkarTapOutcome> tap() async {
    final s = _session;
    if (s == null) return AdhkarTapOutcome.alreadyDone;
    final (next, outcome) = s.tap(_clock());
    if (outcome == AdhkarTapOutcome.alreadyDone) return outcome;
    if (outcome == AdhkarTapOutcome.setCompleted) {
      await _complete(next, marked: false);
    } else {
      await _commit(next);
    }
    return outcome;
  }

  /// Moves to the next unfinished dhikr.
  Future<void> advance() async {
    final s = _session;
    if (s != null) await _commit(s.advance());
  }

  Future<void> goTo(int index) async {
    final s = _session;
    if (s != null && s.index != index) await _commit(s.goTo(index));
  }

  Future<void> resetCurrent() async {
    final s = _session;
    if (s != null) await _commit(s.resetCurrent());
  }

  /// Starts the set over; returns an undo.
  Future<Future<void> Function()> resetAll() async {
    final before = _session;
    if (before != null) await _commit(before.resetAll());
    return () async {
      if (before != null) await _commit(before);
    };
  }

  /// Marks the whole set as said (logged to the activity stream); returns
  /// an undo that restores the counts and removes the log entry it wrote.
  Future<Future<void> Function()> markDone() async {
    final before = _session;
    if (before == null || before.isComplete) return () async {};
    final wrote = await _complete(before.markDone(_clock()), marked: true);
    final repos = ref.read(repositoriesProvider);
    final refId = AdhkarActivity.refIdFor(setKey, _day);
    return () async {
      if (wrote) await repos.activity.removeFor(refTable: AdhkarActivity.refTable, refId: refId);
      await _commit(before);
    };
  }

  /// Saves a completed session and logs it once per day. Returns whether a
  /// log entry was written.
  Future<bool> _complete(AdhkarSession done, {required bool marked}) async {
    if (done.logged) {
      await _commit(done);
      return false;
    }
    final logged = done.markLogged();
    await _commit(logged);
    await ref.read(adhkarCompletionRecorderProvider)(
      kind: AdhkarActivity.kindFor(setKey.category),
      refTable: AdhkarActivity.refTable,
      refId: AdhkarActivity.refIdFor(setKey, _day),
      at: _clock(),
      value: done.length.toDouble(),
      payload: {'set': setKey.storageKey, 'day': AdhkarTiming.dayKey(_day), if (marked) 'marked': true},
    );
    return true;
  }
}

/// Whole-set actions outside the reader (the home cards): mark a set done
/// or start it over, each with an undo.
final adhkarSetServiceProvider = Provider<AdhkarSetService>((ref) => AdhkarSetService(ref));

class AdhkarSetService {
  AdhkarSetService(this._ref);

  final Ref _ref;

  Future<(AdhkarSession, AdhkarProgress?, DateTime)> _load(AdhkarSetKey key) async {
    final library = await _ref.read(adhkarLibraryProvider.future);
    final day = _ref.read(adhkarSetDayProvider(key.category));
    final previous = await _ref.read(adhkarProgressStoreProvider).load(day, key);
    return (AdhkarSession.start(library.category(key.category), prayer: key.prayer, resume: previous), previous, day);
  }

  Future<void> _restore(DateTime day, AdhkarSetKey key, AdhkarProgress? previous) {
    final store = _ref.read(adhkarProgressStoreProvider);
    return previous == null ? store.remove(day, key) : store.save(day, key, previous);
  }

  /// Marks [key] said today (logged once to the activity stream).
  Future<Future<void> Function()> markDone(AdhkarSetKey key) async {
    final (session, previous, day) = await _load(key);
    if (session.isComplete) return () async {};
    final done = session.markDone(_ref.read(adhkarClockProvider)());
    final wrote = !done.logged;
    await _ref.read(adhkarProgressStoreProvider).save(day, key, done.markLogged().toProgress());
    final refId = AdhkarActivity.refIdFor(key, day);
    if (wrote) {
      await _ref.read(adhkarCompletionRecorderProvider)(
        kind: AdhkarActivity.kindFor(key.category),
        refTable: AdhkarActivity.refTable,
        refId: refId,
        at: _ref.read(adhkarClockProvider)(),
        value: session.length.toDouble(),
        payload: {'set': key.storageKey, 'day': AdhkarTiming.dayKey(day), 'marked': true},
      );
    }
    final repos = _ref.read(repositoriesProvider);
    return () async {
      if (wrote) await repos.activity.removeFor(refTable: AdhkarActivity.refTable, refId: refId);
      await _restore(day, key, previous);
    };
  }

  /// Clears today's progress of [key] (a logged completion stays logged).
  Future<Future<void> Function()> restart(AdhkarSetKey key) async {
    final (session, previous, day) = await _load(key);
    await _ref.read(adhkarProgressStoreProvider).save(day, key, session.resetAll().toProgress());
    return () => _restore(day, key, previous);
  }
}

// ------------------------------------------------------ reader prefs ----

/// Per-user reader preferences (encrypted key/value store `adhkar.reader`).
@immutable
class AdhkarReaderPrefs {
  const AdhkarReaderPrefs({this.textScale = 1.0, this.showTranslation = true, this.showVirtue = true});

  static const double minScale = 0.8;
  static const double maxScale = 1.8;

  /// Multiplies the dhikr text size (base 26 logical px).
  final double textScale;

  /// Shows the English meaning in the English UI (when licensed).
  final bool showTranslation;

  /// Shows the virtue under the dhikr.
  final bool showVirtue;

  AdhkarReaderPrefs copyWith({double? textScale, bool? showTranslation, bool? showVirtue}) => AdhkarReaderPrefs(
    textScale: (textScale ?? this.textScale).clamp(minScale, maxScale),
    showTranslation: showTranslation ?? this.showTranslation,
    showVirtue: showVirtue ?? this.showVirtue,
  );

  Map<String, Object?> toJson() => {
    'textScale': textScale,
    'showTranslation': showTranslation,
    'showVirtue': showVirtue,
  };

  factory AdhkarReaderPrefs.fromJson(Object? json) {
    if (json is! Map) return const AdhkarReaderPrefs();
    final s = json['textScale'];
    return AdhkarReaderPrefs(
      textScale: s is num && s.isFinite ? s.toDouble().clamp(minScale, maxScale) : 1.0,
      showTranslation: json['showTranslation'] != false,
      showVirtue: json['showVirtue'] != false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdhkarReaderPrefs &&
      other.textScale == textScale &&
      other.showTranslation == showTranslation &&
      other.showVirtue == showVirtue;

  @override
  int get hashCode => Object.hash(textScale, showTranslation, showVirtue);
}

const String _readerPrefsKey = 'adhkar.reader';

final adhkarReaderPrefsProvider = StreamProvider<AdhkarReaderPrefs>(
  (ref) => ref.watch(repositoriesProvider).keyValues.watchJson(_readerPrefsKey).map(AdhkarReaderPrefs.fromJson),
);

/// Saves [prefs].
final adhkarReaderPrefsWriterProvider = Provider<Future<void> Function(AdhkarReaderPrefs prefs)>((ref) {
  final kv = ref.watch(repositoriesProvider).keyValues;
  return (prefs) => kv.setJson(_readerPrefsKey, prefs.toJson());
});

// --------------------------------------------------------- summary ----

/// Today at a glance: progress of every set, the after-prayer sets done,
/// the tasbeeh total and the set that fits the moment.
@immutable
class AdhkarDaySummary {
  const AdhkarDaySummary({
    required this.progress,
    required this.started,
    required this.afterPrayerDone,
    required this.suggested,
    required this.suggestedPrayer,
    required this.resumeIndex,
  });

  /// 0…1 per set (after-prayer: prayers finished / 5).
  final Map<AdhkarCategoryId, double> progress;

  /// Sets with anything counted today.
  final Set<AdhkarCategoryId> started;

  /// After-prayer sets finished today.
  final Set<Prayer> afterPrayerDone;
  final AdhkarCategoryId suggested;

  /// The prayer whose after-prayer adhkar apply now.
  final Prayer suggestedPrayer;

  /// Page to resume per set (1-based position shown to the user).
  final Map<AdhkarCategoryId, int> resumeIndex;

  bool isDone(AdhkarCategoryId c) => (progress[c] ?? 0) >= 1;

  /// Whether the suggested set is already said (the after-prayer set: after
  /// [suggestedPrayer]).
  bool get suggestedDone =>
      suggested == AdhkarCategoryId.afterPrayer ? afterPrayerDone.contains(suggestedPrayer) : isDone(suggested);

  int get setsDone => AdhkarCategoryId.values.where(isDone).length;
}

final adhkarDaySummaryProvider = Provider.autoDispose<AsyncValue<AdhkarDaySummary>>((ref) {
  final library = ref.watch(adhkarLibraryProvider);
  final stored = ref.watch(adhkarProgressDaysProvider);
  final window = ref.watch(adhkarWindowProvider);
  final now = ref.watch(adhkarNowProvider);
  final night = ref.watch(adhkarNightProvider);
  if (library.hasError) return AsyncError(library.error!, library.stackTrace!);
  final lib = library.value, days = stored.value;
  if (lib == null || days == null) return const AsyncLoading();
  final progress = <AdhkarCategoryId, double>{};
  final started = <AdhkarCategoryId>{};
  final resume = <AdhkarCategoryId, int>{};
  final prayersDone = <Prayer>{};
  for (final c in lib.categories) {
    // Each set on its own day (the on-waking set turns at mid-night).
    final sets = days[AdhkarTiming.dayKey(ref.watch(adhkarSetDayProvider(c.id)))] ?? const {};
    if (c.id == AdhkarCategoryId.afterPrayer) {
      for (final p in kObligatoryPrayers) {
        final pr = sets[AdhkarSetKey(c.id, p)];
        if (pr == null) continue;
        final s = AdhkarSession.start(c, prayer: p, resume: pr);
        if (s.isStarted) started.add(c.id);
        if (s.isComplete || s.progress >= 1) prayersDone.add(p);
      }
      progress[c.id] = prayersDone.length / kObligatoryPrayers.length;
      continue;
    }
    final pr = sets[AdhkarSetKey(c.id)];
    final s = AdhkarSession.start(c, resume: pr);
    progress[c.id] = s.isComplete ? 1 : s.progress;
    if (s.isStarted) {
      started.add(c.id);
      resume[c.id] = s.index + 1;
    }
  }
  return AsyncData(
    AdhkarDaySummary(
      progress: progress,
      started: started,
      afterPrayerDone: prayersDone,
      suggested: AdhkarTiming.suggestAt(
        window: window,
        now: now,
        night: night,
        isDone: (c, p) => c == AdhkarCategoryId.afterPrayer ? prayersDone.contains(p) : (progress[c] ?? 0) >= 1,
      ),
      suggestedPrayer: AdhkarTiming.lastPrayer(window),
      resumeIndex: resume,
    ),
  );
});

// ------------------------------------------------------------- tasbeeh ----

final tasbeehStoreProvider = Provider<TasbeehStore>((ref) => TasbeehStore(ref.watch(repositoriesProvider)));

/// The editable phrase list.
final tasbeehPhrasesProvider = StreamProvider.autoDispose<List<TasbeehPhrase>>(
  (ref) => ref.watch(tasbeehStoreProvider).watchPhrases(),
);

/// Tasbeeh sessions of the last 30 days, newest first.
final tasbeehHistoryProvider = StreamProvider.autoDispose<List<TasbeehSession>>((ref) {
  final day = ref.watch(adhkarDayProvider);
  return ref.watch(tasbeehStoreProvider).watchSessions(day.subtract(const Duration(days: 30)));
});

/// Today's (prayer-day) tasbeeh total.
final tasbeehTodayCountProvider = Provider.autoDispose<int>((ref) {
  final sessions = ref.watch(tasbeehHistoryProvider).value ?? const <TasbeehSession>[];
  final schedule = ref.watch(adhkarScheduleProvider);
  final day = ref.watch(adhkarDayProvider);
  final start = schedule.timesFor(day).fajr;
  final end = schedule.timesFor(DateTime(day.year, day.month, day.day + 1)).fajr;
  return TasbeehStore.totalOn(sessions, start, end);
});

/// What the tasbeeh screen shows.
@immutable
class TasbeehState {
  const TasbeehState({required this.phrases, required this.phraseId, required this.counter, this.sessionId});

  final List<TasbeehPhrase> phrases;
  final String? phraseId;
  final TasbeehCounter counter;

  /// Activity-log row of the session being counted.
  final String? sessionId;

  TasbeehPhrase? get phrase =>
      phrases.where((p) => p.id == phraseId).firstOrNull ?? (phrases.isEmpty ? null : phrases.first);

  TasbeehState copyWith({
    List<TasbeehPhrase>? phrases,
    String? phraseId,
    TasbeehCounter? counter,
    String? sessionId,
    bool clearSession = false,
  }) => TasbeehState(
    phrases: phrases ?? this.phrases,
    phraseId: phraseId ?? this.phraseId,
    counter: counter ?? this.counter,
    sessionId: clearSession ? null : (sessionId ?? this.sessionId),
  );
}

final tasbeehControllerProvider = AsyncNotifierProvider.autoDispose<TasbeehController, TasbeehState>(
  TasbeehController.new,
);

/// The tasbeeh: counts, rounds, phrase and target choice, the editable
/// phrase list, and sessions in the activity log (value = count).
///
/// A session starts with the first tap and ends on reset, on a change of
/// phrase or target, or with the day; its count is written on every round
/// and shortly after the last tap.
class TasbeehController extends AsyncNotifier<TasbeehState> {
  static const Duration writeDelay = Duration(milliseconds: 1200);

  late TasbeehStore _store;
  late DateTime Function() _clock;
  late String _day;
  Timer? _writeTimer;
  Future<String>? _starting;
  bool _dirty = false;

  @override
  Future<TasbeehState> build() async {
    _store = ref.read(tasbeehStoreProvider);
    _clock = ref.read(adhkarClockProvider);
    _day = AdhkarTiming.dayKey(ref.read(adhkarDayProvider));
    final phrases = await _store.loadPhrases();
    final saved = await _store.loadState();
    final sameDay = saved?.day == _day;
    final phraseId = phrases.any((p) => p.id == saved?.phraseId) ? saved!.phraseId : phrases.firstOrNull?.id;
    final target = saved?.target ?? TasbeehDefaults.defaultTarget;
    ref.onDispose(() {
      _writeTimer?.cancel();
      final s = _latest;
      if (s != null && _dirty) unawaited(_flushState(s));
    });
    return _latest = TasbeehState(
      phrases: phrases,
      phraseId: phraseId,
      counter: TasbeehCounter(target: target, count: sameDay ? saved!.count : 0),
      sessionId: sameDay ? saved!.sessionId : null,
    );
  }

  /// The last state set (readable from `onDispose`, where `state` is not).
  TasbeehState? _latest;

  TasbeehState? get _s => state.value;

  @override
  set state(AsyncValue<TasbeehState> value) {
    super.state = value;
    if (value.value != null) _latest = value.value;
  }

  /// One bead. Null when there is no phrase to count.
  Future<TasbeehTapOutcome?> tap() async {
    final s = _s;
    final phrase = s?.phrase;
    if (s == null || phrase == null) return null;
    final (counter, outcome) = s.counter.tap();
    state = AsyncData(s.copyWith(counter: counter));
    _dirty = true;
    if (s.sessionId == null) {
      _starting ??= _store.startSession(phrase: phrase, target: counter.target, count: counter.count, at: _clock());
      final id = await _starting!;
      _starting = null;
      final now = _s!;
      if (now.sessionId == null) state = AsyncData(now.copyWith(sessionId: id));
      _scheduleWrite(immediate: outcome == TasbeehTapOutcome.round);
    } else {
      _scheduleWrite(immediate: outcome == TasbeehTapOutcome.round);
    }
    return outcome;
  }

  void _scheduleWrite({bool immediate = false}) {
    _writeTimer?.cancel();
    if (immediate) {
      unawaited(flush());
    } else {
      _writeTimer = Timer(writeDelay, () => unawaited(flush()));
    }
  }

  /// Writes the running count now (session row and saved state).
  Future<void> flush() async {
    _writeTimer?.cancel();
    final s = _s;
    if (s == null || !_dirty) return;
    await _flushState(s);
  }

  Future<void> _flushState(TasbeehState s) async {
    _dirty = false;
    final id = s.sessionId;
    if (id != null) await _store.updateSession(id, s.counter.count);
    await _store.saveState(
      TasbeehSavedState(
        phraseId: s.phrase?.id ?? '',
        target: s.counter.target,
        count: s.counter.count,
        sessionId: s.sessionId,
        day: _day,
      ),
    );
  }

  /// Ends the session and starts counting from zero.
  Future<void> reset() async {
    await flush();
    final s = _s;
    if (s == null) return;
    state = AsyncData(s.copyWith(counter: s.counter.reset(), clearSession: true));
    _dirty = true;
    await flush();
  }

  Future<void> selectPhrase(String id) async {
    final s = _s;
    if (s == null || s.phrase?.id == id) return;
    await flush();
    state = AsyncData(s.copyWith(phraseId: id, counter: s.counter.reset(), clearSession: true));
    _dirty = true;
    await flush();
  }

  Future<void> setTarget(int target) async {
    final s = _s;
    if (s == null || s.counter.target == target) return;
    await flush();
    state = AsyncData(s.copyWith(counter: TasbeehCounter(target: target), clearSession: true));
    _dirty = true;
    await flush();
  }

  Future<void> _savePhrases(List<TasbeehPhrase> phrases, {String? selectId}) async {
    final s = _s;
    if (s == null) return;
    final keep = phrases.any((p) => p.id == s.phraseId);
    state = AsyncData(
      s.copyWith(
        phrases: phrases,
        phraseId: selectId ?? (keep ? s.phraseId : phrases.firstOrNull?.id),
        counter: keep && selectId == null ? null : s.counter.reset(),
        clearSession: !(keep && selectId == null),
      ),
    );
    await _store.savePhrases(phrases);
    _dirty = true;
    await flush();
  }

  /// Adds a phrase and selects it.
  Future<TasbeehPhrase?> addPhrase(String text) async {
    final s = _s;
    final t = text.trim();
    if (s == null || t.isEmpty) return null;
    final phrase = TasbeehPhrase(id: 'user-${const Uuid().v4()}', text: t);
    await flush();
    await _savePhrases([...s.phrases, phrase], selectId: phrase.id);
    return phrase;
  }

  Future<void> editPhrase(String id, String text) async {
    final s = _s;
    final t = text.trim();
    if (s == null || t.isEmpty) return;
    await _savePhrases([for (final p in s.phrases) p.id == id ? p.copyWith(text: t) : p]);
  }

  /// Removes a phrase; returns an undo.
  Future<Future<void> Function()> deletePhrase(String id) async {
    final s = _s;
    if (s == null) return () async {};
    final before = s.phrases;
    final selected = s.phraseId;
    await _savePhrases([
      for (final p in before)
        if (p.id != id) p,
    ]);
    return () async => _savePhrases(before, selectId: selected == id ? id : null);
  }

  Future<void> reorderPhrases(List<TasbeehPhrase> ordered) => _savePhrases(ordered);

  /// Deletes session [id] from the history; returns an undo (null when it
  /// was already gone). Deleting the session being counted also clears the
  /// counter – its taps went with it, and later taps would otherwise land in
  /// a row that no longer exists; the undo brings both back.
  Future<Future<void> Function()?> deleteSession(String id) async {
    final s = _s;
    final live = s != null && s.sessionId == id;
    if (live) await flush(); // the row carries the latest count for the undo
    final row = await _store.deleteSession(id);
    if (row == null) return null;
    if (live) {
      final now = _s!;
      state = AsyncData(now.copyWith(counter: now.counter.reset(), clearSession: true));
      _dirty = true;
      await flush();
    }
    return () async {
      await _store.restoreSession(row);
      final now = _s;
      if (!live || now == null || now.sessionId != null || now.counter.count != 0) return;
      if (now.phrase?.id != s.phrase?.id || now.counter.target != s.counter.target) return;
      state = AsyncData(now.copyWith(counter: TasbeehCounter(target: now.counter.target, count: (row.value ?? 0).round()), sessionId: id));
      _dirty = true;
      await flush();
    };
  }
}

// ------------------------------------------------------------ reminders ----

/// Delivers the reminders: Madar's notification service
/// ([adhkarNotificationSchedulerProvider]). Tests override it (or the
/// notification platform) with a fake; [NoopAdhkarReminderScheduler]
/// schedules nothing.
final adhkarReminderSchedulerProvider = Provider<AdhkarReminderScheduler>(
  (ref) => ref.watch(adhkarNotificationSchedulerProvider),
);

/// The UI language's strings (for texts built outside the widget tree).
L10n adhkarL10nOf(Ref ref) => lookupL10n(ref.read(appSettingsProvider).locale);

/// The real scheduler: Madar's notification service, adhkar id block,
/// channel named in the UI language.
final adhkarNotificationSchedulerProvider = Provider<AdhkarReminderScheduler>(
  (ref) => NotificationAdhkarReminderScheduler(
    notifications: ref.watch(notificationServiceProvider),
    texts: () {
      final l = adhkarL10nOf(ref);
      return (
        group: l.adhkarTitle,
        name: l.adhkarReminderChannelName,
        description: l.adhkarReminderChannelDescription,
      );
    },
  ),
);

const String _remindersKey = 'adhkar.reminders';

final adhkarReminderSettingsProvider = StreamProvider<AdhkarReminderSettings>(
  (ref) => ref.watch(repositoriesProvider).keyValues.watchJson(_remindersKey).map(AdhkarReminderSettings.fromJson),
);

final adhkarReminderServiceProvider = Provider<AdhkarReminderService>(
  (ref) => AdhkarReminderService(
    kv: ref.watch(repositoriesProvider).keyValues,
    scheduler: ref.watch(adhkarReminderSchedulerProvider),
    schedule: () => ref.read(adhkarScheduleProvider),
    clock: ref.watch(adhkarClockProvider),
    l10n: () => adhkarL10nOf(ref),
  ),
);

/// Plans "morning adhkar after Fajr" / "evening adhkar after Asr" reminders
/// from the prayer times and hands them to the [AdhkarReminderScheduler].
///
/// Call [reschedule] at start-up, after the prayer settings or the language
/// change and once a day (the planner looks [days] ahead).
class AdhkarReminderService {
  AdhkarReminderService({
    required this.kv,
    required this.scheduler,
    required this.schedule,
    required this.clock,
    this.l10n,
  });

  final KeyValueRepository kv;
  final AdhkarReminderScheduler scheduler;
  final PrayerSchedule Function() schedule;
  final DateTime Function() clock;

  /// The default language of the texts (the app's).
  final L10n Function()? l10n;

  Future<AdhkarReminderSettings> load() async => AdhkarReminderSettings.fromJson(await kv.getJson(_remindersKey));

  /// Saves [settings] and reschedules.
  Future<List<AdhkarReminderNotice>> update(AdhkarReminderSettings settings, [L10n? l10n]) async {
    await kv.setJson(_remindersKey, settings.toJson());
    return reschedule(l10n: l10n);
  }

  /// Asks for the notification permission when a reminder is being switched
  /// on; true when reminders can be shown.
  Future<bool> ensurePermission() => scheduler.ensurePermission();

  /// Replaces the scheduled adhkar reminders (none when switched off). The
  /// texts are in [l10n], by default the app's language.
  Future<List<AdhkarReminderNotice>> reschedule({L10n? l10n, int days = 7}) async {
    final l = l10n ?? this.l10n?.call();
    if (l == null) throw StateError('AdhkarReminderService.reschedule: no localisations');
    final settings = await load();
    if (!settings.anyEnabled) {
      await scheduler.cancelAll();
      return const [];
    }
    final s = schedule();
    final reminders = AdhkarReminderPlanner.plan(settings: settings, timesFor: s.timesFor, now: clock(), days: days);
    final notices = [
      for (final r in reminders)
        AdhkarReminderNotice(
          reminder: r,
          title: r.category == AdhkarCategoryId.morning ? l.adhkarReminderMorningTitle : l.adhkarReminderEveningTitle,
          body: r.category == AdhkarCategoryId.morning ? l.adhkarReminderMorningBody : l.adhkarReminderEveningBody,
        ),
    ];
    await scheduler.replaceAll(notices);
    return notices;
  }
}

/// Keeps the adhkar reminders planned (a week ahead): at start and whenever
/// the reminder settings, the prayer settings (location, method…), the
/// language or the day change. Watch it once from the app root, next to the
/// adhan's sync; its state is the last plan (null before the first).
final adhkarReminderSyncProvider = NotifierProvider<AdhkarReminderSync, List<AdhkarReminderNotice>?>(
  AdhkarReminderSync.new,
);

class AdhkarReminderSync extends Notifier<List<AdhkarReminderNotice>?> {
  static const Duration debounce = Duration(milliseconds: 400);

  Timer? _debounce;
  bool _running = false;
  bool _again = false;

  @override
  List<AdhkarReminderNotice>? build() {
    ref.listen(adhkarReminderSettingsProvider, (_, _) => _schedule());
    ref.listen(prayerSettingsProvider, (_, _) => _schedule());
    ref.listen(appSettingsProvider.select((s) => s.languageCode), (_, _) => _schedule());
    ref.listen(orbitTodayProvider, (_, _) => _schedule());
    ref.onDispose(() => _debounce?.cancel());
    _schedule();
    return null;
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(debounce, () => unawaited(syncNow()));
  }

  /// Re-plans now (once more after a running one).
  Future<void> syncNow() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      // Not before the stored location has loaded: a plan for the default
      // city would be wrong. The listener runs it once it arrives.
      if (!ref.read(prayerSettingsProvider).hasValue) return;
      final notices = await ref.read(adhkarReminderServiceProvider).reschedule();
      if (ref.mounted) state = notices;
    } catch (e, st) {
      debugPrint('AdhkarReminderSync failed: $e\n$st');
    } finally {
      _running = false;
      if (_again && ref.mounted) {
        _again = false;
        _schedule();
      }
    }
  }
}

// --------------------------------------------------------------- audio ----

final dhikrAudioStoreProvider = Provider<DhikrAudioStore>(
  (ref) => FileDhikrAudioStore(ref.watch(repositoriesProvider).keyValues),
);

/// Attached recordings by dhikr id.
final dhikrAudioInfoProvider = StreamProvider.autoDispose<Map<String, DhikrAudioInfo>>(
  (ref) => ref.watch(dhikrAudioStoreProvider).watch(),
);

/// Opens the system file picker (overridden in tests).
final dhikrAudioPickerProvider = Provider<Future<PickedAudio?> Function()>((ref) => pickDhikrAudio);

final dhikrAudioPlayerProvider = Provider.autoDispose<DhikrAudioPlayer>((ref) {
  final player = SoloudDhikrAudioPlayer(ref.watch(soundServiceProvider));
  ref.onDispose(() => unawaited(player.dispose()));
  return player;
});
