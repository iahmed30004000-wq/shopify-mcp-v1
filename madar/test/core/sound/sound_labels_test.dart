import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/profiles.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/core/sound/sound_labels.dart';

void main() {
  test('every profile and category has a distinct Arabic and English label', () {
    for (final code in ['ar', 'en']) {
      final l = lookupL10n(Locale(code));
      final names = {for (final id in SoundProfiles.ids) l.soundProfileName(id)};
      final descriptions = {for (final id in SoundProfiles.ids) l.soundProfileDescription(id)};
      final categories = {for (final c in SoundCategory.values) l.soundCategoryName(c)};
      expect(names.length, SoundProfiles.ids.length, reason: code);
      expect(descriptions.length, SoundProfiles.ids.length, reason: code);
      expect(categories.length, SoundCategory.values.length, reason: code);
      for (final s in [...names, ...descriptions, ...categories, l.soundPrayerMuteNote, l.soundPreview]) {
        expect(s.trim(), isNotEmpty);
      }
    }
    final ar = lookupL10n(const Locale('ar'));
    expect(ar.soundProfileName('desert'), contains('عود'));
    expect(ar.soundProfileDescription('lapis'), contains('الراست'));
    expect(ar.soundProfileName('unknown'), ar.soundProfileName('lapis'));
  });
}
