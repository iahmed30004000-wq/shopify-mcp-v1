import 'dart:io';

import 'package:file_picker/file_picker.dart' show PlatformFile;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_providers.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/domain/score_sources.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import 'adhkar_harness.dart';

/// A picked file whose size is known without reading it.
final class _FakePickedFile extends PlatformFile {
  _FakePickedFile(this.name, {required this.size, this.bytes});

  @override
  final String name;
  final int size;
  final Uint8List? bytes;
  int reads = 0;

  @override
  Uri get uri => Uri.file('/picked/$name');

  @override
  get xFile => throw UnimplementedError();

  @override
  int? lengthSync() => size;

  @override
  Future<int?> length() async => size;

  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    return bytes ?? Uint8List(size);
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes ?? Uint8List(0));
}

class _RecordingScheduler implements AdhkarReminderScheduler {
  List<AdhkarReminderNotice>? last;
  int cancels = 0;

  @override
  Future<void> replaceAll(List<AdhkarReminderNotice> notices) async => last = notices;

  @override
  Future<void> cancelAll() async => cancels++;

  bool allow = true;
  int permissionRequests = 0;

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    return allow;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final library = loadBundledLibrary();
  late MadarDatabase db;
  late SharedPreferences prefs;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = testDatabase();
    now = DateTime(2026, 9, 28, 17, 10); // Asr window in Amman
  });

  tearDown(() => db.close());

  ProviderContainer container({List overrides = const []}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        homeClockProvider.overrideWithValue(() => now),
        hapticsServiceProvider.overrideWithValue(RecordingHaptics()),
        adhkarLibraryProvider.overrideWith((ref) async => library),
        notificationPlatformProvider.overrideWithValue(FakeNotificationPlatform()),
        // On the test clock, not the wall clock (requests in its past are dropped).
        notificationServiceProvider.overrideWith((ref) {
          final service = NotificationService(ref.watch(notificationPlatformProvider), clock: () => now);
          ref.onDispose(service.dispose);
          return service;
        }),
        ...overrides.cast(),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<ActivityRow>> adhkarLog() => (db.select(db.activityLog)..where((t) => t.kind.like('adhkar%'))).get();

  group('reader session', () {
    const waking = AdhkarSetKey(AdhkarCategoryId.waking);

    test('taps persist; reopening resumes today where it was left', () async {
      final c = container();
      final sub = c.listen(adhkarSessionProvider(waking), (_, _) {});
      await c.read(adhkarSessionProvider(waking).future);
      final ctrl = c.read(adhkarSessionProvider(waking).notifier);
      expect(await ctrl.tap(), AdhkarTapOutcome.dhikrCompleted);
      await ctrl.advance();
      expect(c.read(adhkarSessionProvider(waking)).value!.index, 1);
      sub.close();

      final again = container();
      again.listen(adhkarSessionProvider(waking), (_, _) {});
      final s = await again.read(adhkarSessionProvider(waking).future);
      expect(s.index, 1);
      expect(s.isDoneAt(0), isTrue);
      expect(s.countAt(1), 0);
    });

    test('finishing a set logs it once to the Faith planet (source "adhkar")', () async {
      final c = container();
      c.listen(adhkarSessionProvider(waking), (_, _) {});
      await c.read(adhkarSessionProvider(waking).future);
      final ctrl = c.read(adhkarSessionProvider(waking).notifier);
      final outcomes = <AdhkarTapOutcome>[];
      for (var i = 0; i < 4; i++) {
        outcomes.add(await ctrl.tap());
        await ctrl.advance();
      }
      expect(outcomes.last, AdhkarTapOutcome.setCompleted);
      var rows = await adhkarLog();
      expect(rows, hasLength(1));
      final row = rows.single;
      expect(row.planetKey, 'faith');
      expect(row.kind, 'adhkar.waking');
      expect(row.kind.startsWith('${ScoreSources.adhkar}.'), isTrue, reason: 'what the Faith planet score reads');
      expect(row.refTable, AdhkarActivity.refTable);
      // The on-waking set's day (the prayer day, or the next one after the
      // middle of the night – the frozen clock is local to the host).
      expect(row.refId, 'waking:${AdhkarTiming.dayKey(c.read(adhkarSetDayProvider(AdhkarCategoryId.waking)))}');
      expect(row.value, 4);
      // Restart and finish again the same day: not logged twice.
      await ctrl.resetAll();
      for (var i = 0; i < 4; i++) {
        await ctrl.tap();
        await ctrl.advance();
      }
      rows = await adhkarLog();
      expect(rows, hasLength(1));
      final summary = c.read(adhkarDaySummaryProvider);
      expect(summary, isA<AsyncValue<AdhkarDaySummary>>());
    });

    test('mark the set done, then undo: the log entry and the counts go back', () async {
      const morning = AdhkarSetKey(AdhkarCategoryId.morning);
      final c = container();
      c.listen(adhkarSessionProvider(morning), (_, _) {});
      await c.read(adhkarSessionProvider(morning).future);
      final ctrl = c.read(adhkarSessionProvider(morning).notifier);
      await ctrl.tap();
      final undo = await ctrl.markDone();
      expect(c.read(adhkarSessionProvider(morning)).value!.isComplete, isTrue);
      expect((await adhkarLog()).single.payload['marked'], true);
      await undo();
      expect(await adhkarLog(), isEmpty);
      final s = c.read(adhkarSessionProvider(morning)).value!;
      expect(s.isComplete, isFalse);
      expect(s.countAt(0), 1);
    });

    test('the after-prayer set is kept per prayer', () async {
      const fajr = AdhkarSetKey(AdhkarCategoryId.afterPrayer, Prayer.fajr);
      // The window is pinned: the host's time zone may differ from Amman's.
      final c = container(overrides: [adhkarWindowProvider.overrideWithValue(PrayerWindow.asr)]);
      final service = c.read(adhkarSetServiceProvider);
      await service.markDone(fajr);
      final progress = await c.read(adhkarProgressStoreProvider).loadDay(c.read(adhkarDayProvider));
      expect(progress.keys, [fajr]);
      final rows = await adhkarLog();
      expect(rows.single.refId, 'afterPrayer.fajr:2026-09-28');
      c.listen(adhkarDaySummaryProvider, (_, _) {});
      await c.read(adhkarProgressDaysProvider.future);
      final summary = c.read(adhkarDaySummaryProvider).value!;
      expect(summary.afterPrayerDone, {Prayer.fajr});
      expect(summary.progress[AdhkarCategoryId.afterPrayer], closeTo(0.2, 1e-9));
      expect(summary.suggested, AdhkarCategoryId.evening, reason: 'the Asr window suggests the evening adhkar');
    });

    test('on-waking adhkar before Fajr count for the new day, not as yesterday\'s', () async {
      // Amman on its own clock, whatever the host's zone; times from the
      // real schedule.
      await Repositories(db).keyValues.setJson('prayer.settings', const PrayerSettings(timeZone: 'Asia/Amman').toJson());
      Future<ProviderContainer> ready() async {
        final c = container();
        c.listen(prayerSettingsProvider, (_, _) {});
        await c.read(prayerSettingsProvider.future);
        return c;
      }

      final schedule = (await ready()).read(adhkarScheduleProvider);
      expect(schedule.zone?.name, 'Asia/Amman');
      final mondayFajr = schedule.timesFor(DateTime(2026, 9, 28)).fajr;
      final tuesdayFajr = schedule.timesFor(DateTime(2026, 9, 29)).fajr;
      Future<void> sayWaking(ProviderContainer c) async {
        final sub = c.listen(adhkarSessionProvider(waking), (_, _) {});
        await c.read(adhkarSessionProvider(waking).future);
        final ctrl = c.read(adhkarSessionProvider(waking).notifier);
        for (var i = 0; i < 4; i++) {
          await ctrl.tap();
          await ctrl.advance();
        }
        expect(c.read(adhkarSessionProvider(waking)).value!.isComplete, isTrue);
        sub.close();
      }

      Future<AdhkarDaySummary> summary(ProviderContainer c) async {
        c.listen(adhkarDaySummaryProvider, (_, _) {});
        await c.read(adhkarProgressDaysProvider.future);
        return c.read(adhkarDaySummaryProvider).value!;
      }

      // Monday, just after Fajr.
      now = mondayFajr.add(const Duration(minutes: 30));
      await sayWaking(await ready());
      // Monday night, an hour after Isha, before sleeping: the sleep adhkar
      // (prayer day Monday).
      now = schedule.timesFor(DateTime(2026, 9, 28)).isha.add(const Duration(hours: 1));
      final evening = await ready();
      await evening.read(adhkarSetServiceProvider).markDone(const AdhkarSetKey(AdhkarCategoryId.sleep));
      // Tuesday, 25 minutes before Fajr – up for the night prayer / Fajr.
      now = tuesdayFajr.subtract(const Duration(minutes: 25));
      final c = await ready();
      expect(c.read(adhkarDayProvider), DateTime(2026, 9, 28), reason: 'still Monday\'s prayer day');
      expect(c.read(adhkarSetDayProvider(AdhkarCategoryId.waking)), DateTime(2026, 9, 29));
      final before = await summary(c);
      expect(before.isDone(AdhkarCategoryId.waking), isFalse, reason: 'Monday\'s waking set is not Tuesday\'s');
      expect(before.isDone(AdhkarCategoryId.sleep), isTrue, reason: 'Monday night\'s sleep adhkar still show');
      expect(before.suggested, AdhkarCategoryId.waking);
      final session = await c.read(adhkarSessionProvider(waking).future);
      expect(session.isStarted, isFalse);
      await sayWaking(c);
      final rows = await adhkarLog();
      expect(
        rows.where((r) => r.kind == 'adhkar.waking').map((r) => r.refId),
        unorderedEquals(['waking:2026-09-28', 'waking:2026-09-29']),
      );
      // After Fajr the waking set stays done (same day), the day moves on.
      now = tuesdayFajr.add(const Duration(minutes: 20));
      final after = await summary(await ready());
      expect(after.isDone(AdhkarCategoryId.waking), isTrue);
      expect(after.isDone(AdhkarCategoryId.sleep), isFalse);
    });

    test('home-card actions: restart keeps the logged flag; undo restores', () async {
      const evening = AdhkarSetKey(AdhkarCategoryId.evening);
      final c = container();
      final service = c.read(adhkarSetServiceProvider);
      final undoDone = await service.markDone(evening);
      final undoRestart = await service.restart(evening);
      final store = c.read(adhkarProgressStoreProvider);
      final day = c.read(adhkarDayProvider);
      expect((await store.load(day, evening))!.isComplete, isFalse);
      expect((await store.load(day, evening))!.logged, isTrue);
      await undoRestart();
      expect((await store.load(day, evening))!.isComplete, isTrue);
      await undoDone();
      expect(await store.load(day, evening), isNull);
      expect(await adhkarLog(), isEmpty);
    });
  });

  group('progress store', () {
    test('each day keeps its own sets; only the last few days are kept', () async {
      final kv = Repositories(db).keyValues;
      final store = AdhkarProgressStore(kv);
      DateTime d(int n) => DateTime(2026, 9, 27 + n);
      const sleep = AdhkarSetKey(AdhkarCategoryId.sleep), waking = AdhkarSetKey(AdhkarCategoryId.waking);
      await store.save(d(1), sleep, const AdhkarProgress(index: 3, counts: {'sleep.01': 2}));
      expect((await store.load(d(1), sleep))!.index, 3);
      expect(await store.load(d(2), sleep), isNull, reason: 'another day reads empty');
      // Waking before Fajr: the next day's waking set while the sleep set of
      // the prayer day is still open.
      await store.save(d(2), waking, const AdhkarProgress(index: 1));
      expect((await store.load(d(1), sleep))!.index, 3, reason: 'both days are kept');
      expect((await store.loadDay(d(2))).keys, [waking]);
      await store.save(d(3), waking, const AdhkarProgress());
      await store.save(d(4), waking, const AdhkarProgress());
      expect(await store.load(d(1), sleep), isNull, reason: 'older than ${AdhkarProgressStore.keepDays} days: dropped');
      expect(await store.load(d(2), waking), isNotNull);
      await store.remove(d(4), waking);
      expect(await store.loadDay(d(4)), isEmpty);
    });

    test('reads the earlier one-day layout', () async {
      final kv = Repositories(db).keyValues;
      await kv.setJson(AdhkarProgressStore.key, {
        'day': '2026-09-28',
        'sets': {
          'morning': {'index': 4, 'counts': {'morning.01': 1}},
        },
      });
      final store = AdhkarProgressStore(kv);
      expect((await store.load(DateTime(2026, 9, 28), const AdhkarSetKey(AdhkarCategoryId.morning)))!.index, 4);
      await store.save(DateTime(2026, 9, 29), const AdhkarSetKey(AdhkarCategoryId.waking), const AdhkarProgress());
      expect((await store.load(DateTime(2026, 9, 28), const AdhkarSetKey(AdhkarCategoryId.morning)))!.index, 4);
    });
  });

  group('tasbeeh', () {
    test('first tap opens a session; rounds and flushes write the count', () async {
      final c = container();
      c.listen(tasbeehControllerProvider, (_, _) {});
      await c.read(tasbeehControllerProvider.future);
      final ctrl = c.read(tasbeehControllerProvider.notifier);
      expect(await ctrl.tap(), TasbeehTapOutcome.bead);
      final id = c.read(tasbeehControllerProvider).value!.sessionId;
      expect(id, isNotNull);
      TasbeehTapOutcome? o;
      for (var i = 0; i < 32; i++) {
        o = await ctrl.tap();
      }
      expect(o, TasbeehTapOutcome.round);
      await ctrl.flush();
      final row = await (db.select(db.activityLog)..where((t) => t.id.equals(id!))).getSingle();
      expect(row.kind, AdhkarActivity.tasbeehKind);
      expect(row.planetKey, 'faith');
      expect(row.value, 33);
      expect(row.payload['phrase'], 'سُبْحَانَ اللَّهِ');
      expect(row.payload['target'], 33);
    });

    test('reset ends the session; the next tap starts a new one', () async {
      final c = container();
      c.listen(tasbeehControllerProvider, (_, _) {});
      await c.read(tasbeehControllerProvider.future);
      final ctrl = c.read(tasbeehControllerProvider.notifier);
      for (var i = 0; i < 5; i++) {
        await ctrl.tap();
      }
      final first = c.read(tasbeehControllerProvider).value!.sessionId;
      await ctrl.reset();
      expect(c.read(tasbeehControllerProvider).value!.counter.count, 0);
      await ctrl.tap();
      await ctrl.flush();
      final second = c.read(tasbeehControllerProvider).value!.sessionId;
      expect(second, isNot(first));
      final sessions = await c.read(tasbeehStoreProvider).watchSessions(DateTime(2026)).first;
      expect({for (final s in sessions) s.id: s.count}, {first: 5, second: 1});
    });

    test('phrase and target changes start fresh; the count resumes the same day only', () async {
      final c = container();
      c.listen(tasbeehControllerProvider, (_, _) {});
      await c.read(tasbeehControllerProvider.future);
      final ctrl = c.read(tasbeehControllerProvider.notifier);
      await ctrl.selectPhrase('istighfar');
      await ctrl.setTarget(100);
      for (var i = 0; i < 7; i++) {
        await ctrl.tap();
      }
      await ctrl.flush();
      final s = c.read(tasbeehControllerProvider).value!;
      expect(s.phrase!.id, 'istighfar');
      expect(s.counter, const TasbeehCounter(target: 100, count: 7));

      final same = container();
      same.listen(tasbeehControllerProvider, (_, _) {});
      final resumed = await same.read(tasbeehControllerProvider.future);
      expect(resumed.phrase!.id, 'istighfar');
      expect(resumed.counter.count, 7);

      now = DateTime(2026, 9, 29, 17, 10);
      final tomorrow = container();
      tomorrow.listen(tasbeehControllerProvider, (_, _) {});
      final next = await tomorrow.read(tasbeehControllerProvider.future);
      expect(
        next.counter,
        const TasbeehCounter(target: 100),
        reason: 'a new day starts from zero, same phrase and target',
      );
      expect(next.phrase!.id, 'istighfar');
    });

    test('phrases: add, edit, reorder, delete with undo – persisted', () async {
      final c = container();
      c.listen(tasbeehControllerProvider, (_, _) {});
      await c.read(tasbeehControllerProvider.future);
      final ctrl = c.read(tasbeehControllerProvider.notifier);
      final added = (await ctrl.addPhrase('  يَا حَيُّ يَا قَيُّومُ  '))!;
      expect(added.text, 'يَا حَيُّ يَا قَيُّومُ');
      expect(c.read(tasbeehControllerProvider).value!.phrase, added, reason: 'a new phrase is selected');
      await ctrl.editPhrase(added.id, 'يَا ذَا الْجَلَالِ وَالْإِكْرَامِ');
      final phrases = c.read(tasbeehControllerProvider).value!.phrases;
      await ctrl.reorderPhrases([phrases.last, ...phrases.take(phrases.length - 1)]);
      expect((await c.read(tasbeehStoreProvider).loadPhrases()).first.text, 'يَا ذَا الْجَلَالِ وَالْإِكْرَامِ');
      final undo = await ctrl.deletePhrase(added.id);
      expect((await c.read(tasbeehStoreProvider).loadPhrases()).any((p) => p.id == added.id), isFalse);
      await undo();
      expect((await c.read(tasbeehStoreProvider).loadPhrases()).first.id, added.id);
    });

    test('deleting the session being counted clears the counter; undo brings both back', () async {
      final c = container();
      c.listen(tasbeehControllerProvider, (_, _) {});
      await c.read(tasbeehControllerProvider.future);
      final ctrl = c.read(tasbeehControllerProvider.notifier);
      for (var i = 0; i < 5; i++) {
        await ctrl.tap();
      }
      final id = c.read(tasbeehControllerProvider).value!.sessionId!;
      final undo = (await ctrl.deleteSession(id))!;
      expect(c.read(tasbeehControllerProvider).value!.counter.count, 0);
      expect(c.read(tasbeehControllerProvider).value!.sessionId, isNull);
      expect(await c.read(tasbeehStoreProvider).watchSessions(DateTime(2026)).first, isEmpty);
      await undo();
      expect(c.read(tasbeehControllerProvider).value!.counter.count, 5);
      await ctrl.tap();
      await ctrl.flush();
      final sessions = await c.read(tasbeehStoreProvider).watchSessions(DateTime(2026)).first;
      expect(sessions.single.id, id, reason: 'counting goes on in the restored row');
      expect(sessions.single.count, 6);
      // Another (finished) session: deleting it leaves the counter alone.
      final other = await c.read(tasbeehStoreProvider).startSession(
        phrase: TasbeehDefaults.phrases[2],
        target: 33,
        count: 33,
        at: now.subtract(const Duration(hours: 2)),
      );
      await ctrl.deleteSession(other);
      expect(c.read(tasbeehControllerProvider).value!.counter.count, 6);
    });

    test('a playing recording stops when the adhan mutes the app', () async {
      final store = MemoryDhikrAudioStore();
      final player = FakeDhikrAudioPlayer();
      final c = container(
        overrides: [
          soundServiceProvider.overrideWithValue(SilentSoundService()),
          dhikrAudioStoreProvider.overrideWithValue(store),
          dhikrAudioPlayerProvider.overrideWithValue(player),
        ],
      );
      await store.attach('waking.01', (name: 'a.wav', bytes: silentWav()));
      c.listen(dhikrPlaybackProvider, (_, _) {});
      expect(await c.read(dhikrPlaybackProvider.notifier).play('waking.01'), isTrue);
      expect(c.read(dhikrPlaybackProvider), 'waking.01');
      final lease = c.read(prayerMuteProvider).acquire('adhan');
      expect(c.read(dhikrPlaybackProvider), isNull);
      expect(player.stops, greaterThan(0));
      // Started again during the prayer minutes: it plays.
      expect(await c.read(dhikrPlaybackProvider.notifier).play('waking.01'), isTrue);
      expect(c.read(dhikrPlaybackProvider), 'waking.01');
      lease.release();
      expect(c.read(dhikrPlaybackProvider), 'waking.01');
    });

    test('a picked file is size-checked before it is read', () async {
      final big = _FakePickedFile('lecture.mp3', size: DhikrAudioStore.maxBytes + 1);
      await expectLater(
        readPickedAudio(big),
        throwsA(isA<DhikrAudioException>().having((e) => e.problem, 'problem', DhikrAudioProblem.tooLarge)),
      );
      expect(big.reads, 0, reason: 'never loaded into memory');
      final small = _FakePickedFile('dhikr.wav', size: 52, bytes: silentWav(samples: 8));
      final picked = await readPickedAudio(small);
      expect(picked.name, 'dhikr.wav');
      expect(small.reads, 1);
    });

    test('session history: delete and restore', () async {
      final store = TasbeehStore(Repositories(db));
      final id = await store.startSession(phrase: TasbeehDefaults.phrases.first, target: 33, count: 40, at: now);
      var sessions = await store.watchSessions(DateTime(2026)).first;
      expect(sessions.single.rounds, 1);
      final row = await store.deleteSession(id);
      expect(await store.watchSessions(DateTime(2026)).first, isEmpty);
      await store.restoreSession(row!);
      sessions = await store.watchSessions(DateTime(2026)).first;
      expect(sessions.single.count, 40);
      expect(TasbeehStore.totalOn(sessions, DateTime(2026, 9, 28), DateTime(2026, 9, 29)), 40);
    });
  });

  group('attached recordings (files)', () {
    test('attach copies into the app folder, replace removes the old file, remove has undo', () async {
      final dir = await Directory.systemTemp.createTemp('adhkar_audio');
      addTearDown(() => dir.delete(recursive: true));
      var tick = 0;
      final store = FileDhikrAudioStore(
        Repositories(db).keyValues,
        directory: () async => dir,
        clock: () => DateTime(2026, 9, 28, 12, 0, tick++),
      );
      final info = await store.attach('morning.01', (name: 'recitation.wav', bytes: silentWav()));
      expect(info.originalName, 'recitation.wav');
      expect(info.duration, const Duration(milliseconds: 500));
      expect(dir.listSync(), hasLength(1));
      expect(await store.read('morning.01'), silentWav());
      final second = await store.attach('morning.01', (name: 'b.wav', bytes: silentWav(samples: 8000)));
      expect(dir.listSync().map((f) => f.uri.pathSegments.last), [second.storedName]);
      final undo = await store.remove('morning.01');
      expect(dir.listSync(), isEmpty);
      expect(await store.all(), isEmpty);
      await undo!();
      expect((await store.all())['morning.01']!.originalName, 'b.wav');
      expect(await store.read('morning.01'), silentWav(samples: 8000));
      await expectLater(
        store.attach('morning.02', (name: 'x.m4a', bytes: silentWav().sublist(8))),
        throwsA(isA<DhikrAudioException>().having((e) => e.problem, 'problem', DhikrAudioProblem.unsupported)),
      );
    });
  });

  group('reminder sync', () {
    test('plans at start, and again when the settings or the language change', () async {
      final scheduler = _RecordingScheduler();
      final c = container(overrides: [adhkarReminderSchedulerProvider.overrideWithValue(scheduler)]);
      await c.read(repositoriesProvider).keyValues.setJson(
        'adhkar.reminders',
        const AdhkarReminderSettings(morning: true).toJson(),
      );
      c.listen(adhkarReminderSyncProvider, (_, _) {});
      await c.read(prayerSettingsProvider.future);
      Future<void> settle() => Future<void>.delayed(AdhkarReminderSync.debounce * 2);
      await settle();
      expect(scheduler.last, isNotEmpty);
      expect(scheduler.last!.first.title, lookupL10n(const Locale('ar')).adhkarReminderMorningTitle);
      expect(c.read(adhkarReminderSyncProvider), scheduler.last);
      await c.read(appSettingsProvider.notifier).update((s) => s.copyWith(languageCode: 'en'));
      await settle();
      expect(scheduler.last!.first.title, lookupL10n(const Locale('en')).adhkarReminderMorningTitle);
      await c.read(repositoriesProvider).keyValues.setJson('adhkar.reminders', const AdhkarReminderSettings().toJson());
      await settle();
      expect(scheduler.cancels, greaterThan(0));
    });
  });

  group('reminder service', () {
    test('saves the settings and hands the planned notices to the scheduler', () async {
      final scheduler = _RecordingScheduler();
      final c = container(overrides: [adhkarReminderSchedulerProvider.overrideWithValue(scheduler)]);
      final l10n = lookupL10n(const Locale('ar'));
      final service = c.read(adhkarReminderServiceProvider);
      final notices = await service.update(const AdhkarReminderSettings(morning: true, evening: true), l10n);
      expect(scheduler.last, notices);
      // The same plan straight from the schedule (independent of the host's
      // time zone): 7 days × 2, minus what already passed today.
      final plan = AdhkarReminderPlanner.plan(
        settings: const AdhkarReminderSettings(morning: true, evening: true),
        timesFor: c.read(adhkarScheduleProvider).timesFor,
        now: now,
      );
      expect(notices.map((n) => n.reminder), plan);
      expect(notices.length, inInclusiveRange(12, 14));
      expect(notices.every((n) => n.at.isAfter(now)), isTrue);
      for (final n in notices) {
        final morning = n.reminder.category == AdhkarCategoryId.morning;
        expect(n.title, morning ? l10n.adhkarReminderMorningTitle : l10n.adhkarReminderEveningTitle);
        expect(n.payload, 'adhkar:${n.reminder.category.name}');
      }
      expect(await service.load(), const AdhkarReminderSettings(morning: true, evening: true));
      await service.update(const AdhkarReminderSettings(), l10n);
      expect(scheduler.cancels, 1);
    });
  });
}
