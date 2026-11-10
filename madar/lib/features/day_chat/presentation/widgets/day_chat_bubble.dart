import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../domain/day_chat_piece.dart';

/// His own line, exactly as he typed it, with **the words each card came
/// from underlined inside it**.
///
/// This is the thing that makes the chat trustworthy: a card never says
/// "I read a prayer somewhere in there", it points at «صليت العصر بالمسجد»
/// in his own sentence. The underline is drawn from
/// [DayChatPiece.span] – `[start, end)` in the raw text – so nothing is
/// matched, searched for or guessed; the engine told us where it looked.
///
/// The piece whose card he is looking at ([focusedPieceId]) is filled as well as
/// underlined, so «وين هاي من كلامي؟» answers itself.
class DayChatBubble extends StatelessWidget {
  const DayChatBubble({
    super.key,
    required this.raw,
    required this.pieces,
    this.focusedPieceId,
    this.at,
  });

  /// The text he typed (every span indexes into this).
  final String raw;

  /// The pieces it was read into (in the order he typed them).
  final List<DayChatPiece> pieces;

  /// The piece whose card is open, drawn stronger than the rest.
  final String? focusedPieceId;

  /// When he sent it.
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final body = text.bodyMedium!.copyWith(color: t.textPrimary, height: 1.65);
    final when = at;

    // His own words sit at the reading start, the way a sent message does.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: GlassCard(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
          borderColor: t.accent.withValues(alpha: 0.26),
          glowColor: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // TalkBack reads the sentence once, plainly: an underline is
              // a pointer for the eye, not a second reading of his words.
              Semantics(
                label: raw,
                excludeSemantics: true,
                child: Text.rich(
                  TextSpan(children: _spans(context, body, t)),
                  textDirection: BidiIsolate.directionOf(raw),
                  textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                ),
              ),
              if (when != null) ...[
                const SizedBox(height: Space.xs),
                Text(fmt.formatTime(when), style: text.labelSmall?.copyWith(color: t.textTertiary)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// His line cut at the pieces' boundaries: plain text between them, an
  /// underlined (and, for the focused one, tinted) stretch on each.
  List<InlineSpan> _spans(BuildContext context, TextStyle base, MadarTokens t) {
    final marks = [
      for (final p in pieces)
        if (!p.span.isEmpty && p.span.start < raw.length) p,
    ]..sort((a, b) => a.span.start.compareTo(b.span.start));
    final out = <InlineSpan>[];
    var cursor = 0;
    for (final piece in marks) {
      final start = piece.span.start.clamp(0, raw.length);
      final end = piece.span.end.clamp(start, raw.length);
      // Overlapping spans never happen (the segmenter cuts the line), but a
      // stored line read again must never throw over a changed reader.
      if (start < cursor) continue;
      if (start > cursor) out.add(TextSpan(text: raw.substring(cursor, start), style: base));
      final focused = piece.id == focusedPieceId;
      final colour = piece.kind == DayChatKind.unread ? t.warning : t.accent;
      out.add(
        TextSpan(
          text: raw.substring(start, end),
          style: base.copyWith(
            color: t.textPrimary,
            backgroundColor: focused ? colour.withValues(alpha: t.isDark ? 0.22 : 0.14) : null,
            decoration: TextDecoration.underline,
            decorationColor: colour.withValues(alpha: focused ? 0.95 : 0.55),
            decorationThickness: focused ? 2.4 : 1.4,
            decorationStyle: piece.kind == DayChatKind.unread ? TextDecorationStyle.dotted : TextDecorationStyle.solid,
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < raw.length) out.add(TextSpan(text: raw.substring(cursor), style: base));
    return out;
  }
}
