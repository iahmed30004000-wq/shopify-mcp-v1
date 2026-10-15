import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';

import 'design_test_utils.dart';

double _contrast(double a, double b) => (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);

/// Relative luminance of an sRGB grey with encoded value [v].
double _greyLuminance(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

void main() {
  group('theme equality (no needless theme animations)', () {
    test('identical inputs build equal themes, with or without a custom accent', () {
      for (final id in MadarThemeId.values) {
        expect(buildMadarTheme(id, arabic: true), buildMadarTheme(id, arabic: true));
        final a = buildMadarTheme(id, customAccent: const Color(0xFF00AA88), arabic: false);
        final b = buildMadarTheme(id, customAccent: const Color(0xFF00AA88), arabic: false);
        expect(a, b, reason: id.name);
        expect(a.hashCode, b.hashCode);
        expect(a.extension<MadarTokens>(), b.extension<MadarTokens>());
      }
      expect(
        buildMadarTheme(MadarThemeId.lapis, customAccent: const Color(0xFF00AA88), arabic: true),
        isNot(buildMadarTheme(MadarThemeId.lapis, customAccent: const Color(0xFF0088AA), arabic: true)),
      );
    });

    test('tokens differing in any field are unequal', () {
      final t = MadarPalettes.tokensFor(MadarThemeId.aurora);
      expect(t.copyWith(accent: t.accent), t);
      expect(t.copyWith(accent: const Color(0xFF123456)), isNot(t));
      expect(t.lerp(MadarPalettes.tokensFor(MadarThemeId.desert), 0.5), isNot(t));
    });
  });

  group('typography pinned to the language (no reflow after a switch)', () {
    test('withMadarTypography swaps the script metrics and keeps the colours', () {
      for (final id in MadarThemeId.values) {
        final arabic = buildMadarTheme(id, arabic: true);
        final latin = withMadarTypography(arabic, arabic: false);
        expect(latin.textTheme, buildMadarTheme(id, arabic: false).textTheme);
        expect(latin.textTheme.bodyMedium!.height, 1.3);
        expect(latin.textTheme.bodyMedium!.color, arabic.textTheme.bodyMedium!.color);
        expect(latin.appBarTheme.titleTextStyle, latin.textTheme.titleLarge);
        expect(latin.inputDecorationTheme.hintStyle!.height, 1.3);
        expect(latin.extension<MadarTokens>(), arabic.extension<MadarTokens>());
        // Nothing to pin: the very same theme comes back.
        expect(identical(withMadarTypography(arabic, arabic: true), arabic), isTrue);
      }
    });

    test('mid-cross-fade, the metrics follow the language while the colours follow the fade', () {
      final from = buildMadarTheme(MadarThemeId.lapis, arabic: true);
      final to = buildMadarTheme(MadarThemeId.pearl, arabic: false);
      final mid = ThemeData.lerp(from, to, 0.3);
      final pinned = withMadarTypography(mid, arabic: false);
      final tokens = mid.extension<MadarTokens>()!;
      expect(pinned.textTheme.bodyMedium!.height, 1.3);
      expect(pinned.textTheme.bodyMedium!.color, tokens.textPrimary);
    });
  });

  test('tooltips never vibrate on their own (haptics go through Fx)', () {
    expect(buildMadarTheme(MadarThemeId.lapis, arabic: true).tooltipTheme.enableFeedback, isFalse);
  });

  test('Latin display headings get a real word gap; Arabic keeps the font spacing', () {
    final en = buildMadarTheme(MadarThemeId.lapis, arabic: false).textTheme;
    final ar = buildMadarTheme(MadarThemeId.lapis, arabic: true).textTheme;
    expect(en.headlineSmall!.wordSpacing, closeTo(20 * 0.12, 1e-9));
    expect(en.displayLarge!.wordSpacing, greaterThan(0));
    expect(ar.headlineSmall!.wordSpacing, isNull);
  });

  group('text on the bare backdrop stays readable', () {
    test('secondary text keeps >= 4.5:1 over the capped (luma 0.24) sky in every dark theme', () {
      final sky = _greyLuminance(0.24);
      for (final id in MadarThemeId.values) {
        final t = MadarPalettes.tokensFor(id);
        if (!t.isDark) continue;
        expect(_contrast(t.textSecondary.computeLuminance(), sky), greaterThanOrEqualTo(4.5), reason: id.name);
      }
    });

    test("Aurora's first nebula is darkened", () {
      expect(MadarPalettes.tokensFor(MadarThemeId.aurora).nebulaA, const Color(0xFF137A63));
    });

    testWidgets('section subtitles use secondary text', (tester) async {
      await pumpMadar(tester, const SectionHeader(title: 'Title', subtitle: 'Subtitle'), theme: MadarThemeId.aurora);
      final t = MadarPalettes.tokensFor(MadarThemeId.aurora);
      expect(tester.widget<Text>(find.text('Subtitle')).style!.color, t.textSecondary);
    });
  });
}
