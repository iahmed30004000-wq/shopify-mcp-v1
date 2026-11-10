// «رمضان» in Arabic and in English, at 320 dp with the text at 1.3: the five
// tabs (today, the Taraweeh log, the khatmah, the last ten nights, this year
// beside last), every write with an undo, the empty states that teach, the
// supplication slot that is only ever his own text - and no overflow.
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart' show MadarButton, MadarSwitch;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/ramadan/ramadan.dart';

import '../adhan/adhan_test_app.dart';

Future<void> _frames(WidgetTester tester, [int n = 14]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  await _frames(tester, 6);
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await _frames(tester, 8);
}

/// The vertical page (the tabs above it scroll sideways and stay put).
Finder _page() => find.byType(ListView).first;

/// `ensureVisible` can park a control under the frosted app bar, where a tap
/// lands on the header. Nudge the list until it is really pressable.
Future<Finder> _pressable(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await _frames(tester, 4);
  for (var i = 0; i < 8 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(_page(), const Offset(0, 80));
    await _frames(tester, 3);
  }
  expect(target.hitTestable(), findsOneWidget, reason: 'the control never cleared the header: $target');
  return target.hitTestable();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await _frames(tester, 4);
}

/// The switch inside a settings row (the row itself is not the target).
Finder _switchOf(String key) => find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(MadarSwitch));

/// Lets the undo toasts expire: they sit above every sheet and would cover its buttons.
Future<void> _quiet(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await _frames(tester, 3);
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
  RamadanTexts get texts => RamadanTexts.forLanguage(language);
  RamadanRepository get repo => RamadanRepository(Repositories(h.db).keyValues);

  Future<T> run<T>(Future<T> Function() f) async => (await tester.runAsync(f)) as T;

  Future<void> tab(RamadanTab t) => _tap(tester, find.byKey(ValueKey('ramadan.tab.${t.name}')));
}

/// Day 13 of Ramadan 1448 (20 February 2027), noon, in Amman.
final _inRamadan = DateTime(2027, 2, 20, 12);

