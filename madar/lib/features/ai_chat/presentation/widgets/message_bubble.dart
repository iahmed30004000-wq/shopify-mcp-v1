import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/ai_models.dart';
import '../../domain/conversation.dart';
import '../../domain/system_prompt.dart';
import '../ai_labels.dart';
import 'markdown_view.dart';

/// One message of the conversation.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.streaming = false,
    this.canRegenerate = false,
    this.onRegenerate,
    this.onRetry,
    this.onOpenSettings,
    this.errorDetail,
    this.onOpenLink,
  });

  final ChatMessage message;

  /// The reply is arriving right now.
  final bool streaming;
  final bool canRegenerate;
  final VoidCallback? onRegenerate;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  /// The provider's (redacted) message for the latest failure.
  final String? errorDetail;
  final MdLinkOpener? onOpenLink;

  @override
  Widget build(BuildContext context) => message.isUser ? _UserBubble(message: message) : _AssistantBubble(bubble: this);
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final r = Radius.circular(t.radiusL);
    final dir = BidiIsolate.directionOf(message.text) ?? Directionality.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
              decoration: BoxDecoration(
                borderRadius: BorderRadiusDirectional.only(
                  topStart: r,
                  topEnd: r,
                  bottomStart: r,
                  bottomEnd: const Radius.circular(6),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    t.accent.withValues(alpha: t.isDark ? 0.34 : 0.2),
                    t.accent.withValues(alpha: t.isDark ? 0.22 : 0.12),
                  ],
                ),
                border: Border.all(color: t.accent.withValues(alpha: 0.45), width: 0.9),
              ),
              child: Text(
                message.text,
                textDirection: dir,
                style: text.bodyLarge!.copyWith(color: t.textPrimary, height: 1.5),
              ),
            ),
            _ActionRow(text: message.text, alignEnd: true),
          ],
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.bubble});

  final MessageBubble bubble;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final m = bubble.message;
    final failed = m.status == MessageStatus.failed;
    final streaming = bubble.streaming;
    final waiting = streaming && m.text.isEmpty;
    final base = text.bodyLarge!.copyWith(color: t.textPrimary, height: 1.6);
    final model = m.model;

    final notes = <Widget>[
      if (m.status == MessageStatus.stopped) _Note(icon: Icons.stop_circle_outlined, text: l.aiChatStopped),
      if (m.stopReason == AiStopReason.maxTokens) _Note(icon: Icons.short_text_rounded, text: l.aiChatCutShort),
      if (m.stopReason == AiStopReason.refusal) _Note(icon: Icons.do_not_disturb_on_outlined, text: l.aiChatRefused),
      if (m.stopReason == AiStopReason.contentFilter) _Note(icon: Icons.filter_alt_outlined, text: l.aiChatFiltered),
      // Also under a failed or stopped partial reply: its text stays visible.
      if (!streaming && m.text.isNotEmpty && HealthMentions.mentions(m.text))
        _Note(icon: Icons.health_and_safety_outlined, text: l.aiChatHealthNote, key: const ValueKey('ai-health-note')),
    ];

    Widget body;
    if (waiting) {
      body = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OrbitLoader(size: 22, semanticLabel: l.aiChatWriting),
          const SizedBox(width: Space.s),
          Text(l.aiChatThinking, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.text.isNotEmpty) MarkdownView(m.text, style: base, onOpenLink: bubble.onOpenLink),
          if (streaming)
            const Padding(
              padding: EdgeInsetsDirectional.only(top: Space.xs),
              child: Align(alignment: AlignmentDirectional.centerStart, child: _Caret()),
            ),
        ],
      );
    }

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(6),
          topEnd: Radius.circular(t.radiusL),
          bottomStart: Radius.circular(t.radiusL),
          bottomEnd: Radius.circular(t.radiusL),
        ),
        color: t.glassFill,
        border: Border.all(color: t.glassBorder.withValues(alpha: 0.75), width: 0.8),
        boxShadow: [
          BoxShadow(color: t.glassShadow.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: AnimatedSize(
        duration: context.reducedMotion ? Duration.zero : MadarMotion.short,
        curve: MadarMotion.standard,
        alignment: AlignmentDirectional.topStart,
        child: body,
      ),
    );

    return Semantics(
      container: true,
      liveRegion: streaming,
      label: l.aiChatRoleAssistant,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (model != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: Space.xs, bottom: Space.xs),
              child: Row(
                children: [
                  IslamicStar(size: 11, color: t.brass, glow: streaming),
                  const SizedBox(width: Space.xs + 2),
                  Flexible(
                    child: Text(
                      aiModelLabel(model),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall!.copyWith(color: t.textTertiary, letterSpacing: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          if (!failed || m.text.isNotEmpty) card,
          for (final n in notes) n,
          if (failed)
            _ErrorCard(
              message: l.aiError(
                m.error ?? AiErrorKind.unknown,
                provider: m.provider ?? AiProviderId.anthropic,
                model: model ?? '',
              ),
              detail: bubble.errorDetail,
              onRetry: bubble.onRetry,
              onOpenSettings: aiErrorWantsSettings(m.error ?? AiErrorKind.unknown) ? bubble.onOpenSettings : null,
            ),
          if (!streaming && m.text.isNotEmpty)
            _ActionRow(text: m.text, onRegenerate: bubble.canRegenerate ? bubble.onRegenerate : null),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.s, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 1),
            child: Icon(icon, size: 14, color: t.textTertiary),
          ),
          const SizedBox(width: Space.xs + 2),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textTertiary, height: 1.4, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.detail, this.onRetry, this.onOpenSettings});

  final String message;
  final String? detail;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsetsDirectional.only(top: Space.s),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        color: t.danger.withValues(alpha: t.isDark ? 0.14 : 0.08),
        border: Border.all(color: t.danger.withValues(alpha: 0.45), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, size: 20, color: t.danger),
              const SizedBox(width: Space.s),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(message, style: text.bodyMedium!.copyWith(color: t.textPrimary, height: 1.45)),
                ),
              ),
            ],
          ),
          if (detail != null && detail!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 28, top: Space.xs),
              child: Text(
                BidiIsolate.isolate(detail!.trim()),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall!.copyWith(color: t.textTertiary),
              ),
            ),
          if (onRetry != null || onOpenSettings != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 20, top: Space.s),
              child: Wrap(
                spacing: Space.s,
                runSpacing: Space.xs,
                children: [
                  if (onRetry != null)
                    MadarButton(
                      label: l.aiChatRetry,
                      icon: Icons.refresh_rounded,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.secondary,
                      onPressed: onRetry,
                    ),
                  if (onOpenSettings != null)
                    MadarButton(
                      label: l.aiChatOpenSettings,
                      icon: Icons.tune_rounded,
                      size: MadarButtonSize.small,
                      variant: MadarButtonVariant.ghost,
                      sfx: Sfx.navigate,
                      onPressed: onOpenSettings,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Copy (and regenerate) under a message.
class _ActionRow extends StatefulWidget {
  const _ActionRow({required this.text, this.onRegenerate, this.alignEnd = false});

  final String text;
  final VoidCallback? onRegenerate;
  final bool alignEnd;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _copied = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.text));
    Fx.fire(Sfx.complete);
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    Widget button(IconData icon, String label, VoidCallback onTap, {Color? color}) => Tooltip(
      message: label,
      child: MadarPressable(
        onTap: onTap,
        sfx: null,
        semanticLabel: label,
        excludeChildSemantics: true,
        focusRadius: BorderRadius.circular(18),
        child: SizedBox.square(dimension: 36, child: Icon(icon, size: 17, color: color ?? t.textTertiary)),
      ),
    );
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.xxs),
      child: Row(
        mainAxisAlignment: widget.alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: context.motion(MadarMotion.short),
            child: _copied
                ? button(Icons.check_rounded, l.aiChatCopied, _copy, color: t.success)
                : button(Icons.copy_rounded, l.aiChatCopy, _copy),
          ),
          if (widget.onRegenerate != null) button(Icons.autorenew_rounded, l.aiChatRegenerate, widget.onRegenerate!),
        ],
      ),
    );
  }
}

/// The glowing dot at the end of a reply that is still arriving (static
/// under reduced motion).
class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reducedMotion) {
      _pulse.stop();
      _pulse.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 1).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.accent,
            boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.7), blurRadius: 8)],
          ),
        ),
      ),
    );
  }
}
