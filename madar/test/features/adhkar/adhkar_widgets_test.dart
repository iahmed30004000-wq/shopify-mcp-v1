import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/adhkar/adhkar.dart';

import 'adhkar_harness.dart';

final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));
String _d(int n) => Digits.toArabicIndic('$n');

Finder _ring() => find.byType(AdhkarCounterRing);

Future<void> _tapRing(WidgetTester tester) async {
  await tester.tap(_ring());
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

class _Scheduler implements AdhkarReminderScheduler {
  bool allow = true;
  int permissionRequests = 0;
  List<AdhkarReminderNotice> notices = const [];

  @override
  Future<void> replaceAll(List<AdhkarReminderNotice> notices) async => this.notices = notices;

  @override
  Future<void> cancelAll() async => notices = const [];

  @override
  Future<bool> ensurePermission() async {
    permissionRequests++;
    return allow;
  }
}

void main() {
  group('reader', () {
    testWidgets('Arabic: taps count with a tick; a finished dhikr chimes and glides to the next; the set completes', (
      tester,
    ) async {
      final env = await pumpAdhkarApp(tester, home: const AdhkarReaderScreen(category: AdhkarCategoryId.sleep));
      expect(find.text(_ar.adhkarCategorySleep), findsOneWidget);
      expect(find.text(_ar.adhkarReaderPosition(_d(1), _d(15))), findsOneWidget);
      // sleep.01 is said three times.
      await _tapRing(tester);
      expect(env.sound.played.last, Sfx.countTick);
      expect(env.haptics.fired.last, Haptic.tick);
      await _tapRing(tester);
      await _tapRing(tester);
      expect(env.sound.played.last, Sfx.complete);
      expect(env.haptics.fired.last, Haptic.success);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarReaderPosition(_d(2), _d(15))), findsOneWidget, reason: 'auto-advanced');
      // Tapping anywhere on the page counts too.
      await tester.tapAt(tester.getCenter(find.byType(PageView)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(env.sound.played.last, Sfx.complete, reason: 'Ayat al-Kursi: once');
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarReaderPosition(_d(3), _d(15))), findsOneWidget);
    });

    testWidgets('finishing every dhikr shows the completion card and logs the set once', (tester) async {
      final env = await pumpAdhkarApp(tester, home: const AdhkarReaderScreen(category: AdhkarCategoryId.waking));
      for (var i = 0; i < 4; i++) {
        await _tapRing(tester);
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
      }
      expect(env.sound.played, contains(Sfx.levelUp));
      expect(find.text(_ar.adhkarSetCompleteTitle), findsOneWidget);
      expect(find.text(_ar.adhkarSetCompleteBody(_ar.adhkarCategoryWaking)), findsOneWidget);
      final rows = await tester.runAsync(
        () => (env.db.select(env.db.activityLog)..where((t) => t.kind.equals('adhkar.waking'))).get(),
      );
      expect(rows, hasLength(1));
      // Review hides the card again.
      await tester.tap(find.text(_ar.adhkarSetCompleteReview));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarSetCompleteTitle), findsNothing);
    });

    testWidgets('English: resumes today where it was left, with the English meaning', (tester) async {
      await pumpAdhkarApp(
        tester,
        locale: const Locale('en'),
        home: const AdhkarReaderScreen(category: AdhkarCategoryId.evening),
        beforePump: (db) async {
          final repos = Repositories(db);
          await AdhkarProgressStore(repos.keyValues).save(
            DateTime(2026, 9, 28),
            const AdhkarSetKey(AdhkarCategoryId.evening),
            const AdhkarProgress(index: 5, counts: {'evening.01': 1}),
          );
        },
      );
      expect(find.text(_en.adhkarReaderPosition('6', '23')), findsOneWidget);
      expect(find.textContaining('Evening has come to us'), findsOneWidget);
      expect(find.text(_en.adhkarRemaining), findsOneWidget);
    });

    testWidgets('Arabic UI shows no English meaning', (tester) async {
      await pumpAdhkarApp(
        tester,
        home: const AdhkarReaderScreen(category: AdhkarCategoryId.evening),
        beforePump: (db) => AdhkarProgressStore(Repositories(db).keyValues)
            .save(DateTime(2026, 9, 28), const AdhkarSetKey(AdhkarCategoryId.evening), const AdhkarProgress(index: 5)),
      );
      expect(find.textContaining('has come to us'), findsNothing);
      expect(find.text(_ar.adhkarVirtue), findsNothing, reason: 'evening.06 has no virtue');
    });

    testWidgets('after-prayer: the set follows the chosen prayer', (tester) async {
      await pumpAdhkarApp(tester, home: const AdhkarReaderScreen(category: AdhkarCategoryId.afterPrayer));
      expect(find.text(_ar.adhkarReaderPosition(_d(1), _d(10))), findsOneWidget, reason: 'Asr: ten adhkar');
      await tester.tap(find.text(_ar.prayerFajr));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarReaderPosition(_d(1), _d(12))), findsOneWidget, reason: 'Fajr adds two');
    });

    testWidgets('options: mark the set done (completion card, undo toast)', (tester) async {
      final env = await pumpAdhkarApp(tester, home: const AdhkarReaderScreen(category: AdhkarCategoryId.morning));
      await tester.tap(find.bySemanticsLabel(_ar.adhkarOptionsTitle));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarTextSize), findsOneWidget);
      await tester.tap(find.text(_ar.adhkarMarkSetDone));
      // Not pumpAndSettle: that would run the undo toast's countdown out.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text(_ar.adhkarSetCompleteTitle), findsOneWidget);
      expect(find.text(_ar.adhkarMarkedDone(_ar.adhkarCategoryMorning)), findsOneWidget);
      final rows = await tester.runAsync(() => env.db.select(env.db.activityLog).get());
      expect(rows!.single.kind, 'adhkar.morning');
      await tester.tap(find.text(_ar.actionUndo));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text(_ar.adhkarSetCompleteTitle), findsNothing);
      expect(await tester.runAsync(() => env.db.select(env.db.activityLog).get()), isEmpty);
    });

    testWidgets('text size is stored per user', (tester) async {
      final env = await pumpAdhkarApp(tester, home: const AdhkarReaderScreen(category: AdhkarCategoryId.waking));
      await tester.tap(find.bySemanticsLabel(_ar.adhkarOptionsTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(_ar.adhkarTextSizeLarger));
      await tester.pumpAndSettle();
      final prefs = await tester.runAsync(() => Repositories(env.db).keyValues.getJson('adhkar.reader'));
      expect(AdhkarReaderPrefs.fromJson(prefs).textScale, closeTo(1.1, 1e-9));
    });

    testWidgets('attach a recording to a dhikr and play it', (tester) async {
      final env = await pumpAdhkarApp(
        tester,
        home: const AdhkarReaderScreen(category: AdhkarCategoryId.waking),
        overrides: [
          dhikrAudioPickerProvider.overrideWithValue(() async => (name: 'recitation.wav', bytes: silentWav())),
        ],
      );
      await tester.tap(find.bySemanticsLabel(_ar.adhkarOptionsTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.adhkarAudioTitle));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarAudioNone), findsOneWidget);
      await tester.tap(find.text(_ar.adhkarAudioAttach));
      await tester.pumpAndSettle();
      expect(find.textContaining('recitation.wav'), findsOneWidget);
      expect((await env.audioStore.all()).keys, ['waking.01']);
      // The sheet's button (the page's own play button is under the barrier).
      await tester.tap(find.bySemanticsLabel(_ar.adhkarAudioPlay).last);
      await tester.pumpAndSettle();
      expect(env.player.played, ['waking.01']);
    });
  });

  group('home and Faith card', () {
    testWidgets('home lists the five sets; a card opens its reader; long-press marks it done', (tester) async {
      final env = await pumpAdhkarApp(tester, home: const AdhkarHomeScreen());
      expect(find.text(_ar.adhkarTodayTitle), findsOneWidget);
      expect(find.text(_ar.adhkarSuggestEvening), findsOneWidget);
      for (final name in [_ar.adhkarCategoryMorning, _ar.adhkarCategoryEvening, _ar.adhkarCategoryAfterPrayer]) {
        expect(find.text(name), findsOneWidget);
      }
      await tester.longPress(find.text(_ar.adhkarCategoryMorning));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_ar.adhkarMarkDone).last);
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarDoneToday), findsOneWidget);
      final rows = await tester.runAsync(() => env.db.select(env.db.activityLog).get());
      expect(rows!.single.kind, 'adhkar.morning');
      await tester.tap(find.text(_ar.adhkarCategoryEvening));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarReaderPosition(_d(1), _d(23))), findsOneWidget);
    });

    testWidgets('the hero moves on once the set of the moment is said', (tester) async {
      Future<void> said(db, List<AdhkarSetKey> keys) async {
        final store = AdhkarProgressStore(Repositories(db).keyValues);
        for (final k in keys) {
          await store.save(DateTime(2026, 9, 28), k, AdhkarProgress(completedAt: DateTime(2026, 9, 28, 16), logged: true));
        }
      }

      // Evening adhkar said during Asr: the adhkar after Asr are next.
      await pumpAdhkarApp(
        tester,
        home: const AdhkarHomeScreen(),
        beforePump: (db) => said(db, [const AdhkarSetKey(AdhkarCategoryId.evening)]),
      );
      expect(find.text(_ar.adhkarSuggestAfterPrayer(_ar.prayerAsr)), findsOneWidget);
      expect(find.text(_ar.adhkarSuggestEvening), findsNothing);
    });

    testWidgets('both said: the hero says so and offers nothing to start', (tester) async {
      await pumpAdhkarApp(
        tester,
        home: const AdhkarHomeScreen(),
        beforePump: (db) async {
          final store = AdhkarProgressStore(Repositories(db).keyValues);
          for (final k in const [
            AdhkarSetKey(AdhkarCategoryId.evening),
            AdhkarSetKey(AdhkarCategoryId.afterPrayer, Prayer.asr),
          ]) {
            await store.save(DateTime(2026, 9, 28), k, AdhkarProgress(completedAt: DateTime(2026, 9, 28, 16)));
          }
        },
      );
      expect(find.text(_ar.adhkarSuggestDone('evening')), findsOneWidget);
      expect(find.text(_ar.adhkarStart), findsNothing);
      expect(find.text(_ar.adhkarContinue), findsNothing);
    });

    testWidgets('switching a reminder on asks for notifications; a refusal is explained', (tester) async {
      final scheduler = _Scheduler()..allow = false;
      await pumpAdhkarApp(
        tester,
        home: const AdhkarHomeScreen(),
        overrides: [adhkarReminderSchedulerProvider.overrideWithValue(scheduler)],
      );
      await tester.drag(find.byType(ListView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarReminderPermissionDenied), findsNothing);
      await tester.tap(find.bySemanticsLabel(_ar.adhkarReminderMorningLabel).last);
      await tester.pumpAndSettle();
      expect(scheduler.permissionRequests, 1);
      expect(find.text(_ar.adhkarReminderPermissionDenied), findsOneWidget);
      expect(scheduler.notices, isNotEmpty, reason: 'the choice is kept; reminders are planned');
      expect(scheduler.notices.every((n) => n.reminder.category == AdhkarCategoryId.morning), isTrue);
    });

    testWidgets('a reminder switched on is scheduled as a notification', (tester) async {
      final env = await pumpAdhkarApp(tester, home: const AdhkarHomeScreen());
      await tester.drag(find.byType(ListView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(_ar.adhkarReminderEveningLabel).last);
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(env.notifications.channels.keys, contains(NotificationAdhkarReminderScheduler.channelId));
      final pending = env.notifications.scheduled.values.map((f) => f.request).toList();
      expect(pending, isNotEmpty);
      expect(pending.every((r) => r.namespace.name == 'adhkar' && r.data['set'] == 'evening'), isTrue);
      expect(pending.first.title, _ar.adhkarReminderEveningTitle);
      expect(find.text(_ar.adhkarReminderPermissionDenied), findsNothing);
    });

    testWidgets('English home and the Faith card', (tester) async {
      await pumpAdhkarApp(
        tester,
        locale: const Locale('en'),
        home: const Scaffold(body: SafeArea(child: AdhkarTodayCard())),
      );
      for (final s in [_en.adhkarShortMorning, _en.adhkarShortEvening, _en.adhkarShortSleep]) {
        expect(find.text(s), findsOneWidget);
      }
      await tester.tap(find.text(_en.adhkarShortSleep));
      await tester.pumpAndSettle();
      expect(find.text(_en.adhkarCategorySleep), findsOneWidget);
      expect(find.text(_en.adhkarReaderPosition('1', '15')), findsOneWidget);
    });
  });

  group('tasbeeh', () {
    testWidgets('a bead per tap, a strong haptic per round, long-press reset with confirmation, history', (
      tester,
    ) async {
      final env = await pumpAdhkarApp(tester, home: const TasbeehScreen());
      final ring = find.byType(TasbeehBeadRing);
      for (var i = 0; i < 33; i++) {
        await tester.tapAt(tester.getCenter(ring));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();
      expect(env.haptics.fired.where((h) => h == Haptic.tick), hasLength(32));
      expect(env.haptics.fired.where((h) => h == Haptic.heavy), hasLength(1));
      expect(find.textContaining(_ar.adhkarTasbeehTotal(_d(33))), findsOneWidget);
      await tester.longPressAt(tester.getCenter(ring));
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarTasbeehResetTitle), findsOneWidget);
      await tester.tap(find.text(_ar.adhkarTasbeehReset).last);
      await tester.pumpAndSettle();
      expect(find.text(_ar.adhkarTasbeehOf(_d(33))), findsOneWidget);
      expect(find.textContaining(_ar.adhkarTasbeehTotal(_d(33))), findsNothing);
      await tester.tap(find.bySemanticsLabel(_ar.adhkarTasbeehHistory));
      await tester.pumpAndSettle();
      expect(find.text(_d(33)), findsWidgets, reason: 'the session is in the history');
    });

    testWidgets('a phrase the user types in English reads left to right, even in the Arabic UI', (tester) async {
      final env = await pumpAdhkarApp(tester, home: const TasbeehScreen());
      await tester.runAsync(() => env.container.read(tasbeehControllerProvider.notifier).addPhrase('Glory be to God!'));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('Glory be to God!'));
      expect(text.textDirection, TextDirection.ltr);
      await tester.runAsync(() => env.container.read(tasbeehControllerProvider.notifier).selectPhrase('subhanallah'));
      await tester.pumpAndSettle();
      final arabic = tester.widget<Text>(find.text(TasbeehDefaults.phrases.first.text));
      expect(arabic.textDirection, TextDirection.rtl);
    });

    testWidgets('English: phrase gloss, target choice and a custom target', (tester) async {
      await pumpAdhkarApp(tester, locale: const Locale('en'), home: const TasbeehScreen());
      expect(find.text(_en.adhkarPhraseSubhanallah), findsOneWidget);
      await tester.tap(find.text('99'));
      await tester.pumpAndSettle();
      expect(find.text(_en.adhkarTasbeehOf('99')), findsOneWidget);
      await tester.tap(find.text(_en.adhkarTasbeehCustom));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, '7');
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.actionSave));
      await tester.pumpAndSettle();
      expect(find.text(_en.adhkarTasbeehOf('7')), findsOneWidget);
    });
  });
}
