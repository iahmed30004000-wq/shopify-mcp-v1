/// What one piece of a typed day is: the fact it would write, where in his
/// own words it came from, how sure the reader is, and what it could not
/// resolve.
///
/// Pure Dart (no Flutter): the reader, the segmenter and the day summary are
/// engines; the screens and the writes live on top of them.
library;

import 'package:meta/meta.dart';

import '../../../core/domain/enums.dart';
import '../../../core/interaction/quick_add/parser.dart';
import '../../ai_bridge/domain/health_guard.dart';

/// Where in the text he typed a piece came from: `[start, end)` in code
/// units of the **raw** text, exactly as he typed it (no folding, no
/// trimming, no digit conversion). The chat screen underlines this range.
@immutable
class DayChatSpan {
  const DayChatSpan(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start;
  bool get isEmpty => end <= start;

  /// His own words of this span.
  String of(String raw) => raw.substring(start.clamp(0, raw.length), end.clamp(0, raw.length));

  @override
  bool operator ==(Object other) => other is DayChatSpan && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'DayChatSpan($start..$end)';
}

/// Where a piece would land.
enum DayChatKind {
  /// Money out («صرفت ٥ دنانير قهوة»).
  expense,

  /// Money in («قبضت الراتب»).
  income,

  /// Something eaten («أكلت منسف»).
  meal,

  /// A training set («تمرين صدر ٤×١٢»).
  workout,

  /// Water («شربت كاسة مي»).
  water,

  /// Pain with a score («وجع الركبة ٦»).
  pain,

  /// A number for a sign he tracks, but no tracker of his matched it yet.
  sign,

  /// A prayer («صليت العصر بالمسجد»).
  prayer,

  /// A task of his that is finished («خلصت تقرير الشغل»).
  taskDone,

  /// Something still to do («لازم أروح للبنك بكرا»).
  taskTodo,

  /// How he felt («مزاجي ٤»).
  mood,

  /// His own words kept as a note – also where a dose or a diagnosis lands.
  note,

  /// He called / visited / messaged somebody.
  contact,

  /// A value for a module he built himself.
  moduleEntry,

  /// Read but not understood: «ما فهمت هاي». Never dropped silently.
  unread,
}

extension DayChatKindInfo on DayChatKind {
  /// The planet a piece of this kind belongs to (the note and the unread
  /// piece belong to none until he says so).
  String? get planetKey => switch (this) {
    DayChatKind.expense || DayChatKind.income => 'money',
    DayChatKind.meal || DayChatKind.water || DayChatKind.workout => 'body',
    DayChatKind.pain || DayChatKind.mood || DayChatKind.sign => 'health',
    DayChatKind.prayer => 'faith',
    DayChatKind.contact => 'family',
    DayChatKind.taskDone || DayChatKind.taskTodo || DayChatKind.note || DayChatKind.moduleEntry => null,
    DayChatKind.unread => null,
  };
}

/// Something the reader could not resolve on its own. A piece with gaps is
/// still shown: he fills the gap, or corrects the piece, or throws it away.
enum DayChatGapKind {
  /// No amount at all («صرفت على القهوة»).
  amount,

  /// An amount with no currency said – the base currency is assumed.
  currency,

  /// The person is not in his family list yet (applying creates them).
  person,

  /// The food is not in his library yet (it is logged by name).
  food,

  /// The exercise is not in his list yet (it is logged by name).
  exercise,

  /// A number for a sign, but no tracker of his is named by this text.
  module,

  /// The module matched, but not which of its fields the number is for.
  field,

  /// A tracker field that needs a value this text did not give.
  value,

  /// Sets and reps or a weight that could not be read.
  measure,

  /// A prayer word with no prayer named.
  prayerName,

  /// A time of day that was guessed, not stated.
  time,

  /// «خلصت …» with no open task of his by that name.
  taskMatch,

  /// A dose, a diagnosis or a treatment claim: kept as his own note only.
  guard,

  /// Nothing in this piece could be read.
  meaning,
}

/// One gap, with the words it is about (for «ما لقيت "رنا" بأهلك»).
@immutable
class DayChatGap {
  const DayChatGap(this.kind, [this.detail]);

  final DayChatGapKind kind;

  /// His own words this gap is about, or the guard's match.
  final String? detail;

  @override
  bool operator ==(Object other) => other is DayChatGap && other.kind == kind && other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, detail);

  @override
  String toString() => 'DayChatGap(${kind.name}${detail == null ? '' : ', $detail'})';
}

// ------------------------------------------------------------------ facts --

/// The typed payload of a piece: exactly what applying it would write.
sealed class DayChatFact {
  const DayChatFact();
}

class MoneyFact extends DayChatFact {
  const MoneyFact({required this.amountMilli, required this.at, this.currency, this.note = '', this.income = false});

  final int amountMilli;
  final String? currency;
  final String note;
  final DateTime at;
  final bool income;

  MoneyFact copyWith({int? amountMilli, String? currency, String? note, DateTime? at}) => MoneyFact(
    amountMilli: amountMilli ?? this.amountMilli,
    currency: currency ?? this.currency,
    note: note ?? this.note,
    at: at ?? this.at,
    income: income,
  );
}

