import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../data/data.dart' show SummarySectionId;
import '../../domain/conversation.dart';
import '../ai_labels.dart';

/// Always visible above the composer: what the next Send will send – the
/// summary sections (or none), how many messages and roughly how many
/// tokens. Tap to review or change (nothing is sent from here).
class WillSendStrip extends StatelessWidget {
  const WillSendStrip({
    super.key,
    required this.chatContext,
    required this.messageCount,
    required this.approxTokens,
    required this.onTap,
    this.omittedCount = 0,
  });

  final ChatContext chatContext;

  /// Messages that go out with the next Send (the typed one included).
  final int messageCount;
  final int approxTokens;
  final int omittedCount;
  final VoidCallback onTap;

  static const Key stripKey = ValueKey('ai-will-send-strip');

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final ctx = chatContext;
    final headings = ctx.sectionTitles;
    final ids = ChatContext.sectionIdsOf(headings, l.summaryTitles());

    final String contextLabel = switch (ctx.mode) {
      ContextMode.personal when ctx.isPersonal => fmt.localizeDigits(l.aiChatContextSections(headings.length)),
      ContextMode.none => l.aiChatContextNone,
      _ => l.aiChatContextReviewFirst,
    };
    final counts = [
      fmt.localizeDigits(l.aiChatMessagesCount(messageCount)),
      l.aiChatApproxTokens(fmt.formatInt(approxTokens)),
    ].join(' · ');
    final semantics = l.aiChatStripSemantics('$contextLabel, $counts');
    final accent = switch (ctx.mode) {
      ContextMode.personal => t.accent,
      ContextMode.none => t.textSecondary,
      ContextMode.unset => t.gold,
    };

    return MadarPressable(
      key: stripKey,
      onTap: onTap,
      sfx: Sfx.sheetOpen,
      pressScale: 0.985,
      semanticLabel: semantics,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.medium),
        curve: MadarMotion.standard,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.s, Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          color: t.glassFill,
          border: Border.all(color: accent.withValues(alpha: 0.38), width: 0.9),
        ),
        child: Row(
          children: [
            _Emblem(mode: ctx.mode, ids: ids),
            const SizedBox(width: Space.s + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${l.aiChatWillSend} · ',
                          style: text.labelMedium!.copyWith(color: accent, fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: contextLabel,
                          style: text.labelMedium!.copyWith(color: t.textPrimary),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    omittedCount > 0 ? '$counts · ${fmt.localizeDigits(l.aiChatOmitted(omittedCount))}' : counts,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall!.copyWith(color: t.textTertiary),
                  ),
                ],
              ),
            ),
            // chevron_right mirrors itself under RTL.
            Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Up to three section icons (or the none / unset symbol).
class _Emblem extends StatelessWidget {
  const _Emblem({required this.mode, required this.ids});

  final ContextMode mode;
  final List<SummarySectionId?> ids;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget dot(IconData icon, Color color) => Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.alphaBlend(color.withValues(alpha: 0.16), t.space1),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Icon(icon, size: 14, color: color),
    );
    if (mode == ContextMode.none) return dot(Icons.visibility_off_outlined, t.textSecondary);
    if (mode == ContextMode.unset || ids.isEmpty) return dot(Icons.shield_moon_outlined, t.gold);
    final shown = ids.take(3).toList();
    return SizedBox(
      width: 26 + (shown.length - 1) * 14.0,
      height: 26,
      child: Stack(
        children: [
          for (var i = shown.length - 1; i >= 0; i--)
            PositionedDirectional(start: i * 14.0, child: dot(summarySectionIcon(shown[i]), t.accent)),
        ],
      ),
    );
  }
}
