import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../wellbeing_texts.dart';
import '../widgets/wb_widgets.dart';

/// Edits one vocabulary (pain locations, pain triggers or mood factors):
/// drag to reorder, tap to rename (entries follow), long-press or swipe to
/// delete with undo, add at the bottom.
Future<void> showTagManagerSheet(BuildContext context, TagKind kind) =>
    showInteractionSheet<void>(context, builder: (_) => TagManagerSheet(kind: kind));

class TagManagerSheet extends ConsumerWidget {
  const TagManagerSheet({super.key, required this.kind});

  final TagKind kind;

  Future<void> _rename(BuildContext context, WidgetRef ref, TagOptionRow tag) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.wbTagRenameTitle,
      icon: Icons.edit_rounded,
      initial: {'label': tag.label},
      fields: [FieldSpec.text('label', l.wbTagName, required: true, autofocus: true, maxLength: 40)],
    );
    final value = (result?['label'] as String?)?.trim();
    if (value == null || value.isEmpty || value == tag.label) return;
    await ref.read(wellbeingServiceProvider).renameTag(tag.id, value);
  }

  Future<UndoableAction?> _delete(BuildContext context, WidgetRef ref, TagOptionRow tag) async {
    final l = L10n.of(context);
    final undo = await ref.read(wellbeingServiceProvider).deleteTag(tag.id);
    return wbUndo(l.wbTagDeleted(BidiIsolate.isolate(tag.label)), undo);
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.wbTagAddTitle(WbTexts.of(context).tagKindName(kind)),
      icon: Icons.add_rounded,
      fields: [FieldSpec.text('label', l.wbTagName, required: true, autofocus: true, maxLength: 40)],
      saveLabel: l.wbAdd,
    );
    final value = (result?['label'] as String?)?.trim();
    if (value == null || value.isEmpty) return;
    await ref.read(wellbeingServiceProvider).addTag(kind, value);
    Fx.fire(Sfx.complete);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final tags = ref.watch(wellbeingTagsProvider(kind)).value ?? const <TagOptionRow>[];
    return InteractionSheetFrame(
      title: tx.tagKindName(kind),
      subtitle: l.wbTagManagerSubtitle,
      icon: Icons.tune_rounded,
      bodyPadding: const EdgeInsetsDirectional.fromSTEB(0, Space.s, 0, Space.l),
      footer: MadarButton(
        label: l.wbTagAdd,
        icon: Icons.add_rounded,
        expand: true,
        variant: MadarButtonVariant.secondary,
        sfx: Sfx.sheetOpen,
        onPressed: () => _add(context, ref),
      ),
      body: tags.isEmpty
          ? Padding(padding: const EdgeInsets.all(Space.gutter), child: WbHint(l.wbTagEmpty))
          : ReorderableGlassList<TagOptionRow>(
              items: tags,
              itemKey: (tag) => tag.id,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter, vertical: Space.xs),
              spacing: Space.xs,
              animateEntrance: false,
              onReorder: (order) => ref.read(wellbeingServiceProvider).reorderTags([for (final o in order) o.id]),
              itemBuilder: (context, tag, index, grip) => ActionableItem(
                semanticLabel: tag.label,
                borderRadius: BorderRadius.circular(t.radiusM),
                onTap: () => _rename(context, ref, tag),
                actions: ItemActions(
                  onEdit: () => _rename(context, ref, tag),
                  onDelete: () => _delete(context, ref, tag),
                ),
                quickActions: [
                  QuickAction(
                    icon: Icons.delete_outline_rounded,
                    label: l.wbDelete,
                    tone: ActionTone.danger,
                    onPressed: () => _delete(context, ref, tag),
                  ),
                ],
                child: GlassCard(
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs, Space.xs, Space.xs),
                  borderRadius: BorderRadius.circular(t.radiusM),
                  glow: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(tag.label, style: text.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      grip,
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
