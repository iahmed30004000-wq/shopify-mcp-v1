// Every sentence the bridge says, in both languages: a problem reads as
// something he can act on, a change line is one short line (it goes on the
// checklist), and the before line names what he has today.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/ai_bridge/ai_bridge.dart';

import 'plan_fixtures.dart';

void main() {
  // Month and weekday names come from intl, which needs its locale data
  // loaded outside a widget test.
  setUpAll(initializeDateFormatting);

  for (final language in ['ar', 'en']) {
    final texts = AiBridgeTexts(lookupL10n(Locale(language)), MadarFormatter(languageCode: language));

    group('in $language', () {
      final validation = PlanValidator(testCatalog()).parse(encodePlan(goodPlan()));
      final previews = PlanPreviewBuilder(testCatalog()).build(validation);

      test('every suggestion has a change line, a before line and a short checklist line', () {
        expect(previews, hasLength(8));
        for (final p in previews) {
          final change = texts.changeLines(p);
          expect(change, isNotEmpty, reason: p.id);
          for (final line in change) {
            expect(line.trim(), isNotEmpty, reason: p.id);
            expect(line, isNot(contains('{')), reason: '${p.id}: an unfilled placeholder');
            expect(line.length, lessThan(120), reason: '${p.id}: too long for one line');
          }
          expect(texts.beforeLines(p).single.trim(), isNotEmpty, reason: p.id);
          expect(texts.checklistLine(p.oneLine).trim(), isNotEmpty);
          expect(texts.kind(p.kind).trim(), isNotEmpty);
          expect(texts.status(p.status).trim(), isNotEmpty);
        }
      });

      test('the before line of the envelope and the habit name what he has today', () {
        final budget = previews.firstWhere((p) => p.id == 'b1');
        expect(texts.beforeLines(budget).single, contains('بقالة'));
        final habit = previews.firstWhere((p) => p.id == 'h1');
        expect(texts.beforeLines(habit).single, contains('مشي'));
        expect(texts.changeLines(habit).first, contains('مشي'));
      });

      test('every problem code has its own sentence, with no placeholder left in it', () {
        for (final code in PlanProblemCode.values) {
          final line = texts.problem(PlanProblem(code, itemId: 'h1', path: 'items[0].data.day', detail: '٥', limit: 7));
          expect(line.trim(), isNotEmpty, reason: code.name);
          expect(line, isNot(contains('{')), reason: code.name);
        }
        for (final reason in PlanEditReason.values) {
          expect(texts.editReason(reason).trim(), isNotEmpty, reason: reason.name);
        }
      });

      test('a refused health suggestion says why, and names the words it hit', () {
        final v = PlanValidator(testCatalog()).parse(
          encodePlan(
            planWith({
              'id': 'd1',
              'kind': 'task',
              'title': 'خُذ ٦٠٠ ملغ بعد الغدا',
              'reason': 'لأن السكر بيرتفع بعد الغدا.',
              'data': {'window': 'asr'},
            }),
          ),
        );
        final problem = v.problemsFor('d1').firstWhere((p) => p.code == PlanProblemCode.healthAdvice);
        final line = texts.problem(problem);
        expect(line.trim(), isNotEmpty);
        expect(line, contains('600'));
      });

      test('the counter and the default name read in his digits', () {
        final line = texts.progress(const PlanProgress(done: 2, total: 4));
        expect(line, contains(language == 'ar' ? '٢' : '2'));
        expect(texts.defaultPlanName(planToday).trim(), isNotEmpty);
      });
    });
  }
}
