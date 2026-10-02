import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart' show Locale;

import '../../../core/db/database.dart';
import '../../../core/db/tables/converters.dart' show CalendarDayConverter;
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/budget_math.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/settings/app_settings.dart' show DigitStyle;
import '../domain/orbit_moons.dart';
import '../domain/planet_extras.dart';
import '../domain/planet_scores.dart';
import '../domain/prayer_schedule.dart';
import '../domain/scene_snapshot.dart';
import '../domain/score_sources.dart';

/// Plans the Health world's dose slots (see [OrbitRepository.doseSlots]).
typedef DoseSlotSource = Future<List<DoseIn>> Function({required DateTime from, required DateTime now});

/// Reads everything the Astrolabe Orbit shows from the real tables: the
/// planet list, the inputs of the balance engine, the moons, the shader
/// extras and the prayer state.
///
/// Reads run in one transaction so a snapshot is always consistent. Growing
/// tables (logs, transactions, activity) are read through time windows or
/// SQL aggregates; small ones (people, boards, trips …) are read whole.
class OrbitRepository {
  OrbitRepository(this.repos, {DateTime Function()? clock, this.doseSlots}) : _clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() _clock;

  /// The Health world's dose slots from [from] (start of the day two days
  /// ago) up to [now], as the medication tracker plans them (courses on
  /// their own days, titration, anchors, timing rules, snoozes); the app
  /// installs it. Null: every `HH:mm` of every active medication, every day.
  final DoseSlotSource? doseSlots;

  MadarDatabase get db => repos.db;

  /// `key_values` key of the prayer settings ([PrayerSettings] JSON).
  static const prayerSettingsKey = 'prayer.settings';

  /// `key_values` key of the daily water target in ml (JSON number).
  static const waterTargetKey = 'body.waterTargetMl';
  static const defaultWaterTargetMl = 2500;

  /// `key_values` key of the Work boards the user archived (JSON list of
  /// ids; Work owns it): an archived board is no moon and its cards neither
  /// count nor warn.
  static const archivedBoardsKey = 'work.archivedBoards';

  static final prayerSettingsKv = KvKey.json<PrayerSettings>(
    prayerSettingsKey,
    fromJson: (j) => j is Map ? PrayerSettings.fromJson(j.cast<String, Object?>()) : const PrayerSettings(),
    toJson: (s) => s.toJson(),
  );

  /// Tables whose writes can change a snapshot (the watcher listens to
  /// exactly these).
  List<TableInfo<Table, Object?>> get watchedTables => [
    db.planets,
    db.keyValues,
    db.activityLog,
    db.tasks,
    db.prayerLogs,
    db.medications,
    db.medDoses,
    db.appointments,
    db.painEntries,
    db.moodEntries,
    db.habits,
    db.habitLogs,
    db.currencies,
    db.wallets,
    db.budgetItems,
    db.transactions,
    db.jars,
    db.jarDeposits,
    db.debts,
    db.debtPayments,
    db.obligations,
    db.people,
    db.contactLogs,
    db.projects,
    db.projectItems,
    db.boards,
    db.boardCards,
    db.trips,
    db.tripItems,
    db.travelDocuments,
    db.learningGoals,
    db.goalLogs,
    db.exercises,
    db.workoutLogs,
    db.fastingSessions,
    db.waterLogs,
    db.customModules,
    db.customEntries,
  ];

  // ------------------------------------------------------------ settings --

  /// The stored prayer settings, or the defaults (Amman, Jordan preset).
  Future<PrayerSettings> prayerSettings() async =>
      await repos.keyValues.get(prayerSettingsKv) ?? const PrayerSettings();

  /// Live [prayerSettings].
  Stream<PrayerSettings> watchPrayerSettings() =>
      repos.keyValues.watch(prayerSettingsKv).map((s) => s ?? const PrayerSettings());

  Future<void> setPrayerSettings(PrayerSettings settings) => repos.keyValues.set(prayerSettingsKv, settings);

  String? _scheduleKey;
  PrayerSchedule? _schedule;

  /// A schedule for [settings], reused while the settings stay the same (its
  /// per-day cache survives between snapshots).
  PrayerSchedule scheduleFor(PrayerSettings settings) {
    final key = jsonEncode(settings.toJson());
    if (key != _scheduleKey || _schedule == null) {
      _scheduleKey = key;
      _schedule = PrayerSchedule(settings);
    }
    return _schedule!;
  }

  // ------------------------------------------------------------- planets --

  /// Every planet in the user's order (hidden ones included).
  Future<List<PlanetConfig>> planetConfigs() async => [for (final r in await repos.planets.getAll()) configOf(r)];

