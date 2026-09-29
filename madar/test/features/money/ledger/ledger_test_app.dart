// Test harness for the ledger screens: an in-memory database with generic
// example data, fixed clock, recording feedback, and a MaterialApp like the
// real one (theme, locale, digit scope, motion scope, celebration overlay).
import 'package:drift/drift.dart' show DatabaseConnection, Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/money/ledger/ledger.dart';

/// "Now" in every ledger test: Tuesday 29 September 2026, 14:00.
final DateTime ledgerNow = DateTime(2026, 9, 29, 14);

class LedgerHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

/// Installs silent, recording feedback for [Fx].
({SilentSoundService sound, LedgerHaptics haptics}) installLedgerFx() {
  final sound = SilentSoundService();
  final haptics = LedgerHaptics();
  Fx.install(FeedbackService(sound, haptics));
  return (sound: sound, haptics: haptics);
}

List<Override> ledgerOverrides(MadarDatabase db, {DateTime? now}) {
  final at = now ?? ledgerNow;
  return [
    databaseProvider.overrideWithValue(db),
    ledgerClockProvider.overrideWithValue(() => at),
    ledgerActivityRecorderProvider.overrideWith((ref) {
      final repos = ref.watch(repositoriesProvider);
      return ({required kind, required refTable, required refId, required at, value, payload = const {}}) => repos
          .activity
          .log(planetKey: 'money', kind: kind, refTable: refTable, refId: refId, at: at, value: value, payload: payload)
          .then((_) {});
    }),
  ];
}

