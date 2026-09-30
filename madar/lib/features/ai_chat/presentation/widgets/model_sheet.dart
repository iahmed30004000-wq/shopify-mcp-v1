import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/ai_chat_providers.dart';
import '../../data/transport.dart';
import '../../domain/ai_models.dart';
import '../../domain/ai_settings.dart';
import '../ai_labels.dart';

/// Service and model: the editable list per service, what "Refresh models"
/// brought (only fetched on tap) and a free-text model id.
Future<void> showModelPickerSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const ModelPickerSheet());

class ModelPickerSheet extends ConsumerStatefulWidget {
  const ModelPickerSheet({super.key});

  static const Key refreshKey = ValueKey('ai-models-refresh');
  static const Key customFieldKey = ValueKey('ai-model-custom');
  static const Key customUseKey = ValueKey('ai-model-custom-use');

  @override
  ConsumerState<ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends ConsumerState<ModelPickerSheet> {
  final _custom = TextEditingController();
  bool _refreshing = false;
  String? _notice;
  bool _noticeOk = true;
  bool _invalid = false;
  AiCancelToken? _cancel;

  @override
  void dispose() {
    _cancel?.cancel();
    _custom.dispose();
    super.dispose();
  }

  AiSettingsController get _settings => ref.read(aiSettingsProvider.notifier);

  void _select(AiProviderId p, String id) {
    Fx.fire(Sfx.toggleOn);
    _settings.change((s) => s.selectModel(p, id).copyWith(provider: p));
    Navigator.of(context).maybePop();
  }

  void _useCustom(AiProviderId p) {
    final id = AiSettings.cleanModelId(_custom.text);
    if (id == null) {
      Fx.fire(Sfx.error);
      setState(() => _invalid = true);
      return;
    }
    _custom.clear();
    _select(p, id);
  }

  Future<void> _refresh(AiProviderId p) async {
    final l = L10n.of(context);
    final fmt = context.formatter;
    final model = ref.read(aiSettingsProvider).value?.modelFor(p) ?? '';
    setState(() {
      _refreshing = true;
      _notice = null;
    });
    final cancel = _cancel = AiCancelToken();
    try {
      final list = await refreshAiModels(ref, p, cancel: cancel);
      if (!mounted) return;
      Fx.fire(Sfx.complete);
      setState(() {
        _refreshing = false;
        _notice = fmt.localizeDigits(l.aiChatModelRefreshed(list.length));
        _noticeOk = true;
      });
    } on AiCancelledException {
      return;
    } on AiException catch (e) {
      if (!mounted) return;
      Fx.fire(Sfx.error);
      setState(() {
        _refreshing = false;
        _notice = l.aiError(e.kind, provider: p, model: model);
        _noticeOk = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(aiSettingsProvider).value ?? const AiSettings();
    final p = settings.provider;
    final list = settings.modelsFor(p);
    final selected = settings.modelFor(p);
    final fetched = [for (final m in settings.fetchedFor(p)) if (!list.contains(m.id)) m];
    final label = text.labelLarge!.copyWith(color: t.textSecondary);

    return InteractionSheetFrame(
      title: l.aiChatModelPickerTitle,
      icon: Icons.memory_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.aiChatSettingsService, style: label),
          const SizedBox(height: Space.s),
          ChoicePills<AiProviderId>.single(
            options: [
              for (final s in AiProviderId.values) ChoiceOption(value: s, label: l.aiService(s), icon: aiServiceIcon(s)),
            ],
            selected: p,
            onChanged: (v) {
              if (v != null) {
                _settings.change((s) => s.copyWith(provider: v));
                setState(() => _notice = null);
              }
            },
          ),
          const SizedBox(height: Space.l),
          Text(l.aiChatModelYourList, style: label),
          const SizedBox(height: Space.s),
          for (final id in list)
            _ModelRow(
              id: id,
              label: aiModelLabel(id, displayName: settings.displayNameOf(p, id)),
              selected: id == selected,
              onTap: () => _select(p, id),
              onRemove: list.length > 1 ? () => _settings.change((s) => s.removeModel(p, id)) : null,
            ),
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              MadarButton(
                key: ModelPickerSheet.refreshKey,
                label: l.aiChatModelRefresh,
                icon: Icons.sync_rounded,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.secondary,
                loading: _refreshing,
                onPressed: _refreshing ? null : () => _refresh(p),
              ),
              MadarButton(
                label: l.aiChatModelReset,
                icon: Icons.restart_alt_rounded,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.ghost,
                onPressed: () => _settings.change((s) => s.resetModels(p)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.xs),
            child: Text(
              l.aiChatModelRefreshNote(l.aiService(p)),
              style: text.bodySmall!.copyWith(color: t.textTertiary),
            ),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            alignment: AlignmentDirectional.topStart,
            child: _notice == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.s),
                    child: Text(
                      _notice!,
                      style: text.bodySmall!.copyWith(color: _noticeOk ? t.success : t.danger),
                    ),
                  ),
          ),
          if (fetched.isNotEmpty) ...[
            const SizedBox(height: Space.l),
            Text(l.aiChatModelsAvailable(l.aiService(p)), style: label),
            const SizedBox(height: Space.s),
            for (final m in fetched.take(40))
              _ModelRow(
                id: m.id,
                label: aiModelLabel(m.id, displayName: m.displayName),
                selected: false,
                onTap: () => _select(p, m.id),
              ),
          ],
          const SizedBox(height: Space.l),
          Text(l.aiChatModelCustom, style: label),
          const SizedBox(height: Space.s),
          Row(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    key: ModelPickerSheet.customFieldKey,
                    controller: _custom,
                    autocorrect: false,
                    enableSuggestions: false,
                    maxLength: AiSettings.maxModelIdLength,
                    style: text.bodyLarge!.copyWith(color: t.textPrimary),
                    cursorColor: t.accent,
                    onChanged: (_) {
                      if (_invalid) setState(() => _invalid = false);
                    },
                    onSubmitted: (_) => _useCustom(p),
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      labelText: l.aiChatModelCustomField,
                      hintText: l.aiChatModelCustomHint,
                      errorText: _invalid ? l.aiChatModelInvalid : null,
                      filled: true,
                      fillColor: t.glassFill,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radiusM)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(t.radiusM),
                        borderSide: BorderSide(color: t.glassBorder),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.s),
              MadarButton(
                key: ModelPickerSheet.customUseKey,
                label: l.aiChatModelUse,
                size: MadarButtonSize.medium,
                variant: MadarButtonVariant.secondary,
                onPressed: () => _useCustom(p),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.id, required this.label, required this.selected, required this.onTap, this.onRemove});

  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.xs + 2),
      child: MadarPressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: '$label, $id',
        excludeChildSemantics: true,
        pressScale: 0.985,
        focusRadius: BorderRadius.circular(t.radiusM),
        child: AnimatedContainer(
          duration: context.motion(MadarMotion.short),
          padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.xs, Space.s),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusM),
            color: selected ? t.accent.withValues(alpha: 0.12) : t.glassFill,
            border: Border.all(
              color: selected ? t.accent.withValues(alpha: 0.7) : t.glassBorder.withValues(alpha: 0.6),
              width: selected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 20,
                color: selected ? t.accent : t.textTertiary,
              ),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                    if (label != id)
                      Text(
                        BidiIsolate.ltr(id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall!.copyWith(color: t.textTertiary),
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  tooltip: l.aiChatModelRemove(id),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: t.textTertiary),
                  onPressed: () {
                    Fx.fire(Sfx.delete);
                    onRemove!();
                  },
                )
              else
                const SizedBox(width: Space.m),
            ],
          ),
        ),
      ),
    );
  }
}
