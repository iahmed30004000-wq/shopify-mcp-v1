import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';

void main() {
  test('every era has a complete skin', () {
    expect(EraSkins.all, hasLength(Era.values.length));
    for (final era in Era.values) {
      final s = EraSkins.of(era);
      expect(s.era, era);
      expect(identical(EraSkins.of(era), s), isTrue, reason: 'skins are cached');
      expect(s.grade.projectionFps, inInclusiveRange(12, 30));
      expect(s.ink.boilFps, inInclusiveRange(0, 24));
      expect(['Amiri', 'ReemKufi', 'PlexArabic'], contains(s.titles.fontFamily), reason: 'bundled fonts only');
      expect(s.stage.footlights, greaterThan(0));
      for (final role in PaletteRole.values) {
        expect(s.palette.resolve(role).a, 1.0, reason: '$era $role must be opaque');
      }
    }
  });

  test('monochrome eras grade to duotone, the 80s go through the VHS pass', () {
    for (final era in Era.values) {
      final g = EraSkins.of(era).grade;
      if (era.isMonochrome) expect(g.saturation, lessThanOrEqualTo(0.1), reason: '$era');
      expect(g.process, era == Era.vhs ? FilmProcess.vhs : FilmProcess.film, reason: '$era');
    }
    expect(EraSkins.of(Era.silent).grade.projectionFps, 18);
  });

  test('music style per era', () {
    expect(EraSkins.of(Era.silent).score.style, MusicStyle.ragtime);
    expect(EraSkins.of(Era.rubberHose).score.style, MusicStyle.swing);
    expect(EraSkins.of(Era.vhs).score.style, MusicStyle.synthwave);
  });

  test('FilmGrade.scaled scales only damage effects', () {
    const g = FilmGrade(grain: 0.5, flicker: 0.8, dust: 0.6, scratches: 0.4, gateWeave: 2, vignette: 0.5, contrast: 1.2);
    final h = g.scaled(0.5);
    expect(h.grain, 0.25);
    expect(h.flicker, 0.4);
    expect(h.dust, 0.3);
    expect(h.scratches, 0.2);
    expect(h.gateWeave, 1);
    expect(h.vignette, 0.5);
    expect(h.contrast, 1.2);
    expect(g.scaled(3).grain, 0.5, reason: 'clamped to 1');
  });

  test('era labels are localised in Arabic and English', () {
    final ar = lookupL10n(const Locale('ar'));
    final en = lookupL10n(const Locale('en'));
    final arLabels = {for (final e in Era.values) e.label(ar)};
    expect(arLabels, hasLength(Era.values.length));
    expect(Era.rubberHose.label(en), '1930s Cartoon');
  });
}
