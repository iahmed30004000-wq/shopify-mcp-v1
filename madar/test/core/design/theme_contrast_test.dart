// WCAG AA legibility of every theme, and of any custom accent colour.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/contrast.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';

/// Every token a screen may use as a text / icon colour.
Map<String, Color> _textTokens(MadarTokens t) => {
  'textPrimary': t.textPrimary,
  'textSecondary': t.textSecondary,
  'textTertiary': t.textTertiary,
  'accent': t.accent,
  'gold': t.gold,
  'brass': t.brass,
  'success': t.success,
  'warning': t.warning,
  'danger': t.danger,
  'info': t.info,
  'highlight': t.highlight,
};

/// Colours a user might pick: every planet colour (the accent swatches),
/// the extremes and a few awkward mid tones.
/// The colour of a three-stop vertical gradient at [at] (0 top … 1 bottom).
Color _gradientAt(List<Color> g, double at) =>
    at <= 0.5 ? Color.lerp(g[0], g[1], at * 2)! : Color.lerp(g[1], g[2], at * 2 - 1)!;

final List<Color> _accents = [
  for (final p in PlanetPalettes.byKey.values) ...[p.surface, p.glow, p.deep],
  const Color(0xFFFFFFFF),
  const Color(0xFF000000),
  const Color(0xFF808080),
  const Color(0xFFFFFF00),
  const Color(0xFF0000FF),
  const Color(0xFFFF0000),
  const Color(0xFF00FF00),
  const Color(0xFF00AA88),
  const Color(0xFF3D5BD9),
  const Color(0xFFE8C77A),
  // The hue rail's colours, every 15°.
  for (var h = 0; h < 360; h += 15) HSLColor.fromAHSL(1, h.toDouble(), 0.72, 0.6).toColor(),
  // Saturated mid tones that land right on the threshold.
  for (var h = 0; h < 360; h += 30) HSLColor.fromAHSL(1, h.toDouble(), 1, 0.5).toColor(),
];

double _hue(Color c) => HSLColor.fromColor(c).hue;

double _hueDistance(double a, double b) {
  final d = (a - b).abs() % 360;
  return math.min(d, 360 - d);
}

