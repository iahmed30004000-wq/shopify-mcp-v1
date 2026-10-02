import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/search/search.dart';

import '../../core/db/fixtures.dart';

MadarDatabase memoryDb() =>
    MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

SearchLoadContext contextFor(MadarDatabase db, {String language = 'en'}) => SearchLoadContext(
  repos: Repositories(db),
  l10n: lookupL10n(Locale(language)),
  formatter: MadarFormatter(languageCode: language),
  surahName: (s) => s == 2 ? (language == 'ar' ? 'البقرة' : 'Al-Baqarah') : null,
);

/// Every text of a record (what could ever be shown or matched).
String everything(SearchDoc d) =>
    [d.title, d.subtitle, d.body, d.refId, d.id, ...d.extra.keys, ...d.extra.values, d.groupLabel ?? ''].join('\n');

void main() {
  late MadarDatabase db;
  late Map<String, List<SearchDoc>> bySource;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    db = memoryDb();
    await populateAllTables(db);
    await Repositories(db).planets.insert(
      PlanetsCompanion.insert(
        key: 'health',
        nameAr: 'الصحة',
        nameEn: 'Health',
        color: 0xFF1FB5C9,
        archetype: PlanetArchetype.ocean,
      ),
    );
    final ctx = contextFor(db);
    bySource = {for (final s in BuiltInSearchSources.all()) s.id: (await s.load(ctx)).map((d) => d.withSource(s.id)).toList()};
  });

  tearDownAll(() => db.close());

  SearchDoc only(String source, bool Function(SearchDoc d) test) => bySource[source]!.singleWhere(test);

  test('every built-in source reads its fixture rows', () {
    // Tables whose fixture has no text worth indexing are notes-only logs:
    // their "full" row has a note and is indexed, the sparse one is not.
    for (final MapEntry(key: id, value: docs) in bySource.entries) {
      expect(docs, isNotEmpty, reason: 'source $id produced nothing');
      for (final d in docs) {
        expect(d.sourceId, id);
        expect(d.planetKey, isNotEmpty);
        expect(d.refId, isNotEmpty);
      }
    }
  });

  test('covers every table with user-written text, and none of the private ones', () {
    final tables = {for (final docs in bySource.values) for (final d in docs) d.refTable};
    expect(
      tables,
      containsAll([
        'tasks', 'prayer_logs', 'medications', 'med_courses', 'med_doses', 'conditions', 'health_alerts', //
        'lab_tests', 'lab_readings', 'appointments', 'doctor_questions', 'pain_entries', 'mood_entries',
        'habits', 'worries', 'wallets', 'transactions', 'budget_items', 'jars', 'jar_deposits', 'debts',
        'debt_payments', 'obligations', 'people', 'contact_logs', 'projects', 'project_items', 'boards',
        'board_cards', 'trips', 'trip_items', 'packing_templates', 'travel_documents', 'learning_goals',
        'goal_logs', 'exercises', 'workout_logs', 'avoid_items', 'fasting_sessions', 'custom_modules',
        'custom_entries', 'quran_bookmarks', 'hifz_items', 'wird_plans', 'planets',
      ]),
    );
    expect(tables.intersection(BuiltInSearchSources.neverIndexed), isEmpty);
  });

  group('privacy', () {
    test('travel document numbers are never indexed', () {
      final passport = only('travel_documents', (d) => d.title == 'Passport');
      expect(passport.subtitle, 'holder');
      expect(passport.body, 'n');
      for (final d in bySource['travel_documents']!) {
        expect(everything(d), isNot(contains('000')));
      }
    });

    test('phone numbers are never indexed', () {
      for (final d in bySource['people']!) {
        expect(everything(d), isNot(contains('+000')));
      }
    });

    test('key/values, reminders, activity and import archives are never read', () {
      final all = [for (final docs in bySource.values) ...docs];
      for (final d in all) {
        final text = everything(d);
        expect(text, isNot(contains('test.kv')));
        expect(text, isNot(contains('{"a":[1,2')));
        expect(text, isNot(contains('تذكير'))); // reminder title
        expect(text, isNot(contains('"raw": true'))); // import archive
        expect(text, isNot(contains('generic.json')));
      }
    });
  });

  group('records', () {
    test('tasks: title, window and done in the subtitle, notes as body, planet', () {
      final t = only('tasks', (d) => d.refId == 'task-full');
      expect(t.title, 'مهمة كاملة');
      expect(t.subtitle, 'Asr · Done');
      expect(t.body, contains('line 2'));
      expect(t.planetKey, 'work');
      expect(t.date, DateTime(2026, 9, 27));
      expect(t.extra, {'projectId': 'project-1', 'cardId': 'card-1'});
      expect(only('tasks', (d) => d.title == 'sparse').planetKey, 'work');
    });

    test('prayer logs: prayer, status and jamaah', () {
      final p = bySource['prayer_logs']!.single;
      expect(p.title, isNotEmpty);
      expect(p.date, DateTime(2026, 9, 27));
      expect(p.extra['day'], '2026-09-27');
      expect(p.planetKey, 'faith');
    });

    test('health: medications, doses with notes only, lab readings with their test', () {
      final med = only('medications', (d) => d.refId == 'med-full');
      expect(med.subtitle, '10 mg · 08:00 20:00');
      expect(med.body, 'notes\nwith water');
      final dose = bySource['med_doses']!.single; // the sparse dose has no note
      expect(dose.title, 'Generic med');
      expect(dose.body, 'n');
      expect(dose.extra, {'medicationId': 'med-full'});
      final reading = only('lab_readings', (d) => d.subtitle == 'trace');
      expect(reading.title, 'Test');
      expect(reading.extra, {'testId': 'lab-1'});
      final lab = only('lab_tests', (d) => d.refId == 'lab-1');
      expect(lab.subtitle, 'blood · 0.5–1.25 mg/dL');
      final q = only('doctor_questions', (d) => d.title == 'سؤال؟');
      expect(q.subtitle, 'Checkup');
      expect(q.body, 'جواب');
      final pain = only('pain_entries', (d) => d.body == 'n');
      expect(pain.title, 'Pain 7/10');
      expect(pain.subtitle, 'head · رقبة · sleep');
      expect(bySource['mood_entries']!.single.subtitle, 'work · sleep'); // the sparse mood has nothing to find
    });

    test('money: transactions carry amount, kind, wallets and tags', () {
      final tx = only('transactions', (d) => d.body.isNotEmpty);
      expect(tx.title, 'n');
      expect(tx.subtitle, contains('Transfer'));
      expect(tx.subtitle, contains('Cash'));
      expect(tx.subtitle, contains('Parent')); // budget category
      expect(tx.subtitle, contains('1.000'));
      expect(tx.body, '#a #ب');
      expect(tx.extra, {'walletId': 'wallet-1'});
      final plain = only('transactions', (d) => d.body.isEmpty);
      expect(plain.title, 'Expense'); // no note, no category: its kind
      final debt = only('debts', (d) => d.title == 'Someone');
      expect(debt.subtitle, startsWith('Owed to me · '));
      expect(only('budget_items', (d) => d.title == 'sparse child').subtitle, 'Parent');
      expect(bySource['jar_deposits']!.single.subtitle, startsWith('Jar · '));
    });

    test('family, work, travel, growth and body', () {
      expect(only('people', (d) => d.refId == 'person-1').subtitle, 'friend');
      final log = bySource['contact_logs']!.single;
      expect(log.title, 'Test person');
      expect(log.subtitle, 'Visit');
      final card = only('board_cards', (d) => d.refId == 'card-1');
      expect(card.subtitle, 'Board · ب · someone');
      expect(card.extra, {'boardId': 'board-1', 'columnId': 'b'});
      expect(only('project_items', (d) => d.title == 'item').subtitle, 'Project · Done');
      expect(only('project_items', (d) => d.title == 'item').planetKey, 'growth'); // its project's planet
      expect(only('trip_items', (d) => d.title == 'item').subtitle, 'Somewhere · docs');
      expect(bySource['packing_templates']!.single.body, 'a, b');
      expect(bySource['goal_logs']!.single.subtitle, 'Goal · 2.25 pages');
      expect(only('exercises', (d) => d.title == 'Exercise').subtitle, '3×12 · 17.5 · 20′');
      expect(bySource['fasting_sessions']!.single.title, 'n');
    });

    test('faith: bookmarks and hifz use sura names', () {
      final b = only('quran_bookmarks', (d) => d.title == 'آية الكرسي');
      expect(b.subtitle, 'Al-Baqarah · ayah 255');
      expect(b.extra, {'surah': '2', 'ayah': '255'});
      final hadith = only('hifz_items', (d) => d.refId == 'hifz-1');
      expect(hadith.title, 'إنما الأعمال بالنيات');
      expect(hadith.subtitle, 'Bukhari 1');
      final ayat = only('hifz_items', (d) => d.refId != 'hifz-1');
      expect(ayat.title, 'Surah 112 · 1–4');
    });

    test('planets: both names are searchable; hidden planets are left out', () {
      final p = bySource['planets']!;
      expect(p.where((d) => d.refId == 'custom_1'), isEmpty); // hidden
      final health = p.singleWhere((d) => d.refId == 'health');
      expect(health.title, 'Health');
      expect(health.subtitle, 'الصحة');
      expect(health.planetKey, 'health');
    });
  });

  group('custom modules (generic)', () {
    test('a module is its own group; entries use field labels and values', () {
      final module = only('custom_modules', (d) => d.refId == 'module-1');
      expect(module.title, 'Module');
      expect(module.subtitle, contains('Pages'));
      expect(module.group, 'module:module-1');
      expect(module.groupIcon, 'book');
      expect(module.planetKey, 'growth');
      final entry = only('custom_entries', (d) => d.body.isNotEmpty);
      expect(entry.title, 'Module'); // no text field: the module's name
      expect(entry.body, 'Pages: 12 p');
      expect(entry.group, 'module:module-1');
      expect(entry.groupLabel, 'Module');
      expect(entry.extra, {'moduleId': 'module-1'});
      expect(entry.openKey, 'custom_entries');
      final sparse = only('custom_modules', (d) => d.title == 'sparse');
      expect(sparse.planetKey, 'custom');
    });

    test('every field type is written up in the app language', () async {
      final db2 = memoryDb();
      addTearDown(db2.close);
      final repos = Repositories(db2);
      await repos.customModules.insert(
        CustomModulesCompanion.insert(
          id: const Value('m'),
          name: 'سجل القراءة',
          color: 0xFF00FF00,
          fields: const Value([
            {'id': 'f1', 'label': 'الكتاب', 'type': 'text'},
            {'id': 'f2', 'label': 'الصفحات', 'type': 'number', 'unit': 'ص'},
            {'id': 'f3', 'label': 'التاريخ', 'type': 'date'},
            {'id': 'f4', 'label': 'الوقت', 'type': 'time'},
            {'id': 'f5', 'label': 'أنهيته', 'type': 'checkbox'},
            {
              'id': 'f6',
              'label': 'النوع',
              'type': 'singleSelect',
              'options': [
                {'id': 'o1', 'label': 'رواية'},
              ],
            },
            {
              'id': 'f7',
              'label': 'الوسوم',
              'type': 'multiSelect',
              'options': [
                {'id': 'o1', 'label': 'ممتع'},
                {'id': 'o2', 'label': 'طويل'},
              ],
            },
            {'id': 'f8', 'label': 'التقييم', 'type': 'rating'},
            {'id': 'f9', 'label': 'السعر', 'type': 'currency', 'currency': 'JOD'},
            {'id': 'f10', 'label': 'مخفي', 'type': 'text', 'hidden': true},
          ]),
        ),
      );
      await repos.customEntries.insert(
        CustomEntriesCompanion.insert(
          moduleId: 'm',
          at: Value(DateTime(2026, 9, 1)),
          entryValues: const Value({
            'f1': 'ثلاثية غرناطة',
            'f2': 120,
            'f3': '2026-09-01',
            'f4': '21:30',
            'f5': true,
            'f6': 'o1',
            'f7': ['o1', 'o2'],
            'f8': 4,
            'f9': {'milli': 7500, 'currency': 'JOD'},
            'f10': 'secret-hidden-value',
          }),
          done: const Value(true),
        ),
      );
      final docs = await CustomModuleSearch.entries().load(contextFor(db2, language: 'ar'));
      final d = docs.single;
      expect(d.title, 'ثلاثية غرناطة');
      expect(d.subtitle, 'سجل القراءة، منجزة');
      expect(d.body, contains('الصفحات: ١٢٠ ص'));
      expect(d.body, contains('التاريخ: ١ سبتمبر ٢٠٢٦'));
      expect(d.body, contains('الوقت: ٢١:٣٠'));
      expect(d.body, contains('، أنهيته'));
      expect(d.body, contains('النوع: رواية'));
      expect(d.body, contains('الوسوم: ممتع، طويل'));
      expect(d.body, contains('التقييم: ★ ٤/٥'));
      expect(d.body, contains('السعر: ٧٫٥٠٠'));
      expect(d.body, isNot(contains('secret-hidden-value')));
      expect(d.planetKey, 'custom');
    });
  });

  test('Arabic context writes labels and digits in Arabic', () async {
    final ctx = contextFor(db, language: 'ar');
    final tasks = await BuiltInSearchSources.all().firstWhere((s) => s.id == 'tasks').load(ctx);
    expect(tasks.firstWhere((d) => d.refId == 'task-full').subtitle, contains('منجزة'));
    final pain = await BuiltInSearchSources.all().firstWhere((s) => s.id == 'pain_entries').load(ctx);
    expect(pain.map((d) => d.title), contains('ألم ٧/١٠'));
  });

  test('every source has a label in both languages', () {
    for (final lang in ['ar', 'en']) {
      final l = lookupL10n(Locale(lang));
      for (final s in BuiltInSearchSources.all()) {
        expect(s.label(l), isNot(startsWith('searchSource')), reason: s.id);
      }
    }
    expect(SearchLabels.builtInPlanet(lookupL10n(const Locale('en')), 'custom'), 'Custom modules');
    expect(PrayerWindow.values, isNotEmpty);
  });
}
