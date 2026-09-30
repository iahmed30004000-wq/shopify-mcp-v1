/// Builds the AI-ready Markdown summary from a [SummaryInput].
///
/// Deterministic (same input → same text: stable ordering, ISO dates,
/// Western digits, `.` decimals in both languages), compact (bullets and a
/// few small tables) and conservative about privacy:
///
/// * never free-text notes, journal text, worries or doctor answers;
/// * never phone numbers, document numbers, document holders or account
///   numbers – and any long digit run typed into a name is masked
///   ([SummaryText.clean]);
/// * health is tracking data only (scores, averages, tags, flags).
///
/// Headings and labels follow the app language via [L10n]. Pure Dart.
library;

import 'dart:math' as math;

import '../../../core/db/database.dart';
import '../../../core/domain/budget_math.dart';
import '../../../core/domain/enums.dart';
import '../../../core/domain/money.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../family/domain/rhythm.dart';
import '../../health/record/domain/lab_flags.dart';
import 'ai_summary.dart';
import 'csv_export.dart' show DataCsvBuilder;
import 'export_range.dart';
import 'plain_numbers.dart';
import 'summary_input.dart';
import 'summary_text.dart';

class AiSummaryBuilder {
  AiSummaryBuilder(this.l, {required this.languageCode});

  final L10n l;
  final String languageCode;

  /// Look-back windows (days).
  static const int shortWindow = 7, window = 30, labMonths = 12;

  /// Caps that keep the document compact.
  static const int maxLabRows = 25, maxModules = 12, maxFieldsPerModule = 6, maxListItems = 12;

  static const _obligatory = {Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha};

  late DateTime _today;

  AiSummary build(SummaryInput input, {SummaryProfileOptions profile = const SummaryProfileOptions()}) {
    _today = ExportDateRange.dayOf(input.now);
    SummarySection section(SummarySectionId id, String title, String body) {
      final b = body.trim();
      return SummarySection(id: id, title: title, body: b.isEmpty ? l.dataSumNoData : b, isEmpty: b.isEmpty);
    }

    return AiSummary(
      heading: l.dataSumHeading(isoDay(_today)),
      preamble: l.dataSumPreamble,
      sections: [
        section(SummarySectionId.profile, l.dataSumProfile, _profile(input, profile)),
        section(SummarySectionId.faith, l.dataSumFaith, _faith(input)),
        section(SummarySectionId.health, l.dataSumHealth, _health(input)),
        section(SummarySectionId.money, l.dataSumMoney, _money(input)),
        section(SummarySectionId.family, l.dataSumFamily, _family(input)),
        section(SummarySectionId.work, l.dataSumWork, _work(input)),
        section(SummarySectionId.growth, l.dataSumGrowth, _growth(input)),
        section(SummarySectionId.body, l.dataSumBody, _body(input)),
        section(SummarySectionId.travel, l.dataSumTravel, _travel(input)),
        section(SummarySectionId.custom, l.dataSumCustom, _custom(input)),
      ],
    );
  }

  // ------------------------------------------------------------ helpers --

  static String _clean(String? s) => SummaryText.clean(s);

  String get _sep => ' · ';
  String _list(Iterable<String> items) => items.join(l.dataSumListSep);
  String _join(Iterable<String?> parts) => parts.whereType<String>().where((s) => s.isNotEmpty).join(_sep);

  static String _num(num v, {int decimals = 1}) => PlainNumbers.decimal(v, maxDecimals: decimals);

  DateTime _day(DateTime t) => ExportDateRange.dayOf(t);

  int _daysFromToday(DateTime t) => (_day(t).difference(_today).inHours / 24).round();

  /// Within the last [days] days, today included.
  bool _within(DateTime t, int days) {
    final back = -_daysFromToday(t);
    return back >= 0 && back < days;
  }

  /// Within the [days] days before the last [days] days.
  bool _withinPrevious(DateTime t, int days) {
    final back = -_daysFromToday(t);
    return back >= days && back < 2 * days;
  }

  static double? _avg(Iterable<num?> values) {
    final v = values.whereType<num>().toList();
    if (v.isEmpty) return null;
    return v.fold<double>(0, (a, b) => a + b) / v.length;
  }

