import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import 'ai_chat_screen.dart';

/// Opens a new AI chat with [prompt] typed in (not sent) – the default of
/// [AskAiEntry] and [AskAiButton]. Pass `onOpen` to route instead.
void openAskAi(BuildContext context, {String? prompt}) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AiChatScreen(initialDraft: prompt)));
}

/// "Ask AI" card for hubs (health, money, faith …): opens a new chat,
/// optionally with a suggested question already typed. Nothing is sent
/// until the user reviews the context and taps Send.
class AskAiEntry extends StatelessWidget {
  const AskAiEntry({super.key, this.area, this.prompt, this.onOpen, this.seed = 0});

  /// The hub's name for "Ask about {area}" (null = "Ask AI").
  final String? area;

  /// Question typed into the new chat (not sent).
  final String? prompt;

  /// Overrides the default (pushing [AiChatScreen]).
  final VoidCallback? onOpen;
  final double seed;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final title = area == null ? l.aiChatAskAi : l.aiChatAskAbout(area!);
    return GlassCard(
      seed: seed,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      semanticLabel: title,
      onTap: () {
        final open = onOpen;
        open != null ? open() : openAskAi(context, prompt: prompt);
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [t.accentSoft, t.accent.withValues(alpha: 0.04)]),
              border: Border.all(color: t.accent.withValues(alpha: 0.5), width: 0.9),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 19, color: t.accent),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: text.titleMedium!.copyWith(color: t.textPrimary)),
                Text(l.aiChatAskAiSubtitle, style: text.bodySmall!.copyWith(color: t.textTertiary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textTertiary),
        ],
      ),
    );
  }
}

/// A round "Ask AI" button for app bars.
class AskAiButton extends StatelessWidget {
  const AskAiButton({super.key, this.prompt, this.onOpen});

  final String? prompt;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => MadarButton.icon(
    icon: Icons.auto_awesome_rounded,
    semanticLabel: L10n.of(context).aiChatAskAi,
    variant: MadarButtonVariant.ghost,
    sfx: Sfx.navigate,
    onPressed: onOpen ?? () => openAskAi(context, prompt: prompt),
  );
}
