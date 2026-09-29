import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/hifz_reveal.dart';

/// A text under review, revealed progressively: hidden words keep their
/// shape as a faint ghost (so nothing moves when they appear), the first
/// letter of each word lights up in [HifzRevealStage.firstLetters], words
/// light up one by one, then all. Ayah markers are always shown. Tapping
/// the text reveals the next word.
class HifzRevealText extends StatelessWidget {
  const HifzRevealText({
    super.key,
    required this.tokens,
    required this.reveal,
    required this.style,
    this.markerStyle,
    this.onTap,
    this.textAlign = TextAlign.center,
    this.semanticsLabel,
  });

  final List<HifzToken> tokens;
  final HifzReveal reveal;
  final TextStyle style;
  final TextStyle? markerStyle;
  final VoidCallback? onTap;
  final TextAlign textAlign;
  final String? semanticsLabel;

  static final RegExp _arabic = RegExp('[\u0600-\u06FF]');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ghost = t.textPrimary.withValues(alpha: t.isDark ? 0.11 : 0.13);
    final hint = Color.lerp(t.accent, t.textPrimary, 0.15)!;
    final shown = style.copyWith(color: t.textPrimary);
    final spans = <InlineSpan>[];
    var w = 0;
    for (var i = 0; i < tokens.length; i++) {
      final tok = tokens[i];
      if (i > 0) spans.add(TextSpan(text: ' ', style: shown));
      if (tok.marker) {
        spans.add(
          TextSpan(
            text: tok.text,
            style: markerStyle ?? style.copyWith(color: t.brass),
          ),
        );
        continue;
      }
      if (reveal.isShown(w)) {
        spans.add(TextSpan(text: tok.text, style: shown));
      } else if (reveal.showsFirstLetters) {
        final (head, rest) = HifzText.splitFirst(tok.text);
        spans.add(
          TextSpan(
            text: head,
            style: style.copyWith(color: hint),
          ),
        );
        if (rest.isNotEmpty) {
          spans.add(
            TextSpan(
              text: rest,
              style: style.copyWith(color: ghost),
            ),
          );
        }
      } else {
        spans.add(
          TextSpan(
            text: tok.text,
            style: style.copyWith(color: ghost),
          ),
        );
      }
      w++;
    }
    final body = Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      textDirection: tokens.any((t) => _arabic.hasMatch(t.text)) ? TextDirection.rtl : TextDirection.ltr,
      semanticsLabel: reveal.isFull ? null : (semanticsLabel ?? ''),
    );
    if (onTap == null) return body;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: body);
  }
}