  static PlanetConfig configOf(PlanetRow r) => PlanetConfig(
    id: r.id,
    key: r.key,
    nameAr: r.nameAr,
    nameEn: r.nameEn,
    color: r.color,
    archetype: r.archetype,
    icon: r.icon,
    hidden: r.hidden,
    weight: r.weight,
    sources: {
      for (final e in r.sources.entries)
        if (e.value case final num v when v.isFinite) e.key: v.toDouble(),
    },
    sortOrder: r.sortOrder,
  );

  // ------------------------------------------------------------ snapshot --

  /// A complete snapshot at [now] (default: the clock) in [languageCode]
  /// with [digits].
  Future<SceneSnapshot> snapshot({
    DateTime? now,
    String languageCode = 'ar',
    DigitStyle digits = DigitStyle.auto,
  }) async {
    final data = await load(now: now);
    return SceneSnapshotBuilder.build(
      data,
      l10n: lookupL10n(Locale(languageCode == 'en' ? 'en' : 'ar')),
      formatter: MadarFormatter(languageCode: languageCode == 'en' ? 'en' : 'ar', digits: digits),
      schedule: scheduleFor(data.prayerSettings),
    );
  }

  /// Everything a snapshot needs, read in one transaction.
  Future<OrbitData> load({DateTime? now}) {
    final at = now ?? _clock();
    return db.transaction(() async {
      final settings = await prayerSettings();
      final schedule = scheduleFor(settings);
      final planets = await planetConfigs();
      final g = _Gatherer(this, at, schedule);
      final prayers = await g.prayers();
      final inputs = await g.inputs(prayers);
      return OrbitData(
        now: at,
        planets: planets,
        scoreInputs: inputs.score,
        moonInputs: inputs.moons,
        extrasInputs: inputs.extras,
        prayerSettings: settings,
        prayerDay: prayers.prayerDay,
        prayerLogs: prayers.logged,
      );
    });
  }

  /// Only the balance-engine inputs at [now].
  Future<ScoreInputs> scoreInputs({DateTime? now}) async => (await load(now: now)).scoreInputs;

  /// Only the moon inputs at [now].
  Future<MoonInputs> moonInputs({DateTime? now}) async => (await load(now: now)).moonInputs;
}

// ---------------------------------------------------------------- gather --

typedef _PrayerData = ({
  List<PrayerLogIn> logs7d,
  int expected7d,
  DateTime prayerDay,
  Map<Prayer, PrayerStatus> logged,
});

typedef _Inputs = ({ScoreInputs score, MoonInputs moons, ExtrasInputs extras});

class _Gatherer {
  _Gatherer(this.repo, this.now, this.schedule) : today = DateTime(now.year, now.month, now.day), db = repo.db;

  final OrbitRepository repo;
  final DateTime now;
  final DateTime today;
  final PrayerSchedule schedule;
  final MadarDatabase db;

  static const _obligatory = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

  DateTime _day(int offset) => DateTime(today.year, today.month, today.day + offset);

  /// `column >= at`, compared as instants (text timestamps may carry
  /// different UTC offsets).
  Expression<bool> _since(Expression<DateTime> column, DateTime at) =>
      column.julianday.isBiggerOrEqual(Variable<DateTime>(at).julianday);

