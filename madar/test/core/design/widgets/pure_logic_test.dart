import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/widgets/widgets.dart';

void main() {
  group('CosmosUniforms', () {
    test('packs 31 floats in shader order', () {
      final t = MadarPalettes.tokensFor(MadarThemeId.lapis);
      final u = CosmosUniforms.pack(size: const Size(412, 915), time: 10, tokens: t, intensity: 0.8, seed: 3);
      expect(u, hasLength(CosmosUniforms.length));
      expect(u.sublist(0, 3), [412, 915, 10]);
      expect(u[3], closeTo(t.space0.r, 1e-9)); // uSpace0.r
      expect(u[19], closeTo(t.starTint.r, 1e-9)); // uStar.r
      expect(u[27], 0.8); // intensity
      expect(u[28], 0); // dark theme
      expect(u[30], 3); // seed
    });

    test('wraps time into the loop period and flags the light theme', () {
      final pearl = MadarPalettes.tokensFor(MadarThemeId.pearl);
      final u = CosmosUniforms.pack(size: const Size(10, 10), time: CosmosUniforms.period + 5, tokens: pearl);
      expect(u[2], closeTo(5, 1e-9));
      expect(u[28], 1);
    });

    test('clamps intensity', () {
      final t = MadarPalettes.tokensFor(MadarThemeId.aurora);
      expect(CosmosUniforms.pack(size: const Size(1, 1), time: 0, tokens: t, intensity: 9)[27], 2);
      expect(CosmosUniforms.pack(size: const Size(1, 1), time: 0, tokens: t, intensity: -1)[27], 0);
    });
  });

  group('GlassUniforms', () {
    test('packs 12 floats; RTL mirrors', () {
      List<double> pack(TextDirection d) => GlassUniforms.pack(
        size: const Size(200, 100),
        time: GlassUniforms.period + 1,
        highlight: const Color(0x66FFF3D1),
        grain: 0.05,
        light: false,
        seed: 2,
        specular: 3,
        direction: d,
      );
      final ltr = pack(TextDirection.ltr);
      expect(ltr, hasLength(GlassUniforms.length));
      expect(ltr[2], closeTo(1, 1e-9));
      expect(ltr[6], closeTo(0x66 / 255, 1e-9));
      expect(ltr[10], 1, reason: 'specular clamped');
      expect(ltr[11], 1);
      expect(pack(TextDirection.rtl)[11], -1);
    });
  });

  group('ChoiceSelection', () {
    test('single select', () {
      expect(ChoiceSelection.toggleSingle<int>(null, 2), 2);
      expect(ChoiceSelection.toggleSingle<int>(1, 2), 2);
      expect(ChoiceSelection.toggleSingle<int>(2, 2), 2);
      expect(ChoiceSelection.toggleSingle<int>(2, 2, allowDeselect: true), isNull);
    });

    test('multi select adds and removes', () {
      expect(ChoiceSelection.toggleMulti({1}, 2), {1, 2});
      expect(ChoiceSelection.toggleMulti({1, 2}, 2), {1});
    });

    test('multi select respects min / max by returning the same set', () {
      final one = {1};
      expect(identical(ChoiceSelection.toggleMulti(one, 1, minSelected: 1), one), isTrue);
      final two = {1, 2};
      expect(identical(ChoiceSelection.toggleMulti(two, 3, maxSelected: 2), two), isTrue);
      expect(ChoiceSelection.toggleMulti(two, 1, maxSelected: 2), {2});
    });

    test('never mutates the input', () {
      final s = {1};
      ChoiceSelection.toggleMulti(s, 2);
      expect(s, {1});
    });
  });

  group('ProgressRingGeometry', () {
    test('normalises', () {
      expect(ProgressRingGeometry.normalize(-1), 0);
      expect(ProgressRingGeometry.normalize(2), 1);
      expect(ProgressRingGeometry.normalize(double.nan), 0);
      expect(ProgressRingGeometry.normalize(0.4), 0.4);
    });

    test('sweep and head angle', () {
      expect(ProgressRingGeometry.sweep(0.5), closeTo(math.pi, 1e-12));
      expect(ProgressRingGeometry.headAngle(0), closeTo(-math.pi / 2, 1e-12));
      expect(ProgressRingGeometry.headAngle(0.25), closeTo(0, 1e-12));
      expect(ProgressRingGeometry.headAngle(0.25, clockwise: false), closeTo(-math.pi, 1e-12));
    });
  });

  group('MadarButtonStyle', () {
    test('every variant resolves in every theme', () {
      for (final id in MadarThemeId.values) {
        final t = MadarPalettes.tokensFor(id);
        for (final v in MadarButtonVariant.values) {
          final s = MadarButtonStyle.of(t, v);
          expect(s.foreground.a, greaterThan(0));
          final d = MadarButtonStyle.disabled(t, v);
          expect(d.glow, isNull);
          expect(d.foreground, t.textTertiary);
        }
        expect(MadarButtonStyle.of(t, MadarButtonVariant.primary).gradient, hasLength(3));
        expect(MadarButtonStyle.of(t, MadarButtonVariant.primary).foreground, t.textOnAccent);
      }
    });
  });

  group('GlassFillStyle', () {
    test('card fill is denser than panel fill (no blur behind it)', () {
      for (final id in MadarThemeId.values) {
        final t = MadarPalettes.tokensFor(id);
        expect(GlassFillStyle.card(t).base.a, greaterThan(GlassFillStyle.panel(t).base.a));
        expect(GlassFillStyle.panel(t).light, !t.isDark);
      }
    });
  });
}
