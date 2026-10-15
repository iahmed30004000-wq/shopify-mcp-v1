// Builds the global search UI for widget and screenshot tests: a seeded
// in-memory database with realistic records, the index inline (no isolate
// under fake async), a fixed clock, the real Quran text from assets/, and
// silent recording sound + haptics.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/quran/quran.dart' show quranStoreProvider;
import 'package:madar/features/search/search.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import '../quran/quran_test_data.dart';

/// Wednesday 30 September 2026, 10:00.
final DateTime searchTestNow = DateTime(2026, 9, 30, 10);

class SearchTestEnv {
  SearchTestEnv(this.db, this.haptics);

  final MadarDatabase db;
  final RecordingHaptics haptics;
  final List<SearchDoc> opened = [];
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

/// Realistic records across the planets, in [language].
Future<void> seedSearchData(MadarDatabase db, {String language = 'ar'}) async {
  final ar = language == 'ar';
  final r = Repositories(db);
  final today = DateTime(searchTestNow.year, searchTestNow.month, searchTestNow.day);
  await r.tasks.insert(
    TasksCompanion.insert(
      title: ar ? 'موعد مع الطبيب لمراجعة التحاليل' : 'Doctor appointment to review the lab results',
      window: const Value(PrayerWindow.asr),
      date: Value(today),
      notes: Value(ar ? 'أخذ ملف التحاليل السابقة ونتائج فيتامين د' : 'Bring the previous lab file and the vitamin D results'),
      planetKey: const Value('health'),
    ),
  );
  await r.tasks.insert(
    TasksCompanion.insert(
      title: ar ? 'شراء دواء الضغط من الصيدلية' : 'Buy blood pressure medicine at the pharmacy',
      window: const Value(PrayerWindow.dhuhr),
      date: Value(today),
    ),
  );
  await r.tasks.insert(
    TasksCompanion.insert(
      title: ar ? 'الاتصال بأمي بعد المغرب' : 'Call mum after Maghrib',
      window: const Value(PrayerWindow.maghrib),
      date: Value(today.subtract(const Duration(days: 1))),
      planetKey: const Value('family'),
      done: const Value(true),
    ),
  );
  await r.appointments.insert(
    AppointmentsCompanion.insert(
      title: ar ? 'مراجعة طبيب القلب' : 'Cardiologist follow-up',
      doctor: Value(ar ? 'د. سامر الخطيب' : 'Dr. Samer Khatib'),
      place: Value(ar ? 'المستشفى التخصصي' : 'Specialty Hospital'),
      at: today.add(const Duration(days: 3, hours: 10)),
      notes: Value(ar ? 'إحضار نتائج تحليل الدم وقائمة الأدوية' : 'Bring the blood test results and the medication list'),
    ),
  );
  final med = await r.medications.insert(
    MedicationsCompanion.insert(
      name: ar ? 'دواء الضغط' : 'Blood pressure tablet',
      dose: Value(ar ? '٥ ملغ' : '5 mg'),
      times: const Value(['08:00']),
      notes: Value(ar ? 'بعد الإفطار مع كوب ماء' : 'After breakfast with a glass of water'),
    ),
  );
  await r.doctorQuestions.insert(
    DoctorQuestionsCompanion.insert(question: ar ? 'هل أستمر على جرعة فيتامين د نفسها؟' : 'Should I keep the same vitamin D dose?'),
  );
  await r.medDoses.insert(
    MedDosesCompanion.insert(
      medicationId: med.id,
      status: DoseStatus.taken,
      takenAt: Value(today.subtract(const Duration(days: 2))),
      note: Value(ar ? 'دوخة خفيفة بعد الجرعة' : 'Slight dizziness after the dose'),
    ),
  );
  await r.people.insert(
    PeopleCompanion.insert(
      name: ar ? 'أم أحمد' : 'Umm Ahmad',
      relation: Value(ar ? 'الجارة' : 'Neighbour'),
      notes: Value(ar ? 'تحب الزيارة يوم الجمعة بعد العصر' : 'Likes a visit on Friday after Asr'),
      phone: const Value('+962790000000'),
    ),
  );
  final wallet = await r.wallets.insert(WalletsCompanion.insert(name: ar ? 'المحفظة النقدية' : 'Cash', currency: 'JOD'));
  await r.transactions.insert(
    TransactionsCompanion.insert(
      walletId: wallet.id,
      kind: TxKind.expense,
      amountMilli: 7500,
      date: today.subtract(const Duration(days: 1)),
      note: Value(ar ? 'دواء الضغط من الصيدلية' : 'Blood pressure medicine from the pharmacy'),
      tags: Value([ar ? 'صحة' : 'health']),
    ),
  );
  await r.transactions.insert(
    TransactionsCompanion.insert(
      walletId: wallet.id,
      kind: TxKind.income,
      amountMilli: 850000,
      date: DateTime(2026, 9, 1),
      note: Value(ar ? 'راتب أيلول' : 'September salary'),
    ),
  );
  final board = await r.boards.insert(BoardsCompanion.insert(name: ar ? 'عيادة الأسنان – موقع' : 'Dental clinic website'));
  await r.boardCards.insert(
    BoardCardsCompanion.insert(
      boardId: board.id,
      title: ar ? 'صفحة حجز موعد مع الطبيب' : 'Doctor appointment booking page',
      columnId: const Value('doing'),
      dueDate: Value(today.add(const Duration(days: 12))),
    ),
  );
  await r.trips.insert(
    TripsCompanion.insert(
      destination: ar ? 'إسطنبول' : 'Istanbul',
      country: Value(ar ? 'تركيا' : 'Türkiye'),
      startDate: Value(DateTime(2026, 11, 14)),
      notes: Value(ar ? 'حجز فندق قريب من المستشفى' : 'Book a hotel near the hospital'),
    ),
  );
  await r.travelDocuments.insert(
    TravelDocumentsCompanion.insert(name: ar ? 'جواز السفر' : 'Passport', number: const Value('N1234567')),
  );
  final module = await r.customModules.insert(
    CustomModulesCompanion.insert(
      name: ar ? 'سجل القراءة' : 'Reading log',
      icon: const Value('book'),
      color: 0xFF4CC96B,
      planetKey: const Value('growth'),
      fields: Value([
        {'id': 'f1', 'label': ar ? 'الكتاب' : 'Book', 'type': 'text'},
        {'id': 'f2', 'label': ar ? 'الصفحات' : 'Pages', 'type': 'number', 'unit': ar ? 'صفحة' : 'p'},
      ]),
    ),
  );
  await r.customEntries.insert(
    CustomEntriesCompanion.insert(
      moduleId: module.id,
      at: Value(today.subtract(const Duration(days: 4))),
      entryValues: Value({'f1': ar ? 'الطبيب والمريض' : 'The doctor and the patient', 'f2': 40}),
    ),
  );
  await r.quranBookmarks.insert(
    QuranBookmarksCompanion.insert(
      surah: 2,
      ayah: 255,
      label: Value(ar ? 'آية الكرسي' : 'Ayat al-Kursi'),
      note: Value(ar ? 'للحفظ قبل النوم' : 'Memorise before sleeping'),
    ),
  );
}

Future<(Widget, SearchTestEnv)> buildSearchApp(
  WidgetTester tester, {
  Widget? home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  bool seed = true,
  List<String> recent = const [],
  SearchOpener? opener,
  bool withQuran = true,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({
    'madar.settings.v1': jsonEncode(AppSettings(languageCode: locale.languageCode, onboarded: true).toJson()),
  });
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  await tester.runAsync(() async {
    if (seed) await seedSearchData(db, language: locale.languageCode);
    if (recent.isNotEmpty) await Repositories(db).keyValues.setJson(RecentSearchesStore.key, recent);
    if (beforePump != null) await beforePump(db);
  });
  // Runs before the database closes (tear-downs run last-in first-out),
  // also when a test fails: unmounting stops the engine, so nothing is left
  // waiting on the database.
  addTearDown(() => tearDownApp(tester));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final env = SearchTestEnv(db, haptics);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      searchWorkerFactoryProvider.overrideWithValue(() async => InlineSearchWorker()),
      searchClockProvider.overrideWithValue(() => searchTestNow),
      searchDebounceProvider.overrideWithValue(const Duration(milliseconds: 50)),
      if (withQuran)
        quranStoreProvider.overrideWith((ref) => QuranTestData.store())
      else
        searchQuranAccessProvider.overrideWithValue(SearchQuranAccess.none),
      searchOpenerProvider.overrideWithValue(
        opener ??
            (context, doc) {
              env.opened.add(doc);
              return true;
            },
      ),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) {
        env.container = ProviderScope.containerOf(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildMadarTheme(theme, arabic: arabic),
          locale: locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          builder: (context, child) => MadarFormatScope(
            digits: DigitStyle.auto,
            child: MotionScope(reduced: true, child: child!),
          ),
          home: home ?? const GlobalSearchScreen(),
        );
      },
    ),
  );
  return (app, env);
}

/// [buildSearchApp] + pump on a phone-sized surface.
Future<SearchTestEnv> pumpSearchApp(
  WidgetTester tester, {
  Widget? home,
  Locale locale = const Locale('ar'),
  bool seed = true,
  List<String> recent = const [],
  SearchOpener? opener,
  bool withQuran = false,
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildSearchApp(
    tester,
    home: home,
    locale: locale,
    seed: seed,
    recent: recent,
    opener: opener,
    withQuran: withQuran,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settle(tester);
  return env;
}

/// Scrolls [finder] into view (chips sit in horizontal rows) and taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

/// Pumps enough frames for the engine (inline), debounces and entrances.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Types [text] into the search field and lets the results arrive.
Future<void> typeQuery(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await settle(tester);
}

/// Unmounts the app so the engine stops its timers.
Future<void> tearDownApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 100));
}
