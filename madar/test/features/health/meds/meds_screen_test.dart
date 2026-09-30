import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/health/meds/meds.dart';

import 'meds_harness.dart';

/// Scrolls the Today list to [name]'s dose and returns its tile.
Future<Finder> scrollToDose(WidgetTester tester, String name) async {
  await tester.scrollUntilVisible(find.text(name), 200, scrollable: find.byType(Scrollable).first);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
  await settleMeds(tester);
  return find.ancestor(of: find.text(name), matching: find.byType(DoseTile)).first;
}

void main() {
  Future<MedsScenario> seed(MadarDatabase db) => seedMedsScenario(db, lang: 'en');

  Future<List<MedDoseRow>> rowsOf(WidgetTester tester, MedsTestEnv env, String medId) async =>
      (await tester.runAsync(() => env.repos.medDoses.getAll(where: (d) => d.medicationId.equals(medId))))!;

  testWidgets('Taken on a due dose records it, celebrates and offers Undo', (tester) async {
    late MedsScenario s;
    final env = await pumpMedsApp(
      tester,
      home: const MedsScreen(),
      locale: const Locale('en'),
      beforePump: (db) async => s = await seed(db),
    );
    // Omega-3 (13:00) is due now.
    final omegaCard = await scrollToDose(tester, 'Omega-3');
    await tester.tap(find.descendant(of: omegaCard, matching: find.text('Taken')));
    await settleMeds(tester);
    var rows = (await rowsOf(tester, env, s.omega)).where((r) => r.scheduledAt == DateTime(2026, 9, 29, 13)).toList();
    expect(rows.single.status, DoseStatus.taken);
    expect(rows.single.takenAt, medsTestNow);
    expect(env.sound.played, contains(Sfx.complete));
    expect(find.textContaining('logged as taken'), findsOneWidget);
    // Stock went 5 → 4.
    expect((await tester.runAsync(() => env.repos.medications.byId(s.omega)))!.stock, 4);

    await tester.tap(find.text('Undo'));
    await settleMeds(tester);
    rows = (await rowsOf(tester, env, s.omega)).where((r) => r.scheduledAt == DateTime(2026, 9, 29, 13)).toList();
    expect(rows, isEmpty);
    expect((await tester.runAsync(() => env.repos.medications.byId(s.omega)))!.stock, 5);
  });

  testWidgets('Snooze asks how long, then snoozes', (tester) async {
    late MedsScenario s;
    final env = await pumpMedsApp(
      tester,
      home: const MedsScreen(),
      locale: const Locale('en'),
      beforePump: (db) async => s = await seed(db),
    );
    final card = await scrollToDose(tester, 'Omega-3');
    await tester.tap(find.descendant(of: card, matching: find.text('Snooze')));
    await settleMeds(tester);
    // A no-break space keeps "30 min" on one line.
    expect(find.text('30\u00A0min'), findsOneWidget);
    await tester.tap(find.text('30\u00A0min'));
    await settleMeds(tester);
    final row = (await rowsOf(tester, env, s.omega)).singleWhere((r) => r.scheduledAt == DateTime(2026, 9, 29, 13));
    expect(row.status, DoseStatus.snoozed);
    expect(row.takenAt, medsTestNow.add(const Duration(minutes: 30)));
    expect(find.textContaining('snoozed until'), findsOneWidget);
  });

  testWidgets('a new medication from the editor lands in My meds with its times', (tester) async {
    final env = await pumpMedsApp(tester, home: const MedsScreen(), locale: const Locale('en'));
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await settleMeds(tester);
    expect(find.text('New medication'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Vitamin D');
    await tester.pump();
    await tester.tap(find.text('Fixed time'));
    await settleMeds(tester);
    await tester.tap(find.text('Save'));
    await settleMeds(tester);
    final meds = (await tester.runAsync(() => env.repos.medications.getAll()))!;
    expect(meds.single.name, 'Vitamin D');
    expect(meds.single.times, ['08:00']);
    await tester.tap(find.text('My meds'));
    await settleMeds(tester);
    expect(find.text('Vitamin D'), findsWidgets);
  });

  testWidgets('an unsaved editor asks before discarding', (tester) async {
    await pumpMedsApp(tester, home: const MedsScreen(), locale: const Locale('en'));
    await tester.tap(find.byIcon(Icons.add_rounded).last);
    await settleMeds(tester);
    await tester.enterText(find.byType(TextField).first, 'X');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await settleMeds(tester);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.byType(MedicationEditor), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await settleMeds(tester);
    expect(find.byType(MedicationEditor), findsNothing);
  });

  testWidgets('the Arabic screen renders RTL with Arabic-Indic digits, reduced motion included', (tester) async {
    await pumpMedsApp(tester, home: const MedsScreen(), beforePump: seedMedsScenario, reducedMotion: true);
    expect(find.text('الأدوية والمكمّلات'), findsOneWidget);
    expect(find.text('أُخذت ٣ من ٨'), findsOneWidget);
    final title = tester.getCenter(find.text('جرعات اليوم'));
    final ring = tester.getCenter(find.byType(ProgressRing).first);
    // The ring sits at the reading start (right) in Arabic.
    expect(ring.dx, greaterThan(title.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the reminders follow the plan on the fake platform', (tester) async {
    final env = await pumpMedsApp(
      tester,
      home: const MedsScreen(),
      locale: const Locale('en'),
      beforePump: (db) => seed(db),
    );
    // The screen keeps the reminders planned (the sync ran while settling).
    final doses = env.notifications.scheduled.values.where((f) => MedsNotificationIds.isDose(f.request.id)).toList();
    expect(doses, isNotEmpty);
    expect(doses.every((f) => f.request.at.isAfter(medsTestNow)), isTrue);
    expect(doses.every((f) => f.request.actions.length == 3), isTrue);
  });

  testWidgets('the Today card takes a dose with one tap', (tester) async {
    late MedsScenario s;
    final env = await pumpMedsApp(
      tester,
      home: const MadarScaffold(body: Column(children: [TodayDosesCard()])),
      locale: const Locale('en'),
      beforePump: (db) async => s = await seed(db),
    );
    expect(find.text('3 of 8 taken'), findsOneWidget);
    final line = find.ancestor(of: find.textContaining('Magnesium'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: line, matching: find.byIcon(Icons.check_rounded)));
    await settleMeds(tester);
    final row = (await rowsOf(tester, env, s.magnesium)).singleWhere((r) => r.scheduledAt == DateTime(2026, 9, 29, 11));
    expect(row.status, DoseStatus.taken);
    expect(find.text('4 of 8 taken'), findsOneWidget);
  });
}
