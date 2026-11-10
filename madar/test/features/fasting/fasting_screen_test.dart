// «صيامي» in Arabic and in English: the coming reminders in both calendars,
// the log (by hand, removed, each with an undo), the Hijri shift that moves
// the dates, the switches, the empty states that teach - and no overflow at
// 320 dp with the text at 1.3.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/fasting/fasting.dart';
import 'package:madar/features/wird/domain/calendar_days.dart';

import '../adhan/adhan_test_app.dart';
import 'fasting_test_support.dart';

Future<void> _frames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  await _frames(tester, 8);
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await _frames(tester, 8);
}

/// `ensureVisible` can park a control under the frosted app bar, where a tap
/// lands on the header. Nudge the list until it is really pressable.
Future<Finder> _pressable(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await _frames(tester, 4);
  for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 80));
    await _frames(tester, 3);
  }
  expect(target.hitTestable(), findsOneWidget, reason: 'the control never cleared the header');
  return target.hitTestable();
}

/// Brings a (non-interactive) tile into view; no hit test - a plain row has
/// nothing under its centre to hit.
Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await _frames(tester, 4);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.tap(await _pressable(tester, target));
  await _settle(tester);
}

class _Screen {
  _Screen(this.h, this.tester, this.language);

  final AdhanHarness h;
  final WidgetTester tester;
  final String language;

  ProviderContainer get container => h.container(tester);
  L10n get l => lookupL10n(Locale(language));
  FastingTexts get texts => FastingTexts.forLanguage(language);
  FastingRepository get repo => FastingRepository(Repositories(h.db).keyValues);

  Future<T> run<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;
}

Future<_Screen> _pump(
  WidgetTester tester, {
  String language = 'ar',
  DateTime? now,
  Size size = const Size(412, 915),
  double textScale = 1,
  Future<void> Function(FastingRepository repo)? seed,
}) async {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final h = await buildAdhanTestApp(
    tester,
    home: const FastingScreen(animateBackdrop: false),
    now: now ?? DateTime(2026, 11, 10, 13, 0),
    language: language,
  );
  if (seed != null) {
    await tester.runAsync(() => seed(FastingRepository(Repositories(h.db).keyValues)));
  }
  await tester.pumpWidget(h.app);
  await _frames(tester);
  return _Screen(h, tester, language);
}