  static String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  static DateTime? _parseDay(String s) {
    final d = DateTime.tryParse(s);
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static DateTime _fromJulian(double jd) {
    const unixEpochJulianDay = 2440587.5;
    final ms = ((jd - unixEpochJulianDay) * Duration.millisecondsPerDay).round();
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }

  /// Latest `at` per group via `max(julianday(at))`.
  Future<Map<String, DateTime>> _lastBy(
    TableInfo<Table, Object?> table,
    GeneratedColumn<String> group,
    GeneratedColumn<DateTime> at, {
    Expression<bool>? where,
  }) async {
    final last = at.julianday.max();
    final q = db.selectOnly(table)
      ..addColumns([group, last])
      ..groupBy([group]);
    if (where != null) q.where(where);
    return {
      for (final r in await q.get())
        if (r.read(group) case final String k)
          if (r.read(last) case final double jd) k: _fromJulian(jd),
    };
  }

  // -------------------------------------------------------------- prayers

  /// Prayer logs of the trailing 7 × 24 h and how many obligatory prayers
  /// were due in that span. Tracking starts with the first logged prayer:
  /// before it nothing is expected (a fresh install is not "35 prayers
  /// behind"), and a tracker started three days ago expects three days.
  Future<_PrayerData> prayers() async {
    final firstDay = db.prayerLogs.day.min();
    final first =
        await (db.selectOnly(db.prayerLogs)
              ..addColumns([firstDay])
              ..where(db.prayerLogs.prayer.isInValues(_obligatory)))
            .map((r) => r.read(firstDay))
            .getSingleOrNull();
    final started = first == null ? null : _parseDay(first);
    // Tracking starts with the first logged day's Fajr (or its midnight,
    // whichever is earlier – far from the configured location the day's
    // Fajr can fall on the previous local evening).
    final startedAt = started == null ? null : _earlier(started, schedule.timesFor(started).fajr);
    final weekAgo = now.subtract(const Duration(days: 7));
    final from = startedAt == null || startedAt.isBefore(weekAgo)
        ? weekAgo
        : startedAt.subtract(const Duration(milliseconds: 1));
    final rows = await (db.select(
      db.prayerLogs,
    )..where((t) => t.day.isBiggerOrEqualValue(_dayKey(_day(-8))) & t.prayer.isInValues(_obligatory))).get();
    final prayerDay = schedule.prayerDayOf(now);
    final logs = <PrayerLogIn>[];
    final logged = <Prayer, PrayerStatus>{};
    for (final r in rows) {
      final day = _parseDay(r.day);
      if (day == null) continue;
      if (day == prayerDay) logged[r.prayer] = r.status;
      final times = schedule.timesFor(day);
      final at = switch (r.prayer) {
        Prayer.fajr => times.fajr,
        Prayer.dhuhr => times.dhuhr,
        Prayer.asr => times.asr,
        Prayer.maghrib => times.maghrib,
        _ => times.isha,
      };
      // Same window as the expected count: prayers that started in the
      // trailing 7 × 24 h.
      if (at.isAfter(from) && !at.isAfter(now)) {
        logs.add(PrayerLogIn(day: day, status: r.status.name, inJamaah: r.inJamaah));
      }
    }
    var expected = 0;
    if (started != null) {
      for (var i = -8; i <= 0; i++) {
        for (final (_, at) in schedule.timesFor(_day(i)).obligatory) {
          if (at.isAfter(from) && !at.isAfter(now)) expected++;
        }
      }
    }
    return (logs7d: logs, expected7d: expected, prayerDay: prayerDay, logged: logged);
  }

  // ------------------------------------------------------------ the rest

  Future<_Inputs> inputs(_PrayerData prayers) async {
    final kv = repo.repos.keyValues;
    final week = now.subtract(const Duration(days: 7));
    final recent = now.subtract(const Duration(days: 8));

    // Doses: every daily time slot of the last three days vs the dose log.
    final doses = await _doses();

    // People: rhythm and the latest contact (column or log, whichever later).
    final peopleRows = await repo.repos.people.getAll();
    final lastLog = await _lastBy(db.contactLogs, db.contactLogs.personId, db.contactLogs.at);
    DateTime? lastContact(PersonRow p) {
      final a = p.lastContact, b = lastLog[p.id];
      if (a == null) return b;
      if (b == null) return a;
      return a.isAfter(b) ? a : b;
    }

    final people = [
      for (final p in peopleRows)
        PersonIn(id: p.id, name: p.name, rhythmDays: p.rhythmDays, lastContact: lastContact(p), createdAt: p.createdAt),
    ];

    // Tasks attached to a planet: open ones and recently completed ones.
    final taskRows = await (db.select(
      db.tasks,
    )..where((t) => t.planetKey.isNotNull() & (t.done.equals(false) | _since(t.doneAt, recent)))).get();
    final tasks = [
      for (final t in taskRows)
        TaskIn(
          id: t.id,
          planetKey: t.planetKey,
          done: t.done,
          // A repeating task is re-armed by its rule, never "overdue".
          date: t.recurrence == null || t.recurrence!.isEmpty ? t.date : null,
          doneAt: t.doneAt,
        ),
    ];

    // Boards and cards (done = the `done` column; doneAt = updatedAt). An
    // archived board is put away: no moon, and its cards (skipped below by
    // their missing board name) neither count nor warn.
    final archivedJson = await kv.getJson(OrbitRepository.archivedBoardsKey);
    final archivedBoards = archivedJson is List ? {for (final e in archivedJson) if (e is String) e} : const <String>{};
    final boardRows = [
      for (final b in await repo.repos.boards.getAll())
        if (!archivedBoards.contains(b.id)) b,
    ];
    final boardName = {for (final b in boardRows) b.id: b.name};
    final cardRows = await (db.select(
      db.boardCards,
    )..where((c) => c.columnId.equals('done').not() | _since(c.updatedAt, recent))).get();
    final cards = <CardIn>[];
    final boardStats = {for (final b in boardRows) b.id: _BoardStats()};
    var touched7d = 0, done7d = 0;
    for (final c in cardRows) {
      final done = c.columnId == 'done';
      final name = boardName[c.boardId];
      if (name == null) continue;
      cards.add(
        CardIn(
          id: c.id,
          boardName: name,
          boardId: c.boardId,
          done: done,
          dueDate: c.dueDate,
          doneAt: done ? c.updatedAt : null,
        ),
      );
      final s = boardStats[c.boardId]!;
      final fresh = !c.updatedAt.isBefore(week);
      if (fresh) {
        s.moved++;
        touched7d++;
      }
      if (done) {
        if (fresh) {
          s.done++;
          done7d++;
        }
      } else {
        s.open++;
        if (c.dueDate != null && c.dueDate!.isBefore(today)) s.overdue++;
      }
    }

    // Money: currencies, wallets and their balances, budget, jars, debts.
    final currencies = await repo.repos.currencies.getAll();
    final baseCode = currencies.where((c) => c.isBase).firstOrNull?.code ?? 'JOD';
    final rates = {for (final c in currencies) c.code.toUpperCase(): c.rateToBase};
    double rate(String? code) => code == null ? 1 : (rates[code.toUpperCase()] ?? 1);
    final walletRows = await repo.repos.wallets.getAll(where: (w) => w.archived.equals(false));
    final walletCurrency = {for (final w in walletRows) w.id: w.currency};
    final balances = await _walletNet();
    final lastTxByWallet = await _lastBy(db.transactions, db.transactions.walletId, db.transactions.date);
    final lastTx = lastTxByWallet.values.fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a);
    final wallets = [
      for (final w in walletRows)
        WalletMoonIn(
          id: w.id,
          name: w.name,
          color: w.color,
          balanceBaseMilli: ((w.openingMilli + (balances[w.id] ?? 0)) * rate(w.currency)).round(),
          lastTx: lastTxByWallet[w.id],
        ),
    ];
    final budget = await _budget(baseCode, {for (final c in currencies) c.code: c.rateToBase}, walletCurrency);

    final jarRows = await repo.repos.jars.getAll(where: (j) => j.archived.equals(false));
    final jarSums = await _sumBy(db.jarDeposits, db.jarDeposits.jarId, db.jarDeposits.amountMilli);
    final jars = [
      for (final j in jarRows)
        JarIn(
          id: j.id,
          name: j.name,
          targetMilli: j.targetMilli,
          savedMilli: math.max(0, jarSums[j.id] ?? 0),
          start: j.createdAt,
          deadline: j.deadline,
        ),
    ];
    double? savingsRatio;
    if (jarRows.isNotEmpty) {
      var target = 0.0, saved = 0.0;
      for (final j in jarRows) {
        if (j.targetMilli <= 0) continue;
        final r = rate(j.currency);
        target += j.targetMilli * r;
        saved += math.min(j.targetMilli, math.max(0, jarSums[j.id] ?? 0)) * r;
      }
      savingsRatio = target <= 0 ? null : saved / target;
    }

    final obligations = [
      for (final o in await repo.repos.obligations.getAll(where: (o) => o.active.equals(true)))
        ObligationIn(id: o.id, name: o.name, nextDue: o.nextDue),
    ];
    final paid = await _sumBy(db.debtPayments, db.debtPayments.debtId, db.debtPayments.amountMilli);
    final debts = [
      for (final d in await repo.repos.debts.getAll())
        DebtIn(
          id: d.id,
          person: d.person,
          iOwe: d.direction == DebtDirection.iOwe,
          dueDate: d.dueDate,
          settled: d.settledAt != null || (paid[d.id] ?? 0) >= d.amountMilli,
        ),
    ];

    // Growth: active goals, progress = initial + logged amounts.
    final goalRows = await repo.repos.learningGoals.getAll(where: (g) => g.active.equals(true));
    final goalSums = await _sumByReal(db.goalLogs, db.goalLogs.goalId, db.goalLogs.amount);
    final goalLast = await _lastBy(db.goalLogs, db.goalLogs.goalId, db.goalLogs.at);
    final goals = [
      for (final g in goalRows)
        GoalIn(
          id: g.id,
          name: g.name,
          target: g.target,
          progress: g.initial + (goalSums[g.id] ?? 0),
          start: g.createdAt,
          deadline: g.deadline,
          lastLog: goalLast[g.id],
        ),
    ];
    final withTarget = goals.where((g) => g.target > 0).toList();
    final growthFraction = withTarget.isEmpty
        ? null
        : withTarget.fold<double>(0, (a, g) => a + (g.progress / g.target).clamp(0.0, 1.0)) / withTarget.length;

    // Body: workouts expected from the exercise weekdays over 7 days.
    final body = await _body();

    // Travel: documents, trips and their packing lists.
    final documents = [
      for (final d in await repo.repos.travelDocuments.getAll())
        DocumentIn(id: d.id, name: d.name, expiry: d.expiry, remindDaysBefore: d.remindDaysBefore),
    ];
    final tripRows = await repo.repos.trips.getAll();
    final itemRows = await repo.repos.tripItems.getAll();
    final itemTotals = <String, (int, int)>{};
    for (final i in itemRows) {
      final (total, packed) = itemTotals[i.tripId] ?? (0, 0);
      itemTotals[i.tripId] = (total + 1, packed + (i.packed ? 1 : 0));
    }
    final trips = [
      for (final t in tripRows)
        if (t.status != TripStatus.done)
          TripIn(
            id: t.id,
            destination: t.destination,
            startDate: t.startDate,
            itemsTotal: itemTotals[t.id]?.$1 ?? 0,
            itemsPacked: itemTotals[t.id]?.$2 ?? 0,
          ),
    ];
    final tripMoons = [
      for (final t in tripRows)
        TripMoonIn(
          id: t.id,
          destination: t.destination,
          color: t.color,
          startDate: t.startDate,
          endDate: t.endDate,
          status: t.status,
          itemsTotal: itemTotals[t.id]?.$1 ?? 0,
          itemsPacked: itemTotals[t.id]?.$2 ?? 0,
        ),
    ];
    final upcomingTrips = tripRows
        .where((t) => t.status == TripStatus.planned && t.startDate != null && !t.startDate!.isBefore(today))
        .length;

    // Custom modules attached to planets, with their latest entry.
    final moduleRows = await repo.repos.customModules.getAll(where: (m) => m.archived.equals(false));
    final moduleLast = await _lastBy(db.customEntries, db.customEntries.moduleId, db.customEntries.at);
    final modules = [
      for (final m in moduleRows)
        if (m.planetKey != null && m.kind == CustomModuleKind.tracker)
          ModuleIn(
            id: m.id,
            name: m.name,
            planetKey: m.planetKey!,
            lastEntry: moduleLast[m.id],
            createdAt: m.createdAt,
          ),
    ];
    final moduleMoons = [
      for (final m in moduleRows)
        if (m.planetKey != null)
          ModuleMoonIn(
            id: m.id,
            name: m.name,
            color: m.color,
            planetKey: m.planetKey!,
            lastEntry: moduleLast[m.id],
            createdAt: m.createdAt,
            tracker: m.kind == CustomModuleKind.tracker,
          ),
    ];

    // Habits (tracked = done in the last 30 days).
    final habits = await _habits();

    // Health extras: mood, pain, appointments.
    final moods = [
      for (final m in await (db.select(db.moodEntries)..where((t) => _since(t.at, week))).get())
        MoodIn(at: m.at, mood: m.mood, stress: m.stress),
    ];
    final pains = [
      for (final p in await (db.select(db.painEntries)..where((t) => _since(t.at, week))).get())
        PainIn(at: p.at, score: p.score),
    ];
    final appointments = [
      for (final a
          in await (db.select(db.appointments)..where(
                (t) =>
                    _since(t.at, now.subtract(const Duration(days: 30))) &
                    t.at.julianday.isSmallerOrEqual(Variable<DateTime>(now.add(const Duration(days: 14))).julianday),
              ))
              .get())
        AppointmentIn(id: a.id, title: a.title, at: a.at, done: a.done),
    ];

    // Projects: items of active projects (open, or done in the last week).
    final projectRows = await repo.repos.projects.getAll(where: (p) => p.status.equalsValue(ProjectStatus.active));
    final projectById = {for (final p in projectRows) p.id: p};
    final projectItems = [
      if (projectRows.isNotEmpty)
        for (final i
            in await (db.select(db.projectItems)..where(
                  (t) => t.projectId.isIn(projectById.keys) & (t.done.equals(false) | _since(t.updatedAt, recent)),
                ))
                .get())
          ProjectItemIn(
            id: i.id,
            projectId: i.projectId,
            projectName: projectById[i.projectId]!.name,
            planetKey: projectById[i.projectId]!.planetKey,
            done: i.done,
            dueDate: i.dueDate,
            doneAt: i.done ? i.updatedAt : null,
          ),
    ];

    // Water: tracked once the user logs water or sets a target.
    final target = await kv.getJson(OrbitRepository.waterTargetKey);
    final waterRows = await (db.select(db.waterLogs)..where((t) => _since(t.at, week))).get();
    final waterToday = waterRows.where((w) => !w.at.isBefore(today)).fold<int>(0, (a, w) => a + w.ml);
    final waterTracked = target is num || waterRows.isNotEmpty;
    final waterTarget = target is num && target > 0 ? target.round() : OrbitRepository.defaultWaterTargetMl;

    // Activity: the last entry per planet, and devotional practices.
    final lastActivity = await _lastBy(db.activityLog, db.activityLog.planetKey, db.activityLog.at);
    final practices = await _practices();

    final score = ScoreInputs(
      now: now,
      prayerLogs7d: prayers.logs7d,
      obligatoryPrayersExpected7d: prayers.expected7d,
      doses3d: doses,
      people: people,
      tasks: tasks,
      cards: cards,
      budget: budget,
      obligations: obligations,
      debts: debts,
      goals: goals,
      workoutsExpected7d: body.expected7d,
      workoutsDone7d: body.done7d,
      fastsPlanned7d: body.fastsPlanned,
      fastsCompleted7d: body.fastsCompleted,
      waterTodayMl: waterTracked ? waterToday : 0,
      waterTargetMl: waterTracked ? waterTarget : 0,
      documents: documents,
      trips: trips,
      modules: modules,
      lastActivity: lastActivity,
      habits: habits,
      moods7d: moods,
      pains7d: pains,
      appointments: appointments,
      projectItems: projectItems,
      jars: jars,
      lastTransactionAt: lastTx,
      practices: practices,
    );
    final moons = MoonInputs(
      people: [
        for (final p in peopleRows)
          PersonMoonIn(
            id: p.id,
            name: p.name,
            color: p.color,
            rhythmDays: p.rhythmDays,
            lastContact: lastContact(p),
            createdAt: p.createdAt,
            showAsMoon: p.showAsMoon,
          ),
      ],
      wallets: wallets,
      boards: [
        for (final b in boardRows)
          BoardMoonIn(
            id: b.id,
            name: b.name,
            color: b.color,
            open: boardStats[b.id]!.open,
            overdue: boardStats[b.id]!.overdue,
            doneRecent: boardStats[b.id]!.done,
            movedRecent: boardStats[b.id]!.moved,
          ),
      ],
      trips: tripMoons,
      modules: moduleMoons,
    );
    final extras = ExtrasInputs(
      peopleCount: peopleRows.where((p) => p.showAsMoon).length,
      boardCount: boardRows.length,
      cardsTouched7d: touched7d,
      cardsDone7d: done7d,
      savingsRatio: savingsRatio,
      growthFraction: growthFraction,
      fastingNow: body.fastingNow,
      workoutsToday: body.doneToday,
      workoutsExpectedToday: body.expectedToday,
      workoutMinutesToday: body.minutesToday,
      upcomingTrips: upcomingTrips,
    );
    return (score: score, moons: moons, extras: extras);
  }

