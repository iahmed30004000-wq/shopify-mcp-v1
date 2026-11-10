// Harness for «السفرة»'s screens: the real app (router, gates, app lock)
// over an in-memory database seeded with made-up kitchen words, a frozen
// day, a temp folder for the dish photos and a scripted image picker.
//
// Nothing in here is a real recipe of hers – the app ships none.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/sufra/sufra.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import '../lock/lock_test_utils.dart';

/// Wednesday 14 Oct 2026, 18:30 – after work, before dinner.
final DateTime sufraNow = DateTime(2026, 10, 14, 18, 30);
final DateTime sufraToday = DateTime(2026, 10, 14);

/// What the fixtures put in the kitchen.
enum SufraSeed {
  /// A fresh install: the world exists, the kitchen is empty.
  empty,

  /// Only the house: finished, past its date, low, and one date coming up.
  house,

  /// The house plus «مجدرة», which she can cook right now.
  cookNow,

  /// The house plus «ملوخية», one known amount away.
  nearly,

  /// A dish that asks for cups of something the house keeps in kilos.
  unknownUnit,

  /// A dish that asks for an amount of something she never counted.
  unknownAmount,

  /// A dish whose word could be either of two things in the house.
  ambiguous,

  /// «مجدرة», cookable, but cooked two days ago.
  held,

  /// An allergy on something «مجدرة» has, and an «أبعد عنه» on «مقلوبة».
  rules,

  /// Everything at once (the screenshots).
  full,
}

/// The ids the tests reach for.
const String riceId = 'p-rice';
const String oilId = 'p-oil';
const String milkId = 'p-milk';
const String sugarId = 'p-sugar';
const String tomatoId = 'p-tomato';
const String breadId = 'p-bread';
const String zaatarId = 'p-zaatar';
const String mujaddaraId = 'r-mujaddara';
const String mloukhiehId = 'r-mloukhieh';
const String maqloubaId = 'r-maqlouba';
const String cupsId = 'r-cups';
const String zaatarDishId = 'r-zaatar';
const String ambiguousDishId = 'r-ambiguous';

DateTime _day(int offset) => DateTime(sufraToday.year, sufraToday.month, sufraToday.day + offset);

