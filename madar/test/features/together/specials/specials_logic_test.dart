import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/together/together.dart';

/// Whether the test process runs in Asia/Amman (run with TZ=Asia/Amman to
/// exercise the DST boundary tests; they are skipped elsewhere).
bool get _inAmman {
  final spring = DateTime.utc(2021, 3, 25, 22).toLocal();
  final summer = DateTime.utc(2021, 7, 1).toLocal();
  final winter = DateTime.utc(2021, 1, 1).toLocal();
  return spring.hour == 1 && spring.day == 26 && summer.timeZoneOffset.inHours == 3 && winter.timeZoneOffset.inHours == 2;
}

KnowMeRound _round({int n = 3, PlayerSlot first = PlayerSlot.one}) => KnowMeRound(
  id: 'r1',
  questions: [for (var i = 0; i < n; i++) RoundQuestion(id: 'q$i', text: 'Question $i')],
  first: first,
  startedAt: DateTime(2026, 9, 30, 20),
);

List<KnowMeAnswer> _answers(List<(String, String)> pairs) => [for (final (o, g) in pairs) KnowMeAnswer(own: o, guess: g)];

MatchRecord _match(int i, DateTime at) =>
    MatchRecord(id: 'm$i', gameId: 'chess', endedAt: at, outcome: MatchOutcome.oneWon);

TogetherLedger _ledger(Iterable<MatchRecord> records) => records.fold(TogetherLedger.empty, (l, r) => l.apply(r));

