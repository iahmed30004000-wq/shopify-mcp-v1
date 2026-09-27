// Seeds a lived-in Madar database for the orbit data-layer tests: real rows
// in every table the Astrolabe Orbit reads, in a "thriving" or a "neglected"
// variant, relative to a fixed "now".
import 'package:drift/drift.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

/// Sunday 27 Sep 2026, 16:00 local.
final DateTime fixtureNow = DateTime(2026, 9, 27, 16);

/// Ids of the rows a test wants to look at.
class FixtureIds {
  late String father, mother, sister, cousin;
  late String cash, bank;
  late String boardJo, boardSy;
  late String tripIstanbul, tripDone;
  late String moduleReading;
  late String metformin, vitaminD;
  late String fuel, food;
  late String passport;
  late String goal;
  late String internet;
}

/// Names in the fixture's language (user data is typed by the user).
class FixtureNames {
  const FixtureNames(this.ar);
  final bool ar;
  String get father => ar ? 'أبي' : 'Father';
  String get mother => ar ? 'أمي' : 'Mother';
  String get sister => ar ? 'أختي' : 'Sister';
  String get cousin => ar ? 'ابن عمي' : 'Cousin';
  String get cash => ar ? 'النقد' : 'Cash';
  String get bank => ar ? 'البنك' : 'Bank';
  String get jordan => ar ? 'الأردن' : 'Jordan';
  String get syria => ar ? 'سوريا' : 'Syria';
  String get istanbul => ar ? 'إسطنبول' : 'Istanbul';
  String get cairo => ar ? 'القاهرة' : 'Cairo';
  String get reading => ar ? 'القراءة' : 'Reading';
  String get fuel => ar ? 'الوقود' : 'Fuel';
  String get food => ar ? 'الطعام' : 'Food';
  String get groceries => ar ? 'البقالة' : 'Groceries';
  String get eatingOut => ar ? 'المطاعم' : 'Eating out';
  String get internet => ar ? 'الإنترنت' : 'Internet';
  String get passport => ar ? 'جواز السفر' : 'Passport';
  String get course => ar ? 'حفظ جزء عمّ' : 'Memorise Juz Amma';
  String get travelJar => ar ? 'صندوق السفر' : 'Travel jar';
}

