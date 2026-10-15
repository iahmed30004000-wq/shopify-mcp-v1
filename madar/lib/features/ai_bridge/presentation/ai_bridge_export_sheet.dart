import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../../data/data.dart'
    show
        AiSummaryOptions,
        ExportPreviewMode,
        SummarySectionId,
        dataClockProvider,
        dataFileBridgeProvider,
        showExportPreviewSheet;
import '../../data/presentation/widgets/data_widgets.dart';
import '../../data/presentation/widgets/file_panel.dart' show DataDelivery;
import '../data/ai_bridge_providers.dart';
import '../data/ai_bridge_repository.dart';
import '../domain/plan_request.dart';

/// Opens «استشارة ذكاء اصطناعي»: he picks what to send with the data
/// package's own chooser, types his question if he wants one, and Madar
/// hands him one file (or the same text on the clipboard) carrying his
/// summary, the prompt and the exact answer shape.
///
/// [initialAsk] only **types** his question into the field (Part 7's daily
/// chat hands over the one sentence it could not read): nothing is chosen,
/// built or sent because of it.
Future<void> showAiBridgeExportSheet(BuildContext context, {String? initialAsk}) =>
    showInteractionSheet<void>(context, builder: (_) => AiBridgeExportSheet(initialAsk: initialAsk));

class AiBridgeExportSheet extends ConsumerStatefulWidget {
  const AiBridgeExportSheet({super.key, this.initialAsk});

  /// A question already typed in – never sent (see [showAiBridgeExportSheet]).
  final String? initialAsk;

  @override
  ConsumerState<AiBridgeExportSheet> createState() => _AiBridgeExportSheetState();
}

class _AiBridgeExportSheetState extends ConsumerState<AiBridgeExportSheet> {
  late final TextEditingController _ask = TextEditingController(text: widget.initialAsk ?? '');

  /// The Markdown he approved in the chooser, and the sections behind it.
  String? _markdown;
  Set<SummarySectionId> _sections = const {};
  PlanRequest? _request;
  String? _notice;
  bool _busy = false;

  @override
  void dispose() {
    _ask.dispose();
    super.dispose();
  }

  bool get _ready => _request != null;

  /// Reuses the data package's per-section chooser – the same sheet,
  /// the same stored choices, no second chooser anywhere.
  Future<void> _choose() async {
    final l = L10n.of(context);
    var options = const AiSummaryOptions();
    final markdown = await showExportPreviewSheet(
      context,
      mode: ExportPreviewMode.select,
      confirmLabel: l.aiPlanExportTitle,
      onApproved: (o) => options = o,
    );
    if (!mounted || markdown == null || markdown.trim().isEmpty) return;
    _markdown = markdown;
    _sections = options.included;
    await _build();
  }

