import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/words/words.dart';

import 'words_test_utils.dart';

void main() {
  group('flags', () {
    test('every flag compiles to finite, well-formed shapes', () {
      for (final c in countries) {
        const h = 200.0;
        final w = h * c.flag.aspectRatio;
        final shapes = c.flag.shapes(w, h);
        expect(shapes, isNotEmpty, reason: c.iso);
        bool ok(FlagPoint p) => p.x.isFinite && p.y.isFinite && p.x > -w && p.x < 2 * w && p.y > -h && p.y < 2 * h;
        for (final s in shapes) {
          expect(s.color >> 24, 0xFF, reason: c.iso);
          switch (s) {
            case FlagPolygon(:final points):
              expect(points.length, greaterThanOrEqualTo(3), reason: c.iso);
              expect(points.every(ok), isTrue, reason: c.iso);
            case FlagCircle(:final center, :final radius):
              expect(ok(center) && radius > 0, isTrue, reason: c.iso);
            case FlagRing(:final center, :final radius, :final innerRadius):
              expect(ok(center) && radius > innerRadius && innerRadius >= 0, isTrue, reason: c.iso);
            case FlagCrescent(:final center, :final radius, :final innerRadius):
              expect(ok(center) && radius > 0 && innerRadius > 0, isTrue, reason: c.iso);
            case FlagText(:final text, :final fontSize):
              expect(text.isNotEmpty && fontSize > 0, isTrue, reason: c.iso);
          }
        }
      }
    });

    test('specific flags carry their characteristic elements', () {
      Country byIso(String iso) => countries.firstWhere((c) => c.iso == iso);
      final sa = byIso('SA').flag.shapes(300, 200);
      expect(sa.whereType<FlagText>().single.text, 'لا إله إلا الله محمد رسول الله');
      expect(byIso('US').flag.shapes(380, 200).whereType<FlagPolygon>().where((p) => p.points.length == 10).length, 50);
      expect(byIso('TR').flag.shapes(300, 200).whereType<FlagCrescent>().length, 1);
      expect(byIso('CH').flag.aspectRatio, 1);
      expect(byIso('NP').flag.aspectRatio, lessThan(1));
      expect(byIso('GB').flag.shapes(400, 200).length, greaterThan(8));
      expect(parseFlagColor('#FF0000'), 0xFFFF0000);
      expect(() => parseFlagColor('red'), throwsFormatException);
    });
  });

  group('capitals quiz', () {
    final quiz = CapitalsQuiz(countries);

    test('all three modes give one right answer and three distinct distractors', () {
      for (final mode in CapitalsQuizMode.values) {
        final qs = quiz.build(mode, count: 60, seed: 11);
        expect(qs.length, 60);
        expect(qs.map((q) => q.id).toSet().length, 60);
        for (final q in qs) {
          final c = countries.firstWhere((x) => x.iso == q.payload['iso']);
          expect(q.options.map((o) => o.ar).toSet().length, 4, reason: q.id);
          final answer = q.answer;
          switch (mode) {
            case CapitalsQuizMode.countryToCapital:
              expect(q.prompt.ar, c.name.ar);
              expect(answer.en, c.capital.en);
            case CapitalsQuizMode.capitalToCountry:
              expect(q.prompt.ar, c.capital.ar);
              expect(answer.en, c.name.en);
              expect(c.capital.ar == c.name.ar, isFalse);
            case CapitalsQuizMode.flagToCountry:
              expect(q.payload['flag'], c.iso);
              expect(answer.en, c.name.en);
          }
          expect(q.level, inInclusiveRange(1, 3));
        }
      }
    });

    test('disputed capitals are never asked; distractors prefer the same continent', () {
      final all = quiz.build(CapitalsQuizMode.countryToCapital, count: 500, seed: 2);
      expect(all.any((q) => q.payload['iso'] == 'IL' || q.payload['iso'] == 'PS'), isFalse);
      expect(all.length, countries.where((c) => !c.capitalDisputed).length);
      final africa = quiz.build(CapitalsQuizMode.flagToCountry, count: 20, seed: 3, continent: Continent.africa);
      for (final q in africa) {
        for (final o in q.options) {
          final c = countries.firstWhere((x) => x.name.en == o.en);
          expect(c.continent, Continent.africa);
        }
      }
      final flags = quiz.build(CapitalsQuizMode.flagToCountry, count: 300, seed: 4);
      expect(flags.length, countries.length);
    });

    test('is deterministic for a seed', () {
      String dump(int seed) => quiz
          .build(CapitalsQuizMode.capitalToCountry, count: 10, seed: seed)
          .map((q) => '${q.id}:${q.options.map((o) => o.en).join('|')}')
          .join(',');
      expect(dump(8), dump(8));
      expect(dump(8), isNot(dump(9)));
    });
  });
}
