import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';

/// Shown instead of the chat while the owner's own switch is off
/// (`AiSettings.outsideAllowed`): why nothing happens, in his own words,
/// and one tap to the switch. Every way into the chat – the route, the
/// "Ask about …" card at the foot of a world, a question handed over from
/// the quick-add bar – lands here rather than on a dead screen.
class AiOffCard extends StatelessWidget {
  const AiOffCard({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  static const Key cardKey = ValueKey('ai-off-card');
  static const Key actionKey = ValueKey('ai-off-open-settings');

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassPanel(
      key: cardKey,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.xl, Space.xl, Space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const GirihRosette(size: 84, folds: 8),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [t.accentSoft, t.space1]),
                    border: Border.all(color: t.success.withValues(alpha: 0.7), width: 0.9),
                  ),
                  child: Icon(Icons.cloud_off_rounded, color: t.success, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          Text(
            l.aiChatOffTitle,
            textAlign: TextAlign.center,
            style: text.headlineSmall!.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: Space.s),
          Text(
            l.aiChatOffBody,
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.55),
          ),
          const SizedBox(height: Space.xl),
          MadarButton(
            key: actionKey,
            label: l.aiChatOffAction,
            icon: Icons.tune_rounded,
            expand: true,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

/// The same message, shrunk to a strip above the field: shown while the
/// switch is off over a conversation that already has messages, so he can
/// still read what was said without the screen pretending Send will work.
class AiOffStrip extends StatelessWidget {
  const AiOffStrip({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  static const Key stripKey = ValueKey('ai-off-strip');

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      key: stripKey,
      onTap: onOpenSettings,
      semanticLabel: '${l.aiChatOffTitle}. ${l.aiChatOffAction}',
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          color: t.success.withValues(alpha: 0.1),
          border: Border.all(color: t.success.withValues(alpha: 0.3), width: 0.9),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: t.success),
            const SizedBox(width: Space.s),
            Expanded(
              child: Text(l.aiChatOffTitle, style: text.bodySmall!.copyWith(color: t.textSecondary)),
            ),
            Text(l.aiChatOffAction, style: text.labelMedium!.copyWith(color: t.accent)),
          ],
        ),
      ),
    );
  }
}
