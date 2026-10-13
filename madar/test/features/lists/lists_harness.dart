// Test harness for the list screens: the real theme, localisations, digit
// scope, motion scope and celebration overlay over an in-memory database,
// silent sound and recording haptics, with a frozen clock.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/lists/lists.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Tuesday 13 Oct 2026, 18:30 – after work, before the shop closes.
final DateTime listsTestNow = DateTime(2026, 10, 13, 18, 30);

/// The envelope and the trip the fixtures hang lists on.
const ListHost listsEnvelope = ListHost(ListHost.budgetItems, 'food');
const ListHost listsTrip = ListHost(ListHost.trips, 'trip-1');

class ListsTestEnv {
  ListsTestEnv(this.db, this.now);

  final MadarDatabase db;
  final DateTime now;
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
  ListService get service => ListService(repos, clock: () => now);
}

/// What the fixtures put in the database.
enum ListsSeed {
  /// Nothing but the envelope and the wallet (a fresh install).
  empty,

  /// A list he just made, with nothing on it yet.
  newList,

  /// «أغراض البقالة» with four items, nothing ticked yet.
  shopping,

  /// The same list with three of the four ticked (in the shop).
  shopped,

  /// The same list, its ticked part already posted as one expense.
  posted,

  /// Two lists on the envelope (the host screen).
  twoLists,

  /// A trip with a packing list: ☐ جواز ☐ شاحن ☐ دوا.
  trip,
}

/// Fills [db] for [seed] and returns the list the screens open.
Future<String?> seedLists(MadarDatabase db, ListsSeed seed, {DateTime? now}) async {
  final at = now ?? listsTestNow;
  final repos = Repositories(db);
  final service = ListService(repos, clock: () => at);
  await repos.budgetItems.insert(
    BudgetItemsCompanion.insert(id: const Value('food'), name: 'بقالة', amountMilli: const Value(200000)),
  );
  await repos.wallets.insert(WalletsCompanion.insert(id: const Value('cash'), name: 'كاش', currency: 'JOD'));

  if (seed == ListsSeed.empty) return null;

  if (seed == ListsSeed.newList) {
    final (row, _) = await service.addList(listsEnvelope, const ListDraft(name: 'أغراض البقالة', currency: 'JOD'));
    return row.id;
  }

  if (seed == ListsSeed.trip) {
    await repos.trips.insert(
      TripsCompanion.insert(
        id: const Value('trip-1'),
        destination: 'عمّان',
        startDate: Value(DateTime(at.year, at.month, at.day + 20)),
        endDate: Value(DateTime(at.year, at.month, at.day + 27)),
      ),
    );
    final (row, _) = await service.addList(listsTrip, const ListDraft(name: 'شنطة السفر'));
    await service.addItems(row.id, ['جواز', 'شاحن', 'دوا', 'عبّاية الصلاة']);
    final items = await service.itemRows(row.id);
    await service.setDone(items.first, true);
    return row.id;
  }

  final (row, _) = await service.addList(listsEnvelope, const ListDraft(name: 'أغراض البقالة', currency: 'JOD'));
  await service.addItem(row.id, const ListItemDraft(title: 'رز', quantity: 2, unit: 'كيلو', priceMilli: 1500));
  await service.addItem(row.id, const ListItemDraft(title: 'زيت', priceMilli: 2500));
  await service.addItem(row.id, const ListItemDraft(title: 'لبن', quantity: 2, priceMilli: 1250));
  await service.addItem(row.id, const ListItemDraft(title: 'خبز عربي'));

  if (seed == ListsSeed.twoLists) {
    final (second, _) = await service.addList(listsEnvelope, const ListDraft(name: 'خضرة وفواكه', currency: 'JOD'));
    await service.addItem(second.id, const ListItemDraft(title: 'بندورة', quantity: 1, unit: 'كيلو', priceMilli: 900));
    await service.addItem(second.id, const ListItemDraft(title: 'خيار', priceMilli: 700));
    final greens = await service.itemRows(second.id);
    await service.setDone(greens.first, true);
  }

  if (seed == ListsSeed.shopped || seed == ListsSeed.posted) {
    for (final item in await service.itemRows(row.id)) {
      if (item.title != 'خبز عربي') await service.setDone(item, true);
    }
  }
  if (seed == ListsSeed.posted) {
    await service.claimPost(row.id, amountMilli: 8000, itemCount: 3, at: at, txId: 'tx-posted');
  }
  return row.id;
}

/// The app around [home] (no router: the screens are pumped directly).
Future<(Widget, ListsTestEnv)> buildListsApp(
  WidgetTester tester, {
  required Widget Function(String? listId) home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  ListsSeed seed = ListsSeed.shopping,
  double textScale = 1,
  bool reducedMotion = false,
  List<Override> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode);
  final listId = await tester.runAsync(() => seedLists(db, seed));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final env = ListsTestEnv(db, listsTestNow);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => listsTestNow),
      appSettingsProvider.overrideWith(() => _FixedSettings(AppSettings(languageCode: locale.languageCode))),
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
          home: home(listId),
        );
      },
    ),
  );
  return (app, env);
}

class _FixedSettings extends AppSettingsController {
  _FixedSettings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;
}

/// [buildListsApp] + pump on a phone-sized surface.
Future<ListsTestEnv> pumpListsApp(
  WidgetTester tester, {
  required Widget Function(String? listId) home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  ListsSeed seed = ListsSeed.shopping,
  double textScale = 1,
  bool reducedMotion = false,
  List<Override> overrides = const [],
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildListsApp(
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
  await listFrames(tester, n: 16);
  return env;
}

/// Pumps [n] frames, letting database work in between (deliberately not
/// `pumpAndSettle`: the empty states' illustrations and the glass sheen
/// loop for ever, and an undo toast counts down for five seconds).
Future<void> listFrames(WidgetTester tester, {int n = 10, Duration step = const Duration(milliseconds: 60)}) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(step);
  }
}
