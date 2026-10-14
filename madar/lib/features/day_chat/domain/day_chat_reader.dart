/// The understanding engine of the daily chat.
///
/// He types his day in one line, in his own Jordanian Arabic. The reader cuts
/// it into the separate things he said ([DayChatSegmenter]) and turns each one
/// into a proposal ([DayChatPiece]): what it would write, where in his words it
/// came from, how sure it is, and what it could not resolve. **Nothing is
/// written here** – the engine is pure Dart and only reads text.
///
/// What it reads
/// -------------
/// * money out and in – through the quick-add parser («صرفت ٥ دنانير قهوة»);
/// * a meal («أكلت منسف الساعة ٢»), with his library's food when he has it;
/// * a workout («تمرين صدر ٤×١٢», «٤ في ١٢ وزن ٤٠ كيلو», «مشيت ٣٠ دقيقة»);
/// * water, pain with a score, a mood – the quick-add parser's own kinds;
/// * a prayer, with jamaah / mosque / late / missed / made up;
/// * a task of his finished («خلصت تقرير الشغل») and a task still to do;
/// * a value for a module he built himself («سكر الدم ١٢٠»);
/// * a contact with a person, resolved against his family list;
/// * a note – and **every dose or diagnosis**, which `HealthGuard` allows to
///   be nothing else.
///
/// What it refuses to guess
/// -----------------------
/// * the currency of a bare amount (it says so and uses his base currency);
/// * which tracker a number belongs to when no module of his is named
///   ([DayChatKind.sign] with [DayChatGapKind.module]);
/// * which field of a module with several numeric fields a number is for;
/// * a pain or mood score that was not said;
/// * which prayer he means when he only said «صليت»;
/// * a person, a food or an exercise he has never saved (it still applies,
///   by name, and says that it is new);
/// * anything else: the piece stays [DayChatKind.unread] – «ما فهمت هاي» –
///   which he can turn into a note, correct, or send to the AI himself.
library;

import 'dart:math' as math;

import '../../../core/domain/enums.dart';
import '../../../core/import/sha256.dart';
import '../../../core/interaction/numbers.dart';
import '../../../core/interaction/quick_add/parser.dart';
import '../../ai_bridge/domain/health_guard.dart';
import '../../family/family_texts.dart' show FamilyTexts;
import '../../prayer_tracker/domain/tracker_prayers.dart' show PrayerStatusCounting;
import '../../search/domain/search_text.dart';
import 'day_chat_piece.dart';
import 'day_chat_segmenter.dart';
import 'day_chat_text.dart';
import 'day_chat_vocabulary.dart';

/// Stable ids: the same words typed on the same day are the same piece, so
/// applying twice is recognised even after the app was closed.
abstract final class DayChatIds {
  static String of({
    required DateTime day,
    required DayChatKind kind,
    required DayChatSpan span,
    required String fingerprint,
  }) {
    final d = '${day.year}-${day.month}-${day.day}';
    return Sha256.ofString('$d|${kind.name}|${span.start}-${span.end}|$fingerprint').substring(0, 16);
  }
}

class DayChatReader {
  DayChatReader({this.vocabulary = DayChatVocabulary.empty, this.baseCurrency});

  /// His own modules, people, foods, exercises and open tasks.
  final DayChatVocabulary vocabulary;

  /// The currency a bare amount is assumed to be in (for the proposal's
  /// text only – the write resolves it again).
  final String? baseCurrency;

  /// Reads one typed line.
  ///
  /// [now] is the clock, [day] the prayer day the line is about (the data
  /// layer passes the prayer day, so a line typed at 00:30 still belongs to
  /// the evening he is talking about). Both default to the real clock.
  DayChatReading read(String raw, {DateTime? now, DateTime? day}) {
    final clock = now ?? DateTime.now();
    final theDay = day == null ? DateTime(clock.year, clock.month, clock.day) : DateTime(day.year, day.month, day.day);
    final pieces = <DayChatPiece>[];
    for (final segment in DayChatSegmenter.split(raw)) {
      final piece = _readSegment(segment, clock, theDay);
      if (piece != null) pieces.add(piece);
    }
    return DayChatReading(raw: raw, day: theDay, pieces: pieces);
  }

