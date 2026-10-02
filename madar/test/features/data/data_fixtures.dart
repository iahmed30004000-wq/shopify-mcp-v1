// A realistic, generic data set touching every summary section, used by the
// summary / repository tests (English names) and the screenshots (Arabic or
// English names). "Now" is Wednesday 30 Sep 2026, 10:00.
import 'package:drift/drift.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/key_value_repository.dart';
import 'package:madar/core/domain/enums.dart';

final DateTime dataTestNow = DateTime(2026, 9, 30, 10);

String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Names per language (user content).
Map<String, String> _names(String lang) => lang == 'ar'
    ? {
        'khatma': 'ختمة الشهر',
        'alert1': 'لا كورتيزون – نخر العظم',
        'alert2': 'تجنّب مضادات الالتهاب',
        'asthma': 'ربو',
        'metformin': 'ميتفورمين',
        'vitd': 'فيتامين د',
        'knee': 'الركبة',
        'back': 'أسفل الظهر',
        'stairs': 'الدرج',
        'work': 'العمل',
        'cash': 'نقدي',
        'usd': 'بطاقة الدولار',
        'food': 'الطعام',
        'rest': 'المطاعم',
        'rent': 'الإيجار',
        'internet': 'الإنترنت',
        'ali': 'علي',
        'travelJar': 'صندوق السفر',
        'mother': 'أمي',
        'motherRel': 'الأم',
        'brother': 'أخي أحمد',
        'brotherRel': 'أخ',
        'sami': 'سامي 0791234567',
        'report': 'إنهاء التقرير',
        'jordan': 'الأردن',
        'cardA': 'متابعة المورّد',
        'cardB': 'تصميم الحملة',
        'cardC': 'الفواتير',
        'website': 'الموقع الجديد',
        'paused': 'كتاب الوصفات',
        'grammar': 'قواعد العربية',
        'lessons': 'درسًا',
        'squats': 'قرفصاء',
        'walk': 'مشي',
        'deep': 'القرفصاء العميقة',
        'kneeReason': 'الركبة',
        'cairo': 'القاهرة',
        'amman': 'عمّان',
        'passport': 'جواز السفر',
        'visa': 'تأشيرة',
        'licence': 'رخصة القيادة',
        'reading': 'سجل القراءة',
        'pages': 'الصفحات',
        'finished': 'أنهيته',
        'genre': 'التصنيف',
        'history': 'تاريخ',
        'fiqh': 'فقه',
        'groceries': 'المشتريات',
      }
    : {
        'khatma': 'Monthly khatma',
        'alert1': 'No cortisone — AVN',
        'alert2': 'Avoid NSAIDs',
        'asthma': 'Asthma',
        'metformin': 'Metformin',
        'vitd': 'Vitamin D',
        'knee': 'knee',
        'back': 'lower back',
        'stairs': 'stairs',
        'work': 'work',
        'cash': 'Cash',
        'usd': 'USD card',
        'food': 'Food',
        'rest': 'Restaurants',
        'rent': 'Rent',
        'internet': 'Internet',
        'ali': 'Ali',
        'travelJar': 'Travel',
        'mother': 'Mother',
        'motherRel': 'mother',
        'brother': 'Brother Ahmad',
        'brotherRel': 'brother',
        'sami': 'Sami 0791234567',
        'report': 'Finish the report',
        'jordan': 'Jordan',
        'cardA': 'Call the supplier',
        'cardB': 'Campaign design',
        'cardC': 'Invoices',
        'website': 'Website',
        'paused': 'Recipe book',
        'grammar': 'Arabic grammar',
        'lessons': 'lessons',
        'squats': 'Squats',
        'walk': 'Walk',
        'deep': 'Deep squats',
        'kneeReason': 'knee',
        'cairo': 'Cairo',
        'amman': 'Amman',
        'passport': 'Passport',
        'visa': 'Visa',
        'licence': 'Driving licence',
        'reading': 'Reading log',
        'pages': 'Pages',
        'finished': 'Finished',
        'genre': 'Genre',
        'history': 'History',
        'fiqh': 'Fiqh',
        'groceries': 'Groceries',
      };