Future<_Screen> _pump(
  WidgetTester tester, {
  String language = 'ar',
  DateTime? now,
  Size size = const Size(412, 915),
  double textScale = 1,
  RamadanTab tab = RamadanTab.today,
  Future<void> Function(RamadanRepository repo)? seed,
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
    home: RamadanScreen(animateBackdrop: false, initialTab: tab),
    now: now ?? _inRamadan,
    language: language,
  );
  if (seed != null) await tester.runAsync(() => seed(RamadanRepository(Repositories(h.db).keyValues)));
  await tester.pumpWidget(h.app);
  await _frames(tester);
  return _Screen(h, tester, language);
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  for (final language in ['ar', 'en']) {
    group(language, () {
      testWidgets('today: the day, the live countdown, tonight\'s Taraweeh, the portion and the settings; five tabs', (tester) async {
        final s = await _pump(tester, language: language);
        expect(find.text(s.l.ramadanTitle), findsWidgets);
        for (final label in [s.l.ramadanTabToday, s.l.ramadanTabTaraweeh, s.l.ramadanTabKhatmah, s.l.ramadanTabLastTen, s.l.ramadanTabCompare]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(find.text(s.l.ramadanDayOf(s.texts.number(13))), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.countdown.iftar')), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.countdown.time')), findsOneWidget);
        await _reveal(tester, find.byKey(const ValueKey('ramadan.today.tonight')));
        expect(find.text(s.l.ramadanTaraweehTonight(s.texts.number(14))), findsOneWidget);
        await _reveal(tester, find.byKey(const ValueKey('ramadan.today.portion')));
        // Nothing read yet: the 604 pages are re-planned over the 17 days left,
        // 36 on each of the first twelve, so today's portion is pages 1 to 36.
        expect(find.text(s.l.ramadanKhatmahPages(s.texts.number(1), s.texts.number(36))), findsOneWidget);
        // The settings are there, with the shift explained.
        for (final key in ['atmosphere', 'suhoor', 'iftar', 'taraweeh', 'lastTen', 'khatmah']) {
          await _reveal(tester, find.byKey(ValueKey('ramadan.switch.$key')));
        }
        await _reveal(tester, find.byKey(const ValueKey('ramadan.shift')));
        expect(find.text(s.l.fastRemShiftNote), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _leave(tester);
      });

      testWidgets('tonight\'s switch on today logs night 14 and an undo takes it back', (tester) async {
        final s = await _pump(tester, language: language);
        await _tap(tester, _switchOf('ramadan.today.tonight'));
        expect((await s.run(() => s.repo.logBook())).of(1448)!.taraweeh.isDone(14), isTrue);
        expect(find.text(s.l.ramadanTaraweehLoggedToast), findsOneWidget);
        await _tap(tester, find.text(s.l.actionUndo));
        expect((await s.run(() => s.repo.logBook())).of(1448)?.taraweeh.isDone(14) ?? false, isFalse);
        await _leave(tester);
      });

      testWidgets('Taraweeh tab: the 29 nights of the month; one tap logs a night, with its undo; the rakaat is optional', (tester) async {
        final s = await _pump(tester, language: language, tab: RamadanTab.taraweeh);
        for (var n = 1; n <= 29; n++) {
          await _reveal(tester, find.byKey(ValueKey('ramadan.night.$n')));
          expect(find.byKey(ValueKey('ramadan.night.$n')), findsOneWidget);
          final size = tester.getSize(find.byKey(ValueKey('ramadan.night.$n')));
          expect(size.width, greaterThanOrEqualTo(48), reason: 'night $n');
          expect(size.height, greaterThanOrEqualTo(48), reason: 'night $n');
        }
        expect(find.byKey(const ValueKey('ramadan.night.30')), findsNothing, reason: '1448 has 29 days');
        // Tonight (14) is preselected: its detail is open.
        expect(find.byKey(const ValueKey('ramadan.taraweeh.done')), findsOneWidget);

        await _tap(tester, find.byKey(const ValueKey('ramadan.night.5')));
        var log = (await s.run(() => s.repo.logBook())).of(1448)!.taraweeh;
        expect(log.isDone(5), isTrue, reason: 'one tap');
        expect(log.entryOf(5)!.rakaat, isNull);
        expect(find.text(s.l.ramadanTaraweehLoggedToast), findsOneWidget);
        // Its detail opened, and says the night.
        expect(find.text(s.l.ramadanNightTitle(s.texts.number(5))), findsWidgets);

        // A second tap on the same night un-logs it.
        await _quiet(tester);
        await _tap(tester, find.byKey(const ValueKey('ramadan.night.5')));
        log = (await s.run(() => s.repo.logBook())).of(1448)!.taraweeh;
        expect(log.isDone(5), isFalse);

        // Undo brings it back.
        await _tap(tester, find.text(s.l.actionUndo));
        log = (await s.run(() => s.repo.logBook())).of(1448)!.taraweeh;
        expect(log.isDone(5), isTrue);

        // The summary counts.
        expect(find.text(s.l.ramadanTaraweehSummary(s.texts.number(1), s.texts.number(29))), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('Taraweeh tab: the rakaat count is typed in a sheet, saved with the night, and undoable', (tester) async {
        final s = await _pump(tester, language: language, tab: RamadanTab.taraweeh);
        await _tap(tester, find.byKey(const ValueKey('ramadan.night.9')));
        await _quiet(tester);
        await _tap(tester, find.byKey(const ValueKey('ramadan.taraweeh.rakaat')));
        await tester.enterText(find.byType(TextField).last, '8');
        await _frames(tester, 4);
        await tester.tap(find.text(s.l.actionSave));
        await _settle(tester);
        final entry = (await s.run(() => s.repo.logBook())).of(1448)!.taraweeh.entryOf(9)!;
        expect((entry.done, entry.rakaat), (true, 8));
        expect(find.text(s.texts.rakaat(8)), findsOneWidget);
        expect(find.text(s.l.ramadanTaraweehRakaatToast), findsOneWidget);
        await _tap(tester, find.text(s.l.actionUndo));
        final back = (await s.run(() => s.repo.logBook())).of(1448)!.taraweeh.entryOf(9)!;
        expect(back.rakaat, isNull);
        expect(back.done, isTrue);
        await _leave(tester);
      });

      testWidgets('khatmah: today\'s portion, mark it read with an undo, open the Quran button is there', (tester) async {
        final s = await _pump(tester, language: language, tab: RamadanTab.khatmah);
        expect(find.byKey(const ValueKey('ramadan.khatmah.portion')), findsOneWidget);
        expect(find.text(s.l.ramadanKhatmahPages(s.texts.number(1), s.texts.number(36))), findsOneWidget);
        expect(find.text(s.l.ramadanKhatmahDayOf(s.texts.number(13), s.texts.number(29))), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.khatmah.openQuran')), findsOneWidget);
        // Twelve days behind the plan: nothing was ever marked.
        expect(find.byKey(const ValueKey('ramadan.khatmah.replan')), findsOneWidget);

        await _tap(tester, find.byKey(const ValueKey('ramadan.khatmah.mark')));
        final record = (await s.run(() => s.repo.khatmahs()))[1448]!;
        expect(record.progress.frontier, 36, reason: 'today\'s whole portion');
        expect((await s.run(() => s.repo.logBook())).of(1448)!.pagesRead, 36, reason: 'the year\'s log follows');
        expect(find.text(s.l.ramadanKhatmahDoneToday), findsWidgets);
        expect(find.text(s.l.ramadanKhatmahMarkedToast), findsOneWidget);
        await _tap(tester, find.text(s.l.actionUndo));
        expect((await s.run(() => s.repo.khatmahs()))[1448], isNull, reason: 'undo puts back "nothing stored"');
        await _leave(tester);
      });

      testWidgets('khatmah: after missed days the re-plan is said in plain words, and the ceiling he sets is never exceeded', (tester) async {
        final s = await _pump(tester, language: language, tab: RamadanTab.khatmah);
        final replan = find.byKey(const ValueKey('ramadan.khatmah.replan'));
        // Day 13 with nothing read: 252 pages behind the even plan; 604 over 17 days fits under 40 a day.
        expect(find.descendant(of: replan, matching: find.textContaining(s.texts.pages(252))), findsOneWidget);
        // Lower the ceiling to 15: the rest cannot fit in the days left, and the screen says by how much.
        await _tap(tester, find.descendant(of: find.byKey(const ValueKey('ramadan.khatmah.ceiling')), matching: find.text(s.texts.pages(15))));
        final record = (await s.run(() => s.repo.khatmahs()))[1448]!;
        expect(record.plan.ceilingPages, 15);
        final today = record.plan.today(DateTime(2027, 2, 20), record.progress);
        expect(today.portion.pages, lessThanOrEqualTo(15), reason: 'never above the ceiling');
        expect(today.shortfallPages, greaterThan(0));
        expect(today.suggestedExtensionDays, greaterThan(0));
        expect(
          find.descendant(
            of: replan,
            matching: find.textContaining(s.l.ramadanKhatmahShortfall(s.texts.pages(today.shortfallPages), s.texts.days(today.suggestedExtensionDays))),
          ),
          findsOneWidget,
        );
        expect(find.text(s.l.ramadanKhatmahCeilingToast), findsOneWidget);
        await _leave(tester);
      });

      testWidgets('last ten nights: nights 21-29 with the odd ones starred; the supplication slot is empty and asks for HIS text', (tester) async {
        final s = await _pump(tester, language: language, tab: RamadanTab.lastTen, now: DateTime(2027, 3, 1, 12));
        for (var n = 21; n <= 29; n++) {
          await _reveal(tester, find.byKey(ValueKey('ramadan.lastTen.$n')));
          expect(find.byKey(ValueKey('ramadan.lastTen.$n')), findsOneWidget);
        }
        expect(find.byKey(const ValueKey('ramadan.lastTen.20')), findsNothing);
        expect(find.byKey(const ValueKey('ramadan.lastTen.30')), findsNothing);
        // Stars on the odd nights only.
        for (final n in [21, 23, 25, 27, 29]) {
          expect(find.descendant(of: find.byKey(ValueKey('ramadan.lastTen.$n')), matching: find.byIcon(Icons.star_rounded)), findsOneWidget, reason: 'night $n');
        }
        for (final n in [22, 24, 26, 28]) {
          expect(find.descendant(of: find.byKey(ValueKey('ramadan.lastTen.$n')), matching: find.byIcon(Icons.star_rounded)), findsNothing, reason: 'night $n');
        }
        // The slot: nothing is written for him.
        await _reveal(tester, find.byKey(const ValueKey('ramadan.qadr.empty')));
        expect(find.text(s.l.ramadanQadrEmpty), findsOneWidget);
        if (language == 'ar') expect(s.l.ramadanQadrEmpty, 'ضيف الدعاء بنصّه ومصدره');
        expect(find.byKey(const ValueKey('ramadan.qadr.text')), findsNothing);
        expect(find.byKey(const ValueKey('ramadan.qadr.filled')), findsNothing);
        expect(tester.takeException(), isNull);
        await _leave(tester);
      });

      testWidgets('the supplication: he types its text, source and grading; they show back as typed, the source and grading under it; editable and clearable', (tester) async {
        final s = await _pump(tester, language: language, tab: RamadanTab.lastTen, now: DateTime(2027, 3, 1, 12));
        await _tap(tester, find.byKey(const ValueKey('ramadan.qadr.add')));
        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(3));
        await tester.enterText(fields.at(0), 'نصّ كتبه صاحب الجهاز');
        await tester.enterText(fields.at(1), 'كتاب كذا، رقم ١');
        await tester.enterText(fields.at(2), 'صحيح');
        await _frames(tester, 4);
        await tester.tap(find.text(s.l.actionSave));
        await _settle(tester);
        expect(await s.run(() => s.repo.supplication()), const QadrSupplication(text: 'نصّ كتبه صاحب الجهاز', source: 'كتاب كذا، رقم ١', grading: 'صحيح'));
        await _reveal(tester, find.byKey(const ValueKey('ramadan.qadr.text')));
        expect(find.text('نصّ كتبه صاحب الجهاز'), findsOneWidget);
        expect(find.text(s.l.ramadanQadrSource('كتاب كذا، رقم ١')), findsOneWidget);
        expect(find.text(s.l.ramadanQadrGrading('صحيح')), findsOneWidget);
        // The source and the grading sit under the text.
        final textY = tester.getTopLeft(find.byKey(const ValueKey('ramadan.qadr.text'))).dy;
        expect(tester.getTopLeft(find.byKey(const ValueKey('ramadan.qadr.source'))).dy, greaterThan(textY));
        expect(tester.getTopLeft(find.byKey(const ValueKey('ramadan.qadr.grading'))).dy, greaterThan(tester.getTopLeft(find.byKey(const ValueKey('ramadan.qadr.source'))).dy));

        // Edit: the sheet opens on what he wrote.
        await _quiet(tester);
        await _tap(tester, find.byKey(const ValueKey('ramadan.qadr.edit')));
        expect(find.text('نصّ كتبه صاحب الجهاز'), findsWidgets);
        await tester.enterText(find.byType(TextField).at(1), 'مصدر آخر');
        await _frames(tester, 4);
        await tester.tap(find.text(s.l.actionSave));
        await _settle(tester);
        expect((await s.run(() => s.repo.supplication()))!.source, 'مصدر آخر');

        // Clear, with an undo.
        await _quiet(tester);
        await _tap(tester, find.byKey(const ValueKey('ramadan.qadr.clear')));
        expect(await s.run(() => s.repo.supplication()), isNull);
        await _tap(tester, find.text(s.l.actionUndo));
        expect((await s.run(() => s.repo.supplication()))!.text, 'نصّ كتبه صاحب الجهاز');
        await _leave(tester);
      });

      testWidgets('a supplication without a source says so gently; nothing is shown as an authority', (tester) async {
        final s = await _pump(
          tester,
          language: language,
          tab: RamadanTab.lastTen,
          now: DateTime(2027, 3, 1, 12),
          seed: (repo) => repo.saveSupplication(const QadrSupplication(text: 'نص فقط')),
        );
        await _reveal(tester, find.byKey(const ValueKey('ramadan.qadr.text')));
        expect(find.text('نص فقط'), findsOneWidget);
        expect(find.text(s.l.ramadanQadrNoSource), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.qadr.source')), findsNothing);
        expect(find.byKey(const ValueKey('ramadan.qadr.grading')), findsNothing);
        await _leave(tester);
      });

      testWidgets('a night\'s note: written for night 27, kept, shown, undoable - and it does not mark the night prayed', (tester) async {
        final s = await _pump(tester, language: language, tab: RamadanTab.lastTen, now: DateTime(2027, 3, 4, 12)); // day 25: tonight is 26
        await _tap(tester, find.byKey(const ValueKey('ramadan.lastTen.27')));
        await _tap(tester, find.byKey(const ValueKey('ramadan.lastTen.note')));
        await tester.enterText(find.byType(TextField).last, 'قمنا في المسجد');
        await _frames(tester, 4);
        await tester.tap(find.text(s.l.actionSave));
        await _settle(tester);
        final entry = (await s.run(() => s.repo.logBook())).of(1448)!.taraweeh.entryOf(27)!;
        expect(entry.note, 'قمنا في المسجد');
        expect(entry.done, isFalse, reason: 'a note alone is not a prayed night');
        expect(find.textContaining('قمنا في المسجد'), findsOneWidget);
        await _tap(tester, find.text(s.l.actionUndo));
        expect((await s.run(() => s.repo.logBook())).of(1448)!.taraweeh.entryOf(27), isNull);
        await _leave(tester);
      });

      testWidgets('compare: with one year the empty state teaches; with two, the totals side by side and what changed', (tester) async {
        final s = await _pump(tester, language: language, tab: RamadanTab.compare);
        expect(find.byKey(const ValueKey('ramadan.compare.empty')), findsOneWidget);
        expect(find.text(s.l.ramadanCompareEmptyTitle), findsOneWidget);
        expect(find.text(s.l.ramadanCompareEmptyBody), findsOneWidget);
        await _leave(tester);

        final t = await _pump(
          tester,
          language: language,
          tab: RamadanTab.compare,
          seed: (repo) async {
            for (final n in [1, 2, 3]) {
              await repo.setTaraweeh(1447, n, TaraweehEntry(night: n, rakaat: 8));
            }
            for (final n in [1, 2, 3, 4, 5]) {
              await repo.setTaraweeh(1448, n, TaraweehEntry(night: n, rakaat: n == 1 ? 20 : null));
            }
          },
        );
        expect(find.byKey(const ValueKey('ramadan.compare.empty')), findsNothing);
        await _reveal(tester, find.byKey(const ValueKey('ramadan.compare.years')));
        expect(find.text(t.l.ramadanCompareYear(t.texts.number(1448))), findsOneWidget);
        expect(find.text(t.l.ramadanCompareYear(t.texts.number(1447))), findsOneWidget);
        final nights = find.byKey(const ValueKey('ramadan.compare.nights'));
        await _reveal(tester, nights);
        // 5 nights this year, 3 last year: two more.
        expect(find.descendant(of: nights, matching: find.text(t.l.ramadanCompareMore(t.texts.nights(2)))), findsOneWidget);
        // Rakaat: 20 now, 24 then: four fewer.
        final rakaat = find.byKey(const ValueKey('ramadan.compare.rakaat'));
        await _reveal(tester, rakaat);
        expect(find.descendant(of: rakaat, matching: find.text(t.l.ramadanCompareLess(t.texts.rakaat(4)))), findsOneWidget);
        // Fasting was not tracked: the row is not made up.
        expect(find.byKey(const ValueKey('ramadan.compare.fasting')), findsNothing);
        await _reveal(tester, find.byKey(const ValueKey('ramadan.compare.strip')));
        await _leave(tester);
      });

      testWidgets('outside Ramadan (10 November): the countdown to Ramadan, and every tab teaches instead of showing empty boxes', (tester) async {
        final s = await _pump(tester, language: language, now: DateTime(2026, 11, 10, 12));
        expect(find.text(s.l.ramadanComingTitle(s.texts.days(90))), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.countdown.iftar')), findsNothing);
        expect(find.byKey(const ValueKey('ramadan.today.tonight')), findsNothing);
        expect(find.text(s.l.ramadanFarHint), findsOneWidget);
        await _reveal(tester, find.byKey(const ValueKey('ramadan.switch.atmosphere')));

        await s.tab(RamadanTab.taraweeh);
        expect(find.byKey(const ValueKey('ramadan.taraweeh.empty')), findsOneWidget, reason: 'taraweeh tab');
        await s.tab(RamadanTab.khatmah);
        expect(find.text(s.l.ramadanKhatmahNotStarted), findsOneWidget, reason: 'khatmah tab');
        expect(find.byKey(const ValueKey('ramadan.khatmah.mark')), findsOneWidget, reason: 'mark button');
        // He can already set his daily limit; marking today read is not offered yet.
        final mark = tester.widget<MadarButton>(find.byKey(const ValueKey('ramadan.khatmah.mark')));
        expect(mark.onPressed, isNull);
        await s.tab(RamadanTab.lastTen);
        expect(find.text(s.l.ramadanLastTenEmpty), findsOneWidget);
        expect(find.byKey(const ValueKey('ramadan.qadr.empty')), findsOneWidget, reason: 'the slot is his at any time of the year');
        await s.tab(RamadanTab.compare);
        expect(find.byKey(const ValueKey('ramadan.compare.empty')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _leave(tester);
      });

      testWidgets('settings: the atmosphere switch, a lead time and the Hijri shift are written, each with an undo', (tester) async {
        final s = await _pump(tester, language: language);
        await _tap(tester, _switchOf('ramadan.switch.atmosphere'));
        expect((await s.run(() => s.repo.config())).atmosphere, isFalse);
        expect(find.text(s.l.ramadanSettingChanged), findsOneWidget);
        await _tap(tester, find.text(s.l.actionUndo));
        expect((await s.run(() => s.repo.config())).atmosphere, isTrue);

        await _quiet(tester);
        // The iftar lead: 15 by default, 30 chosen.
        final lead = find.byKey(const ValueKey('ramadan.lead.iftar'));
        await _reveal(tester, lead);
        await _tap(tester, find.descendant(of: lead, matching: find.text(s.texts.minutes(30))));
        expect((await s.run(() => s.repo.config())).iftarLeadMinutes, 30);
        // Suhoor off: its lead row goes away.
        expect(find.byKey(const ValueKey('ramadan.lead.suhoor')), findsOneWidget);
        await _tap(tester, _switchOf('ramadan.switch.suhoor'));
        expect(find.byKey(const ValueKey('ramadan.lead.suhoor')), findsNothing);

        await _quiet(tester);
        // The Hijri shift is the prayer settings' own.
        final shift = find.byKey(const ValueKey('ramadan.shift'));
        await _reveal(tester, shift);
        await _tap(tester, find.descendant(of: shift, matching: find.text(s.l.fastRemShiftAhead)));
        expect((await s.run(() => OrbitRepository(Repositories(s.h.db)).prayerSettings())).hijriOffsetDays, 1);
        // And back.
        await _quiet(tester);
        await _tap(tester, find.text(s.l.fastRemShiftNone));
        expect((await s.run(() => OrbitRepository(Repositories(s.h.db)).prayerSettings())).hijriOffsetDays, 0);
        await _leave(tester);
      });

      for (final tab in RamadanTab.values) {
        testWidgets('${tab.name} at 320 dp with the text at 1.3: no overflow, targets of 48 dp', (tester) async {
          final s = await _pump(
            tester,
            language: language,
            size: const Size(320, 640),
            textScale: 1.3,
            tab: tab,
            now: DateTime(2027, 3, 1, 12), // day 22: the last ten are on
            seed: (repo) async {
              await repo.setTaraweeh(1447, 3, const TaraweehEntry(night: 3));
              await repo.setTaraweeh(1448, 3, const TaraweehEntry(night: 3, rakaat: 8, note: 'ملاحظة طويلة قليلاً لتتأكد من أن النص يلتف ولا يفيض'));
              await repo.saveSupplication(const QadrSupplication(text: 'نص طويل قليلاً يكتبه هو بنفسه ليتأكد الفحص من أن السطور تلتف', source: 'مصدر طويل قليلاً من الكتاب ورقم الحديث', grading: 'درجة'));
            },
          );
          // Walk the whole page: every control is reachable and none overflows.
          final scrollable = _page();
          for (var i = 0; i < 12; i++) {
            await tester.drag(scrollable, const Offset(0, -300));
            await _frames(tester, 3);
          }
          expect(tester.takeException(), isNull, reason: '${tab.name} in $language');
          await tester.drag(scrollable, const Offset(0, 6000));
          await _frames(tester, 4);
          // The tabs themselves stay 48 dp tall targets.
          for (final t in RamadanTab.values) {
            final size = tester.getSize(find.byKey(ValueKey('ramadan.tab.${t.name}')));
            expect(size.height, greaterThanOrEqualTo(48), reason: t.name);
          }
          await _leave(tester);
        });
      }
    });
  }
}
