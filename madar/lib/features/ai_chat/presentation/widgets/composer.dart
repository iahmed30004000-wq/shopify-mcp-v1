import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';

/// The message field with Send (or Stop while a reply arrives). The field
/// follows the direction of what is typed.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onStop,
    required this.busy,
    this.enabled = true,
    this.focusNode,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final bool busy;
  final bool enabled;
  final FocusNode? focusNode;

  static const Key sendKey = ValueKey('ai-send');
  static const Key stopKey = ValueKey('ai-stop');
  static const Key fieldKey = ValueKey('ai-input');

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final dir = BidiIsolate.directionOf(value.text) ?? Directionality.of(context);
        final canSend = enabled && !busy && value.text.trim().isNotEmpty;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(t.radiusL),
                  color: t.glassFill,
                  border: Border.all(color: t.glassBorder.withValues(alpha: 0.9), width: 0.9),
                ),
                child: TextField(
                  key: fieldKey,
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 6,
                  maxLength: 8000,
                  textDirection: dir,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  style: text.bodyLarge!.copyWith(color: t.textPrimary, height: 1.45),
                  cursorColor: t.accent,
                  decoration: InputDecoration(
                    hintText: l.aiChatInputHint,
                    hintStyle: text.bodyLarge!.copyWith(color: t.textTertiary),
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m + 1, Space.l, Space.m + 1),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.s),
            AnimatedSwitcher(
              duration: context.motion(MadarMotion.short),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: busy
                  ? MadarButton.icon(
                      key: stopKey,
                      icon: Icons.stop_rounded,
                      semanticLabel: l.aiChatStop,
                      variant: MadarButtonVariant.danger,
                      sfx: Sfx.toggleOff,
                      onPressed: onStop,
                    )
                  : MadarButton.icon(
                      key: sendKey,
                      icon: Icons.arrow_upward_rounded,
                      semanticLabel: l.aiChatSend,
                      variant: MadarButtonVariant.primary,
                      sfx: Sfx.navigate,
                      onPressed: canSend ? onSend : null,
                    ),
            ),
          ],
        );
      },
    );
  }
}
