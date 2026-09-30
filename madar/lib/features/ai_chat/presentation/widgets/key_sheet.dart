import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/ai_chat_providers.dart';
import '../../data/key_store.dart';
import '../../data/transport.dart';
import '../../domain/ai_models.dart';
import '../ai_labels.dart';

/// Paste / replace / delete / test the key of [provider]. The key is shown
/// only as its last four characters; the field is obscured, without
/// suggestions or keyboard learning, and cleared when the sheet closes.
Future<void> showAiKeySheet(BuildContext context, AiProviderId provider) =>
    showInteractionSheet<void>(context, builder: (_) => AiKeySheet(provider: provider));

/// Where each service hands out keys (opened only on tap).
const Map<AiProviderId, String> aiKeyConsoleUrls = {
  AiProviderId.anthropic: 'https://platform.claude.com/settings/keys',
  AiProviderId.openai: 'https://platform.openai.com/api-keys',
};

class AiKeySheet extends ConsumerStatefulWidget {
  const AiKeySheet({super.key, required this.provider});

  final AiProviderId provider;

  static const Key fieldKey = ValueKey('ai-key-field');
  static const Key saveKey = ValueKey('ai-key-save');
  static const Key testKey = ValueKey('ai-key-test');
  static const Key deleteKey = ValueKey('ai-key-delete');
  static const Key pasteKey = ValueKey('ai-key-paste');

  @override
  ConsumerState<AiKeySheet> createState() => _AiKeySheetState();
}

class _AiKeySheetState extends ConsumerState<AiKeySheet> {
  final _field = TextEditingController();
  bool _busy = false;
  String? _notice;
  bool _noticeOk = true;
  AiKeyProblem? _problem;
  AiCancelToken? _cancel;

  AiProviderId get _p => widget.provider;

  @override
  void dispose() {
    _cancel?.cancel();
    _field.clear();
    _field.dispose();
    super.dispose();
  }

  String _problemText(L10n l, AiKeyProblem p) => switch (p) {
    AiKeyProblem.empty => l.aiChatKeyProblemEmpty,
    AiKeyProblem.tooShort => l.aiChatKeyProblemShort,
    AiKeyProblem.spaces => l.aiChatKeyProblemSpaces,
    AiKeyProblem.wrongProvider => l.aiChatKeyProblemProvider,
  };

