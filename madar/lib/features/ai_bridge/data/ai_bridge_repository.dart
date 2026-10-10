import 'dart:convert';
import 'dart:typed_data';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart' show CurrencyCatalog;
import '../../data/data.dart' show DataFile;
import '../../data/domain/ai_summary.dart' show SummarySectionId;
import '../../data/domain/plain_numbers.dart';
import '../domain/plan_catalog.dart';
import '../domain/plan_contract.dart';
import '../domain/plan_request.dart';

/// Reads the database for the AI bridge: the catalogue of his own things,
/// and the request file that carries it.
///
/// Two uses, one loader:
///
/// * **for the export** – [loadCatalog] with the sections he chose, so a
///   summary without Money carries no envelopes;
/// * **for an import** – [loadCatalog] with no sections (everything), so a
///   reference is checked against what he really has, whatever he happened
///   to send.
///
/// Nothing here writes. Names travel; notes never do – the same line the
/// AI-ready summary draws.
class AiBridgeRepository {
  AiBridgeRepository(this.repos);

  final Repositories repos;

  MadarDatabase get _db => repos.db;

  /// Everything the AI may point at.
  ///
  /// [sections] limits it to the areas he is sending (null = all areas,
  /// which is what an import checks against).
  Future<PlanCatalog> loadCatalog(DateTime now, {Set<SummarySectionId>? sections}) async {
    bool on(SummarySectionId id) => sections == null || sections.contains(id);

    final money = on(SummarySectionId.money);
    final health = on(SummarySectionId.health);
    final body = on(SummarySectionId.body);
    final work = on(SummarySectionId.work);
    final growth = on(SummarySectionId.growth);
    final custom = on(SummarySectionId.custom);

    final currencies = money ? await repos.currencies.getAll() : const <CurrencyRow>[];
    final base = currencies.where((c) => c.isBase).firstOrNull ?? currencies.firstOrNull;
    final decimals = base == null ? 3 : CurrencyCatalog.decimalsFor(base.code);

    final budget = money ? await repos.budgetItems.getAll() : const <BudgetItemRow>[];
    final wallets = money ? await repos.wallets.getAll(where: (w) => w.archived.equals(false)) : const <WalletRow>[];

    final foods = body ? await repos.foods.getAll(where: (f) => f.archived.equals(false)) : const <FoodRow>[];
    final logs = body ? await _db.select(_db.foodLogs).get() : const <FoodLogRow>[];
    final plans = body ? await repos.mealPlans.getAll() : const <MealPlanRow>[];
    final slots = body ? await repos.mealSlots.getAll() : const <MealSlotRow>[];
    final avoid = body ? await repos.avoidItems.getAll() : const <AvoidItemRow>[];

    final habits = health ? await repos.habits.getAll() : const <HabitRow>[];
    final conditions = health ? await repos.conditions.getAll() : const <ConditionRow>[];
    final labs = health ? await repos.labTests.getAll() : const <LabTestRow>[];

    final projects = work ? await repos.projects.getAll() : const <ProjectRow>[];
    final goals = growth ? await repos.learningGoals.getAll() : const <LearningGoalRow>[];
    final trackers = custom
        ? await repos.customModules.getAll(where: (m) => m.archived.equals(false))
        : const <CustomModuleRow>[];

    final planName = {for (final p in plans) p.id: p.name};

    return PlanCatalog(
      today: now,
      baseCurrency: base?.code ?? '',
      currencyCodes: {for (final c in currencies) c.code},
      budgetItems: PlanRefSet([
        for (final b in budget)
          PlanRef(
            id: b.id,
            name: b.name,
            detail: _envelopeDetail(b, base?.code ?? '', decimals),
            extra: {
              'mode': b.mode.name,
              'period': b.period.name,
              'amountMilli': b.amountMilli,
              'percent': b.percent,
              'currency': b.currency ?? base?.code,
            },
          ),
      ]),
      wallets: PlanRefSet([for (final w in wallets) PlanRef(id: w.id, name: w.name, detail: w.currency)]),
      foods: PlanRefSet([
        for (final f in foods)
          PlanRef(
            id: f.id,
            name: f.name,
            detail: f.tags.isEmpty ? null : f.tags.join(', '),
            extra: {'tags': f.tags, 'portion': f.defaultPortion, 'unit': f.unit},
          ),
        // Foods he logged by hand without adding them to the library: the
        // AI may name those too, because he has eaten them.
        for (final name in {
          for (final l in logs)
            if (l.foodId == null) l.name.trim(),
        })
          if (name.isNotEmpty) PlanRef(id: 'logged:$name', name: name),
      ]),
      mealPlans: PlanRefSet([
        for (final p in plans) PlanRef(id: p.id, name: p.name, extra: {'active': p.active}),
      ]),
      mealSlots: PlanRefSet([
        for (final s in slots)
          PlanRef(
            id: s.id,
            name: s.name,
            detail: planTime(s.timeMinutes),
            extra: {
              'planId': s.planId,
              'planName': planName[s.planId],
              'timeMinutes': s.timeMinutes,
              'weekdays': s.weekdays,
            },
          ),
      ]),
      habits: PlanRefSet([
        for (final h in habits)
          PlanRef(id: h.id, name: h.name, detail: h.category, extra: {'active': h.active, 'category': h.category}),
      ]),
      conditions: PlanRefSet([for (final c in conditions) PlanRef(id: c.id, name: c.name)]),
      labTests: PlanRefSet([
        for (final t in labs)
          PlanRef(
            id: t.id,
            name: t.name,
            detail: t.unit,
            extra: {'unit': t.unit, 'low': t.low, 'high': t.high, 'category': t.category},
          ),
      ]),
      avoidItems: PlanRefSet([for (final a in avoid) PlanRef(id: a.id, name: a.body, detail: a.reason)]),
      projects: PlanRefSet([for (final p in projects) PlanRef(id: p.id, name: p.name)]),
      learningGoals: PlanRefSet([
        for (final g in goals)
          PlanRef(
            id: g.id,
            name: g.name,
            detail: '${PlainNumbers.decimal(g.target)} ${g.unit}'.trim(),
            extra: {'target': g.target, 'unit': g.unit, 'active': g.active},
          ),
      ]),
      trackers: PlanRefSet([
        for (final m in trackers) PlanRef(id: m.id, name: m.name, extra: {'planetKey': m.planetKey}),
      ]),
    );
  }

