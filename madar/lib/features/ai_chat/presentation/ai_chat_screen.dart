import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../data/ai_chat_providers.dart';
import '../data/key_store.dart';
import '../domain/ai_models.dart';
import '../domain/ai_settings.dart';
import '../domain/conversation.dart';
import 'ai_chat_list_screen.dart';
import 'ai_labels.dart';
import 'ai_settings_screen.dart';
import 'chat_controller.dart';
import 'widgets/composer.dart';
import 'widgets/key_sheet.dart';
import 'widgets/markdown_view.dart';
import 'widgets/message_bubble.dart';
import 'widgets/model_sheet.dart';
import 'widgets/payload_sheet.dart';
import 'widgets/setup_card.dart';
import 'widgets/will_send_sheet.dart';
import 'widgets/will_send_strip.dart';

/// The conversation. A call happens only when the user taps Send (or
/// Regenerate / Try again): the first Send of a conversation opens the
/// summary preview so the user sees and trims exactly what is shared; after
/// that the "will send" strip above the field always shows what goes out.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({
    super.key,
    this.conversationId,
    this.initialDraft,
    this.onOpenSettings,
    this.onOpenList,
    this.onOpenLink,
  });

  /// A stored conversation (null = a new chat).
  final String? conversationId;

  /// Text typed into the field (never sent by itself).
  final String? initialDraft;

  /// Defaults to pushing [AiSettingsScreen].
  final VoidCallback? onOpenSettings;

  /// Defaults to pushing [AiChatListScreen].
  final VoidCallback? onOpenList;

  /// Opens a tapped link in a reply (defaults to url_launcher).
  final MdLinkOpener? onOpenLink;

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  late ChatController _chat;
  late final TextEditingController _input = TextEditingController(text: widget.initialDraft);
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String? _notice;
  Timer? _noticeTimer;

  @override
  void initState() {
    super.initState();
    _chat = _newController(widget.conversationId);
    _input.addListener(_onDraft);
  }

  ChatController _newController(String? id) {
    final c = ChatController(
      store: ref.read(conversationStoreProvider),
      providers: ref.read(aiProviderRegistryProvider),
      keys: ref.read(aiKeyStoreProvider),
      clock: ref.read(aiClockProvider),
      newId: ref.read(aiIdProvider),
      conversationId: id,
    );
    unawaited(c.load());
    return c;
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _chat.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onDraft() {
    // The strip's counts follow the draft.
    if (mounted) setState(() {});
  }

  String get _lang => Localizations.localeOf(context).languageCode;

  AiSettings get _settings => ref.read(aiSettingsProvider).value ?? const AiSettings();

  void _say(String text) {
    _noticeTimer?.cancel();
    setState(() => _notice = text);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  // ------------------------------------------------------------ actions --

  /// The saved settings are loaded (until then Send would use defaults –
  /// maybe another service than the one the user chose).
  bool get _settingsReady => ref.read(aiSettingsProvider).hasValue;

  /// First call of a conversation (or after "No personal context" was
  /// switched off): the user sees exactly what is shared and can trim it.
  /// False when they dismissed the preview.
  Future<bool> _decideContext() async {
    final l = L10n.of(context);
    final markdown = await ref.read(aiContextPickerProvider)(context, andSend: true);
    if (!mounted) return false;
    if (markdown == null || markdown.trim().isEmpty) {
      _say(l.aiChatContextCancelled);
      return false;
    }
    _chat.setContext(ChatContext.personal(markdown, approvedAt: ref.read(aiClockProvider)()));
    return true;
  }

  Future<void> _send() async {
    if (!_settingsReady) return;
    final settings = _settings;
    final hints = ref.read(aiKeyHintsProvider).value ?? const {};
    final text = _input.text;
    switch (_chat.blockFor(text, hasKey: hints[settings.provider] != null)) {
      case SendBlock.empty || SendBlock.busy:
        return;
      case SendBlock.noKey:
        await showAiKeySheet(context, settings.provider);
        return;
      case SendBlock.needsContext:
        if (!await _decideContext()) return;
      case null:
        break;
    }
    final ok = await _chat.send(text, settings: settings, languageCode: _lang);
    if (!mounted) return;
    if (!ok) {
      // The key went missing since the screen last looked.
      if (_chat.lastError?.kind == AiErrorKind.noKey) {
        ref.invalidate(aiKeyHintsProvider);
        await showAiKeySheet(context, settings.provider);
      }
      return;
    }
    _input.clear();
    setState(() => _notice = null);
    if (_scroll.hasClients) {
      unawaited(_scroll.animateTo(0, duration: context.motion(MadarMotion.medium), curve: MadarMotion.standard));
    }
  }

  Future<void> _regenerate() async {
    if (!_settingsReady || _chat.busy) return;
    final settings = _settings;
    final hints = ref.read(aiKeyHintsProvider).value ?? const {};
    if (hints[settings.provider] == null) {
      await showAiKeySheet(context, settings.provider);
      return;
    }
    // Never a silent no-op: an undecided context is decided first.
    if (!_chat.conversation.context.isDecided && !await _decideContext()) return;
    if (!mounted) return;
    await _chat.regenerate(settings: settings, languageCode: _lang);
  }

  Future<void> _chooseSections(BuildContext sheetContext) async {
    final markdown = await ref.read(aiContextPickerProvider)(sheetContext, andSend: false);
    if (markdown == null || markdown.trim().isEmpty || !mounted) return;
    _chat.setContext(ChatContext.personal(markdown, approvedAt: ref.read(aiClockProvider)()));
  }

  Future<void> _viewPayload(BuildContext sheetContext) async {
    final settings = _settings;
    final draft = _input.text.trim();
    final payload = _chat.payloadFor(settings, _lang, draft: draft.isEmpty ? null : draft);
    final hint = ref.read(aiKeyHintsProvider).value?[settings.provider];
    final request = ref
        .read(aiProviderRegistryProvider)[settings.provider]
        .chatRequest(payload.request, apiKey: AiKeyStore.maskHint(hint));
    await showPayloadSheet(sheetContext, request: request, payload: payload, includesDraft: draft.isNotEmpty);
  }

  Future<void> _openWillSend() async {
    final l = L10n.of(context);
    final settings = _settings;
    await showWillSendSheet(
      context,
      controller: _chat,
      payload: () {
        final draft = _input.text.trim();
        return _chat.payloadFor(_settings, _lang, draft: draft.isEmpty ? null : draft);
      },
      serviceModel: l.aiChatServiceModel(l.aiService(settings.provider), aiModelLabel(settings.model)),
      onChooseSections: _chooseSections,
      onViewPayload: _viewPayload,
      clock: ref.read(aiClockProvider),
    );
  }

  void _openSettings() {
    final open = widget.onOpenSettings;
    if (open != null) {
      open();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen()));
  }

  void _openList() {
    final open = widget.onOpenList;
    if (open != null) {
      open();
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AiChatListScreen()));
  }

  Future<void> _addKey(AiProviderId p) async {
    await showAiKeySheet(context, p);
    if (!mounted) return;
    final hints = ref.read(aiKeyHintsProvider).value ?? const {};
    if (hints[p] != null && _settings.provider != p) {
      await ref.read(aiSettingsProvider.notifier).change((s) => s.copyWith(provider: p));
    }
  }

  void _newChat() {
    if (_chat.conversation.isEmpty) return;
    final old = _chat;
    setState(() => _chat = _newController(null));
    old.dispose();
  }

  Future<void> _rename() async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.aiChatRename,
      icon: Icons.edit_rounded,
      saveLabel: l.aiChatRenameSave,
      fields: [FieldSpec.text('title', l.aiChatRenameField, required: true, maxLength: Conversation.maxTitleChars)],
      initial: {'title': _chat.conversation.title},
    );
    final title = result?['title'];
    if (title is String && mounted) _chat.rename(title);
  }

  Future<void> _delete() async {
    final l = L10n.of(context);
    final store = ref.read(conversationStoreProvider);
    final id = _chat.conversation.id;
    await _chat.discard();
    final removed = await store.delete(id);
    if (!mounted) return;
    Fx.fire(Sfx.delete);
    if (removed != null) {
      showUndoToast(context, UndoableAction(label: l.aiChatDeleted, undo: () => store.restore([removed])));
    }
    await Navigator.of(context).maybePop();
  }

  Future<void> _more() async {
    final l = L10n.of(context);
    final saved = !_chat.conversation.isEmpty;
    await showInteractionSheet<void>(
      context,
      builder: (sheet) => InteractionSheetFrame(
        title: l.aiChatMenu,
        icon: Icons.more_horiz_rounded,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuRow(
              icon: Icons.forum_outlined,
              label: l.aiChatOpenList,
              onTap: () {
                Navigator.of(sheet).pop();
                _openList();
              },
            ),
            _MenuRow(
              icon: Icons.visibility_rounded,
              label: l.aiChatContextTitle,
              onTap: () {
                Navigator.of(sheet).pop();
                _openWillSend();
              },
            ),
            if (saved)
              _MenuRow(
                icon: Icons.edit_rounded,
                label: l.aiChatRename,
                onTap: () {
                  Navigator.of(sheet).pop();
                  _rename();
                },
              ),
            _MenuRow(
              icon: Icons.tune_rounded,
              label: l.aiChatSettingsTitle,
              onTap: () {
                Navigator.of(sheet).pop();
                _openSettings();
              },
            ),
            if (saved)
              _MenuRow(
                icon: Icons.delete_outline_rounded,
                label: l.aiChatDelete,
                danger: true,
                onTap: () {
                  Navigator.of(sheet).pop();
                  _delete();
                },
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final settingsAsync = ref.watch(aiSettingsProvider);
    final settings = settingsAsync.value ?? const AiSettings();
    final settingsReady = settingsAsync.hasValue;
    final hintsAsync = ref.watch(aiKeyHintsProvider);
    final hints = hintsAsync.value;
    final powerSaver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final hasKey = hints?[settings.provider] != null;
    final needsSetup = hints != null && !hasKey;

    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) {
        final conversation = _chat.conversation;
        final title = conversation.title.isEmpty ? l.aiChatTitle : conversation.title;
        final draft = _input.text.trim();
        final payload = _chat.payloadFor(settings, _lang, draft: draft.isEmpty ? null : draft);

        Widget content;
        if (_chat.loading || hints == null) {
          content = const Center(child: OrbitLoader(size: 40));
        } else if (_chat.missing) {
          content = AnimatedEmptyState(kind: EmptyStateKind.noResults, title: l.aiChatListEmptyTitle);
        } else if (needsSetup && conversation.isEmpty) {
          content = ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.l),
            children: [
              AnimatedReveal(
                child: AiKeySetupCard(preferred: settings.provider, onAddKey: _addKey),
              ),
            ],
          );
        } else if (conversation.isEmpty) {
          content = _EmptyChat(
            onSuggestion: (s) {
              _input.text = s;
              _input.selection = TextSelection.collapsed(offset: s.length);
              _focus.requestFocus();
            },
          );
        } else {
          content = _Messages(
            chat: _chat,
            scroll: _scroll,
            onRegenerate: _regenerate,
            onOpenSettings: _openSettings,
            onOpenLink: widget.onOpenLink,
          );
        }

        return MadarScaffold(
          titleWidget: _TitleBlock(
            title: title,
            model: aiModelLabel(settings.model, displayName: settings.displayNameOf(settings.provider, settings.model)),
            onModelTap: _chat.busy ? null : () => showModelPickerSheet(context),
          ),
          actions: [
            MadarButton.icon(
              icon: Icons.add_comment_outlined,
              semanticLabel: l.aiChatNewChat,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.ghost,
              onPressed: conversation.isEmpty || _chat.busy ? null : _newChat,
            ),
            MadarButton.icon(
              icon: Icons.more_horiz_rounded,
              semanticLabel: l.aiChatMenu,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.ghost,
              sfx: Sfx.sheetOpen,
              onPressed: _more,
            ),
          ],
          animateBackdrop: !powerSaver,
          backdropSeed: 0.41,
          backdropIntensity: 0.85,
          body: Column(
            children: [
              Expanded(child: content),
              AnimatedSize(
                duration: context.motion(MadarMotion.short),
                child: _notice == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xs, Space.gutter, 0),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _notice!,
                            textAlign: TextAlign.center,
                            style: text.bodySmall!.copyWith(color: t.textSecondary),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasKey && !_chat.loading) ...[
                      WillSendStrip(
                        chatContext: conversation.context,
                        messageCount: payload.historyCount,
                        approxTokens: payload.approxTokens,
                        omittedCount: payload.omittedCount,
                        onTap: _openWillSend,
                      ),
                      const SizedBox(height: Space.s),
                    ],
                    ChatComposer(
                      controller: _input,
                      focusNode: _focus,
                      busy: _chat.busy,
                      enabled: !_chat.loading && !_chat.missing && settingsReady,
                      onSend: _send,
                      onStop: _chat.stop,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.title, required this.model, required this.onModelTap});

  final String title;
  final String model;
  final VoidCallback? onModelTap;

  static const Key modelChipKey = ValueKey('ai-model-chip');

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium!.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 2),
        MadarPressable(
          key: modelChipKey,
          onTap: onModelTap,
          enabled: onModelTap != null,
          sfx: Sfx.sheetOpen,
          semanticLabel: l.aiChatModelChip(model),
          excludeChildSemantics: true,
          focusRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.s + 2, 2, Space.xs + 2, 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: t.accent.withValues(alpha: 0.1),
              border: Border.all(color: t.accent.withValues(alpha: 0.35), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    model,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall!.copyWith(color: t.accent, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(Icons.expand_more_rounded, size: 14, color: t.accent),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Messages extends StatelessWidget {
  const _Messages({
    required this.chat,
    required this.scroll,
    required this.onRegenerate,
    required this.onOpenSettings,
    this.onOpenLink,
  });

  final ChatController chat;
  final ScrollController scroll;
  final VoidCallback onRegenerate;
  final VoidCallback onOpenSettings;
  final MdLinkOpener? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final messages = chat.conversation.messages;
    final n = messages.length;
    return ListView.builder(
      controller: scroll,
      reverse: true,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      itemCount: n,
      itemBuilder: (context, i) {
        final index = n - 1 - i;
        final m = messages[index];
        final last = index == n - 1;
        return Padding(
          key: ValueKey(m.id),
          padding: EdgeInsetsDirectional.only(top: index == 0 ? 0 : (m.isUser ? Space.l : Space.m)),
          child: MessageBubble(
            message: m,
            streaming: m.id == chat.streamingId,
            canRegenerate: last && chat.canRegenerate,
            onRegenerate: onRegenerate,
            onRetry: last && m.status == MessageStatus.failed && AiException(m.error ?? AiErrorKind.unknown).retryable
                ? onRegenerate
                : null,
            onOpenSettings: onOpenSettings,
            errorDetail: last ? _errorDetail(context, chat.lastError) : null,
            onOpenLink: onOpenLink,
          ),
        );
      },
    );
  }
}

/// The provider's (redacted) words plus "try again in N s" when known.
String? _errorDetail(BuildContext context, AiException? e) {
  if (e == null) return null;
  final wait = e.retryAfter;
  final parts = [
    if (wait != null && wait.inSeconds > 0)
      L10n.of(context).aiChatErrorRetryAfter(context.formatter.formatInt(wait.inSeconds)),
    ?e.detail,
  ];
  return parts.isEmpty ? null : parts.join('\n');
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final suggestions = [l.aiChatSuggestWeek, l.aiChatSuggestPlan, l.aiChatSuggestBudget, l.aiChatSuggestPrayer];
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.xxl, Space.gutter, Space.l),
      children: [
        StaggerIn(
          id: 'ai-chat-empty',
          children: [
            Center(
              child: SizedBox.square(
                dimension: 112,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const GirihRosette(size: 112, folds: 8),
                    IslamicStar(size: 34, color: t.gold, glow: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Space.xl),
            Text(
              l.aiChatEmptyTitle,
              textAlign: TextAlign.center,
              style: text.headlineSmall!.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: Space.s),
            Text(
              l.aiChatEmptyBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.55),
            ),
            const SizedBox(height: Space.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final s in suggestions)
                  MadarChip(label: s, icon: Icons.lightbulb_outline_rounded, onSelected: (_) => onSuggestion(s)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = danger ? t.danger : t.textPrimary;
    return MadarPressable(
      onTap: onTap,
      sfx: danger ? Sfx.tap : Sfx.navigate,
      pressScale: 0.985,
      semanticLabel: label,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.m, horizontal: Space.xs),
        child: Row(
          children: [
            Icon(icon, size: 20, color: danger ? t.danger : t.accent),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}
