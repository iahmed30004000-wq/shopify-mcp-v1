import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../data/quran_providers.dart';
import '../../domain/tajweed.dart';
import '../quran_labels.dart';
import '../tajweed_palette.dart';

/// How one ayah is drawn inside a paragraph.
class AyahPaint {
  const AyahPaint({
    this.tajweed = true,
    this.highlight,
    this.matches = const [],
    this.markerColor,
    this.recognizer,
    this.semanticsLabel,
  });

  /// Colour the tajweed rules.
  final bool tajweed;

  /// A background wash over the whole ayah (recited / selected / found).
  final Color? highlight;

  /// Code-unit ranges of the ayah text to mark (search hits).
  final List<(int, int)> matches;

  /// Colour of the end-of-ayah sign (the bookmark colour when bookmarked).
  final Color? markerColor;
  final GestureRecognizer? recognizer;
  final String? semanticsLabel;
}

/// Display-only spacing of the Tanzil text (the text itself is never
/// changed – same length, so tajweed offsets still apply): the space Tanzil
/// puts before a pause mark or the sajdah sign, and after the rub-el-hizb
/// sign, becomes a no-break space, so a sign never wraps away from its word
/// and justification never pulls it apart.
abstract final class QuranDisplay {
  static final RegExp _beforeSign = RegExp(' (?=[\u06D6-\u06DC\u06E9])');

  static String glue(String text) {
    var t = text.replaceAll(_beforeSign, '\u00A0');
    if (t.startsWith('\u06DE ')) t = '\u06DE\u00A0${t.substring(2)}';
    return t;
  }
}

/// Builds the spans of Quran text: every span shares one font, size and
/// height (only paint changes – colour and background), so the paragraph is
/// shaped as one run and Arabic letters keep joining across tajweed colours.
abstract final class AyahSpans {
  /// The ayah's text as coloured runs, then « ۝N ».
  static List<InlineSpan> ayah(
    AyahContent content,
    TextStyle base,
    MadarTokens t, {
    AyahPaint paint = const AyahPaint(),
    bool withMarker = true,
  }) {
    final spans = <InlineSpan>[];
    final text = QuranDisplay.glue(content.text);
    final palette = paint.tajweed ? TajweedPalette.of(t) : null;
    final runs = paint.tajweed ? Tajweed.runs(text.length, content.marks) : [TajweedRun(0, text.length, null)];
    final background = paint.highlight == null ? null : (Paint()..color = paint.highlight!);
    final matchPaint = Paint()..color = t.accent.withValues(alpha: t.isDark ? 0.30 : 0.22);
    // Cut the runs further at the search-hit boundaries.
    final cuts = <int>{0, text.length};
    for (final r in runs) {
      cuts
        ..add(r.start)
        ..add(r.end);
    }
    for (final (s, e) in paint.matches) {
      cuts
        ..add(s.clamp(0, text.length))
        ..add(e.clamp(0, text.length));
    }
    final points = cuts.toList()..sort();
    var runIndex = 0;
    for (var i = 0; i + 1 < points.length; i++) {
      final s = points[i];
      final e = points[i + 1];
      if (s == e) continue;
      while (runIndex < runs.length && runs[runIndex].end <= s) {
        runIndex++;
      }
      final rule = runIndex < runs.length ? runs[runIndex].rule : null;
      final matched = paint.matches.any((m) => m.$1 <= s && e <= m.$2);
      spans.add(
        TextSpan(
          text: text.substring(s, e),
          style: base.copyWith(
            color: rule != null && palette != null ? palette[rule] : null,
            background: matched ? matchPaint : background,
          ),
          recognizer: paint.recognizer,
        ),
      );
    }
    if (withMarker) {
      spans.add(
        TextSpan(
          text: ' ${quranAyahMark(content.ref.ayah)} ',
          style: base.copyWith(color: paint.markerColor ?? t.gold, background: background),
          recognizer: paint.recognizer,
        ),
      );
    }
    if (paint.semanticsLabel != null) {
      return [TextSpan(children: spans, semanticsLabel: paint.semanticsLabel)];
    }
    return spans;
  }

  /// A standalone text (the basmala) with its tajweed.
  static List<InlineSpan> plain(String text, List<TajweedMark> marks, TextStyle base, MadarTokens t, {bool tajweed = true}) {
    final shown = QuranDisplay.glue(text);
    if (!tajweed || marks.isEmpty) return [TextSpan(text: shown, style: base)];
    final palette = TajweedPalette.of(t);
    return [
      for (final r in Tajweed.runs(shown.length, marks))
        TextSpan(
          text: shown.substring(r.start, r.end),
          style: r.rule == null ? base : base.copyWith(color: palette[r.rule!]),
        ),
    ];
  }
}
