// The Money world's balance, moons and Neglect Radar, end to end from the
// money packages' own services (not hand-written rows): wallets written by
// the ledger orbit Money sized by their share of the balances (an overdrawn
// one looks neglected); the budget's plan vs this month's entries, a bill
// ("Paid" advances it and clears its reason) and a debt the user owes
// (repaid clears it) feed the score; the radar names the overdue debt and
// its link opens the debt's sheet; every write is logged on the Money world.
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/money/budget/budget.dart';
import 'package:madar/features/money/goals/goals.dart';
import 'package:madar/features/money/hub/money_links.dart';
import 'package:madar/features/money/ledger/ledger.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/domain/neglect_text.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';
import 'package:madar/features/orbit/domain/scene_snapshot.dart';
import 'package:madar/features/orbit/domain/score_sources.dart';
import 'package:madar/features/orbit/presentation/planet/record_open.dart';

import 'money_hub_seed.dart';

const _fsi = '\u2068', _pdi = '\u2069';
String _iso(String s) => '$_fsi$s$_pdi';

void main() {
  var now = moneyHubNow;
  final en = lookupL10n(const Locale('en'));
  final ar = lookupL10n(const Locale('ar'));
  const enFmt = MadarFormatter(languageCode: 'en');
  const arFmt = MadarFormatter();

  late MadarDatabase db;
  late Repositories repos;
  late OrbitRepository orbit;
  late MoneyHubIds ids;

  setUp(() async {
    now = moneyHubNow;
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    orbit = OrbitRepository(repos, clock: () => now);
    ids = await seedMoneyHub(db);
  });
  tearDown(() => db.close());

  Future<SceneSnapshot> snap() => orbit.snapshot(now: now, languageCode: 'en');
  Future<OrbitPlanet> money() async => (await snap()).planet('money')!;
  NeglectReason? reason(OrbitPlanet p, ReasonCode code) =>
      p.score.reasons.where((r) => r.code == code).firstOrNull;

  test('wallets orbit Money sized by their share of the balances; an overdrawn one looks neglected', () async {
    var planet = await money();
    final moons = {
      for (final m in planet.moons)
        if (m.refTable == 'wallets') m.refId: m,
    };
    expect(moons.keys.toSet(), {ids.cash, ids.bank, ids.egypt});
    // 105 + 1 570 + 290 (20 000 EGP at 0.0145) = 1 965 JOD of positive balances.
    double size(double balance) => 0.35 + 0.65 * math.sqrt(balance / 1965);
    expect(moons[ids.bank]!.size, closeTo(size(1570), 1e-6));
    expect(moons[ids.egypt]!.size, closeTo(size(290), 1e-6));
    expect(moons[ids.cash]!.size, closeTo(size(105), 1e-6));
    expect(moons[ids.bank]!.label, 'Bank');

    // 200 JOD more from cash: overdrawn (−95).
    await LedgerService(repos, clock: () => now).add(
      TxWrite(walletId: ids.cash, kind: TxKind.expense, amountMilli: 200000, date: now),
    );
    planet = await money();
    final cash = planet.moons.firstWhere((m) => m.refId == ids.cash);
    expect(cash.score, 0.15);
    expect(cash.size, 0.35);
  });

  test('the budget, the bills and the debts feed the score; paying clears their reasons', () async {
    var planet = await money();
    final s = planet.score;
    expect(s.dormant, isFalse);
    // Fuel spent 130 of 100: 200 of 300 planned JOD are on track.
    expect(s.sources[ScoreSources.budget], closeTo(200 / 300, 1e-9));
    final over = reason(planet, ReasonCode.budgetOverspent)!;
    expect((over.refTable, over.refId), ('budget_items', ids.fuel));
    expect(neglectReasonText(en, over, enFmt), '${_iso('Car fuel')} — 30% over budget');
    expect(RecordOpener.moneyTarget('${over.refTable}:${over.refId}'), const MoneyRouteTarget('/budget?tab=spending'));
    // The bill is due on 1 Oct: nothing overdue yet.
    expect(s.sources[ScoreSources.obligations], 1);
    // The debt owed to Khaled was due two days ago.
    expect(s.sources[ScoreSources.debts], 0);
    final debt = reason(planet, ReasonCode.debtOverdue)!;
    expect((debt.refTable, debt.refId), ('debts', ids.debtIOwe));
    expect(neglectReasonText(en, debt, enFmt), 'Debt to ${_iso('Khaled')} — 2 days overdue');
    expect(neglectReasonText(ar, debt, arFmt), 'دَين ${_iso('Khaled')} — تأخّر السداد يومين');

    // Repaid in full through the goals: settled, the reason leaves.
    final goals = GoalsService(repos, clock: () => now);
    await goals.addDebtPayment(ids.debtIOwe, amountMilli: 150000, walletId: ids.bank);
    planet = await money();
    expect(reason(planet, ReasonCode.debtOverdue), isNull);
    expect(planet.score.sources.containsKey(ScoreSources.debts), isFalse, reason: 'no dated debt left to owe');

    // Three days on the bill is two days overdue …
    now = DateTime(2026, 10, 3, 9);
    planet = await money();
    final bill = reason(planet, ReasonCode.obligationOverdue)!;
    expect((bill.refTable, bill.refId), ('obligations', ids.internet));
    expect(neglectReasonText(en, bill, enFmt), '${_iso('Internet')} — 2 days overdue');
    expect(planet.score.sources[ScoreSources.obligations], 0);
    // … "Paid" advances it to 1 Nov: on track again.
    await goals.payObligation(ids.internet);
    expect((await repos.obligations.byId(ids.internet))!.nextDue, DateTime(2026, 11, 1));
    planet = await money();
    expect(reason(planet, ReasonCode.obligationOverdue), isNull);
    expect(planet.score.sources[ScoreSources.obligations], 1);
  });

  test("the radar names Money's worst record and its link opens it", () async {
    Future<RadarEntry> entry() async => (await snap()).radar.where((e) => e.planetKey == 'money').single;
    // Fuel 30 % over (severity 0.7) outranks the debt two days late (0.6).
    var e = await entry();
    expect(e.reason.code, ReasonCode.budgetOverspent);
    expect(RecordOpener.moneyTarget('${e.reason.refTable}:${e.reason.refId}'), const MoneyRouteTarget('/budget?tab=spending'));

    // A plan of 150 for fuel covers the 130 spent: the debt is next.
    await BudgetRepository(repos, clock: () => now).save(
      BudgetNode(id: ids.fuel, name: 'Car fuel', amountMilli: 150000),
    );
    e = await entry();
    expect(e.reason.code, ReasonCode.debtOverdue);
    expect(e.text, 'Debt to ${_iso('Khaled')} — 2 days overdue');
    expect(RecordOpener.canOpen(e.reason.refTable, e.reason.refId, const [], planetKey: 'money'), isTrue);
    expect(RecordOpener.moneyTarget('${e.reason.refTable}:${e.reason.refId}'), MoneyDebtTarget(ids.debtIOwe));
  });

  test('every money write is logged on the Money world', () async {
    Future<Set<String>> kinds() async =>
        {for (final a in await repos.activity.since(DateTime(2026, 9, 1), planetKey: 'money')) a.kind};
    // Entries, the jar deposit and the budget plan.
    expect(await kinds(), containsAll([LedgerService.activityKind, GoalsService.kindJar, 'money.budget']));
    final goals = GoalsService(repos, clock: () => now);
    await goals.addDebtPayment(ids.debtIOwe, amountMilli: 50000);
    await goals.payObligation(ids.internet);
    expect(await kinds(), containsAll([GoalsService.kindDebt, GoalsService.kindObligation]));
  });
}