  // ------------------------------------------------------------ segments --

  DayChatPiece? _readSegment(DayChatSegment segment, DateTime now, DateTime day) {
    final text = segment.text.trim();
    if (text.isEmpty) return null;
    final folded = segment.folded;
    final intent = QuickAddParser.parse(text, now: now);

    // 1. A dose, a diagnosis or a treatment claim is his own note and
    //    nothing else – Madar tracks and practises, medicine is his
    //    doctor's.
    final flag = HealthGuard.scanOne(text);
    if (flag != null) {
      return _piece(
        segment,
        day,
        kind: DayChatKind.note,
        fact: NoteFact(text: text, day: day, window: intent.window, planetKey: null),
        confidence: 0.6,
        gaps: [DayChatGap(DayChatGapKind.guard, flag.match)],
        flag: flag,
        intent: intent,
        fingerprint: text,
      );
    }

    return _prayer(segment, folded, intent, now, day) ??
        _meal(segment, folded, intent, now, day) ??
        _workout(segment, folded, intent, now, day) ??
        _module(segment, folded, intent, now, day) ??
        _taskDone(segment, folded, intent, day) ??
        _quickAdd(segment, folded, intent, now, day) ??
        _sign(segment, folded, intent, now, day) ??
        _unread(segment, day, text, intent);
  }

  // -------------------------------------------------------------- prayer --

  static final RegExp _prayerVerb = RegExp(r'(?<![\p{L}])(?:و)?(?:صليت|صلينا|صلت|prayed)(?![\p{L}])', unicode: true);
  static final RegExp _prayerMissed = RegExp(r'(?<![\p{L}])(?:و)?(?:فاتتني|فاتني|فوتت|ما صليت|مصليت)(?![\p{L}])', unicode: true);
  static final RegExp _prayerLate = RegExp(r'(?<![\p{L}])(?:و)?(?:متاخر|تاخرت|قضيتها بوقتها|late)(?![\p{L}])', unicode: true);
  static final RegExp _prayerQada = RegExp(r'(?<![\p{L}])(?:قضاء|قضيت|قضا)(?![\p{L}])', unicode: true);
  static final RegExp _mosque = RegExp(r'(?:بالمسجد|في المسجد|بالجامع|في الجامع|المسجد|الجامع|mosque)', unicode: true);
  static final RegExp _jamaah = RegExp(r'(?:جماعه|بالجماعه|جماعة|congregation)', unicode: true);

  /// Folded prayer names, longest first so «سنه الفجر» beats «الفجر».
  static const List<(String, Prayer)> _prayerNames = [
    ('سنه الفجر', Prayer.sunnahFajr),
    ('سنه الظهر', Prayer.sunnahDhuhr),
    ('سنه المغرب', Prayer.sunnahMaghrib),
    ('سنه العشاء', Prayer.sunnahIsha),
    ('سنه العشا', Prayer.sunnahIsha),
    ('الفجر', Prayer.fajr),
    ('فجر', Prayer.fajr),
    ('الظهر', Prayer.dhuhr),
    ('ظهر', Prayer.dhuhr),
    ('العصر', Prayer.asr),
    ('عصر', Prayer.asr),
    ('المغرب', Prayer.maghrib),
    ('مغرب', Prayer.maghrib),
    ('العشاء', Prayer.isha),
    ('العشا', Prayer.isha),
    ('عشاء', Prayer.isha),
    ('الضحي', Prayer.duha),
    ('ضحي', Prayer.duha),
    ('الوتر', Prayer.witr),
    ('وتر', Prayer.witr),
    ('القيام', Prayer.qiyam),
    ('قيام', Prayer.qiyam),
    ('التراويح', Prayer.qiyam),
  ];

