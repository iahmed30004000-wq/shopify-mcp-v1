// Shared fixtures of the budget tests: the product spec's example budget
// (as BudgetNodes and as rows in a test database), an app shell around a
// budget widget and a few expenses.
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/money/budget/budget.dart';

/// A seeded in-memory database opened outside the fake-async zone (like
/// `test/helpers/test_app.dart`, without pulling in the whole app).
Future<MadarDatabase> openBudgetDatabase(WidgetTester tester, {bool seed = true}) async {
  final db = MadarDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    seed: seed ? const SeedOptions() : null,
  );
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  addTearDown(() => tester.runAsync(db.close));
  return db;
}

/// The fixed "today" of the budget tests.
final DateTime budgetToday = DateTime(2026, 9, 29, 10);

/// The spec example: Home food 200 → proteins 100, spices 20, treats 30,
/// fruit & vegetables 50; car fuel 100; emergency 30; allowance 5 / week.
List<BudgetNode> specNodes() => const [
  BudgetNode(id: 'food', name: 'Home food', amountMilli: 200000, sortOrder: 1),
  BudgetNode(id: 'prot', parentId: 'food', name: 'Proteins', amountMilli: 100000, sortOrder: 2),
  BudgetNode(id: 'spice', parentId: 'food', name: 'Spices', amountMilli: 20000, sortOrder: 3),
  BudgetNode(id: 'treat', parentId: 'food', name: 'Treats', amountMilli: 30000, sortOrder: 4),
  BudgetNode(id: 'fv', parentId: 'food', name: 'Fruit & vegetables', amountMilli: 50000, sortOrder: 5),
  BudgetNode(id: 'fuel', name: 'Car fuel', amountMilli: 100000, sortOrder: 6),
  BudgetNode(id: 'emerg', name: 'Emergency', amountMilli: 30000, sortOrder: 7),
  BudgetNode(id: 'wife', name: "Wife's allowance", amountMilli: 5000, period: BudgetPeriod.weekly, sortOrder: 8),
];

const specSettings = BudgetSettings(ratesToBase: {'USD': 0.709, 'EGP': 0.0145});

BudgetMath specMath([List<BudgetNode>? nodes]) => BudgetMath(nodes ?? specNodes(), settings: specSettings);

/// Arabic names of the same budget (for Arabic screenshots).
const specNamesAr = {
  'food': 'طعام البيت',
  'prot': 'بروتينات',
  'spice': 'بهارات',
  'treat': 'حلويات وتسالي',
  'fv': 'خضار وفواكه',
  'fuel': 'بنزين السيارة',
  'emerg': 'طوارئ',
  'wife': 'مصروف الزوجة',
};

/// Writes [nodes] as budget item rows (keeping their ids and order).
Future<void> insertNodes(Repositories repos, List<BudgetNode> nodes, {Map<String, String>? names}) async {
  for (final n in nodes) {
    await repos.budgetItems.insert(
      BudgetItemsCompanion.insert(
        id: Value(n.id),
        parentId: Value(n.parentId),
        name: names?[n.id] ?? n.name,
        mode: Value(n.mode),
        amountMilli: Value(n.amountMilli),
        percent: Value(n.percent),
        percentOf: Value(n.percentOf),
        period: Value(n.period),
        currency: Value(n.currency),
      ),
    );
  }
}

/// A JOD wallet (the seeded base) and a USD one.
Future<void> insertWallets(Repositories repos) async {
  await repos.wallets.insert(WalletsCompanion.insert(id: const Value('cash'), name: 'Cash', currency: 'JOD'));
  await repos.wallets.insert(WalletsCompanion.insert(id: const Value('usd'), name: 'Card', currency: 'USD'));
}

Future<void> addExpense(
  Repositories repos, {
  required String? item,
  required int milli,
  required DateTime date,
  String wallet = 'cash',
  TxKind kind = TxKind.expense,
}) => repos.transactions.insert(
  TransactionsCompanion.insert(
    walletId: wallet,
    kind: kind,
    amountMilli: milli,
    date: DateTime(date.year, date.month, date.day),
    budgetItemId: Value(item),
  ),
);

/// Expenses of September 2026 (and a few earlier months) against the spec
/// budget: Proteins 112.500 (over), Spices 18.250 (near), Car fuel 64.000,
/// Allowance 17.000, and 19.99 USD outside the budget.
Future<void> seedSpending(Repositories repos) async {
  await insertWallets(repos);
  final d = DateTime(2026, 9, 1);
  DateTime day(int n) => DateTime(d.year, d.month, n);
  await addExpense(repos, item: 'prot', milli: 42750, date: day(2));
  await addExpense(repos, item: 'prot', milli: 38250, date: day(12));
  await addExpense(repos, item: 'prot', milli: 31500, date: day(25));
  await addExpense(repos, item: 'spice', milli: 18250, date: day(8));
  await addExpense(repos, item: 'treat', milli: 9500, date: day(19));
  await addExpense(repos, item: 'fv', milli: 22400, date: day(15));
  await addExpense(repos, item: 'fuel', milli: 40000, date: day(3));
  await addExpense(repos, item: 'fuel', milli: 24000, date: day(21));
  await addExpense(repos, item: 'wife', milli: 5000, date: day(5));
  await addExpense(repos, item: 'wife', milli: 5000, date: day(12));
  await addExpense(repos, item: 'wife', milli: 5000, date: day(19));
  await addExpense(repos, item: 'wife', milli: 2000, date: day(27));
  await addExpense(repos, item: null, milli: 19990, date: day(4), wallet: 'usd');
  // Earlier months.
  for (final (m, food, fuel) in [
    (4, 176000, 91000),
    (5, 214500, 88000),
    (6, 190250, 104000),
    (7, 181000, 97500),
    (8, 205750, 84000),
  ]) {
    await addExpense(repos, item: 'prot', milli: food ~/ 2, date: DateTime(2026, m, 6));
    await addExpense(repos, item: 'fv', milli: food - food ~/ 2, date: DateTime(2026, m, 16));
    await addExpense(repos, item: 'fuel', milli: fuel, date: DateTime(2026, m, 10));
    await addExpense(repos, item: 'wife', milli: 20000, date: DateTime(2026, m, 20));
  }
  // Income never counts.
  await addExpense(repos, item: 'prot', milli: 500000, date: day(1), kind: TxKind.income);
}

/// Overrides that pin the budget screens to [db] and [now].
List<Override> budgetOverrides({required MadarDatabase db, DateTime? now}) {
  final at = now ?? budgetToday;
  return [databaseProvider.overrideWithValue(db), budgetClockProvider.overrideWithValue(() => at)];
}

/// A MaterialApp like the real one around [home].
Widget budgetTestApp({
  required Widget home,
  required List<Override> overrides,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  bool reducedMotion = false,
  DigitStyle digits = DigitStyle.auto,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMadarTheme(theme, arabic: locale.languageCode == 'ar'),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MadarFormatScope(
        digits: digits,
        child: MotionScope(
          reduced: reducedMotion,
          child: CelebrationOverlay(child: child!),
        ),
      ),
      home: home,
    ),
  );
}

/// Records haptics (the app's own recorder lives in test_app.dart, which
/// pulls in the whole app).
class BudgetHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

/// Installs silent, recording feedback for [Fx]; returns the sound log.
({SilentSoundService sound, BudgetHaptics haptics}) installBudgetFx() {
  final sound = SilentSoundService();
  final haptics = BudgetHaptics();
  Fx.install(FeedbackService(sound, haptics));
  return (sound: sound, haptics: haptics);
}