void main() {
  group('MadarContrast maths', () {
    test('luminance and ratio match WCAG reference values', () {
      expect(MadarContrast.luminance(const Color(0xFF000000)), 0);
      expect(MadarContrast.luminance(const Color(0xFFFFFFFF)), closeTo(1, 1e-9));
      expect(MadarContrast.ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 1e-9));
      expect(MadarContrast.ratio(const Color(0xFFFFFFFF), const Color(0xFF000000)), closeTo(21, 1e-9));
      // #767676 on white is the classic 4.54:1.
      expect(MadarContrast.ratio(const Color(0xFF767676), const Color(0xFFFFFFFF)), closeTo(4.54, 0.01));
      // Agrees with Flutter's own implementation.
      for (final c in _accents) {
        expect(MadarContrast.luminance(c), closeTo(c.computeLuminance(), 1e-6));
      }
    });

    test('over() composites a translucent colour onto an opaque one', () {
      final c = MadarContrast.over(const Color(0x80FFFFFF), const Color(0xFF000000));
      expect(c.a, 1);
      expect(c.r, closeTo(0.5, 0.01));
    });

    test('ensure() leaves a passing colour untouched', () {
      const gold = Color(0xFFE8C77A);
      expect(MadarContrast.ensure(gold, const [Color(0xFF03050F)]), same(gold));
    });

    test('ensure() lightens on dark and darkens on light backgrounds, keeping the hue', () {
      const navy = Color(0xFF1A237E);
      final lifted = MadarContrast.ensure(navy, const [Color(0xFF03050F)]);
      expect(MadarContrast.ratio(lifted, const Color(0xFF03050F)), greaterThanOrEqualTo(4.5));
      expect(lifted.computeLuminance(), greaterThan(navy.computeLuminance()));
      expect(_hueDistance(_hue(lifted), _hue(navy)), lessThan(3));

      const mint = Color(0xFF7FE3C4);
      final deepened = MadarContrast.ensure(mint, const [Color(0xFFF7F3EA)]);
      expect(MadarContrast.ratio(deepened, const Color(0xFFF7F3EA)), greaterThanOrEqualTo(4.5));
      expect(deepened.computeLuminance(), lessThan(mint.computeLuminance()));
      expect(_hueDistance(_hue(deepened), _hue(mint)), lessThan(3));
    });

    test('ensure() moves as little as needed (just past the threshold)', () {
      const grey = Color(0xFF999999);
      final c = MadarContrast.ensure(grey, const [Color(0xFFFFFFFF)]);
      final r = MadarContrast.ratio(c, const Color(0xFFFFFFFF));
      expect(r, inInclusiveRange(4.5, 4.7));
    });

    test('ensure() returns plain 8-bit colours', () {
      final c = MadarContrast.ensure(const Color(0xFF7FE3C4), const [Color(0xFFF7F3EA)]);
      expect(Color(c.toARGB32()), c);
    });

    test('ensure() falls back to the extreme when nothing passes', () {
      // Nothing reaches 25:1 – the best effort on a dark ground is white,
      // on a light one black.
      expect(
        MadarContrast.ensure(const Color(0xFFFF0000), const [Color(0xFF202020)], min: 25),
        const Color(0xFFFFFFFF),
      );
      expect(
        MadarContrast.ensure(const Color(0xFFFF0000), const [Color(0xFFE0E0E0)], min: 25),
        const Color(0xFF000000),
      );
    });

    test('bestOn() picks the more readable candidate', () {
      const light = Color(0xFFFFFBF1);
      const dark = Color(0xFF14110A);
      expect(MadarContrast.bestOn(const Color(0xFF203080), const [light, dark]), light);
      expect(MadarContrast.bestOn(const Color(0xFFF0E080), const [light, dark]), dark);
    });
  });

  group('the five themes', () {
    for (final id in MadarThemeId.values) {
      final t = MadarPalettes.tokensFor(id);

      test('${id.name}: every text colour reaches 4.5:1 on every surface', () {
        final surfaces = MadarPalettes.textSurfaces(t);
        for (final e in _textTokens(t).entries) {
          final worst = MadarContrast.minRatio(e.value, surfaces);
          // Brass draws rings and rules (3 : 1), never text.
          final min = e.key == 'brass' ? MadarContrast.graphic : MadarContrast.text;
          expect(worst, greaterThanOrEqualTo(min), reason: '${id.name}.${e.key}: $worst');
        }
      });

      test('${id.name}: every text colour stays AA on raised surfaces too', () {
        // Pearl's space3 is a border / pressed tone, never a text ground.
        final raised = [t.space2, if (t.isDark) t.space3];
        for (final e in _textTokens(t).entries) {
          if (e.key == 'brass') continue; // a metal for graphics – see below
          expect(
            MadarContrast.minRatio(e.value, raised),
            greaterThanOrEqualTo(MadarContrast.text),
            reason: '${id.name}.${e.key}',
          );
        }
      });

      final lit = t.glassLit;
      if (t.isDark) {
        test('${id.name}: every text colour reads on the brightest glass measured on screen', () {
          // glassLit is measured by rendered_contrast_screenshot_test.dart:
          // glass lit by the nebula is far brighter than the token surfaces.
          expect(MadarContrast.luminance(lit), greaterThan(MadarContrast.luminance(t.space3)));
          for (final e in _textTokens(t).entries) {
            // Brass draws rings and rules (3 : 1), never text.
            final min = e.key == 'brass' ? MadarContrast.graphic : MadarContrast.text;
            expect(MadarContrast.ratio(e.value, lit), greaterThanOrEqualTo(min), reason: '${id.name}.${e.key} on $lit');
          }
        });
      }

      test('${id.name}: the text hierarchy is ordered (primary > secondary > tertiary)', () {
        final bg = t.space0;
        final p = MadarContrast.ratio(t.textPrimary, bg);
        final s = MadarContrast.ratio(t.textSecondary, bg);
        final q = MadarContrast.ratio(t.textTertiary, bg);
        expect(p, greaterThan(s));
        expect(s, greaterThan(q + 1));
      });

      test('${id.name}: its own accent has the headroom custom accents are fitted to', () {
        expect(
          MadarContrast.minRatio(t.accent, MadarPalettes.textSurfaces(t)),
          greaterThanOrEqualTo(MadarPalettes.accentHeadroom),
        );
      });

      test('${id.name}: labels on the accent (buttons, badges) reach 4.5:1', () {
        expect(MadarContrast.ratio(t.textOnAccent, t.accent), greaterThanOrEqualTo(MadarContrast.text));
        final button = MadarButtonStyle.of(t, MadarButtonVariant.primary);
        final g = button.gradient!;
        // The label spans the middle half of the button's vertical gradient.
        for (final at in [0.25, 0.5, 0.75]) {
          final behind = at <= 0.5 ? Color.lerp(g[0], g[1], at * 2)! : Color.lerp(g[1], g[2], at * 2 - 1)!;
          expect(
            MadarContrast.ratio(button.foreground, behind),
            greaterThanOrEqualTo(MadarContrast.text),
            reason: '${id.name} at $at',
          );
        }
      });
    }
  });

  group('custom accent colour', () {
    for (final id in MadarThemeId.values) {
      test('${id.name}: any accent is adjusted until it reads on every surface', () {
        final base = MadarPalettes.tokensFor(id);
        final surfaces = MadarPalettes.textSurfaces(base);
        for (final pick in _accents) {
          final t = MadarPalettes.withAccent(base, pick);
          expect(
            MadarContrast.minRatio(t.accent, surfaces),
            greaterThanOrEqualTo(MadarPalettes.accentHeadroom),
            reason: '${id.name} $pick',
          );
          expect(MadarContrast.ratio(t.textOnAccent, t.accent), greaterThanOrEqualTo(4.5), reason: '${id.name} $pick');
          expect(t.accent.a, 1);
          expect(t.accentSoft, t.accent.withValues(alpha: 0.2));
          expect(t.accentGlow, t.accent.withValues(alpha: 0.6));
          // Chromatic picks keep their hue (only the lightness moves).
          final hsl = HSLColor.fromColor(pick);
          if (hsl.saturation > 0.2 && hsl.lightness > 0.05 && hsl.lightness < 0.95) {
            expect(_hueDistance(_hue(t.accent), hsl.hue), lessThan(6), reason: '${id.name} $pick → ${t.accent}');
          }
          // The primary button's label reads across its whole sheen (the
          // accent itself only just passes, so the darker / lighter ends
          // must not undo that).
          final button = MadarButtonStyle.of(t, MadarButtonVariant.primary);
          for (final at in [0.0, 0.25, 0.5, 0.75, 1.0]) {
            expect(
              MadarContrast.ratio(button.foreground, _gradientAt(button.gradient!, at)),
              greaterThanOrEqualTo(MadarContrast.text),
              reason: '${id.name} $pick button at $at',
            );
          }
          // Everything else is the theme's own.
          expect(t.textPrimary, base.textPrimary);
          expect(t.gold, base.gold);
          expect(t.space0, base.space0);
        }
      });
    }

    test('a colour that already reads is used exactly as picked', () {
      final t = MadarPalettes.withAccent(MadarPalettes.tokensFor(MadarThemeId.lapis), PlanetPalettes.money.surface);
      expect(t.accent, PlanetPalettes.money.surface);
    });

    test('a pale accent turns deep on Pearl but stays pale on the night themes', () {
      const mint = Color(0xFF7FE3C4);
      final pearl = MadarPalettes.resolve(MadarThemeId.pearl, accent: mint);
      final lapis = MadarPalettes.resolve(MadarThemeId.lapis, accent: mint);
      expect(pearl.accent.computeLuminance(), lessThan(0.2));
      expect(lapis.accent, mint);
      expect(pearl.textOnAccent.computeLuminance(), greaterThan(0.8));
      expect(lapis.textOnAccent.computeLuminance(), lessThan(0.05));
    });

    test('buildMadarTheme installs the resolved tokens', () {
      const pick = Color(0xFF9C8CFF);
      for (final id in MadarThemeId.values) {
        final theme = buildMadarTheme(id, customAccent: pick, arabic: true);
        expect(theme.extension<MadarTokens>(), MadarPalettes.resolve(id, accent: pick));
        expect(theme.colorScheme.primary, MadarPalettes.resolve(id, accent: pick).accent);
      }
      expect(
        buildMadarTheme(MadarThemeId.aurora, arabic: false).extension<MadarTokens>(),
        MadarPalettes.tokensFor(MadarThemeId.aurora),
      );
    });
  });
}