  /// Scheduled dose slots (every `HH:mm` of every active medication on the
  /// last three days, up to now, not before the medication existed) matched
  /// against the dose log. A slot is handled when a log for it says taken or
  /// skipped: first by its exact `scheduledAt`, else by a `takenAt` within
  /// three hours of the slot. The app plans them with the medication
  /// tracker instead ([OrbitRepository.doseSlots]).
  Future<List<DoseIn>> _doses() async {
    final source = repo.doseSlots;
    if (source != null) return source(from: _day(-2), now: now);
    final meds = await repo.repos.medications.getAll(where: (m) => m.active.equals(true));
    final withTimes = meds.where((m) => m.times.isNotEmpty).toList();
    if (withTimes.isEmpty) return const [];
    final from = _day(-2);
    final logs =
        await (db.select(db.medDoses)..where(
              (d) =>
                  d.medicationId.isIn(withTimes.map((m) => m.id)) &
                  (_since(d.scheduledAt, from.subtract(const Duration(hours: 3))) |
                      (d.scheduledAt.isNull() & _since(d.takenAt, from.subtract(const Duration(hours: 3))))),
            ))
            .get();
    final byMed = <String, List<MedDoseRow>>{};
    for (final l in logs) {
      (byMed[l.medicationId] ??= []).add(l);
    }
    final out = <DoseIn>[];
    for (final m in withTimes) {
      final mine = byMed[m.id] ?? const <MedDoseRow>[];
      final used = <String>{};
      for (var d = 0; d < 3; d++) {
        final day = _day(d - 2);
        for (final time in m.times) {
          final hm = _parseHm(time);
          if (hm == null) continue;
          final slot = DateTime(day.year, day.month, day.day, hm.$1, hm.$2);
          if (slot.isAfter(now) || slot.isBefore(m.createdAt)) continue;
          final exact = mine
              .where((l) => l.scheduledAt != null && l.scheduledAt!.difference(slot).inMinutes.abs() < 1)
              .toList();
          var handled = exact.any((l) => l.status == DoseStatus.taken || l.status == DoseStatus.skipped);
          if (!handled && exact.isEmpty) {
            MedDoseRow? best;
            var bestGap = const Duration(hours: 3);
            for (final l in mine) {
              final t = l.takenAt;
              if (l.scheduledAt != null || t == null || used.contains(l.id)) continue;
              if (l.status != DoseStatus.taken && l.status != DoseStatus.skipped) continue;
              final gap = t.difference(slot).abs();
              if (gap <= bestGap) {
                best = l;
                bestGap = gap;
              }
            }
            if (best != null) {
              used.add(best.id);
              handled = true;
            }
          }
          out.add(DoseIn(medId: m.id, medName: m.name, scheduledAt: slot, taken: handled));
        }
      }
    }
    return out;
  }

