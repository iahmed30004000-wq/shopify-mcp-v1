import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../domain/ai_models.dart';
import '../ai_labels.dart';

/// Shown instead of the chat while no key is saved for the chosen service:
/// what the chat needs, where the key lives, and one tap to add it.
class AiKeySetupCard extends StatelessWidget {
  const AiKeySetupCard({super.key, required this.onAddKey, this.preferred = AiProviderId.anthropic});

  final void Function(AiProviderId provider) onAddKey;

  /// Listed first (the chosen service).
  final AiProviderId preferred;

  static Key addKey(AiProviderId p) => ValueKey('ai-setup-add-${p.name}');

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final order = [preferred, ...AiProviderId.values.where((p) => p != preferred)];
    return GlassPanel(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.xl, Space.xl, Space.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GirihRosette(size: 84, folds: 8),
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [t.accentSoft, t.space1]),
                    border: Border.all(color: t.brass.withValues(alpha: 0.7), width: 0.9),
                    boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 16)],
                  ),
                  child: Icon(Icons.key_rounded, color: t.gold, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          Text(
            l.aiChatSetupTitle,
            textAlign: TextAlign.center,
            style: text.headlineSmall!.copyWith(color: t.textPrimary),
          ),
          const SizedBox(height: Space.s),
          Text(
            l.aiChatSetupBody,
            textAlign: TextAlign.center,
            style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.55),
          ),
          const SizedBox(height: Space.xl),
          for (var i = 0; i < order.length; i++) ...[
            if (i > 0) const SizedBox(height: Space.s),
            MadarButton(
              key: addKey(order[i]),
              label: l.aiChatSetupAdd(l.aiService(order[i])),
              icon: aiServiceIcon(order[i]),
              expand: true,
              variant: i == 0 ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
              onPressed: () => onAddKey(order[i]),
            ),
          ],
          const SizedBox(height: Space.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_moon_outlined, size: 16, color: t.textTertiary),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(l.aiChatSetupPrivacy, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.45)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
