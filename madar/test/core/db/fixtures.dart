import 'package:drift/drift.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';

/// Timestamps that exercise every DateTime storage shape: local with offset,
/// UTC, and microsecond precision.
final tLocal = DateTime(2026, 9, 27, 8, 30);
final tUtc = DateTime.utc(2026, 1, 2, 3, 4, 5, 6);
final tMicros = DateTime(2025, 12, 31, 23, 59, 59, 999, 999);

/// Fills every table of [db] with a "full" row (all columns set, including
/// enums, JSON, dates, unicode, negatives) and, where a table has nullable
/// columns, a "sparse" row (every nullable column null). Only generic data.
Future<void> populateAllTables(MadarDatabase db) async {
  await db.batch((b) {
    // ------------------------------------------------------------- core
    b.insertAll(db.planets, [
      PlanetsCompanion.insert(
        id: const Value('planet-custom'),
        key: 'custom_1',
        nameAr: 'كوكب تجريبي',
        nameEn: 'Test planet',
        color: 0xFF123456,
        archetype: PlanetArchetype.ice,
        icon: const Value('star'),
        hidden: const Value(true),
        weight: const Value(2.5),
        sources: const Value({
          'tasks': 0.5,
          'nested': {
            'list': [1, 'two', null, true, 3.25],
          },
        }),
        sortOrder: const Value(42),
        createdAt: Value(tUtc),
        updatedAt: Value(tMicros),
      ),
    ]);
    b.insert(db.keyValues, KeyValuesCompanion.insert(key: 'test.kv', value: '{"a":[1,2,{"b":null}]}'));
    b.insertAll(db.reminders, [
      RemindersCompanion.insert(
        ownerTable: 'tasks',
        ownerId: 'task-full',
        title: const Value('تذكير'),
        rule: const {
          'kind': 'weekly',
          'time': '08:30',
          'weekdays': [1, 3, 5],
        },
        enabled: const Value(false),
      ),
      RemindersCompanion.insert(ownerTable: 'medications', ownerId: 'x', rule: const {}),
    ]);
    b.insertAll(db.activityLog, [
      ActivityLogCompanion.insert(
        planetKey: 'work',
        kind: 'task.done',
        refTable: const Value('tasks'),
        refId: const Value('task-full'),
        at: Value(tLocal),
        value: const Value(-1.5),
        payload: const Value({'k': 'v'}),
      ),
      ActivityLogCompanion.insert(planetKey: 'faith', kind: 'prayer'),
    ]);
    b.insertAll(db.tasks, [
      TasksCompanion.insert(
        id: const Value('task-full'),
        title: 'مهمة كاملة',
        notes: const Value('line 1\nline 2 "quoted" \'single\''),
        window: const Value(PrayerWindow.asr),
        date: Value(tLocal),
        recurrence: const Value({
          'every': 'week',
          'weekdays': [5],
        }),
        done: const Value(true),
        doneAt: Value(tMicros),
        planetKey: const Value('work'),
        priority: const Value(-2),
        isTop3: const Value(true),
        projectId: const Value('project-1'),
        cardId: const Value('card-1'),
        sortOrder: const Value(3),
      ),
      TasksCompanion.insert(title: 'sparse'),
    ]);
    b.insertAll(db.prayerLogs, [
      PrayerLogsCompanion.insert(
        day: '2026-09-27',
        prayer: Prayer.sunnahFajr,
        status: const Value(PrayerStatus.qada),
        inJamaah: const Value(true),
        atMosque: const Value(true),
        loggedAt: Value(tUtc),
      ),
    ]);
    b.insert(
      db.importArchive,
      ImportArchiveCompanion.insert(source: 'generic.json', raw: '{"raw": true}', summary: const Value({'n': 3})),
    );

    // ----------------------------------------------------------- health
    b.insert(
      db.healthAlerts,
      HealthAlertsCompanion.insert(
        body: 'تنبيه عام',
        severity: const Value(Severity.warning),
        pinned: const Value(false),
      ),
    );
    b.insertAll(db.conditions, [
      ConditionsCompanion.insert(
        name: 'Generic condition',
        notes: const Value('n'),
        since: Value(tLocal),
        active: const Value(false),
      ),
      ConditionsCompanion.insert(name: 'sparse'),
    ]);
    b.insertAll(db.medications, [
      MedicationsCompanion.insert(
        id: const Value('med-full'),
        name: 'Generic med',
        kind: const Value(MedKind.injection),
        dose: const Value('10 mg'),
        doseAmount: const Value(10.5),
        doseUnit: const Value('mg'),
        times: const Value(['08:00', '20:00']),
        takenWith: const Value(TakenWith.perCourse),
        takenWithNote: const Value('with water'),
        notes: const Value('notes'),
        active: const Value(false),
        stock: const Value(30),
        refillAt: const Value(5),
        courseId: const Value('course-1'),
        titration: const Value([
          {'from': '2026-10-01', 'dose': '5 mg', 'doseAmount': 5},
        ]),
        color: const Value(0xFFABCDEF),
      ),
      MedicationsCompanion.insert(name: 'sparse'),
    ]);
    b.insertAll(db.medCourses, [
      MedCoursesCompanion.insert(
        name: 'Course',
        medicationId: const Value('med-full'),
        startDate: tUtc,
        phases: const Value([
          {'label': 'Loading', 'frequency': 'daily', 'interval': 1, 'count': 10, 'dose': '1 amp'},
        ]),
        notes: const Value('n'),
        active: const Value(false),
      ),
      MedCoursesCompanion.insert(name: 'sparse', startDate: tLocal),
    ]);
    b.insertAll(db.medRules, [
      MedRulesCompanion.insert(
        kind: MedRuleKind.separate,
        medAId: 'med-full',
        medBId: const Value('med-b'),
        minutes: const Value(120),
        note: const Value('n'),
      ),
      MedRulesCompanion.insert(kind: MedRuleKind.custom, medAId: 'med-full'),
    ]);
    b.insertAll(db.medDoses, [
      MedDosesCompanion.insert(
        medicationId: 'med-full',
        scheduledAt: Value(tLocal),
        takenAt: Value(tMicros),
        status: DoseStatus.snoozed,
        dose: const Value('1'),
        note: const Value('n'),
      ),
      MedDosesCompanion.insert(medicationId: 'med-full', status: DoseStatus.missed),
    ]);
    b.insertAll(db.labTests, [
      LabTestsCompanion.insert(
        id: const Value('lab-1'),
        name: 'Test',
        unit: const Value('mg/dL'),
        low: const Value(0.5),
        high: const Value(1.25),
        category: const Value('blood'),
        notes: const Value('n'),
      ),
      LabTestsCompanion.insert(name: 'sparse'),
    ]);
    b.insertAll(db.labReadings, [
      LabReadingsCompanion.insert(
        testId: 'lab-1',
        date: tLocal,
        value: const Value(0.75),
        valueText: const Value('trace'),
        note: const Value('n'),
      ),
      LabReadingsCompanion.insert(testId: 'lab-1', date: tUtc),
    ]);
    b.insertAll(db.appointments, [
      AppointmentsCompanion.insert(
        id: const Value('appt-1'),
        title: 'Checkup',
        doctor: const Value('Dr. Generic'),
        place: const Value('Clinic'),
        at: tLocal,
        notes: const Value('n'),
        done: const Value(true),
      ),
      AppointmentsCompanion.insert(title: 'sparse', at: tUtc),
    ]);
    b.insertAll(db.doctorQuestions, [
      DoctorQuestionsCompanion.insert(
        appointmentId: const Value('appt-1'),
        question: 'سؤال؟',
        answered: const Value(true),
        answer: const Value('جواب'),
      ),
      DoctorQuestionsCompanion.insert(question: 'sparse'),
    ]);
    b.insertAll(db.painEntries, [
      PainEntriesCompanion.insert(
        at: tLocal,
        score: 7,
        locations: const Value(['head', 'رقبة']),
        triggers: const Value(['sleep']),
        bodyPoints: const Value([
          {'x': 0.42, 'y': 0.31, 'side': 'front'},
        ]),
        notes: const Value('n'),
      ),
      PainEntriesCompanion.insert(at: tUtc, score: 0),
    ]);
    b.insertAll(db.moodEntries, [
      MoodEntriesCompanion.insert(
        at: tLocal,
        mood: const Value(4),
        stress: const Value(3),
        anxiety: const Value(2),
        energy: const Value(8),
        sleepHours: const Value(7.5),
        caffeineCups: const Value(2),
        factors: const Value(['work', 'sleep']),
        notes: const Value('n'),
      ),
      MoodEntriesCompanion.insert(at: tUtc),
    ]);
    b.insertAll(db.tagOptions, [
      TagOptionsCompanion.insert(kind: TagKind.generic, label: 'tag', color: const Value(0xFF00FF00)),
      TagOptionsCompanion.insert(kind: TagKind.habitCategory, label: 'sparse'),
    ]);
    b.insertAll(db.habits, [
      HabitsCompanion.insert(
        id: const Value('habit-1'),
        name: 'Habit',
        category: const Value('focus'),
        planetKey: const Value('growth'),
        active: const Value(false),
      ),
      HabitsCompanion.insert(name: 'sparse'),
    ]);
    b.insert(db.habitLogs, HabitLogsCompanion.insert(habitId: 'habit-1', day: '2026-09-27', done: const Value(false)));
    b.insertAll(db.worries, [
      WorriesCompanion.insert(body: 'worry', resolved: const Value(true), reflection: const Value('ok')),
      WorriesCompanion.insert(body: 'sparse'),
    ]);

    // ------------------------------------------------------------ money
    b.insert(
      db.currencies,
      CurrenciesCompanion.insert(
        code: 'EUR',
        nameAr: 'يورو',
        nameEn: 'Euro',
        symbol: '€',
        decimals: const Value(2),
        rateToBase: const Value(0.8123456789),
        sortOrder: const Value(9),
      ),
    );
    b.insertAll(db.wallets, [
      WalletsCompanion.insert(
        id: const Value('wallet-1'),
        name: 'Cash',
        currency: 'JOD',
        openingMilli: const Value(-123456),
        kind: const Value(WalletKind.business),
        color: const Value(0xFF111111),
        icon: const Value('wallet'),
        archived: const Value(true),
      ),
      WalletsCompanion.insert(name: 'sparse', currency: 'USD'),
    ]);
    b.insertAll(db.budgetItems, [
      BudgetItemsCompanion.insert(
        id: const Value('budget-parent'),
        name: 'Parent',
        mode: const Value(BudgetMode.percent),
        amountMilli: const Value(500000),
        percent: const Value(12.5),
        percentOf: const Value(PercentBase.total),
        period: const Value(BudgetPeriod.weekly),
        currency: const Value('USD'),
        color: const Value(0xFF222222),
        icon: const Value('home'),
      ),
      BudgetItemsCompanion.insert(parentId: const Value('budget-parent'), name: 'sparse child'),
    ]);
    b.insertAll(db.transactions, [
      TransactionsCompanion.insert(
        walletId: 'wallet-1',
        kind: TxKind.transfer,
        amountMilli: 1000,
        date: tLocal,
        budgetItemId: const Value('budget-parent'),
        toWalletId: const Value('wallet-2'),
        toAmountMilli: const Value(1410),
        note: const Value('n'),
        tags: const Value(['a', 'ب']),
      ),
      TransactionsCompanion.insert(walletId: 'wallet-1', kind: TxKind.expense, amountMilli: 1, date: tUtc),
    ]);
    b.insertAll(db.jars, [
      JarsCompanion.insert(
        id: const Value('jar-1'),
        name: 'Jar',
        targetMilli: 9000000,
        currency: 'JOD',
        deadline: Value(tLocal),
        color: const Value(0xFF333333),
        icon: const Value('plane'),
        archived: const Value(true),
      ),
      JarsCompanion.insert(name: 'sparse', targetMilli: 1, currency: 'USD'),
    ]);
    b.insertAll(db.jarDeposits, [
      JarDepositsCompanion.insert(
        jarId: 'jar-1',
        amountMilli: -500,
        date: tLocal,
        walletId: const Value('wallet-1'),
        note: const Value('n'),
      ),
      JarDepositsCompanion.insert(jarId: 'jar-1', amountMilli: 1, date: tUtc),
    ]);
    b.insertAll(db.debts, [
      DebtsCompanion.insert(
        id: const Value('debt-1'),
        direction: DebtDirection.owedToMe,
        person: 'Someone',
        amountMilli: 250000,
        currency: 'JOD',
        dueDate: Value(tLocal),
        note: const Value('n'),
        settledAt: Value(tUtc),
      ),
      DebtsCompanion.insert(direction: DebtDirection.iOwe, person: 'sparse', amountMilli: 1, currency: 'USD'),
    ]);
    b.insertAll(db.debtPayments, [
      DebtPaymentsCompanion.insert(debtId: 'debt-1', amountMilli: 1000, date: tLocal, note: const Value('n')),
      DebtPaymentsCompanion.insert(debtId: 'debt-1', amountMilli: 1, date: tUtc),
    ]);
    b.insertAll(db.obligations, [
      ObligationsCompanion.insert(
        id: const Value('obl-1'),
        name: 'Rent',
        amountMilli: 300000,
        currency: 'JOD',
        walletId: const Value('wallet-1'),
        budgetItemId: const Value('budget-parent'),
        frequency: Recurrence.yearly,
        interval: const Value(2),
        nextDue: tLocal,
        note: const Value('n'),
        active: const Value(false),
      ),
      ObligationsCompanion.insert(
        name: 'sparse',
        amountMilli: 1,
        currency: 'USD',
        frequency: Recurrence.weekly,
        nextDue: tUtc,
      ),
    ]);
    b.insertAll(db.obligationPayments, [
      ObligationPaymentsCompanion.insert(
        obligationId: 'obl-1',
        dueDate: tLocal,
        paidAt: tMicros,
        amountMilli: 300000,
        transactionId: const Value('tx-1'),
      ),
      ObligationPaymentsCompanion.insert(obligationId: 'obl-1', dueDate: tUtc, paidAt: tUtc, amountMilli: 1),
    ]);

    // ------------------------------------------------------------- life
    b.insertAll(db.people, [
      PeopleCompanion.insert(
        id: const Value('person-1'),
        name: 'Test person',
        relation: const Value('friend'),
        rhythmDays: const Value(14),
        lastContact: Value(tLocal),
        phone: const Value('+000'),
        birthday: Value(DateTime(2000, 2, 29)),
        notes: const Value('n'),
        color: const Value(0xFF444444),
        showAsMoon: const Value(false),
      ),
      PeopleCompanion.insert(name: 'sparse'),
    ]);
    b.insertAll(db.contactLogs, [
      ContactLogsCompanion.insert(
        personId: 'person-1',
        at: tLocal,
        channel: const Value(ContactChannel.visit),
        note: const Value('n'),
      ),
      ContactLogsCompanion.insert(personId: 'person-1', at: tUtc),
    ]);
    b.insertAll(db.projects, [
      ProjectsCompanion.insert(
        id: const Value('project-1'),
        name: 'Project',
        description: const Value('d'),
        deadline: Value(tLocal),
        status: const Value(ProjectStatus.paused),
        planetKey: const Value('growth'),
        color: const Value(0xFF555555),
      ),
      ProjectsCompanion.insert(name: 'sparse'),
    ]);
    b.insertAll(db.projectItems, [
      ProjectItemsCompanion.insert(
        projectId: 'project-1',
        body: 'item',
        done: const Value(true),
        dueDate: Value(tLocal),
      ),
      ProjectItemsCompanion.insert(projectId: 'project-1', body: 'sparse'),
    ]);
    b.insertAll(db.boards, [
      BoardsCompanion.insert(
        id: const Value('board-1'),
        name: 'Board',
        country: const Value('XX'),
        color: const Value(0xFF666666),
        columns: const Value([
          {'id': 'a', 'label': 'A'},
          {'id': 'b', 'label': 'ب'},
        ]),
      ),
      BoardsCompanion.insert(name: 'sparse'),
    ]);
    b.insertAll(db.boardCards, [
      BoardCardsCompanion.insert(
        id: const Value('card-1'),
        boardId: 'board-1',
        columnId: const Value('b'),
        title: 'Card',
        notes: const Value('n'),
        assignee: const Value('someone'),
        dueDate: Value(tLocal),
        isTop3: const Value(true),
        window: const Value(PrayerWindow.maghrib),
      ),
      BoardCardsCompanion.insert(boardId: 'board-1', title: 'sparse'),
    ]);
    b.insertAll(db.trips, [
      TripsCompanion.insert(
        id: const Value('trip-1'),
        destination: 'Somewhere',
        country: const Value('XX'),
        latitude: const Value(31.9539),
        longitude: const Value(-35.9106),
        startDate: Value(tLocal),
        endDate: Value(tUtc),
        status: const Value(TripStatus.active),
        notes: const Value('n'),
        color: const Value(0xFF777777),
      ),
      TripsCompanion.insert(destination: 'sparse'),
    ]);
    b.insertAll(db.tripItems, [
      TripItemsCompanion.insert(
        tripId: 'trip-1',
        body: 'item',
        category: const Value('docs'),
        packed: const Value(true),
      ),
      TripItemsCompanion.insert(tripId: 'trip-1', body: 'sparse'),
    ]);
    b.insert(db.packingTemplates, PackingTemplatesCompanion.insert(name: 'Template', items: const Value(['a', 'b'])));
    b.insertAll(db.travelDocuments, [
      TravelDocumentsCompanion.insert(
        name: 'Passport',
        holder: const Value('holder'),
        number: const Value('000'),
        expiry: Value(tLocal),
        remindDaysBefore: const Value(90),
        notes: const Value('n'),
      ),
      TravelDocumentsCompanion.insert(name: 'sparse'),
    ]);
    b.insertAll(db.learningGoals, [
      LearningGoalsCompanion.insert(
        id: const Value('goal-1'),
        name: 'Goal',
        unit: const Value('pages'),
        target: 604,
        initial: const Value(12.5),
        deadline: Value(tLocal),
        color: const Value(0xFF888888),
        active: const Value(false),
      ),
      LearningGoalsCompanion.insert(name: 'sparse', target: 1),
    ]);
    b.insertAll(db.goalLogs, [
      GoalLogsCompanion.insert(goalId: 'goal-1', amount: 2.25, at: tLocal, note: const Value('n')),
      GoalLogsCompanion.insert(goalId: 'goal-1', amount: 0, at: tUtc),
    ]);
    b.insertAll(db.exercises, [
      ExercisesCompanion.insert(
        id: const Value('ex-1'),
        name: 'Exercise',
        weekdays: const Value([1, 3, 7]),
        sets: const Value(3),
        reps: const Value(12),
        durationMin: const Value(20),
        weight: const Value(17.5),
        notes: const Value('n'),
        active: const Value(false),
      ),
      ExercisesCompanion.insert(name: 'sparse'),
    ]);
    b.insertAll(db.workoutLogs, [
      WorkoutLogsCompanion.insert(
        exerciseId: const Value('ex-1'),
        name: 'Exercise',
        at: tLocal,
        sets: const Value(3),
        reps: const Value(10),
        weight: const Value(15),
        durationMin: const Value(18),
        notes: const Value('n'),
      ),
      WorkoutLogsCompanion.insert(name: 'sparse', at: tUtc),
    ]);
    b.insertAll(db.avoidItems, [
      AvoidItemsCompanion.insert(body: 'item', reason: const Value('r')),
      AvoidItemsCompanion.insert(body: 'sparse'),
    ]);
    b.insertAll(db.fastingSessions, [
      FastingSessionsCompanion.insert(start: tLocal, end: Value(tMicros), targetHours: 16, note: const Value('n')),
      FastingSessionsCompanion.insert(start: tUtc, targetHours: 12.5),
    ]);
    b.insert(db.waterLogs, WaterLogsCompanion.insert(at: tLocal, ml: 250));
    b.insertAll(db.customModules, [
      CustomModulesCompanion.insert(
        id: const Value('module-1'),
        name: 'Module',
        kind: const Value(CustomModuleKind.list),
        icon: const Value('book'),
        color: 0xFF999999,
        planetKey: const Value('growth'),
        window: const Value(PrayerWindow.isha),
        fields: const Value([
          {'id': 'f1', 'label': 'Pages', 'type': 'number', 'unit': 'p', 'required': true, 'options': []},
        ]),
        chart: const Value({'type': 'line', 'fieldId': 'f1', 'range': 30}),
        archived: const Value(true),
      ),
      CustomModulesCompanion.insert(name: 'sparse', color: 0xFF000000),
    ]);
    b.insertAll(db.customEntries, [
      CustomEntriesCompanion.insert(
        moduleId: 'module-1',
        at: Value(tLocal),
        entryValues: const Value({'f1': 12, 'f2': 'text', 'f3': null, 'f4': 1.5}),
        done: const Value(true),
      ),
      CustomEntriesCompanion.insert(moduleId: 'module-1'),
    ]);
    // Schema v2: Quran, wird, Hifz.
    b.insertAll(db.quranBookmarks, [
      QuranBookmarksCompanion.insert(surah: 2, ayah: 255, label: const Value('آية الكرسي'), note: const Value('note'), color: const Value(0xFFD4AF37)),
      QuranBookmarksCompanion.insert(surah: 1, ayah: 1),
    ]);
    b.insertAll(db.quranSessions, [
      QuranSessionsCompanion.insert(
        day: DateTime(2026, 9, 1),
        mode: const Value(QuranSessionMode.listen),
        fromSurah: 2,
        fromAyah: 1,
        toSurah: 2,
        toAyah: 141,
        ayahCount: const Value(141),
        pages: const Value(20.5),
        seconds: const Value(3600),
        planId: const Value('plan-1'),
      ),
      QuranSessionsCompanion.insert(day: DateTime(2026, 9, 2), fromSurah: 1, fromAyah: 1, toSurah: 1, toAyah: 7),
    ]);
    b.insertAll(db.wirdPlans, [
      WirdPlansCompanion.insert(
        id: const Value('plan-1'),
        name: 'ختمة شهرية',
        unit: const Value(WirdUnit.juz),
        amountPerDay: 1,
        startSurah: const Value(2),
        startAyah: const Value(142),
        startDate: DateTime(2026, 9, 1),
        targetDate: Value(DateTime(2026, 9, 30)),
        window: const Value(PrayerWindow.fajr),
        active: const Value(false),
      ),
      WirdPlansCompanion.insert(name: 'sparse', amountPerDay: 2, startDate: DateTime(2026, 9, 1)),
    ]);
    b.insertAll(db.hifzItems, [
      HifzItemsCompanion.insert(
        id: const Value('hifz-1'),
        kind: const Value(HifzKind.hadith),
        title: const Value('إنما الأعمال بالنيات'),
        body: const Value('text'),
        source: const Value('Bukhari 1'),
        easeFactor: const Value(2.36),
        intervalDays: const Value(6),
        repetitions: const Value(2),
        lapses: const Value(1),
        due: Value(DateTime(2026, 9, 7)),
        lastReviewedAt: Value(tLocal),
        suspended: const Value(true),
      ),
      HifzItemsCompanion.insert(surah: const Value(112), ayahFrom: const Value(1), ayahTo: const Value(4)),
    ]);
    b.insertAll(db.hifzReviews, [
      HifzReviewsCompanion.insert(itemId: 'hifz-1', at: tLocal, grade: 4, intervalBefore: 1, intervalAfter: 6, easeAfter: 2.36),
      HifzReviewsCompanion.insert(itemId: 'hifz-1', at: tLocal, grade: 0, intervalBefore: 6, intervalAfter: 1, easeAfter: 2.16),
    ]);
  });
}
