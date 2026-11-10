import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart' show AppliedPlanItemRow, AppliedPlanRow;
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../data/ai_bridge_providers.dart';
import '../data/plan_apply_service.dart';
import '../domain/plan_catalog.dart';
import '../domain/plan_contract.dart';
import '../domain/plan_preview.dart';
import 'ai_bridge_texts.dart';

/// Every decision the review screen makes, each with the app's undo toast.
///
/// Three rules live here, and they are the whole point of the screen:
///
/// * **one suggestion at a time.** Every method takes one
///   [PlanItemPreview]; there is no "approve everything" and no loop over
///   the list that would be one in disguise. His tap on that card is the
///   only thing that writes.
/// * **nothing refused is ever offered.** [approve] asks the engine, which
///   throws [PlanApplyRefused] for anything that is not `ready`; the
///   screens never show an Approve button for such a card, and if one ever
///   slipped through, the engine still says no and the toast says why.
/// * **an edit changes a value, never the words.** [edit] only ever writes
///   a day, a number or a reference he picked out of his own data into the
///   item's `data`; the title and the reason the AI wrote stay exactly as
///   they arrived, so the health guard's verdict on them cannot be edited
///   away.
abstract final class PlanActions {
  static UndoableAction _undo(String label, PlanUndo undo) => UndoableAction(label: label, undo: undo);

  // Every decision invalidates `planReviewProvider`: the plan is read
  // again against his data **as it is now**, so a suggestion that was
  // waiting for the one he just approved turns ready in front of him. The
  // invalidation is always guarded on the screen still being there – an
  // undo tapped after it is gone has nothing left to refresh.

  // --------------------------------------------------------------- decide --

  /// Approves **this one** suggestion and writes it, then shows the undo
  /// toast. Returns false when the engine refused it (the screens never
  /// offer it, so this is the belt to the braces).
  static Future<bool> approve(
    BuildContext context,
    WidgetRef ref,
    AppliedPlanRow plan,
    PlanItemPreview preview,
  ) async {
    final l = L10n.of(context);
    final texts = AiBridgeTexts.of(context);
    if (!preview.canApply) {
      Fx.fire(Sfx.error);
      return false;
    }
    final PlanApplyOutcome outcome;
    try {
      outcome = await ref.read(planApplyServiceProvider).applyItem(plan, preview);
    } on PlanApplyRefused {
      Fx.fire(Sfx.error);
      return false;
    }
    if (!context.mounted) return true;
    ref.invalidate(planReviewProvider(plan.id));
    if (outcome.alreadyApplied) {
      Fx.fire(Sfx.tap);
      return true;
    }
    Fx.fire(Sfx.complete);
    unawaited(
      showUndoToast(context, _undo(l.aiPlanApprovedToast(texts.name(preview.item.title)), outcome.undo)).then((undone) {
        if (undone && context.mounted) ref.invalidate(planReviewProvider(plan.id));
      }),
    );
    return true;
  }

  /// He said no to this one suggestion. Writes nothing to his data.
  static Future<void> reject(
    BuildContext context,
    WidgetRef ref,
    AppliedPlanRow plan,
    PlanItemPreview preview,
  ) async {
    final l = L10n.of(context);
    final texts = AiBridgeTexts.of(context);
    final undo = await ref.read(planApplyServiceProvider).rejectItem(plan, preview);
    if (!context.mounted) return;
    ref.invalidate(planReviewProvider(plan.id));
    Fx.fire(Sfx.tap);
    unawaited(
      showUndoToast(context, _undo(l.aiPlanRejectedToast(texts.name(preview.item.title)), undo)).then((undone) {
        if (undone && context.mounted) ref.invalidate(planReviewProvider(plan.id));
      }),
    );
  }

  // ----------------------------------------------------------------- edit --