class MealFact extends DayChatFact {
  const MealFact({required this.name, required this.at, this.foodId, this.portion, this.unit, this.note});

  final String name;

  /// Set when the food is already in his library.
  final String? foodId;
  final double? portion;
  final String? unit;
  final String? note;
  final DateTime at;

  MealFact copyWith({String? name, DateTime? at, double? portion, String? unit, String? foodId}) => MealFact(
    name: name ?? this.name,
    at: at ?? this.at,
    foodId: foodId ?? this.foodId,
    portion: portion ?? this.portion,
    unit: unit ?? this.unit,
    note: note,
  );
}

class WorkoutFact extends DayChatFact {
  const WorkoutFact({
    required this.name,
    required this.at,
    this.exerciseId,
    this.sets,
    this.reps,
    this.weight,
    this.durationMin,
  });

  final String name;

  /// Set when the exercise is already in his plan.
  final String? exerciseId;
  final int? sets;
  final int? reps;
  final double? weight;
  final int? durationMin;
  final DateTime at;

  WorkoutFact copyWith({String? name, int? sets, int? reps, double? weight, int? durationMin, DateTime? at}) =>
      WorkoutFact(
        name: name ?? this.name,
        at: at ?? this.at,
        exerciseId: exerciseId,
        sets: sets ?? this.sets,
        reps: reps ?? this.reps,
        weight: weight ?? this.weight,
        durationMin: durationMin ?? this.durationMin,
      );
}

class WaterFact extends DayChatFact {
  const WaterFact({required this.ml, required this.at});

  final int ml;
  final DateTime at;

  WaterFact copyWith({int? ml, DateTime? at}) => WaterFact(ml: ml ?? this.ml, at: at ?? this.at);
}

class PainFact extends DayChatFact {
  const PainFact({required this.score, required this.at, this.location});

  /// 0–10, as he said it.
  final int score;
  final String? location;
  final DateTime at;

  PainFact copyWith({int? score, String? location, DateTime? at}) =>
      PainFact(score: score ?? this.score, location: location ?? this.location, at: at ?? this.at);
}

class MoodFact extends DayChatFact {
  const MoodFact({required this.score, required this.at, this.note});

  /// 1–5.
  final int score;
  final String? note;
  final DateTime at;

  MoodFact copyWith({int? score, String? note, DateTime? at}) =>
      MoodFact(score: score ?? this.score, note: note ?? this.note, at: at ?? this.at);
}

class PrayerFact extends DayChatFact {
  const PrayerFact({
    required this.prayer,
    required this.day,
    this.status = PrayerStatus.prayed,
    this.atMosque = false,
    this.inJamaah = false,
  });

  final Prayer prayer;
  final PrayerStatus status;
  final bool atMosque;
  final bool inJamaah;

  /// The prayer day (local midnight) the log belongs to.
  final DateTime day;

  PrayerFact copyWith({Prayer? prayer, PrayerStatus? status, bool? atMosque, bool? inJamaah, DateTime? day}) =>
      PrayerFact(
        prayer: prayer ?? this.prayer,
        day: day ?? this.day,
        status: status ?? this.status,
        atMosque: atMosque ?? this.atMosque,
        inJamaah: inJamaah ?? this.inJamaah,
      );
}

class TaskDoneFact extends DayChatFact {
  const TaskDoneFact({required this.title, this.taskId});

  final String title;

  /// The open task of his this matched; null: nothing of his matched.
  final String? taskId;

  TaskDoneFact copyWith({String? title, String? taskId}) =>
      TaskDoneFact(title: title ?? this.title, taskId: taskId ?? this.taskId);
}

class TaskTodoFact extends DayChatFact {
  const TaskTodoFact({required this.title, this.window, this.date, this.time, this.planetKey});

  final String title;
  final PrayerWindow? window;
  final DateTime? date;

  /// `"HH:mm"` when he said a clock time.
  final String? time;
  final String? planetKey;

  TaskTodoFact copyWith({String? title, PrayerWindow? window, DateTime? date, String? time, String? planetKey}) =>
      TaskTodoFact(
        title: title ?? this.title,
        window: window ?? this.window,
        date: date ?? this.date,
        time: time ?? this.time,
        planetKey: planetKey ?? this.planetKey,
      );
}

class ContactFact extends DayChatFact {
  const ContactFact({required this.name, required this.at, this.personId, this.channel = ContactChannel.other});

  final String name;

  /// Set when the person is already in his family list.
  final String? personId;
  final ContactChannel channel;
  final DateTime at;

  ContactFact copyWith({String? name, String? personId, ContactChannel? channel, DateTime? at}) => ContactFact(
    name: name ?? this.name,
    at: at ?? this.at,
    personId: personId ?? this.personId,
    channel: channel ?? this.channel,
  );
}

class ModuleFact extends DayChatFact {
  const ModuleFact({
    required this.moduleId,
    required this.moduleName,
    required this.at,
    this.fieldId,
    this.fieldLabel,
    this.value,
  });

  final String moduleId;
  final String moduleName;