  DayChatPiece? _prayer(DayChatSegment s, String folded, QuickAddIntent intent, DateTime now, DateTime day) {
    final missed = _prayerMissed.hasMatch(folded);
    if (!missed && !_prayerVerb.hasMatch(folded)) return null;
    Prayer? prayer;
    for (final (name, p) in _prayerNames) {
      if (folded.contains(name)) {
        prayer = p;
        break;
      }
    }
    // The parser's own window word («بعد العصر») names the prayer too.
    prayer ??= switch (intent.window) {
      PrayerWindow.fajr => Prayer.fajr,
      PrayerWindow.dhuhr => Prayer.dhuhr,
      PrayerWindow.asr => Prayer.asr,
      PrayerWindow.maghrib => Prayer.maghrib,
      PrayerWindow.isha => Prayer.isha,
      PrayerWindow.duha => Prayer.duha,
      _ => null,
    };
    final mosque = _mosque.hasMatch(folded);
    final jamaah = _jamaah.hasMatch(folded) || mosque;
    final status = missed
        ? PrayerStatus.missed
        : _prayerQada.hasMatch(folded)
        ? PrayerStatus.qada
        : _prayerLate.hasMatch(folded)
        ? PrayerStatus.late
        : PrayerStatus.prayed;
    final gaps = <DayChatGap>[if (prayer == null) const DayChatGap(DayChatGapKind.prayerName)];
    final fact = PrayerFact(
      prayer: prayer ?? Prayer.fajr,
      day: intent.date ?? day,
      status: status,
      atMosque: status.counts && mosque,
      inJamaah: status.counts && jamaah,
    );
    return _piece(
      s,
      day,
      kind: DayChatKind.prayer,
      fact: fact,
      confidence: prayer == null ? 0.4 : (mosque || jamaah ? 0.95 : 0.9),
      gaps: gaps,
      intent: intent,
      fingerprint: '${prayer?.name}|${status.name}|$mosque|$jamaah',
    );
  }

  // ---------------------------------------------------------------- meal --

  static final RegExp _mealVerb = RegExp(
    r'(?<![\p{L}])(?:و)?(?:اكلت|كلت|اكلنا|تغديت|اتغديت|تغدينا|تعشيت|اتعشيت|تعشينا|فطرت|افطرت|تفطرت|فطرنا|ate|had lunch|had dinner|had breakfast)(?![\p{L}])',
    unicode: true,
  );
  static final RegExp _mealNoun = RegExp(
    r'(?<![\p{L}])(?:و)?(?:الغدا|الغداء|غدا|غداء|العشاء|العشا|عشاء|الفطور|فطور|وجبه|سناك)(?![\p{L}])',
    unicode: true,
  );
  static const Set<String> _mealTerms = {
    'واكلت', 'وتغديت', 'وتعشيت', 'وفطرت',
    'اكلت', 'كلت', 'اكلنا', 'تغديت', 'اتغديت', 'تغدينا', 'تعشيت', 'اتعشيت', 'تعشينا', 'فطرت', 'افطرت', 'تفطرت',
    'فطرنا', 'وجبه', 'ate', 'had',
  };

