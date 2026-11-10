/// Every sentence the daily chat says, in his language and his digits.
///
/// Three rules it keeps, because the chat screen on top of it must never
/// break them:
///
/// * a proposal says **what would be written, in his own words** – never a
///   kind name on its own, never a code;
/// * a gap is a sentence he can act on: it names what is missing and, where
///   it helps, quotes his own words («ما لقيت مهمة باسم «غسيل السيارة»»);
/// * a refused health sentence always says why: Madar tracks and charts, and
///   medicine is his doctor's.
///
/// The day summary («شو صار اليوم؟») is read out of the facts
/// [DaySummaryBuilder] counted – no AI, no network, and nothing that is not
/// already in his database.
library;

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart' show initializeDateFormatting;

import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../ai_bridge/domain/health_guard.dart';
import '../../money/budget/presentation/budget_format.dart';
import '../../prayer_tracker/presentation/tracker_labels.dart';
import '../domain/day_chat_piece.dart';
import '../domain/day_summary.dart';

class DayChatTexts {
  DayChatTexts(this.l, this.fmt, {BudgetFormat? money}) : money = money ?? BudgetFormat(fmt) {
    // A card can name a time of day («أكلت منسف الساعة ٢»), and the engine
    // is used outside the widget tree too (a notification, a test), where
    // nothing has loaded the date symbols yet.
    if (!_dateSymbols) {
      _dateSymbols = true;
      initializeDateFormatting();
    }
  }

  factory DayChatTexts.of(BuildContext context) => DayChatTexts(L10n.of(context), context.formatter);

  static bool _dateSymbols = false;

  final L10n l;
  final MadarFormatter fmt;

  /// Amounts in his currencies and his digits (the Money screens' own
  /// formatter).
  final BudgetFormat money;

  /// A name he typed, isolated so it reads correctly inside a sentence.
  String name(String value) => fmt.isolate(value.trim());

  String _n(num value) => fmt.formatNumber(value, maxDecimals: 2);

  String _int(int value) => fmt.formatInt(value);

  /// The short name of a kind («مصروف», «صلاة»).
  String kind(DayChatKind kind) => switch (kind) {
    DayChatKind.expense => l.dayChatKindExpense,
    DayChatKind.income => l.dayChatKindIncome,
    DayChatKind.meal => l.dayChatKindMeal,
    DayChatKind.workout => l.dayChatKindWorkout,
    DayChatKind.water => l.dayChatKindWater,
    DayChatKind.pain => l.dayChatKindPain,
    DayChatKind.sign => l.dayChatKindSign,
    DayChatKind.prayer => l.dayChatKindPrayer,
    DayChatKind.taskDone => l.dayChatKindTaskDone,
    DayChatKind.taskTodo => l.dayChatKindTaskTodo,
    DayChatKind.mood => l.dayChatKindMood,
    DayChatKind.note => l.dayChatKindNote,
    DayChatKind.contact => l.dayChatKindContact,
    DayChatKind.moduleEntry => l.dayChatKindModule,
    DayChatKind.unread => l.dayChatKindUnread,
  };

