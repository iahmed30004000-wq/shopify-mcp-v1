// The sentences «السفرة» says. The one that matters most: when a unit
// cannot be converted she is told so, in her words, with no number in it.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/sufra/sufra.dart';

import 'sufra_fixtures.dart';

void main() {
  late SufraTexts ar;
  late SufraTexts en;

  setUpAll(() {
    initializeDateFormatting();
    ar = SufraTexts(lookupL10n(const Locale('ar')), const MadarFormatter(languageCode: 'ar', digits: DigitStyle.arabicIndic));
    en = SufraTexts(lookupL10n(const Locale('en')), const MadarFormatter(languageCode: 'en', digits: DigitStyle.western));
  });

  IngredientCheck checkOf(Recipe recipe, PantryBoard pantry) =>
      PantryMatcher.match(recipe, pantry: pantry).checks.first;

  test('a missing thing says how much, in her digits', () {
    final c = checkOf(
      dish('r1', 'مقلوبة', ingredients: [ing('دجاج', quantity: 2, unit: 'فرخة')]),
      board(const []),
    );
    final line = ar.check(c);
    expect(line, contains('دجاج'));
    expect(line, contains('٢'));
    expect(line, isNot(contains('2')));
  });

  test('a short thing says what is there and what it needs', () {
    final c = checkOf(
      dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 2, unit: 'كيلو')]),
      board([item('رز', quantity: 1200, unit: 'غرام')]),
    );
    expect(c.verdict, IngredientVerdict.short);
    final line = en.check(c);
    expect(line, contains('1.2'));
    expect(line, contains('2'));
    expect(line, contains('رز'));
  });

  test('a unit it cannot convert says «ما بعرف أحسب» and carries no made-up amount', () {
    final c = checkOf(
      dish('r1', 'كبسة', ingredients: [ing('رز', quantity: 2, unit: 'كوب')]),
      board([item('رز', quantity: 5, unit: 'كيلو')]),
    );
    expect(c.verdict, IngredientVerdict.unknownUnit);
    final line = ar.check(c);
    expect(line, contains('ما بعرف أحسب'));
    expect(line, contains('كوب'));
    expect(line, contains('كيلو'));
    expect(line, isNot(contains('٥')), reason: 'what is in the house is not an answer to what the dish needs');
  });

  test('an amount she never typed says so', () {
    final c = checkOf(
      dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 2, unit: 'كيلو')]),
      board([item('رز', unit: 'كيلو')]),
    );
    expect(ar.check(c), contains('ما كتبتي قديش'));
  });

  test('two candidates are both named', () {
    final c = checkOf(
      dish('r1', 'مجدرة', ingredients: [ing('رز', quantity: 1, unit: 'كيلو')]),
      board([item('رز بسمتي', quantity: 2, unit: 'كيلو', id: 'a'), item('رز مصري', quantity: 2, unit: 'كيلو', id: 'b')]),
    );
    final line = ar.check(c);
    expect(line, contains('رز بسمتي'));
    expect(line, contains('رز مصري'));
  });

  test('an amount with no number at all is empty, never a zero', () {
    expect(ar.amount(null, null), '');
    expect(ar.amount(null, 'كيلو'), contains('كيلو'));
    expect(ar.amount(null, 'كيلو'), isNot(contains('٠')));
  });

  test('the four verdicts each have their own sentence', () {
    final said = {for (final v in MatchVerdict.values) ar.verdict(v)};
    expect(said, hasLength(MatchVerdict.values.length));
  });

  test('every constraint breach has a sentence, and an allergy names who it is for', () {
    for (final breach in ConstraintBreach.values) {
      expect(ar.breach(ConstraintHit(breach, term: 'فول سوداني')), isNotEmpty, reason: breach.name);
    }
    expect(
      ar.breach(const ConstraintHit(ConstraintBreach.allergy, term: 'فول سوداني', who: 'أحمد')),
      contains('أحمد'),
    );
  });

  test('every pantry state and every rule kind has a sentence', () {
    expect({for (final s in PantryState.values) ar.state(s)}, hasLength(PantryState.values.length));
    expect({for (final k in KitchenRuleKind.values) ar.ruleKind(k)}, hasLength(KitchenRuleKind.values.length));
  });

  test('an imported dish always says whose it is', () {
    final mine = dish('r1', 'مجدرة');
    final hers = dish('r2', 'ملوخية', source: RecipeSource.imported, sourceName: 'خالتي أم محمد');
    expect(ar.source(mine), isNot(contains('خالتي')));
    expect(ar.source(hers), contains('خالتي أم محمد'));
  });

  test('a held dish says when she cooked it and when it comes back', () {
    final hold = NoRepeat.check(
      [cooked('r1', today.subtract(const Duration(days: 2)))],
      recipeId: 'r1',
      today: today,
      windowDays: 14,
    );
    expect(ar.held(hold), isNotNull);
    expect(ar.freeFrom(hold), isNotNull);
    expect(ar.held(RepeatHold.free), isNull);
    expect(ar.freeFrom(RepeatHold.free), isNull);
  });

  test('her window choices read in her digits, with "no limit" for zero', () {
    final choices = ar.windowChoices;
    expect(choices.first.$1, 0);
    expect(choices.first.$2, contains('بلا حد'));
    expect(choices.last.$2, isNot(contains('30')));
  });
}