  DayChatPiece? _meal(DayChatSegment s, String folded, QuickAddIntent intent, DateTime now, DateTime day) {
    final verb = _mealVerb.firstMatch(folded);
    if (verb == null) return null;
    // «أكلت» with a drink is water's business, not a meal.
    if (intent.kind == QuickAddKind.water) return null;
    var name = _strip(intent.title, (t) => _mealTerms.contains(t));
    if (name.trim().isEmpty) {
      final noun = _mealNoun.firstMatch(folded);
      name = noun == null ? '' : s.rawSpanOf(noun.start, noun.end).of(s.source.raw);
    }
    if (name.trim().isEmpty) return null;
    final food = vocabulary.food(name);
    final gaps = <DayChatGap>[
      if (food == null) DayChatGap(DayChatGapKind.food, name),
      if (intent.time == null) const DayChatGap(DayChatGapKind.time),
    ];
    return _piece(
      s,
      day,
      kind: DayChatKind.meal,
      fact: MealFact(
        name: name,
        at: _at(intent, now, day),
        foodId: food?.id,
        portion: food?.portion,
        unit: food?.unit,
      ),
      confidence: food == null ? 0.78 : 0.9,
      gaps: gaps,
      intent: intent,
      fingerprint: 'meal|${DayChatText.nameKey(name)}',
    );
  }

  // ------------------------------------------------------------- workout --

  static final RegExp _workoutWord = RegExp(
    r'(?<![\p{L}])(?:و)?(?:تمرين|تمرينه|تمرنت|تدربت|تمارين|جيم|الجيم|نادي|مشيت|جريت|سبحت|لعبت|workout|training|gym|walked|ran)(?![\p{L}])',
    unicode: true,
  );
  static final RegExp _setsReps = RegExp(r'(\d+)\s*(?:[x*×]|في)\s*(\d+)');
  static final RegExp _weight = RegExp(r'(?:وزن\s*)?(\d+(?:[.,]\d+)?)\s*(?:كيلوغرام|كيلوجرام|كيلو|كجم|كغم|كغ|kgs|kg)(?![\p{L}])', unicode: true);
  static final RegExp _minutes = RegExp(r'(\d+)\s*(?:دقيقه|دقايق|دقائق|minutes|minute|mins|min)(?![\p{L}])', unicode: true);
  static final RegExp _hours = RegExp(r'(\d+)\s*(?:ساعات|ساعه)(?![\p{L}])', unicode: true);
  static final RegExp _repsOnly = RegExp(r'(\d+)\s*(?:تكرار|عده|عدات|reps|rep)(?![\p{L}])', unicode: true);
  static final RegExp _setsOnly = RegExp(r'(\d+)\s*(?:مجموعات|مجموعه|جولات|جوله|سيتات|سيت|sets|set)(?![\p{L}])', unicode: true);
  static const Set<String> _workoutTerms = {
    'تمرين', 'تمرينه', 'تمرنت', 'تدربت', 'تمارين', 'جيم', 'الجيم', 'نادي', 'وزن', 'كيلو', 'كجم', 'كغم', 'كغ', 'kg',
    'دقيقه', 'دقايق', 'دقائق', 'min', 'mins', 'minutes', 'ساعه', 'ساعات', 'تكرار', 'عده', 'عدات', 'reps', 'مجموعات',
    'مجموعه', 'سيت', 'سيتات', 'sets', 'set', 'في', 'x', 'workout', 'training', 'gym', 'وتمرين', 'وتمرنت',
  };

