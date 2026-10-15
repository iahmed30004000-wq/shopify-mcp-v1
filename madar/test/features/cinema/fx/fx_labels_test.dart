import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';

void main() {
  test('FX settings and leader captions are localised in Arabic and English', () {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      final l10n = lookupL10n(locale);
      final labels = {for (final q in FilmQuality.values) q.label(l10n)};
      expect(labels.length, FilmQuality.values.length, reason: locale.languageCode);
      expect(labels.every((s) => s.trim().isNotEmpty), isTrue);
      expect(filmLookHeading(l10n), isNotEmpty);
      expect(reelCaption(l10n, '١'), endsWith('١'));
    }
    expect(filmLookHeading(lookupL10n(const Locale('ar'))), 'مظهر الفيلم');
  });
}
