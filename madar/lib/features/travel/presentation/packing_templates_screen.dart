import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/sound/sound_api.dart';
import '../data/travel_providers.dart';
import '../domain/packing.dart';
import '../travel_texts.dart';
import 'travel_actions.dart';
import 'widgets/travel_widgets.dart';

/// Packing templates manager as a page of its own.
class PackingTemplatesScreen extends ConsumerWidget {
  const PackingTemplatesScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return MadarScaffold(
      title: l.travelTemplatesTitle,
      backdropSeed: 5.3,
      animateBackdrop: animateBackdrop,
      floatingAction: MadarButton.icon(
        icon: Icons.add_rounded,
        semanticLabel: l.travelAddTemplate,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => TravelActions.addTemplate(context, ref),
      ),
      body: const PackingTemplatesView(),
    );
  }
}

/// The templates list (reorderable; tap to edit, long-press for rename /
/// duplicate / delete with undo). Empty: an invitation and generic starter
/// lists.
class PackingTemplatesView extends ConsumerWidget {
  const PackingTemplatesView({super.key, this.bottomPadding = 120});

  final double bottomPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final templates = ref.watch(travelTemplatesProvider).value;
    if (templates == null) return const Center(child: OrbitLoader(size: 36));
    if (templates.isEmpty) {
      return ListView(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, bottomPadding),
        children: [
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.travelTemplatesEmptyTitle,
            body: l.travelTemplatesEmptyBody,
            actionLabel: l.travelTemplatesStarter,
            actionIcon: Icons.auto_awesome_rounded,
            onAction: () => TravelActions.addStarterTemplates(context, ref),
          ),
        ],
      );
    }
    return ReorderableGlassList<PackingTemplateRow>(
      items: templates,
      itemKey: (t) => t.id,
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bottomPadding),
      onReorder: (order) => unawaited(ref.read(travelServiceProvider).reorderTemplates([for (final t in order) t.id])),
      itemBuilder: (context, t, index, handle) => ActionableItem(
        key: ValueKey(t.id),
        onTap: () => TravelActions.openTemplate(context, t.id),
        // No semanticLabel: the row's own texts say it once (a title-only label
        // made screen readers read the title twice).
        actions: ItemActions(
          onEdit: () => TravelActions.openTemplate(context, t.id),
          onDuplicate: () => TravelActions.duplicateTemplate(context, ref, t),
          onDelete: () => TravelActions.deleteTemplate(context, ref, t),
          extra: [
            ItemAction(
              icon: Icons.drive_file_rename_outline_rounded,
              label: l.travelTemplateRename,
              onSelected: () => TravelActions.renameTemplate(context, ref, t),
            ),
          ],
        ),
        swipeEnabled: false,
        child: TemplateTile(template: t, dragHandle: handle),
      ),
    );
  }
}

/// A template row: icon, name, item count and the first items.
class TemplateTile extends StatelessWidget {
  const TemplateTile({super.key, required this.template, this.dragHandle, this.trailing});

  final PackingTemplateRow template;
  final Widget? dragHandle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final items = PackingTemplateMath.decodeAll(template.items);
    final categories = {for (final i in items) PackingCategories.of(i.category)}.take(4).toList();
    return GlassCard(
      glow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusM),
              color: t.accent.withValues(alpha: t.isDark ? 0.16 : 0.1),
              border: Border.all(color: t.accent.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.luggage_rounded, color: t.accent, size: 22),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(tx.templateItems(items.length), style: text.bodySmall!.copyWith(color: t.gold)),
                    const SizedBox(width: Space.s),
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: Space.xs),
                        child: Icon(categoryIcon(c), size: 14, color: t.textTertiary),
                      ),
                  ],
                ),
                if (items.isNotEmpty)
                  Text(
                    items.take(4).map((i) => i.body).join(tx.l.interactionListSeparator),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: t.textSecondary),
                  ),
              ],
            ),
          ),
          ?trailing,
          dragHandle ?? const SizedBox(width: Space.s),
        ],
      ),
    );
  }
}

/// Edits one template: rename, add items (with a category), reorder by
/// dragging, edit, and delete with undo.
class PackingTemplateScreen extends ConsumerStatefulWidget {
  const PackingTemplateScreen({super.key, required this.templateId, this.animateBackdrop = true});

  final String templateId;
  final bool animateBackdrop;

  @override
  ConsumerState<PackingTemplateScreen> createState() => _PackingTemplateScreenState();
}