Widget ledgerTestApp({
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

/// Phone-sized test surface (logical 412×915).
void usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// An in-memory database (seeded currencies) with the example data unless
/// [data] is false. Query streams close synchronously so widget tests end
/// without pending timers. (Self-contained: the app-wide test helpers pull
/// in every feature.)
Future<MadarDatabase> ledgerDb(WidgetTester tester, {bool data = true, bool arabic = true}) async {
  final db = MadarDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
    seed: SeedOptions(languageCode: arabic ? 'ar' : 'en'),
  );
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  addTearDown(() => tester.runAsync(db.close));
  if (data) await tester.runAsync(() => seedLedgerExample(Repositories(db), arabic: arabic));
  return db;
}

/// Ids of the example data.
abstract final class Ex {
  static const cash = 'w.cash';
  static const bank = 'w.bank';
  static const usd = 'w.usd';
  static const syria = 'w.syria';
  static const egypt = 'w.egypt';
  static const libya = 'w.libya';
  static const food = 'b.food';
  static const proteins = 'b.proteins';
  static const spices = 'b.spices';
  static const treats = 'b.treats';
  static const veg = 'b.veg';
  static const fuel = 'b.fuel';
  static const emergency = 'b.emergency';
  static const allowance = 'b.allowance';
}

/// Generic example data (the spec's budget example, a few wallets across
/// currencies and five months of entries). Test-only – the app starts empty.
Future<void> seedLedgerExample(Repositories repos, {required bool arabic, DateTime? today}) async {
  final t = today ?? DateTime(ledgerNow.year, ledgerNow.month, ledgerNow.day);
  String n(String ar, String en) => arabic ? ar : en;
  Future<void> wallet(
    String id,
    String ar,
    String en,
    String currency,
    int opening,
    WalletKind kind, {
    String? icon,
    int? order,
  }) => repos.wallets.insert(
    WalletsCompanion.insert(
      id: Value(id),
      name: n(ar, en),
      currency: currency,
      openingMilli: Value(opening),
      kind: Value(kind),
      icon: Value(icon),
    ),
  );
  await wallet(Ex.cash, 'الصندوق', 'Cash', 'JOD', 180000, WalletKind.personal, icon: 'wallet');
  await wallet(Ex.bank, 'البنك', 'Bank', 'JOD', 1250000, WalletKind.personal, icon: 'coins');
  await wallet(Ex.usd, 'حساب الدولار', 'USD account', 'USD', 400000, WalletKind.personal, icon: 'globe');
  await wallet(
    Ex.syria,
    'عهدة المندوب · سوريا',
    'Courier float · Syria',
    'SYP',
    3500000000,
    WalletKind.business,
    icon: 'handshake',
  );
  await wallet(Ex.egypt, 'مبيعات مصر', 'Egypt sales', 'EGP', 25000000, WalletKind.business, icon: 'bag');
  await wallet(Ex.libya, 'مبيعات ليبيا', 'Libya sales', 'LYD', 1800000, WalletKind.business, icon: 'cart');

  Future<void> item(
    String id,
    String ar,
    String en, {
    String? parent,
    int? amount,
    BudgetPeriod period = BudgetPeriod.monthly,
    String? icon,
    int order = 0,
  }) => repos.budgetItems.insert(
    BudgetItemsCompanion.insert(
      id: Value(id),
      name: n(ar, en),
      parentId: Value(parent),
      amountMilli: Value(amount),
      period: Value(period),
      icon: Value(icon),
    ),
  );
  await item(Ex.food, 'طعام البيت', 'Home food', amount: 200000, icon: 'food');
  await item(Ex.proteins, 'بروتينات', 'Proteins', parent: Ex.food, amount: 100000);
  await item(Ex.spices, 'بهارات', 'Spices', parent: Ex.food, amount: 20000);
  await item(Ex.treats, 'حلويات', 'Treats', parent: Ex.food, amount: 30000);
  await item(Ex.veg, 'خضار وفواكه', 'Fruit & vegetables', parent: Ex.food, amount: 50000);
  await item(Ex.fuel, 'وقود السيارة', 'Car fuel', amount: 100000, icon: 'fuel');
  await item(Ex.emergency, 'طوارئ', 'Emergency', amount: 30000, icon: 'bolt');
  await item(
    Ex.allowance,
    'مصروف الزوجة',
    'Wife’s allowance',
    amount: 5000,
    period: BudgetPeriod.weekly,
    icon: 'heart',
  );
  await repos.keyValues.setJson(BudgetSettings.weeksPerMonthKey, 4);

  var clock = DateTime(t.year, t.month - 5, 1, 9);
  Future<void> tx(
    String wallet,
    TxKind kind,
    int milli,
    DateTime day, {
    String? item,
    String? noteAr,
    String? noteEn,
    List<String> tags = const [],
    String? to,
    int? toAmount,
  }) {
    clock = clock.add(const Duration(minutes: 7));
    return repos.transactions.insert(
      TransactionsCompanion.insert(
        walletId: wallet,
        kind: kind,
        amountMilli: milli,
        date: day,
        budgetItemId: Value(item),
        note: Value(noteAr == null ? null : n(noteAr, noteEn ?? noteAr)),
        tags: Value(tags),
        toWalletId: Value(to),
        toAmountMilli: Value(toAmount),
        createdAt: Value(DateTime(day.year, day.month, day.day, 8).add(Duration(minutes: clock.minute))),
      ),
    );
  }

  DateTime d(int back) => DateTime(t.year, t.month, t.day - back);
  final family = n('العائلة', 'family');
  final shop = n('المتجر', 'shop');
  // Five earlier months, lighter.
  for (var m = 5; m >= 1; m--) {
    final base = DateTime(t.year, t.month - m, 3);
    await tx(Ex.usd, TxKind.income, 900000 + m * 25000, base, noteAr: 'راتب', noteEn: 'Salary');
    await tx(Ex.usd, TxKind.transfer, 500000, DateTime(base.year, base.month, 4), to: Ex.bank, toAmount: 354500);
    await tx(
      Ex.bank,
      TxKind.transfer,
      150000,
      DateTime(base.year, base.month, 5),
      to: Ex.cash,
      noteAr: 'سحب نقدي',
      noteEn: 'Cash withdrawal',
    );
    await tx(
      Ex.cash,
      TxKind.expense,
      60000 + m * 7000,
      DateTime(base.year, base.month, 8),
      item: Ex.proteins,
      tags: [family],
    );
    await tx(Ex.cash, TxKind.expense, 42000 - m * 2000, DateTime(base.year, base.month, 12), item: Ex.veg);
    await tx(Ex.bank, TxKind.expense, 85000 + m * 3000, DateTime(base.year, base.month, 15), item: Ex.fuel);
    await tx(Ex.egypt, TxKind.income, 18000000 + m * 900000, DateTime(base.year, base.month, 20), tags: [shop]);
    await tx(
      Ex.bank,
      TxKind.expense,
      120000 + m * 11000,
      DateTime(base.year, base.month, 24),
      noteAr: 'إيجار المستودع',
      noteEn: 'Warehouse rent',
      tags: [shop],
    );
  }
  // This month, detailed.
  await tx(Ex.usd, TxKind.income, 1000000, d(27), noteAr: 'راتب', noteEn: 'Salary');
  await tx(
    Ex.usd,
    TxKind.transfer,
    300000,
    d(26),
    to: Ex.bank,
    toAmount: 212700,
    noteAr: 'تحويل للبنك',
    noteEn: 'To the bank',
  );
  await tx(
    Ex.cash,
    TxKind.expense,
    38500,
    d(20),
    item: Ex.proteins,
    noteAr: 'دجاج ولحمة',
    noteEn: 'Chicken and meat',
    tags: [family],
  );
  await tx(Ex.cash, TxKind.expense, 6250, d(18), item: Ex.spices);
  await tx(Ex.bank, TxKind.expense, 45000, d(15), item: Ex.fuel, noteAr: 'تعبئة كاملة', noteEn: 'Full tank');
  await tx(
    Ex.syria,
    TxKind.income,
    1250000000,
    d(12),
    noteAr: 'تحصيل الدفع عند الاستلام',
    noteEn: 'COD collection',
    tags: [shop],
  );
  await tx(Ex.cash, TxKind.expense, 5000, d(10), item: Ex.allowance);
  await tx(Ex.libya, TxKind.expense, 150000, d(8), noteAr: 'شحن', noteEn: 'Shipping', tags: [shop]);
  await tx(Ex.cash, TxKind.expense, 12750, d(5), item: Ex.treats, noteAr: 'كنافة', noteEn: 'Knafeh', tags: [family]);
  await tx(Ex.bank, TxKind.transfer, 60000, d(4), to: Ex.cash, noteAr: 'سحب نقدي', noteEn: 'Cash withdrawal');
  await tx(Ex.cash, TxKind.expense, 5000, d(3), item: Ex.allowance);
  await tx(Ex.cash, TxKind.adjustment, -1250, d(2), noteAr: 'فرق عد\u0651 الصندوق', noteEn: 'Cash count difference');
  await tx(
    Ex.cash,
    TxKind.expense,
    21400,
    d(1),
    item: Ex.veg,
    noteAr: 'سوق الخضار',
    noteEn: 'Vegetable market',
    tags: [family],
  );
  await tx(
    Ex.egypt,
    TxKind.income,
    21500000,
    d(1),
    noteAr: 'تسوية شركة الشحن',
    noteEn: 'Courier settlement',
    tags: [shop],
  );
  await tx(Ex.cash, TxKind.expense, 3500, d(0), noteAr: 'قهوة', noteEn: 'Coffee');
  await tx(Ex.bank, TxKind.expense, 16000, d(0), item: Ex.proteins, noteAr: 'سمك', noteEn: 'Fish', tags: [family]);
  // Rates reviewed by the user.
  await repos.currencies.setRate('SYP', 0.0000545);
}