  /// `80.000 JOD monthly` / `15% of parent` – plain, machine-readable text
  /// (Western digits in every language; the UI localises the digits).
  static String _envelopeDetail(BudgetItemRow b, String currency, int decimals) {
    final period = b.period.name;
    if (b.mode == BudgetMode.percent) {
      final percent = b.percent;
      return percent == null ? period : '${PlainNumbers.decimal(percent)}% ${b.percentOf.name} $period';
    }
    final milli = b.amountMilli;
    if (milli == null) return period;
    final code = b.currency ?? currency;
    return '${PlainNumbers.milli(milli, decimals: decimals)} $code $period'.trim();
  }

  /// The request he hands to an AI app: his approved summary, his own
  /// things, the prompt and the answer contract in one file.
  Future<PlanRequest> buildRequest({
    required DateTime now,
    required String languageCode,
    required String summaryMarkdown,
    required Set<SummarySectionId> sections,
    String ask = '',
    String? requestId,
  }) async {
    final catalog = await loadCatalog(now, sections: sections);
    return PlanRequest(
      requestId: requestId ?? 'r-${planDay(now)}-${newId().substring(0, 8)}',
      generatedAt: now,
      languageCode: languageCode,
      summaryMarkdown: summaryMarkdown,
      sections: [
        for (final s in SummarySectionId.values)
          if (sections.contains(s)) s.name,
      ],
      catalog: catalog,
      ask: ask,
      omitted: PlanOmissions.all,
    );
  }

  /// The request as a file ready for the share sheet or a save dialog.
  static DataFile requestFile(PlanRequest request) {
    final text = request.encode();
    return DataFile(
      name: 'madar-ai-request-${planDay(request.generatedAt)}.json',
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: 'application/json',
      encrypted: false,
    );
  }
}
