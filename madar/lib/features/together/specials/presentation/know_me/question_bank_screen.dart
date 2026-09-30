import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/specials_providers.dart';
import '../../data/specials_repository.dart';
import '../../domain/know_me_bank.dart';
import '../../domain/know_me_catalogue.dart';
import '../../domain/specials_bounds.dart';
import '../specials_texts.dart';

/// The question bank of "How well do you know me?": categories along the
/// top, the selected category's questions below – add, reword, move, delete
/// (with undo) and drag to reorder; categories can be added, renamed,
/// given an icon, reordered and deleted; the default questions can be
/// restored at any time.
class QuestionBankScreen extends ConsumerStatefulWidget {
  const QuestionBankScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  ConsumerState<QuestionBankScreen> createState() => _QuestionBankScreenState();
}

class _QuestionBankScreenState extends ConsumerState<QuestionBankScreen> {
  String? _selected;

  SpecialsRepository get _repo => ref.read(specialsRepositoryProvider);

  static Map<String, IconData> get _icons => {
    for (final k in KnowMeCatalogue.iconKeys) k: SpecialsLook.categoryIcon(k),
  };

  Future<void> _undoable(Future<SpecialsUndo> change, String label) async {
    final undo = await change;
    if (!mounted) return;
    unawaited(showUndoToast(context, UndoableAction(label: label, undo: undo)));
  }

  List<SelectOption> _categoryOptions(KnowMeBank bank, SpecialsTexts st) => [
    for (final c in bank.categories)
      SelectOption(id: c.id, label: st.category(c), icon: SpecialsLook.categoryIcon(c.iconKey)),
  ];

