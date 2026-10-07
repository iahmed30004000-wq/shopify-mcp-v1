// Text drawn on a tracker's own colour (the module screen's "Done for
// today" banner, the selected range pill, the streak badge, a ticked box)
// is whichever of white and the near-black ink reads better on it: the
// orbit palette's mid-tone colours need the dark ink to reach WCAG AA.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/contrast.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/features/custom_modules/custom_modules.dart' show ModuleTemplates;
import 'package:madar/features/custom_modules/presentation/widgets/module_visuals.dart' show ModuleColors;

void main() {
  for (final theme in [MadarThemeId.lapis, MadarThemeId.pearl]) {
    test('${theme.name}: a tracker colour carries the more legible of white / dark text', () {
      final tokens = buildMadarTheme(theme, arabic: true).extension<MadarTokens>()!;
      final worse = <String, String>{};
      for (final MapEntry(key: planet, value: argb) in ModuleTemplates.planetColors.entries) {
        final c = ModuleColors.of(argb, tokens);
        final picked = MadarContrast.ratio(c.onBase, c.base);
        final white = MadarContrast.ratio(Colors.white, c.base);
        final dark = MadarContrast.ratio(const Color(0xFF14110C), c.base);
        final best = white > dark ? white : dark;
        if (picked + 0.01 < best || picked < MadarContrast.text) {
          worse[planet] =
              '${picked.toStringAsFixed(2)}:1 picked, ${best.toStringAsFixed(2)}:1 available '
              '(#${(argb & 0xFFFFFF).toRadixString(16).toUpperCase()})';
        }
        // The done banner: base → sheen, its hint line at 86 % opacity.
        for (final fill in [c.base, c.sheen]) {
          final hint = MadarContrast.over(c.onSheen.withValues(alpha: 0.86), fill);
          if (MadarContrast.ratio(c.onSheen, fill) < MadarContrast.text || MadarContrast.ratio(hint, fill) < 4.5) {
            worse['$planet banner'] = '${MadarContrast.ratio(hint, fill).toStringAsFixed(2)}:1 on the banner';
          }
        }
      }
      expect(worse, isEmpty, reason: 'text on a filled tracker colour (ModuleColors.onBase / onSheen)');
    });
  }

  test('any colour the user picks gets at least ~4.4:1', () {
    final tokens = buildMadarTheme(MadarThemeId.lapis, arabic: true).extension<MadarTokens>()!;
    for (var argb = 0xFF000000; argb <= 0xFFFFFFFF; argb += 0x00070B0D) {
      final c = ModuleColors(Color(argb), tokens);
      expect(MadarContrast.ratio(c.onBase, c.base), greaterThan(4.3), reason: '#${argb.toRadixString(16)}');
    }
  });
}
