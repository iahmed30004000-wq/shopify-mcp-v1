import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/contrast.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/quran/domain/tajweed.dart';
import 'package:madar/features/quran/presentation/tajweed_palette.dart';
import 'package:madar/features/quran/presentation/widgets/ayah_spans.dart';

/// Rough perceptual distance (redmean).
double _distance(Color a, Color b) {
  final r = (a.r + b.r) * 127.5;
  final dr = (a.r - b.r) * 255, dg = (a.g - b.g) * 255, db = (a.b - b.b) * 255;
  return math.sqrt((2 + r / 256) * dr * dr + 4 * dg * dg + (2 + (255 - r) / 256) * db * db);
}

void main() {
  group('tajweed palette', () {
    for (final id in MadarThemeId.values) {
      test('${id.name}: every rule reads on the reading surfaces', () {
        final t = MadarPalettes.tokensFor(id);
        final palette = TajweedPalette.of(t);
        for (final rule in TajweedRule.values) {
          final c = palette[rule];
          expect(
            MadarContrast.minRatio(c, TajweedPalette.surfaces(t)),
            greaterThanOrEqualTo(MadarContrast.text),
            reason: '${id.name} ${rule.name}',
          );
          expect(MadarContrast.minRatio(c, [t.glassLit]), greaterThanOrEqualTo(MadarContrast.graphic));
        }
      });

      test('${id.name}: the families and the madd lengths stay apart', () {
        final t = MadarPalettes.tokensFor(id);
        final p = TajweedPalette.of(t);
        // One representative per family is clearly different from the others.
        final reps = [TajweedRule.silent, TajweedRule.maddConnected, TajweedRule.ghunnah, TajweedRule.qalqalah];
        for (var i = 0; i < reps.length; i++) {
          for (var j = i + 1; j < reps.length; j++) {
            expect(_distance(p[reps[i]], p[reps[j]]), greaterThan(90), reason: '${id.name} ${reps[i]} vs ${reps[j]}');
          }
        }
        // The natural madd (2) and the necessary madd (6) are told apart.
        expect(_distance(p[TajweedRule.maddNatural], p[TajweedRule.maddNecessary]), greaterThan(60), reason: id.name);
        // And no rule is drawn in the plain text colour.
        for (final rule in TajweedRule.values) {
          expect(_distance(p[rule], t.textPrimary), greaterThan(40), reason: '${id.name} ${rule.name}');
        }
      });
    }
  });

  group('display glue', () {
    test('signs stay with their word; the length never changes', () {
      const s = 'رَيْبَ ۛ فِيهِ ۛ هُدًى';
      final g = QuranDisplay.glue(s);
      expect(g.length, s.length);
      expect(g, 'رَيْبَ ۛ فِيهِ ۛ هُدًى');
      expect(QuranDisplay.glue('۞ إِنَّ'), '۞ إِنَّ');
      expect(QuranDisplay.glue('يَسْجُدُونَ ۩'), 'يَسْجُدُونَ ۩');
      expect(QuranDisplay.glue('قُلْ هُوَ'), 'قُلْ هُوَ');
    });
  });
}