  DayChatPiece? _workout(DayChatSegment s, String folded, QuickAddIntent intent, DateTime now, DateTime day) {
    if (!_workoutWord.hasMatch(folded)) return null;
    if (intent.kind == QuickAddKind.expense || intent.kind == QuickAddKind.income) return null;
    final sr = _setsReps.firstMatch(folded);
    final w = _weight.firstMatch(folded);
    final mins = _minutes.firstMatch(folded);
    final hrs = _hours.firstMatch(folded);
    final reps = _repsOnly.firstMatch(folded);
    final sets = _setsOnly.firstMatch(folded);
    final durationMin = mins != null
        ? int.parse(mins.group(1)!)
        : hrs != null
        ? int.parse(hrs.group(1)!) * 60
        : null;
    final name = _tidy(_strip(intent.title, (t) => _workoutTerms.contains(t) || _isNumber(t)));
    final exercise = name.trim().isEmpty ? null : vocabulary.exercise(name);
    final hasMeasure = sr != null || w != null || durationMin != null || reps != null || sets != null;
    final gaps = <DayChatGap>[
      if (!hasMeasure) const DayChatGap(DayChatGapKind.measure),
      if (name.trim().isNotEmpty && exercise == null) DayChatGap(DayChatGapKind.exercise, name.trim()),
    ];
    return _piece(
      s,
      day,
      kind: DayChatKind.workout,
      fact: WorkoutFact(
        name: name.trim().isEmpty ? s.text.trim() : name.trim(),
        at: _at(intent, now, day),
        exerciseId: exercise?.id,
        sets: sr != null ? int.parse(sr.group(1)!) : (sets == null ? null : int.parse(sets.group(1)!)),
        reps: sr != null ? int.parse(sr.group(2)!) : (reps == null ? null : int.parse(reps.group(1)!)),
        weight: w == null ? null : _toDouble(w.group(1)!),
        durationMin: durationMin,
      ),
      confidence: hasMeasure ? (exercise == null ? 0.85 : 0.92) : 0.7,
      gaps: gaps,
      intent: intent,
      fingerprint: 'workout|${DayChatText.nameKey(name)}|${sr?.group(0)}|${w?.group(1)}|$durationMin',
    );
  }

  // -------------------------------------------------------------- module --

  DayChatPiece? _module(DayChatSegment s, String folded, QuickAddIntent intent, DateTime now, DateTime day) {
    for (final m in vocabulary.trackers) {
      if (!DayChatText.containsWords(s.text, m.name)) continue;
      // The field he named, else the module's only numeric field.
      DayChatField? field;
      for (final f in m.fields) {
        if (f.label.trim().isNotEmpty && DayChatText.containsWords(s.text, f.label)) {
          field = f;
          break;
        }
      }
      final numbers = _numbersOutside(folded, s, m.name);
      final numeric = m.numberFields;
      field ??= numeric.length == 1 ? numeric.single : null;
      if (field == null && numeric.isEmpty) {
        // A module with no numeric field: the first checkbox is a tick.
        for (final f in m.fields) {
          if (f.type == FieldType.checkbox) {
            field = f;
            break;
          }
        }
      }
      final gaps = <DayChatGap>[];
      Object? value;
      if (field == null) {
        gaps.add(DayChatGap(DayChatGapKind.field, m.name));
      } else if (field.takesNumber) {
        if (numbers.isEmpty) {
          gaps.add(DayChatGap(DayChatGapKind.value, field.label));
        } else {
          final n = numbers.first;
          value = field.type == FieldType.currency ? LocalizedNumbers.toMilli(n) : n;
          final min = field.min, max = field.max;
          if ((min != null && n < min) || (max != null && n > max)) {
            gaps.add(DayChatGap(DayChatGapKind.value, field.label));
          }
        }
      } else if (field.type == FieldType.checkbox) {
        value = true;
      } else if (field.type == FieldType.text) {
        value = s.text.trim();
      } else {
        gaps.add(DayChatGap(DayChatGapKind.value, field.label));
      }
      return _piece(
        s,
        day,
        kind: DayChatKind.moduleEntry,
        fact: ModuleFact(
          moduleId: m.id,
          moduleName: m.name,
          at: _at(intent, now, day),
          fieldId: field?.id,
          fieldLabel: field?.label,
          value: value,
        ),
        confidence: value == null ? 0.5 : 0.9,
        gaps: gaps,
        intent: intent,
        fingerprint: 'module|${m.id}|${field?.id}|$value',
      );
    }
    return null;
  }

  /// Every number of the segment that is not part of [exclude] (a module's
  /// own name can hold a digit).
  List<num> _numbersOutside(String folded, DayChatSegment s, String exclude) {
    final skip = DayChatText.rangeOf(s.text, exclude);
    final out = <num>[];
    for (final m in RegExp(r'\d+(?:[.,]\d+)?').allMatches(folded)) {
      if (skip != null) {
        final raw = s.rawSpanOf(m.start, m.end);
        final rawStart = raw.start - s.span.start;
        if (rawStart >= skip.$1 && rawStart < skip.$2) continue;
      }
      out.add(_toDouble(m.group(0)!));
    }
    return out;
  }

