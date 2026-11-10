/// «شو صار اليوم؟» – his own day, read back to him from his own data.
///
/// Offline and with no AI call: everything here is counted out of his
/// database. The engine produces facts ([DaySummaryLine]); the sentences are
/// `DayChatTexts`'s, in his language and his digits, the way Part 3's
/// `AiSummaryBuilder` keeps its own wording in one place – except that this
/// one is for **him** to read, not for a machine.
///
/// Pure Dart.
library;

import 'package:meta/meta.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../custom_modules/domain/field_values.dart';
import '../../prayer_tracker/domain/tracker_prayers.dart';
import 'day_chat_journal.dart';
import 'day_chat_vocabulary.dart';

/// What the summary reads. The data layer fills it
/// ([DayChatService.summaryInput]); a test can build it by hand.
@immutable
class DaySummaryInput {
  const DaySummaryInput({
    required this.day,
    required this.now,
    this.transactions = const [],
    this.wallets = const [],
    this.foodLogs = const [],
    this.workouts = const [],
    this.water = const [],
    this.waterTargetMl,
    this.pain = const [],
    this.moods = const [],
    this.prayers = const [],
    this.tasks = const [],
    this.contacts = const [],
    this.people = const [],
    this.moduleEntries = const [],
    this.modules = const [],
    this.chat,
    this.baseCurrency,
  });

  final DateTime day;
  final DateTime now;
  final List<TransactionRow> transactions;
  final List<WalletRow> wallets;
  final List<FoodLogRow> foodLogs;
  final List<WorkoutLogRow> workouts;
  final List<WaterLogRow> water;
  final int? waterTargetMl;
  final List<PainEntryRow> pain;
  final List<MoodEntryRow> moods;
  final List<PrayerLogRow> prayers;
  final List<TaskRow> tasks;
  final List<ContactLogRow> contacts;
  final List<PersonRow> people;
  final List<CustomEntryRow> moduleEntries;
  final List<DayChatModule> modules;

  /// The chat of that day (how much of it he filed himself).
  final DayChatDay? chat;

  final String? baseCurrency;
}

/// What one line of the summary is about.
enum DaySummaryTopic { prayers, money, meals, water, workouts, pain, mood, tasks, people, modules, chat }

/// One fact of his day. Every field is optional on purpose: the sentence
/// decides what to say with what it got.
@immutable
class DaySummaryLine {
  const DaySummaryLine({
    required this.topic,
    this.count = 0,
    this.second = 0,
    this.third = 0,
    this.amountMilli,
    this.secondAmountMilli,
    this.currency,
    this.value,
    this.target,
    this.names = const [],
    this.more = 0,
  });

  final DaySummaryTopic topic;

  /// The main count: meals, workouts, prayers prayed, tasks done, contacts,
  /// module entries, pieces filed from the chat.
  final int count;

  /// A second count: prayers at the mosque, tasks still open.
  final int second;

  /// A third count: prayers missed.
  final int third;

  /// Money out and money in, in [currency].
  final int? amountMilli;
  final int? secondAmountMilli;
  final String? currency;

  /// A measured value: millilitres of water, minutes of training, the worst
  /// pain score, the mood.
  final double? value;

  /// What the value was aimed at (the water target).
  final double? target;

  /// His own words: the foods, the exercises, the people, the modules, the
  /// tasks still open.
  final List<String> names;

  /// How many more names there were than [names] holds.
  final int more;
}

/// His day, in facts.
@immutable
class DaySummary {
  const DaySummary({required this.day, this.lines = const []});

  final DateTime day;

  /// In the order they are read out.
  final List<DaySummaryLine> lines;

  /// Nothing happened (or nothing was logged) – the summary says exactly
  /// that instead of pretending.
  bool get isEmpty => lines.isEmpty;

  DaySummaryLine? line(DaySummaryTopic topic) {
    for (final l in lines) {
      if (l.topic == topic) return l;
    }
    return null;
  }
}

