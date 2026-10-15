import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/day_chat_providers.dart';

/// The box he types his day into.
///
/// Sending **reads** the line and remembers it, and that is all: every
/// piece it was read into waits on its own card for his tap. The composer
/// writes nothing of his into any feature, and it reaches no network.
///
/// It is the quick-add pill's shape on purpose – same glass, same send
/// button, same place at the bottom of the screen – because the chat is
/// meant to feel like that one bar, grown up: the bar files one fact at
/// once, the chat takes a whole day and asks about each piece.
class DayChatComposer extends ConsumerStatefulWidget {
  const DayChatComposer({super.key, required this.day, this.initialText, this.scroll});

  /// The day the line belongs to.
  final DateTime day;

  /// Text already in the box (handed over from the home bar) – not sent.
  final String? initialText;

  /// Scrolled to the newest line after a send.
  final ScrollController? scroll;

  @override
  ConsumerState<DayChatComposer> createState() => _DayChatComposerState();
}

class _DayChatComposerState extends ConsumerState<DayChatComposer> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialText ?? '');
  final FocusNode _focus = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onText)
      ..dispose();
    _focus
      ..removeListener(_onFocus)
      ..dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  void _onFocus() => setState(() {});

  /// Reads the line and keeps it. Nothing of his is written by this.
  Future<void> _send() async {
    if (_busy) return;
    final text = _controller.text.trim();
    if (text.isEmpty) {
      Fx.fire(Sfx.error);
      return;
    }
    setState(() => _busy = true);
    Fx.fire(Sfx.tap);
    try {
      final service = ref.read(dayChatServiceProvider);
      final reading = await service.read(text, day: widget.day);
      await service.remember(reading);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _controller.clear();
      }
    }
    if (!mounted) return;
    Fx.fire(Sfx.complete);
    // The newest line is at the end of the list.
    final scroll = widget.scroll;
    if (scroll != null && scroll.hasClients) {
      unawaited(
        scroll.animateTo(
          scroll.position.maxScrollExtent + 600,
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.emphasized,
        ),
      );
    }
  }

  /// Direction of the text as typed, so a mixed line reads naturally
  /// whatever the UI language is.
  static TextDirection? _typed(String text) => text.trim().isEmpty ? null : BidiIsolate.directionOf(text);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final hasText = _controller.text.trim().isNotEmpty;
    final focused = _focus.hasFocus;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, 0, Space.l, Space.m),
      child: GlassPanel(
        borderRadius: BorderRadius.circular(t.radiusXL),
        borderColor: focused ? t.accent.withValues(alpha: 0.75) : null,
        glowColor: focused ? t.accentGlow.withValues(alpha: t.accentGlow.a * 0.55) : null,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs + 2, Space.xs + 2, Space.xs + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('dayChat.input'),
                controller: _controller,
                focusNode: _focus,
                textDirection: _typed(_controller.text),
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                style: text.bodyLarge?.copyWith(color: t.textPrimary),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  hintText: fmt.localizeDigits(l.dayChatComposerHint),
                  hintStyle: text.bodyMedium?.copyWith(color: t.textTertiary),
                  hintMaxLines: 2,
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: const EdgeInsetsDirectional.symmetric(vertical: Space.m),
                ),
              ),
            ),
            const SizedBox(width: Space.xs),
            _SendButton(
              key: const ValueKey('dayChat.send'),
              enabled: hasText && !_busy,
              busy: _busy,
              label: l.dayChatSendAction,
              onTap: () => unawaited(_send()),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round send button of the quick-add pill, kept to the letter so the
/// chat's box and the home bar are visibly the same thing.
class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.enabled,
    required this.busy,
    required this.label,
    required this.onTap,
  });

  final bool enabled;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final motion = context.motion(MadarMotion.short);
    return MadarPressable(
      onTap: onTap,
      enabled: enabled,
      sfx: null,
      pressScale: 0.9,
      semanticLabel: label,
      excludeChildSemantics: true,
      minTapTarget: MadarPressable.minTouchTarget,
      child: AnimatedContainer(
        duration: motion,
        curve: MadarMotion.emphasized,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color.lerp(t.accent, t.glassHighlight, 0.2)!, t.accent],
                )
              : null,
          color: enabled ? null : t.glassFill,
          border: Border.all(color: enabled ? t.accent : t.glassBorder, width: 0.9),
        ),
        child: busy
            ? Center(
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.textOnAccent),
                ),
              )
            : Icon(Icons.send_rounded, size: 20, color: enabled ? t.textOnAccent : t.textTertiary),
      ),
    );
  }
}
