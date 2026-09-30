import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../data/data.dart' show AiSummary;
import '../../data/transport.dart';
import '../../domain/ai_models.dart';
import '../../domain/payload.dart';
import '../ai_labels.dart';

/// "What will be sent": the exact request of the next call – endpoint,
/// headers (the key masked), the instructions with the approved context,
/// every message, and the full JSON body. Opening it sends nothing.
Future<void> showPayloadSheet(
  BuildContext context, {
  required AiHttpRequest request,
  required AiPayload payload,
  required bool includesDraft,
}) => showInteractionSheet<void>(
  context,
  builder: (_) => PayloadSheet(request: request, payload: payload, includesDraft: includesDraft),
);

class PayloadSheet extends StatefulWidget {
  const PayloadSheet({super.key, required this.request, required this.payload, required this.includesDraft});

  final AiHttpRequest request;
  final AiPayload payload;
  final bool includesDraft;

  @override
  State<PayloadSheet> createState() => _PayloadSheetState();
}

class _PayloadSheetState extends State<PayloadSheet> {
  bool _raw = false;
  bool _copied = false;

  String get _pretty {
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(widget.request.body ?? 'null'));
    } catch (_) {
      return widget.request.body ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final req = widget.payload.request;
    final body = widget.request.body ?? '';
    final bytes = AiSummary.byteSize(body);
    final size = bytes < 1024
        ? l.aiChatBytes(fmt.formatInt(bytes))
        : l.aiChatKiloBytes(fmt.formatNumber(bytes / 1024, maxDecimals: 1));
    final label = text.labelLarge!.copyWith(color: t.textSecondary);
    final mono = text.bodySmall!.copyWith(color: t.textPrimary, height: 1.5, fontSize: 12.5);

    Widget box(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(Space.m),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        color: t.space0.withValues(alpha: t.isDark ? 0.42 : 0.55),
        border: Border.all(color: t.glassBorder.withValues(alpha: 0.7), width: 0.8),
      ),
      child: child,
    );

    // Display only: each line takes its own direction.
    Widget lines(String s) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final line in s.split('\n'))
          Text(
            line.isEmpty ? ' ' : line,
            textDirection: BidiIsolate.directionOf(line) ?? TextDirection.ltr,
            style: mono,
          ),
      ],
    );

    final children = <Widget>[
      Row(
        children: [
          Icon(aiServiceIcon(req.provider), size: 18, color: t.accent),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(
              l.aiChatServiceModel(l.aiService(req.provider), BidiIsolate.ltr(req.model)),
              style: text.titleSmall!.copyWith(color: t.textPrimary),
            ),
          ),
          Text(
            l.aiChatPayloadSize(size, fmt.formatInt(widget.payload.approxTokens)),
            style: text.labelSmall!.copyWith(color: t.textTertiary),
          ),
        ],
      ),
      const SizedBox(height: Space.s),
      _Hint(text: widget.includesDraft ? l.aiChatPayloadDraftNote : l.aiChatPayloadNoDraft),
      const SizedBox(height: Space.l),
      Text(l.aiChatPayloadEndpoint, style: label),
      const SizedBox(height: Space.xs),
      box(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText('${widget.request.method} ${widget.request.url}', style: mono),
        ),
      ),
      const SizedBox(height: Space.m),
      Text(l.aiChatPayloadHeaders, style: label),
      const SizedBox(height: Space.xs),
      box(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SelectableText(
            [for (final e in widget.request.headers.entries) '${e.key}: ${e.value}'].join('\n'),
            style: mono,
          ),
        ),
      ),
      const SizedBox(height: Space.m),
      Text(l.aiChatPayloadSystem, style: label),
      const SizedBox(height: Space.xs),
      box(SelectionArea(child: lines(req.system))),
      const SizedBox(height: Space.m),
      Text(l.aiChatPayloadMessages, style: label),
      const SizedBox(height: Space.xs),
      for (final m in req.messages) ...[
        box(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                m.role == ChatRole.user ? l.aiChatRoleUser : l.aiChatRoleAssistant,
                style: text.labelSmall!.copyWith(color: t.accent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Space.xxs),
              SelectionArea(child: lines(m.text)),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
      ],
      const SizedBox(height: Space.s),
      DisclosureRow(
        label: l.aiChatPayloadRaw,
        expanded: _raw,
        onTap: () => setState(() => _raw = !_raw),
      ),
      AnimatedSize(
        duration: context.motion(MadarMotion.medium),
        curve: MadarMotion.emphasized,
        alignment: AlignmentDirectional.topCenter,
        child: _raw
            ? Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.xs),
                child: box(
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(_pretty, key: const ValueKey('ai-payload-json'), style: mono),
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    ];

    return InteractionSheetFrame(
      title: l.aiChatPayloadTitle,
      subtitle: l.aiChatContextSubtitle,
      icon: Icons.data_object_rounded,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
      footer: Row(
        children: [
          SheetButton(
            label: _copied ? l.aiChatCopied : l.aiChatCopy,
            icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: body));
              Fx.fire(Sfx.complete);
              setState(() => _copied = true);
            },
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: SheetButton(
              label: l.aiChatDone,
              icon: Icons.check_rounded,
              primary: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2),
          child: Icon(Icons.info_outline_rounded, size: 15, color: t.textTertiary),
        ),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textTertiary, height: 1.4)),
        ),
      ],
    );
  }
}

/// A disclosure row ("Full body (JSON)  ⌄").
class DisclosureRow extends StatelessWidget {
  const DisclosureRow({super.key, required this.label, required this.expanded, required this.onTap});

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusS),
        onTap: () {
          Fx.fire(expanded ? Sfx.toggleOff : Sfx.toggleOn);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
          child: Row(
            children: [
              Expanded(
                child: Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.textSecondary)),
              ),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: context.motion(MadarMotion.short),
                child: Icon(Icons.expand_more_rounded, color: t.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
