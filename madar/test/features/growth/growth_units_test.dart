import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/growth/domain/growth_units.dart';
import 'package:madar/features/growth/presentation/growth_texts.dart';

void main() {
  group('GrowthUnit', () {
    test('recognises known units in any spelling', () {
      expect(GrowthUnit.parse('pages').kind, GrowthUnitKind.pages);
      expect(GrowthUnit.parse('  Pages ').kind, GrowthUnitKind.pages);
      expect(GrowthUnit.parse('صفحات').kind, GrowthUnitKind.pages);
      expect(GrowthUnit.parse('صفحة').kind, GrowthUnitKind.pages);
      expect(GrowthUnit.parse('ساعات').kind, GrowthUnitKind.hours);
      expect(GrowthUnit.parse('دورة').kind, GrowthUnitKind.courses);
      expect(GrowthUnit.parse('كلمات').kind, GrowthUnitKind.words);
      expect(GrowthUnit.parse('مُحاضَرات').kind, GrowthUnitKind.lectures, reason: 'diacritics ignored');
    });

    test('keeps anything else as the user typed it', () {
      final u = GrowthUnit.parse(' حلقات ');
      expect(u.isKnown, isFalse);
      expect(u.stored, 'حلقات');
      expect(GrowthUnit.parse('').isEmpty, isTrue);
      expect(GrowthUnit.parse(null), GrowthUnit.none);
    });

    test('stores known units by key', () {
      expect(const GrowthUnit.known(GrowthUnitKind.hours).stored, 'hours');
      expect(GrowthUnit.parse('ساعة').stored, 'hours');
    });

    test('quick amounts and steps follow the unit', () {
      expect(const GrowthUnit.known(GrowthUnitKind.pages).quickAmounts(300), [1, 5, 10, 20]);
      expect(const GrowthUnit.known(GrowthUnitKind.hours).quickAmounts(40), [0.5, 1, 2]);
      expect(const GrowthUnit.known(GrowthUnitKind.hours).stepFor(40), 0.5);
      expect(const GrowthUnit.custom('x').quickAmounts(8), [1, 2, 3]);
      expect(const GrowthUnit.custom('x').quickAmounts(150), [1, 5, 10]);
      expect(const GrowthUnit.custom('x').quickAmounts(1500), [5, 10, 25, 50]);
      expect(const GrowthUnit.custom('x').stepFor(5000), 10);
    });
  });

  group('GrowthRate', () {
    const pages = GrowthUnit.known(GrowthUnitKind.pages);
    const hours = GrowthUnit.known(GrowthUnitKind.hours);

    test('needed rates round up to whole things', () {
      expect(GrowthRate.of(4.2, pages, roundUp: true), const GrowthRate(5, perWeek: false));
      expect(GrowthRate.of(4.0, pages, roundUp: true), const GrowthRate(4, perWeek: false));
      expect(GrowthRate.of(4.2, pages), const GrowthRate(4, perWeek: false));
    });

    test('below one a day switches to a weekly rate', () {
      expect(GrowthRate.of(0.4, pages, roundUp: true), const GrowthRate(3, perWeek: true));
      expect(GrowthRate.of(0.02, pages), const GrowthRate(1, perWeek: true), reason: 'never rounds to zero');
    });

    test('hours keep tenths', () {
      expect(GrowthRate.of(0.25, hours), const GrowthRate(0.3, perWeek: false));
      expect(GrowthRate.of(1.44, hours, roundUp: true), const GrowthRate(1.5, perWeek: false));
    });
  });

  group('GrowthTexts', () {
    GrowthTexts texts(String lang) => GrowthTexts(lookupL10n(Locale(lang)), MadarFormatter(languageCode: lang));
    const pages = GrowthUnit.known(GrowthUnitKind.pages);

    test('Arabic plurals with Arabic-Indic digits', () {
      final t = texts('ar');
      expect(t.amount(pages, 1), 'صفحة واحدة');
      expect(t.amount(pages, 2), 'صفحتان');
      expect(t.amount(pages, 5), '٥ صفحات');
      expect(t.amount(pages, 11), '١١ صفحة');
      expect(t.amount(pages, 300), '٣٠٠ صفحة');
      expect(t.amount(pages, 2.5), '٢٫٥ صفحة');
      expect(t.amount(const GrowthUnit.known(GrowthUnitKind.hours), 1.5), '١٫٥ ساعة');
      expect(t.rate(pages, 12), '١٢ صفحة يوميًا');
      expect(t.rate(pages, 0.4, needed: true), '٣ صفحات أسبوعيًا');
    });

    test('English plurals', () {
      final t = texts('en');
      expect(t.amount(pages, 1), '1 page');
      expect(t.amount(pages, 12), '12 pages');
      expect(t.amount(pages, 1250), '1,250 pages');
      expect(t.rate(const GrowthUnit.known(GrowthUnitKind.hours), 1.5), '1.5 hours a day');
    });

    test('custom units are isolated, empty units are plain numbers', () {
      final t = texts('ar');
      expect(t.amount(const GrowthUnit.custom('episodes'), 3), '٣ \u2068episodes\u2069');
      expect(t.amount(GrowthUnit.none, 42), '٤٢');
    });

    test('signed amounts', () {
      expect(texts('en').signed(5), '+5');
      expect(texts('ar').signed(5), '؜+٥');
    });
  });
}