  /// What applying this piece would write, in his own words – the one line
  /// of the card he confirms.
  String title(DayChatPiece piece) {
    final fact = piece.fact;
    switch (fact) {
      case MoneyFact():
        final amount = money.money(fact.amountMilli, fact.currency);
        final note = fact.note.trim();
        // No amount at all: the card says so in words. Formatting a zero
        // would put a number in his mouth that he never said.
        if (fact.amountMilli <= 0) {
          if (fact.income) {
            return note.isEmpty ? l.dayChatTitleIncomeUnknownBare : l.dayChatTitleIncomeUnknown(name(note));
          }
          return note.isEmpty ? l.dayChatTitleExpenseUnknownBare : l.dayChatTitleExpenseUnknown(name(note));
        }
        if (fact.income) {
          return note.isEmpty ? l.dayChatTitleIncomeBare(amount) : l.dayChatTitleIncome(amount, name(note));
        }
        return note.isEmpty ? l.dayChatTitleExpenseBare(amount) : l.dayChatTitleExpense(amount, name(note));
      case MealFact():
        final stated = piece.intent?.time != null;
        return stated
            ? l.dayChatTitleMealAt(name(fact.name), fmt.formatTime(fact.at))
            : l.dayChatTitleMeal(name(fact.name));
      case WorkoutFact():
        var text = fact.sets != null && fact.reps != null
            ? l.dayChatTitleWorkoutSets(name(fact.name), _int(fact.sets!), _int(fact.reps!))
            : l.dayChatTitleWorkout(name(fact.name));
        if (fact.weight != null) text = l.dayChatTitleWorkoutWeight(text, _n(fact.weight!));
        if (fact.durationMin != null) {
          text = fmt.localizeDigits(l.dayChatTitleWorkoutMinutes(text, fact.durationMin!));
        }
        return text;
      case WaterFact():
        return l.dayChatTitleWater(water(fact.ml));
      case PainFact():
        final where = fact.location?.trim();
        return where == null || where.isEmpty
            ? l.dayChatTitlePain(_int(fact.score))
            : l.dayChatTitlePainWhere(name(where), _int(fact.score));
      case MoodFact():
        return l.dayChatTitleMood(_int(fact.score));
      case PrayerFact():
        final prayer = l.trackerPrayerName(fact.prayer);
        return switch (fact.status) {
          PrayerStatus.missed => l.dayChatTitlePrayerMissed(prayer),
          PrayerStatus.qada => l.dayChatTitlePrayerQada(prayer),
          PrayerStatus.late => l.dayChatTitlePrayerLate(prayer),
          PrayerStatus.prayed => fact.atMosque
              ? l.dayChatTitlePrayerMosque(prayer)
              : fact.inJamaah
              ? l.dayChatTitlePrayerJamaah(prayer)
              : l.dayChatTitlePrayer(prayer),
        };
      case TaskDoneFact():
        return fact.taskId == null
            ? l.dayChatTitleTaskNew(name(fact.title))
            : l.dayChatTitleTaskDone(name(fact.title));
      case TaskTodoFact():
        final when = _when(fact);
        return when == null ? l.dayChatTitleTodo(name(fact.title)) : l.dayChatTitleTodoWhen(name(fact.title), when);
      case ContactFact():
        final person = name(fact.name);
        return switch (fact.channel) {
          ContactChannel.call => l.dayChatTitleCall(person),
          ContactChannel.visit => l.dayChatTitleVisit(person),
          ContactChannel.message => l.dayChatTitleMessage(person),
          ContactChannel.other => l.dayChatTitleContactOther(person),
        };
      case ModuleFact():
        final value = fact.value;
        if (piece.kind == DayChatKind.sign) {
          return l.dayChatTitleSign(name(fact.moduleName), value == null ? '' : _value(value));
        }
        return value == null || value == true
            ? l.dayChatTitleModuleTick(name(fact.moduleName))
            : l.dayChatTitleModule(name(fact.moduleName), _value(value));
      case NoteFact():
        return l.dayChatTitleNote(name(fact.text));
      case UnreadFact():
        return l.dayChatTitleUnread;
    }
  }

  /// Where the piece would land («بتنزل بالمصاري»).
  String where(DayChatPiece piece) => switch (piece.kind) {
    DayChatKind.expense || DayChatKind.income => l.dayChatWhereMoney,
    DayChatKind.meal => l.dayChatWhereFood,
    DayChatKind.workout || DayChatKind.water => l.dayChatWhereBody,
    DayChatKind.pain || DayChatKind.mood => l.dayChatWhereHealth,
    DayChatKind.prayer => l.dayChatWhereFaith,
    DayChatKind.taskDone || DayChatKind.taskTodo || DayChatKind.note => l.dayChatWhereTasks,
    DayChatKind.contact => l.dayChatWhereFamily,
    DayChatKind.moduleEntry => l.dayChatWhereModule(
      name(piece.fact is ModuleFact ? (piece.fact as ModuleFact).moduleName : ''),
    ),
    DayChatKind.sign || DayChatKind.unread => l.dayChatWhereNowhere,
  };

  /// What it could not resolve, as a sentence he can act on.
  String gap(DayChatGap gap) {
    final detail = gap.detail?.trim() ?? '';
    return switch (gap.kind) {
      DayChatGapKind.amount => l.dayChatGapAmount,
      DayChatGapKind.currency => l.dayChatGapCurrency(detail.isEmpty ? money.base : detail),
      DayChatGapKind.person => l.dayChatGapPerson(name(detail)),
      DayChatGapKind.food => l.dayChatGapFood(name(detail)),
      DayChatGapKind.exercise => l.dayChatGapExercise(name(detail)),
      DayChatGapKind.module => l.dayChatGapModule,
      DayChatGapKind.field => l.dayChatGapField(name(detail)),
      DayChatGapKind.value => l.dayChatGapValue(name(detail)),
      DayChatGapKind.measure => l.dayChatGapMeasure,
      DayChatGapKind.prayerName => l.dayChatGapPrayerName,
      DayChatGapKind.time => l.dayChatGapTime,
      DayChatGapKind.taskMatch => l.dayChatGapTaskMatch(name(detail)),
      DayChatGapKind.guard => l.dayChatGapGuard(name(detail)),
      DayChatGapKind.meaning => l.dayChatGapMeaning,
    };
  }