  /// Lets him settle what the suggestion left open, and gives back the
  /// same suggestion with that one value changed (null when he cancelled,
  /// or when nothing about this item is editable from here).
  ///
  /// Nothing is written: the edited item goes back to the card, and only
  /// his tap on Approve applies it.
  static Future<PlanItem?> edit(
    BuildContext context,
    WidgetRef ref,
    PlanItemPreview preview, {
    required PlanCatalog catalog,
  }) async {
    final l = L10n.of(context);
    final reason = preview.editReasons.firstOrNull;
    if (reason == null) return null;
    switch (reason) {
      case PlanEditReason.dayPassed:
        final today = DateTime(catalog.today.year, catalog.today.month, catalog.today.day);
        final values = await showEditSheet(
          context,
          title: l.aiPlanEditTitle,
          icon: Icons.event_rounded,
          fields: [
            FieldSpec.date(
              'day',
              l.aiPlanEditDayField,
              required: true,
              firstDate: today,
              lastDate: today.add(const Duration(days: PlanLimits.maxDayDistance)),
              icon: Icons.event_rounded,
            ),
          ],
          initial: {'day': today},
        );
        final day = values?['day'] as DateTime?;
        if (day == null) return null;
        return _with(preview.item, {'day': planDay(day)});

      case PlanEditReason.envelopeMode:
        final envelope = preview.target(PlanTargetSlot.envelope);
        if (envelope == null) return null;
        final percentMode = envelope.extra['mode'] == 'percent';
        final values = await showEditSheet(
          context,
          title: l.aiPlanEditTitle,
          icon: Icons.account_balance_wallet_rounded,
          fields: [
            if (percentMode)
              FieldSpec.number(
                'percent',
                l.aiPlanEditPercentField,
                required: true,
                min: 0,
                max: 100,
                decimals: 1,
                icon: Icons.percent_rounded,
              )
            else
              FieldSpec.number(
                'amount',
                l.aiPlanEditAmountField,
                required: true,
                min: 0,
                max: PlanLimits.maxMoney,
                decimals: 3,
                icon: Icons.payments_rounded,
              ),
          ],
          initial: {
            if (percentMode)
              'percent': preview.item.number('newPercent') ?? (envelope.extra['percent'] as num?)?.toDouble()
            else
              'amount': preview.item.number('newAmount'),
          },
        );
        if (values == null) return null;
        final percent = (values['percent'] as num?)?.toDouble();
        final amount = (values['amount'] as num?)?.toDouble();
        if (percentMode && percent == null) return null;
        if (!percentMode && amount == null) return null;
        return _with(
          preview.item,
          percentMode ? {'newPercent': percent, 'newAmount': null} : {'newAmount': amount, 'newPercent': null},
        );

      case PlanEditReason.foodMissing:
        if (catalog.foods.isEmpty) return null;
        final values = await showEditSheet(
          context,
          title: l.aiPlanEditTitle,
          icon: Icons.restaurant_rounded,
          fields: [
            FieldSpec.singleSelect(
              'food',
              l.aiPlanEditFoodField,
              required: true,
              options: [for (final f in catalog.foods.refs) SelectOption(id: f.id, label: f.name)],
              icon: Icons.restaurant_rounded,
            ),
          ],
          initial: const {},
        );
        final food = values?['food'] as String?;
        if (food == null || food.isEmpty) return null;
        return _with(preview.item, {'foodRef': food});

      // He has no meal plan at all: that is built on the Body planet, not
      // in a sheet over a suggestion.
      case PlanEditReason.mealPlanMissing:
        return null;
    }
  }

  /// [item] with [changes] merged into its `data` (a null value removes the
  /// key). Everything else – the id, the kind, the title, the reason – is
  /// carried over untouched.
  static PlanItem _with(PlanItem item, Map<String, Object?> changes) {
    final data = {...item.data};
    for (final e in changes.entries) {
      if (e.value == null) {
        data.remove(e.key);
      } else {
        data[e.key] = e.value;
      }
    }
    return PlanItem(
      id: item.id,
      kind: item.kind,
      title: item.title,
      reason: item.reason,
      area: item.area,
      evidence: item.evidence,
      confidence: item.confidence,
      dependsOn: item.dependsOn,
      data: data,
    );
  }

  // ------------------------------------------------------------ checklist --

  /// Ticks or un-ticks one line of a plan's checklist, with its undo.
  static Future<void> setDone(BuildContext context, WidgetRef ref, AppliedPlanItemRow row, bool done) async {
    final l = L10n.of(context);
    final texts = AiBridgeTexts.of(context);
    final PlanUndo undo;
    try {
      undo = await ref.read(planApplyServiceProvider).setDone(row, done);
    } on PlanApplyRefused {
      Fx.fire(Sfx.error);
      return;
    }
    if (!context.mounted) return;
    Fx.fire(done ? Sfx.complete : Sfx.tap);
    final label = done ? l.aiPlanTickedToast(texts.name(row.title)) : l.aiPlanUntickedToast(texts.name(row.title));
    unawaited(showUndoToast(context, _undo(label, undo)));
  }

  /// His own name for the list.
  static Future<void> rename(BuildContext context, WidgetRef ref, AppliedPlanRow plan) async {
    final l = L10n.of(context);
    final texts = AiBridgeTexts.of(context);
    final values = await showEditSheet(
      context,
      title: l.aiPlanRenameAction,
      icon: Icons.drive_file_rename_outline_rounded,
      fields: [
        FieldSpec.text(
          'name',
          l.aiPlanRenameField,
          required: true,
          maxLength: 60,
          autofocus: true,
          icon: Icons.label_outline_rounded,
        ),
      ],
      initial: {'name': plan.name},
    );
    final name = (values?['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return;
    final PlanUndo undo;
    try {
      undo = await ref.read(planApplyServiceProvider).rename(plan, name);
    } on PlanApplyRefused {
      Fx.fire(Sfx.error);
      return;
    }
    if (!context.mounted) return;
    ref.invalidate(planReviewProvider(plan.id));
    Fx.fire(Sfx.complete);
    unawaited(
      showUndoToast(context, _undo(l.aiPlanRenamedToast(texts.name(name)), undo)).then((undone) {
        if (undone && context.mounted) ref.invalidate(planReviewProvider(plan.id));
      }),
    );
  }

}