  static (int, int)? _parseHm(String s) {
    final parts = s.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return (h, m);
  }

  /// Net movement per wallet (income − expense − transfers out + transfers
  /// in + adjustments), without the opening balance.
  Future<Map<String, int>> _walletNet() async {
    final t = db.transactions;
    final sum = t.amountMilli.sum();
    final q = db.selectOnly(t)
      ..addColumns([t.walletId, t.kind, sum])
      ..groupBy([t.walletId, t.kind]);
    final net = <String, int>{};
    for (final r in await q.get()) {
      final wallet = r.read(t.walletId);
      final kind = r.read(t.kind);
      final v = r.read(sum) ?? 0;
      if (wallet == null) continue;
      final signed = switch (kind) {
        'income' || 'adjustment' => v,
        'expense' || 'transfer' => -v,
        _ => 0,
      };
      net[wallet] = (net[wallet] ?? 0) + signed;
    }
    final received = t.toAmountMilli.sum();
    final sent = t.amountMilli.sum();
    final qin = db.selectOnly(t)
      ..addColumns([t.toWalletId, received, sent])
      ..where(t.kind.equalsValue(TxKind.transfer) & t.toWalletId.isNotNull() & t.toAmountMilli.isNotNull())
      ..groupBy([t.toWalletId]);
    for (final r in await qin.get()) {
      final wallet = r.read(t.toWalletId);
      if (wallet != null) net[wallet] = (net[wallet] ?? 0) + (r.read(received) ?? 0);
    }
    // Transfers without a received amount land at face value.
    final qface = db.selectOnly(t)
      ..addColumns([t.toWalletId, sent])
      ..where(t.kind.equalsValue(TxKind.transfer) & t.toWalletId.isNotNull() & t.toAmountMilli.isNull())
      ..groupBy([t.toWalletId]);
    for (final r in await qface.get()) {
      final wallet = r.read(t.toWalletId);
      if (wallet != null) net[wallet] = (net[wallet] ?? 0) + (r.read(sent) ?? 0);
    }
    return net;
  }