/// Fills [db] for [seed].
Future<void> seedSufra(MadarDatabase db, SufraSeed seed) async {
  if (seed == SufraSeed.empty) return;
  final repos = Repositories(db);

  Future<void> item(
    String id,
    String name, {
    double? quantity,
    String? unit,
    String? place,
    double? lowAt,
    DateTime? expires,
    bool staple = false,
    List<String> aliases = const [],
    int sortOrder = 0,
  }) => repos.pantryItems.insert(
    PantryItemsCompanion.insert(
      id: Value(id),
      name: name,
      aliases: Value(aliases),
      quantity: Value(quantity),
      unit: Value(unit),
      place: Value(place),
      lowAt: Value(lowAt),
      expires: Value(expires),
      staple: Value(staple),
      sortOrder: Value(sortOrder),
    ),
  );

  Future<void> dish(
    String id,
    String name, {
    required List<(String, double?, String?, bool)> ingredients,
    int? servings,
    int? minutes,
    List<String> steps = const [],
    List<String> tags = const [],
    RecipeSource source = RecipeSource.mine,
    String? sourceName,
    int sortOrder = 0,
  }) async {
    await repos.recipes.insert(
      RecipesCompanion.insert(
        id: Value(id),
        name: name,
        steps: Value(steps),
        servings: Value(servings),
        minutes: Value(minutes),
        tags: Value(tags),
        source: Value(source),
        sourceName: Value(sourceName),
        sortOrder: Value(sortOrder),
      ),
    );
    var order = 0;
    for (final (iName, quantity, unit, optional) in ingredients) {
      await repos.recipeIngredients.insert(
        RecipeIngredientsCompanion.insert(
          id: Value('i-$id-$order'),
          recipeId: id,
          name: iName,
          quantity: Value(quantity),
          unit: Value(unit),
          optional: Value(optional),
          sortOrder: Value(order++),
        ),
      );
    }
  }

  // The house, in the order she added things (which is the order inside a
  // place on screen).
  final ambiguousOnly = seed == SufraSeed.ambiguous;
  if (!ambiguousOnly) {
    await item(riceId, 'رز', quantity: 2.5, unit: 'كيلو', place: 'خزانة المونة', lowAt: 1, sortOrder: 0);
  }
  await item(oilId, 'زيت', quantity: 0, unit: 'لتر', place: 'خزانة المونة', sortOrder: 1, staple: true);
  await item(milkId, 'لبن', quantity: 1, unit: 'لتر', place: 'البراد', expires: _day(-1), sortOrder: 2);
  await item(sugarId, 'سكر', quantity: 0.5, unit: 'كيلو', place: 'خزانة المونة', lowAt: 1, sortOrder: 3);
  await item(tomatoId, 'بندورة', quantity: 3, unit: 'حبة', place: 'البراد', sortOrder: 4);
  await item(breadId, 'خبز', quantity: 2, unit: 'ربطة', place: 'البراد', expires: _day(2), sortOrder: 5);

  switch (seed) {
    case SufraSeed.empty:
    case SufraSeed.house:
      break;
    case SufraSeed.cookNow:
      await dish(
        mujaddaraId,
        'مجدرة',
        servings: 4,
        minutes: 30,
        steps: const ['سخّني الزيت', 'ضيفي الرز'],
        tags: const ['سهلة'],
        ingredients: const [('رز', 1.0, 'كيلو', false), ('بندورة', 2.0, 'حبة', false)],
      );
    case SufraSeed.nearly:
      await dish(
        mloukhiehId,
        'ملوخية',
        servings: 5,
        minutes: 45,
        ingredients: const [('رز', 1.0, 'كيلو', false), ('لحمة', 0.5, 'كيلو', false)],
      );
    case SufraSeed.unknownUnit:
      await dish(cupsId, 'رز بحليب', servings: 4, ingredients: const [('رز', 2.0, 'كوب', false)]);
    case SufraSeed.unknownAmount:
      await item(zaatarId, 'زعتر', place: 'خزانة المونة', sortOrder: 6);
      await dish(zaatarDishId, 'مناقيش', servings: 4, ingredients: const [('زعتر', 2.0, 'ملعقة', false)]);
    case SufraSeed.ambiguous:
      await item('p-rice-basmati', 'رز بسمتي', quantity: 2, unit: 'كيلو', place: 'خزانة المونة', sortOrder: 6);
      await item('p-rice-egypt', 'رز مصري', quantity: 1, unit: 'كيلو', place: 'خزانة المونة', sortOrder: 7);
      await dish(ambiguousDishId, 'رز بسيط', servings: 4, ingredients: const [('رز', 1.0, 'كيلو', false)]);
    case SufraSeed.held:
      await dish(
        mujaddaraId,
        'مجدرة',
        servings: 4,
        minutes: 30,
        ingredients: const [('رز', 1.0, 'كيلو', false), ('بندورة', 2.0, 'حبة', false)],
      );
      await repos.cookedMeals.insert(
        CookedMealsCompanion.insert(
          id: const Value('c-1'),
          recipeId: const Value(mujaddaraId),
          name: 'مجدرة',
          day: _day(-2),
          servings: const Value(4),
        ),
      );
    case SufraSeed.rules:
      await dish(
        mujaddaraId,
        'مجدرة',
        servings: 4,
        minutes: 30,
        ingredients: const [('رز', 1.0, 'كيلو', false), ('بندورة', 2.0, 'حبة', false)],
      );
      await dish(
        maqloubaId,
        'مقلوبة',
        servings: 4,
        minutes: 60,
        sortOrder: 1,
        ingredients: const [('رز', 1.0, 'كيلو', false)],
      );
      await repos.kitchenRules.insert(
        KitchenRulesCompanion.insert(
          id: const Value('k-allergy'),
          kind: const Value(KitchenRuleKind.allergy),
          term: 'بندورة',
          who: const Value('أحمد'),
          sortOrder: const Value(0),
        ),
      );
      await repos.kitchenRules.insert(
        KitchenRulesCompanion.insert(
          id: const Value('k-avoid'),
          kind: const Value(KitchenRuleKind.avoid),
          term: 'رز',
          sortOrder: const Value(1),
        ),
      );
    case SufraSeed.full:
      await item(zaatarId, 'زعتر', place: 'خزانة المونة', sortOrder: 6);
      await dish(
        mujaddaraId,
        'مجدرة',
        servings: 4,
        minutes: 30,
        steps: const ['سخّني الزيت', 'ضيفي الرز والبندورة', 'اتركيها عشر دقايق'],
        tags: const ['سهلة'],
        ingredients: const [('رز', 1.0, 'كيلو', false), ('بندورة', 2.0, 'حبة', false)],
      );
      await dish(
        mloukhiehId,
        'ملوخية',
        servings: 5,
        minutes: 45,
        sortOrder: 1,
        source: RecipeSource.imported,
        sourceName: 'خالتي',
        ingredients: const [('رز', 1.0, 'كيلو', false), ('لحمة', 0.5, 'كيلو', false)],
      );
      await dish(
        cupsId,
        'رز بحليب',
        servings: 4,
        sortOrder: 2,
        ingredients: const [('رز', 2.0, 'كوب', false), ('لبن', 1.0, 'لتر', false)],
      );
      await dish(zaatarDishId, 'مناقيش', servings: 4, sortOrder: 3, ingredients: const [('زعتر', 2.0, 'ملعقة', false)]);
  }
}