  // ----------------------------------------------------------- task done --

  static final RegExp _doneVerb = RegExp(
    r'(?<![\p{L}])(?:و)?(?:خلصت|خلصنا|انجزت|انهيت|تممت|سويت|عملت|finished|done)(?![\p{L}])',
    unicode: true,
  );
  static const Set<String> _doneTerms = {'وخلصت', 'وعملت', 'وسويت', 'خلصت', 'خلصنا', 'انجزت', 'انهيت', 'تممت', 'سويت', 'عملت', 'finished', 'done'};

  DayChatPiece? _taskDone(DayChatSegment s, String folded, QuickAddIntent intent, DateTime day) {
    if (!_doneVerb.hasMatch(folded)) return null;
    if (intent.kind != QuickAddKind.task && intent.kind != QuickAddKind.note) return null;
    final title = _strip(intent.title, (t) => _doneTerms.contains(t)).trim();
    if (title.isEmpty) return null;
    final task = vocabulary.openTask(title);
    return _piece(
      s,
      day,
      kind: DayChatKind.taskDone,
      fact: TaskDoneFact(title: task?.title ?? title, taskId: task?.id),
      confidence: task == null ? 0.65 : 0.92,
      gaps: [if (task == null) DayChatGap(DayChatGapKind.taskMatch, title)],
      intent: intent,
      fingerprint: 'done|${task?.id ?? DayChatText.nameKey(title)}',
    );
  }

  // ----------------------------------------------------------- quick add --

  static final RegExp _obligation = RegExp(
    r'(?<![\p{L}])(?:و)?(?:لازم|ضروري|بدي|بديش|عليي|علي|ذكرني|لا تنسي|ما تنسي|must|need to|have to|remind)(?![\p{L}])',
    unicode: true,
  );
  static final RegExp _pastMarker = RegExp(
    r'(?<![\p{L}])(?:كان|كانت|صار|صارت|كنت|حسيت|شعرت|was|were)(?![\p{L}])',
    unicode: true,
  );
  static final RegExp _volume = RegExp(
    r'(?:\d|كاسه|كاسات|كاستين|كوب|كوبين|لتر|لترين|ليتر|مل|ml|litre|liter|cup|glass|bottle|قنينه|عبوه)',
    unicode: true,
  );

