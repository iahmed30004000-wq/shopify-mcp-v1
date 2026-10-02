import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/i18n/formatters.dart';
import '../../domain/adhkar_models.dart';

/// Base size of the dhikr text at scale 1 (logical px).
const double kDhikrBaseFontSize = 25;

/// The fully vowelled Arabic of a dhikr in Amiri, right-to-left in both app
/// languages. Quran verses sit between ornate brackets ﴿ ﴾ with an
/// end-of-ayah mark and number after each verse; the basmala or isti'adha
/// before them stands on its own line.
class DhikrText extends StatelessWidget {
  const DhikrText({
    super.key,
    required this.dhikr,
    this.scale = 1,
    this.color,
    this.maxLines,
    this.textAlign = TextAlign.center,
  });

  final Dhikr dhikr;
  final double scale;
  final Color? color;
  final int? maxLines;
  final TextAlign textAlign;

  /// «۝٢٥٥» – Amiri draws the digits inside the ayah ornament.
  static String ayahMark(int ayah) => '۝${Digits.toArabicIndic('$ayah')}';

  static const String openBracket = '﴿'; // ﴿
  static const String closeBracket = '﴾'; // ﴾

  /// The spans of [dhikr] (exposed for the preview in the options sheet).
  static List<InlineSpan> spans(Dhikr dhikr, {required Color bracket, required Color verse}) {
    final out = <InlineSpan>[];
    for (var i = 0; i < dhikr.segments.length; i++) {
      if (i > 0) out.add(const TextSpan(text: '\n'));
      switch (dhikr.segments[i]) {
        case DhikrTextSegment(:final text):
          out.add(TextSpan(text: text));
        case final DhikrQuranSegment q:
          out.add(
            TextSpan(
              text: '$openBracket ',
              style: TextStyle(color: bracket),
            ),
          );
          for (var v = 0; v < q.verses.length; v++) {
            out.add(
              TextSpan(
                text: q.verses[v],
                style: TextStyle(color: verse),
              ),
            );
            out.add(
              TextSpan(
                text: ' ${ayahMark(q.ayahAt(v))}${v < q.verses.length - 1 ? ' ' : ''}',
                style: TextStyle(color: bracket),
              ),
            );
          }
          out.add(
            TextSpan(
              text: ' $closeBracket',
              style: TextStyle(color: bracket),
            ),
          );
      }
    }
    return out;
  }

  static TextStyle style(MadarTokens t, double scale, {Color? color}) => TextStyle(
    fontFamily: MadarTypography.naskhFamily,
    fontSize: kDhikrBaseFontSize * scale,
    height: 2.0,
    color: color ?? t.textPrimary,
    // Amiri's own ligatures and mark positioning; no synthetic spacing.
    letterSpacing: 0,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text.rich(
        TextSpan(
          children: spans(dhikr, bracket: t.accent, verse: color ?? t.textPrimary),
        ),
        textAlign: textAlign,
        textDirection: TextDirection.rtl,
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: style(t, scale, color: color),
      ),
    );
  }
}
