import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/nutrition/nutrition.dart';

final _pressure = const ConditionRef(id: 'c-pressure', name: 'الضغط');
final _stomach = const ConditionRef(id: 'c-stomach', name: 'المعدة');

FoodEntry _entry(
  String id,
  String name, {
  DateTime? at,
  String? foodId,
  double? portion,
  List<String> tags = const [],
  String? slotId,
}) => FoodEntry(
  id: id,
  name: name,
  at: at ?? DateTime(2026, 10, 10, 13),
  foodId: foodId,
  portion: portion,
  tags: tags,
  slotId: slotId,
);

FoodRule _tagRule(
  String id,
  String tag, {
  String? conditionId,
  RiskWeight weight = RiskWeight.medium,
  double? minPortion,
  int? from,
  int? to,
  int? maxPerDay,
  String? note,
  bool active = true,
}) => FoodRule(
  id: id,
  target: FoodRuleTarget.tag,
  tag: tag,
  conditionId: conditionId,
  weight: weight,
  minPortion: minPortion,
  fromMinutes: from,
  toMinutes: to,
  maxPerDay: maxPerDay,
  note: note,
  active: active,
);

void main() {
  group('no rules of his own', () {
    test('an entry has no rating at all (not a zero)', () {
      final rating = RiskEngine.rateEntry(
        _entry('e1', 'بطاطا مقلية', tags: ['مقلي']),
        rules: const [],
        conditions: [_stomach],
      );
      expect(rating, isNull);
    });

    test('a day has no rating at all', () {
      expect(
        RiskEngine.rateDay(
          day: DateTime(2026, 10, 10),
          entries: [_entry('e1', 'مقلي', tags: ['مقلي'])],
          rules: const [],
          conditions: [_stomach],
        ),
        isNull,
      );
    });

    test('rules switched off, or tied to a condition he turned off, are no rules', () {
      final entry = _entry('e1', 'مقلي', tags: ['مقلي']);
      expect(
        RiskEngine.rateEntry(
          entry,
          rules: [_tagRule('r1', 'مقلي', conditionId: _stomach.id, active: false)],
          conditions: [_stomach],
        ),
        isNull,
      );
      expect(
        RiskEngine.rateEntry(
          entry,
          rules: [_tagRule('r1', 'مقلي', conditionId: _stomach.id)],
          conditions: [const ConditionRef(id: 'c-stomach', name: 'المعدة', active: false)],
        ),
        isNull,
      );
      // A rule whose condition he deleted stops counting as well.
      expect(
        RiskEngine.rateEntry(entry, rules: [_tagRule('r1', 'مقلي', conditionId: 'gone')], conditions: const []),
        isNull,
      );
      // An incomplete rule (a tag rule without a tag) never counts.
      expect(
        RiskEngine.rateEntry(entry, rules: [_tagRule('r1', '   ')], conditions: const []),
        isNull,
      );
    });
  });

  group('with his rules', () {
    test('rules apply but none fires: a clear rating, level none', () {
      final rating = RiskEngine.rateEntry(
        _entry('e1', 'سلطة', tags: ['خضار']),
        rules: [_tagRule('r1', 'مقلي', conditionId: _stomach.id)],
        conditions: [_stomach],
      )!;
      expect(rating.score, 0);
      expect(rating.level, RiskLevel.none);
      expect(rating.isClear, isTrue);
      expect(rating.reasons, isEmpty);
    });

    test('a tag rule fires with his own words and his condition as the reason', () {
      final rating = RiskEngine.rateEntry(
        _entry('e1', 'بطاطا مقلية', tags: ['مقلي']),
        rules: [
          _tagRule('r1', 'مقلي', conditionId: _stomach.id, weight: RiskWeight.high, note: 'المقلي يتعب معدتي'),
        ],
        conditions: [_stomach],
      )!;
      expect(rating.score, 3);
      expect(rating.level, RiskLevel.medium);
      final reason = rating.reasons.single;
      expect(reason.ruleId, 'r1');
      expect(reason.tag, 'مقلي');
      expect(reason.conditionName, 'المعدة');
      expect(reason.note, 'المقلي يتعب معدتي');
      expect(reason.weight, RiskWeight.high);
      expect(reason.points, 3);
      expect(rating.conditionIds, ['c-stomach']);
    });

    test('a tag written with different harakat still matches, and the food\'s own tags count', () {
      final food = const Food(id: 'f1', name: 'بطاطا مقلية', tags: ['مَقلي']);
      final rating = RiskEngine.rateEntry(
        _entry('e1', 'بطاطا مقلية', foodId: 'f1'),
        rules: [_tagRule('r1', 'مقلي')],
        conditions: const [],
        food: food,
      )!;
      expect(rating.score, 2);
    });

    test('weights add up and the level follows the thresholds', () {
      final rules = [
        _tagRule('r1', 'مقلي', weight: RiskWeight.low),
        _tagRule('r2', 'ملح عالي', conditionId: _pressure.id, weight: RiskWeight.high),
      ];
      final entry = _entry('e1', 'مقلي مملح', tags: ['مقلي', 'ملح عالي']);
      final rating = RiskEngine.rateEntry(entry, rules: rules, conditions: [_pressure])!;
      expect(rating.score, 4);
      expect(rating.level, RiskLevel.medium);
      // Heaviest reason first.
      expect(rating.reasons.map((r) => r.ruleId), ['r2', 'r1']);

      expect(RiskEngine.levelOfEntry(0), RiskLevel.none);
      expect(RiskEngine.levelOfEntry(2), RiskLevel.low);
      expect(RiskEngine.levelOfEntry(3), RiskLevel.medium);
      expect(RiskEngine.levelOfEntry(5), RiskLevel.high);
    });

    test('a food rule matches by id, and by name for a free-text entry', () {
      final rule = FoodRule(
        id: 'r1',
        target: FoodRuleTarget.food,
        foodId: 'f9',
        foodName: 'قهوة',
        weight: RiskWeight.low,
        conditionId: _stomach.id,
      );
      final byId = RiskEngine.rateEntry(_entry('e1', 'قهوة', foodId: 'f9'), rules: [rule], conditions: [_stomach])!;
      expect(byId.score, 1);
      final byName = RiskEngine.rateEntry(_entry('e2', 'قَهوة'), rules: [rule], conditions: [_stomach])!;
      expect(byName.score, 1);
      final other = RiskEngine.rateEntry(_entry('e3', 'شاي'), rules: [rule], conditions: [_stomach])!;
      expect(other.score, 0);
    });

    test('a portion threshold needs the amount he logged', () {
      final rule = _tagRule('r1', 'سكر', minPortion: 3);
      final entry = _entry('e1', 'شاي', tags: ['سكر']);
      expect(RiskEngine.rateEntry(entry, rules: [rule], conditions: const [])!.score, 0);
      expect(
        RiskEngine.rateEntry(_entry('e2', 'شاي', tags: ['سكر'], portion: 2), rules: [rule], conditions: const [])!.score,
        0,
      );
      expect(
        RiskEngine.rateEntry(_entry('e3', 'شاي', tags: ['سكر'], portion: 3), rules: [rule], conditions: const [])!.score,
        2,
      );
      // The food's default portion counts when the entry has none.
      final food = const Food(id: 'f1', name: 'شاي', tags: ['سكر'], defaultPortion: 4);
      expect(
        RiskEngine.rateEntry(
          _entry('e4', 'شاي', foodId: 'f1'),
          rules: [rule],
          conditions: const [],
          food: food,
        )!.score,
        2,
      );
    });

    test('a time window counts only inside it, and wraps over midnight', () {
      final late = _tagRule('r1', 'كافيين', from: 20 * 60, to: 6 * 60, note: 'الكافيين المتأخر يقطع نومي');
      FoodEntry at(int hour, int minute) =>
          _entry('e$hour', 'قهوة', tags: ['كافيين'], at: DateTime(2026, 10, 10, hour, minute));
      expect(RiskEngine.rateEntry(at(13, 0), rules: [late], conditions: const [])!.score, 0);
      expect(RiskEngine.rateEntry(at(20, 0), rules: [late], conditions: const [])!.score, 2);
      expect(RiskEngine.rateEntry(at(23, 30), rules: [late], conditions: const [])!.score, 2);
      expect(RiskEngine.rateEntry(at(5, 59), rules: [late], conditions: const [])!.score, 2);
      expect(RiskEngine.rateEntry(at(6, 0), rules: [late], conditions: const [])!.score, 0);
      expect(late.windowLabel, '20:00–06:00');
    });

    test('anyFood with a window rates everything eaten in it', () {
      final rule = FoodRule(
        id: 'r1',
        target: FoodRuleTarget.anyFood,
        weight: RiskWeight.low,
        fromMinutes: 22 * 60,
        toMinutes: 24 * 60,
        note: 'الأكل بعد العشر',
      );
      expect(
        RiskEngine.rateEntry(_entry('e1', 'أي شي', at: DateTime(2026, 10, 10, 22, 30)), rules: [rule], conditions: const [])!.score,
        1,
      );
      expect(
        RiskEngine.rateEntry(_entry('e2', 'أي شي', at: DateTime(2026, 10, 10, 21)), rules: [rule], conditions: const [])!.score,
        0,
      );
    });
  });

  group('a whole day', () {
    final day = DateTime(2026, 10, 10);

    test('the day adds its entries up, merges a repeated rule into one reason and names the heaviest entry', () {
      final rules = [_tagRule('r1', 'مقلي', conditionId: _stomach.id, weight: RiskWeight.medium)];
      final entries = [
        _entry('e1', 'فلافل', tags: ['مقلي'], at: DateTime(2026, 10, 10, 8)),
        _entry('e2', 'بطاطا', tags: ['مقلي'], at: DateTime(2026, 10, 10, 14)),
        _entry('e3', 'سلطة', tags: ['خضار'], at: DateTime(2026, 10, 10, 19)),
      ];
      final risk = RiskEngine.rateDay(day: day, entries: entries, rules: rules, conditions: [_stomach])!;
      expect(risk.score, 4);
      expect(risk.level, RiskLevel.medium);
      expect(risk.reasons.single.ruleId, 'r1');
      expect(risk.reasons.single.points, 4);
      expect(risk.perEntry['e1']!.score, 2);
      expect(risk.perEntry['e3']!.score, 0);
      expect(risk.heaviestEntryId, 'e1');
    });

    test('a daily-limit rule never rates one entry and fires only above the limit', () {
      final rule = _tagRule('r1', 'مقلي', maxPerDay: 2, weight: RiskWeight.high, conditionId: _stomach.id);
      expect(rule.isDayRule, isTrue);
      final one = _entry('e1', 'فلافل', tags: ['مقلي']);
      // Only a day rule exists: a single entry gets no rating at all.
      expect(RiskEngine.rateEntry(one, rules: [rule], conditions: [_stomach]), isNull);

      final twoDays = RiskEngine.rateDay(
        day: day,
        entries: [one, _entry('e2', 'بطاطا', tags: ['مقلي'])],
        rules: [rule],
        conditions: [_stomach],
      )!;
      expect(twoDays.score, 0, reason: 'two is still within his own limit');

      final three = RiskEngine.rateDay(
        day: day,
        entries: [one, _entry('e2', 'بطاطا', tags: ['مقلي']), _entry('e3', 'سمبوسك', tags: ['مقلي'])],
        rules: [rule],
        conditions: [_stomach],
      )!;
      expect(three.score, 3);
      final reason = three.reasons.single;
      expect(reason.isDayReason, isTrue);
      expect(reason.dayCount, 3);
      expect(reason.maxPerDay, 2);
    });

    test('the day level has its own thresholds', () {
      expect(RiskEngine.levelOfDay(0), RiskLevel.none);
      expect(RiskEngine.levelOfDay(3), RiskLevel.low);
      expect(RiskEngine.levelOfDay(4), RiskLevel.medium);
      expect(RiskEngine.levelOfDay(8), RiskLevel.high);
    });

    test('the tags of a library food count for a day too', () {
      final foods = {'f1': const Food(id: 'f1', name: 'فلافل', tags: ['مقلي'])};
      final risk = RiskEngine.rateDay(
        day: day,
        entries: [_entry('e1', 'فلافل', foodId: 'f1')],
        rules: [_tagRule('r1', 'مقلي')],
        conditions: const [],
        foodsById: foods,
      )!;
      expect(risk.score, 2);
    });
  });

  test('entriesHit shows which entries a rule would flag (the editor preview)', () {
    final rule = _tagRule('r1', 'مقلي');
    final hits = RiskEngine.entriesHit(rule, [
      _entry('e1', 'فلافل', tags: ['مقلي']),
      _entry('e2', 'سلطة', tags: ['خضار']),
    ]);
    expect(hits.map((e) => e.id), ['e1']);
  });
}