  /// Plan vs spent of every leaf budget item this calendar month (through
  /// [BudgetMath], in the base currency).
  Future<List<BudgetStatusIn>> _budget(String base, Map<String, num> rates, Map<String, String> walletCurrency) async {
    final items = await repo.repos.budgetItems.getAll();
    if (items.isEmpty) return const [];
    final weeks = await repo.repos.keyValues.getJson(BudgetSettings.weeksPerMonthKey);
    final math = BudgetMath(
      [
        for (final i in items)
          BudgetNode(
            id: i.id,
            name: i.name,
            parentId: i.parentId,
            mode: i.mode,
            amountMilli: i.amountMilli,
            percent: i.percent,
            percentOf: i.percentOf,
            period: i.period,
            currency: i.currency,
            sortOrder: i.sortOrder,
          ),
      ],
      settings: BudgetSettings(
        weeksPerMonth: weeks is num ? weeks : BudgetSettings.defaultWeeksPerMonth,
        baseCurrency: base,
        ratesToBase: rates,
      ),
    );
    final window = BudgetWindow.month(now);
    final txRows =
        await (db.select(db.transactions)..where(
              (t) =>
                  t.kind.equalsValue(TxKind.expense) &
                  _since(t.date, CalendarDayConverter.startOf(window.start)) &
                  t.date.julianday.isSmallerThan(
                    Variable<DateTime>(CalendarDayConverter.startOf(window.end)).julianday,
                  ),
            ))
            .get();
    final report = math.spend([
      for (final t in txRows)
        BudgetTx(
          budgetItemId: t.budgetItemId,
          amountMilli: t.amountMilli,
          date: t.date,
          currency: walletCurrency[t.walletId],
          kind: t.kind,
        ),
    ], window);
    return [
      for (final r in math.results.values)
        if (!r.hasChildren)
          if (report.byId[r.node.id] case final s?)
            BudgetStatusIn(id: r.node.id, name: r.node.name, planMilli: s.plannedMilli, spentMilli: s.spentMilli),
    ];
  }