/// An image picker the tests drive: a PNG by default, nothing when
/// [picked] is null.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.picked = 'dish.png', this.bytes});

  /// The file name the picker reports (null = she closed it).
  String? picked;

  /// What the file holds (a tiny PNG header by default).
  List<int>? bytes;
  int picks = 0;

  @override
  Future<PickedPhoto?> pick() async {
    picks++;
    final name = picked;
    if (name == null) return null;
    return PickedPhoto(
      name: name,
      read: () async => Uint8List.fromList(bytes ?? const [137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]),
    );
  }
}

/// The photo store over a temp folder plus [picker].
({List<Override> overrides, Directory folder, FakePhotoPicker picker}) photoStore({FakePhotoPicker? picker}) {
  final dir = Directory.systemTemp.createTempSync('madar_sufra_photos_');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  final p = picker ?? FakePhotoPicker();
  return (
    overrides: [recipePhotosProvider.overrideWithValue(RecipePhotos.at(dir, picker: p, random: Random(7)))],
    folder: dir,
    picker: p,
  );
}

/// The whole app at [location] with [seed] in the kitchen.
Future<TestApp> pumpSufra(
  WidgetTester tester, {
  required String location,
  SufraSeed seed = SufraSeed.full,
  String lang = 'ar',
  List<Override> overrides = const [],
  int frames = 24,
}) async {
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang),
    initialLocation: location,
    now: sufraNow,
    beforePump: (db) => seedSufra(db, seed),
    overrides: [...LockFixture.empty().overrides, ...overrides],
    settle: false,
  );
  // Every test leaves the toasts counted down and the frames drained, so
  // the next one in the same process never inherits a pending timer.
  addTearDown(() async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 60));
  });
  await sufraFrames(tester, n: frames);
  return app;
}

/// Pumps [n] frames, letting the database work in between (deliberately
/// not `pumpAndSettle`: the empty states' illustrations and the glass
/// sheen loop for ever, and an undo toast counts down for five seconds).
Future<void> sufraFrames(WidgetTester tester, {int n = 16, Duration step = const Duration(milliseconds: 60)}) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(step);
  }
}

/// Lets an undo toast count all the way down (five seconds) so a pending
/// timer never leaks into the next test.
Future<void> letToastsExpire(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await sufraFrames(tester, n: 4);
}

// ---------------------------------------------------------- one screen only
//
// The screenshots (and the layout checks) pump one kitchen screen on its
// own, over the same database, theme, digits and motion the app uses – no
// router, so a screen can be captured without the orbit flying in
// underneath it.

/// The app around [home]: the real theme, localisations, digit scope and
/// motion scope over an in-memory database with [seed] in the kitchen.
Future<(Widget, MadarDatabase)> buildSufraApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  SufraSeed seed = SufraSeed.full,
  double textScale = 1,
  bool reducedMotion = false,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  await tester.runAsync(() => seedSufra(db, seed));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => sufraNow),
      appSettingsProvider.overrideWith(() => FixedSufraSettings(AppSettings(languageCode: locale.languageCode))),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMadarTheme(theme, arabic: arabic),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: textScale,
        maxScaleFactor: textScale,
        child: MadarFormatScope(
          digits: DigitStyle.auto,
          child: MotionScope(
            reduced: reducedMotion,
            child: CelebrationOverlay(child: child!),
          ),
        ),
      ),
      home: home,
    ),
  );
  return (app, db);
}

class FixedSufraSettings extends AppSettingsController {
  FixedSufraSettings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;
}

/// [buildSufraApp] + pump on a phone-sized surface.
Future<MadarDatabase> pumpSufraScreen(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  SufraSeed seed = SufraSeed.full,
  double textScale = 1,
  bool reducedMotion = false,
  List<Override> overrides = const [],
}) async {
  usePhoneSurface(tester);
  final (app, db) = await buildSufraApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    seed: seed,
    textScale: textScale,
    reducedMotion: reducedMotion,
    overrides: overrides,
  );
  await tester.pumpWidget(app);
  await sufraFrames(tester, n: 16);
  return db;
}
