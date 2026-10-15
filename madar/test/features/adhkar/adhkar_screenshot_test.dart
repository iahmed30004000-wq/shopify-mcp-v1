@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

import '../../helpers/screenshot_harness.dart';
import 'adhkar_harness.dart';

const _dir = 'phase2/adhkar';
final _library = loadBundledLibrary();

class _RefusingScheduler implements AdhkarReminderScheduler {
  const _RefusingScheduler();

  @override
  Future<void> replaceAll(List<AdhkarReminderNotice> notices) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> ensurePermission() async => false;
}
final _ar = lookupL10n(const Locale('ar'));
final _en = lookupL10n(const Locale('en'));
final _day = DateTime(2026, 9, 28);

Future<void> _progress(MadarDatabase db, Map<AdhkarSetKey, AdhkarProgress> sets) async {
  final store = AdhkarProgressStore(Repositories(db).keyValues);
  for (final e in sets.entries) {
    await store.save(_day, e.key, e.value);
  }
}

Future<void> _settle(WidgetTester tester, [int frames = 24]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    Future<void> Function(MadarDatabase db)? beforePump,
    Future<void> Function(AdhkarTestEnv env)? setup,
    Future<void> Function(WidgetTester tester, AdhkarTestEnv env)? beforeCapture,
    DateTime? now,
    PrayerWindow window = PrayerWindow.asr,
    List<Override> overrides = const [],
  }) async {
    final (app, env) = await buildAdhkarApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      beforePump: beforePump,
      now: now,
      window: window,
      overrides: overrides,
    );
    if (setup != null) await tester.runAsync(() => setup(env));
    await captureScreen(
      tester,
      app,
      '$_dir/$name',
      beforeCapture: beforeCapture == null ? null : (t) => beforeCapture(t, env),
    );
  }

  group('reader', () {
    testWidgets('morning, Arabic, Lapis', (tester) async {
      await shot(tester, 'reader_morning_ar_lapis', const AdhkarReaderScreen(category: AdhkarCategoryId.morning));
    });

    testWidgets('evening, English, Pearl', (tester) async {
      await shot(
        tester,
        'reader_evening_en_pearl',
        const AdhkarReaderScreen(category: AdhkarCategoryId.evening),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforePump: (db) => _progress(db, {
          const AdhkarSetKey(AdhkarCategoryId.evening): const AdhkarProgress(
            index: 5,
            counts: {'evening.01': 1, 'evening.02': 1, 'evening.03': 3, 'evening.04': 3, 'evening.05': 3},
          ),
        }),
      );
    });

    testWidgets('sleep (three surahs), Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'reader_sleep_ar_emerald',
        const AdhkarReaderScreen(category: AdhkarCategoryId.sleep),
        theme: MadarThemeId.emerald,
      );
    });

    testWidgets('mid-count with repetition beads, Arabic, Aurora', (tester) async {
      await shot(
        tester,
        'reader_counting_ar_aurora',
        const AdhkarReaderScreen(category: AdhkarCategoryId.morning),
        theme: MadarThemeId.aurora,
        beforePump: (db) => _progress(db, {
          const AdhkarSetKey(AdhkarCategoryId.morning): const AdhkarProgress(
            index: 7,
            counts: {
              'morning.01': 1,
              'morning.02': 3,
              'morning.03': 3,
              'morning.04': 3,
              'morning.05': 1,
              'morning.06': 1,
              'morning.07': 1,
              'morning.08': 2,
            },
          ),
        }),
      );
    });

    testWidgets('after-prayer with the prayer picker, English, Lapis', (tester) async {
      await shot(
        tester,
        'reader_after_prayer_en_lapis',
        const AdhkarReaderScreen(category: AdhkarCategoryId.afterPrayer),
        locale: const Locale('en'),
        beforeCapture: (tester, _) async {
          await tester.tap(find.text(_en.prayerMaghrib));
          await _settle(tester);
          for (var i = 0; i < 3; i++) {
            await tester.tap(find.byType(AdhkarCounterRing));
            await _settle(tester, 20);
          }
          await _settle(tester);
        },
      );
    });

    testWidgets('set complete, Arabic, Lapis', (tester) async {
      await shot(
        tester,
        'reader_complete_ar_lapis',
        const AdhkarReaderScreen(category: AdhkarCategoryId.waking),
        beforePump: (db) => _progress(db, {
          const AdhkarSetKey(AdhkarCategoryId.waking): const AdhkarProgress(
            index: 3,
            counts: {'waking.01': 1, 'waking.02': 1, 'waking.03': 1},
          ),
        }),
        beforeCapture: (tester, _) async {
          await tester.tap(find.byType(AdhkarCounterRing));
          await _settle(tester, 30);
        },
      );
    });

    testWidgets('reading options sheet, Arabic, Desert', (tester) async {
      await shot(
        tester,
        'reader_options_ar_desert',
        const AdhkarReaderScreen(category: AdhkarCategoryId.evening),
        theme: MadarThemeId.desert,
        beforeCapture: (tester, _) async {
          await tester.tap(find.bySemanticsLabel(_ar.adhkarOptionsTitle));
          await _settle(tester);
        },
      );
    });

    testWidgets('recording sheet with an attached file, English, Pearl', (tester) async {
      await shot(
        tester,
        'reader_audio_en_pearl',
        const AdhkarReaderScreen(category: AdhkarCategoryId.waking),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        setup: (env) => env.audioStore.attach('waking.01', (
          name: 'Waking dhikr – my recording.wav',
          bytes: silentWav(samples: 60000),
        )),
        beforeCapture: (tester, _) async {
          await tester.tap(find.bySemanticsLabel(_en.adhkarOptionsTitle));
          await _settle(tester);
          await tester.tap(find.text(_en.adhkarAudioTitle));
          await _settle(tester);
        },
      );
    });
  });

  group('home and card', () {
    testWidgets('home, Arabic, Lapis', (tester) async {
      await shot(tester, 'home_ar_lapis', const AdhkarHomeScreen());
    });

    testWidgets('home with progress, Arabic, Aurora', (tester) async {
      await shot(
        tester,
        'home_progress_ar_aurora',
        const AdhkarHomeScreen(),
        theme: MadarThemeId.aurora,
        beforePump: (db) => _progress(db, {
          const AdhkarSetKey(AdhkarCategoryId.morning): AdhkarProgress(
            index: 24,
            counts: {for (var i = 1; i <= 25; i++) 'morning.${i.toString().padLeft(2, '0')}': 100},
            completedAt: DateTime(2026, 9, 28, 6, 40),
          ),
          const AdhkarSetKey(AdhkarCategoryId.evening): const AdhkarProgress(
            index: 6,
            counts: {
              'evening.01': 1,
              'evening.02': 1,
              'evening.03': 3,
              'evening.04': 3,
              'evening.05': 3,
              'evening.06': 1,
            },
          ),
        }),
      );
    });

    testWidgets('home, English, Pearl', (tester) async {
      await shot(
        tester,
        'home_en_pearl',
        const AdhkarHomeScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
      );
    });

    testWidgets('home reminders, English, Emerald', (tester) async {
      await shot(
        tester,
        'home_reminders_en_emerald',
        const AdhkarHomeScreen(),
        theme: MadarThemeId.emerald,
        locale: const Locale('en'),
        beforePump: (db) => Repositories(db).keyValues.setJson(
          'adhkar.reminders',
          const AdhkarReminderSettings(morning: true, evening: false, morningOffsetMin: 20).toJson(),
        ),
        beforeCapture: (tester, _) async {
          await tester.drag(find.byType(ListView), const Offset(0, -1400));
          await _settle(tester);
        },
      );
    });

    testWidgets('home reminders, Arabic, Pearl', (tester) async {
      await shot(
        tester,
        'home_reminders_ar_pearl',
        const AdhkarHomeScreen(),
        theme: MadarThemeId.pearl,
        beforePump: (db) => Repositories(db).keyValues.setJson(
          'adhkar.reminders',
          const AdhkarReminderSettings(morning: true, evening: true, eveningOffsetMin: 10).toJson(),
        ),
        beforeCapture: (tester, _) async {
          await tester.drag(find.byType(ListView), const Offset(0, -1400));
          await _settle(tester);
        },
      );
    });

    testWidgets('before dawn: the on-waking adhkar are the next ones, Arabic, Lapis', (tester) async {
      // 25 minutes before Tuesday's Fajr; Monday night's sleep adhkar said.
      final fajr = PrayerSchedule(const PrayerSettings()).timesFor(DateTime(2026, 9, 29)).fajr;
      await shot(
        tester,
        'home_before_dawn_ar_lapis',
        const AdhkarHomeScreen(),
        now: fajr.subtract(const Duration(minutes: 25)),
        window: PrayerWindow.isha,
        beforePump: (db) => _progress(db, {
          const AdhkarSetKey(AdhkarCategoryId.sleep): AdhkarProgress(
            index: 14,
            counts: {for (final d in _library.category(AdhkarCategoryId.sleep).items) d.id: d.count},
            completedAt: DateTime(2026, 9, 28, 22, 40),
            logged: true,
          ),
        }),
      );
    });

    testWidgets('evening adhkar and those after Asr said, English, Emerald', (tester) async {
      await shot(
        tester,
        'home_moment_done_en_emerald',
        const AdhkarHomeScreen(),
        theme: MadarThemeId.emerald,
        locale: const Locale('en'),
        beforePump: (db) => _progress(db, {
          for (final k in const [
            AdhkarSetKey(AdhkarCategoryId.evening),
            AdhkarSetKey(AdhkarCategoryId.afterPrayer, Prayer.asr),
          ])
            k: AdhkarProgress(completedAt: DateTime(2026, 9, 28, 16, 30), logged: true),
        }),
      );
    });

    testWidgets('reminder on, notifications refused, English, Pearl', (tester) async {
      await shot(
        tester,
        'home_reminders_refused_en_pearl',
        const AdhkarHomeScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        overrides: [adhkarReminderSchedulerProvider.overrideWithValue(const _RefusingScheduler())],
        beforeCapture: (tester, _) async {
          await tester.drag(find.byType(ListView), const Offset(0, -1400));
          await _settle(tester);
          await tester.tap(find.bySemanticsLabel(_en.adhkarReminderEveningLabel).last);
          await _settle(tester);
          await tester.drag(find.byType(ListView), const Offset(0, -400));
          await _settle(tester);
        },
      );
    });

    // The card as it sits on a Faith page: on the app backdrop, near the top.
    Widget card() => MadarScaffold(
      showBack: false,
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: const [
          SizedBox(height: Space.xxl),
          AdhkarTodayCard(),
        ],
      ),
    );

    testWidgets('Faith card, Arabic, Desert', (tester) async {
      await shot(
        tester,
        'today_card_ar_desert',
        card(),
        theme: MadarThemeId.desert,
        beforePump: (db) => _progress(db, {
          const AdhkarSetKey(AdhkarCategoryId.morning): AdhkarProgress(
            counts: const {'morning.01': 1},
            completedAt: DateTime(2026, 9, 28, 6, 40),
            markedDone: true,
          ),
          const AdhkarSetKey(AdhkarCategoryId.evening): const AdhkarProgress(
            index: 3,
            counts: {'evening.01': 1, 'evening.02': 1, 'evening.03': 3},
          ),
        }),
      );
    });

    testWidgets('Faith card, English, Pearl', (tester) async {
      await shot(tester, 'today_card_en_pearl', card(), theme: MadarThemeId.pearl, locale: const Locale('en'));
    });
  });

  group('tasbeeh', () {
    Future<void> taps(WidgetTester tester, int n) async {
      for (var i = 0; i < n; i++) {
        await tester.tapAt(tester.getCenter(find.byType(TasbeehBeadRing)));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await _settle(tester, 20);
    }

    testWidgets('Arabic, Lapis, 12 taps', (tester) async {
      await shot(tester, 'tasbeeh_ar_lapis', const TasbeehScreen(), beforeCapture: (t, _) => taps(t, 12));
    });

    testWidgets('English, Pearl, 20 taps', (tester) async {
      await shot(
        tester,
        'tasbeeh_en_pearl',
        const TasbeehScreen(),
        theme: MadarThemeId.pearl,
        locale: const Locale('en'),
        beforeCapture: (t, _) => taps(t, 20),
      );
    });

    testWidgets('second round, Arabic, Emerald', (tester) async {
      await shot(
        tester,
        'tasbeeh_round_ar_emerald',
        const TasbeehScreen(),
        theme: MadarThemeId.emerald,
        beforeCapture: (t, _) => taps(t, 40),
      );
    });

    testWidgets('99 beads, English, Aurora', (tester) async {
      await shot(
        tester,
        'tasbeeh_99_en_aurora',
        const TasbeehScreen(),
        theme: MadarThemeId.aurora,
        locale: const Locale('en'),
        beforeCapture: (t, _) async {
          await t.tap(find.text('99'));
          await _settle(t);
          await taps(t, 45);
        },
      );
    });

    testWidgets('a phrase typed in English, Arabic UI, Desert', (tester) async {
      await shot(
        tester,
        'tasbeeh_user_phrase_ar_desert',
        const TasbeehScreen(),
        theme: MadarThemeId.desert,
        beforeCapture: (t, env) async {
          await t.runAsync(() => env.container.read(tasbeehControllerProvider.notifier).addPhrase('Glory be to God!'));
          await _settle(t);
          await taps(t, 5);
        },
      );
    });

    testWidgets('phrase editor, Arabic, Desert', (tester) async {
      await shot(
        tester,
        'tasbeeh_phrases_ar_desert',
        const TasbeehScreen(),
        theme: MadarThemeId.desert,
        beforeCapture: (t, _) async {
          await t.tap(find.bySemanticsLabel(_ar.adhkarTasbeehEditPhrases));
          await _settle(t);
        },
      );
    });

    testWidgets('history, English, Lapis', (tester) async {
      await shot(
        tester,
        'tasbeeh_history_en_lapis',
        const TasbeehScreen(),
        locale: const Locale('en'),
        beforePump: (db) async {
          final store = TasbeehStore(Repositories(db));
          await store.startSession(
            phrase: TasbeehDefaults.phrases[0],
            target: 33,
            count: 33,
            at: DateTime(2026, 9, 28, 5, 20),
          );
          await store.startSession(
            phrase: TasbeehDefaults.phrases[4],
            target: 100,
            count: 100,
            at: DateTime(2026, 9, 28, 13, 5),
          );
          await store.startSession(
            phrase: TasbeehDefaults.phrases[5],
            target: 33,
            count: 66,
            at: DateTime(2026, 9, 27, 21, 40),
          );
        },
        beforeCapture: (t, _) async {
          await t.tap(find.bySemanticsLabel(_en.adhkarTasbeehHistory));
          await _settle(t);
        },
      );
    });
  });
}