void main() {
  // ---------------------------------------------------------------- content

  group('default content', () {
    test('60 know-me questions in 6 categories of 10, bilingual, bounded, unique', () {
      expect(KnowMeCatalogue.questions, hasLength(60));
      expect(KnowMeCatalogue.categories, hasLength(6));
      final ids = KnowMeCatalogue.questions.map((q) => q.id).toSet();
      expect(ids, hasLength(60));
      for (final c in KnowMeCatalogue.categories) {
        expect(KnowMeCatalogue.questions.where((q) => q.category == c.id), hasLength(10), reason: c.id);
        expect(KnowMeCatalogue.iconKeys, contains(c.icon));
        expect(c.name.ar, matches(RegExp('[؀-ۿ]')));
        expect(c.name.en, isNotEmpty);
      }
      for (final q in KnowMeCatalogue.questions) {
        expect(SpecialsBounds.isValidId(q.id), isTrue, reason: q.id);
        expect(KnowMeCatalogue.isDefaultCategory(q.category), isTrue);
        expect(q.text.ar, matches(RegExp('[؀-ۿ]')), reason: q.id);
        expect(q.text.ar.trim(), endsWith('؟'), reason: q.id);
        expect(q.text.en.trim(), endsWith('?'), reason: q.id);
        for (final s in [q.text.ar, q.text.en]) {
          expect(s.runes.length, lessThanOrEqualTo(SpecialsBounds.maxQuestionLength), reason: q.id);
          expect(SpecialsBounds.clean(s, SpecialsBounds.maxQuestionLength), s, reason: 'clean: ${q.id}');
        }
      }
    });

    test('no question asks for personal data or intimate details', () {
      final forbidden = RegExp(
        r'phone|number|address|password|salary|income|money|weight|health|pin\b|passport|bank|body|kiss|'
        'رقم|عنوان|كلمة السر|راتب|دخل|وزن|صحة|جواز|بنك|جسد|قبلة',
        caseSensitive: false,
      );
      for (final q in KnowMeCatalogue.questions) {
        expect(forbidden.hasMatch(q.text.en), isFalse, reason: q.text.en);
        expect(forbidden.hasMatch(q.text.ar), isFalse, reason: q.text.ar);
      }
    });

    test('26 weekly challenges, bilingual, bounded, unique', () {
      expect(ChallengeCatalogue.all, hasLength(26));
      expect(ChallengeCatalogue.all.map((c) => c.id).toSet(), hasLength(26));
      for (final c in ChallengeCatalogue.all) {
        expect(SpecialsBounds.isValidId(c.id), isTrue);
        expect(c.text.ar, matches(RegExp('[؀-ۿ]')));
        expect(c.text.en, isNotEmpty);
        expect(c.text.ar.runes.length, lessThanOrEqualTo(SpecialsBounds.maxChallengeLength));
        expect(c.text.en.runes.length, lessThanOrEqualTo(SpecialsBounds.maxChallengeLength));
      }
    });
  });

  // ------------------------------------------------------------------- bank

  group('question bank', () {
    test('add, reword, move, delete, reorder', () {
      var b = KnowMeBank.defaults();
      b = b.addQuestion(id: 'qown1', categoryId: 'fav', text: '  What is my  favourite\u202E book? ');
      final own = b.question('qown1')!;
      expect(own.text, 'What is my favourite book?');
      // Right after the category's last question.
      expect(b.questionsIn('fav').last.id, 'qown1');
      expect(b.questions.indexWhere((q) => q.id == 'qown1'), 10);

      b = b.editQuestion('fav.dish', text: 'What do I always order?');
      expect(b.question('fav.dish')!.isEdited, isTrue);
      expect(b.question('fav.dish')!.textIn('ar'), 'What do I always order?');
      // Reworded back to the default text → the default (follows the language again).
      b = b.editQuestion('fav.dish', text: 'ما طبقي المفضّل؟');
      expect(b.question('fav.dish')!.isEdited, isFalse);
      expect(b.question('fav.dish')!.textIn('en'), "What's my favourite dish?");

      b = b.editQuestion('qown1', categoryId: 'dreams');
      expect(b.question('qown1')!.category, 'dreams');
      expect(b.questionsIn('dreams').last.id, 'qown1');

      final ids = b.questionsIn('habits').map((q) => q.id).toList();
      b = b.reorderQuestions('habits', ids.reversed.toList());
      expect(b.questionsIn('habits').map((q) => q.id), ids.reversed);
      expect(b.questions, hasLength(61));

      b = b.deleteQuestion('fav.fruit');
      expect(b.question('fav.fruit'), isNull);
      expect(b.removedQuestions, contains('fav.fruit'));
      expect(() => b.addQuestion(id: 'qx', categoryId: 'fav', text: '   '), throwsA(isA<BankEditException>()));
      expect(() => b.addQuestion(id: 'qx', categoryId: 'nope', text: 'Hi?'), throwsA(isA<BankEditException>()));
      expect(() => b.addQuestion(id: 'fav.dish', categoryId: 'fav', text: 'Hi?'), throwsArgumentError);
    });

    test('a deleted default never comes back on load; a new default does', () {
      final b = KnowMeBank.defaults().deleteQuestion('fav.fruit').deleteQuestion('me.gift');
      final json = jsonDecode(jsonEncode(b.toJson())) as Map<String, Object?>;
      // An older bank that never knew "choose.planSurprise".
      json['q'] = (json['q']! as List).where((q) => (q as Map)['i'] != 'choose.planSurprise').toList();
      final loaded = KnowMeBank.fromJson(json);
      expect(loaded.question('fav.fruit'), isNull);
      expect(loaded.question('me.gift'), isNull);
      expect(loaded.question('choose.planSurprise')?.category, 'choose');
      expect(loaded.questionsIn('choose').last.id, 'choose.planSurprise');
      expect(loaded.questions, hasLength(58));
    });

    test('categories: add, rename, delete (questions move), the last one stays', () {
      var b = KnowMeBank.defaults().addCategory(id: 'ctravel', name: 'Travel', icon: 'plane');
      b = b.addQuestion(id: 'q1', categoryId: 'ctravel', text: 'Window or aisle?');
      b = b.renameCategory('fav', 'Loves');
      expect(b.category('fav')!.nameIn('ar'), 'Loves');
      b = b.renameCategory('fav', 'Favourites');
      expect(b.category('fav')!.name, '', reason: 'back to the default name');
      expect(() => b.renameCategory('ctravel', '  '), throwsA(isA<BankEditException>()));

      b = b.deleteCategory('ctravel', moveTo: 'dreams');
      expect(b.category('ctravel'), isNull);
      expect(b.question('q1')!.category, 'dreams');
      b = b.deleteCategory('habits');
      expect(b.removedCategories, contains('habits'));
      expect(b.questionsIn('fav').length, 20, reason: 'habits moved to the first other category');
      var only = b;
      for (final c in b.categories.skip(1).toList()) {
        only = only.deleteCategory(c.id);
      }
      expect(only.categories, hasLength(1));
      expect(only.questions, hasLength(b.questions.length));
      expect(() => only.deleteCategory(only.categories.single.id), throwsA(isA<BankEditException>()));
      // A removed default category stays removed on load.
      expect(KnowMeBank.fromJson(jsonDecode(jsonEncode(b.toJson()))).category('habits'), isNull);
    });

    test('restoring the defaults keeps the couple\'s own questions', () {
      var b = KnowMeBank.defaults()
          .addCategory(id: 'cown', name: 'Ours')
          .addQuestion(id: 'q1', categoryId: 'cown', text: 'Our song?')
          .editQuestion('fav.dish', text: 'Custom?')
          .deleteQuestion('me.talent')
          .deleteCategory('choose');
      expect(b.differsFromDefaults, isTrue);
      b = b.restoreDefaults();
      expect(b.questions, hasLength(61));
      expect(b.question('fav.dish')!.isEdited, isFalse);
      expect(b.question('me.talent'), isNotNull);
      expect(b.question('q1')!.category, 'cown');
      expect(b.questionsIn('choose'), hasLength(10));
      expect(b.removedQuestions, isEmpty);
    });

    test('corrupt or hostile stored banks load safely', () {
      expect(KnowMeBank.fromJson(null), KnowMeBank.defaults());
      expect(KnowMeBank.fromJson('x'), KnowMeBank.defaults());
      expect(KnowMeBank.fromJson({'c': 1, 'q': []}), KnowMeBank.defaults());
      final b = KnowMeBank.fromJson({
        'c': [
          {'i': 'fav'},
          {'i': 'bad id!', 'n': 'x'},
          {'i': 'cnoname'},
          {'i': 'cok', 'n': '\u202Eevil\u0000 name that is far too long to be stored in full'},
        ],
        'q': [
          {'i': 'fav.dish', 'c': 'fav'},
          {'i': 'fav.dish', 'c': 'fav', 't': 'dupe'},
          {'i': 'qcustom', 'c': 'missing', 't': 'Orphan?'},
          {'i': 'qempty', 'c': 'fav'},
          {'i': 'qlong', 'c': 'cok', 't': 'x' * 500},
          42,
        ],
        'rq': ['unknown', 5],
      });
      expect(b.category('bad id!'), isNull);
      expect(b.category('cnoname'), isNull);
      expect(b.category('cok')!.name.runes.length, lessThanOrEqualTo(SpecialsBounds.maxCategoryNameLength));
      expect(b.category('cok')!.name, startsWith('evil name'));
      expect(b.question('qempty'), isNull);
      expect(b.question('qcustom')!.category, 'fav', reason: 'orphans go to the first category');
      expect(b.question('qlong')!.text.runes.length, SpecialsBounds.maxQuestionLength);
      expect(b.questions.where((q) => q.id == 'fav.dish'), hasLength(1));
      expect(b.questions.length, 62);
    });

    test('bounded: a full bank of four-byte characters stays under the storage limit', () {
      var b = KnowMeBank.defaults();
      for (var i = 0; b.categories.length < SpecialsBounds.maxCategories; i++) {
        b = b.addCategory(id: 'c$i', name: '🌙' * 40);
      }
      expect(() => b.addCategory(id: 'cmore', name: 'x'), throwsA(isA<BankEditException>()));
      for (var i = 0; !b.isFull; i++) {
        b = b.addQuestion(id: 'q$i', categoryId: 'c${i % 10}', text: '🌙' * 400);
      }
      expect(() => b.addQuestion(id: 'qmore', categoryId: 'fav', text: 'x'), throwsA(isA<BankEditException>()));
      final bytes = utf8.encode(jsonEncode(b.toJson())).length;
      expect(bytes, lessThan(TogetherBounds.maxStoredBytes));
      // Loading a stored bank beyond the bounds cuts it back.
      final json = b.toJson();
      json['q'] = [
        ...json['q']! as List,
        for (var i = 0; i < 50; i++) {'i': 'qx$i', 'c': 'fav', 't': 'extra'},
      ];
      expect(KnowMeBank.fromJson(json).questions, hasLength(SpecialsBounds.maxQuestions));
    });

    test('prefs remember recently asked questions, bounded', () {
      var p = const KnowMePrefs();
      p = p.asked(['a', 'b']).asked(['c', 'a']);
      expect(p.recent, ['b', 'c', 'a']);
      for (var i = 0; i < 300; i++) {
        p = p.asked(['x$i']);
      }
      expect(p.recent, hasLength(SpecialsBounds.maxRecentAsked));
      expect(p.recent.last, 'x299');
      expect(KnowMePrefs.fromJson(jsonDecode(jsonEncode(p.toJson()))), p);
      expect(KnowMePrefs.fromJson({'n': 999, 'c': 'x', 'r': [1, 'ok', 'ok']}).roundSize, SpecialsBounds.defaultRoundSize);
      expect(KnowMePrefs.fromJson({'r': [1, 'ok', 'ok']}).recent, ['ok']);
    });
  });

  // ------------------------------------------------------------------ round

  group('know-me round', () {
    test('draw: fresh questions first, then the longest ago asked', () {
      final bank = KnowMeBank.defaults();
      final favIds = bank.questionsIn('fav').map((q) => q.id).toList();
      // Every favourite asked except two; the oldest asked is favIds[2].
      final prefs = KnowMePrefs(categories: const {'fav'}, recent: favIds.skip(2).toList());
      final picked = KnowMeRound.pickQuestions(bank, prefs, count: 3, random: math.Random(1));
      expect(picked.map((q) => q.id).toSet(), {favIds[0], favIds[1], favIds[2]});
      expect(KnowMeRound.pickQuestions(bank, const KnowMePrefs(), count: 99, random: math.Random(1)), hasLength(15));
      // Unknown categories fall back to every question.
      final any = KnowMeRound.pickQuestions(bank, const KnowMePrefs(categories: {'gone'}), count: 5, random: math.Random(2));
      expect(any, hasLength(5));
      final r = KnowMeRound.draw(bank: bank, prefs: const KnowMePrefs(), languageCode: 'en', first: PlayerSlot.two, now: DateTime(2026));
      expect(r.questions, hasLength(SpecialsBounds.defaultRoundSize));
      expect(r.questions.first.text, endsWith('?'));
      expect(r.turn, PlayerSlot.two);
    });

    test('answers are private until both have answered', () {
      final r = _round(n: 2, first: PlayerSlot.two);
      expect(r.phase, KnowMePhase.answering);
      expect(r.turn, PlayerSlot.two);
      expect(() => r.submit(PlayerSlot.one, _answers([('a', 'b'), ('c', 'd')])), throwsA(isA<KnowMeRoundError>()));
      r.submit(PlayerSlot.two, _answers([('tea', 'coffee'), ('sea', 'city')]));
      // The second player's turn: the first player's answers cannot be read.
      expect(r.turn, PlayerSlot.one);
      expect(() => r.answersOf(PlayerSlot.two), throwsA(isA<KnowMeRoundError>()));
      expect(() => r.ownAnswer(KnowMeItem(0, PlayerSlot.two)), throwsA(isA<KnowMeRoundError>()));
      expect(() => r.scoreOf(PlayerSlot.one), throwsA(isA<KnowMeRoundError>()));
      expect(() => r.submit(PlayerSlot.two, _answers([('x', 'y'), ('z', 'w')])), throwsA(isA<KnowMeRoundError>()));
      expect(() => r.submit(PlayerSlot.one, _answers([('x', 'y')])), throwsArgumentError);
      r.submit(PlayerSlot.one, _answers([('coffee', 'tea'), ('mountains', 'sea')]));
      expect(r.phase, KnowMePhase.reveal);
      expect(r.answersOf(PlayerSlot.two).first.own, 'tea');
    });

    test('scoring: spot on 2, close 1, not quite 0; skipped questions are not scored', () {
      final r = _round(n: 3);
      r.submit(PlayerSlot.one, _answers([('Pizza', 'Tea'), ('', 'blue'), ('winter', '')]));
      r.submit(PlayerSlot.two, _answers([('tea', 'pizza'), ('red', 'green'), ('summer', 'winter')]));
      // Guesses of player one's answers (by two): pizza = Pizza (auto spot on),
      // question 1 skipped by one (void), winter = winter (auto).
      final items = r.items;
      expect(items, hasLength(6));
      expect(r.isVoid(KnowMeItem(1, PlayerSlot.one)), isTrue);
      expect(r.verdictOf(KnowMeItem(0, PlayerSlot.one)), KnowMeVerdict.exact);
      expect(r.verdictOf(KnowMeItem(2, PlayerSlot.one)), KnowMeVerdict.exact);
      // Guesses of player two's answers (by one): Tea = tea (auto), blue vs red
      // (to judge), blank guess vs summer (auto not quite).
      expect(r.verdictOf(KnowMeItem(0, PlayerSlot.two)), KnowMeVerdict.exact);
      expect(r.verdictOf(KnowMeItem(1, PlayerSlot.two)), isNull);
      expect(r.verdictOf(KnowMeItem(2, PlayerSlot.two)), KnowMeVerdict.miss);
      expect(r.pending, [KnowMeItem(1, PlayerSlot.two)]);
      expect(() => r.finish(), throwsA(isA<KnowMeRoundError>()));
      expect(() => r.judge(KnowMeItem(1, PlayerSlot.one), KnowMeVerdict.exact), throwsA(isA<KnowMeRoundError>()));
      expect(() => r.judge(KnowMeItem(7, PlayerSlot.one), KnowMeVerdict.exact), throwsRangeError);
      r.judge(KnowMeItem(1, PlayerSlot.two), KnowMeVerdict.close);
      // The subject may overrule an automatic verdict.
      r.judge(KnowMeItem(0, PlayerSlot.two), KnowMeVerdict.close);
      expect(r.scoreOf(PlayerSlot.two), 4);
      expect(r.maxScoreOf(PlayerSlot.two), 4);
      expect(r.scoreOf(PlayerSlot.one), 2);
      expect(r.maxScoreOf(PlayerSlot.one), 6);
      final result = r.finish();
      expect(result.outcome, MatchOutcome.twoWon);
      expect((result.scoreOne, result.scoreTwo), (2, 4));
      expect(result.perfect, isEmpty, reason: 'fewer than five scored questions');
      expect(identical(r.finish(), result), isTrue);
      expect(() => r.judge(KnowMeItem(1, PlayerSlot.two), KnowMeVerdict.exact), throwsA(isA<KnowMeRoundError>()));
      final record = r.toRecord(DateTime(2026, 9, 30, 20, 5));
      expect(record.id, 'knowMe-r1');
      expect(record.gameId, 'knowMe');
      expect(record.isValid, isTrue);
      expect(record.durationSeconds, 300);
      expect((record.scoreOne, record.scoreTwo), (2, 4));
    });

    test('a perfect round of five or more is a mind reader; an empty round is not recordable', () {
      final r = _round(n: 5);
      r.submit(PlayerSlot.one, _answers([for (var i = 0; i < 5; i++) ('a$i', 'x')]));
      r.submit(PlayerSlot.two, _answers([for (var i = 0; i < 5; i++) ('b$i', 'a$i')]));
      for (var i = 0; i < 5; i++) {
        r.judge(KnowMeItem(i, PlayerSlot.two), KnowMeVerdict.miss);
      }
      final result = r.finish();
      expect(result.perfect, {PlayerSlot.two});
      expect(result.scoreTwo, 10);
      expect(result.recordable, isTrue);

      final empty = _round(n: 2);
      empty.submit(PlayerSlot.one, _answers([(' ', 'x'), ('\u200B', 'y')]));
      empty.submit(PlayerSlot.two, _answers([('', ''), ('', '')]));
      expect(empty.pending, isEmpty);
      final e = empty.finish();
      expect(e.recordable, isFalse);
      expect(e.outcome, MatchOutcome.draw);
    });

    test('answers are cleaned and bounded (bidi tricks, controls, length)', () {
      final r = _round(n: 1);
      r.submit(PlayerSlot.one, [KnowMeAnswer(own: '\u202Emalicious\u0000 ${'x' * 200}', guess: 'ok')]);
      r.submit(PlayerSlot.two, const [KnowMeAnswer(own: 'b', guess: 'c')]);
      final own = r.answersOf(PlayerSlot.one).single.own;
      expect(own, startsWith('malicious '));
      expect(own.runes.length, SpecialsBounds.maxAnswerLength);
    });

    test('forgiving matching of answers and guesses', () {
      expect(KnowMeAnswerMatch.same('القهوة', 'قهوه'), isTrue);
      expect(KnowMeAnswerMatch.same('أحمر', 'احمر'), isTrue);
      expect(KnowMeAnswerMatch.same('مُسَلْسَل', 'مسلسل'), isTrue);
      expect(KnowMeAnswerMatch.same('الساعة ١١', 'ساعه 11'), isTrue);
      expect(KnowMeAnswerMatch.same('The Sea!', 'sea'), isTrue);
      expect(KnowMeAnswerMatch.same('ice cream', 'Ice-cream'), isTrue);
      expect(KnowMeAnswerMatch.same('مستشفى', 'مستشفي'), isTrue);
      expect(KnowMeAnswerMatch.same('tea', 'coffee'), isFalse);
      expect(KnowMeAnswerMatch.same('the', 'a'), isFalse, reason: 'nothing left to compare');
      expect(KnowMeAnswerMatch.same('؟', '!'), isFalse);
      expect(KnowMeAnswerMatch.similar('pizza with cheese', 'pizza'), isTrue);
      expect(KnowMeAnswerMatch.similar('شاي بالنعناع', 'الشاي'), isTrue);
      expect(KnowMeAnswerMatch.similar('red', 'blue'), isFalse);
      expect(KnowMeAnswerMatch.similar('', 'x'), isFalse);
    });
  });

  // ------------------------------------------------------------------ weeks

  group('weeks in local time', () {
    test('weekday of a day index and the week start, for every week start', () {
      for (var d = -400; d < 800; d++) {
        final date = DateTime.utc(1970, 1, 1 + d);
        expect(SpecialWeeks.weekdayOfDay(d), date.weekday, reason: '$d');
        for (var ws = 1; ws <= 7; ws++) {
          final s = SpecialWeeks.startOf(d, ws);
          expect(d - s, inInclusiveRange(0, 6));
          expect(SpecialWeeks.weekdayOfDay(s), ws);
        }
      }
    });

    test('Saturday weeks: Friday 23:59 and Saturday 00:00 are different weeks', () {
      const sat = DateTime.saturday;
      final friday = SpecialWeeks.weekOf(DateTime(2026, 10, 2, 23, 59, 59), sat);
      final saturday = SpecialWeeks.weekOf(DateTime(2026, 10, 3), sat);
      expect(saturday - friday, 7);
      expect(SpecialWeeks.dateOf(saturday), DateTime(2026, 10, 3));
      expect(SpecialWeeks.weekOf(DateTime(2026, 9, 30, 20), sat), SpecialWeeks.weekOf(DateTime(2026, 9, 26), sat));
      expect(SpecialWeeks.daysLeft(saturday, DateTime(2026, 10, 3, 8)), 7);
      expect(SpecialWeeks.daysLeft(saturday, DateTime(2026, 10, 9, 23)), 1);
      // Sunday weeks (Jordan's work week) and Monday weeks.
      expect(SpecialWeeks.dateOf(SpecialWeeks.weekOf(DateTime(2026, 10, 3), DateTime.sunday)), DateTime(2026, 9, 27));
      expect(SpecialWeeks.dateOf(SpecialWeeks.weekOf(DateTime(2026, 10, 4), DateTime.monday)), DateTime(2026, 9, 28));
    });

    test('Asia/Amman DST: clocks jumped at midnight on Fridays – week boundaries hold', () {
      const fri = DateTime.friday;
      // 26 March 2021: 00:00 → 01:00 (Friday midnight never happened).
      final thursdayNight = DateTime.utc(2021, 3, 25, 21, 59).toLocal(); // Thu 23:59 EET
      final fridayStart = DateTime.utc(2021, 3, 25, 22).toLocal(); // Fri 01:00 EEST
      expect(thursdayNight.weekday, DateTime.thursday);
      expect(fridayStart.weekday, DateTime.friday);
      expect(SpecialWeeks.weekOf(fridayStart, fri) - SpecialWeeks.weekOf(thursdayNight, fri), 7);
      expect(TogetherDays.indexOf(fridayStart) - TogetherDays.indexOf(thursdayNight), 1);
      // A naive "local midnight" of that Friday lands at 01:00 – whole-day
      // arithmetic still puts it on the Friday.
      expect(TogetherDays.indexOf(DateTime(2021, 3, 26)), TogetherDays.indexOf(fridayStart));
      expect(SpecialWeeks.dateOf(SpecialWeeks.weekOf(fridayStart, fri)).day, 26);
      // 29 October 2021: 01:00 → 00:00 (Friday's first hour happened twice).
      final first = DateTime.utc(2021, 10, 28, 21, 30).toLocal(); // Fri 00:30 EEST
      final again = DateTime.utc(2021, 10, 28, 22, 30).toLocal(); // Fri 00:30 EET
      final before = DateTime.utc(2021, 10, 28, 20, 59).toLocal(); // Thu 23:59 EEST
      expect(SpecialWeeks.weekOf(first, fri), SpecialWeeks.weekOf(again, fri));
      expect(SpecialWeeks.weekOf(first, fri) - SpecialWeeks.weekOf(before, fri), 7);
      // Saturday weeks are unaffected by the Friday jumps.
      expect(
        SpecialWeeks.weekOf(DateTime.utc(2021, 3, 26, 21).toLocal(), DateTime.saturday) -
            SpecialWeeks.weekOf(DateTime.utc(2021, 3, 26, 20, 59).toLocal(), DateTime.saturday),
        7,
      );
      // Since 28 October 2022 Amman stays on UTC+3.
      expect(DateTime.utc(2026, 10, 2, 21).toLocal().day, 3);
    }, skip: _inAmman ? false : 'run with TZ=Asia/Amman');
  });

  // ------------------------------------------------------------- challenges

  group('weekly challenge', () {
    const sat = DateTime.saturday;
    final pool = ChallengeList.defaults().pool;
    final w0 = SpecialWeeks.weekOf(DateTime(2026, 9, 5), sat); // a Saturday
    DateTime at(int week, [int day = 2]) => SpecialWeeks.dateOf(week + day).add(const Duration(hours: 20));

    ChallengeMark mark(ChallengeLog log, int week, PlayerSlot s, {bool done = true, int weekStart = sat}) =>
        log.mark(week: week, weekStart: weekStart, slot: s, done: done, at: at(week), pool: pool);

    ChallengeLog both(ChallengeLog log, int week, {int weekStart = sat}) {
      final a = mark(log, week, PlayerSlot.one, weekStart: weekStart).log;
      return mark(a, week, PlayerSlot.two, weekStart: weekStart).log;
    }

    test('rotation: each week the next challenge, pinned once shown', () {
      var log = ChallengeLog.empty.ensureWeek(w0, sat, pool);
      final first = log.weekAt(w0, sat)!.challengeId;
      expect(first, pool[(w0 ~/ 7) % pool.length].id);
      final i = pool.indexWhere((c) => c.id == first);
      expect(log.challengeFor(w0 + 7, sat, pool), pool[(i + 1) % pool.length].id);
      log = log.ensureWeek(w0 + 7, sat, pool);
      // The list changes later: pinned weeks keep their challenge.
      final changed = ChallengeList.defaults().setHidden(first, true).pool;
      expect(log.challengeFor(w0, sat, changed), first);
      expect(log.ensureWeek(w0, sat, changed), log);
    });

    test('both players mark it: a streak; un-marking takes it back exactly', () {
      var log = ChallengeLog.empty;
      final m1 = mark(log, w0, PlayerSlot.one);
      expect(m1.completed, isFalse);
      final m2 = mark(m1.log, w0, PlayerSlot.two);
      expect(m2.completed, isTrue);
      log = m2.log;
      expect((log.total, log.best, log.currentStreak(w0, sat)), (1, 1, 1));
      // Marking again changes nothing.
      expect(mark(log, w0, PlayerSlot.two).log, log);
      final undone = mark(log, w0, PlayerSlot.one, done: false);
      expect(undone.uncompleted, isTrue);
      expect((undone.log.total, undone.log.best, undone.log.currentStreak(w0, sat)), (0, 0, 0));
      // Marking and un-marking over and over never farms the streak.
      var farm = log;
      for (var k = 0; k < 5; k++) {
        farm = mark(farm, w0, PlayerSlot.one, done: false).log;
        farm = mark(farm, w0, PlayerSlot.one).log;
      }
      expect((farm.total, farm.best, farm.currentStreak(w0, sat)), (1, 1, 1));
    });

    test('streaks: consecutive weeks, a missed week resets, alive until a week is missed', () {
      var log = ChallengeLog.empty;
      for (var k = 0; k < 4; k++) {
        log = both(log, w0 + 7 * k);
      }
      final w3 = w0 + 21;
      expect(log.currentStreak(w3, sat), 4);
      expect(log.weekAt(w3, sat)!.streak, 4);
      // Next week, not done yet: the streak is still alive.
      expect(log.currentStreak(w3 + 7, sat), 4);
      // A week missed: gone.
      expect(log.currentStreak(w3 + 14, sat), 0);
      log = both(log, w3 + 14);
      expect(log.currentStreak(w3 + 14, sat), 1);
      expect((log.total, log.best), (5, 4));
      // One of the two only: not a completed week.
      log = mark(log, w3 + 21, PlayerSlot.one).log;
      expect(log.total, 5);
      expect(log.recent(w3 + 21, sat, count: 4).map((w) => w?.bothDone), [true, null, true, false]);
    });

    test('the clock or the time zone moving back never breaks the streak', () {
      var log = both(both(ChallengeLog.empty, w0), w0 + 7);
      // "Now" moved back into the previous week (travelling west over the
      // Saturday midnight): the latest completed week is ahead of "now".
      expect(log.currentStreak(w0, sat), 2);
      expect(log.currentStreak(w0 - 7, sat), 2);
    });

    test('changing the week start keeps the log and the streak', () {
      var log = both(both(ChallengeLog.empty, w0), w0 + 7);
      // Saturday → Sunday: the same weeks, a day later.
      const sun = DateTime.sunday;
      final now = at(w0 + 14, 3); // Tuesday of the third week
      final week = SpecialWeeks.weekOf(now, sun);
      expect(week, w0 + 15);
      expect(log.weekAt(w0 + 8, sun), isNotNull);
      expect(log.currentStreak(week, sun), 2);
      log = both(log, week, weekStart: sun);
      expect(log.currentStreak(week, sun), 3);
      expect(log.weekAt(week, sun)!.streak, 3);
      // Saturday → Friday (a day earlier) keeps it too.
      expect(log.currentStreak(SpecialWeeks.weekOf(now, DateTime.friday), DateTime.friday), 3);
    });

    test('swap only before anyone has done it, only to a challenge in rotation', () {
      var log = ChallengeLog.empty.ensureWeek(w0, sat, pool);
      final next = log.nextAfter(w0, sat, pool);
      log = log.swap(week: w0, weekStart: sat, challengeId: next, pool: pool);
      expect(log.weekAt(w0, sat)!.challengeId, next);
      expect(() => log.swap(week: w0, weekStart: sat, challengeId: 'nope', pool: pool), throwsA(isA<ChallengeEditException>()));
      log = mark(log, w0, PlayerSlot.two).log;
      expect(() => log.swap(week: w0, weekStart: sat, challengeId: pool.first.id, pool: pool), throwsStateError);
    });

    test('the log is bounded; lifetime total and best survive the window', () {
      var log = ChallengeLog.empty;
      for (var k = 0; k < SpecialsBounds.maxWeeks + 20; k++) {
        log = both(log, w0 + 7 * k);
      }
      expect(log.weeks, hasLength(SpecialsBounds.maxWeeks));
      expect(log.total, SpecialsBounds.maxWeeks + 20);
      expect(log.best, SpecialsBounds.maxWeeks + 20);
      final last = w0 + 7 * (SpecialsBounds.maxWeeks + 19);
      expect(log.currentStreak(last, sat), SpecialsBounds.maxWeeks + 20);
      final json = jsonEncode(log.toJson());
      expect(utf8.encode(json).length, lessThan(TogetherBounds.maxStoredBytes));
      expect(ChallengeLog.fromJson(jsonDecode(json)), log);
    });

    test('corrupt logs load safely', () {
      final log = ChallengeLog.fromJson({
        'w': [
          {'w': 100, 'c': 'walk', 'a': 1, 's': 9},
          {'w': 107, 'c': 'walk', 'a': 1, 'b': 2, 's': -3},
          {'w': 'x'},
          {'w': 114, 'c': 'bad id!'},
          {'w': 1 << 50, 'c': 'walk'},
        ],
        't': -5,
        'b': 'x',
      });
      expect(log.weeks.map((w) => w.start), [100, 107]);
      expect(log.weeks.first.streak, isNull, reason: 'only one of the two: no streak');
      expect(log.weeks.last.streak, 1);
      expect((log.total, log.best), (1, 1));
    });

    test('the list: reword, hide (not the last), add, delete, reorder, defaults always present', () {
      var list = ChallengeList.defaults();
      list = list.edit('walk', 'Walk to the park');
      expect(list.byId('walk')!.isEdited, isTrue);
      list = list.edit('walk', 'Walk together for half an hour');
      expect(list.byId('walk')!.isEdited, isFalse);
      list = list.add(id: 'wown', text: 'Visit grandma');
      list = list.delete('walk');
      expect(list.byId('walk')!.hidden, isTrue, reason: 'defaults are hidden, not deleted');
      list = list.delete('wown');
      expect(list.byId('wown'), isNull);
      for (final c in list.pool.skip(1).toList()) {
        list = list.setHidden(c.id, true);
      }
      expect(list.pool, hasLength(1));
      expect(() => list.setHidden(list.pool.single.id, true), throwsA(isA<ChallengeEditException>()));
      final reordered = ChallengeList.defaults().reorder(['tea', 'walk']);
      expect(reordered.items.take(2).map((c) => c.id), ['tea', 'walk']);
      expect(reordered.items, hasLength(26));
      // Stored lists: every default comes back; a custom one cannot be hidden.
      final loaded = ChallengeList.fromJson({
        'i': [
          {'i': 'wown', 't': 'Ours', 'h': 1},
          {'i': 'walk', 'h': 1},
          {'i': 'wempty'},
        ],
      });
      expect(loaded.items, hasLength(27));
      expect(loaded.byId('wown')!.hidden, isFalse);
      expect(loaded.byId('wempty'), isNull);
      // Everything hidden in storage: one comes back into rotation.
      final allHidden = ChallengeList.fromJson({
        'i': [for (final c in ChallengeCatalogue.all) {'i': c.id, 'h': 1}],
      });
      expect(allHidden.pool, hasLength(1));
    });
  });

  // ------------------------------------------------------------------- goal

  group('cooperative goal', () {
    final start = DateTime(2026, 9, 1, 12);
    final before = [for (var i = 0; i < 10; i++) _match(i, DateTime(2026, 8, 1 + i))];

    test('points: only what happens after the goal started', () {
      final ledger = _ledger(before);
      final g = CoopGoal.start(reward: 'Dinner out', target: 20, now: start, ledger: ledger, challengesDone: 3);
      expect(g.baseMatches, 10);
      expect(g.progress(ledger: ledger, challengesDone: 3), 0);
      final later = _ledger([...before, for (var i = 0; i < 4; i++) _match(100 + i, DateTime(2026, 9, 2 + i))]);
      expect(g.progress(ledger: later, challengesDone: 5), 4 + 2 * SpecialsBounds.challengePoints);
      expect(g.copyWith(countChallenges: false).progress(ledger: later, challengesDone: 5), 4);
      expect(g.copyWith(countGames: false).progress(ledger: later, challengesDone: 5), 10);
      // Both sources off is not a goal: games count again.
      expect(g.copyWith(countGames: false, countChallenges: false).countGames, isTrue);
    });

    test('records cleared after the goal started: every match since counts, never negative', () {
      final g = CoopGoal.start(reward: 'x', target: 5, now: start, ledger: _ledger(before), challengesDone: 0);
      // History reset, then two new matches: the ledger begins after the goal.
      final fresh = _ledger([_match(200, DateTime(2026, 9, 10)), _match(201, DateTime(2026, 9, 11))]);
      expect(g.progress(ledger: fresh, challengesDone: 0), 2);
      expect(g.progress(ledger: TogetherLedger.empty, challengesDone: 0), 0);
      // The challenge log is lifetime: fewer than at the start reads 0.
      expect(g.progress(ledger: TogetherLedger.empty, challengesDone: -4), 0);
    });

    test('counter goals, bounds and storage', () {
      var g = CoopGoal.start(
        title: '  Our \u202Ewalks ',
        reward: 'x' * 500,
        metric: GoalMetric.counter,
        target: 99999999,
        unit: 'walks',
        now: start,
        ledger: TogetherLedger.empty,
        challengesDone: 0,
      );
      expect(g.title, 'Our walks');
      expect(g.reward.runes.length, SpecialsBounds.maxRewardLength);
      expect(g.target, SpecialsBounds.maxGoalTarget);
      g = g.copyWith(counter: -5);
      expect(g.counter, 0);
      g = g.copyWith(counter: 1 << 40);
      expect(g.counter, SpecialsBounds.maxCounter);
      expect(g.progress(ledger: TogetherLedger.empty, challengesDone: 0), SpecialsBounds.maxCounter);
      final back = CoopGoal.fromJson(jsonDecode(jsonEncode(g.toJson())));
      expect(back, g);
      expect(CoopGoal.fromJson({'r': '', 's': 1, 'n': 5}), isNull);
      expect(CoopGoal.fromJson({'r': 'x', 's': 'x', 'n': 5}), isNull);
      expect(CoopGoal.fromJson({'r': 'x', 's': 1, 'n': -3})!.target, 1);
    });

    test('standing, unlocking and our rewards (bounded)', () {
      final g = CoopGoal.start(reward: 'Trip', target: 3, now: start, ledger: TogetherLedger.empty, challengesDone: 0);
      expect(GoalStanding(goal: g, progress: 9).fraction, 1);
      final s = GoalStanding(goal: g, progress: 2);
      expect((s.reached, s.remaining), (false, 1));
      expect(s.fraction, closeTo(0.667, 0.001));
      var board = GoalBoard(active: g);
      expect(board.archiveActive().active, isNotNull, reason: 'a goal not unlocked stays');
      for (var i = 0; i < SpecialsBounds.maxAchieved + 5; i++) {
        board = board.withActive(g.copyWith(unlockedAt: () => DateTime(2026, 10, 1 + i % 20))).archiveActive();
      }
      expect(board.active, isNull);
      expect(board.achieved, hasLength(SpecialsBounds.maxAchieved));
      final json = jsonEncode(board.withActive(g).toJson());
      expect(utf8.encode(json).length, lessThan(TogetherBounds.maxStoredBytes));
      final loaded = GoalBoard.fromJson(jsonDecode(json));
      expect(loaded.achieved, hasLength(SpecialsBounds.maxAchieved));
      expect(loaded.active, g);
    });
  });

  test('settings: week start stored and validated', () {
    expect(const SpecialsSettings().weekStart, DateTime.saturday);
    expect(SpecialsSettings.fromJson({'ws': 7}).weekStart, DateTime.sunday);
    expect(SpecialsSettings.fromJson({'ws': 0}).weekStart, DateTime.saturday);
    expect(SpecialsSettings.fromJson({'ws': 3.0}).weekStart, DateTime.saturday);
    expect(const SpecialsSettings().copyWith(weekStart: 9).weekStart, DateTime.saturday);
  });
}
