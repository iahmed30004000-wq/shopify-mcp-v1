// «شو صار اليوم؟» – his own day, counted out of his own data and read back
// to him in plain Jordanian Arabic. Offline: nothing here touches a network
// or an AI.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/day_chat/day_chat.dart';
import 'package:madar/features/home/domain/prayer_day.dart';

import '../../helpers/test_app.dart';

void main() {
  final now = DateTime(2026, 10, 14, 20, 30);
  final today = DateTime(2026, 10, 14);

  DayChatTexts texts([String language = 'ar']) =>
      DayChatTexts(lookupL10n(Locale(language)), MadarFormatter(languageCode: language));

  group('the engine counts his day', () {
    test('an empty day says so instead of pretending', () {
      final summary = DaySummaryBuilder().build(DaySummaryInput(day: today, now: now));
      expect(summary.isEmpty, isTrue);
      expect(texts().summary(summary), [lookupL10n(const Locale('ar')).dayChatSummaryEmpty]);
    });

    test('prayers: how many, how many at the mosque, how many missed', () {
      PrayerLogRow log(Prayer prayer, PrayerStatus status, {bool mosque = false}) => PrayerLogRow(
        id: '${prayer.name}$status',
        createdAt: now,
        updatedAt: now,
        day: '2026-10-14',
        prayer: prayer,
        status: status,
        inJamaah: mosque,
        atMosque: mosque,
        loggedAt: now,
      );
      final summary = DaySummaryBuilder().build(
        DaySummaryInput(
          day: today,
          now: now,
          prayers: [
            log(Prayer.fajr, PrayerStatus.prayed),
            log(Prayer.dhuhr, PrayerStatus.prayed, mosque: true),
            log(Prayer.asr, PrayerStatus.prayed, mosque: true),
            log(Prayer.maghrib, PrayerStatus.missed),
            log(Prayer.witr, PrayerStatus.prayed),
          ],
        ),
      );
      final line = summary.line(DaySummaryTopic.prayers)!;
      expect(line.count, 3, reason: 'three obligatory prayers prayed');
      expect(line.second, 2, reason: 'two at the mosque');
      expect(line.third, 1, reason: 'one missed');
      expect(line.value, 1, reason: 'one voluntary prayer');
      final text = texts().summary(summary).single;
      expect(text, contains('بالمسجد'));
      expect(text, contains('فاتتك'));
      expect(text, isNot(contains('3')), reason: 'his digits, never Western ones in Arabic');
      expect(text, contains('٣'));
    });

    test('money is grouped per currency, spent and received apart', () {
      WalletRow wallet(String id, String currency) => WalletRow(
        id: id,
        createdAt: now,
        updatedAt: now,
        sortOrder: 0,
        name: id,
        currency: currency,
        openingMilli: 0,
        kind: WalletKind.personal,
        archived: false,
      );
      TransactionRow tx(String id, String wallet, TxKind kind, int milli) => TransactionRow(
        id: id,
        createdAt: now,
        updatedAt: now,
        walletId: wallet,
        kind: kind,
        amountMilli: milli,
        date: now,
        tags: const [],
      );
      final summary = DaySummaryBuilder().build(
        DaySummaryInput(
          day: today,
          now: now,
          wallets: [wallet('w1', 'JOD'), wallet('w2', 'USD')],
          transactions: [
            tx('t1', 'w1', TxKind.expense, 5000),
            tx('t2', 'w1', TxKind.expense, 2500),
            tx('t3', 'w1', TxKind.income, 700000),
            tx('t4', 'w2', TxKind.expense, 1000),
          ],
          baseCurrency: 'JOD',
        ),
      );
      final lines = [
        for (final l in summary.lines)
          if (l.topic == DaySummaryTopic.money) l,
      ];
      expect(lines, hasLength(2));
      expect(lines.first.currency, 'JOD');
      expect(lines.first.amountMilli, 7500);
      expect(lines.first.secondAmountMilli, 700000);
      expect(lines[1].currency, 'USD');
    });

    test('the names it reads out are his own, at most three, then «وكمان»', () {
      FoodLogRow meal(String name) =>
          FoodLogRow(id: name, createdAt: now, updatedAt: now, name: name, at: now, tags: const []);
      final summary = DaySummaryBuilder().build(
        DaySummaryInput(
          day: today,
          now: now,
          foodLogs: [meal('منسف'), meal('شاي'), meal('تمر'), meal('لبنة'), meal('منسف')],
        ),
      );
      final line = summary.line(DaySummaryTopic.meals)!;
      expect(line.count, 5);
      expect(line.names, ['منسف', 'شاي', 'تمر'], reason: 'each name once, in his order');
      expect(line.more, 1);
      final text = texts().summary(summary).single;
      expect(text, contains('منسف'));
      expect(text, contains('شاي'));
      expect(text, isNot(contains('لبنة')));
    });

    test('water says how much and out of what', () {
      final summary = DaySummaryBuilder().build(
        DaySummaryInput(
          day: today,
          now: now,
          water: [
            WaterLogRow(id: 'a', createdAt: now, updatedAt: now, at: now, ml: 500),
            WaterLogRow(id: 'b', createdAt: now, updatedAt: now, at: now, ml: 750),
          ],
          waterTargetMl: 2500,
        ),
      );
      final line = summary.line(DaySummaryTopic.water)!;
      expect(line.value, 1250);
      expect(line.target, 2500);
      final text = texts().summary(summary).single;
      final fmt = MadarFormatter(languageCode: 'ar');
      expect(text, contains(fmt.formatInt(1250)));
      expect(text, contains(fmt.formatInt(2500)));
      expect(texts('en').summary(summary).single, contains(MadarFormatter(languageCode: 'en').formatInt(1250)));
    });

    test('tasks: what he finished, and what is still open by name', () {
      TaskRow task(String title, {required bool done}) => TaskRow(
        id: title,
        createdAt: now,
        updatedAt: now,
        sortOrder: 0,
        title: title,
        window: PrayerWindow.dhuhr,
        done: done,
        doneAt: done ? now : null,
        priority: 0,
        isTop3: false,
      );
      final summary = DaySummaryBuilder().build(
        DaySummaryInput(
          day: today,
          now: now,
          tasks: [task('تقرير الشغل', done: true), task('البنك', done: false), task('الصيدلية', done: false)],
        ),
      );
      final line = summary.line(DaySummaryTopic.tasks)!;
      expect(line.count, 1);
      expect(line.second, 2);
      expect(line.names, ['البنك', 'الصيدلية']);
      final text = texts().summary(summary).single;
      expect(text, contains('البنك'));
    });
  });

  group('over his real data', () {
    late MadarDatabase db;
    late Repositories repos;
    late DayChatService service;

    setUp(() async {
      db = testDatabase();
      await db.customSelect('SELECT 1').get();
      repos = Repositories(db);
      service = DayChatService(
        repos,
        clock: () => now,
        prayerDay: () => PrayerDayTimes.placeholder,
        focusedWindow: () => PrayerWindow.isha,
        defaultWalletName: () => 'المحفظة',
      );
    });

    tearDown(() => db.close());

    test('what he filed from the chat today is what the summary reads back', () async {
      await CustomModulesService(repos, clock: () => now).createModule(
        const ModuleDefinition(
          id: '',
          name: 'سكر الدم',
          colorArgb: 0xFF112233,
          fields: [ModuleField(id: 'f1', label: 'القراءة', type: FieldType.number, min: 40, max: 500)],
        ),
      );
      await repos.tasks.insert(TasksCompanion.insert(title: 'تقرير الشغل', window: Value(PrayerWindow.dhuhr)));

      const line = 'صرفت ٥ دنانير قهوة، صليت العصر بالمسجد، تمرين صدر ٤×١٢، وجع الركبة ٦، '
          'أكلت منسف الساعة ٢، شربت ٥٠٠ مل مي، سكر الدم ١٢٠، خلصت تقرير الشغل';
      final reading = await service.read(line);
      await service.remember(reading);
      for (final piece in reading.pieces) {
        expect(piece.canApply, isTrue, reason: '${piece.kind}: ${piece.gaps}');
        await service.apply(piece);
      }

      final summary = await service.summary();
      expect(summary.isEmpty, isFalse);
      expect(summary.line(DaySummaryTopic.money)?.amountMilli, 5000);
      expect(summary.line(DaySummaryTopic.prayers)?.second, 1);
      expect(summary.line(DaySummaryTopic.workouts)?.count, 1);
      expect(summary.line(DaySummaryTopic.pain)?.value, 6);
      expect(summary.line(DaySummaryTopic.meals)?.names, ['منسف']);
      expect(summary.line(DaySummaryTopic.water)?.value, 500);
      expect(summary.line(DaySummaryTopic.modules)?.names, ['سكر الدم 120']);
      expect(summary.line(DaySummaryTopic.tasks)?.count, 1);
      expect(summary.line(DaySummaryTopic.chat)?.count, reading.pieces.length);

      final sentences = texts().summary(summary);
      expect(sentences, isNotEmpty);
      expect(sentences.join(' '), contains('منسف'));
      expect(sentences.join(' '), contains('المسجد'));
      // His digits everywhere in Arabic.
      expect(sentences.join(' '), isNot(matches(RegExp('[0-9]'))));
    });

    test('a day he logged nothing on reads as an empty day', () async {
      final summary = await service.summary(day: DateTime(2026, 10, 10));
      expect(summary.isEmpty, isTrue);
      expect(texts().summary(summary).single, lookupL10n(const Locale('ar')).dayChatSummaryEmpty);
    });
  });
}
