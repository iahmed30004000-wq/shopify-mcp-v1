import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../domain/conversation.dart';
import '../../domain/payload.dart';
import '../ai_labels.dart';
import '../chat_controller.dart';

/// Opened from the "will send" strip: which summary sections go out (or
/// none), how much, and the way to change it or to see the exact request.
/// Nothing is sent from here.
Future<void> showWillSendSheet(
  BuildContext context, {
  required ChatController controller,
  required AiPayload Function() payload,
  required String serviceModel,
  required Future<void> Function(BuildContext context) onChooseSections,
  required void Function(BuildContext context) onViewPayload,
  required DateTime Function() clock,
}) => showInteractionSheet<void>(
  context,
  builder: (_) => WillSendSheet(
    controller: controller,
    payload: payload,
    serviceModel: serviceModel,
    onChooseSections: onChooseSections,
    onViewPayload: onViewPayload,
    clock: clock,
  ),
);

class WillSendSheet extends StatelessWidget {
  const WillSendSheet({
    super.key,
    required this.controller,
    required this.payload,
    required this.serviceModel,
    required this.onChooseSections,
    required this.onViewPayload,
    required this.clock,
  });

  final ChatController controller;
  final AiPayload Function() payload;
  final String serviceModel;
  final Future<void> Function(BuildContext context) onChooseSections;
  final void Function(BuildContext context) onViewPayload;
  final DateTime Function() clock;

  static const Key noneSwitchKey = ValueKey('ai-no-context-switch');
  static const Key chooseKey = ValueKey('ai-choose-sections');
  static const Key payloadKey = ValueKey('ai-view-payload');

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final t = context.tokens;
        final fmt = context.formatter;
        final text = Theme.of(context).textTheme;
        final ctx = controller.conversation.context;
        final p = payload();
        final headings = ctx.sectionTitles;
        final ids = ChatContext.sectionIdsOf(headings, l.summaryTitles());
        final none = ctx.mode == ContextMode.none;

        final counts = [
          fmt.localizeDigits(l.aiChatMessagesCount(p.historyCount)),
          l.aiChatApproxTokens(fmt.formatInt(p.approxTokens)),
          if (p.omittedCount > 0) fmt.localizeDigits(l.aiChatOmitted(p.omittedCount)),
        ].join(' · ');

        Widget contextBody;
        if (ctx.isPersonal) {
          contextBody = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  for (var i = 0; i < headings.length; i++)
                    MadarChip(label: headings[i], icon: summarySectionIcon(ids[i]), selected: true, dense: true),
                ],
              ),
              if (ctx.approvedAt != null) ...[
                const SizedBox(height: Space.s),
                Text(
                  l.aiChatContextReviewed(fmt.formatTime(ctx.approvedAt!)),
                  style: text.labelSmall!.copyWith(color: t.textTertiary),
                ),
              ],
            ],
          );
        } else if (none) {
          contextBody = Text(l.aiChatContextNoneHint, style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.45));
        } else {
          contextBody = Text(
            l.aiChatContextUnsetHint,
            style: text.bodySmall!.copyWith(color: t.textSecondary, height: 1.45),
          );
        }

        return InteractionSheetFrame(
          title: l.aiChatContextTitle,
          subtitle: l.aiChatContextSubtitle,
          icon: Icons.visibility_rounded,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassCard(
                glow: false,
                padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
                child: Row(
                  children: [
                    Icon(aiServiceIcon(p.request.provider), size: 18, color: t.accent),
                    const SizedBox(width: Space.s),
                    Expanded(child: Text(serviceModel, style: text.titleSmall!.copyWith(color: t.textPrimary))),
                  ],
                ),
              ),
              const SizedBox(height: Space.l),
              Text(l.aiChatContextFromSummary, style: text.labelLarge!.copyWith(color: t.textSecondary)),
              const SizedBox(height: Space.s),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: none ? 0.6 : 1,
                child: contextBody,
              ),
              const SizedBox(height: Space.m),
              if (!none)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: MadarButton(
                    key: chooseKey,
                    label: ctx.isPersonal ? l.aiChatContextChange : l.aiChatContextChoose,
                    icon: Icons.checklist_rounded,
                    size: MadarButtonSize.small,
                    variant: MadarButtonVariant.secondary,
                    onPressed: () => onChooseSections(context),
                  ),
                ),
              const SizedBox(height: Space.m),
              GlassCard(
                glow: false,
                padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.m, Space.s),
                child: Row(
                  children: [
                    Icon(Icons.visibility_off_outlined, size: 18, color: t.textSecondary),
                    const SizedBox(width: Space.m),
                    Expanded(child: Text(l.aiChatContextNone, style: text.titleSmall!.copyWith(color: t.textPrimary))),
                    MadarSwitch(
                      key: noneSwitchKey,
                      value: none,
                      semanticLabel: l.aiChatContextNone,
                      onChanged: (v) => controller.setNoContext(v, now: clock()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.l),
              Row(
                children: [
                  Icon(Icons.token_outlined, size: 16, color: t.textTertiary),
                  const SizedBox(width: Space.s),
                  Expanded(child: Text(counts, style: text.bodySmall!.copyWith(color: t.textSecondary))),
                ],
              ),
            ],
          ),
          footer: Row(
            children: [
              Expanded(
                child: SheetButton(
                  key: payloadKey,
                  label: l.aiChatViewPayload,
                  icon: Icons.data_object_rounded,
                  onPressed: () => onViewPayload(context),
                ),
              ),
              const SizedBox(width: Space.s),
              SheetButton(
                label: l.aiChatDone,
                icon: Icons.check_rounded,
                primary: true,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        );
      },
    );
  }
}
