// Material's own numbers – the calendar of a date field, its month header –
// follow the user's digit style like everything Madar formats itself.
// (Material formats with intl's `ar` data, which writes Western digits: an
// Arabic-Indic app used to show a calendar of 1 … 30.)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/contrast.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';

import 'text_scan.dart';

Future<void> _pumpCalendar(WidgetTester tester, {required String lang, required DigitStyle digits}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MadarFormatScope(digits: digits, child: child!),
      home: Scaffold(
        body: CalendarDatePicker(
          initialDate: DateTime(2026, 9, 27),
          currentDate: DateTime(2026, 9, 27),
          firstDate: DateTime(2026),
          lastDate: DateTime(2027),
          onDateChanged: (_) {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets("why: Material's own Arabic calendar mixes Arabic-Indic dates with Western day numbers", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        home: Scaffold(
          body: CalendarDatePicker(
            initialDate: DateTime(2026, 9, 27),
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
            onDateChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('27'), findsOneWidget);
    expect(find.textContaining('٢٠٢٦'), findsWidgets);
  });

  testWidgets('Arabic (automatic digits): the calendar counts in Arabic-Indic digits', (tester) async {
    await _pumpCalendar(tester, lang: 'ar', digits: DigitStyle.auto);
    expect(find.text('٢٧'), findsOneWidget);
    expect(find.textContaining('٢٠٢٦'), findsWidgets);
    expect(paintedStrings(tester).where(westernDigit.hasMatch), isEmpty);
    // Material's own strings stay Arabic and right to left.
    expect(Directionality.of(tester.element(find.byType(CalendarDatePicker))), TextDirection.rtl);
    expect(find.textContaining('سبتمبر'), findsWidgets);
  });

  testWidgets('Arabic with Western digits chosen: 1 … 30', (tester) async {
    await _pumpCalendar(tester, lang: 'ar', digits: DigitStyle.western);
    expect(find.text('27'), findsOneWidget);
    expect(paintedStrings(tester).where(easternDigit.hasMatch), isEmpty);
  });

  testWidgets('English: Western digits', (tester) async {
    await _pumpCalendar(tester, lang: 'en', digits: DigitStyle.auto);
    expect(find.text('27'), findsOneWidget);
    expect(find.textContaining('September 2026'), findsWidgets);
  });

  testWidgets('switching the digit style re-formats the open calendar at once', (tester) async {
    await _pumpCalendar(tester, lang: 'ar', digits: DigitStyle.auto);
    expect(find.text('٢٧'), findsOneWidget);
    await _pumpCalendar(tester, lang: 'ar', digits: DigitStyle.western);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('٢٧'), findsNothing);
  });

  testWidgets("the calendar's month header reads at AA in every theme (not onSurface at 60 %)", (tester) async {
    for (final id in MadarThemeId.values) {
      final theme = buildMadarTheme(id, arabic: false);
      final t = theme.extension<MadarTokens>()!;
      expect(theme.datePickerTheme.subHeaderForegroundColor, t.textSecondary);
      expect(MadarContrast.minRatio(t.textSecondary, MadarPalettes.textSurfaces(t)), greaterThanOrEqualTo(4.5));
    }
  });

  test('the delegate picks Egyptian Arabic data only for Arabic-Indic Arabic', () {
    const on = MadarMaterialDigitsDelegate(arabicIndic: true);
    const off = MadarMaterialDigitsDelegate(arabicIndic: false);
    expect(on.localeFor(const Locale('ar')), const Locale('ar', 'EG'));
    expect(on.localeFor(const Locale('en')), const Locale('en'));
    expect(off.localeFor(const Locale('ar')), const Locale('ar'));
    expect(on.shouldReload(off), isTrue);
    expect(on.shouldReload(const MadarMaterialDigitsDelegate(arabicIndic: true)), isFalse);
  });
}