  /// The field the value is for; null: he still has to pick one.
  final String? fieldId;
  final String? fieldLabel;

  /// Already in the field's own type: a num for number / rating, a bool for
  /// a checkbox, a String for text and for a picked option.
  final Object? value;
  final DateTime at;

  ModuleFact copyWith({String? fieldId, String? fieldLabel, Object? value, DateTime? at}) => ModuleFact(
    moduleId: moduleId,
    moduleName: moduleName,
    at: at ?? this.at,
    fieldId: fieldId ?? this.fieldId,
    fieldLabel: fieldLabel ?? this.fieldLabel,
    value: value ?? this.value,
  );
}

/// A note in his own words – and the only thing a dose or a diagnosis can
/// ever become.
class NoteFact extends DayChatFact {
  const NoteFact({required this.text, required this.day, this.window, this.planetKey});

  final String text;
  final DateTime day;
  final PrayerWindow? window;
  final String? planetKey;

  NoteFact copyWith({String? text, DateTime? day, PrayerWindow? window, String? planetKey}) => NoteFact(
    text: text ?? this.text,
    day: day ?? this.day,
    window: window ?? this.window,
    planetKey: planetKey ?? this.planetKey,
  );
}

/// «ما فهمت هاي» – his words, kept whole, with nothing read out of them.
class UnreadFact extends DayChatFact {
  const UnreadFact(this.text);

  final String text;
}

// ------------------------------------------------------------------ piece --

/// One proposal: a fact, where it came from, how sure, and what is missing.
///
/// Nothing is written until he applies it ([DayChatKind] tells which
/// feature), and a piece with [needsHim] true cannot be applied as it is –
/// he has to fill the gap first (the screen's "edit").
@immutable
class DayChatPiece {
  const DayChatPiece({
    required this.id,
    required this.kind,
    required this.span,
    required this.text,
    required this.fact,
    required this.confidence,
    this.gaps = const [],
    this.flag,
    this.intent,
    this.edited = false,
  });

  /// Stable for the same words typed on the same day, so applying twice is
  /// recognised even after the app was closed (see `DayChatIds`).
  final String id;

  final DayChatKind kind;

  /// Where in the raw text this came from.
  final DayChatSpan span;

  /// His own words of [span], trimmed.
  final String text;

  final DayChatFact fact;

  /// 0..1 – how sure the reader is about [kind] and the fact's fields.
  final double confidence;

  /// What it could not resolve (never silently dropped).
  final List<DayChatGap> gaps;

  /// Set when `HealthGuard` refused to read this as anything but a note.
  final HealthFlag? flag;

  /// The quick-add intent this piece came from, when it came from one (the
  /// money / water / pain / mood / contact / task kinds). Kept so the chat
  /// screen can show the same chips the quick-add bar shows.
  final QuickAddIntent? intent;

  /// True when he changed the piece before applying it.
  final bool edited;

  /// The planet this piece's fact belongs to (a note or a to-do takes the
  /// planet the parser guessed, if any).
  String? get planetKey => switch (fact) {
    NoteFact(:final planetKey) => planetKey,
    TaskTodoFact(:final planetKey) => planetKey,
    _ => kind.planetKey,
  };

  /// True when he must fill something in before this can be written.
  bool get needsHim =>
      kind == DayChatKind.unread ||
      gaps.any(
        (g) =>
            g.kind == DayChatGapKind.amount ||
            g.kind == DayChatGapKind.module ||
            g.kind == DayChatGapKind.field ||
            g.kind == DayChatGapKind.value ||
            g.kind == DayChatGapKind.prayerName,
      );

  /// What applying this piece would write right now.
  bool get canApply => !needsHim;

  DayChatPiece copyWith({
    DayChatKind? kind,
    DayChatFact? fact,
    double? confidence,
    List<DayChatGap>? gaps,
    bool? edited,
  }) => DayChatPiece(
    id: id,
    kind: kind ?? this.kind,
    span: span,
    text: text,
    fact: fact ?? this.fact,
    confidence: confidence ?? this.confidence,
    gaps: gaps ?? this.gaps,
    flag: flag,
    intent: intent,
    edited: edited ?? this.edited,
  );

  @override
  String toString() => 'DayChatPiece(${kind.name}, «$text», ${span.start}..${span.end}, $confidence)';
}

/// Everything one typed line became.
@immutable
class DayChatReading {
  const DayChatReading({required this.raw, required this.day, required this.pieces});

  /// The text exactly as he typed it (every span indexes into this).
  final String raw;

  /// The day the reading is about (local midnight).
  final DateTime day;

  /// One per piece, in the order he typed them.
  final List<DayChatPiece> pieces;

  bool get isEmpty => pieces.isEmpty;

  /// Pieces nothing could be read out of – the ones to ask the AI about.
  List<DayChatPiece> get unread => [
    for (final p in pieces)
      if (p.kind == DayChatKind.unread) p,
  ];

  bool get hasUnread => unread.isNotEmpty;

  DayChatPiece? byId(String id) {
    for (final p in pieces) {
      if (p.id == id) return p;
    }
    return null;
  }
}