  Future<void> _build() async {
    final markdown = _markdown;
    if (markdown == null) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final request = await ref
          .read(aiBridgeRepositoryProvider)
          .buildRequest(
            now: ref.read(dataClockProvider)(),
            languageCode: Localizations.localeOf(context).languageCode,
            summaryMarkdown: markdown,
            sections: _sections,
            ask: _ask.text,
          );
      if (!mounted) return;
      setState(() {
        _request = request;
        _busy = false;
      });
    } catch (_) {
      Fx.fire(Sfx.error);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice = L10n.of(context).dataExportFailed;
      });
    }
  }

  Future<void> _deliver(DataDelivery? how) async {
    final request = _request;
    if (request == null) return;
    final l = L10n.of(context);
    final bridge = ref.read(dataFileBridgeProvider);
    try {
      if (how == null) {
        await bridge.copyText(request.asText());
        Fx.fire(Sfx.complete);
        if (mounted) setState(() => _notice = l.dataSummaryCopied);
        return;
      }
      final file = AiBridgeRepository.requestFile(request);
      final ok = how == DataDelivery.shared
          ? await bridge.share(file, subject: l.aiPlanExportTitle)
          : await bridge.save(file);
      if (ok) {
        Fx.fire(Sfx.complete);
        if (mounted) setState(() => _notice = how == DataDelivery.shared ? l.dataFileShared : l.dataFileSaved);
      }
    } catch (_) {
      Fx.fire(Sfx.error);
      if (mounted) setState(() => _notice = l.dataFileSendFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final request = _request;

    return InteractionSheetFrame(
      title: l.aiPlanExportTitle,
      subtitle: l.aiPlanExportSubtitle,
      icon: Icons.auto_awesome_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DataNote(text: l.aiPlanExportBody, icon: Icons.swap_horiz_rounded, color: t.accent),
          const SizedBox(height: Space.l),
          Text(l.aiPlanStepChoose, style: text.labelLarge!.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.xs),
          Text(l.aiPlanStepChooseBody, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.5)),
          const SizedBox(height: Space.m),
          MadarButton(
            label: _ready ? l.aiPlanChangeChoice : l.aiPlanChooseAction,
            icon: Icons.checklist_rounded,
            variant: _ready ? MadarButtonVariant.secondary : MadarButtonVariant.primary,
            expand: true,
            sfx: Sfx.sheetOpen,
            onPressed: _busy ? null : _choose,
          ),
          const SizedBox(height: Space.l),
          TextField(
            controller: _ask,
            minLines: 1,
            maxLines: 3,
            maxLength: 280,
            style: text.bodyMedium!.copyWith(color: t.textPrimary),
            cursorColor: t.accent,
            decoration: dataInputDecoration(context, label: l.aiPlanAskLabel, hint: l.aiPlanAskHint),
            onChanged: (_) {
              if (_request != null) unawaited(_build());
            },
          ),
          Text(l.aiPlanAskOptional, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.5)),
          const SizedBox(height: Space.l),
          if (_busy)
            DataBusy(title: l.dataSummaryPreparing)
          else if (request == null)
            DataNote(text: l.aiPlanChooseFirst, icon: Icons.touch_app_rounded, color: t.warning, dense: true)
          else ...[
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: l.aiPlanFileReady,
                    value: formatDataSize(l, fmt, request.byteSize),
                    icon: Icons.description_outlined,
                    color: t.success,
                  ),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: StatTile(
                    label: l.dataSummarySections,
                    value: fmt.formatInt(request.sections.length),
                    icon: Icons.checklist_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            DataNote(text: l.aiPlanPromptIncluded, icon: Icons.menu_book_rounded, color: t.accent, dense: true),
            const SizedBox(height: Space.s),
            DataNote(text: l.aiPlanLeftOut, icon: Icons.lock_rounded, color: t.gold, dense: true),
            const SizedBox(height: Space.s),
            DataNote(text: l.aiPlanHowTo, icon: Icons.ios_share_rounded, color: t.textSecondary, dense: true),
            const SizedBox(height: Space.s),
            DataNote(text: l.aiPlanAnswerBack, icon: Icons.move_to_inbox_rounded, color: t.secondary, dense: true),
          ],
          if (_notice != null) ...[
            const SizedBox(height: Space.m),
            DataNote(
              text: _notice!,
              icon: _notice == l.dataFileSendFailed || _notice == l.dataExportFailed
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_rounded,
              color: _notice == l.dataFileSendFailed || _notice == l.dataExportFailed ? t.danger : t.success,
              dense: true,
            ),
          ],
        ],
      ),
      footer: Row(
        children: [
          SheetButton(
            label: l.dataCopyAction,
            icon: Icons.copy_rounded,
            enabled: _ready,
            onPressed: () => _deliver(null),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: SheetButton(
              label: l.dataSaveAction,
              icon: Icons.save_alt_rounded,
              enabled: _ready,
              onPressed: () => _deliver(DataDelivery.saved),
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: SheetButton(
              label: l.dataShareAction,
              icon: Icons.ios_share_rounded,
              primary: true,
              enabled: _ready,
              onPressed: () => _deliver(DataDelivery.shared),
            ),
          ),
        ],
      ),
    );
  }
}