  Future<void> _addQuestion(KnowMeBank bank, String categoryId) async {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    if (bank.isFull) {
      Fx.fire(Sfx.error);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l.togetherKnowMeBankFull(st.n(SpecialsBounds.maxQuestions)))),
      );
      return;
    }
    final values = await showEditSheet(
      context,
      title: l.togetherKnowMeAddQuestion,
      icon: Icons.add_comment_rounded,
      fields: [
        FieldSpec.multiline(
          'text',
          l.togetherKnowMeQuestionField,
          required: true,
          hint: l.togetherKnowMeQuestionHint,
          maxLength: SpecialsBounds.maxQuestionLength,
        ),
        FieldSpec.singleSelect('category', l.togetherKnowMeCategoryField, options: _categoryOptions(bank, st), required: true),
      ],
      initial: {'category': categoryId},
    );
    final text = values?['text'];
    final category = values?['category'];
    if (text is! String || category is! String) return;
    final id = SpecialsBounds.newId('q');
    await _repo.updateBank((b) => b.addQuestion(id: id, categoryId: category, text: text));
    if (mounted && category != _selected) setState(() => _selected = category);
  }

  Future<void> _editQuestion(KnowMeBank bank, KnowMeQuestion q) async {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final values = await showEditSheet(
      context,
      title: l.togetherKnowMeEditQuestion,
      icon: Icons.edit_rounded,
      fields: [
        FieldSpec.multiline(
          'text',
          l.togetherKnowMeQuestionField,
          required: true,
          hint: l.togetherKnowMeQuestionHint,
          maxLength: SpecialsBounds.maxQuestionLength,
        ),
        FieldSpec.singleSelect('category', l.togetherKnowMeCategoryField, options: _categoryOptions(bank, st), required: true),
      ],
      initial: {'text': st.question(q), 'category': q.category},
    );
    final text = values?['text'];
    final category = values?['category'];
    if (text is! String || category is! String) return;
    // Unchanged default wording stays the default (and follows the app
    // language).
    final reworded = text.trim() != st.question(q).trim();
    await _repo.updateBank((b) => b.editQuestion(q.id, text: reworded ? text : null, categoryId: category));
  }

  Future<void> _moveQuestion(KnowMeBank bank, KnowMeQuestion q) async {
    final st = SpecialsTexts.of(context);
    final values = await showEditSheet(
      context,
      title: st.l.togetherKnowMeMoveTo,
      icon: Icons.drive_file_move_rounded,
      fields: [
        FieldSpec.singleSelect('category', st.l.togetherKnowMeCategoryField, options: _categoryOptions(bank, st), required: true),
      ],
      initial: {'category': q.category},
    );
    final category = values?['category'];
    if (category is! String || category == q.category) return;
    await _undoable(_repo.updateBank((b) => b.editQuestion(q.id, categoryId: category)), st.tx.l.itemMoved);
  }

  Future<void> _addCategory(KnowMeBank bank) async {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    if (bank.categoriesFull) {
      Fx.fire(Sfx.error);
      return;
    }
    final values = await showEditSheet(
      context,
      title: l.togetherKnowMeAddCategory,
      icon: Icons.create_new_folder_rounded,
      fields: [
        FieldSpec.text(
          'name',
          l.togetherKnowMeCategoryName,
          required: true,
          maxLength: SpecialsBounds.maxCategoryNameLength,
          autofocus: true,
        ),
        FieldSpec.icon('icon', l.togetherKnowMeCategoryIcon, icons: _icons),
      ],
      initial: {'icon': 'star'},
    );
    final name = values?['name'];
    if (name is! String) return;
    final icon = values?['icon'];
    final id = SpecialsBounds.newId('c');
    await _repo.updateBank((b) => b.addCategory(id: id, name: name, icon: icon is String ? icon : ''));
    if (mounted) setState(() => _selected = id);
  }

  Future<void> _editCategory(KnowMeBank bank, KnowMeCategory c) async {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final values = await showEditSheet(
      context,
      title: l.togetherKnowMeEditCategory,
      icon: SpecialsLook.categoryIcon(c.iconKey),
      fields: [
        FieldSpec.text(
          'name',
          l.togetherKnowMeCategoryName,
          required: !c.isDefault,
          maxLength: SpecialsBounds.maxCategoryNameLength,
        ),
        FieldSpec.icon('icon', l.togetherKnowMeCategoryIcon, icons: _icons),
      ],
      initial: {'name': st.category(c), 'icon': c.iconKey},
    );
    if (values == null) return;
    final name = values['name'];
    final icon = values['icon'];
    final unchanged = name is String && name.trim() == st.category(c).trim();
    await _repo.updateBank(
      (b) => b.renameCategory(c.id, unchanged ? c.name : (name is String ? name : ''), icon: icon is String ? icon : null),
    );
  }

  Future<void> _deleteCategory(KnowMeBank bank, KnowMeCategory c) async {
    final st = SpecialsTexts.of(context);
    if (bank.categories.length <= 1) {
      Fx.fire(Sfx.error);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(st.l.togetherKnowMeLastCategory)));
      return;
    }
    final target = bank.categories.firstWhere((x) => x.id != c.id);
    Fx.fire(Sfx.delete);
    setState(() => _selected = target.id);
    await _undoable(
      _repo.updateBank((b) => b.deleteCategory(c.id, moveTo: target.id)),
      st.l.togetherKnowMeCategoryDeleted(st.tx.fmt.isolate(st.category(target))),
    );
  }

  Future<void> _restoreDefaults() async {
    final st = SpecialsTexts.of(context);
    Fx.fire(Sfx.complete);
    await _undoable(_repo.updateBank((b) => b.restoreDefaults()), st.l.togetherKnowMeRestored);
  }

  @override
  Widget build(BuildContext context) {
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final bankAsync = ref.watch(knowMeBankProvider);
    final bank = bankAsync.value;
    final selectedId = bank == null
        ? null
        : (bank.category(_selected ?? '') ?? bank.categories.first).id;
    return MadarScaffold(
      title: l.togetherKnowMeBankTitle,
      backdropSeed: 1.9,
      animateBackdrop: widget.animateBackdrop,
      actions: [
        if (bank != null)
          MadarButton.icon(
            key: const ValueKey('bank-add-category'),
            icon: Icons.create_new_folder_rounded,
            onPressed: bank.categoriesFull ? null : () => unawaited(_addCategory(bank)),
            semanticLabel: l.togetherKnowMeAddCategory,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.sheetOpen,
          ),
        if (bank != null && bank.differsFromDefaults)
          MadarButton.icon(
            key: const ValueKey('bank-restore'),
            icon: Icons.settings_backup_restore_rounded,
            onPressed: () => unawaited(_restoreDefaults()),
            semanticLabel: l.togetherKnowMeRestoreDefaults,
            variant: MadarButtonVariant.ghost,
          ),
      ],
      floatingAction: bank == null
          ? null
          : MadarButton.icon(
              key: const ValueKey('bank-add-question'),
              icon: Icons.add_rounded,
              onPressed: () => unawaited(_addQuestion(bank, selectedId!)),
              semanticLabel: l.togetherKnowMeAddQuestion,
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.large,
              sfx: Sfx.sheetOpen,
            ),
      body: bank == null
          ? const Center(child: OrbitLoader(size: 40))
          : _body(context, bank, bank.category(selectedId!)!),
    );
  }

  Widget _body(BuildContext context, KnowMeBank bank, KnowMeCategory selected) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final l = st.l;
    final text = Theme.of(context).textTheme;
    final questions = bank.questionsIn(selected.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
            children: [
              for (final c in bank.categories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: Space.s),
                  child: Center(
                    child: _CategoryChip(
                      key: ValueKey('bank-cat-${c.id}'),
                      label: st.category(c),
                      count: bank.questionsIn(c.id).length,
                      icon: SpecialsLook.categoryIcon(c.iconKey),
                      selected: c.id == selected.id,
                      onTap: () => setState(() => _selected = c.id),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.s, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      st.category(selected),
                      style: text.titleMedium?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      st.questions(questions.length),
                      style: text.bodySmall?.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              MadarButton.icon(
                key: const ValueKey('bank-edit-category'),
                icon: Icons.edit_rounded,
                onPressed: () => unawaited(_editCategory(bank, selected)),
                semanticLabel: l.togetherKnowMeEditCategory,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
                sfx: Sfx.sheetOpen,
              ),
              MadarButton.icon(
                key: const ValueKey('bank-delete-category'),
                icon: Icons.delete_outline_rounded,
                onPressed: bank.categories.length <= 1 ? null : () => unawaited(_deleteCategory(bank, selected)),
                semanticLabel: l.togetherKnowMeDeleteCategory,
                variant: MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
              ),
            ],
          ),
        ),
        Expanded(
          child: questions.isEmpty
              ? Center(
                  child: AnimatedEmptyState(
                    kind: EmptyStateKind.emptyList,
                    title: l.togetherKnowMeEmptyCategory,
                    body: l.togetherKnowMeQuestionHint,
                    actionLabel: l.togetherKnowMeAddQuestion,
                    actionIcon: Icons.add_rounded,
                    onAction: () => unawaited(_addQuestion(bank, selected.id)),
                  ),
                )
              : ReorderableGlassList<KnowMeQuestion>(
                  key: ValueKey('bank-list-${selected.id}'),
                  items: questions,
                  itemKey: (q) => q.id,
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, 96),
                  header: Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                    child: Text(l.togetherKnowMeReorderHint, style: text.labelSmall?.copyWith(color: t.textTertiary)),
                  ),
                  onReorder: (list) =>
                      unawaited(_repo.updateBank((b) => b.reorderQuestions(selected.id, [for (final q in list) q.id]))),
                  itemBuilder: (context, q, index, grip) => _QuestionRow(
                    key: ValueKey('bank-q-${q.id}'),
                    question: q,
                    grip: grip,
                    onTap: () => unawaited(_editQuestion(bank, q)),
                    actions: ItemActions(
                      onEdit: () => _editQuestion(bank, q),
                      onMove: bank.categories.length > 1
                          ? () async {
                              await _moveQuestion(bank, q);
                              return null;
                            }
                          : null,
                      onDelete: () async {
                        final undo = await _repo.updateBank((b) => b.deleteQuestion(q.id));
                        return UndoableAction(label: l.togetherKnowMeQuestionDeleted, undo: undo);
                      },
                      extra: [
                        if (q.isEdited)
                          ItemAction(
                            icon: Icons.format_quote_rounded,
                            label: l.togetherKnowMeResetWording,
                            onSelected: () async {
                              final undo = await _repo.updateBank((b) => b.resetQuestionText(q.id));
                              return UndoableAction(label: st.tx.l.itemSaved, undo: undo);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    required this.count,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$label, ${st.questions(count)}',
      excludeChildSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? t.accent.withValues(alpha: t.isDark ? 0.26 : 0.16) : t.glassFill,
          border: Border.all(color: selected ? t.accent : t.glassBorder, width: selected ? 1.3 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? t.accent : t.textSecondary),
            const SizedBox(width: Space.xs),
            Text(label, style: text.labelLarge?.copyWith(color: selected ? t.textPrimary : t.textSecondary)),
            const SizedBox(width: Space.xs),
            Text(st.n(count), style: text.labelSmall?.copyWith(color: selected ? t.gold : t.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    super.key,
    required this.question,
    required this.grip,
    required this.onTap,
    required this.actions,
  });

  final KnowMeQuestion question;
  final Widget grip;
  final VoidCallback onTap;
  final ItemActions actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final st = SpecialsTexts.of(context);
    final text = Theme.of(context).textTheme;
    final tag = question.isEdited
        ? st.l.togetherKnowMeEdited
        : !question.isDefault
        ? st.l.togetherKnowMeOwn
        : null;
    return ActionableItem(
      onTap: onTap,
      actions: actions,
      swipeEnabled: false,
      semanticLabel: st.question(question),
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.xs, Space.s),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(st.question(question), style: text.bodyLarge?.copyWith(color: t.textPrimary, height: 1.35)),
                  if (tag != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: Space.xxs),
                      child: Text(tag, style: text.labelSmall?.copyWith(color: t.gold)),
                    ),
                ],
              ),
            ),
            grip,
          ],
        ),
      ),
    );
  }
}