  DayChatPiece? _quickAdd(DayChatSegment s, String folded, QuickAddIntent intent, DateTime now, DateTime day) {
    final at = _at(intent, now, day);
    switch (intent.kind) {
      case QuickAddKind.expense:
      case QuickAddKind.income:
        final income = intent.kind == QuickAddKind.income;
        final amount = intent.amountMilli;
        final gaps = <DayChatGap>[
          if (amount == null) const DayChatGap(DayChatGapKind.amount),
          if (amount != null && intent.currency == null) DayChatGap(DayChatGapKind.currency, baseCurrency),
        ];
        return _piece(
          s,
          day,
          kind: income ? DayChatKind.income : DayChatKind.expense,
          fact: MoneyFact(
            amountMilli: amount ?? 0,
            currency: intent.currency,
            note: intent.title.trim(),
            at: at,
            income: income,
          ),
          confidence: intent.confidence,
          gaps: gaps,
          intent: intent,
          fingerprint: 'money|$income|$amount|${intent.currency}|${DayChatText.nameKey(intent.title)}',
        );

      case QuickAddKind.water:
        final ml = intent.ml ?? 250;
        final stated = _volume.hasMatch(folded);
        return _piece(
          s,
          day,
          kind: DayChatKind.water,
          fact: WaterFact(ml: ml, at: at),
          confidence: intent.confidence,
          gaps: [if (!stated) const DayChatGap(DayChatGapKind.measure)],
          intent: intent,
          fingerprint: 'water|$ml',
        );

      case QuickAddKind.pain:
        final score = intent.score;
        final where = intent.title.trim();
        return _piece(
          s,
          day,
          kind: DayChatKind.pain,
          fact: PainFact(score: score ?? 0, location: where.isEmpty ? null : where, at: at),
          confidence: intent.confidence,
          gaps: [if (score == null) const DayChatGap(DayChatGapKind.value)],
          intent: intent,
          fingerprint: 'pain|$score|${DayChatText.nameKey(where)}',
        );

      case QuickAddKind.mood:
        final score = intent.score;
        final note = intent.title.trim();
        return _piece(
          s,
          day,
          kind: DayChatKind.mood,
          fact: MoodFact(score: score ?? 3, note: note.isEmpty ? null : note, at: at),
          confidence: intent.confidence,
          gaps: [if (score == null) const DayChatGap(DayChatGapKind.value)],
          intent: intent,
          fingerprint: 'mood|$score',
        );

      case QuickAddKind.contact:
        final name = intent.title.trim();
        if (name.isEmpty) return null;
        final relation = FamilyTexts.relationKeyFor(name);
        final person = vocabulary.person(name, relation: relation);
        return _piece(
          s,
          day,
          kind: DayChatKind.contact,
          fact: ContactFact(
            name: person?.name ?? name,
            at: at,
            personId: person?.id,
            channel: intent.channel ?? ContactChannel.other,
          ),
          confidence: person == null ? intent.confidence - 0.05 : intent.confidence,
          gaps: [if (person == null) DayChatGap(DayChatGapKind.person, name)],
          intent: intent,
          fingerprint: 'contact|${person?.id ?? DayChatText.nameKey(name)}|${intent.channel?.name}',
        );

      case QuickAddKind.note:
        final body = intent.title.trim().isEmpty ? s.text.trim() : intent.title.trim();
        return _piece(
          s,
          day,
          kind: DayChatKind.note,
          fact: NoteFact(text: body, day: intent.date ?? day, window: intent.window, planetKey: intent.planetKey),
          confidence: intent.confidence,
          intent: intent,
          fingerprint: 'note|${DayChatText.nameKey(body)}',
        );

      case QuickAddKind.task:
        final title = intent.title.trim();
        if (title.isEmpty) return null;
        final planned = intent.date != null && intent.date!.isAfter(day);
        final todo = _obligation.hasMatch(folded) || intent.confidence >= 0.6 || planned || intent.time != null;
        if (!todo || _pastMarker.hasMatch(folded)) return null;
        return _piece(
          s,
          day,
          kind: DayChatKind.taskTodo,
          fact: TaskTodoFact(
            title: title,
            window: intent.window,
            date: intent.date,
            time: intent.time,
            planetKey: intent.planetKey,
          ),
          confidence: intent.confidence,
          gaps: [if (intent.time != null && intent.date == null) const DayChatGap(DayChatGapKind.time)],
          intent: intent,
          fingerprint: 'todo|${DayChatText.nameKey(title)}|${intent.date}|${intent.time}',
        );
    }
  }

  // ---------------------------------------------------------------- sign --

