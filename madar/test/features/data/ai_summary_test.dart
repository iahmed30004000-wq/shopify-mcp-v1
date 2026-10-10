import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/data/data/data_repository.dart';
import 'package:madar/features/data/domain/ai_summary.dart';
import 'package:madar/features/data/domain/ai_summary_builder.dart';
import 'package:madar/features/data/domain/summary_input.dart';
import 'package:madar/features/data/domain/summary_text.dart';

import 'data_fixtures.dart';

final en = lookupL10n(const Locale('en'));
final ar = lookupL10n(const Locale('ar'));
const allProfile = SummaryProfileOptions(
  city: true,
  timeZone: true,
  currency: true,
  language: true,
  aboutMe: '34 years old,\ncall me at 0791234567',
);

AiSummary build(SummaryInput input, {String lang = 'en', SummaryProfileOptions profile = const SummaryProfileOptions()}) =>
    AiSummaryBuilder(lang == 'ar' ? ar : en, languageCode: lang).build(input, profile: profile);

/// Expected English bodies of the scenario in `data_fixtures.dart`.
const expectedBodies = <SummarySectionId, String>{
  SummarySectionId.profile: '''
- City: Amman (JO)
- Time zone: Asia/Amman
- Base currency: JOD
- App language: English
- About me: 34 years old, call me at •••''',
  SummarySectionId.faith: '''
### Prayers
- Last 7 days (obligatory) — logged: 32/35 · on time: 29 · late: 1 · made up: 1 · missed: 1 · in congregation: 6
- Last 30 days (obligatory) — logged: 37/150 · on time: 34 · late: 1 · made up: 1 · missed: 1 · in congregation: 6
- Last 30 days (voluntary): 2

### Quran and wird
- Last 7 days — sessions: 1 · pages: 2.5 · 15 min
- Last 30 days — sessions: 2 · pages: 12.5 · 45 min
- Wird “Monthly khatma”: 20 pages a day · since 2026-09-01 · by 2026-10-01

### Hifz
- items: 3 · new: 1 · due today: 1
- Last 30 days — reviews: 2 · average grade: 4.5/5''',
  SummarySectionId.health: '''
### Standing alerts
- No cortisone — AVN (critical)
- Avoid NSAIDs (warning)

### Conditions
- Asthma · since 2019-05-01

### Active medications
- Metformin · 500 mg · 08:00, 20:00 · with breakfast
- Vitamin D (supplement) · 09:00

### Recent labs
_Latest result per test in the last 12 months; flags compare with the range saved in the app._

| Test | Date | Result | Range | Flag | Previous |
| --- | --- | --- | --- | --- | --- |
| HbA1c | 2026-09-01 | 6.1 % | 4–5.6 | high | 5.55 % (2026-03-01) |
| CRP | 2026-09-02 | 2 mg/L | ≤ 5 | in range |   |

### Pain (tracking)
- Last 30 days — entries: 2 · average: 4.5/10 · highest: 6/10
- The 30 days before — entries: 1 · average: 8/10
- Most logged places: knee (2), lower back (1)
- Most logged triggers: stairs (1)

### Mood (tracking)
- Last 30 days — entries: 2 · mood: 3.5/5 · stress: 4.5/10 · anxiety: 2/10 · energy: 6/10 · sleep: 6.8 h · caffeine: 2 cups
- The 30 days before — entries: 1 · mood: 2/5 · stress: 8/10
- Common factors: work (1)''',
  SummarySectionId.money: '''
### Wallets
_Converted to JOD with the exchange rates saved in the app._

| Wallet | Balance | In JOD |
| --- | --- | --- |
| Cash | 120.950 JOD | 120.950 |
| USD card | 50.00 USD | 35.450 |

- Total: 156.400 JOD

### Budget — 2026-09
- planned: 200.000 JOD · spent: 12.500 JOD (6%) · remaining: 187.500 JOD
- Over plan: Restaurants +2.500

### Due in the next 30 days
- Internet: 25.000 JOD – overdue since 2026-09-25
- Rent: 350.000 JOD – due 2026-10-01

### Debts
- I owe Ali: 50.000 JOD left of 100.000 JOD · due 2026-10-10

### Savings jars
- Travel: 450.000 JOD of 1000.000 JOD (45%) · by 2026-12-31''',
  SummarySectionId.family: '''
- Brother Ahmad (Brother) · rhythm: every 7 days · days since last contact: 12 · overdue by (days): 5
- Mother (Mother) · rhythm: every 3 days · days since last contact: 0 · due in (days): 3
- Sami ••• · rhythm: every 30 days · no contact logged yet · due in (days): 20
- 2 more people without a contact rhythm''',
  SummarySectionId.work: '''
### Top 3
- Finish the report
- Call the supplier (board: Jordan)

### Boards
- Jordan (JO): To-do 1 · Doing 1 · Done 1

### Projects
- Website (active) · items done: 1/3 · deadline: 2026-11-01
- Recipe book (paused)''',
  SummarySectionId.growth: '''
- Arabic grammar: 42 of 100 lessons (42%) · Last 30 days: +8 · by 2026-12-31''',
  SummarySectionId.body: '''
### Exercise plan
- Squats: Tue, Thu, Sun · 3×12 · 20 kg
- Walk: 30 min

### Last 30 days
- workouts: 2 · 75 min
- fasts: 2 · average: 15 h · target: 16 h
- Water, last 7 days: 1000 ml a day on average · target: 2500 ml

### Avoid
- Deep squats — knee''',
  SummarySectionId.travel: '''
### Upcoming trips
- Amman · 2026-09-28 → 2026-10-02 · under way
- Cairo (EG) · 2026-10-12 → 2026-10-20 · planned

### Documents (numbers are never included)
- Visa: expired 2026-09-01
- Passport: expires 2027-03-01 (days left: 152)
- Driving licence: no expiry date''',
  SummarySectionId.custom: '''
### Groceries (list)
- open: 2 · done: 1

### Reading log (tracker)
- entries: 3 · Last 30 days: 2 · last: 2026-09-29
- Pages (p): average: 15 · min: 10 · max: 20 · total: 30
- Finished: ticked: 1/2
- Genre: History (2)''',
};

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  late MadarDatabase db;
  setUp(() => db = MadarDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<SummaryInput> load() => DataExportRepository(db, useIsolate: false).loadSummaryInput(dataTestNow);

  group('empty data', () {
    test('every section is empty and says so; the document is just the header', () {
      final s = build(SummaryInput(now: dataTestNow));
      expect(s.sections.map((x) => x.id), SummarySectionId.values);
      for (final section in s.sections) {
        expect(section.isEmpty, isTrue, reason: section.id.name);
        expect(section.body, 'No data yet.');
      }
      expect(s.compose(SummarySectionId.values.toSet()), '# Madar summary — 2026-09-30\n\n${en.dataSumPreamble}\n');
    });

    test('the app language is the only profile item that needs no data', () {
      final s = build(SummaryInput(now: dataTestNow), profile: allProfile.copyWith(aboutMe: ''));
      expect(s.section(SummarySectionId.profile).body, '- App language: English');
    });

    test('an empty database gives the same result', () async {
      final s = build(await load());
      expect(s.sections.where((x) => !x.isEmpty), isEmpty);
    });

    test('in Arabic too', () {
      final s = build(SummaryInput(now: dataTestNow), lang: 'ar');
      expect(s.heading, 'ملخّص مَدار — 2026-09-30');
      expect(s.section(SummarySectionId.health).body, 'لا بيانات بعد.');
      expect(s.section(SummarySectionId.health).title, 'الصحة');
    });
  });

  group('every section with data', () {
    late AiSummary s;
    setUp(() async {
      await seedSummaryScenario(db);
      s = build(await load(), profile: allProfile);
    });

    for (final id in SummarySectionId.values) {
      test(id.name, () {
        final section = s.section(id);
        expect(section.isEmpty, isFalse);
        expect(section.body, expectedBodies[id]!.trim());
        expect(section.markdown, startsWith('## ${section.title}\n\n'));
      });
    }

    test('section titles follow the app language', () {
      expect(s.sections.map((x) => x.title), [
        'Profile', 'Faith', 'Health', 'Money', 'Family', 'Work', 'Growth', 'Body', 'Travel', 'Custom trackers',
      ]);
    });
  });

  group('privacy', () {
    test('never notes, phones, document numbers, holders, worries or free text', () async {
      await seedSummaryScenario(db);
      final text = build(await load(), profile: allProfile).compose(SummarySectionId.values.toSet());
      for (final secret in [
        'private', // every note / worry / free-text value in the fixtures
        '0790000001',
        '0790000002',
        '0790000003',
        '0791234567',
        'N1234567',
        'V-77-99',
        'Holder Person',
        'Thoughts',
      ]) {
        expect(text, isNot(contains(secret)), reason: secret);
      }
    });

    test('profile is opt-in item by item', () async {
      await seedSummaryScenario(db);
      final input = await load();
      expect(build(input).section(SummarySectionId.profile).isEmpty, isTrue);
      final onlyCity = build(input, profile: const SummaryProfileOptions(city: true)).section(SummarySectionId.profile);
      expect(onlyCity.body, '- City: Amman (JO)');
      final arCity = build(input, lang: 'ar', profile: const SummaryProfileOptions(city: true)).section(SummarySectionId.profile);
      expect(arCity.body, '- المدينة: عمّان (JO)');
    });

    test('SummaryText.clean masks identifiers but keeps dates and words', () {
      expect(SummaryText.clean('Sami 0791234567'), 'Sami •••');
      expect(SummaryText.clean('Call +962 79 123 4567 now'), 'Call +••• now');
      expect(SummaryText.clean('IBAN JO94 CBJO 0010 0000 0000 0131 0003 02'), 'IBAN •••');
      expect(SummaryText.clean('Passport ٠٧٩١٢٣٤٥٦٧'), 'Passport •••');
      expect(SummaryText.clean('Umrah 2026-10-01'), 'Umrah 2026-10-01');
      expect(SummaryText.clean('Room 12, floor 3'), 'Room 12, floor 3');
      expect(SummaryText.clean('line1\n  line2\t'), 'line1 line2');
      expect(SummaryText.clean('a | b'), 'a / b');
      expect(SummaryText.clean('# heading'), r'\# heading');
      expect(SummaryText.clean('x' * 200).runes.length, SummaryText.maxLength);
      expect(SummaryText.clean(null), '');
    });
  });

  group('compose', () {
    late AiSummary s;
    setUp(() async {
      await seedSummaryScenario(db);
      s = build(await load(), profile: allProfile);
    });

    test('includes exactly the chosen sections, in document order', () {
      final md = s.compose({SummarySectionId.travel, SummarySectionId.faith});
      expect(RegExp(r'^## ', multiLine: true).allMatches(md).length, 2);
      expect(md.indexOf('## Faith'), lessThan(md.indexOf('## Travel')));
      expect(md, isNot(contains('## Health')));
      expect(md, startsWith('# Madar summary — 2026-09-30\n\n'));
      expect(md, endsWith('by 2026-10-01\n\n### Hifz\n- items: 3 · new: 1 · due today: 1\n- Last 30 days — reviews: 2 · average grade: 4.5/5\n\n## Travel\n\n${expectedBodies[SummarySectionId.travel]!.trim()}\n'));
    });

    test('empty sections never appear even when chosen', () {
      final sparse = build(SummaryInput(now: dataTestNow));
      expect(sparse.selected(SummarySectionId.values.toSet()), isEmpty);
      expect(s.selected(SummarySectionId.values.toSet()), hasLength(SummarySectionId.values.length));
    });

    test('is deterministic', () async {
      final again = build(await load(), profile: allProfile);
      expect(again.compose(SummarySectionId.values.toSet()), s.compose(SummarySectionId.values.toSet()));
    });

    test('size estimates', () {
      final md = s.compose(AiSummaryOptions.defaultIncluded);
      expect(AiSummary.byteSize(md), greaterThan(md.length)); // non-ASCII bullets and dashes
      expect(AiSummary.estimateTokens('abcd' * 10), 10);
      expect(AiSummary.estimateTokens('عربي'), 2);
      expect(AiSummary.estimateTokens(''), 0);
    });

    test('Arabic headings, Western digits and ISO dates', () async {
      final text = build(await load(), lang: 'ar', profile: allProfile).compose(SummarySectionId.values.toSet());
      expect(text, contains('## الصحة'));
      expect(text, contains('## المال'));
      expect(text, contains('2026-09-01'));
      expect(RegExp('[٠-٩]').hasMatch(text), isFalse);
    });
  });

  group('edge cases', () {
    test('money without a base currency lists balances without conversion', () async {
      await db.into(db.wallets).insert(WalletsCompanion.insert(name: 'Pocket', currency: 'USD', openingMilli: const Value(5000)));
      final body = build(await load()).section(SummarySectionId.money).body;
      expect(body, '### Wallets\n| Wallet | Balance |\n| --- | --- |\n| Pocket | 5.00 USD |');
    });

    test('labs older than 12 months are left out; long lists are capped', () async {
      await db.batch((b) {
        for (var i = 0; i < 30; i++) {
          b.insert(db.labTests, LabTestsCompanion.insert(id: Value('t$i'), name: 'Test ${i.toString().padLeft(2, '0')}'));
          b.insert(db.labReadings, LabReadingsCompanion.insert(testId: 't$i', date: DateTime(2026, 9, 1), value: Value(i.toDouble())));
        }
        b.insert(db.labTests, LabTestsCompanion.insert(id: const Value('old'), name: 'Ancient'));
        b.insert(db.labReadings, LabReadingsCompanion.insert(testId: 'old', date: DateTime(2025, 9, 1), value: const Value(1)));
      });
      final body = build(await load()).section(SummarySectionId.health).body;
      expect(body, isNot(contains('Ancient')));
      expect(RegExp(r'^\| Test \d\d ', multiLine: true).allMatches(body).length, 25);
      expect(body, endsWith('\n\n- not shown: 5'));
    });

    test('faith with only hifz data', () async {
      await db.into(db.hifzItems).insert(HifzItemsCompanion.insert(surah: const Value(1)));
      final body = build(await load()).section(SummarySectionId.faith).body;
      expect(body, '### Hifz\n- items: 1 · new: 1 · due today: 0');
    });

    test('family with nobody on a rhythm', () async {
      await db.into(db.people).insert(PeopleCompanion.insert(name: 'Aunt', phone: const Value('0799999999')));
      final body = build(await load()).section(SummarySectionId.family).body;
      expect(body, '- 1 person, no contact rhythm set');
    });

    test('custom modules are capped and fields without data are skipped', () async {
      await db.batch((b) {
        for (var i = 0; i < AiSummaryBuilder.maxModules + 2; i++) {
          b.insert(db.customModules, CustomModulesCompanion.insert(name: 'M${i.toString().padLeft(2, '0')}', color: 0, fields: const Value([{'id': 'f', 'label': 'N', 'type': 'number'}])));
        }
      });
      final body = build(await load()).section(SummarySectionId.custom).body;
      expect('### M'.allMatches(body).length, AiSummaryBuilder.maxModules);
      expect(body, endsWith('- not shown: 2'));
      expect(body, isNot(contains('N:')));
    });

    test('a finished trip and an expired past trip are not upcoming', () async {
      await db.batch((b) {
        b.insert(db.trips, TripsCompanion.insert(destination: 'Done', status: const Value(TripStatus.done)));
        b.insert(db.trips, TripsCompanion.insert(destination: 'Past', endDate: Value(DateTime(2026, 9, 29))));
      });
      expect(build(await load()).section(SummarySectionId.travel).isEmpty, isTrue);
    });
  });

  group('options', () {
    test('JSON round trip and defaults', () {
      const o = AiSummaryOptions(
        included: {SummarySectionId.profile, SummarySectionId.money},
        profile: SummaryProfileOptions(city: true, aboutMe: 'hi'),
      );
      expect(AiSummaryOptions.fromJson(o.toJson()), o);
      expect(AiSummaryOptions.fromJson(null), const AiSummaryOptions());
      expect(AiSummaryOptions.fromJson('junk'), const AiSummaryOptions());
      expect(const AiSummaryOptions().included, isNot(contains(SummarySectionId.profile)));
      expect(const AiSummaryOptions().toggle(SummarySectionId.health, false).included, isNot(contains(SummarySectionId.health)));
      expect(const AiSummaryOptions().toggle(SummarySectionId.profile, true).included, contains(SummarySectionId.profile));
    });

    test('are stored in the encrypted database', () async {
      final repo = DataExportRepository(db, useIsolate: false);
      expect(await repo.summaryOptions(), const AiSummaryOptions());
      const o = AiSummaryOptions(included: {SummarySectionId.work}, profile: SummaryProfileOptions(language: true));
      await repo.saveSummaryOptions(o);
      expect(await repo.summaryOptions(), o);
    });
  });
}