class DaySummaryBuilder {
  DaySummaryBuilder({this.maxNames = 3});

  /// How many of his own words one line names before it says «وغيرها».
  final int maxNames;

  DaySummary build(DaySummaryInput input) {
    final lines = <DaySummaryLine>[
      ?_prayers(input),
      ..._money(input),
      ?_meals(input),
      ?_water(input),
      ?_workouts(input),
      ?_pain(input),
      ?_mood(input),
      ?_tasks(input),
      ?_people(input),
      ?_modules(input),
      ?_chat(input),
    ];
    return DaySummary(day: input.day, lines: lines);
  }

  // ------------------------------------------------------------- topics --

  DaySummaryLine? _prayers(DaySummaryInput input) {
    final obligatory = [
      for (final p in input.prayers)
        if (TrackerPrayers.isObligatory(p.prayer)) p,
    ];
    if (obligatory.isEmpty) return null;
    final prayed = obligatory.where((p) => p.status.counts).length;
    final mosque = obligatory.where((p) => p.atMosque).length;
    final missed = obligatory.where((p) => p.status == PrayerStatus.missed).length;
    final voluntary = input.prayers.length - obligatory.length;
    return DaySummaryLine(
      topic: DaySummaryTopic.prayers,
      count: prayed,
      second: mosque,
      third: missed,
      value: voluntary.toDouble(),
    );
  }

  List<DaySummaryLine> _money(DaySummaryInput input) {
    if (input.transactions.isEmpty) return const [];
    final currencyOf = {for (final w in input.wallets) w.id: w.currency};
    final out = <String, (int, int, int)>{};
    for (final t in input.transactions) {
      if (t.kind != TxKind.expense && t.kind != TxKind.income) continue;
      final currency = currencyOf[t.walletId] ?? input.baseCurrency ?? '';
      final (spent, got, n) = out[currency] ?? (0, 0, 0);
      out[currency] = t.kind == TxKind.expense
          ? (spent + t.amountMilli.abs(), got, n + 1)
          : (spent, got + t.amountMilli.abs(), n + 1);
    }
    final lines = [
      for (final e in out.entries)
        DaySummaryLine(
          topic: DaySummaryTopic.money,
          currency: e.key.isEmpty ? null : e.key,
          amountMilli: e.value.$1,
          secondAmountMilli: e.value.$2,
          count: e.value.$3,
        ),
    ];
    lines.sort((a, b) => (b.amountMilli ?? 0).compareTo(a.amountMilli ?? 0));
    return lines;
  }

  DaySummaryLine? _meals(DaySummaryInput input) {
    if (input.foodLogs.isEmpty) return null;
    final names = _names([for (final f in input.foodLogs) f.name]);
    return DaySummaryLine(
      topic: DaySummaryTopic.meals,
      count: input.foodLogs.length,
      names: names.$1,
      more: names.$2,
    );
  }

  DaySummaryLine? _water(DaySummaryInput input) {
    if (input.water.isEmpty) return null;
    var ml = 0;
    for (final w in input.water) {
      ml += w.ml;
    }
    final target = input.waterTargetMl;
    return DaySummaryLine(
      topic: DaySummaryTopic.water,
      count: input.water.length,
      value: ml.toDouble(),
      target: target == null || target <= 0 ? null : target.toDouble(),
    );
  }

  DaySummaryLine? _workouts(DaySummaryInput input) {
    if (input.workouts.isEmpty) return null;
    var minutes = 0;
    for (final w in input.workouts) {
      minutes += w.durationMin ?? 0;
    }
    final names = _names([for (final w in input.workouts) w.name]);
    return DaySummaryLine(
      topic: DaySummaryTopic.workouts,
      count: input.workouts.length,
      value: minutes == 0 ? null : minutes.toDouble(),
      names: names.$1,
      more: names.$2,
    );
  }