  /// «سكر الدم ١٢٠» with no tracker of his by that name: a number for
  /// something he watches, and the reader says plainly that it does not know
  /// which tracker («ما بعرف لوين هاد الرقم»).
  DayChatPiece? _sign(DayChatSegment s, String folded, QuickAddIntent intent, DateTime now, DateTime day) {
    final words = DayChatText.terms(s.text);
    if (words.length > 5 || words.length < 2) return null;
    final numbers = RegExp(r'(?<![\p{L}])\d+(?:[.,]\d+)?(?![\p{L}])', unicode: true).allMatches(folded).toList();
    if (numbers.length != 1) return null;
    final name = _strip(s.text, _isNumber).trim();
    if (name.isEmpty) return null;
    return _piece(
      s,
      day,
      kind: DayChatKind.sign,
      fact: ModuleFact(moduleId: '', moduleName: name, at: _at(intent, now, day), value: _toDouble(numbers.first.group(0)!)),
      confidence: 0.45,
      gaps: [DayChatGap(DayChatGapKind.module, name)],
      intent: intent,
      fingerprint: 'sign|${DayChatText.nameKey(name)}|${numbers.first.group(0)}',
    );
  }

  // -------------------------------------------------------------- unread --

  DayChatPiece _unread(DayChatSegment s, DateTime day, String text, QuickAddIntent intent) => _piece(
    s,
    day,
    kind: DayChatKind.unread,
    fact: UnreadFact(text),
    confidence: 0.1,
    gaps: const [DayChatGap(DayChatGapKind.meaning)],
    intent: intent,
    fingerprint: 'unread|${DayChatText.nameKey(text)}',
  );

  // ------------------------------------------------------------- helpers --

  DayChatPiece _piece(
    DayChatSegment s,
    DateTime day, {
    required DayChatKind kind,
    required DayChatFact fact,
    required double confidence,
    required String fingerprint,
    List<DayChatGap> gaps = const [],
    HealthFlag? flag,
    QuickAddIntent? intent,
  }) {
    final hard = gaps.any(
      (g) =>
          g.kind == DayChatGapKind.amount ||
          g.kind == DayChatGapKind.module ||
          g.kind == DayChatGapKind.field ||
          g.kind == DayChatGapKind.value ||
          g.kind == DayChatGapKind.prayerName,
    );
    final soft = gaps.length - (hard ? 1 : 0);
    final c = confidence - (hard ? 0.3 : 0) - math.min(0.1, soft * 0.03);
    return DayChatPiece(
      id: DayChatIds.of(day: day, kind: kind, span: s.span, fingerprint: fingerprint),
      kind: kind,
      span: s.span,
      text: s.text.trim(),
      fact: fact,
      confidence: double.parse(c.clamp(0.05, 0.99).toStringAsFixed(2)),
      gaps: gaps,
      flag: flag,
      intent: intent,
    );
  }

  /// When a log happened: the day and clock time he said, else now (a day
  /// he named without a time lands at noon, so it stays on that day in every
  /// time zone).
  static DateTime _at(QuickAddIntent intent, DateTime now, DateTime day) {
    final both = intent.dateTime;
    if (both != null && intent.time != null) return both;
    final d = intent.date;
    final t = intent.time;
    if (t != null) {
      final parts = t.split(':');
      final base = d ?? day;
      return DateTime(base.year, base.month, base.day, int.parse(parts[0]), int.parse(parts[1]));
    }
    if (d == null) return now;
    final isToday = d.year == day.year && d.month == day.month && d.day == day.day;
    return isToday ? now : DateTime(d.year, d.month, d.day, 12);
  }

  /// [text] without the words [remove] accepts, his own spelling kept for
  /// everything else.
  static String _strip(String text, bool Function(String term) remove) {
    if (text.trim().isEmpty) return '';
    final tokens = SearchText.tokenize(text);
    final keep = StringBuffer();
    var cursor = 0;
    for (final t in tokens) {
      if (!remove(t.term)) continue;
      keep.write(text.substring(cursor, t.start));
      keep.write(' ');
      cursor = t.end;
    }
    keep.write(text.substring(cursor));
    return keep.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Drops the separators a measure leaves behind («صدر ×» → «صدر»).
  static String _tidy(String name) =>
      name.replaceAll(RegExp(r'[×xX*٭]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static bool _isNumber(String term) => RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(term);

  static double _toDouble(String raw) => double.parse(raw.replaceAll(',', '.'));
}
