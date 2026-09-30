import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/money/budget/budget.dart' show BudgetScreen, BudgetTab, showBudgetPicker;
import '../../features/money/goals/goals.dart'
    show GoalsNavigation, GoalsScreen, GoalsTab, JarScreen, showDebtSheet, showObligationSheet;
import '../../features/money/hub/money_links.dart';
import '../../features/money/ledger/ledger.dart'
    show CurrenciesScreen, LedgerRoutes, MoneyLedgerScreen, TransactionsScreen, TxFilter, WalletScreen;
import '../db/repositories/repositories.dart';
import '../domain/enums.dart';
import '../settings/app_settings.dart';
import '../sound/sound_api.dart';
import 'routes.dart';

/// Adapters between the router and the Phase 5 money screens (the Money
/// world's hub, Settings › Money, notification taps, the packages' own
/// links): every money screen is a route, so back, deep links and
/// notification taps share one stack.
///
/// In-app links `push` (back returns to the Money page or wherever they were
/// opened); notification deep links `go` (see `AppNotificationRouter`). A
/// debt or an obligation opens as its sheet over the page it was tapped on.
abstract final class MoneyNav {
  static void ledger(BuildContext context) => context.push(AppRoutes.ledger);

  static void wallet(BuildContext context, String walletId) => context.push(AppRoutes.walletOf(walletId));

  static void transactions(BuildContext context, {TxFilter filter = TxFilter.none}) =>
      context.push(AppRoutes.transactionsOf(TxFilterQuery.encode(filter)));

  static void currencies(BuildContext context) => context.push(AppRoutes.currencies);

  static void budget(BuildContext context, {BudgetTab tab = BudgetTab.plan}) =>
      context.push(AppRoutes.budgetOf(tab: tab.name));

  static void goals(BuildContext context, {GoalsTab tab = GoalsTab.jars}) =>
      context.push(AppRoutes.goalsOf(tab: tab.name));

  static void jar(BuildContext context, String jarId) => context.push(AppRoutes.jarOf(jarId));

  /// Opens [target]: a route, or a debt's / an obligation's sheet.
  static Future<void> open(BuildContext context, MoneyTarget target) => switch (target) {
    MoneyRouteTarget(:final location) => context.push<void>(location),
    MoneyDebtTarget(:final debtId) => showDebtSheet(context, debtId),
    MoneyObligationTarget(:final obligationId) => showObligationSheet(context, obligationId),
  };
}

/// The ledger's links, routed (installed app-wide through
/// `moneyHookOverrides`): its screens open as routes, a jar / debt /
/// obligation entry opens its jar, debt or obligation, and the budget item
/// picker is the budget package's tree picker.
LedgerRoutes routedLedgerRoutes(Ref ref) {
  void push(BuildContext context, String location) {
    Fx.fire(Sfx.navigate);
    unawaited(context.push<void>(location));
  }

  return LedgerRoutes(
    ledger: (context) => push(context, AppRoutes.ledger),
    wallet: (context, walletId) => push(context, AppRoutes.walletOf(walletId)),
    transactions: (context, filter) => push(context, AppRoutes.transactionsOf(TxFilterQuery.encode(filter))),
    currencies: (context) => push(context, AppRoutes.currencies),
    linked: (context, tx, link) async {
      final target = await MoneyLinks.linkedTarget(ref.read(repositoriesProvider), tx, link);
      if (target == null || !context.mounted) return;
      await MoneyNav.open(context, target);
    },
    budgetPicker: (context, {selected, title}) async {
      final pick = await showBudgetPicker(context, selectedId: selected, title: title);
      return pick == null ? null : (id: pick.id);
    },
  );
}

/// The goals package's own navigation, routed: a jar and the goals' tabs
/// open as routes.
class RoutedGoalsNavigation extends GoalsNavigation {
  const RoutedGoalsNavigation();

  @override
  Future<void> openJar(BuildContext context, String jarId) => context.push<void>(AppRoutes.jarOf(jarId));

  @override
  Future<void> openGoals(BuildContext context, {GoalsTab tab = GoalsTab.jars}) =>
      context.push<void>(AppRoutes.goalsOf(tab: tab.name));
}

/// The transactions' filters as query parameters (pure): repeated keys for
/// several values, days as `yyyy-mm-dd`; unknown values are dropped.
abstract final class TxFilterQuery {
  static Map<String, List<String>> encode(TxFilter f) => {
    if (f.walletIds.isNotEmpty) 'wallet': [...f.walletIds],
    if (f.kinds.isNotEmpty)
      'kind': [
        for (final k in TxKind.values)
          if (f.kinds.contains(k)) k.name,
      ],
    if (f.budgetItemIds.isNotEmpty) 'item': [...f.budgetItemIds],
    if (f.unassignedOnly) 'unassigned': const ['1'],
    if (f.tags.isNotEmpty) 'tag': [...f.tags],
    if (f.from != null) 'from': [_day(f.from!)],
    if (f.to != null) 'to': [_day(f.to!)],
    if (f.walletKind != null) 'scope': [f.walletKind!.name],
    if (f.query.trim().isNotEmpty) 'q': [f.query.trim()],
  };