DateTime _day(DateTime now, int offset) => DateTime(now.year, now.month, now.day + offset);

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Fills [r] with a realistic week of life. [thriving] = everything kept up;
/// otherwise the same records slipping (overdue people, missed doses,
/// overspent fuel, late bill, expiring passport, unpacked trip …).
Future<FixtureIds> seedLivedIn(
  Repositories r, {
  DateTime? now,
  required bool thriving,
  bool arabic = true,
}) async {
  final at = now ?? fixtureNow;
  final n = FixtureNames(arabic);
  final ids = FixtureIds();
  final created = at.subtract(const Duration(days: 20));
  final schedule = PrayerSchedule(const PrayerSettings());

  // ---- Faith: every obligatory prayer of the last 8 days that has started.
  const obligatory = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];
  for (var d = -8; d <= 0; d++) {
    final day = _day(at, d);
    final times = schedule.timesFor(day);
    for (final (p, t) in times.obligatory) {
      if (t.isAfter(at)) continue;
      // Neglected: only Fajr gets logged (and not every day).
      if (!thriving && (p != Prayer.fajr || d.isOdd)) continue;
      await r.prayerLogs.insert(PrayerLogsCompanion.insert(
        day: _dayKey(day),
        prayer: p,
        status: Value(thriving ? PrayerStatus.prayed : PrayerStatus.late),
        inJamaah: Value(thriving && (p == Prayer.maghrib || p == Prayer.isha)),
      ));
    }
    if (d == -8 && !thriving) {
      // Tracking started 8 days ago.
      final exists = await r.prayerLogs.count(where: (t) => t.day.equals(_dayKey(day)));
      if (exists == 0) {
        await r.prayerLogs.insert(PrayerLogsCompanion.insert(day: _dayKey(day), prayer: obligatory.first));
      }
    }
  }

  // ---- Health: two medications, doses logged (or not).
  final metformin = await r.medications.insert(MedicationsCompanion.insert(
    name: 'Metformin',
    times: const Value(['08:00', '20:00']),
    createdAt: Value(created),
  ));
  final vitD = await r.medications.insert(MedicationsCompanion.insert(
    name: arabic ? 'فيتامين د' : 'Vitamin D',
    kind: const Value(MedKind.supplement),
    times: const Value(['09:00']),
    createdAt: Value(created),
  ));
  ids
    ..metformin = metformin.id
    ..vitaminD = vitD.id;
  for (var d = -2; d <= 0; d++) {
    final day = _day(at, d);
    for (final (med, hm) in [(metformin, (8, 0)), (metformin, (20, 0)), (vitD, (9, 0))]) {
      final slot = DateTime(day.year, day.month, day.day, hm.$1, hm.$2);
      if (slot.isAfter(at)) continue;
      // Neglected: nothing logged since the day before yesterday.
      if (!thriving && d > -2) continue;
      await r.medDoses.insert(MedDosesCompanion.insert(
        medicationId: med.id,
        scheduledAt: Value(slot),
        takenAt: Value(slot.add(const Duration(minutes: 7))),
        status: DoseStatus.taken,
      ));
    }
  }

  // ---- Family: people with contact rhythms (+ one not shown as a moon).
  Future<String> person(String name, int rhythm, int daysSince, {bool moon = true, int? color}) async {
    final p = await r.people.insert(PeopleCompanion.insert(
      name: name,
      rhythmDays: Value(rhythm),
      lastContact: Value(at.subtract(Duration(days: daysSince + 1))),
      showAsMoon: Value(moon),
      color: Value(color),
      createdAt: Value(created),
    ));
    // The latest contact lives in the contact log.
    await r.contactLogs.insert(ContactLogsCompanion.insert(personId: p.id, at: at.subtract(Duration(days: daysSince))));
    return p.id;
  }

  ids
    ..father = await person(n.father, 2, thriving ? 1 : 5)
    ..mother = await person(n.mother, 3, thriving ? 0 : 6)
    ..sister = await person(n.sister, 7, thriving ? 2 : 12)
    ..cousin = await person(n.cousin, 30, 3, moon: false);

  // ---- Work: two country boards and their cards.
  final jo = await r.boards.insert(BoardsCompanion.insert(name: n.jordan, country: const Value('JO')));
  final sy = await r.boards.insert(BoardsCompanion.insert(name: n.syria, country: const Value('SY')));
  ids
    ..boardJo = jo.id
    ..boardSy = sy.id;
  Future<void> card(String board, String title, {String column = 'todo', int? dueIn}) async {
    await r.boardCards.insert(BoardCardsCompanion.insert(
      boardId: board,
      title: title,
      columnId: Value(column),
      dueDate: Value(dueIn == null ? null : _day(at, dueIn)),
    ));
  }

  if (thriving) {
    await card(jo.id, 'Supplier call', dueIn: 2);
    await card(jo.id, 'Invoice', column: 'done');
    await card(jo.id, 'Price list', column: 'done');
    await card(sy.id, 'Warehouse visit', column: 'doing', dueIn: 5);
    await card(sy.id, 'Contract', column: 'done');
  } else {
    await card(jo.id, 'Supplier call', dueIn: -4);
    await card(jo.id, 'Invoice', dueIn: -2);
    await card(jo.id, 'Price list', dueIn: 3);
    await card(sy.id, 'Warehouse visit', column: 'doing', dueIn: -6);
    await card(sy.id, 'Contract', dueIn: -1);
  }

  // ---- Money: wallets, a nested budget, this month's spending, a bill, a jar.
  final cash = await r.wallets.insert(WalletsCompanion.insert(name: n.cash, currency: 'JOD', openingMilli: const Value(150000)));
  final bank = await r.wallets.insert(WalletsCompanion.insert(name: n.bank, currency: 'USD', openingMilli: const Value(2000000)));
  ids
    ..cash = cash.id
    ..bank = bank.id;
  final food = await r.budgetItems.insert(BudgetItemsCompanion.insert(name: n.food, amountMilli: const Value(200000)));
  final groceries = await r.budgetItems.insert(
    BudgetItemsCompanion.insert(name: n.groceries, parentId: Value(food.id), amountMilli: const Value(150000)),
  );
  await r.budgetItems.insert(BudgetItemsCompanion.insert(name: n.eatingOut, parentId: Value(food.id), amountMilli: const Value(50000)));
  final fuel = await r.budgetItems.insert(BudgetItemsCompanion.insert(name: n.fuel, amountMilli: const Value(60000)));
  ids
    ..fuel = fuel.id
    ..food = food.id;
  Future<void> spend(String item, int milli, int day, {String? wallet}) async {
    await r.transactions.insert(TransactionsCompanion.insert(
      walletId: wallet ?? cash.id,
      kind: TxKind.expense,
      amountMilli: milli,
      date: DateTime(at.year, at.month, day, 12),
      budgetItemId: Value(item),
    ));
  }

  await spend(groceries.id, 90000, 5);
  await spend(fuel.id, thriving ? 40000 : 90000, 10);
  if (thriving) await spend(groceries.id, 12500, at.day - 1);
  await r.transactions.insert(TransactionsCompanion.insert(
    walletId: cash.id,
    kind: TxKind.income,
    amountMilli: 100000,
    date: DateTime(at.year, at.month, 1, 9),
  ));
  final internet = await r.obligations.insert(ObligationsCompanion.insert(
    name: n.internet,
    amountMilli: 25000,
    currency: 'JOD',
    frequency: Recurrence.monthly,
    nextDue: thriving ? _day(at, 6) : _day(at, -4),
  ));
  ids.internet = internet.id;
  final jar = await r.jars.insert(JarsCompanion.insert(
    name: n.travelJar,
    targetMilli: 1000000,
    currency: 'JOD',
    deadline: Value(_day(at, 60)),
    createdAt: Value(_day(at, -30)),
  ));
  await r.jarDeposits.insert(JarDepositsCompanion.insert(jarId: jar.id, amountMilli: thriving ? 400000 : 20000, date: _day(at, -10)));

  // ---- Growth: a learning goal with a deadline, and a tracker module.
  final goal = await r.learningGoals.insert(LearningGoalsCompanion.insert(
    name: n.course,
    target: 30,
    deadline: Value(_day(at, 40)),
    createdAt: Value(_day(at, -20)),
  ));
  ids.goal = goal.id;
  await r.goalLogs.insert(GoalLogsCompanion.insert(goalId: goal.id, amount: thriving ? 14 : 2, at: _day(at, thriving ? -1 : -15)));
  final reading = await r.customModules.insert(CustomModulesCompanion.insert(
    name: n.reading,
    color: 0xFF4CC96B,
    planetKey: const Value('growth'),
    createdAt: Value(created),
  ));
  ids.moduleReading = reading.id;
  await r.customEntries.insert(CustomEntriesCompanion.insert(moduleId: reading.id, at: Value(_day(at, thriving ? -1 : -6))));

  // ---- Body: two scheduled exercises, logs, water, a fast.
  final pushUps = await r.exercises.insert(ExercisesCompanion.insert(
    name: 'Push-ups',
    weekdays: const Value([1, 3, 5, 7]),
    createdAt: Value(created),
  ));
  final walk = await r.exercises.insert(ExercisesCompanion.insert(
    name: 'Walk',
    weekdays: const Value([1, 2, 3, 4, 5, 6, 7]),
    durationMin: const Value(30),
    createdAt: Value(created),
  ));
  if (thriving) {
    for (var d = -6; d <= 0; d++) {
      final day = _day(at, d);
      final when = DateTime(day.year, day.month, day.day, 7);
      await r.workoutLogs.insert(WorkoutLogsCompanion.insert(exerciseId: Value(walk.id), name: 'Walk', at: when, durationMin: const Value(30)));
      if ([1, 3, 5, 7].contains(day.weekday)) {
        await r.workoutLogs.insert(WorkoutLogsCompanion.insert(exerciseId: Value(pushUps.id), name: 'Push-ups', at: when));
      }
    }
    await r.fastingSessions.insert(FastingSessionsCompanion.insert(start: _day(at, -3).add(const Duration(hours: 4)), end: Value(_day(at, -3).add(const Duration(hours: 18, minutes: 30))), targetHours: 14));
    await r.fastingSessions.insert(FastingSessionsCompanion.insert(start: _day(at, 0).add(const Duration(hours: 4)), targetHours: 14));
  } else {
    await r.workoutLogs.insert(WorkoutLogsCompanion.insert(exerciseId: Value(walk.id), name: 'Walk', at: _day(at, -5).add(const Duration(hours: 7))));
    await r.fastingSessions.insert(FastingSessionsCompanion.insert(start: _day(at, -2).add(const Duration(hours: 4)), end: Value(_day(at, -2).add(const Duration(hours: 9))), targetHours: 14));
  }
  for (final (hour, ml) in thriving ? [(8, 500), (11, 500), (14, 600)] : [(9, 250)]) {
    await r.waterLogs.insert(WaterLogsCompanion.insert(at: _day(at, 0).add(Duration(hours: hour)), ml: ml));
  }

  // ---- Travel: a passport, an upcoming trip being packed, a finished trip.
  final passport = await r.travelDocuments.insert(TravelDocumentsCompanion.insert(
    name: n.passport,
    expiry: Value(thriving ? _day(at, 700) : _day(at, 10)),
  ));
  ids.passport = passport.id;
  final ist = await r.trips.insert(TripsCompanion.insert(
    destination: n.istanbul,
    startDate: Value(_day(at, 5)),
    endDate: Value(_day(at, 12)),
  ));
  ids.tripIstanbul = ist.id;
  for (var i = 0; i < 10; i++) {
    await r.tripItems.insert(TripItemsCompanion.insert(tripId: ist.id, body: 'item $i', packed: Value(i < (thriving ? 8 : 1))));
  }
  final done = await r.trips.insert(TripsCompanion.insert(
    destination: n.cairo,
    startDate: Value(_day(at, -60)),
    endDate: Value(_day(at, -50)),
    status: const Value(TripStatus.done),
  ));
  ids.tripDone = done.id;

  // ---- Tasks attached to planets.
  await r.tasks.insert(TasksCompanion.insert(
    title: 'Call the bank',
    planetKey: const Value('money'),
    date: Value(_day(at, thriving ? 1 : -3)),
  ));
  if (thriving) {
    await r.tasks.insert(TasksCompanion.insert(
      title: 'Pay zakat al-fitr reminder',
      planetKey: const Value('money'),
      done: const Value(true),
      doneAt: Value(at.subtract(const Duration(days: 1))),
    ));
    // Recent activity on every planet.
    for (final key in ['faith', 'health', 'family', 'work', 'money', 'growth', 'body', 'travel']) {
      await r.activity.log(planetKey: key, kind: 'fixture.done', at: at.subtract(const Duration(hours: 3)));
    }
  }
  return ids;
}
