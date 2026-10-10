// The gate of the AI bridge: one good answer, and a dozen bad ones.
//
// Every bad payload must come back as a list of problems – never a crash,
// never a half-accepted plan – and the health rule must refuse a
// diagnosis, a treatment or a dose wherever it is hidden.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';

import 'plan_fixtures.dart';

PlanValidation check(Object payload, {PlanCatalog? catalog}) {
  final validator = PlanValidator(catalog ?? testCatalog());
  return payload is String ? validator.parse(payload) : validator.validate(payload);
}

Set<PlanProblemCode> codesOf(PlanValidation v) => {for (final p in v.problems) p.code};

void main() {
  group('a good answer', () {
    test('every suggestion is accepted, with its reason and its references resolved', () {
      final v = check(encodePlan(goodPlan()));
      expect(v.fatal, isEmpty, reason: '${v.problems}');
      expect(v.plan, isNotNull);
      expect(v.plan!.items, hasLength(8));
      expect(v.accepted, hasLength(8));
      expect(v.rejected, isEmpty);
      expect(v.isUsable, isTrue);
      for (final item in v.plan!.items) {
        expect(item.reason.trim(), isNotEmpty, reason: item.id);
      }
      expect(v.plan!.title, 'خطة تشرين الأول');
      expect(v.plan!.generatedFor, DateTime(2026, 10, 10));
    });

    test('the flagged over-claim travels as a warning and is never an item', () {
      final v = check(encodePlan(goodPlan()));
      expect(v.plan!.source.claimsFlagged, hasLength(1));
      expect(v.plan!.source.completeness, isNotNull);
      // The claim mentions curing disease; it must not be refused, because
      // it is shown as a warning and never applied.
      expect(codesOf(v).contains(PlanProblemCode.healthAdvice), isFalse);
    });

    test('a Markdown code fence around the JSON is tolerated', () {
      final v = check('```json\n${encodePlan(goodPlan())}\n```');
      expect(v.fatal, isEmpty);
      expect(v.accepted, hasLength(8));
    });

    test('the same answer always has the same fingerprint, whatever the key order', () {
      final a = check(encodePlan(goodPlan())).plan!;
      final reordered = jsonDecode(encodePlan(goodPlan())) as Map<String, Object?>;
      final b = check({
        'items': reordered['items'],
        'version': 1,
        'madar': 'plan',
        'title': reordered['title'],
        'summary': reordered['summary'],
        'generatedFor': reordered['generatedFor'],
        'source': reordered['source'],
      }).plan!;
      expect(b.canonical(), a.canonical());
    });

    test('the example in the prompt is itself a valid plan', () {
      final v = check(jsonEncode(PlanPrompt.exampleAnswer), catalog: PlanCatalog(today: planToday));
      expect(v.fatal, isEmpty, reason: '${v.problems}');
      expect(v.accepted, hasLength(2));
      expect(v.problems.where((p) => p.rejects), isEmpty);
    });
  });

  group('the whole payload is refused', () {
    test('1. not JSON at all', () {
      final v = check('هاي خطتك: اعمل كذا وكذا');
      expect(v.plan, isNull);
      expect(codesOf(v), contains(PlanProblemCode.notJson));
    });

    test('2. JSON, but not an object', () {
      final v = check('[1, 2, 3]');
      expect(v.plan, isNull);
      expect(codesOf(v), contains(PlanProblemCode.notAnObject));
    });

    test('3. another Madar file (a data export), not a plan', () {
      final v = check('{"format":"madar.snapshot","formatVersion":1,"tables":{}}');
      expect(v.plan, isNull);
      expect(codesOf(v), contains(PlanProblemCode.notAMadarPlan));
    });

    test('4. a version from a newer Madar', () {
      final v = check({...goodPlan(), 'version': 2});
      expect(v.plan, isNull);
      expect(codesOf(v), contains(PlanProblemCode.unsupportedVersion));
      expect(v.problems.first.detail, '2');
    });

    test('5. an empty plan', () {
      final v = check({'madar': 'plan', 'version': 1, 'items': <Object?>[]});
      expect(v.plan, isNull);
      expect(codesOf(v), contains(PlanProblemCode.noItems));
    });

    test('6. a 5 MB payload', () {
      final big = {
        ...goodPlan(),
        'summary': 'ا' * (5 * 1024 * 1024),
      };
      final v = check(encodePlan(big));
      expect(v.plan, isNull);
      expect(codesOf(v), contains(PlanProblemCode.tooBig));
      expect(v.problems.single.limit, PlanLimits.maxPayloadBytes);
    });

    test('7. nested far deeper than a plan ever is', () {
      Object? nest = 'x';
      for (var i = 0; i < 40; i++) {
        nest = [nest];
      }
      final v = check({'madar': 'plan', 'version': 1, 'items': nest});
      expect(v.plan, isNull);
      expect(codesOf(v), contains(PlanProblemCode.tooDeep));
    });

    test('8. a top-level field the contract does not know', () {
      final v = check({...goodPlan(), 'painNotes': 'الوجع كان سبعة أمس'});
      expect(codesOf(v), contains(PlanProblemCode.unknownField));
      expect(v.problems.first.detail, 'painNotes');
    });
  });

  group('one suggestion is refused, the rest survive', () {
    test('9. no reason', () {
      final items = (goodPlan()['items']! as List).toList();
      items[0] = Map<String, Object?>.from(items.first as Map)..remove('reason');
      final v = check({'madar': 'plan', 'version': 1, 'items': items});
      expect(v.problemsFor('h1').map((p) => p.code), contains(PlanProblemCode.missingReason));
      expect(v.rejected, contains('h1'));
      // The other seven are still reviewable.
      expect(v.accepted.map((i) => i.id), containsAll(['b1', 't1', 'n1']));
      expect(v.isUsable, isTrue);
    });

    test('10. an envelope he does not have', () {
      final v = check(
        planWith({
          'id': 'b9',
          'kind': 'budgetTweak',
          'title': 'نزّل مصروف المطاعم',
          'reason': 'لأن المطاعم أكبر بند عندك.',
          'data': {'envelopeRef': 'مطاعم', 'newAmount': 50},
        }),
      );
      final problems = v.problemsFor('b9');
      expect(problems.map((p) => p.code), contains(PlanProblemCode.unknownReference));
      expect(problems.first.detail, 'مطاعم');
      expect(v.accepted, isEmpty);
      expect(v.isUsable, isFalse);
    });

    test('11. a food he never logged', () {
      final v = check(
        planWith({
          'id': 'm9',
          'kind': 'mealChange',
          'title': 'حطّ سلمون على الغدا',
          'reason': 'لأن الغدا نشويات لحاله.',
          'data': {'op': 'addFood', 'slotRef': 'غدا', 'foodRef': 'سلمون نرويجي'},
        }),
      );
      expect(v.problemsFor('m9').map((p) => p.code), contains(PlanProblemCode.unknownReference));
    });

    test('12. a number out of range', () {
      final v = check(
        planWith({
          'id': 'b8',
          'kind': 'budgetTweak',
          'title': 'زيد التوفير',
          'reason': 'لأن المدخرات واقفة من ثلاث شهور.',
          'data': {'envelopeRef': 'توفير', 'newPercent': 500},
        }),
      );
      final problems = v.problemsFor('b8');
      expect(problems.map((p) => p.code), contains(PlanProblemCode.outOfRange));
      expect(problems.first.path, 'items[0].data.newPercent');
    });

    test('13. a diagnosis', () {
      final v = check(
        planWith({
          'id': 'd1',
          'kind': 'note',
          'title': 'عندك مرض السكري',
          'reason': 'سكر الصائم عندك مرتفع بثلاث تحاليل.',
          'data': {'body': 'التشخيص واضح من التحاليل.'},
        }),
      );
      final problems = v.problemsFor('d1');
      expect(problems.map((p) => p.code), contains(PlanProblemCode.healthAdvice));
      expect(v.rejected, contains('d1'));
    });

    test('14. a dose – even hidden in a task title', () {
      final v = check(
        planWith({
          'id': 'd2',
          'kind': 'task',
          'title': 'خُذ ألفا ليبويك أسيد 600 مجم بعد الغدا',
          'reason': 'لأن السكر بيرتفع بعد الغدا.',
          'data': {'window': 'asr'},
        }),
      );
      final problems = v.problemsFor('d2');
      expect(problems.map((p) => p.code), contains(PlanProblemCode.healthAdvice));
      expect(problems.first.detail, contains('600'));
    });

    test('15. "stop your medicine" is refused too', () {
      final v = check(
        planWith({
          'id': 'd3',
          'kind': 'habit',
          'title': 'اوقف الدواء وجرّب الصيام',
          'reason': 'لأن الصيام ظهر عليه تحسّن بأيامك.',
          'data': {'category': 'صيام'},
        }),
      );
      expect(v.problemsFor('d3').map((p) => p.code), contains(PlanProblemCode.healthAdvice));
    });

    test('16. free text we never sent, smuggled into an item', () {
      final v = check(
        planWith({
          'id': 'x1',
          'kind': 'note',
          'title': 'ملاحظة',
          'reason': 'سبب مكتوب تمام.',
          'painNote': 'كتبت إن الركبة وجعتك أمس',
          'data': {'body': 'نص'},
        }),
      );
      final problems = v.problemsFor('x1');
      expect(problems.map((p) => p.code), contains(PlanProblemCode.unknownField));
      expect(problems.first.detail, 'painNote');
      expect(v.rejected, contains('x1'));
    });

    test('17. an unknown key inside data', () {
      final v = check(
        planWith({
          'id': 'x2',
          'kind': 'habit',
          'title': 'عادة',
          'reason': 'سبب مكتوب تمام.',
          'data': {'category': 'حركة', 'dose': '600 مجم'},
        }),
      );
      expect(v.problemsFor('x2').map((p) => p.code), contains(PlanProblemCode.unknownField));
    });

    test('18. two suggestions with the same id', () {
      final items = (goodPlan()['items']! as List).take(2).toList();
      final twin = Map<String, Object?>.from(items.first as Map);
      final v = check({'madar': 'plan', 'version': 1, 'items': [...items, twin]});
      expect(codesOf(v), contains(PlanProblemCode.duplicateItemId));
      expect(v.plan!.items, hasLength(2));
    });

    test('19. an unknown kind, and an unknown window value', () {
      final v = check({
        'madar': 'plan',
        'version': 1,
        'items': [
          {'id': 'u1', 'kind': 'buyMeAHouse', 'title': 't', 'reason': 'سبب كافي', 'data': <String, Object?>{}},
          {
            'id': 'u2',
            'kind': 'task',
            'title': 'مهمة',
            'reason': 'سبب كافي',
            'data': {'window': 'midnight'},
          },
        ],
      });
      expect(codesOf(v), containsAll([PlanProblemCode.unknownKind, PlanProblemCode.unknownValue]));
      expect(v.rejected, contains('u2'));
    });

    test('20. a day that cannot be read, and one a year and a half away', () {
      final v = check({
        'madar': 'plan',
        'version': 1,
        'items': [
          {
            'id': 'p1',
            'kind': 'task',
            'title': 'مهمة',
            'reason': 'سبب كافي',
            'data': {'day': 'الخميس الجاي'},
          },
          {
            'id': 'p2',
            'kind': 'task',
            'title': 'مهمة',
            'reason': 'سبب كافي',
            'data': {'day': '2028-10-10'},
          },
        ],
      });
      expect(v.problemsFor('p1').map((p) => p.code), contains(PlanProblemCode.badDay));
      expect(v.problemsFor('p2').map((p) => p.code), contains(PlanProblemCode.badDay));
    });

    test('21. a dependency that is not in the plan, and a circle', () {
      final v = check({
        'madar': 'plan',
        'version': 1,
        'items': [
          {
            'id': 'a',
            'kind': 'note',
            'title': 'أ',
            'reason': 'سبب كافي',
            'dependsOn': ['b'],
            'data': {'body': 'x'},
          },
          {
            'id': 'b',
            'kind': 'note',
            'title': 'ب',
            'reason': 'سبب كافي',
            'dependsOn': ['a'],
            'data': {'body': 'y'},
          },
          {
            'id': 'c',
            'kind': 'note',
            'title': 'ج',
            'reason': 'سبب كافي',
            'dependsOn': ['nope'],
            'data': {'body': 'z'},
          },
        ],
      });
      expect(codesOf(v), containsAll([PlanProblemCode.circularDependency, PlanProblemCode.missingDependency]));
      expect(v.rejected, containsAll(['a', 'b', 'c']));
    });

    test('22. a deliberately hostile payload is refused item by item, and never crashes', () {
      final v = check({
        'madar': 'plan',
        'version': 1,
        'items': [
          {
            'id': '../../etc/passwd',
            'kind': 'note',
            'title': 'x',
            'reason': 'سبب كافي',
            'data': {'body': 'y'},
          },
          {
            'id': 'ctrl',
            'kind': 'note',
            'title': 'عنوان\u0000فيه رمز',
            'reason': 'سبب كافي',
            'data': {'body': 'y'},
          },
          {
            'id': 'huge',
            'kind': 'note',
            'title': 'ع' * 400,
            'reason': 'ب' * 900,
            'data': {'body': 'y'},
          },
          {
            'id': 'types',
            'kind': 'budgetTweak',
            'title': 'x',
            'reason': 'سبب كافي',
            'data': {'envelopeRef': 'بقالة', 'newAmount': 'ألف دينار', 'period': 7},
          },
          {
            'id': 'proto',
            'kind': 'note',
            'title': 'x',
            'reason': 'سبب كافي',
            '__proto__': {'admin': true},
            'data': {'body': 'y'},
          },
          {
            'id': 'nulls',
            'kind': 'task',
            'title': null,
            'reason': null,
            'data': null,
          },
        ],
      });
      expect(v.problems, isNotEmpty);
      expect(
        codesOf(v),
        containsAll([
          PlanProblemCode.controlCharacters,
          PlanProblemCode.tooLong,
          PlanProblemCode.wrongType,
          PlanProblemCode.unknownField,
          PlanProblemCode.missingReason,
        ]),
      );
      expect(v.accepted, isEmpty);
      expect(v.isUsable, isFalse);
    });

    test('23. text around the JSON is reported, and the plan inside is still read', () {
      final v = check('أهلاً! هاي خطتك:\n${encodePlan(goodPlan())}\nبالتوفيق يا صاحبي.');
      expect(codesOf(v), contains(PlanProblemCode.trailingText));
      expect(v.fatal, isEmpty);
      expect(v.accepted, hasLength(8));
    });
  });

  group('kinds kept for later', () {
    test('a recipe validates, is flagged as deferred and never rejected', () {
      final v = check(
        planWith({
          'id': 'k1',
          'kind': 'recipe',
          'title': 'شوربة عدس',
          'reason': 'لأن المونة عندك فيها عدس.',
          'data': {'servings': 4, 'minutes': 30},
        }),
      );
      expect(v.fatal, isEmpty);
      expect(v.accepted.map((i) => i.id), contains('k1'));
      final problems = v.problemsFor('k1');
      expect(problems.single.code, PlanProblemCode.deferredKind);
      expect(problems.single.rejects, isFalse);
    });
  });

  group('the health guard', () {
    test('tracking and practising pass', () {
      for (final text in [
        'مشي عشرين دقيقة بعد العشا',
        'تابع نوعية النوم من صفر لعشرة',
        'اشرب لتر ماء قبل الظهر',
        'walk twenty minutes after dinner',
      ]) {
        expect(HealthGuard.scanOne(text), isNull, reason: text);
      }
    });

    test('a dose, a diagnosis, a treatment claim and a medication change do not', () {
      expect(HealthGuard.scanOne('٦٠٠ ملغ قبل النوم')?.kind, HealthFlagKind.dose);
      expect(HealthGuard.scanOne('take 5000 IU daily')?.kind, HealthFlagKind.dose);
      expect(HealthGuard.scanOne('الجرعة مرتين باليوم')?.kind, HealthFlagKind.dose);
      expect(HealthGuard.scanOne('التشخيص: التهاب مزمن')?.kind, HealthFlagKind.diagnosis);
      expect(HealthGuard.scanOne('هذا بيشفي المرض')?.kind, HealthFlagKind.treatment);
      expect(HealthGuard.scanOne('بلاش دواء بعد اليوم')?.kind, HealthFlagKind.medicationChange);
      expect(HealthGuard.scanOne('this cures diabetes')?.kind, HealthFlagKind.treatment);
    });
  });
}