  Future<Map<String, int>> _sumBy(
    TableInfo<Table, Object?> table,
    GeneratedColumn<String> group,
    GeneratedColumn<int> value,
  ) async {
    final sum = value.sum();
    final q = db.selectOnly(table)
      ..addColumns([group, sum])
      ..groupBy([group]);
    return {
      for (final r in await q.get())
        if (r.read(group) case final String k) k: r.read(sum) ?? 0,
    };
  }

  Future<Map<String, double>> _sumByReal(
    TableInfo<Table, Object?> table,
    GeneratedColumn<String> group,
    GeneratedColumn<double> value,
  ) async {
    final sum = value.sum();
    final q = db.selectOnly(table)
      ..addColumns([group, sum])
      ..groupBy([group]);
    return {
      for (final r in await q.get())
        if (r.read(group) case final String k) k: r.read(sum) ?? 0,
    };
  }

  Future<_BodyData> _body() async {
    final exercises = await repo.repos.exercises.getAll(where: (e) => e.active.equals(true));
    final start = _day(-6);
    final logs = await (db.select(db.workoutLogs)..where((t) => _since(t.at, start))).get();
    final doneKeys = <String>{};
    final doneToday = <String>{};
    var minutesToday = 0;
    for (final l in logs) {
      if (l.at.isAfter(now)) continue;
      final day = DateTime(l.at.year, l.at.month, l.at.day);
      final id = l.exerciseId ?? l.name;
      doneKeys.add('$id|${day.millisecondsSinceEpoch}');
      if (day == today) {
        doneToday.add(id);
        minutesToday += l.durationMin ?? 0;
      }
    }
    var expected = 0;
    var expectedToday = 0;
    for (final e in exercises) {
      if (e.weekdays.isEmpty) continue;
      final created = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      for (var i = -6; i <= 0; i++) {
        final day = _day(i);
        if (day.isBefore(created) || !e.weekdays.contains(day.weekday)) continue;
        if (i == 0) {
          expectedToday++;
          // Today's session only counts once it is done (it is not missed
          // before the day is over).
          if (doneToday.contains(e.id)) expected++;
        } else {
          expected++;
        }
      }
    }
    final fasts = await (db.select(
      db.fastingSessions,
    )..where((t) => _since(t.start, now.subtract(const Duration(days: 7))) | t.end.isNull())).get();
    var planned = 0, completed = 0;
    var fastingNow = false;
    for (final f in fasts) {
      final end = f.end;
      final target = Duration(minutes: (f.targetHours * 60).round());
      final reached = (end ?? now).difference(f.start) >= target * 0.9;
      if (end == null) {
        if (!f.start.isAfter(now)) fastingNow = true;
        if (reached) {
          planned++;
          completed++;
        }
        continue;
      }
      if (f.start.isBefore(now.subtract(const Duration(days: 7)))) continue;
      planned++;
      if (reached) completed++;
    }
    return _BodyData(
      expected7d: expected,
      done7d: doneKeys.length,
      expectedToday: expectedToday,
      doneToday: doneToday.length,
      minutesToday: minutesToday,
      fastsPlanned: planned,
      fastsCompleted: completed,
      fastingNow: fastingNow,
    );
  }