  /// Every gap of a piece, in order.
  List<String> gaps(DayChatPiece piece) => [for (final g in piece.gaps) gap(g)];

  /// Why a health sentence is only a note.
  String guard(HealthFlag flag) => l.dayChatGapGuard(name(flag.match));

  /// How sure the reader is, in one word.
  String confidence(double value) => value >= 0.8
      ? l.dayChatSure
      : value >= 0.5
      ? l.dayChatMaybe
      : l.dayChatUnsure;

  /// Millilitres the way the Body screens say them («٥٠٠ مل»).
  String water(int ml) => l.bodyMl(_int(ml));

  String? _when(TaskTodoFact fact) {
    final date = fact.date;
    final time = fact.time;
    if (date == null && time == null) return null;
    final parts = <String>[
      if (date != null) fmt.formatDate(date, style: MadarDateStyle.dayMonth),
      if (time != null) fmt.formatClock(int.parse(time.split(':').first), int.parse(time.split(':').last)),
    ];
    return parts.join(' · ');
  }

  String _value(Object value) => switch (value) {
    final num n => _n(n),
    true => l.cmodChecked,
    false => l.cmodUnchecked,
    _ => name('$value'),
  };

  // ------------------------------------------------------------ summary --

  /// «شو صار اليوم – ١٤ تشرين الأول».
  String summaryTitle(DateTime day) => l.dayChatSummaryTitle(fmt.formatDate(day, style: MadarDateStyle.medium));

  /// His day, line by line, in plain Jordanian Arabic. An empty day says so.
  ///
  /// Every count goes through [MadarFormatter.localizeDigits]: a plural
  /// picks its branch from the number, which `gen-l10n` then writes in
  /// Western digits – his digit setting has the last word.
  List<String> summary(DaySummary summary) {
    if (summary.isEmpty) return [l.dayChatSummaryEmpty];
    return [
      for (final line in summary.lines)
        for (final text in [?_line(line)]) fmt.localizeDigits(text),
    ];
  }

  String? _line(DaySummaryLine line) {
    final sep = l.dayChatListSep;
    String withNames(String text, DaySummaryLine line) {
      if (line.names.isEmpty) return text;
      final names = [for (final n in line.names) name(n)].join(sep);
      final more = line.more == 0 ? '' : ' ${l.dayChatSumMore(_int(line.more))}';
      return '$text ${l.dayChatSumWith(names)}$more';
    }

    switch (line.topic) {
      case DaySummaryTopic.prayers:
        final parts = <String>[
          l.dayChatSumPrayers(line.count),
          if (line.second > 0) l.dayChatSumPrayersMosque(line.second),
          if (line.third > 0) l.dayChatSumPrayersMissed(line.third),
          if ((line.value ?? 0) > 0) l.dayChatSumSunnah(line.value!.round()),
        ];
        return parts.join(sep);
      case DaySummaryTopic.money:
        final parts = <String>[
          if ((line.amountMilli ?? 0) > 0) l.dayChatSumSpent(money.money(line.amountMilli!, line.currency)),
          if ((line.secondAmountMilli ?? 0) > 0)
            l.dayChatSumReceived(money.money(line.secondAmountMilli!, line.currency)),
        ];
        return parts.isEmpty ? null : parts.join(sep);
      case DaySummaryTopic.meals:
        return withNames(l.dayChatSumMeals(line.count), line);
      case DaySummaryTopic.water:
        final ml = (line.value ?? 0).round();
        final target = line.target;
        return target == null
            ? l.dayChatSumWater(water(ml))
            : l.dayChatSumWaterTarget(water(ml), water(target.round()));
      case DaySummaryTopic.workouts:
        var text = l.dayChatSumWorkouts(line.count);
        if (line.value != null) text = '$text$sep${l.dayChatSumMinutes(line.value!.round())}';
        return withNames(text, line);
      case DaySummaryTopic.pain:
        final score = _int((line.value ?? 0).round());
        return line.names.isEmpty
            ? l.dayChatSumPain(score)
            : l.dayChatSumPainWhere(score, [for (final n in line.names) name(n)].join(sep));
      case DaySummaryTopic.mood:
        return l.dayChatSumMood(_int((line.value ?? 0).round()));
      case DaySummaryTopic.tasks:
        final parts = <String>[
          l.dayChatSumTasksDone(line.count),
          if (line.second > 0) withNames(l.dayChatSumTasksOpen(line.second), line),
        ];
        return parts.join(sep);
      case DaySummaryTopic.people:
        return withNames(l.dayChatSumPeople(line.count), line);
      case DaySummaryTopic.modules:
        return withNames(l.dayChatSumModules(line.count), line);
      case DaySummaryTopic.chat:
        return l.dayChatSumChat(line.count);
    }
  }
}
