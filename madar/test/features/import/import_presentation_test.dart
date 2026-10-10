import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:madar/core/domain/budget_math.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/import/import_presentation.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  const ar = ImportFormats(languageCode: 'ar', digits: DigitStyle.auto);
  const arWestern = ImportFormats(languageCode: 'ar', digits: DigitStyle.western);
  const en = ImportFormats(languageCode: 'en', digits: DigitStyle.auto);

  test('percentages use the Arabic decimal separator and percent sign', () {
    expect(ar.percent(33.3), '٣٣٫٣٪');
    expect(ar.percent(50), '٥٠٪');
    expect(arWestern.percent(33.3), '33.3%');
    expect(en.percent(33.3), '33.3%');
    expect(en.percent(100), '100%');
  });

  test('dates follow the digit style in both directions', () {
    final d = DateTime(2026, 9, 27);
    expect(ar.date(d), isNot(matches(RegExp('[0-9]'))));
    expect(arWestern.date(d), isNot(matches(RegExp('[٠-٩]'))));
    expect(arWestern.date(d), contains('27'));
  });

  test('a budget warning reads with Arabic separators', () {
    final l = lookupL10n(const Locale('ar'));
    final text = ar.budgetIssue(
      l,
      const ImportIssue(
        ImportIssueCode.budget,
        args: {'kind': 'percentOver100', 'name': 'البيت', 'percent': 120.5},
      ),
    );
    expect(text, contains('١٢٠٫٥٪'));
    expect(BudgetWarningKind.percentOver100.name, 'percentOver100');
  });
}
