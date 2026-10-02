import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/painters/painters.dart';
import 'package:madar/core/design/themes.dart';

/// Paints [painter] at several sizes (including degenerate ones) into a
/// real picture – every painter must be total and crash-free.
void paintAll(CustomPainter painter) {
  for (final size in const [Size.zero, Size(1, 1), Size(24, 24), Size(160, 90), Size(412, 64)]) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), size);
    recorder.endRecording().dispose();
  }
}

void main() {
  final t = MadarPalettes.tokensFor(MadarThemeId.lapis);
  const phase = AlwaysStoppedAnimation<double>(0.37);
  final colors = EmptyIllustrationColors(
    gold: t.gold,
    brass: t.brass,
    brassDark: t.brassDark,
    glow: t.accentGlow,
    star: t.starTint,
    line: t.glassBorder,
    glass: t.glassFill,
    accent: t.accent,
  );

  test('Islamic star painter (both styles, all options)', () {
    for (final style in IslamicStarStyle.values) {
      for (final points in [5, 8, 12]) {
        paintAll(
          IslamicStarPainter(
            style: style,
            points: points,
            fillColor: t.gold,
            fillGradient: [t.gold, t.brass],
            strokeColor: t.brass,
            glowColor: t.accentGlow,
            centerDotColor: t.gold,
          ),
        );
      }
    }
  });

  test('girih rosette painter', () {
    for (final folds in [6, 8, 10, 12]) {
      paintAll(
        GirihRosettePainter(
          folds: folds,
          strandColor: t.gold,
          strandInnerColor: t.brassDark,
          ringColor: t.brass,
          fillColor: t.accentSoft,
          centerColor: t.gold,
        ),
      );
    }
  });

  test('arabesque border painter in both directions, scrolled', () {
    for (final dir in TextDirection.values) {
      for (final p in [0.0, 0.3, 1.7]) {
        paintAll(ArabesqueBorderPainter(color: t.brass, leafColor: t.gold, textDirection: dir, phase: p));
      }
    }
    paintAll(ArabesqueBorderPainter(color: t.brass, rails: false));
  });

  test('astrolabe ticks painter with and without numerals', () {
    paintAll(AstrolabeTicksPainter(color: t.brass, majorColor: t.gold));
    paintAll(AstrolabeTicksPainter(color: t.brass, arabicIndic: false, rotation: 1));
    paintAll(AstrolabeTicksPainter(color: t.brass, showNumerals: false, innerRing: false));
  });

  test('empty-state illustrations', () {
    for (final dir in TextDirection.values) {
      paintAll(CrescentStarsPainter(phase: phase, colors: colors, textDirection: dir));
      paintAll(AstrolabeNeedlePainter(phase: phase, colors: colors, textDirection: dir));
      paintAll(TelescopeScanPainter(phase: phase, colors: colors, textDirection: dir));
    }
  });

  test('shouldRepaint reacts to real changes only', () {
    final a = IslamicStarPainter(strokeColor: t.gold);
    expect(a.shouldRepaint(IslamicStarPainter(strokeColor: t.gold)), isFalse);
    expect(a.shouldRepaint(IslamicStarPainter(strokeColor: t.brass)), isTrue);
    final r = GirihRosettePainter(strandColor: t.gold);
    expect(r.shouldRepaint(GirihRosettePainter(strandColor: t.gold)), isFalse);
    expect(r.shouldRepaint(GirihRosettePainter(strandColor: t.gold, folds: 10)), isTrue);
    final b = ArabesqueBorderPainter(color: t.brass);
    expect(b.shouldRepaint(ArabesqueBorderPainter(color: t.brass, textDirection: TextDirection.ltr)), isTrue);
    final c = CrescentStarsPainter(phase: phase, colors: colors);
    expect(c.shouldRepaint(CrescentStarsPainter(phase: phase, colors: colors)), isFalse);
  });
}
