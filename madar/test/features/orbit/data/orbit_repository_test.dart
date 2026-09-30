import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/neglect_text.dart';
import 'package:madar/features/orbit/domain/orbit_moons.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/work/work.dart' show WorkService;

import 'orbit_fixtures.dart';

const _fsi = '\u2068', _pdi = '\u2069';
String iso(String s) => '$_fsi$s$_pdi';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late OrbitRepository repo;

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    repo = OrbitRepository(repos, clock: () => fixtureNow);
  });
  tearDown(() => db.close());

  group('fresh install', () {
    test('eight dormant planets in seeded order, calm balance, empty radar', () async {
      final snap = await repo.snapshot();
      expect(snap.planets.map((p) => p.key), [
        'faith',
        'health',
        'family',
        'work',
        'money',
        'growth',
        'body',
        'travel',
      ]);
      expect(snap.planets.map((p) => p.name), [
        'الإيمان',
        'الصحة',
        'العائلة',
        'العمل',
        'المال',
        'النمو',
        'الجسد',
        'السفر',
      ]);
      expect(snap.planets.every((p) => p.state == PlanetState.dormant), isTrue);
      expect(snap.balanceDormant, isTrue);
      expect(snap.balance, 0.6);
      expect(snap.radar, isEmpty);
      // Built-in planets keep their curated palettes.
      expect(snap.planets.first.palette, same(PlanetPalettes.faith));
      expect(snap.planets.every((p) => p.moons.isEmpty), isTrue);
    });

    test('English names and prayer state from the Amman defaults', () async {
      final snap = await repo.snapshot(languageCode: 'en');
      expect(snap.planets.map((p) => p.name).first, 'Faith');
      final schedule = PrayerSchedule(const PrayerSettings());
      final w = schedule.windowAt(fixtureNow);
      expect(snap.prayer.currentWindow, w.window);
      expect(snap.prayer.countdownTarget, w.nextPrayerAt);
      expect(snap.prayer.nextPrayer, w.nextPrayer);
      expect(snap.prayer.settings.latitude, closeTo(31.95, 0.01));
      expect(snap.prayer.logged, isEmpty);
    });
  });

  group('score inputs from real rows', () {
    test('doses: every daily slot of the last three days vs the dose log', () async {
      final ids = await seedLivedIn(repos, thriving: false);
      final inputs = await repo.scoreInputs();
      final metformin = inputs.doses3d.where((d) => d.medId == ids.metformin).toList();
      // 08:00 and 20:00 on the two previous days + today's 08:00 (20:00 is ahead).
      expect(metformin, hasLength(5));
      expect(metformin.map((d) => d.scheduledAt.hour), [8, 20, 8, 20, 8]);
      // Only the day before yesterday was logged.
      expect(metformin.map((d) => d.taken), [true, true, false, false, false]);
      final vitD = inputs.doses3d.where((d) => d.medId == ids.vitaminD).toList();
      expect(vitD.map((d) => d.taken), [true, false, false]);
    });

    test('doses logged without a scheduled time match the nearest slot', () async {
      final med = await repos.medications.insert(
        MedicationsCompanion.insert(
          name: 'Iron',
          times: const Value(['10:00']),
          createdAt: Value(fixtureNow.subtract(const Duration(days: 5))),
        ),
      );
      await repos.medDoses.insert(
        MedDosesCompanion.insert(
          medicationId: med.id,
          takenAt: Value(DateTime(2026, 9, 27, 11, 40)),
          status: DoseStatus.taken,
        ),
      );
      await repos.medDoses.insert(
        MedDosesCompanion.insert(
          medicationId: med.id,
          scheduledAt: Value(DateTime(2026, 9, 26, 10)),
          status: DoseStatus.missed,
        ),
      );
      final doses = (await repo.scoreInputs()).doses3d;
      expect(doses.map((d) => (d.scheduledAt.day, d.taken)), [(25, false), (26, false), (27, true)]);
    });

    test('a medication added today does not owe the morning dose', () async {
      await repos.medications.insert(
        MedicationsCompanion.insert(
          name: 'New',
          times: const Value(['08:00', '15:00']),
          createdAt: Value(DateTime(2026, 9, 27, 12)),
        ),
      );
      final doses = (await repo.scoreInputs()).doses3d;
      expect(doses.map((d) => d.scheduledAt.hour), [15]);
    });

    test('people: the latest contact is the later of the column and the log', () async {
      final ids = await seedLivedIn(repos, thriving: false);
      final people = (await repo.scoreInputs()).people;
      final father = people.firstWhere((p) => p.id == ids.father);
      expect(father.rhythmDays, 2);
      expect(father.lastContact, fixtureNow.subtract(const Duration(days: 5)));
    });

    test('cards: done = the done column, doneAt = updatedAt; board ids carried', () async {
      final ids = await seedLivedIn(repos, thriving: true);
      final cards = (await repo.scoreInputs()).cards;
      expect(cards, hasLength(5));
      final done = cards.where((c) => c.done).toList();
      expect(done, hasLength(3));
      expect(done.every((c) => c.doneAt != null), isTrue);
      expect(cards.where((c) => !c.done).every((c) => c.doneAt == null), isTrue);
      expect(cards.map((c) => c.boardId).toSet(), {ids.boardJo, ids.boardSy});
    });

    test('budget: leaf items planned vs spent this month through BudgetMath', () async {
      final ids = await seedLivedIn(repos, thriving: false);
      final budget = (await repo.scoreInputs()).budget;
      // Leaves only: groceries, eating out, fuel (food is their parent).
      expect(budget.map((b) => b.id), isNot(contains(ids.food)));
      expect(budget, hasLength(3));
      final fuel = budget.firstWhere((b) => b.id == ids.fuel);
      expect(fuel.planMilli, 60000);
      expect(fuel.spentMilli, 90000);
    });

    test('workouts expected from the exercise weekdays; today counts only once done', () async {
      await seedLivedIn(repos, thriving: true);
      final inputs = await repo.scoreInputs();
      // 27 Sep 2026 is a Sunday (7). Walk every day (7) + push-ups Mon/Wed/Fri/Sun
      // over 21–27 Sep (Mon 21, Wed 23, Fri 25, Sun 27 → 4) = 11.
      expect(inputs.workoutsExpected7d, 11);
      expect(inputs.workoutsDone7d, 11);
      // The fast running since 04:00 has not reached 90 % of 14 h yet, so only
      // the finished one counts.
      expect(inputs.fastsPlanned7d, 1);
      expect(inputs.fastsCompleted7d, 1);
    });

    test('water is tracked once logged, against the default 2500 ml target', () async {
      expect((await repo.scoreInputs()).waterTargetMl, 0);
      await seedLivedIn(repos, thriving: true);
      final inputs = await repo.scoreInputs();
      expect(inputs.waterTargetMl, 2500);
      expect(inputs.waterTodayMl, 1600);
      await repos.keyValues.setJson(OrbitRepository.waterTargetKey, 3000);
      expect((await repo.scoreInputs()).waterTargetMl, 3000);
    });

    test('prayers: expected count starts with the first logged prayer', () async {
      final day = DateTime(2026, 9, 26);
      await repos.prayerLogs.insert(PrayerLogsCompanion.insert(day: '2026-09-26', prayer: Prayer.fajr));
      final inputs = await repo.scoreInputs();
      final schedule = PrayerSchedule(const PrayerSettings());
      var expected = 0;
      for (final d in [day, DateTime(2026, 9, 27)]) {
        for (final (_, t) in schedule.timesFor(d).obligatory) {
          if (!t.isAfter(fixtureNow)) expected++;
        }
      }
      expect(inputs.obligatoryPrayersExpected7d, expected);
      expect(inputs.prayerLogs7d, hasLength(1));
    });

    test('goals, trips, documents, modules and last activity', () async {
      final ids = await seedLivedIn(repos, thriving: false);
      final inputs = await repo.scoreInputs();
      expect(inputs.goals.single.progress, 2);
      final trip = inputs.trips.single; // the finished trip is not scored
      expect(trip.id, ids.tripIstanbul);
      expect((trip.itemsTotal, trip.itemsPacked), (10, 1));
      expect(inputs.documents.single.id, ids.passport);
      expect(inputs.modules.single.id, ids.moduleReading);
      expect(inputs.modules.single.lastEntry, DateTime(2026, 9, 21));
      await repos.activity.log(planetKey: 'faith', kind: 'x', at: DateTime(2026, 9, 27, 10));
      expect((await repo.scoreInputs()).lastActivity['faith'], DateTime(2026, 9, 27, 10));
    });
  });

  group('living state', () {
    test('every planet visibly changes between thriving and neglected', () async {
      final thrivingSnap = await (() async {
        await seedLivedIn(repos, thriving: true);
        return repo.snapshot();
      })();
      final other = await openInMemoryMadarDatabase();
      addTearDown(other.close);
      final otherRepos = Repositories(other);
      await seedLivedIn(otherRepos, thriving: false);
      final neglectedSnap = await OrbitRepository(otherRepos, clock: () => fixtureNow).snapshot();

      for (final key in ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel']) {
        final t = thrivingSnap.planet(key)!, n = neglectedSnap.planet(key)!;
        expect(t.state, PlanetState.thriving, reason: '$key thriving (${t.uScore})');
        expect(n.state, PlanetState.neglected, reason: '$key neglected (${n.uScore}) ${n.score.reasons}');
      }
      expect(thrivingSnap.balance, greaterThan(0.9));
      expect(neglectedSnap.balance, lessThan(0.35));
      expect(thrivingSnap.radar, isEmpty);
      expect(neglectedSnap.radar, hasLength(3));
    });

    test('neglected radar: the three weakest planets with natural Arabic reasons', () async {
      final ids = await seedLivedIn(repos, thriving: false);
      final snap = await repo.snapshot();
      expect(snap.radar.map((r) => r.planetKey), ['faith', 'body', 'work']);
      expect(snap.radar.map((r) => r.text), [
        '٣١ صلاةً لم تُسجَّل هذا الأسبوع',
        '٨ تمارين فائتة هذا الأسبوع',
        '${iso('الأردن')} — بطاقتان متأخرتان',
      ]);
      for (var i = 1; i < snap.radar.length; i++) {
        expect(snap.radar[i - 1].score, lessThanOrEqualTo(snap.radar[i].score));
      }
      // Tapping a reason opens its record (the Jordan board), or the planet.
      expect((snap.radar.last.refTable, snap.radar.last.refId), ('boards', ids.boardJo));
      expect(snap.radar.first.opensPlanet, isTrue);
      // The travel world's own reasons, most urgent first, on calendar days.
      final travel = snap.planet('travel')!.score.reasons;
      expect(
        [for (final r in travel) neglectReasonText(lookupL10n(const Locale('ar')), r, const MadarFormatter())],
        [
          '${iso('جواز السفر')} — انتهاء الصلاحية خلال ١٠ أيام',
          '${iso('إسطنبول')} — السفر بعد ٥ أيام، والتجهيز ١٠٪ فقط',
        ],
      );
    });

    test('every reason of a neglected world reads naturally in Arabic and English', () async {
      final ids = await seedLivedIn(repos, thriving: false, arabic: false);
      final snap = await repo.snapshot(languageCode: 'en');
      final ar = lookupL10n(const Locale('ar'));
      const arFmt = MadarFormatter();
      final en = lookupL10n(const Locale('en'));
      const enFmt = MadarFormatter(languageCode: 'en');
      String textOf(String planet, ReasonCode code, L10n l, MadarFormatter f) =>
          neglectReasonText(l, snap.planet(planet)!.score.reasons.firstWhere((r) => r.code == code), f);

      expect(textOf('family', ReasonCode.personOverdue, en, enFmt), '${iso('Father')} — 3 days overdue');
      expect(textOf('family', ReasonCode.personOverdue, ar, arFmt), '${iso('Father')} — متأخر ٣ أيام');
      // Today's 08:00 Metformin and 09:00 Vitamin D.
      expect(textOf('health', ReasonCode.dosesPastDue, en, enFmt), '2 doses past due');
      expect(textOf('health', ReasonCode.dosesPastDue, ar, arFmt), 'جرعتان فائتتان');
      expect(textOf('money', ReasonCode.budgetOverspent, en, enFmt), '${iso('Fuel')} — 50% over budget');
      expect(textOf('money', ReasonCode.budgetOverspent, ar, arFmt), '${iso('Fuel')} — تجاوز الميزانية بنسبة ٥٠٪');
      expect(textOf('money', ReasonCode.obligationOverdue, en, enFmt), '${iso('Internet')} — 4 days overdue');
      expect(
        textOf('travel', ReasonCode.tripUnpacked, en, enFmt),
        '${iso('Istanbul')} — leaving in 5 days, only 10% packed',
      );
      expect(
        textOf('travel', ReasonCode.tripUnpacked, ar, arFmt),
        '${iso('Istanbul')} — السفر بعد ٥ أيام، والتجهيز ١٠٪ فقط',
      );
      expect(textOf('travel', ReasonCode.documentExpiring, en, enFmt), '${iso('Passport')} — expires in 10 days');
      expect(textOf('work', ReasonCode.cardsOverdue, en, enFmt), '${iso('Jordan')} — 2 cards overdue');
      expect(textOf('work', ReasonCode.cardsOverdue, ar, arFmt), '${iso('Jordan')} — بطاقتان متأخرتان');
      expect(textOf('growth', ReasonCode.moduleStale, en, enFmt), '${iso('Reading')} — no entry for 6 days');
      expect(textOf('body', ReasonCode.waterLow, en, enFmt), "Water — only 10% of today's goal");
      // Refs open the real record.
      final overdue = snap.planet('family')!.score.reasons.firstWhere((r) => r.code == ReasonCode.personOverdue);
      expect((overdue.refTable, overdue.refId), ('people', ids.father));
      final cards = snap.planet('work')!.score.reasons.firstWhere((r) => r.code == ReasonCode.cardsOverdue);
      expect(cards.refId, anyOf(ids.boardJo, ids.boardSy));
    });

    test('digit style follows the setting (Western digits in Arabic)', () async {
      await seedLivedIn(repos, thriving: false);
      final snap = await repo.snapshot(digits: DigitStyle.western);
      expect(snap.radar.first.text, '31 صلاةً لم تُسجَّل هذا الأسبوع');
    });
  });

  group('moons', () {
    test('people around Family, wallets around Money, boards around Work, trips around Travel, modules around their planet', () async {
      final ids = await seedLivedIn(repos, thriving: false);
      final snap = await repo.snapshot();
      final family = snap.planet('family')!.moons;
      expect(family.map((m) => m.refId), [ids.father, ids.mother, ids.sister]); // cousin: showAsMoon false
      expect(family.map((m) => m.label), ['أبي', 'أمي', 'أختي']);
      expect(family.every((m) => m.refTable == 'people' && m.kind == MoonKind.rocky), isTrue);
      expect(family.first.score, lessThan(0.2)); // father overdue
      final money = snap.planet('money')!.moons;
      expect(money.map((m) => m.refId), [ids.cash, ids.bank]);
      expect(money.every((m) => m.kind == MoonKind.metallic), isTrue);
      // 2000 USD ≈ 1418 JOD outweighs 150 JOD − 90 − 90 + 100.
      expect(money.last.size, greaterThan(money.first.size));
      final work = snap.planet('work')!.moons;
      expect(work.map((m) => (m.refTable, m.refId)), [('boards', ids.boardJo), ('boards', ids.boardSy)]);
      expect(work.every((m) => m.kind == MoonKind.lava), isTrue);
      final travel = snap.planet('travel')!.moons;
      expect(travel.single.refId, ids.tripIstanbul); // the finished Cairo trip is not a moon
      expect(travel.single.kind, MoonKind.icy);
      expect(snap.planet('growth')!.moons.single.refTable, 'custom_modules');
      // Every moon maps to a real row.
      for (final p in snap.planets) {
        for (final m in p.moons) {
          final row = await repos.forTable(m.refTable)!.byId(m.refId);
          expect(row, isNotNull, reason: m.id);
        }
      }
      expect(snap.moon('people:${ids.mother}')!.label, 'أمي');
    });

    test('an archived Work board is no moon, and its cards neither count nor warn', () async {
      expect(OrbitRepository.archivedBoardsKey, WorkService.archivedKey, reason: 'one key, owned by Work');
      final ids = await seedLivedIn(repos, thriving: false);
      final before = await repo.snapshot();
      expect(
        before.planet('work')!.score.reasons.where((r) => r.code == ReasonCode.cardsOverdue).map((r) => r.refId),
        contains(ids.boardJo),
      );
      await repos.keyValues.setJson(OrbitRepository.archivedBoardsKey, [ids.boardJo]);
      final snap = await repo.snapshot();
      final work = snap.planet('work')!;
      expect(work.moons.map((m) => (m.refTable, m.refId)), [('boards', ids.boardSy)]);
      expect(work.score.reasons.where((r) => r.refTable == 'boards' && r.refId == ids.boardJo), isEmpty);
      expect(snap.radar.where((r) => r.refId == ids.boardJo), isEmpty);
      expect(work.extras[0], 1, reason: 'one board left in use');
      // Restored: a moon again.
      await repos.keyValues.setJson(OrbitRepository.archivedBoardsKey, const <String>[]);
      expect((await repo.snapshot()).planet('work')!.moons, hasLength(2));
    });

    test('at most 12 moons per planet; the overflow is counted and the most overdue are kept', () async {
      final created = fixtureNow.subtract(const Duration(days: 40));
      final overdueIds = <String>[];
      for (var i = 0; i < 15; i++) {
        final p = await repos.people.insert(
          PeopleCompanion.insert(
            name: 'P$i',
            rhythmDays: const Value(7),
            lastContact: Value(fixtureNow.subtract(Duration(days: i < 3 ? 20 : 1))),
            createdAt: Value(created),
          ),
        );
        if (i < 3) overdueIds.add(p.id);
      }
      final family = (await repo.snapshot()).planet('family')!;
      expect(family.moons, hasLength(12));
      expect(family.moonOverflow, 3);
      expect(family.moons.map((m) => m.refId), containsAll(overdueIds));
      // Shown in the user's order.
      expect(family.moons.first.label, 'P0');
    });
  });

  group('extras', () {
    test('uExtra follows the data of each world', () async {
      await seedLivedIn(repos, thriving: true);
      final snap = await repo.snapshot();
      expect(snap.planet('work')!.extras[0], 2); // two country boards
      expect(snap.planet('work')!.extras[1], inInclusiveRange(0.3, 1.0));
      expect(snap.planet('travel')!.extras[0], 1); // one upcoming trip → one ship
      expect(snap.planet('body')!.extras, [1, 1, 0, 0]); // fasting now, trained today
      expect(snap.planet('growth')!.extras[0], closeTo(14 / 30, 1e-9));
      expect(snap.planet('family')!.extras[0], closeTo(0.75, 1e-9)); // 3 moons / 4
      expect(snap.planet('money')!.extras[1], closeTo(0.4, 1e-9)); // jar 400/1000
      expect(snap.planet('faith')!.extras, [0, 0, 0, 0]);
    });
  });

  group('planets', () {
    test('hidden planets leave the orbit; custom planets read their chosen sources', () async {
      await seedLivedIn(repos, thriving: false);
      final growth = (await repos.planets.getAll(where: (p) => p.key.equals('growth'))).single;
      await repos.planets.setColumn(growth.id, 'hidden', true);
      await repos.planets.insert(
        PlanetsCompanion.insert(
          key: 'custom_sport',
          nameAr: 'الرياضة',
          nameEn: 'Sport',
          color: 0xFF88CCEE,
          archetype: PlanetArchetype.ice,
          sources: const Value({'workouts': 1.0}),
        ),
      );
      final snap = await repo.snapshot();
      expect(snap.planet('growth'), isNull);
      final sport = snap.planet('custom_sport')!;
      expect(sport.name, 'الرياضة');
      expect(sport.shaderArchetype, PlanetArchetype.crystal);
      expect(sport.extras, [1.55, 0.06, 0, 0]);
      expect(sport.score.sources.keys, contains('workouts'));
      expect(sport.state, PlanetState.neglected);
      expect(sport.palette.surface.toARGB32(), 0xFF88CCEE);
      // The same missed workouts are listed once in the radar.
      final codes = snap.radar.map((r) => '${r.reason.code}|${r.reason.args}').toList();
      expect(codes.toSet().length, codes.length);
    });

    test('a recoloured built-in gets a derived palette', () async {
      final work = (await repos.planets.getAll(where: (p) => p.key.equals('work'))).single;
      await repos.planets.setColumn(work.id, 'color', 0xFF3366FF);
      final snap = await repo.snapshot();
      expect(snap.planet('work')!.palette, isNot(same(PlanetPalettes.work)));
      expect(snap.planet('work')!.palette.surface.toARGB32(), 0xFF3366FF);
    });
  });

  group('prayer', () {
    test('logged prayers of the prayer day light their pointers', () async {
      await repos.prayerLogs.insert(PrayerLogsCompanion.insert(day: '2026-09-27', prayer: Prayer.fajr));
      await repos.prayerLogs.insert(
        PrayerLogsCompanion.insert(day: '2026-09-27', prayer: Prayer.dhuhr, status: const Value(PrayerStatus.missed)),
      );
      await repos.prayerLogs.insert(PrayerLogsCompanion.insert(day: '2026-09-27', prayer: Prayer.duha));
      final snap = await repo.snapshot();
      expect(snap.prayer.logged, {Prayer.fajr: PrayerStatus.prayed, Prayer.dhuhr: PrayerStatus.missed});
      expect(snap.prayer.lit, {Prayer.fajr});
    });

    test('before Fajr the prayer day is still yesterday', () async {
      final schedule = PrayerSchedule(const PrayerSettings());
      final early = schedule.timesFor(DateTime(2026, 9, 28)).fajr.subtract(const Duration(minutes: 10));
      await repos.prayerLogs.insert(PrayerLogsCompanion.insert(day: '2026-09-27', prayer: Prayer.isha));
      final snap = await OrbitRepository(repos, clock: () => early).snapshot();
      expect(snap.prayer.prayerDay, DateTime(2026, 9, 27));
      expect(snap.prayer.lit, {Prayer.isha});
      expect(snap.prayer.nextPrayer, Prayer.fajr);
    });

    test('prayer settings come from key_values', () async {
      const damascus = PrayerSettings(latitude: 33.51, longitude: 36.29, cityName: 'Damascus');
      await repo.setPrayerSettings(damascus);
      expect((await repo.prayerSettings()).cityName, 'Damascus');
      final snap = await repo.snapshot();
      expect(snap.prayer.settings.latitude, 33.51);
      expect(snap.prayer.times.dhuhr, PrayerSchedule(damascus).timesFor(fixtureNow).dhuhr);
    });
  });
}
