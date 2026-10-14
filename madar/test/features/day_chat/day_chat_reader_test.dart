// The understanding engine over real sentences he would type, in his own
// Jordanian Arabic. Every test asserts the span the proposal came from –
// the chat screen underlines exactly those letters, so a right value read
// out of the wrong words is still a bug.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/ai_bridge/domain/health_guard.dart';
import 'package:madar/features/day_chat/day_chat.dart';

void main() {
  // Wednesday 14 October 2026, 20:30.
  final now = DateTime(2026, 10, 14, 20, 30);
  final today = DateTime(2026, 10, 14);

  // His own things: one tracker, one person, one food, one exercise, one
  // open task. A fresh install has none of them – every test that needs one
  // says so.
  final vocabulary = DayChatVocabulary(
    modules: const [
      DayChatModule(
        id: 'm-sugar',
        name: 'سكر الدم',
        planetKey: 'health',
        fields: [
          DayChatField(id: 'f1', label: 'القراءة', type: FieldType.number, unit: 'ملغ', min: 40, max: 500),
        ],
      ),
    ],
    people: const [DayChatPerson(id: 'p-rana', name: 'رنا')],
    foods: const [DayChatNamed(id: 'fd-mansaf', name: 'منسف', unit: 'طبق', portion: 1)],
    exercises: const [DayChatNamed(id: 'ex-chest', name: 'صدر')],
    openTasks: const [DayChatOpenTask(id: 't-report', title: 'تقرير الشغل')],
  );

  DayChatReading read(String text, {DayChatVocabulary? vocab}) =>
      DayChatReader(vocabulary: vocab ?? vocabulary, baseCurrency: 'JOD').read(text, now: now, day: today);

  /// The piece's own words, cut out of the raw line by its span – what the
  /// screen underlines.
  String spanned(DayChatReading r, DayChatPiece p) => p.span.of(r.raw);

  test('one line, five facts – each in its own words', () {
    const line = 'صرفت ٥ دنانير قهوة، صليت العصر بالمسجد، تمرين صدر ٤×١٢، وجع الركبة ٦، أكلت منسف الساعة ٢';
    final r = read(line);
    expect(r.pieces.map((p) => p.kind), [
      DayChatKind.expense,
      DayChatKind.prayer,
      DayChatKind.workout,
      DayChatKind.pain,
      DayChatKind.meal,
    ]);
    // Every span is his own words, in the order he typed them, and none of
    // them overlaps the next.
    expect([for (final p in r.pieces) spanned(r, p)], [
      'صرفت ٥ دنانير قهوة',
      'صليت العصر بالمسجد',
      'تمرين صدر ٤×١٢',
      'وجع الركبة ٦',
      'أكلت منسف الساعة ٢',
    ]);
    for (var i = 1; i < r.pieces.length; i++) {
      expect(r.pieces[i].span.start, greaterThanOrEqualTo(r.pieces[i - 1].span.end));
    }
    expect(r.pieces.every((p) => p.canApply), isTrue);
    expect(r.hasUnread, isFalse);

    final money = r.pieces.first.fact as MoneyFact;
    expect(money.amountMilli, 5000);
    expect(money.currency, 'JOD');
    expect(money.note, 'قهوة');

    final prayer = r.pieces[1].fact as PrayerFact;
    expect(prayer.prayer, Prayer.asr);
    expect(prayer.atMosque, isTrue);
    expect(prayer.inJamaah, isTrue, reason: 'at the mosque is in congregation');
    expect(prayer.status, PrayerStatus.prayed);

    final workout = r.pieces[2].fact as WorkoutFact;
    expect((workout.sets, workout.reps), (4, 12));
    expect(workout.name, 'صدر');
    expect(workout.exerciseId, 'ex-chest', reason: 'his own exercise');

    final pain = r.pieces[3].fact as PainFact;
    expect(pain.score, 6);
    expect(pain.location, 'الركبة');

    final meal = r.pieces[4].fact as MealFact;
    expect(meal.name, 'منسف');
    expect(meal.foodId, 'fd-mansaf');
    expect(meal.at, DateTime(2026, 10, 14, 14));
  });

  test('«و» glued to the next verb starts a new piece, and no punctuation is needed', () {
    final r = read('صرفت 5 قهوة وصليت المغرب جماعة أكلت منسف');
    expect(r.pieces.map((p) => p.kind), [DayChatKind.expense, DayChatKind.prayer, DayChatKind.meal]);
    expect(spanned(r, r.pieces[1]), 'وصليت المغرب جماعة');
    expect(spanned(r, r.pieces[2]), 'أكلت منسف');
    final prayer = r.pieces[1].fact as PrayerFact;
    expect(prayer.prayer, Prayer.maghrib);
    expect(prayer.inJamaah, isTrue);
    expect(prayer.atMosque, isFalse, reason: 'he did not say the mosque');
  });

  test('Arabic-Indic and Western digits in one line', () {
    final r = read('صرفت ١٢٫٥ دينار بنزين وشربت 500 مل مي');
    expect(r.pieces.map((p) => p.kind), [DayChatKind.expense, DayChatKind.water]);
    expect((r.pieces.first.fact as MoneyFact).amountMilli, 12500);
    expect(spanned(r, r.pieces.first), 'صرفت ١٢٫٥ دينار بنزين');
    expect((r.pieces[1].fact as WaterFact).ml, 500);
    expect(spanned(r, r.pieces[1]), 'وشربت 500 مل مي');
  });

  test('an amount without a currency says so instead of inventing one', () {
    final withCurrency = read('صرفت ٥ دنانير قهوة').pieces.single;
    expect((withCurrency.fact as MoneyFact).currency, 'JOD');
    expect(withCurrency.gaps, isEmpty);

    final r = read('صرفت ٥ قهوة');
    final bare = r.pieces.single;
    expect(bare.kind, DayChatKind.expense);
    expect((bare.fact as MoneyFact).amountMilli, 5000);
    expect((bare.fact as MoneyFact).currency, isNull);
    expect(bare.gaps.map((g) => g.kind), [DayChatGapKind.currency]);
    expect(bare.gaps.single.detail, 'JOD', reason: 'it says which currency it would take');
    expect(bare.canApply, isTrue, reason: 'his base currency is a stated assumption, not a guess');
    expect(spanned(r, bare), 'صرفت ٥ قهوة');
  });

  test('«٤×١٢» and «٤ في ١٢», with a weight', () {
    final crossed = read('تمرين صدر ٤×١٢').pieces.single.fact as WorkoutFact;
    final spelled = read('تمرين صدر ٤ في ١٢ وزن ٤٠ كيلو');
    final fact = spelled.pieces.single.fact as WorkoutFact;
    expect((crossed.sets, crossed.reps), (4, 12));
    expect((fact.sets, fact.reps), (4, 12));
    expect(fact.weight, 40);
    expect(fact.name, 'صدر', reason: 'the measure never leaks into the name');
    expect(spanned(spelled, spelled.pieces.single), 'تمرين صدر ٤ في ١٢ وزن ٤٠ كيلو');

    final walk = read('مشيت ٣٠ دقيقة');
    final walked = walk.pieces.single.fact as WorkoutFact;
    expect(walked.durationMin, 30);
    expect(spanned(walk, walk.pieces.single), 'مشيت ٣٠ دقيقة');
  });

  test('a time of day: «الساعة ٢» and «٢ العصر»', () {
    final clock = read('أكلت منسف الساعة ٢');
    final meal = clock.pieces.single;
    expect((meal.fact as MealFact).at, DateTime(2026, 10, 14, 14));
    expect(spanned(clock, meal), 'أكلت منسف الساعة ٢');

    final asr = read('أكلت منسف ٢ العصر');
    final afternoon = asr.pieces.single;
    expect(afternoon.kind, DayChatKind.meal);
    expect((afternoon.fact as MealFact).at, DateTime(2026, 10, 14, 14));
    expect(spanned(asr, afternoon), 'أكلت منسف ٢ العصر');
  });

  test('a meal with no time says the time was not stated', () {
    final r = read('أكلت منسف');
    final meal = r.pieces.single;
    expect((meal.fact as MealFact).at, now, reason: 'logged when he typed it');
    expect(meal.gaps.map((g) => g.kind), contains(DayChatGapKind.time));
    expect(meal.canApply, isTrue);
  });

  test('a pain score, and a pain without one', () {
    final scored = read('وجع الركبة ٦');
    expect((scored.pieces.single.fact as PainFact).score, 6);
    expect(scored.pieces.single.canApply, isTrue);
    expect(spanned(scored, scored.pieces.single), 'وجع الركبة ٦');

    final r = read('وجع راسي');
    final piece = r.pieces.single;
    expect(piece.kind, DayChatKind.pain);
    expect(piece.gaps.map((g) => g.kind), [DayChatGapKind.value]);
    expect(piece.canApply, isFalse, reason: 'it never invents a score');
    expect(spanned(r, piece), 'وجع راسي');
  });

  test('a prayer: the mosque, congregation, late, missed, made up – and «أي صلاة؟»', () {
    PrayerFact factOf(String line) => read(line).pieces.single.fact as PrayerFact;
    expect(factOf('صليت الفجر بالمسجد').atMosque, isTrue);
    expect(factOf('صليت العشاء جماعة').inJamaah, isTrue);
    expect(factOf('صليت الظهر متأخر').status, PrayerStatus.late);
    expect(factOf('فاتتني العصر').status, PrayerStatus.missed);
    expect(factOf('قضيت الفجر').status, PrayerStatus.qada);
    expect(factOf('صليت الضحى').prayer, Prayer.duha);

    final vague = read('صليت');
    final piece = vague.pieces.single;
    expect(piece.kind, DayChatKind.prayer);
    expect(piece.gaps.map((g) => g.kind), [DayChatGapKind.prayerName]);
    expect(piece.canApply, isFalse, reason: 'it never picks a prayer for him');
    expect(spanned(vague, piece), 'صليت');
  });

  test('a person of his, and a person he never saved', () {
    final his = read('كلمت رنا');
    final known = his.pieces.single;
    expect(known.kind, DayChatKind.contact);
    expect((known.fact as ContactFact).personId, 'p-rana');
    expect((known.fact as ContactFact).channel, ContactChannel.call);
    expect(known.gaps, isEmpty);
    expect(spanned(his, known), 'كلمت رنا');

    final stranger = read('كلمت ابو محمود');
    final piece = stranger.pieces.single;
    expect((piece.fact as ContactFact).personId, isNull);
    expect((piece.fact as ContactFact).name, 'ابو محمود');
    expect(piece.gaps.map((g) => g.kind), [DayChatGapKind.person]);
    expect(piece.canApply, isTrue, reason: 'a new person is added, and it says so');
  });

  test('a value for a module he built himself', () {
    final r = read('سكر الدم ١٢٠');
    final piece = r.pieces.single;
    expect(piece.kind, DayChatKind.moduleEntry);
    final fact = piece.fact as ModuleFact;
    expect(fact.moduleId, 'm-sugar');
    expect(fact.fieldId, 'f1');
    expect(fact.value, 120);
    expect(piece.gaps, isEmpty);
    expect(spanned(r, piece), 'سكر الدم ١٢٠');
  });

  test('a number for a tracker he does not have: it asks instead of guessing', () {
    final r = read('ضغط الدم ١٤');
    final piece = r.pieces.single;
    expect(piece.kind, DayChatKind.sign);
    expect(piece.gaps.map((g) => g.kind), [DayChatGapKind.module]);
    expect(piece.canApply, isFalse);
    expect(spanned(r, piece), 'ضغط الدم ١٤');
  });

  test('a value outside the module\'s own bounds is handed back to him', () {
    final r = read('سكر الدم ٩٩٩');
    final piece = r.pieces.single;
    expect(piece.kind, DayChatKind.moduleEntry);
    expect(piece.gaps.map((g) => g.kind), contains(DayChatGapKind.value));
    expect(piece.canApply, isFalse);
  });

  test('a finished task of his, and one he never had', () {
    final his = read('خلصت تقرير الشغل');
    final done = his.pieces.single;
    expect(done.kind, DayChatKind.taskDone);
    expect((done.fact as TaskDoneFact).taskId, 't-report');
    expect(done.gaps, isEmpty);
    expect(spanned(his, done), 'خلصت تقرير الشغل');

    final other = read('خلصت غسيل السيارة').pieces.single;
    expect(other.kind, DayChatKind.taskDone);
    expect((other.fact as TaskDoneFact).taskId, isNull);
    expect(other.gaps.map((g) => g.kind), [DayChatGapKind.taskMatch]);
    expect(other.canApply, isTrue, reason: 'what he finished is still part of his day');
  });

  test('something still to do keeps its day', () {
    final r = read('لازم اروح للبنك بكرا');
    final piece = r.pieces.single;
    expect(piece.kind, DayChatKind.taskTodo);
    expect((piece.fact as TaskTodoFact).date, DateTime(2026, 10, 15));
    expect(spanned(r, piece), 'لازم اروح للبنك بكرا');
  });

  test('a sentence with no fact in it is a proposal of its own, never dropped', () {
    final r = read('اليوم كان يوم طويل');
    final piece = r.pieces.single;
    expect(piece.kind, DayChatKind.unread);
    expect(piece.fact, isA<UnreadFact>());
    expect((piece.fact as UnreadFact).text, 'اليوم كان يوم طويل');
    expect(piece.gaps.map((g) => g.kind), [DayChatGapKind.meaning]);
    expect(piece.canApply, isFalse, reason: 'he turns it into a note, or corrects it');
    expect(r.hasUnread, isTrue);
    expect(spanned(r, piece), 'اليوم كان يوم طويل');
  });

  test('a dose is kept as his own note and nothing else', () {
    final r = read('اخذت حبة بنادول ٥٠٠ ملغ');
    final piece = r.pieces.single;
    expect(piece.kind, DayChatKind.note, reason: 'tracking and charting only – medicine is his doctor\'s');
    expect(piece.fact, isA<NoteFact>());
    expect((piece.fact as NoteFact).text, 'اخذت حبة بنادول ٥٠٠ ملغ', reason: 'his own words, whole');
    expect(piece.flag?.kind, HealthFlagKind.dose);
    expect(piece.gaps.map((g) => g.kind), [DayChatGapKind.guard]);
    expect(spanned(r, piece), 'اخذت حبة بنادول ٥٠٠ ملغ');
  });

  test('a diagnosis is a note too', () {
    final piece = read('الدكتور قال عندك التهاب').pieces.single;
    expect(piece.kind, DayChatKind.note);
    expect(piece.flag?.kind, HealthFlagKind.diagnosis);
  });

  test('a deliberately confusing sentence: «صرفت وقت» is not money', () {
    final r = read('صرفت وقت مع امي بالبيت');
    final piece = r.pieces.single;
    expect(piece.kind, DayChatKind.expense, reason: 'the verb is a money verb');
    expect(piece.gaps.map((g) => g.kind), [DayChatGapKind.amount]);
    expect(piece.canApply, isFalse, reason: 'no amount is ever invented, so nothing is written');
    expect(piece.confidence, lessThan(0.5));
    expect(spanned(r, piece), 'صرفت وقت مع امي بالبيت');
  });

  test('a fresh install knows no names and still reads the line', () {
    final r = read('أكلت منسف وتمرين صدر ٣×١٠', vocab: DayChatVocabulary.empty);
    expect(r.pieces.map((p) => p.kind), [DayChatKind.meal, DayChatKind.workout]);
    expect(r.pieces.first.gaps.map((g) => g.kind), contains(DayChatGapKind.food));
    expect(r.pieces[1].gaps.map((g) => g.kind), contains(DayChatGapKind.exercise));
    expect(r.pieces.every((p) => p.canApply), isTrue);
  });

  test('ids are stable for the same words on the same day, and differ per piece', () {
    const line = 'صرفت ٥ دنانير قهوة، شربت كاستين مي';
    final first = read(line);
    final second = read(line);
    expect([for (final p in first.pieces) p.id], [for (final p in second.pieces) p.id]);
    expect(first.pieces.first.id, isNot(first.pieces[1].id));
    final tomorrow = DayChatReader(vocabulary: vocabulary).read(line, now: now, day: DateTime(2026, 10, 15));
    expect(tomorrow.pieces.first.id, isNot(first.pieces.first.id), reason: 'a new day is a new piece');
  });

  test('empty and punctuation-only lines read as nothing', () {
    expect(read('').pieces, isEmpty);
    expect(read('   ').pieces, isEmpty);
    expect(read('،،، ...').pieces, isEmpty);
  });
}
