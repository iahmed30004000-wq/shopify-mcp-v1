import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/budget_math.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/budget_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget_edits.dart';
import 'budget_format.dart';
import 'budget_item_sheet.dart';
import 'budget_labels.dart';
import 'budget_weeks_sheet.dart';

/// UI glue between the budget sheets and [BudgetRepository]: opens the
/// right sheet, persists the result and wraps the repository's undo in a
/// localised [UndoableAction]. No arithmetic lives here.
class BudgetActions {
  BudgetActions(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  BudgetRepository get _repo => ref.read(budgetRepositoryProvider);
  L10n get _l => L10n.of(context);
  BudgetMath? get _math => ref.read(budgetMathProvider).value;
  BudgetCurrencies get _currencies => ref.read(budgetCurrenciesProvider).value ?? BudgetCurrencies.fallback;

  /// A new item under [parentId] (top level when null); with [afterId] it
  /// lands right after that sibling.
  Future<void> add({String? parentId, String? afterId}) async {
    final math = _math;
    if (math == null) return;
    final result = await showBudgetItemSheet(context, math: math, parentId: parentId, currencies: _currencies);
    if (result is! BudgetItemSaved) return;
    final undo = await _repo.add(result.node, afterId: afterId);
    if (context.mounted) unawaited(showUndoToast(context, UndoableAction(label: _l.budgetAdded, undo: undo)));
  }

  /// Opens the editor for [id]; saves or deletes with undo.
  Future<void> edit(String id) async {
    final math = _math;
    if (math == null || math[id] == null) return;
    final result = await showBudgetItemSheet(context, math: math, itemId: id, currencies: _currencies);
    if (!context.mounted) return;
    switch (result) {
      case BudgetItemSaved(:final node):
        final undo = await _repo.save(node);
        if (context.mounted) unawaited(showUndoToast(context, UndoableAction(label: _l.budgetSaved, undo: undo)));
      case BudgetItemDeleteRequested(:final id):
        Fx.fire(Sfx.delete);
        final action = await delete(id);
        if (context.mounted) unawaited(showUndoToast(context, action));
      case null:
        break;
    }
  }

  /// The move sheet: the top level or any item outside [id]'s own subtree.
  /// The effective amount is kept.
  Future<UndoableAction?> move(String id) async {
    final math = _math;
    final r = math?[id];
    if (math == null || r == null) return null;
    String path(String nodeId) {
      final names = <String>[];
      String? cur = nodeId;
      while (cur != null) {
        final n = math[cur];
        if (n == null) break;
        names.insert(0, n.node.name);
        cur = n.parentId;
      }
      return names.join(' › ');
    }

    final target = await showMoveSheet(
      context,
      title: _l.budgetMoveTitle(BudgetLabels.name(r.node.name)),
      subtitle: _l.budgetMoveSubtitle,
      icon: Icons.account_tree_rounded,
      targets: [
        MoveTarget(
          id: '',
          label: _l.budgetTopLevel,
          icon: Icons.vertical_align_top_rounded,
          isCurrent: r.parentId == null,
        ),
        for (final c in BudgetEdits.parentCandidates(math, id))
          MoveTarget(
            id: c.node.id,
            label: c.node.name,
            icon: c.depth == 0 ? Icons.folder_rounded : Icons.subdirectory_arrow_left_rounded,
            subtitle: c.parentId == null ? null : path(c.parentId!),
            isCurrent: c.node.id == r.parentId,
          ),
      ],
    );
    if (target == null || target.isCurrent) return null;
    final node = BudgetEdits.moveTo(math, id, target.id.isEmpty ? null : target.id);
    final undo = await _repo.save(node);
    return UndoableAction(label: _l.itemMoved, undo: undo);
  }

  /// Deletes [id] with its sub-items (their expenses move up to the parent).
  Future<UndoableAction> delete(String id) async {
    final math = _math;
    final children = math == null ? 0 : BudgetEdits.subtree(math, id).length - 1;
    final label = MadarFormatter.of(context).localizeDigits(_l.budgetDeletedWithChildren(children));
    final undo = await _repo.deleteSubtree(id);
    return UndoableAction(label: label, undo: undo);
  }

  /// Stores a new order of one group of siblings.
  Future<void> reorder(List<String> ids) => _repo.reorder(ids);

  /// The weeks-per-month sheet; stores the value with undo.
  Future<void> editWeeksPerMonth() async {
    final math = _math;
    final current = math?.settings.weeksPerMonth ?? BudgetSettings.defaultWeeksPerMonth;
    final value = await showBudgetWeeksSheet(context, current: current, format: BudgetFormat.of(context, _currencies));
    if (value == null || value == current) return;
    final undo = await _repo.setWeeksPerMonth(value);
    if (context.mounted) unawaited(showUndoToast(context, UndoableAction(label: _l.budgetWeeksSaved, undo: undo)));
  }
}