  /// Most frequent labels (ties by label), as `label (n)`.
  String _top(Iterable<String> labels, {int n = 3}) {
    final counts = <String, int>{};
    for (final raw in labels) {
      final s = _clean(raw);
      if (s.isEmpty) continue;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c != 0 ? c : a.key.compareTo(b.key);
      });
    return _list([for (final e in sorted.take(n)) '${e.key} (${e.value})']);
  }

  String _windowLabel(int days) => l.dataSumLastDays(days);

  static int _bySortThenName(int sa, int sb, String a, String b, String ia, String ib) {
    final c = sa.compareTo(sb);
    if (c != 0) return c;
    final n = a.compareTo(b);
    return n != 0 ? n : ia.compareTo(ib);
  }

  // ------------------------------------------------------------ profile --

  String _profile(SummaryInput input, SummaryProfileOptions o) {
    final lines = <String>[];
    final place = input.place;
    if (o.city) {
      final city = place.cityFor(languageCode);
      if (city != null) {
        final country = place.countryCode;
        lines.add('- ${l.dataSumCity}: ${_clean(city)}${country == null ? '' : ' (${_clean(country)})'}');
      }
    }
    if (o.timeZone && place.timeZone != null) lines.add('- ${l.dataSumTimeZone}: ${_clean(place.timeZone)}');
    if (o.currency) {
      final base = input.currencies.where((c) => c.isBase).firstOrNull;
      if (base != null) lines.add('- ${l.dataSumBaseCurrency}: ${base.code}');
    }
    if (o.language) lines.add('- ${l.dataSumLanguage}: ${l.dataSumLanguageName}');
    final about = SummaryText.clean(o.aboutMe, maxLength: SummaryText.maxNoteLength);
    if (about.isNotEmpty) lines.add('- ${l.dataSumAboutMe}: $about');
    return lines.join('\n');
  }

  // -------------------------------------------------------------- faith --

  String _faith(SummaryInput input) {
    final md = _Md();

    // Prayers.
    final prayers = <String>[];
    DateTime? dayOfLog(PrayerLogRow r) {
      final parts = r.day.split('-');
      if (parts.length != 3) return null;
      final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2]);
      return y == null || m == null || d == null ? null : DateTime(y, m, d);
    }

    for (final days in const [shortWindow, window]) {
      var logged = 0, onTime = 0, late = 0, qada = 0, missed = 0, jamaah = 0;
      for (final r in input.prayerLogs) {
        if (!_obligatory.contains(r.prayer)) continue;
        final d = dayOfLog(r);
        if (d == null || !_within(d, days)) continue;
        logged++;
        switch (r.status) {
          case PrayerStatus.prayed:
            onTime++;
          case PrayerStatus.late:
            late++;
          case PrayerStatus.qada:
            qada++;
          case PrayerStatus.missed:
            missed++;
        }
        if (r.inJamaah) jamaah++;
      }
      if (logged == 0) continue;
      prayers.add(
        '- ${l.dataSumObligatory(_windowLabel(days))}: ${_join([
          l.dataSumLogged('$logged', '${days * _obligatory.length}'),
          l.dataSumOnTime('$onTime'),
          if (late > 0) l.dataSumLate('$late'),
          if (qada > 0) l.dataSumMadeUp('$qada'),
          if (missed > 0) l.dataSumMissed('$missed'),
          if (jamaah > 0) l.dataSumInCongregation('$jamaah'),
        ])}',
      );
    }
    final voluntary = input.prayerLogs.where((r) {
      if (_obligatory.contains(r.prayer) || r.status == PrayerStatus.missed) return false;
      final d = dayOfLog(r);
      return d != null && _within(d, window);
    }).length;
    if (voluntary > 0) prayers.add('- ${l.dataSumVoluntary(_windowLabel(window))}: $voluntary');
    md.sub(l.dataSumPrayersTitle, prayers);

    // Quran and wird.
    final quran = <String>[];
    for (final days in const [shortWindow, window]) {
      final s = input.quranSessions.where((q) => _within(q.day, days)).toList();
      if (s.isEmpty) continue;
      final pages = s.fold<double>(0, (a, q) => a + q.pages);
      final minutes = (s.fold<int>(0, (a, q) => a + q.seconds) / 60).round();
      quran.add(
        '- ${_windowLabel(days)}: ${_join([
          l.dataSumSessions('${s.length}'),
          l.dataSumPages(_num(pages)),
          if (minutes > 0) l.dataSumMinutes('$minutes'),
        ])}',
      );
    }
    if (quran.isEmpty && input.quranSessions.isNotEmpty) {
      final last = input.quranSessions.map((q) => q.day).reduce((a, b) => a.isAfter(b) ? a : b);
      quran.add('- ${l.dataSumLastSession(isoDay(last))}');
    }
    final plans = input.wirdPlans.where((w) => w.active).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    for (final w in plans) {
      final unit = switch (w.unit) {
        WirdUnit.pages => l.dataSumUnitPages,
        WirdUnit.juz => l.dataSumUnitJuz,
        WirdUnit.hizb => l.dataSumUnitHizb,
        WirdUnit.ayat => l.dataSumUnitAyat,
      };
      quran.add(
        '- ${l.dataSumWird(_clean(w.name))}: ${_join([
          l.dataSumPerDay(_num(w.amountPerDay), unit),
          l.dataSumSince(isoDay(w.startDate)),
          if (w.targetDate != null) l.dataSumBy(isoDay(w.targetDate!)),
        ])}',
      );
    }
    md.sub(l.dataSumQuranTitle, quran);

    // Hifz.
    final items = input.hifzItems.where((h) => !h.suspended).toList();
    if (items.isNotEmpty || input.hifzReviews.isNotEmpty) {
      final fresh = items.where((h) => h.due == null).length;
      final due = items.where((h) => h.due != null && !_day(h.due!).isAfter(_today)).length;
      final reviews = input.hifzReviews.where((r) => _within(r.at, window)).toList();
      final avg = _avg(reviews.map((r) => r.grade));
      md.sub(l.dataSumHifzTitle, [
        '- ${_join([
          l.dataSumItems('${items.length}'),
          if (fresh > 0) l.dataSumNew('$fresh'),
          l.dataSumDueToday('$due'),
        ])}',
        if (reviews.isNotEmpty)
          '- ${_windowLabel(window)}: ${_join([
            l.dataSumReviews('${reviews.length}'),
            if (avg != null) l.dataSumAvgGrade(_num(avg)),
          ])}',
      ]);
    }
    return md.text;
  }

  // ------------------------------------------------------------- health --

  String _health(SummaryInput input) {
    final md = _Md();

    final alerts = input.healthAlerts.where((a) => a.pinned).toList()
      ..sort((a, b) {
        final s = b.severity.index.compareTo(a.severity.index);
        return s != 0 ? s : _bySortThenName(a.sortOrder, b.sortOrder, a.body, b.body, a.id, b.id);
      });
    md.sub(l.dataSumAlertsTitle, [
      for (final a in alerts)
        '- ${_clean(a.body)} (${switch (a.severity) {
          Severity.critical => l.dataSumSeverityCritical,
          Severity.warning => l.dataSumSeverityWarning,
          Severity.info => l.dataSumSeverityInfo,
        }})',
    ]);

    final conditions = input.conditions.where((c) => c.active).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    md.sub(l.dataSumConditionsTitle, [
      for (final c in conditions) '- ${_join([_clean(c.name), if (c.since != null) l.dataSumSince(isoDay(c.since!))])}',
    ]);

    final meds = input.medications.where((m) => m.active).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    md.sub(l.dataSumMedsTitle, [
      for (final m in meds)
        '- ${_join([
          switch (m.kind) {
            MedKind.supplement => '${_clean(m.name)} (${l.dataSumKindSupplement})',
            MedKind.injection => '${_clean(m.name)} (${l.dataSumKindInjection})',
            _ => _clean(m.name),
          },
          if (m.dose != null && m.dose!.trim().isNotEmpty) _clean(m.dose),
          if (m.times.isNotEmpty) (List.of(m.times)..sort()).map(_clean).join(', '),
          switch (m.takenWith) {
            TakenWith.emptyStomach => l.dataSumWithEmptyStomach,
            TakenWith.breakfast => l.dataSumWithBreakfast,
            TakenWith.lunch => l.dataSumWithLunch,
            TakenWith.dinner => l.dataSumWithDinner,
            TakenWith.bedtime => l.dataSumWithBedtime,
            TakenWith.perCourse => l.dataSumWithCourse,
            TakenWith.other || TakenWith.anytime => null,
          },
        ])}',
    ]);

    md.sub(l.dataSumLabsTitle, _labs(input));
    md.sub(l.dataSumPainTitle, _pain(input));
    md.sub(l.dataSumMoodTitle, _mood(input));
    return md.text;
  }

  List<String> _labs(SummaryInput input) {
    final tests = {for (final t in input.labTests) t.id: t};
    final since = DateTime(_today.year, _today.month - labMonths, _today.day);
    final byTest = <String, List<LabReadingRow>>{};
    for (final r in input.labReadings) {
      if (!tests.containsKey(r.testId)) continue;
      (byTest[r.testId] ??= []).add(r);
    }
    final rows = <(int, String, List<String>)>[];
    for (final MapEntry(key: id, value: readings) in byTest.entries) {
      readings.sort((a, b) {
        final c = b.date.compareTo(a.date);
        if (c != 0) return c;
        final k = b.createdAt.compareTo(a.createdAt);
        return k != 0 ? k : b.id.compareTo(a.id);
      });
      final latest = readings.first;
      if (_day(latest.date).isBefore(since) || _day(latest.date).isAfter(_today)) continue;
      final t = tests[id]!;
      final range = LabRange(low: t.low, high: t.high);
      final flag = LabFlags.classify(latest.value, range, margin: input.labMargin);
      String result(LabReadingRow r) => r.value != null
          ? '${_num(r.value!, decimals: 3)}${t.unit == null || t.unit!.trim().isEmpty ? '' : ' ${_clean(t.unit)}'}'
          : _clean(r.valueText);
      final (lo, hi) = range.ordered;
      final rangeText = lo != null && hi != null
          ? '${_num(lo, decimals: 3)}–${_num(hi, decimals: 3)}'
          : lo != null
          ? '≥ ${_num(lo, decimals: 3)}'
          : hi != null
          ? '≤ ${_num(hi, decimals: 3)}'
          : '';
      final flagText = DataCsvBuilder.labFlagLabel(l, flag);
      final previous = readings.length > 1 ? '${result(readings[1])} (${isoDay(readings[1].date)})' : '';
      rows.add((
        flag.attention,
        _clean(t.name),
        [_clean(t.name), isoDay(latest.date), result(latest), rangeText, flagText.isEmpty ? '—' : flagText, previous],
      ));
    }
    if (rows.isEmpty) return const [];
    rows.sort((a, b) {
      final c = b.$1.compareTo(a.$1);
      return c != 0 ? c : a.$2.compareTo(b.$2);
    });
    final shown = rows.take(maxLabRows).toList();
    return [
      '_${l.dataSumLabsWindow('$labMonths')}_',
      '',
      _tableRow([l.dataSumColTest, l.dataSumColDate, l.dataSumColResult, l.dataSumColRange, l.dataSumColFlag, l.dataSumColPrevious]),
      _tableRow(List.filled(6, '---')),
      for (final r in shown) _tableRow(r.$3),
      if (rows.length > shown.length) '- ${l.dataSumMore('${rows.length - shown.length}')}',
    ];
  }

  static String _tableRow(List<String> cells) => '| ${cells.map((c) => c.isEmpty ? ' ' : c).join(' | ')} |';

  List<String> _pain(SummaryInput input) {
    final recent = input.painEntries.where((p) => _within(p.at, window)).toList();
    final previous = input.painEntries.where((p) => _withinPrevious(p.at, window)).toList();
    if (recent.isEmpty && previous.isEmpty) return const [];
    final out = <String>[];
    if (recent.isNotEmpty) {
      out.add(
        '- ${_windowLabel(window)}: ${_join([
          l.dataSumEntries('${recent.length}'),
          l.dataSumAverageOf(_num(_avg(recent.map((p) => p.score))!), '10'),
          l.dataSumHighest('${recent.map((p) => p.score).reduce(math.max)}', '10'),
        ])}',
      );
    } else {
      out.add('- ${_windowLabel(window)}: ${l.dataSumEntries('0')}');
    }
    if (previous.isNotEmpty) {
      out.add(
        '- ${l.dataSumPreviousDays(_windowLabel(window))}: ${_join([
          l.dataSumEntries('${previous.length}'),
          l.dataSumAverageOf(_num(_avg(previous.map((p) => p.score))!), '10'),
        ])}',
      );
    }
    final places = _top(recent.expand((p) => p.locations));
    if (places.isNotEmpty) out.add('- ${l.dataSumTopPlaces}: $places');
    final triggers = _top(recent.expand((p) => p.triggers));
    if (triggers.isNotEmpty) out.add('- ${l.dataSumTopTriggers}: $triggers');
    return out;
  }

  List<String> _mood(SummaryInput input) {
    final recent = input.moodEntries.where((m) => _within(m.at, window)).toList();
    final previous = input.moodEntries.where((m) => _withinPrevious(m.at, window)).toList();
    if (recent.isEmpty && previous.isEmpty) return const [];
    String? metrics(List<MoodEntryRow> list) {
      String? a(num? Function(MoodEntryRow) f, String Function(String) label) {
        final v = _avg(list.map(f));
        return v == null ? null : label(_num(v));
      }

      final parts = [
        a((m) => m.mood, (v) => l.dataSumMoodAvg(v)),
        a((m) => m.stress, (v) => l.dataSumStressAvg(v)),
        a((m) => m.anxiety, (v) => l.dataSumAnxietyAvg(v)),
        a((m) => m.energy, (v) => l.dataSumEnergyAvg(v)),
        a((m) => m.sleepHours, (v) => l.dataSumSleepAvg(v)),
        a((m) => m.caffeineCups, (v) => l.dataSumCaffeineAvg(v)),
      ];
      return _join([l.dataSumEntries('${list.length}'), ...parts]);
    }

    final out = <String>[
      '- ${_windowLabel(window)}: ${recent.isEmpty ? l.dataSumEntries('0') : metrics(recent)}',
      if (previous.isNotEmpty) '- ${l.dataSumPreviousDays(_windowLabel(window))}: ${metrics(previous)}',
    ];
    final factors = _top(recent.expand((m) => m.factors));
    if (factors.isNotEmpty) out.add('- ${l.dataSumTopFactors}: $factors');
    return out;
  }

  // -------------------------------------------------------------- money --

  String _money(SummaryInput input) {
    final md = _Md();
    final currencies = {for (final c in input.currencies) c.code.toUpperCase(): c};
    final base = input.currencies.where((c) => c.isBase).firstOrNull;
    final baseCode = base?.code.toUpperCase();
    int decimals(String code) => currencies[code.toUpperCase()]?.decimals ?? CurrencyCatalog.decimalsFor(code);
    String amount(int milli, String code) => '${PlainNumbers.milli(milli, decimals: decimals(code))} ${code.toUpperCase()}';
    num? rate(String code) {
      if (baseCode == null) return null;
      if (code.toUpperCase() == baseCode) return 1;
      final r = currencies[code.toUpperCase()]?.rateToBase;
      return r == null || r <= 0 || !r.isFinite ? null : r;
    }

    int? inBase(int milli, String code) {
      final r = rate(code);
      return r == null ? null : Money(milli, code.toUpperCase()).toBase(r, baseCode!).milli;
    }

    // Wallets.
    final wallets = input.wallets.where((w) => !w.archived).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    final walletById = {for (final w in input.wallets) w.id: w};
    final balances = {for (final w in input.wallets) w.id: w.openingMilli};
    for (final t in input.transactions) {
      if (balances.containsKey(t.walletId)) {
        balances[t.walletId] = balances[t.walletId]! +
            switch (t.kind) {
              TxKind.income => t.amountMilli.abs(),
              TxKind.expense || TxKind.transfer => -t.amountMilli.abs(),
              TxKind.adjustment => t.amountMilli,
            };
      }
      final to = t.toWalletId;
      if (t.kind == TxKind.transfer && to != null && to != t.walletId && balances.containsKey(to)) {
        balances[to] = balances[to]! + (t.toAmountMilli ?? t.amountMilli).abs();
      }
    }
    if (wallets.isNotEmpty) {
      var total = 0;
      final lines = <String>[
        if (baseCode != null) '_${l.dataSumConvertedTo(baseCode)}_',
        if (baseCode != null) '',
        _tableRow([l.dataSumColWallet, l.dataSumColBalance, if (baseCode != null) l.dataSumColInBase(baseCode)]),
        _tableRow(List.filled(baseCode != null ? 3 : 2, '---')),
      ];
      for (final w in wallets) {
        final b = balances[w.id] ?? 0;
        final converted = inBase(b, w.currency);
        if (converted != null) total += converted;
        lines.add(_tableRow([
          _clean(w.name),
          amount(b, w.currency),
          if (baseCode != null) converted == null ? '—' : PlainNumbers.milli(converted, decimals: decimals(baseCode)),
        ]));
      }
      if (baseCode != null) lines.add('- ${l.dataSumTotal(amount(total, baseCode))}');
      md.sub(l.dataSumWalletsTitle, lines);
    }

    // Budget (this month).
    if (input.budgetItems.isNotEmpty && baseCode != null) {
      final rates = <String, num>{
        for (final c in input.currencies)
          if (rate(c.code) != null) c.code.toUpperCase(): rate(c.code)!,
      };
      final budget = BudgetMath(
        [
          for (final b in input.budgetItems)
            BudgetNode(
              id: b.id,
              name: b.name,
              parentId: b.parentId,
              mode: b.mode,
              amountMilli: b.amountMilli,
              percent: b.percent,
              percentOf: b.percentOf,
              period: b.period,
              currency: b.currency,
              sortOrder: b.sortOrder,
            ),
        ],
        settings: BudgetSettings(weeksPerMonth: input.weeksPerMonth, baseCurrency: baseCode, ratesToBase: rates),
      );
      final report = budget.spend([
        for (final t in input.transactions)
          BudgetTx(
            budgetItemId: t.budgetItemId,
            amountMilli: t.amountMilli.abs(),
            date: t.date,
            currency: walletById[t.walletId]?.currency,
            kind: t.kind,
          ),
      ], BudgetWindow.month(_today));
      final planned = report.totalPlannedMilli, spent = report.totalSpentMilli;
      final pct = PlainNumbers.percent(spent, planned);
      final lines = <String>[
        '- ${_join([
          l.dataSumPlanned(amount(planned, baseCode)),
          l.dataSumSpent(amount(spent, baseCode)) + (pct == null ? '' : ' ($pct%)'),
          l.dataSumRemaining(amount(planned - spent, baseCode)),
        ])}',
      ];
      final names = {for (final b in input.budgetItems) b.id: b.name};
      final over = [
        for (final w in report.warnings)
          if (w.kind == BudgetWarningKind.overspent && w.nodeId != null && names.containsKey(w.nodeId))
            (names[w.nodeId]!, w.amountMilli ?? 0),
      ]..sort((a, b) {
          final c = b.$2.compareTo(a.$2);
          return c != 0 ? c : a.$1.compareTo(b.$1);
        });
      if (over.isNotEmpty) {
        lines.add('- ${l.dataSumOverPlan}: ${_list([for (final o in over.take(5)) '${_clean(o.$1)} +${PlainNumbers.milli(o.$2, decimals: decimals(baseCode))}'])}');
      }
      if (report.unassignedMilli > 0) lines.add('- ${l.dataSumUnassigned(amount(report.unassignedMilli, baseCode))}');
      final month = '${_today.year}-${_today.month.toString().padLeft(2, '0')}';
      md.sub(l.dataSumBudgetTitle(month), lines);
    }

    // Dues.
    final horizon = _today.add(const Duration(days: window));
    final dues = input.obligations.where((o) => o.active && !_day(o.nextDue).isAfter(horizon)).toList()
      ..sort((a, b) {
        final c = a.nextDue.compareTo(b.nextDue);
        return c != 0 ? c : _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id);
      });
    md.sub(l.dataSumDueTitle(_windowLabel(window)), [
      for (final o in dues)
        _day(o.nextDue).isBefore(_today)
            ? '- ${_clean(o.name)}: ${amount(o.amountMilli, o.currency)} – ${l.dataSumOverdueSince(isoDay(o.nextDue))}'
            : '- ${_clean(o.name)}: ${amount(o.amountMilli, o.currency)} – ${l.dataSumDueOn(isoDay(o.nextDue))}',
    ]);

    // Debts.
    final paid = <String, int>{};
    for (final p in input.debtPayments) {
      paid[p.debtId] = (paid[p.debtId] ?? 0) + p.amountMilli;
    }
    final debts = [
      for (final d in input.debts)
        if (d.settledAt == null && d.amountMilli - (paid[d.id] ?? 0) > 0) d,
    ]..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.person, b.person, a.id, b.id));
    md.sub(l.dataSumDebtsTitle, [
      for (final d in debts)
        '- ${_join([
          d.direction == DebtDirection.iOwe
              ? l.dataSumIOwe(_clean(d.person), amount(d.amountMilli - (paid[d.id] ?? 0), d.currency), amount(d.amountMilli, d.currency))
              : l.dataSumOwedToMe(_clean(d.person), amount(d.amountMilli - (paid[d.id] ?? 0), d.currency), amount(d.amountMilli, d.currency)),
          if (d.dueDate != null) l.dataSumDueOn(isoDay(d.dueDate!)),
        ])}',
    ]);

    // Jars.
    final saved = <String, int>{};
    for (final dep in input.jarDeposits) {
      saved[dep.jarId] = (saved[dep.jarId] ?? 0) + dep.amountMilli;
    }
    final jars = input.jars.where((j) => !j.archived).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    md.sub(l.dataSumJarsTitle, [
      for (final j in jars)
        '- ${_join([
          l.dataSumJar(
            _clean(j.name),
            amount(saved[j.id] ?? 0, j.currency),
            amount(j.targetMilli, j.currency),
            '${PlainNumbers.percent(saved[j.id] ?? 0, j.targetMilli) ?? 0}',
          ),
          if (j.deadline != null) l.dataSumBy(isoDay(j.deadline!)),
        ])}',
    ]);
    return md.text;
  }

  // ------------------------------------------------------------- family --

  String _family(SummaryInput input) {
    final logs = <String, List<DateTime>>{};
    for (final c in input.contactLogs) {
      (logs[c.personId] ??= []).add(c.at);
    }
    final withRhythm = <(PersonRow, RhythmState)>[];
    var without = 0;
    for (final p in input.people) {
      final rhythm = RhythmEngine.normalizeRhythm(p.rhythmDays);
      if (rhythm == null) {
        without++;
        continue;
      }
      final last = RhythmEngine.effectiveLastContact(stored: p.lastContact, logs: logs[p.id] ?? const [], now: input.now);
      withRhythm.add((p, RhythmEngine.evaluate(rhythmDays: rhythm, lastContact: last, createdAt: p.createdAt, now: input.now)));
    }
    final ordered = RhythmEngine.byUrgency(withRhythm, (e) => e.$2);
    final lines = <String>[
      for (final (p, s) in ordered)
        '- ${_join([
          p.relation == null || p.relation!.trim().isEmpty ? _clean(p.name) : '${_clean(p.name)} (${_clean(p.relation)})',
          l.dataSumEvery('${s.rhythmDays}'),
          s.daysSinceContact == null ? l.dataSumNeverContacted : l.dataSumLastContact('${s.daysSinceContact}'),
          switch (s.status) {
            RhythmStatus.overdue => l.dataSumOverdueBy('${s.daysOverdue}'),
            RhythmStatus.dueToday => l.dataSumDueTodayStatus,
            RhythmStatus.dueSoon || RhythmStatus.ok => l.dataSumDueIn('${s.daysUntilDue}'),
            RhythmStatus.none => null,
          },
        ])}',
      if (without > 0 && withRhythm.isNotEmpty) '- ${l.dataSumNoRhythm(without)}',
      if (without > 0 && withRhythm.isEmpty) '- ${l.dataSumPeopleNoRhythm(without)}',
    ];
    return lines.join('\n');
  }

  // --------------------------------------------------------------- work --

  String _work(SummaryInput input) {
    final md = _Md();
    final boards = input.boards.where((b) => !input.archivedBoardIds.contains(b.id)).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    final boardById = {for (final b in input.boards) b.id: b};
    List<(String, String)> columnsOf(BoardRow b) => [
      for (final c in b.columns)
        if (c is Map && c['id'] is String) (c['id'] as String, '${c['label'] ?? c['id']}'),
    ];
    bool cardDone(BoardCardRow c) {
      final b = boardById[c.boardId];
      if (b == null) return false;
      final cols = columnsOf(b);
      return cols.isNotEmpty && cols.last.$1 == c.columnId;
    }

    final top = <String>[
      for (final t in input.tasks.where((t) => t.isTop3 && !t.done).toList()
        ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.title, b.title, a.id, b.id)))
        '- ${_clean(t.title)}',
      for (final c in input.boardCards.where(
        (c) => c.isTop3 && !cardDone(c) && !input.archivedBoardIds.contains(c.boardId) && boardById.containsKey(c.boardId),
      ).toList()
        ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.title, b.title, a.id, b.id)))
        '- ${_clean(c.title)} (${l.dataSumOnBoard(_clean(boardById[c.boardId]!.name))})',
    ];
    md.sub(l.dataSumTop3Title, top);

    md.sub(l.dataSumBoardsTitle, [
      for (final b in boards)
        () {
          final cards = input.boardCards.where((c) => c.boardId == b.id).toList();
          final cols = columnsOf(b);
          final known = {for (final c in cols) c.$1};
          final counts = [
            for (final (id, label) in cols) '${_clean(label)} ${cards.where((c) => c.columnId == id).length}',
            if (cards.any((c) => !known.contains(c.columnId)))
              '${l.dataSumOther} ${cards.where((c) => !known.contains(c.columnId)).length}',
          ];
          final name = b.country == null || b.country!.trim().isEmpty ? _clean(b.name) : '${_clean(b.name)} (${_clean(b.country)})';
          return '- $name: ${counts.join(_sep)}';
        }(),
    ]);

    final projects = input.projects.where((p) => p.status != ProjectStatus.done).toList()
      ..sort((a, b) {
        final s = a.status.index.compareTo(b.status.index);
        return s != 0 ? s : _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id);
      });
    md.sub(l.dataSumProjectsTitle, [
      for (final p in projects)
        () {
          final items = input.projectItems.where((i) => i.projectId == p.id).toList();
          final status = p.status == ProjectStatus.paused ? l.dataSumStatusPaused : l.dataSumStatusActive;
          return '- ${_join([
            '${_clean(p.name)} ($status)',
            if (items.isNotEmpty) l.dataSumDoneOf('${items.where((i) => i.done).length}', '${items.length}'),
            if (p.deadline != null) l.dataSumDeadline(isoDay(p.deadline!)),
          ])}';
        }(),
    ]);
    return md.text;
  }

  // ------------------------------------------------------------- growth --

  String _growth(SummaryInput input) {
    final goals = input.learningGoals.where((g) => g.active).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    return [
      for (final g in goals)
        () {
          final logs = input.goalLogs.where((x) => x.goalId == g.id);
          final current = g.initial + logs.fold<double>(0, (a, x) => a + x.amount);
          final recent = logs.where((x) => _within(x.at, window)).fold<double>(0, (a, x) => a + x.amount);
          final unit = _clean(g.unit);
          final pct = g.target > 0 && g.target.isFinite ? (current * 100 / g.target).round() : null;
          return '- ${_join([
            '${_clean(g.name)}: ${l.dataSumProgress(_num(current), _num(g.target), unit)}'.trim() + (pct == null ? '' : ' ($pct%)'),
            if (recent != 0) l.dataSumRecentGain('${recent > 0 ? '+' : ''}${_num(recent)}', _windowLabel(window)),
            if (g.deadline != null) l.dataSumBy(isoDay(g.deadline!)),
          ])}';
        }(),
    ].join('\n');
  }

  // --------------------------------------------------------------- body --

  String _body(SummaryInput input) {
    final md = _Md();
    final weekdays = l.dataSumWeekdays.split(',');
    String dayNames(List<int> days) => _list([
      for (final d in (days.toSet().toList()..sort()))
        if (d >= 1 && d <= 7 && weekdays.length == 7) weekdays[d - 1].trim(),
    ]);
    final exercises = input.exercises.where((e) => e.active).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    md.sub(l.dataSumExercisePlanTitle, [
      for (final e in exercises)
        '- ${_clean(e.name)}: ${_join([
          if (e.weekdays.isNotEmpty) dayNames(e.weekdays),
          if (e.sets != null && e.reps != null) '${e.sets}×${e.reps}' else if (e.sets != null) l.dataSumSets('${e.sets}'),
          if (e.durationMin != null) l.dataSumMinutes('${e.durationMin}'),
          if (e.weight != null) l.dataSumKg(_num(e.weight!)),
        ])}'.replaceFirst(RegExp(r': $'), ''),
    ]);

    final recent = <String>[];
    final workouts = input.workoutLogs.where((w) => _within(w.at, window)).toList();
    if (workouts.isNotEmpty) {
      final minutes = workouts.fold<int>(0, (a, w) => a + (w.durationMin ?? 0));
      recent.add('- ${_join([l.dataSumWorkouts('${workouts.length}'), if (minutes > 0) l.dataSumMinutes('$minutes')])}');
    }
    final fasts = input.fastingSessions.where((f) => f.end != null && _within(f.start, window)).toList();
    if (fasts.isNotEmpty) {
      final hours = _avg(fasts.map((f) => f.end!.difference(f.start).inMinutes / 60))!;
      final target = (List.of(fasts)..sort((a, b) => b.start.compareTo(a.start))).first.targetHours;
      recent.add('- ${_join([l.dataSumFasting('${fasts.length}', _num(hours)), l.dataSumTargetHours(_num(target))])}');
    }
    final water = input.waterLogs.where((w) => _within(w.at, shortWindow)).toList();
    if (water.isNotEmpty) {
      final avg = (water.fold<int>(0, (a, w) => a + w.ml) / shortWindow).round();
      recent.add(
        '- ${_join([
          l.dataSumWater(_windowLabel(shortWindow), '$avg'),
          if (input.waterTargetMl != null) l.dataSumTargetMl('${input.waterTargetMl}'),
        ])}',
      );
    }
    md.sub(_windowLabel(window), recent);

    final avoid = List.of(input.avoidItems)
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.body, b.body, a.id, b.id));
    md.sub(l.dataSumAvoidTitle, [
      for (final a in avoid)
        a.reason == null || a.reason!.trim().isEmpty ? '- ${_clean(a.body)}' : '- ${_clean(a.body)} — ${_clean(a.reason)}',
    ]);
    return md.text;
  }

  // ------------------------------------------------------------- travel --

  String _travel(SummaryInput input) {
    final md = _Md();
    final trips = input.trips
        .where((t) => t.status != TripStatus.done && (t.endDate == null || !_day(t.endDate!).isBefore(_today)))
        .toList()
      ..sort((a, b) {
        final sa = a.startDate, sb = b.startDate;
        if (sa != null && sb != null && sa != sb) return sa.compareTo(sb);
        if (sa == null && sb != null) return 1;
        if (sa != null && sb == null) return -1;
        return _bySortThenName(a.sortOrder, b.sortOrder, a.destination, b.destination, a.id, b.id);
      });
    md.sub(l.dataSumTripsTitle, [
      for (final t in trips)
        '- ${_join([
          t.country == null || t.country!.trim().isEmpty ? _clean(t.destination) : '${_clean(t.destination)} (${_clean(t.country)})',
          if (t.startDate != null || t.endDate != null)
            '${t.startDate == null ? '…' : isoDay(t.startDate!)} → ${t.endDate == null ? '…' : isoDay(t.endDate!)}',
          t.status == TripStatus.active ? l.dataSumTripUnderWay : l.dataSumTripPlanned,
        ])}',
    ]);

    final docs = List.of(input.travelDocuments)
      ..sort((a, b) {
        final ea = a.expiry, eb = b.expiry;
        if (ea != null && eb != null && ea != eb) return ea.compareTo(eb);
        if (ea == null && eb != null) return 1;
        if (ea != null && eb == null) return -1;
        return _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id);
      });
    md.sub(l.dataSumDocumentsTitle, [
      for (final d in docs)
        () {
          final e = d.expiry;
          if (e == null) return '- ${_clean(d.name)}: ${l.dataSumNoExpiry}';
          final days = _daysFromToday(e);
          return days < 0
              ? '- ${_clean(d.name)}: ${l.dataSumExpired(isoDay(e))}'
              : '- ${_clean(d.name)}: ${l.dataSumExpiresIn(isoDay(e), '$days')}';
        }(),
    ]);
    return md.text;
  }

  // ------------------------------------------------------------- custom --

  String _custom(SummaryInput input) {
    final md = _Md();
    final modules = input.customModules.where((m) => !m.archived).toList()
      ..sort((a, b) => _bySortThenName(a.sortOrder, b.sortOrder, a.name, b.name, a.id, b.id));
    for (final m in modules.take(maxModules)) {
      final entries = input.customEntries.where((e) => e.moduleId == m.id).toList();
      final kind = m.kind == CustomModuleKind.list ? l.dataSumModuleList : l.dataSumModuleTracker;
      final lines = <String>[];
      if (m.kind == CustomModuleKind.list) {
        final done = entries.where((e) => e.done).length;
        lines.add('- ${_join([l.dataSumOpen('${entries.length - done}'), l.dataSumDone('$done')])}');
      } else {
        final recent = entries.where((e) => _within(e.at, window)).toList();
        final last = entries.isEmpty ? null : entries.map((e) => e.at).reduce((a, b) => a.isAfter(b) ? a : b);
        lines.add(
          '- ${_join([
            l.dataSumEntries('${entries.length}'),
            l.dataSumInWindow('${recent.length}', _windowLabel(window)),
            if (last != null) l.dataSumLastOn(isoDay(last)),
          ])}',
        );
        var shown = 0;
        for (final f in _fields(m.fields)) {
          if (shown >= maxFieldsPerModule) break;
          final line = _fieldLine(f, recent);
          if (line != null) {
            lines.add('- $line');
            shown++;
          }
        }
      }
      md.sub('${_clean(m.name)} ($kind)', lines);
    }
    if (modules.length > maxModules) md.lines(['- ${l.dataSumMore('${modules.length - maxModules}')}']);
    return md.text;
  }

  static List<_Field> _fields(List<Object?> raw) => [
    for (final f in raw)
      if (f is Map && f['id'] is String && f['hidden'] != true)
        _Field(
          id: f['id'] as String,
          label: '${f['label'] ?? f['name'] ?? f['id']}',
          type: FieldType.values.where((t) => t.name == f['type']).firstOrNull,
          unit: f['unit'] is String ? f['unit'] as String : null,
          options: {
            if (f['options'] is List)
              for (final o in f['options'] as List)
                if (o is Map && o['id'] != null) '${o['id']}': '${o['label'] ?? o['name'] ?? o['id']}'
                else if (o is String) o: o,
          },
        ),
  ];

  String? _fieldLine(_Field f, List<CustomEntryRow> entries) {
    final label = f.unit == null || f.unit!.trim().isEmpty ? _clean(f.label) : '${_clean(f.label)} (${_clean(f.unit)})';
    switch (f.type) {
      case FieldType.number || FieldType.rating || FieldType.currency:
        final values = <double>[];
        for (final e in entries) {
          final v = e.entryValues[f.id];
          final n = switch (v) {
            num n => n.toDouble(),
            Map m when m['milli'] is num => (m['milli'] as num) / 1000,
            Map m when m['amount'] is num => (m['amount'] as num).toDouble(),
            String s => double.tryParse(s),
            _ => null,
          };
          if (n != null && n.isFinite) values.add(n);
        }
        if (values.isEmpty) return null;
        final total = values.fold<double>(0, (a, b) => a + b);
        return '$label: ${_join([
          l.dataSumAverage(_num(total / values.length)),
          l.dataSumMin(_num(values.reduce(math.min))),
          l.dataSumMax(_num(values.reduce(math.max))),
          if (f.type != FieldType.rating) l.dataSumSum(_num(total)),
        ])}';
      case FieldType.checkbox:
        final answered = entries.where((e) => e.entryValues[f.id] is bool).toList();
        if (answered.isEmpty) return null;
        return '$label: ${l.dataSumTicked('${answered.where((e) => e.entryValues[f.id] == true).length}', '${answered.length}')}';
      case FieldType.singleSelect || FieldType.multiSelect:
        final picks = <String>[];
        for (final e in entries) {
          final v = e.entryValues[f.id];
          for (final id in v is List ? v : [v]) {
            if (id == null) continue;
            picks.add(f.options['$id'] ?? '$id');
          }
        }
        final top = _top(picks);
        return top.isEmpty ? null : '$label: $top';
      case FieldType.text || FieldType.date || FieldType.time || null:
        return null;
    }
  }
}

class _Field {
  const _Field({required this.id, required this.label, required this.type, required this.unit, required this.options});

  final String id;
  final String label;
  final FieldType? type;
  final String? unit;
  final Map<String, String> options;
}

/// Accumulates `### sub-sections` separated by blank lines; empty
/// sub-sections are dropped.
class _Md {
  final List<String> _parts = [];

  void sub(String title, List<String> lines) {
    if (lines.isEmpty) return;
    _parts.add(['### $title', ...lines].join('\n'));
  }

  void lines(List<String> lines) {
    if (lines.isEmpty) return;
    _parts.add(lines.join('\n'));
  }

  String get text => _parts.join('\n\n');
}