class _PackingTemplateScreenState extends ConsumerState<PackingTemplateScreen> {
  final _input = TextEditingController();
  String _category = PackingCategories.misc;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _save(PackingTemplateRow t, List<PackingTemplateItem> items) async {
    await TravelActions.setTemplateItems(ref, t, items);
  }

  Future<void> _add(PackingTemplateRow t) async {
    final body = _input.text.trim();
    if (body.isEmpty) return;
    Fx.fire(Sfx.drop);
    _input.clear();
    final items = PackingTemplateMath.decodeAll(t.items);
    await _save(t, [...items, PackingTemplateItem(body, _category)]);
  }

  Future<void> _pickCategory(List<PackingTemplateItem> items) async {
    final l = L10n.of(context);
    final target = await showMoveSheet(
      context,
      title: l.travelFieldCategory,
      icon: Icons.category_rounded,
      targets: [
        for (final o in TravelActions.categoryOptions(context, custom: items.map((i) => PackingCategories.of(i.category))))
          MoveTarget(id: o.id, label: o.label, icon: o.icon, isCurrent: o.id == _category),
      ],
    );
    if (target != null && mounted) setState(() => _category = target.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = TravelTexts.of(context);
    final text = Theme.of(context).textTheme;
    final async = ref.watch(travelTemplateProvider(widget.templateId));
    final template = async.value;
    if (template == null) {
      // Loaded and gone (a deleted list's old search hit or link): say so
      // instead of loading forever.
      final gone = async.hasValue || async.hasError;
      return MadarScaffold(
        title: l.travelTemplatesTitle,
        animateBackdrop: widget.animateBackdrop,
        body: Center(
          child: gone
              ? AnimatedEmptyState(kind: EmptyStateKind.noResults, title: l.travelTemplateNotFound, body: '')
              : const OrbitLoader(size: 36),
        ),
      );
    }
    final items = PackingTemplateMath.decodeAll(template.items);
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];

    final addRow = GlassCard(
      glow: false,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.xs, Space.xs, Space.xs),
      child: Row(
        children: [
          MadarPressable(
            onTap: () => _pickCategory(items),
            sfx: Sfx.sheetOpen,
            semanticLabel: l.travelAddItemIn(tx.category(_category)),
            // A 48 dp target (Android), the icon centred in it.
            child: SizedBox.square(
              dimension: 48,
              child: Center(child: Icon(categoryIcon(_category), color: t.accent, size: 22)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _input,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _add(template),
              decoration: kitInputDecoration(context, hint: l.travelAddItemTo(tx.category(_category))).copyWith(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: text.bodyMedium!.copyWith(color: t.textTertiary),
              ),
            ),
          ),
          MadarButton.icon(
            icon: Icons.add_rounded,
            semanticLabel: l.travelAddItem,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.primary,
            sfx: Sfx.tap,
            onPressed: () => _add(template),
          ),
        ],
      ),
    );

    return MadarScaffold(
      title: template.name,
      backdropSeed: 5.7,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        MadarButton.icon(
          icon: Icons.drive_file_rename_outline_rounded,
          semanticLabel: l.travelTemplateRename,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () async {
            final action = await TravelActions.renameTemplate(context, ref, template);
            if (action != null && context.mounted) unawaited(showUndoToast(context, action));
          },
        ),
      ],
      body: ReorderableGlassList<(int, PackingTemplateItem)>(
        items: indexed,
        itemKey: (e) => '${e.$1}:${e.$2.encode()}',
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
        header: Padding(
          padding: const EdgeInsetsDirectional.only(bottom: Space.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                items.isEmpty ? l.travelTemplateEmptyItems : tx.templateItems(items.length),
                style: text.bodyMedium!.copyWith(color: items.isEmpty ? t.textSecondary : t.gold),
              ),
              const SizedBox(height: Space.m),
              addRow,
            ],
          ),
        ),
        onReorder: (order) => unawaited(_save(template, [for (final e in order) e.$2])),
        itemBuilder: (context, e, index, handle) {
          final item = e.$2;
          return ActionableItem(
            key: ValueKey('${e.$1}:${item.encode()}'),
            // No semanticLabel: the row's own texts say it once (a title-only label
            // made screen readers read the title twice).
            onTap: () => _editItem(template, items, e.$1),
            actions: ItemActions(
              onEdit: () => _editItem(template, items, e.$1),
              onDelete: () async {
                final service = ref.read(travelServiceProvider);
                final before = template;
                await _save(template, [...items]..removeAt(e.$1));
                return UndoableAction(
                  label: l.travelUndoItemDeleted,
                  undo: () => service.repos.packingTemplates.update(before),
                );
              },
            ),
            swipeEnabled: false,
            child: GlassCard(
              glow: false,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.xs, Space.s),
              child: Row(
                children: [
                  Icon(categoryIcon(PackingCategories.of(item.category)), size: 18, color: t.textTertiary),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.body, style: text.bodyLarge),
                        Text(
                          tx.category(item.category),
                          style: text.labelSmall!.copyWith(color: t.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  handle,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editItem(PackingTemplateRow template, List<PackingTemplateItem> items, int index) async {
    final l = L10n.of(context);
    final item = items[index];
    final r = await showEditSheet(
      context,
      title: l.travelItemEditTitle,
      icon: Icons.luggage_rounded,
      fields: [
        FieldSpec.text(
          'body',
          l.travelFieldItem,
          required: true,
          validator: (v, _) => (v as String?)?.trim().isEmpty ?? true ? l.travelItemRequired : null,
        ),
        FieldSpec.singleSelect(
          'category',
          l.travelFieldCategory,
          options: TravelActions.categoryOptions(
            context,
            extra: item.category,
            custom: items.map((i) => PackingCategories.of(i.category)),
          ),
        ),
      ],
      initial: {'body': item.body, 'category': PackingCategories.of(item.category)},
    );
    if (r == null || !mounted) return;
    final next = [...items];
    next[index] = PackingTemplateItem((r['body'] as String?)?.trim() ?? item.body, r['category'] as String?);
    final before = template;
    final service = ref.read(travelServiceProvider);
    await _save(template, next);
    if (mounted) {
      unawaited(
        showUndoToast(
          context,
          UndoableAction(
            label: l.travelUndoSaved,
            undo: () => service.repos.packingTemplates.update(before),
          ),
        ),
      );
    }
  }
}

/// Picks one or more templates to merge into a trip. Returns the chosen
/// templates in list order, or null.
Future<List<PackingTemplateRow>?> showTemplatePickerSheet(
  BuildContext context, {
  required List<PackingTemplateRow> templates,
}) => showInteractionSheet<List<PackingTemplateRow>>(
  context,
  builder: (_) => TemplatePickerSheet(templates: templates),
);

class TemplatePickerSheet extends ConsumerStatefulWidget {
  const TemplatePickerSheet({super.key, required this.templates});

  final List<PackingTemplateRow> templates;

  @override
  ConsumerState<TemplatePickerSheet> createState() => _TemplatePickerSheetState();
}

class _TemplatePickerSheetState extends ConsumerState<TemplatePickerSheet> {
  final Set<String> _picked = {};

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final templates = widget.templates;
    return InteractionSheetFrame(
      title: l.travelPickTemplatesTitle,
      subtitle: l.travelPickTemplatesHint,
      icon: Icons.playlist_add_rounded,
      body: templates.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedEmptyState(
                  kind: EmptyStateKind.emptyList,
                  title: l.travelTemplatesEmptyTitle,
                  body: l.travelTemplatesEmptyBody,
                  illustrationSize: 100,
                  actionLabel: l.travelTemplatesStarter,
                  actionIcon: Icons.auto_awesome_rounded,
                  onAction: () async {
                    await TravelActions.addStarterTemplates(context, ref);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tpl in templates)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                    child: MadarPressable(
                      onTap: () => setState(() {
                        if (!_picked.remove(tpl.id)) _picked.add(tpl.id);
                      }),
                      sfx: _picked.contains(tpl.id) ? Sfx.toggleOff : Sfx.toggleOn,
                      toggled: _picked.contains(tpl.id),
                      semanticLabel: tpl.name,
                      excludeChildSemantics: true,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(t.radiusM),
                          border: Border.all(
                            color: _picked.contains(tpl.id) ? t.accent : Colors.transparent,
                            width: 1.4,
                          ),
                        ),
                        child: TemplateTile(
                          template: tpl,
                          trailing: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s),
                            child: Icon(
                              _picked.contains(tpl.id) ? Icons.check_circle_rounded : Icons.circle_outlined,
                              color: _picked.contains(tpl.id) ? t.accent : t.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      footer: templates.isEmpty
          ? null
          : SheetButton(
              label: l.travelPickTemplatesAdd,
              primary: true,
              enabled: _picked.isNotEmpty,
              icon: Icons.playlist_add_check_rounded,
              onPressed: () => Navigator.of(context).pop([
                for (final tpl in templates)
                  if (_picked.contains(tpl.id)) tpl,
              ]),
            ),
    );
  }
}
