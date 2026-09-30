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
import '../data/conversation_store.dart';
import '../domain/conversation.dart';
import 'ai_chat_screen.dart';
import 'ai_settings_screen.dart';

/// Stored conversations, newest first: open, rename, delete one (with
/// undo) or all.
class AiChatListScreen extends ConsumerWidget {
  const AiChatListScreen({super.key, this.onOpenConversation, this.onOpenSettings});

  /// Opens a conversation (null id = a new chat). Defaults to pushing
  /// [AiChatScreen].
  final ValueChanged<String?>? onOpenConversation;

  /// Defaults to pushing [AiSettingsScreen].
  final VoidCallback? onOpenSettings;

  void _open(BuildContext context, String? id) {
    final open = onOpenConversation;
    if (open != null) {
      open(id);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AiChatScreen(conversationId: id)));
  }

  Future<UndoableAction?> _delete(BuildContext context, WidgetRef ref, String id) async {
    final l = L10n.of(context);
    final store = ref.read(conversationStoreProvider);
    final removed = await store.delete(id);
    if (removed == null) return null;
    return UndoableAction(label: l.aiChatDeleted, undo: () => store.restore([removed]));
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final store = ref.read(conversationStoreProvider);
    final removed = await store.deleteAll();
    if (removed.isEmpty || !context.mounted) return;
    Fx.fire(Sfx.delete);
    showUndoToast(context, UndoableAction(label: l.aiChatDeletedAll, undo: () => store.restore(removed)));
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, ConversationMeta m) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.aiChatRename,
      icon: Icons.edit_rounded,
      saveLabel: l.aiChatRenameSave,
      fields: [FieldSpec.text('title', l.aiChatRenameField, required: true, maxLength: Conversation.maxTitleChars)],
      initial: {'title': m.title},
    );
    final title = result?['title'];
    if (title is String) await ref.read(conversationStoreProvider).rename(m.id, title);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final text = Theme.of(context).textTheme;
    final index = ref.watch(conversationIndexProvider);
    final powerSaver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final list = index.value ?? const <ConversationMeta>[];
    final now = ref.watch(aiClockProvider)();

    String when(DateTime d) {
      final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
      if (days <= 0) return fmt.formatTime(d);
      if (days == 1) return l.aiChatYesterday;
      return fmt.formatDate(d, style: days < 300 ? MadarDateStyle.dayMonth : MadarDateStyle.medium);
    }

    Widget body;
    if (!index.hasValue) {
      body = const Center(child: OrbitLoader(size: 40));
    } else if (list.isEmpty) {
      body = Center(
        child: AnimatedEmptyState(
          kind: EmptyStateKind.emptyList,
          title: l.aiChatListEmptyTitle,
          body: l.aiChatListEmptyBody,
          actionLabel: l.aiChatNewChat,
          actionIcon: Icons.add_comment_outlined,
          onAction: () => _open(context, null),
        ),
      );
    } else {
      body = ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
        children: [
          for (final (i, m) in list.indexed)
            Padding(
              key: ValueKey(m.id),
              padding: const EdgeInsetsDirectional.only(bottom: Space.s + 2),
              child: StaggerItem(
                index: i,
                child: ActionableItem(
                  onTap: () => _open(context, m.id),
                  semanticLabel: m.title.isEmpty ? l.aiChatUntitled : m.title,
                  actions: ItemActions(
                    onEdit: () => _rename(context, ref, m),
                    onDelete: () => _delete(context, ref, m.id),
                  ),
                  quickActions: [
                    QuickAction(
                      icon: Icons.edit_rounded,
                      label: l.aiChatRename,
                      onPressed: () async {
                        await _rename(context, ref, m);
                        return null;
                      },
                    ),
                    QuickAction(
                      icon: Icons.delete_outline_rounded,
                      label: l.aiChatDelete,
                      tone: ActionTone.danger,
                      onPressed: () => _delete(context, ref, m.id),
                    ),
                  ],
                  child: GlassCard(
                    seed: i * 0.13,
                    glow: false,
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: t.accent.withValues(alpha: 0.12),
                            border: Border.all(color: t.accent.withValues(alpha: 0.35), width: 0.8),
                          ),
                          child: Icon(Icons.auto_awesome_rounded, size: 18, color: t.accent),
                        ),
                        const SizedBox(width: Space.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                m.title.isEmpty ? l.aiChatUntitled : m.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection: BidiIsolate.directionOf(m.title),
                                style: text.titleSmall!.copyWith(color: t.textPrimary),
                              ),
                              if (m.preview.isNotEmpty)
                                Text(
                                  m.preview,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: BidiIsolate.directionOf(m.preview),
                                  style: text.bodySmall!.copyWith(color: t.textSecondary),
                                ),
                              Text(
                                l.aiChatListUpdated(
                                  when(m.updatedAt),
                                  fmt.localizeDigits(l.aiChatMessagesCount(m.messageCount)),
                                ),
                                style: text.labelSmall!.copyWith(color: t.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: Space.l),
          Center(
            child: MadarButton(
              label: l.aiChatDeleteAll,
              icon: Icons.delete_sweep_outlined,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.ghost,
              sfx: Sfx.tap,
              onPressed: () => _deleteAll(context, ref),
            ),
          ),
          const SizedBox(height: Space.s),
          Text(
            l.aiChatListLimitNote(fmt.formatInt(ConversationStore.maxConversations)),
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(color: t.textTertiary),
          ),
        ],
      );
    }

    return MadarScaffold(
      title: l.aiChatListTitle,
      animateBackdrop: !powerSaver,
      backdropSeed: 0.43,
      actions: [
        MadarButton.icon(
          icon: Icons.tune_rounded,
          semanticLabel: l.aiChatSettingsTitle,
          size: MadarButtonSize.small,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed:
              onOpenSettings ??
              () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AiSettingsScreen())),
        ),
      ],
      floatingAction: list.isEmpty
          ? null
          : MadarButton(
              label: l.aiChatNewChat,
              icon: Icons.add_comment_outlined,
              size: MadarButtonSize.large,
              sfx: Sfx.navigate,
              onPressed: () => _open(context, null),
            ),
      body: EntranceChoreo(id: 'ai-chat-list', child: body),
    );
  }
}