  Future<List<HabitIn>> _habits() async {
    final habits = await repo.repos.habits.getAll(where: (h) => h.active.equals(true));
    if (habits.isEmpty) return const [];
    final from = _dayKey(_day(-30));
    final weekFrom = _day(-6);
    final logs = await (db.select(
      db.habitLogs,
    )..where((t) => t.day.isBiggerOrEqualValue(from) & t.done.equals(true))).get();
    final days7 = <String, Set<String>>{};
    final last = <String, DateTime>{};
    for (final l in logs) {
      final day = _parseDay(l.day);
      if (day == null || day.isAfter(today)) continue;
      if (!day.isBefore(weekFrom)) (days7[l.habitId] ??= {}).add(l.day);
      final prev = last[l.habitId];
      if (prev == null || day.isAfter(prev)) last[l.habitId] = day;
    }
    return [
      for (final h in habits)
        HabitIn(
          id: h.id,
          name: h.name,
          planetKey: h.planetKey,
          doneDays7d: days7[h.id]?.length ?? 0,
          lastDone: last[h.id],
        ),
    ];
  }

  /// Adhkar and Quran practice from the activity stream: kinds `adhkar`,
  /// `adhkar.*`, `faith.adhkar*` (same for `quran`).
  Future<Map<String, PracticeIn>> _practices() async {
    final a = db.activityLog;
    final rows =
        await (db.select(a)..where(
              (t) =>
                  _since(t.at, _day(-30)) &
                  (t.kind.like('%${ScoreSources.adhkar}%') | t.kind.like('%${ScoreSources.quran}%')),
            ))
            .get();
    final out = <String, PracticeIn>{};
    for (final source in const [ScoreSources.adhkar, ScoreSources.quran]) {
      final mine = rows
          .where((r) {
            final k = r.kind;
            return k == source || k.startsWith('$source.') || k.startsWith('faith.$source');
          })
          .where((r) => !r.at.isAfter(now));
      if (mine.isEmpty) continue;
      final weekFrom = _day(-6);
      final days = <int>{};
      DateTime? last;
      for (final r in mine) {
        final day = DateTime(r.at.year, r.at.month, r.at.day);
        if (!day.isBefore(weekFrom)) days.add(day.millisecondsSinceEpoch);
        if (last == null || r.at.isAfter(last)) last = r.at;
      }
      out[source] = PracticeIn(daysDone7d: days.length, last: last);
    }
    return out;
  }
}

class _BoardStats {
  int open = 0, overdue = 0, done = 0, moved = 0;
}

class _BodyData {
  const _BodyData({
    required this.expected7d,
    required this.done7d,
    required this.expectedToday,
    required this.doneToday,
    required this.minutesToday,
    required this.fastsPlanned,
    required this.fastsCompleted,
    required this.fastingNow,
  });
  final int expected7d, done7d, expectedToday, doneToday, minutesToday, fastsPlanned, fastsCompleted;
  final bool fastingNow;
}