  DaySummaryLine? _pain(DaySummaryInput input) {
    if (input.pain.isEmpty) return null;
    var worst = input.pain.first;
    for (final p in input.pain) {
      if (p.score > worst.score) worst = p;
    }
    final names = _names([
      for (final p in input.pain) ...p.locations,
    ]);
    return DaySummaryLine(
      topic: DaySummaryTopic.pain,
      count: input.pain.length,
      value: worst.score.toDouble(),
      names: names.$1,
      more: names.$2,
    );
  }

  DaySummaryLine? _mood(DaySummaryInput input) {
    final scored = [
      for (final m in input.moods)
        if (m.mood != null) m,
    ];
    if (scored.isEmpty) return null;
    scored.sort((a, b) => a.at.compareTo(b.at));
    return DaySummaryLine(
      topic: DaySummaryTopic.mood,
      count: scored.length,
      value: scored.last.mood!.toDouble(),
    );
  }

  DaySummaryLine? _tasks(DaySummaryInput input) {
    if (input.tasks.isEmpty) return null;
    final done = [
      for (final t in input.tasks)
        if (t.done) t,
    ];
    final open = [
      for (final t in input.tasks)
        if (!t.done) t,
    ];
    final names = _names([for (final t in open) t.title]);
    return DaySummaryLine(
      topic: DaySummaryTopic.tasks,
      count: done.length,
      second: open.length,
      names: names.$1,
      more: names.$2,
    );
  }

  DaySummaryLine? _people(DaySummaryInput input) {
    if (input.contacts.isEmpty) return null;
    final byId = {for (final p in input.people) p.id: p.name};
    final names = _names([
      for (final c in input.contacts) ?byId[c.personId],
    ]);
    return DaySummaryLine(
      topic: DaySummaryTopic.people,
      count: input.contacts.length,
      names: names.$1,
      more: names.$2,
    );
  }

  DaySummaryLine? _modules(DaySummaryInput input) {
    if (input.moduleEntries.isEmpty) return null;
    final byId = {for (final m in input.modules) m.id: m};
    final labels = <String>[];
    for (final e in input.moduleEntries) {
      final m = byId[e.moduleId];
      if (m == null) continue;
      final value = _firstValue(m, e);
      labels.add(value == null ? m.name : '${m.name} $value');
    }
    final names = _names(labels);
    return DaySummaryLine(
      topic: DaySummaryTopic.modules,
      count: input.moduleEntries.length,
      names: names.$1,
      more: names.$2,
    );
  }

  DaySummaryLine? _chat(DaySummaryInput input) {
    final chat = input.chat;
    if (chat == null) return null;
    final applied = chat.applied.length;
    if (applied == 0 && chat.lines.isEmpty) return null;
    return DaySummaryLine(topic: DaySummaryTopic.chat, count: applied, second: chat.lines.length);
  }

  // ------------------------------------------------------------ helpers --

  /// The first value of an entry worth reading out («١٢٠»).
  static String? _firstValue(DayChatModule module, CustomEntryRow entry) {
    for (final f in module.fields) {
      final raw = entry.entryValues[f.id];
      if (raw == null) continue;
      final n = FieldValues.number(raw);
      if (n != null) return n == n.roundToDouble() ? '${n.toInt()}' : '$n';
      final text = FieldValues.text(raw);
      if (text != null && text.trim().isNotEmpty) return text.trim();
    }
    return null;
  }

  /// At most [maxNames] of his own words, each once, plus how many more
  /// there were.
  (List<String>, int) _names(Iterable<String> all) {
    final seen = <String>[];
    for (final raw in all) {
      final name = raw.trim();
      if (name.isEmpty || seen.contains(name)) continue;
      seen.add(name);
    }
    if (seen.length <= maxNames) return (seen, 0);
    return (seen.take(maxNames).toList(), seen.length - maxNames);
  }
}