  void _say(String text, {bool ok = true}) {
    if (!mounted) return;
    setState(() {
      _notice = text;
      _noticeOk = ok;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    _field.text = AiKeyStore.clean(text);
    _field.selection = TextSelection.collapsed(offset: _field.text.length);
    setState(() {
      _problem = null;
      _notice = null;
    });
  }

  Future<void> _save() async {
    final l = L10n.of(context);
    final key = AiKeyStore.clean(_field.text);
    final problem = AiKeyStore.check(_p, key);
    if (problem != null && problem != AiKeyProblem.wrongProvider) {
      Fx.fire(Sfx.error);
      setState(() => _problem = problem);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(aiKeyHintsProvider.notifier).save(_p, key);
      _field.clear();
      Fx.fire(Sfx.complete);
      setState(() {
        _busy = false;
        _problem = problem; // a provider mismatch stays visible as a warning
      });
      _say(l.aiChatKeySavedNotice);
    } catch (_) {
      Fx.fire(Sfx.error);
      setState(() => _busy = false);
      _say(l.aiChatErrorUnknown, ok: false);
    }
  }

  Future<void> _test() async {
    final l = L10n.of(context);
    final model = ref.read(aiSettingsProvider).value?.modelFor(_p) ?? '';
    setState(() {
      _busy = true;
      _notice = null;
    });
    final cancel = _cancel = AiCancelToken();
    try {
      await testAiKey(ref, _p, cancel: cancel);
      if (!mounted) return;
      Fx.fire(Sfx.complete);
      setState(() => _busy = false);
      _say(l.aiChatKeyTestOk);
    } on AiCancelledException {
      return;
    } on AiException catch (e) {
      if (!mounted) return;
      Fx.fire(Sfx.error);
      setState(() => _busy = false);
      _say(l.aiError(e.kind, provider: _p, model: model), ok: false);
    }
  }

  Future<void> _delete() async {
    final l = L10n.of(context);
    final undo = await ref.read(aiKeyHintsProvider.notifier).delete(_p);
    if (!mounted) return;
    setState(() {
      _notice = null;
      _problem = null;
    });
    if (undo != null) {
      showUndoToast(context, UndoableAction(label: l.aiChatKeyDeleted, undo: undo));
    }
  }

  Future<void> _openConsole() async {
    Fx.fire(Sfx.navigate);
    try {
      await launchUrl(Uri.parse(aiKeyConsoleUrls[_p]!), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final hint = ref.watch(aiKeyHintsProvider).value?[_p];
    final service = l.aiService(_p);
    final saved = hint != null;

    return InteractionSheetFrame(
      title: l.aiChatKeyTitle(service),
      subtitle: l.aiChatKeySheetSubtitle,
      icon: Icons.key_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassCard(
            glow: false,
            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
            child: Row(
              children: [
                Icon(saved ? Icons.lock_rounded : Icons.lock_open_rounded, size: 18, color: saved ? t.success : t.textTertiary),
                const SizedBox(width: Space.m),
                Expanded(child: Text(l.aiChatKeyCurrent, style: text.titleSmall!.copyWith(color: t.textPrimary))),
                Text(
                  saved ? BidiIsolate.ltr('••••$hint') : l.aiChatKeyNotSet,
                  key: const ValueKey('ai-key-mask'),
                  style: text.labelLarge!.copyWith(
                    color: saved ? t.textPrimary : t.textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: saved ? 1 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              key: AiKeySheet.fieldKey,
              controller: _field,
              obscureText: true,
              obscuringCharacter: '•',
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.visiblePassword,
              autofillHints: const <String>[],
              maxLines: 1,
              style: text.bodyLarge!.copyWith(color: t.textPrimary),
              cursorColor: t.accent,
              onChanged: (_) {
                if (_problem != null || _notice != null) {
                  setState(() {
                    _problem = null;
                    _notice = null;
                  });
                }
              },
              decoration: InputDecoration(
                labelText: l.aiChatKeyField,
                hintText: l.aiChatKeyFieldHint,
                filled: true,
                fillColor: t.glassFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(t.radiusM)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.radiusM),
                  borderSide: BorderSide(color: t.glassBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.radiusM),
                  borderSide: BorderSide(color: t.accent, width: 1.4),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: Space.xs),
                  child: TextButton.icon(
                    key: AiKeySheet.pasteKey,
                    onPressed: _busy ? null : _paste,
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: Text(l.aiChatKeyPaste),
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            alignment: AlignmentDirectional.topStart,
            child: _problem == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.s, start: Space.xs),
                    child: Text(
                      _problemText(l, _problem!),
                      style: text.bodySmall!.copyWith(
                        color: _problem == AiKeyProblem.wrongProvider ? t.warning : t.danger,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: Space.m),
          Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              MadarButton(
                key: AiKeySheet.testKey,
                label: l.aiChatKeyTest,
                icon: Icons.wifi_tethering_rounded,
                size: MadarButtonSize.small,
                variant: MadarButtonVariant.secondary,
                loading: _busy && saved && _field.text.isEmpty,
                onPressed: saved && !_busy ? _test : null,
              ),
              if (saved)
                MadarButton(
                  key: AiKeySheet.deleteKey,
                  label: l.aiChatKeyDelete,
                  icon: Icons.delete_outline_rounded,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.ghost,
                  sfx: Sfx.delete,
                  onPressed: _busy ? null : _delete,
                ),
            ],
          ),
          if (saved)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.s),
              child: Text(l.aiChatKeyTestNote, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.4)),
            ),
          AnimatedSize(
            duration: context.motion(MadarMotion.short),
            alignment: AlignmentDirectional.topStart,
            child: _notice == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.m),
                    child: Semantics(
                      liveRegion: true,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _noticeOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                            size: 18,
                            color: _noticeOk ? t.success : t.danger,
                          ),
                          const SizedBox(width: Space.s),
                          Expanded(
                            child: Text(_notice!, style: text.bodyMedium!.copyWith(color: t.textPrimary, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: Space.l),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _openConsole,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(l.aiChatKeyWhere),
            ),
          ),
          Text(l.aiChatPrivacyKeys, style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.45)),
        ],
      ),
      footer: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _field,
        builder: (context, value, _) => SheetButton(
          key: AiKeySheet.saveKey,
          label: saved ? l.aiChatKeyReplace : l.aiChatKeySave,
          icon: Icons.lock_rounded,
          primary: true,
          enabled: !_busy && value.text.trim().isNotEmpty,
          onPressed: _save,
        ),
      ),
    );
  }
}