/// Fills [db] with the scenario (no seeding needed).
Future<void> seedSummaryScenario(MadarDatabase db, {String lang = 'en'}) async {
  final n = _names(lang);
  final kv = KeyValueRepository(db);
  await kv.setJson('prayer.settings', {
    'cityNameEn': 'Amman',
    'cityNameAr': 'عمّان',
    'countryCode': 'JO',
    'timeZone': 'Asia/Amman',
    'latitude': 31.95,
    'longitude': 35.93,
  });
  await kv.setJson('body.waterTargetMl', 2500);
  await kv.setJson('work.archivedBoards', ['board-old']);

  await db.batch((b) {
    // ------------------------------------------------------------- faith
    const five = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];
    for (var d = 24; d <= 30; d++) {
      final day = DateTime(2026, 9, d);
      for (final p in d == 30 ? const [Prayer.fajr, Prayer.dhuhr] : five) {
        final status = switch ((d, p)) {
          (25, Prayer.asr) => PrayerStatus.late,
          (26, Prayer.fajr) => PrayerStatus.qada,
          (27, Prayer.isha) => PrayerStatus.missed,
          _ => PrayerStatus.prayed,
        };
        b.insert(
          db.prayerLogs,
          PrayerLogsCompanion.insert(day: _day(day), prayer: p, status: Value(status), inJamaah: Value(p == Prayer.maghrib)),
        );
      }
    }
    for (final p in five) {
      b.insert(db.prayerLogs, PrayerLogsCompanion.insert(day: '2026-09-10', prayer: p));
      b.insert(db.prayerLogs, PrayerLogsCompanion.insert(day: '2026-08-01', prayer: p));
    }
    b.insertAll(db.prayerLogs, [
      PrayerLogsCompanion.insert(day: '2026-09-28', prayer: Prayer.witr),
      PrayerLogsCompanion.insert(day: '2026-09-29', prayer: Prayer.duha),
      PrayerLogsCompanion.insert(day: '2026-09-29', prayer: Prayer.qiyam, status: const Value(PrayerStatus.missed)),
    ]);
    b.insertAll(db.quranSessions, [
      QuranSessionsCompanion.insert(day: DateTime(2026, 9, 29), fromSurah: 2, fromAyah: 1, toSurah: 2, toAyah: 20, pages: const Value(2.5), seconds: const Value(900)),
      QuranSessionsCompanion.insert(day: DateTime(2026, 9, 20), fromSurah: 3, fromAyah: 1, toSurah: 3, toAyah: 90, pages: const Value(10), seconds: const Value(1800)),
    ]);
    b.insertAll(db.wirdPlans, [
      WirdPlansCompanion.insert(name: n['khatma']!, amountPerDay: 20, startDate: DateTime(2026, 9, 1), targetDate: Value(DateTime(2026, 10, 1))),
      WirdPlansCompanion.insert(name: 'Old plan', amountPerDay: 1, startDate: DateTime(2025, 1, 1), active: const Value(false)),
    ]);
    b.insertAll(db.hifzItems, [
      HifzItemsCompanion.insert(id: const Value('h1'), surah: const Value(112), ayahFrom: const Value(1), ayahTo: const Value(4)),
      HifzItemsCompanion.insert(id: const Value('h2'), surah: const Value(113), due: Value(DateTime(2026, 9, 30))),
      HifzItemsCompanion.insert(id: const Value('h3'), surah: const Value(114), due: Value(DateTime(2026, 10, 5))),
      HifzItemsCompanion.insert(id: const Value('h4'), surah: const Value(1), suspended: const Value(true)),
    ]);
    b.insertAll(db.hifzReviews, [
      HifzReviewsCompanion.insert(itemId: 'h2', at: DateTime(2026, 9, 25, 9), grade: 4, intervalBefore: 1, intervalAfter: 3, easeAfter: 2.5),
      HifzReviewsCompanion.insert(itemId: 'h3', at: DateTime(2026, 9, 28, 9), grade: 5, intervalBefore: 3, intervalAfter: 7, easeAfter: 2.6),
      HifzReviewsCompanion.insert(itemId: 'h3', at: DateTime(2026, 7, 1, 9), grade: 1, intervalBefore: 3, intervalAfter: 1, easeAfter: 2.2),
    ]);

    // ------------------------------------------------------------ health
    b.insertAll(db.healthAlerts, [
      HealthAlertsCompanion.insert(body: n['alert2']!, severity: const Value(Severity.warning)),
      HealthAlertsCompanion.insert(body: n['alert1']!),
      HealthAlertsCompanion.insert(body: 'Unpinned note', severity: const Value(Severity.info), pinned: const Value(false)),
    ]);
    b.insertAll(db.conditions, [
      ConditionsCompanion.insert(name: n['asthma']!, since: Value(DateTime(2019, 5, 1)), notes: const Value('private condition note')),
      ConditionsCompanion.insert(name: 'Old condition', active: const Value(false)),
    ]);
    b.insertAll(db.medications, [
      MedicationsCompanion.insert(
        name: n['metformin']!,
        dose: const Value('500 mg'),
        times: const Value(['20:00', '08:00']),
        takenWith: const Value(TakenWith.breakfast),
        notes: const Value('private med note'),
      ),
      MedicationsCompanion.insert(name: n['vitd']!, kind: const Value(MedKind.supplement), times: const Value(['09:00'])),
      MedicationsCompanion.insert(name: 'Stopped med', active: const Value(false)),
    ]);
    b.insertAll(db.labTests, [
      LabTestsCompanion.insert(id: const Value('lt-a1c'), name: 'HbA1c', unit: const Value('%'), low: const Value(4), high: const Value(5.6)),
      LabTestsCompanion.insert(id: const Value('lt-crp'), name: 'CRP', unit: const Value('mg/L'), high: const Value(5)),
      LabTestsCompanion.insert(id: const Value('lt-old'), name: 'Old test'),
    ]);
    b.insertAll(db.labReadings, [
      LabReadingsCompanion.insert(testId: 'lt-a1c', date: DateTime(2026, 9, 1), value: const Value(6.1), note: const Value('private lab note')),
      LabReadingsCompanion.insert(testId: 'lt-a1c', date: DateTime(2026, 3, 1), value: const Value(5.55)),
      LabReadingsCompanion.insert(testId: 'lt-crp', date: DateTime(2026, 9, 2), value: const Value(2)),
      LabReadingsCompanion.insert(testId: 'lt-old', date: DateTime(2024, 1, 1), value: const Value(1)),
    ]);
    b.insertAll(db.painEntries, [
      PainEntriesCompanion.insert(
        at: DateTime(2026, 9, 29, 8),
        score: 6,
        locations: Value([n['knee']!, n['back']!]),
        triggers: Value([n['stairs']!]),
        notes: const Value('private pain note'),
      ),
      PainEntriesCompanion.insert(at: DateTime(2026, 9, 28, 21), score: 3, locations: Value([n['knee']!])),
      PainEntriesCompanion.insert(at: DateTime(2026, 8, 20, 12), score: 8),
    ]);
    b.insertAll(db.moodEntries, [
      MoodEntriesCompanion.insert(
        at: DateTime(2026, 9, 29, 22),
        mood: const Value(4),
        stress: const Value(3),
        anxiety: const Value(2),
        energy: const Value(6),
        sleepHours: const Value(7.5),
        caffeineCups: const Value(2),
        factors: Value([n['work']!]),
        notes: const Value('private mood note'),
      ),
      MoodEntriesCompanion.insert(at: DateTime(2026, 9, 27, 22), mood: const Value(3), stress: const Value(6), sleepHours: const Value(6)),
      MoodEntriesCompanion.insert(at: DateTime(2026, 8, 25, 22), mood: const Value(2), stress: const Value(8)),
    ]);
    b.insert(db.worries, WorriesCompanion.insert(body: 'private worry'));

    // ------------------------------------------------------------- money
    b.insertAll(db.currencies, [
      CurrenciesCompanion.insert(code: 'JOD', nameAr: 'دينار', nameEn: 'Dinar', symbol: 'JD', decimals: const Value(3), isBase: const Value(true)),
      CurrenciesCompanion.insert(code: 'USD', nameAr: 'دولار', nameEn: 'Dollar', symbol: r'$', decimals: const Value(2), rateToBase: const Value(0.709)),
    ]);
    b.insertAll(db.wallets, [
      WalletsCompanion.insert(id: const Value('w-cash'), name: n['cash']!, currency: 'JOD', openingMilli: const Value(100000)),
      WalletsCompanion.insert(id: const Value('w-usd'), name: n['usd']!, currency: 'USD'),
      WalletsCompanion.insert(id: const Value('w-old'), name: 'Old wallet', currency: 'JOD', archived: const Value(true)),
    ]);
    b.insertAll(db.budgetItems, [
      BudgetItemsCompanion.insert(id: const Value('b-food'), name: n['food']!, amountMilli: const Value(200000)),
      BudgetItemsCompanion.insert(id: const Value('b-rest'), name: n['rest']!, parentId: const Value('b-food'), amountMilli: const Value(10000)),
    ]);
    b.insertAll(db.transactions, [
      TransactionsCompanion.insert(walletId: 'w-cash', kind: TxKind.expense, amountMilli: 12500, date: DateTime(2026, 9, 29), budgetItemId: const Value('b-rest'), note: const Value('private tx note')),
      TransactionsCompanion.insert(walletId: 'w-usd', kind: TxKind.income, amountMilli: 100000, date: DateTime(2026, 9, 10)),
      TransactionsCompanion.insert(walletId: 'w-usd', kind: TxKind.transfer, amountMilli: 50000, toWalletId: const Value('w-cash'), toAmountMilli: const Value(35450), date: DateTime(2026, 9, 11)),
      TransactionsCompanion.insert(walletId: 'w-cash', kind: TxKind.adjustment, amountMilli: -2000, date: DateTime(2026, 9, 12)),
    ]);
    b.insertAll(db.obligations, [
      ObligationsCompanion.insert(name: n['rent']!, amountMilli: 350000, currency: 'JOD', frequency: Recurrence.monthly, nextDue: DateTime(2026, 10, 1)),
      ObligationsCompanion.insert(name: n['internet']!, amountMilli: 25000, currency: 'JOD', frequency: Recurrence.monthly, nextDue: DateTime(2026, 9, 25)),
      ObligationsCompanion.insert(name: 'Insurance', amountMilli: 90000, currency: 'JOD', frequency: Recurrence.yearly, nextDue: DateTime(2026, 12, 1)),
      ObligationsCompanion.insert(name: 'Gym', amountMilli: 20000, currency: 'JOD', frequency: Recurrence.monthly, nextDue: DateTime(2026, 10, 2), active: const Value(false)),
    ]);
    b.insertAll(db.debts, [
      DebtsCompanion.insert(id: const Value('d1'), direction: DebtDirection.iOwe, person: n['ali']!, amountMilli: 100000, currency: 'JOD', dueDate: Value(DateTime(2026, 10, 10))),
      DebtsCompanion.insert(id: const Value('d2'), direction: DebtDirection.owedToMe, person: 'Settled person', amountMilli: 5000, currency: 'JOD', settledAt: Value(DateTime(2026, 9, 1))),
    ]);
    b.insert(db.debtPayments, DebtPaymentsCompanion.insert(debtId: 'd1', amountMilli: 50000, date: DateTime(2026, 9, 15)));
    b.insertAll(db.jars, [
      JarsCompanion.insert(id: const Value('j1'), name: n['travelJar']!, targetMilli: 1000000, currency: 'JOD', deadline: Value(DateTime(2026, 12, 31))),
    ]);
    b.insertAll(db.jarDeposits, [
      JarDepositsCompanion.insert(jarId: 'j1', amountMilli: 400000, date: DateTime(2026, 8, 1)),
      JarDepositsCompanion.insert(jarId: 'j1', amountMilli: 50000, date: DateTime(2026, 9, 1)),
    ]);

    // ------------------------------------------------------------ family
    b.insertAll(db.people, [
      PeopleCompanion.insert(
        id: const Value('p-mother'),
        name: n['mother']!,
        relation: Value(n['motherRel']),
        rhythmDays: const Value(3),
        lastContact: Value(DateTime(2026, 9, 29, 10)),
        phone: const Value('0790000001'),
        createdAt: Value(DateTime(2026, 1, 1)),
      ),
      PeopleCompanion.insert(
        id: const Value('p-brother'),
        name: n['brother']!,
        relation: Value(n['brotherRel']),
        rhythmDays: const Value(7),
        lastContact: Value(DateTime(2026, 9, 18, 18)),
        phone: const Value('0790000002'),
        createdAt: Value(DateTime(2026, 1, 1)),
      ),
      PeopleCompanion.insert(id: const Value('p-sami'), name: n['sami']!, rhythmDays: const Value(30), createdAt: Value(DateTime(2026, 9, 20))),
      PeopleCompanion.insert(name: 'Cousin', phone: const Value('0790000003')),
      PeopleCompanion.insert(name: 'Neighbour'),
    ]);
    b.insert(db.contactLogs, ContactLogsCompanion.insert(personId: 'p-mother', at: DateTime(2026, 9, 30, 8), note: const Value('private call note')));

    // -------------------------------------------------------------- work
    b.insertAll(db.tasks, [
      TasksCompanion.insert(title: n['report']!, isTop3: const Value(true)),
      TasksCompanion.insert(title: 'Done top task', isTop3: const Value(true), done: const Value(true)),
      TasksCompanion.insert(title: 'Plain task'),
    ]);
    b.insertAll(db.boards, [
      BoardsCompanion.insert(id: const Value('board-jo'), name: n['jordan']!, country: const Value('JO')),
      BoardsCompanion.insert(id: const Value('board-old'), name: 'Archived board'),
    ]);
    b.insertAll(db.boardCards, [
      BoardCardsCompanion.insert(boardId: 'board-jo', title: n['cardA']!, isTop3: const Value(true)),
      BoardCardsCompanion.insert(boardId: 'board-jo', title: n['cardB']!, columnId: const Value('doing')),
      BoardCardsCompanion.insert(boardId: 'board-jo', title: n['cardC']!, columnId: const Value('done'), isTop3: const Value(true)),
      BoardCardsCompanion.insert(boardId: 'board-old', title: 'Archived top card', isTop3: const Value(true)),
    ]);
    b.insertAll(db.projects, [
      ProjectsCompanion.insert(id: const Value('pr-web'), name: n['website']!, deadline: Value(DateTime(2026, 11, 1))),
      ProjectsCompanion.insert(name: n['paused']!, status: const Value(ProjectStatus.paused)),
      ProjectsCompanion.insert(name: 'Finished project', status: const Value(ProjectStatus.done)),
    ]);
    b.insertAll(db.projectItems, [
      ProjectItemsCompanion.insert(projectId: 'pr-web', body: 'a', done: const Value(true)),
      ProjectItemsCompanion.insert(projectId: 'pr-web', body: 'b'),
      ProjectItemsCompanion.insert(projectId: 'pr-web', body: 'c'),
    ]);

    // ------------------------------------------------------------ growth
    b.insertAll(db.learningGoals, [
      LearningGoalsCompanion.insert(id: const Value('g1'), name: n['grammar']!, unit: Value(n['lessons']!), target: 100, initial: const Value(30), deadline: Value(DateTime(2026, 12, 31))),
      LearningGoalsCompanion.insert(name: 'Paused goal', target: 10, active: const Value(false)),
    ]);
    b.insertAll(db.goalLogs, [
      GoalLogsCompanion.insert(goalId: 'g1', amount: 8, at: DateTime(2026, 9, 20)),
      GoalLogsCompanion.insert(goalId: 'g1', amount: 4, at: DateTime(2026, 7, 1)),
    ]);

    // -------------------------------------------------------------- body
    b.insertAll(db.exercises, [
      ExercisesCompanion.insert(name: n['squats']!, weekdays: const Value([7, 2, 4]), sets: const Value(3), reps: const Value(12), weight: const Value(20)),
      ExercisesCompanion.insert(name: n['walk']!, durationMin: const Value(30)),
      ExercisesCompanion.insert(name: 'Old exercise', active: const Value(false)),
    ]);
    b.insertAll(db.workoutLogs, [
      WorkoutLogsCompanion.insert(name: n['walk']!, at: DateTime(2026, 9, 29, 18), durationMin: const Value(30)),
      WorkoutLogsCompanion.insert(name: n['squats']!, at: DateTime(2026, 9, 20, 18), durationMin: const Value(45)),
      WorkoutLogsCompanion.insert(name: 'Old', at: DateTime(2026, 6, 1, 18), durationMin: const Value(60)),
    ]);
    b.insertAll(db.fastingSessions, [
      FastingSessionsCompanion.insert(start: DateTime(2026, 9, 28, 20), end: Value(DateTime(2026, 9, 29, 12)), targetHours: 16),
      FastingSessionsCompanion.insert(start: DateTime(2026, 9, 21, 20), end: Value(DateTime(2026, 9, 22, 10)), targetHours: 14),
      FastingSessionsCompanion.insert(start: DateTime(2026, 9, 30, 6), targetHours: 16),
    ]);
    b.insertAll(db.waterLogs, [
      WaterLogsCompanion.insert(at: DateTime(2026, 9, 29, 12), ml: 2000),
      WaterLogsCompanion.insert(at: DateTime(2026, 9, 30, 9), ml: 1500),
      WaterLogsCompanion.insert(at: DateTime(2026, 9, 24, 9), ml: 3500),
      WaterLogsCompanion.insert(at: DateTime(2026, 9, 1, 9), ml: 9999),
    ]);
    b.insert(db.avoidItems, AvoidItemsCompanion.insert(body: n['deep']!, reason: Value(n['kneeReason'])));

    // ------------------------------------------------------------ travel
    b.insertAll(db.trips, [
      TripsCompanion.insert(destination: n['cairo']!, country: const Value('EG'), startDate: Value(DateTime(2026, 10, 12)), endDate: Value(DateTime(2026, 10, 20))),
      TripsCompanion.insert(destination: n['amman']!, startDate: Value(DateTime(2026, 9, 28)), endDate: Value(DateTime(2026, 10, 2)), status: const Value(TripStatus.active)),
      TripsCompanion.insert(destination: 'Past trip', startDate: Value(DateTime(2026, 8, 1)), endDate: Value(DateTime(2026, 9, 1))),
      TripsCompanion.insert(destination: 'Done trip', status: const Value(TripStatus.done)),
    ]);
    b.insertAll(db.travelDocuments, [
      TravelDocumentsCompanion.insert(name: n['passport']!, number: const Value('N1234567'), holder: const Value('Holder Person'), expiry: Value(DateTime(2027, 3, 1))),
      TravelDocumentsCompanion.insert(name: n['visa']!, number: const Value('V-77-99'), expiry: Value(DateTime(2026, 9, 1))),
      TravelDocumentsCompanion.insert(name: n['licence']!, notes: const Value('private doc note')),
    ]);

    // ------------------------------------------------------------ custom
    b.insertAll(db.customModules, [
      CustomModulesCompanion.insert(
        id: const Value('m-read'),
        name: n['reading']!,
        color: 0xFF3366AA,
        fields: Value([
          {'id': 'f1', 'label': n['pages'], 'type': 'number', 'unit': 'p'},
          {'id': 'f2', 'label': n['finished'], 'type': 'checkbox'},
          {
            'id': 'f3',
            'label': n['genre'],
            'type': 'singleSelect',
            'options': [
              {'id': 'o1', 'label': n['history']},
              {'id': 'o2', 'label': n['fiqh']},
            ],
          },
          {'id': 'f4', 'label': 'Thoughts', 'type': 'text'},
        ]),
      ),
      CustomModulesCompanion.insert(id: const Value('m-list'), name: n['groceries']!, color: 0xFF22AA66, kind: const Value(CustomModuleKind.list)),
      CustomModulesCompanion.insert(name: 'Archived module', color: 0xFF000000, archived: const Value(true)),
    ]);
    b.insertAll(db.customEntries, [
      CustomEntriesCompanion.insert(moduleId: 'm-read', at: Value(DateTime(2026, 9, 29, 21)), entryValues: const Value({'f1': 20, 'f2': true, 'f3': 'o1', 'f4': 'private thoughts'})),
      CustomEntriesCompanion.insert(moduleId: 'm-read', at: Value(DateTime(2026, 9, 20, 21)), entryValues: const Value({'f1': 10, 'f2': false, 'f3': 'o1'})),
      CustomEntriesCompanion.insert(moduleId: 'm-read', at: Value(DateTime(2026, 7, 1, 21)), entryValues: const Value({'f1': 99})),
      CustomEntriesCompanion.insert(moduleId: 'm-list', entryValues: const Value({'title': 'Milk'})),
      CustomEntriesCompanion.insert(moduleId: 'm-list', entryValues: const Value({'title': 'Bread'})),
      CustomEntriesCompanion.insert(moduleId: 'm-list', entryValues: const Value({'title': 'Dates'}), done: const Value(true)),
    ]);
  });
}