void main() {
  for (final language in ['ar', 'en']) {
    group(language, () {
      testWidgets('a fresh install: the coming reminders in both calendars, a log that teaches, the shift explained', (tester) async {
        final s = await _pump(tester, language: language);
        final today = DateTime(2026, 11, 10);
        final upcoming = FastingOverview.upcoming(config: cfg(0), today: today);
        expect(upcoming, hasLength(10));

        // Title and the three parts.
        expect(find.text(s.l.fastRemTitle), findsWidgets);
        expect(find.text(s.l.fastRemSectionUpcoming), findsOneWidget);
        expect(find.text(s.l.fastRemSectionLog), findsOneWidget);
        expect(find.text(s.l.fastRemSectionSettings), findsOneWidget);

        // Each row: its date in the week, both calendars and the kind.
        for (final u in upcoming.take(3)) {
          final row = find.byKey(ValueKey('fasting.upcoming.${CalendarDays.key(u.reminder.day)}'));
          await _reveal(tester, row);
          expect(find.descendant(of: row, matching: find.textContaining(s.texts.kind(u.reminder.kind))), findsWidgets);
          expect(
            find.descendant(of: row, matching: find.textContaining(s.texts.hijriDayMonth(u.reminder.hijri))),
            findsOneWidget,
            reason: 'the Hijri date',
          );
          expect(
            find.descendant(of: row, matching: find.textContaining(s.texts.gregorian(u.reminder.day))),
            findsOneWidget,
            reason: 'the Gregorian date',
          );
        }
        expect(find.byKey(const ValueKey('fasting.upcoming.empty')), findsNothing);

        // The log is empty and says what to do.
        await _reveal(tester, find.byKey(const ValueKey('fasting.log.empty')));
        expect(find.text(s.l.fastRemLogEmptyTitle), findsOneWidget);
        expect(find.text(s.l.fastRemLogEmptyBody), findsOneWidget);
        expect(find.text(s.l.fastRemLogToday), findsOneWidget);

        // The shift: explained in one line with its example, as «no shift».
        await _reveal(tester, find.byKey(const ValueKey('fasting.shift')));
        expect(find.text(s.l.fastRemShiftNote), findsOneWidget);
        expect(find.text(s.l.fastRemShiftNone), findsOneWidget);
        expect(find.text(s.l.fastRemNeverNote), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('«سجّل صيام اليوم» logs today with an undo; the month and the year count it; remove it, undo that', (tester) async {
        final s = await _pump(tester, language: language);
        final today = DateTime(2026, 11, 10);
        final key = CalendarDays.key(today);
        final fmt = s.texts.fmt;
        String days(int n) => fmt.localizeDigits(s.l.fastRemStatDays(n));
        Finder stat(String name, String text) =>
            find.descendant(of: find.byKey(ValueKey('fasting.stat.$name')), matching: find.text(text));

        await _reveal(tester, find.byKey(const ValueKey('fasting.stat.month')));
        expect(stat('month', days(0)), findsOneWidget);
        await _tap(tester, find.byKey(const ValueKey('fasting.log.today')));

        // One entry, today, by hand.
        final log = await s.run(() => s.repo.log());
        expect(log, hasLength(1));
        expect(log.single.day, today);
        expect(log.single.source, FastLogSource.manual);
        expect(find.text(s.l.fastRemLogged), findsOneWidget, reason: 'the undo toast');
        expect(find.byKey(ValueKey('fasting.log.$key')), findsOneWidget);
        expect(stat('month', days(1)), findsOneWidget);
        expect(stat('year', days(1)), findsOneWidget);
        expect(find.text(s.l.fastRemLogEmptyTitle), findsNothing);
        // The button is now a quiet "logged" - he cannot log the day twice.
        expect(find.text(s.l.fastRemLogTodayDone), findsOneWidget);
        expect(tester.widget<MadarButton>(find.byKey(const ValueKey('fasting.log.today'))).onPressed, isNull);

        // Undo the log.
        await tester.tap(find.text(s.l.actionUndo).last);
        await _settle(tester);
        expect(await s.run(() => s.repo.log()), isEmpty);
        expect(find.byKey(ValueKey('fasting.log.$key')), findsNothing);
        expect(stat('month', days(0)), findsOneWidget);

        // Log again, then remove the entry from the list - and bring it back.
        await _tap(tester, find.byKey(const ValueKey('fasting.log.today')));
        expect(await s.run(() => s.repo.log()), hasLength(1));
        await tester.pump(const Duration(seconds: 6)); // the first toast goes
        await _tap(tester, find.byKey(ValueKey('fasting.log.remove.$key')));
        expect(await s.run(() => s.repo.log()), isEmpty);
        expect(find.text(s.l.fastRemLogRemoved), findsOneWidget);
        await tester.tap(find.text(s.l.actionUndo).last);
        await _settle(tester);
        expect((await s.run(() => s.repo.log())).single.day, today);
        await tester.pump(const Duration(seconds: 6));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the Shawwal progress reads "n of 6" and the white days are counted on their own', (tester) async {
        // 5 Shawwal 1448 is in the future of this test's date; use the engine's own calendar.
        final year = HijriYearView(1448);
        final shawwal = year.starts[10]!;
        final white = year.civil(11, 14, 0);
        final now = DateTime(white.year, white.month, white.day, 13);
        final s = await _pump(
          tester,
          language: language,
          now: now,
          seed: (repo) async {
            // Three of the six, a white day (a Monday or not - it counts as one white day either way).
            for (final n in [1, 2, 3]) {
              await repo.setLogEntry(FastLogEntry(day: CalendarDays.add(shawwal, n), fasted: true, source: FastLogSource.manual));
            }
            await repo.setLogEntry(FastLogEntry(day: white, fasted: true, source: FastLogSource.manual));
          },
        );
        final fmt = s.texts.fmt;
        // We are in Dhu al-Qa'da 1448; the same Hijri year holds that Shawwal.
        final six = find.descendant(
          of: find.byKey(const ValueKey('fasting.stat.six')),
          matching: find.text(s.l.fastRemSixProgress(fmt.formatInt(3), fmt.formatInt(6))),
        );
        await _reveal(tester, find.byKey(const ValueKey('fasting.stat.six')));
        expect(six, findsOneWidget);
        // The white day is in the white count: this month one, this year one.
        final whiteTile = find.byKey(const ValueKey('fasting.stat.white'));
        await _reveal(tester, whiteTile);
        String days(int n) => fmt.localizeDigits(s.l.fastRemStatDays(n));
        expect(find.descendant(of: whiteTile, matching: find.textContaining('${s.l.fastRemStatMonth}: ${days(1)}')), findsOneWidget);
        expect(find.descendant(of: whiteTile, matching: find.textContaining('${s.l.fastRemStatYear}: ${days(1)}')), findsOneWidget);
        // …while the year total counts every fasted day: three + one.
        expect(
          find.descendant(of: find.byKey(const ValueKey('fasting.stat.year')), matching: find.text(days(4))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('the Hijri day shift is the prayer settings\' own and moves the next reminders', (tester) async {
        final year = HijriYearView(1448);
        final d = year.civil(2, 10, 0); // the white days are three days ahead
        final s = await _pump(tester, language: language, now: DateTime(d.year, d.month, d.day, 13));
        List<String> whites() => [
          for (final u in s.container.read(fastingUpcomingProvider))
            if (u.reminder.kind == FastKind.whiteDay) CalendarDays.key(u.reminder.day),
        ];
        List<String> expected(int offset) => [for (final n in [13, 14, 15]) CalendarDays.key(year.civil(2, n, offset))];
        expect(whites(), expected(0));

        await _tap(tester, find.text(s.l.fastRemShiftAhead));
        // One setting: the prayer settings' own row, and none of ours.
        final prayer = (await s.run(() => Repositories(s.h.db).keyValues.getJson('prayer.settings')))! as Map;
        expect(prayer['hijriOffsetDays'], 1);
        expect((await s.run(() => Repositories(s.h.db).keyValues.getJson(FastingRepository.configKey))), anyOf(isNull, containsPair('hijriOffset', 0)));
        await _settle(tester);
        expect(whites(), expected(1), reason: '"a day ahead": each white day comes a day earlier');
        // The dates on the rows moved with it.
        final first = find.byKey(ValueKey('fasting.upcoming.${expected(1).first}'));
        await _reveal(tester, first);
        expect(first, findsOneWidget);
        expect(find.text(s.l.fastRemShiftChanged), findsOneWidget, reason: 'the undo toast');

        // Undo restores the shift and the dates.
        await tester.tap(find.text(s.l.actionUndo).last);
        await _settle(tester);
        expect(whites(), expected(0));
        expect(((await s.run(() => Repositories(s.h.db).keyValues.getJson('prayer.settings')))! as Map)['hijriOffsetDays'], 0);

        await tester.pump(const Duration(seconds: 6));
        await _tap(tester, find.text(s.l.fastRemShiftBehind));
        await _settle(tester);
        expect(whites(), expected(-1));
        await tester.pump(const Duration(seconds: 6));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the switches: weekly off removes Monday and Thursday; all off shows the empty state; undo brings them back', (tester) async {
        final s = await _pump(tester, language: language);
        Set<FastKind> kinds() => {for (final u in s.container.read(fastingUpcomingProvider)) u.reminder.kind};
        Finder switchOf(String g) => find.descendant(of: find.byKey(ValueKey('fasting.switch.$g')), matching: find.byType(MadarSwitch));
        expect(kinds(), anyOf(contains(FastKind.monday), contains(FastKind.thursday)));

        await _tap(tester, switchOf('weekly'));
        var config = await s.run(() => s.repo.config());
        expect(config.isEnabled(FastKind.monday), isFalse);
        expect(config.isEnabled(FastKind.thursday), isFalse);
        expect(config.isEnabled(FastKind.whiteDay), isTrue, reason: 'only that group');
        expect(kinds().intersection({FastKind.monday, FastKind.thursday}), isEmpty);
        expect(find.text(s.l.fastRemSettingChanged), findsOneWidget, reason: 'the undo toast');

        // Undo (while the toast is still up).
        await tester.tap(find.text(s.l.actionUndo).last);
        await _settle(tester);
        config = await s.run(() => s.repo.config());
        expect(config.disabled, isEmpty);
        await tester.pump(const Duration(seconds: 6));

        for (final g in ['weekly', 'white', 'yearly', 'nudge']) {
          await _tap(tester, switchOf(g));
          await tester.pump(const Duration(seconds: 6));
        }
        expect(await s.run(() => s.repo.config()), isNot(const FastingConfig()));
        await _reveal(tester, find.byKey(const ValueKey('fasting.upcoming.empty')));
        expect(find.text(s.l.fastRemUpcomingEmptyBody), findsOneWidget);
        expect(s.container.read(fastingUpcomingProvider), isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('the first of the six of Shawwal can be moved', (tester) async {
        final s = await _pump(tester, language: language);
        expect((await s.run(() => s.repo.config())).effectiveShawwalStart, 2);
        await _tap(tester, find.text(s.l.fastRemShawwalDay(s.texts.fmt.formatInt(4))));
        expect((await s.run(() => s.repo.config())).shawwalStartDay, 4);
        await tester.pump(const Duration(seconds: 6));
        expect(tester.takeException(), isNull);
      });

      testWidgets('a day he said «ناوي» to asks to be confirmed into the log; a «لأ» tags its row', (tester) async {
        final yesterday = DateTime(2026, 11, 9);
        final s = await _pump(
          tester,
          language: language,
          seed: (repo) async {
            await repo.setIntention(FastIntention(day: yesterday, choice: FastIntentionChoice.yes));
            await repo.setIntention(FastIntention(day: DateTime(2026, 11, 12), choice: FastIntentionChoice.no));
          },
        );
        final card = find.byKey(ValueKey('fasting.confirm.${CalendarDays.key(yesterday)}'));
        await _reveal(tester, card);
        expect(find.text(s.l.fastRemConfirmTitle), findsOneWidget);
        // Thursday 12 Nov: the «لأ» shows on its reminder.
        final thursday = find.byKey(const ValueKey('fasting.upcoming.2026-11-12'));
        await _reveal(tester, thursday);
        expect(find.descendant(of: thursday, matching: find.text(s.l.fastRemAnsweredNo)), findsOneWidget);

        await _tap(tester, find.descendant(of: card, matching: find.byType(MadarButton)));
        final log = await s.run(() => s.repo.log());
        expect(log.single.day, yesterday);
        expect(log.single.source, FastLogSource.reminded);
        expect(card, findsNothing, reason: 'confirmed: the card is gone');
        await tester.pump(const Duration(seconds: 6));
        expect(tester.takeException(), isNull);
      });
    });
  }

  for (final language in ['ar', 'en']) {
    testWidgets('$language: 320 dp wide with the text at 1.3 - every part, nothing overflows, targets are 48 dp', (tester) async {
      final yesterday = DateTime(2026, 11, 6);
      final s = await _pump(
        tester,
        language: language,
        size: const Size(320, 640),
        textScale: 1.3,
        seed: (repo) async {
          await repo.setIntention(FastIntention(day: yesterday, choice: FastIntentionChoice.yes));
          await repo.setIntention(FastIntention(day: DateTime(2026, 11, 12), choice: FastIntentionChoice.yes));
          for (final n in [1, 2, 3, 5]) {
            await repo.setLogEntry(
              FastLogEntry(day: DateTime(2026, 11, 10 - n), fasted: true, source: FastLogSource.manual, kind: FastKind.monday),
            );
          }
        },
      );
      // Scroll the whole page, top to bottom.
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 14; i++) {
        await tester.drag(list, const Offset(0, -400));
        await _frames(tester, 3);
        expect(tester.takeException(), isNull, reason: 'overflow after scrolling $i times');
      }
      // The big controls clear 48 dp.
      for (final key in const ['fasting.log.today']) {
        await _pressable(tester, find.byKey(ValueKey(key)));
        expect(tester.getSize(find.byKey(ValueKey(key))).height, greaterThanOrEqualTo(48));
      }
      final remove = find.byWidgetPredicate((w) => w is MadarButton && w.isIconOnly);
      await _pressable(tester, remove.first);
      for (final e in tester.widgetList(remove)) {
        final size = tester.getSize(find.byWidget(e));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
      expect(s.container.read(fastingUpcomingProvider), isNotEmpty);
      expect(tester.takeException(), isNull);
    });
  }
}