  static TxFilter decode(Map<String, List<String>> q) {
    Set<String> ids(String key) => {
      for (final v in q[key] ?? const <String>[])
        if (v.trim().isNotEmpty) v.trim(),
    };
    String? one(String key) => (q[key] ?? const <String>[]).firstOrNull;
    return TxFilter(
      walletIds: ids('wallet'),
      kinds: {
        for (final name in q['kind'] ?? const <String>[])
          ?TxKind.values.where((k) => k.name == name).firstOrNull,
      },
      budgetItemIds: ids('item'),
      unassignedOnly: one('unassigned') == '1',
      tags: ids('tag'),
      from: _parseDay(one('from')),
      to: _parseDay(one('to')),
      walletKind: WalletKind.values.where((k) => k.name == one('scope')).firstOrNull,
      query: one('q')?.trim() ?? '',
    );
  }

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static final RegExp _dayPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static DateTime? _parseDay(String? s) {
    final m = s == null ? null : _dayPattern.firstMatch(s.trim());
    if (m == null) return null;
    final y = int.parse(m[1]!), mo = int.parse(m[2]!), d = int.parse(m[3]!);
    final day = DateTime(y, mo, d);
    // Rejects impossible days (2026-02-31) instead of rolling them over.
    return day.year == y && day.month == mo && day.day == d ? day : null;
  }
}

/// Whether decorative backdrops rest (battery saver).
bool _saver(WidgetRef ref) => ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));

/// The enum value of [values] named [name], else [fallback] (pure).
T _named<T extends Enum>(List<T> values, String? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

/// `/ledger`.
class LedgerRoutePage extends ConsumerWidget {
  const LedgerRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MoneyLedgerScreen(animateBackdrop: !_saver(ref));
}

/// `/ledger/wallet/:id` (an unknown wallet shows the screen's own "gone").
class WalletRoutePage extends ConsumerWidget {
  const WalletRoutePage({super.key, required this.walletId});

  final String walletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      WalletScreen(key: ValueKey('wallet:$walletId'), walletId: walletId, animateBackdrop: !_saver(ref));
}

/// `/ledger/transactions[?wallet=&kind=&item=&tag=&from=&to=&scope=&q=]`.
class TransactionsRoutePage extends ConsumerWidget {
  const TransactionsRoutePage({super.key, this.filter = TxFilter.none});

  final TxFilter filter;

  /// The filter named by the location's query parameters.
  static TxFilter filterOf(Map<String, List<String>> query) => TxFilterQuery.decode(query);

  @override
  Widget build(BuildContext context, WidgetRef ref) => TransactionsScreen(
    key: ValueKey('transactions:${AppRoutes.transactionsOf(TxFilterQuery.encode(filter))}'),
    filter: filter,
    animateBackdrop: !_saver(ref),
  );
}

/// `/ledger/currencies`.
class CurrenciesRoutePage extends ConsumerWidget {
  const CurrenciesRoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => CurrenciesScreen(animateBackdrop: !_saver(ref));
}

/// `/budget[?tab=spending]`.
class BudgetRoutePage extends ConsumerWidget {
  const BudgetRoutePage({super.key, this.tab = BudgetTab.plan});

  final BudgetTab tab;

  static BudgetTab tabOf(String? name) => _named(BudgetTab.values, name, BudgetTab.plan);

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BudgetScreen(key: ValueKey('budget:${tab.name}'), initialTab: tab, animateBackdrop: !_saver(ref));
}

/// `/goals[?tab=debts|obligations][&debt=<id>|&obligation=<id>]`: a debt or
/// an obligation named in the location opens as its sheet once the page is
/// up (a due reminder's tap lands here).
class GoalsRoutePage extends ConsumerStatefulWidget {
  const GoalsRoutePage({super.key, this.tab = GoalsTab.jars, this.debtId, this.obligationId});

  final GoalsTab tab;
  final String? debtId;
  final String? obligationId;

  static GoalsTab tabOf(String? name) => _named(GoalsTab.values, name, GoalsTab.jars);

  /// The tab a location shows: a named debt or obligation implies its tab.
  static GoalsTab tabFor({String? tab, String? debtId, String? obligationId}) {
    if (debtId != null && debtId.isNotEmpty) return GoalsTab.debts;
    if (obligationId != null && obligationId.isNotEmpty) return GoalsTab.obligations;
    return tabOf(tab);
  }

  @override
  ConsumerState<GoalsRoutePage> createState() => _GoalsRoutePageState();
}

class _GoalsRoutePageState extends ConsumerState<GoalsRoutePage> {
  @override
  void initState() {
    super.initState();
    final debt = widget.debtId, obligation = widget.obligationId;
    if ((debt ?? obligation) == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (debt != null && debt.isNotEmpty) {
        unawaited(showDebtSheet(context, debt));
      } else if (obligation != null && obligation.isNotEmpty) {
        unawaited(showObligationSheet(context, obligation));
      }
    });
  }

  @override
  Widget build(BuildContext context) => GoalsScreen(
    key: ValueKey('goals:${widget.tab.name}'),
    initialTab: widget.tab,
    animateBackdrop: !_saver(ref),
  );
}

/// `/goals/jar/:id` (an unknown jar shows the screen's own "gone").
class JarRoutePage extends ConsumerWidget {
  const JarRoutePage({super.key, required this.jarId});

  final String jarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      JarScreen(key: ValueKey('jar:$jarId'), jarId: jarId, animateBackdrop: !_saver(ref));
}
