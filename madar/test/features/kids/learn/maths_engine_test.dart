import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/learn/domain/maths_engine.dart';

void main() {
  void checkQuestion(MathsQuestion q) {
    // exactly three choices, the answer once, nothing equal in value to it twice
    expect(q.choices.length, MathsEngine.choiceCount, reason: '$q');
    expect(q.choices.where((c) => c.sameValue(q.answer)).length, 1, reason: '${q.key} ${q.choices}');
    expect(q.choices.where((c) => c == q.answer).length, 1);
    for (var i = 0; i < q.choices.length; i++) {
      for (var j = i + 1; j < q.choices.length; j++) {
        expect(q.choices[i].sameValue(q.choices[j]), isFalse, reason: 'distractors repeat in ${q.key}');
      }
      expect(q.choices[i].num, greaterThan(0), reason: 'no zero or negative choice');
      expect(q.choices[i].den, greaterThan(0));
    }
    expect(q.answer.num, greaterThan(0));
    expect(q.isCorrect(q.answer), isTrue);
    for (final c in q.choices) {
      expect(q.isCorrect(c), c == q.answer);
    }
  }

  for (final kind in MathsKind.values) {
    test('1000 seeded ${kind.name} questions are all well formed (levels 1-5)', () {
      for (var level = 1; level <= MathsEngine.maxLevel; level++) {
        final engine = MathsEngine(seed: 7 + level, level: level);
        for (var i = 0; i < 200; i++) {
          final q = engine.next(kind);
          checkQuestion(q);
          switch (kind) {
            case MathsKind.multiplication:
              expect(q.answer.num, q.a * q.b);
              expect([q.a, q.b].any((x) => x >= 2 && x <= 12), isTrue);
              expect(q.a, inInclusiveRange(2, 12));
              expect(q.b, inInclusiveRange(2, 12));
            case MathsKind.division:
              expect(q.b, greaterThanOrEqualTo(2), reason: 'never divide by zero (or by one)');
              expect(q.a % q.b, 0, reason: 'no remainders');
              expect(q.answer.num * q.b, q.a, reason: 'division is the inverse');
              expect(q.answer.isWhole, isTrue);
            case MathsKind.fractions:
              expect(q.b, greaterThanOrEqualTo(2));
              expect(q.a, inInclusiveRange(1, q.b - 1), reason: 'a proper fraction');
              if (q.task == FractionTask.readPie) {
                expect(q.answer, MathsValue(q.a, q.b));
                expect(q.answer.value, inExclusiveRange(0, 1));
              } else {
                final total = q.total!;
                expect(total % q.b, 0, reason: 'the amount splits evenly');
                expect(q.answer.num, q.a * (total ~/ q.b));
                expect(q.answer.isWhole, isTrue);
              }
          }
        }
      }
    });

    test('${kind.name}: never the same question twice in a row', () {
      for (final level in [1, 3, 5]) {
        final engine = MathsEngine(seed: 99, level: level);
        String? last;
        for (var i = 0; i < 500; i++) {
          final q = engine.next(kind);
          expect(q.key, isNot(last), reason: 'repeat at $i, level $level');
          last = q.key;
        }
      }
    });
  }

  test('the same seed gives the same questions (reproducible)', () {
    final a = MathsEngine(seed: 5), b = MathsEngine(seed: 5);
    for (var i = 0; i < 50; i++) {
      final qa = a.next(MathsKind.multiplication), qb = b.next(MathsKind.multiplication);
      expect(qa.key, qb.key);
      expect(qa.choices, qb.choices);
    }
  });

  test('difficulty adapts gently: up after 3 first-try hits, down after 2 misses, within 1..5', () {
    final e = MathsEngine(seed: 1);
    expect(e.level, 1);
    e
      ..record(firstTry: true)
      ..record(firstTry: true);
    expect(e.level, 1, reason: 'two hits are not enough');
    e.record(firstTry: true);
    expect(e.level, 2);
    e
      ..record(firstTry: false)
      ..record(firstTry: true) // a hit in between resets the misses
      ..record(firstTry: false);
    expect(e.level, 2);
    e
      ..record(firstTry: false)
      ..record(firstTry: false);
    expect(e.level, 1);
    e
      ..record(firstTry: false)
      ..record(firstTry: false);
    expect(e.level, 1, reason: 'never below 1');
    for (var i = 0; i < 100; i++) {
      e.record(firstTry: true);
    }
    expect(e.level, MathsEngine.maxLevel);
  });

  test('level 1 stays with the easy tables and halves/quarters', () {
    final e = MathsEngine(seed: 3, level: 1);
    for (var i = 0; i < 200; i++) {
      final m = e.next(MathsKind.multiplication);
      expect({2, 5, 10}.contains(m.a) || {2, 5, 10}.contains(m.b), isTrue, reason: m.key);
      final f = e.next(MathsKind.fractions);
      expect(f.task, FractionTask.readPie);
      expect({2, 4}.contains(f.b), isTrue);
    }
  });

  test('thirds and fractions of an amount appear as the child improves', () {
    final e = MathsEngine(seed: 4, level: 4);
    final dens = <int>{};
    final tasks = <FractionTask>{};
    for (var i = 0; i < 300; i++) {
      final f = e.next(MathsKind.fractions);
      dens.add(f.b);
      tasks.add(f.task!);
    }
    expect(dens, containsAll([2, 3, 4]));
    expect(tasks, {FractionTask.readPie, FractionTask.ofAmount});
  });

  test('MathsValue: equality by value is not equality of representation', () {
    expect(const MathsValue(2, 4).sameValue(const MathsValue(1, 2)), isTrue);
    expect(const MathsValue(2, 4) == const MathsValue(1, 2), isFalse);
    expect(const MathsValue(3).isWhole, isTrue);
  });
}
