import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../domain/dose_tracker.dart';
import '../../domain/meds_settings.dart';
import '../../meds_texts.dart';
import 'meds_widgets.dart';

/// One dose of the day: orb, name, dose and "taken with", its time (and why
/// a rule moved it), its state, and – while it waits – Taken / Snooze /
/// Skip. Swipe right = Taken; swipe left = snooze 10 / 30 / 60 or skip;
/// long-press for the menu (edit the medication, history, clear the answer).
class DoseTile extends StatelessWidget {
  const DoseTile({
    super.key,
    required this.dose,
    required this.onTake,
    required this.onSnooze,
    required this.onPickSnooze,
    required this.onSkip,
    required this.onReset,
    required this.onEditMed,
    required this.onHistory,
    this.courseName,
    this.dense = false,
    this.showButtons,
  });

  final TrackedDose dose;
  final FutureOr<UndoableAction?> Function() onTake;
  final FutureOr<UndoableAction?> Function(int minutes) onSnooze;
  final VoidCallback onPickSnooze;
  final FutureOr<UndoableAction?> Function() onSkip;
  final FutureOr<UndoableAction?> Function() onReset;
  final FutureOr<void> Function() onEditMed;
  final FutureOr<void> Function() onHistory;
  final String? courseName;
  final bool dense;

  /// Whether the Taken / Snooze / Skip row shows (default: once the dose is
  /// due, late, missed or snoozed; a later dose keeps its swipe and menu).
  final bool? showButtons;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final text = Theme.of(context).textTheme;
    final d = dose.dose;
    final state = dose.state;
    final stateColor = doseStateColor(state, t);
    final open = state.open || state == DoseState.missed;
    final buttons = !dense && open && (showButtons ?? state != DoseState.upcoming);
    final answered = state.done;
    final shift = tx.shift(d);
    final doseLine = tx.doseLine(d);
    // A taken dose sits at its real time (shown in its badge); its row keeps
    // the time it was planned for.
    final timeText = tx.time(switch (state) {
      DoseState.snoozed => dose.dueAt,
      DoseState.taken when d.ruleIds.isEmpty => d.baseAt,
      _ => d.at,
    });
    final semantics = l.medsDoseSemantics(d.med.name, doseLine, timeText, tx.state(dose));

    final card = GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      tint: state.needsAction ? stateColor.withValues(alpha: t.isDark ? 0.10 : 0.06) : null,
      borderColor: state.needsAction ? stateColor.withValues(alpha: 0.65) : null,
      glowColor: state.needsAction ? stateColor.withValues(alpha: 0.35) : null,
      padding: EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, buttons ? Space.s : Space.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              MedOrb(med: d.med, state: state, size: dense ? 34 : 42),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d.med.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: BidiIsolate.directionOf(d.med.name),
                      style: text.titleMedium!.copyWith(
                        color: answered ? t.textSecondary : t.textPrimary,
                        decoration: state == DoseState.skipped ? TextDecoration.lineThrough : null,
                        decorationColor: t.textTertiary,
                      ),
                    ),
                    if (doseLine.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 1),
                        child: Text(
                          doseLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall!.copyWith(color: t.textSecondary),
                        ),
                      ),
                    if (!dense && (shift != null || courseName != null))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 3),
                        child: Row(
                          children: [
                            Icon(
                              shift != null ? Icons.swap_vert_rounded : Icons.timeline_rounded,
                              size: 13,
                              color: t.info,
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                shift ?? l.medsPartOfCourse(fmt.isolate(courseName!)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.labelSmall!.copyWith(color: t.info),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: text.titleSmall!.copyWith(
                      color: answered ? t.textTertiary : t.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 3),
                  MedBadge(
                    label: _stateLabel(tx, dose),
                    color: stateColor,
                    icon: doseStateIcon(state),
                    filled: state != DoseState.upcoming,
                  ),
                  if (d.pastMidnight)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 2),
                      child: Text(l.medsPastMidnight, style: text.labelSmall!.copyWith(color: t.textTertiary)),
                    ),
                ],
              ),
            ],
          ),
          if (buttons) ...[
            const SizedBox(height: Space.s),
            _DoseButtons(
              state: state,
              onTake: () => _withToast(context, onTake),
              onSnooze: onPickSnooze,
              onSkip: () => _withToast(context, onSkip),
            ),
          ],
        ],
      ),
    );

    return ActionableItem(
      semanticLabel: semantics,
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => onHistory(),
      onCompleteSwipe: open ? onTake : null,
      completeLabel: l.medsTake,
      swipeEnabled: open,
      actions: ItemActions(
        onEdit: onEditMed,
        extra: [
          if (open)
            ItemAction(icon: Icons.check_rounded, label: l.medsTake, onSelected: onTake, tone: ActionTone.success),
          if (state.open)
            ItemAction(icon: Icons.snooze_rounded, label: l.medsSnooze, onSelected: () async {
              onPickSnooze();
              return null;
            }, tone: ActionTone.info),
          if (open) ItemAction(icon: Icons.redo_rounded, label: l.medsSkip, onSelected: onSkip),
          if (!open) ItemAction(icon: Icons.undo_rounded, label: l.medsReset, onSelected: onReset, tone: ActionTone.warning),
          ItemAction(
            icon: Icons.insights_rounded,
            label: l.medsHistory,
            onSelected: () async {
              await onHistory();
              return null;
            },
          ),
        ],
      ),
      quickActions: [
        if (state.open)
          for (final m in MedsSettings.snoozeChoices)
            QuickAction(
              icon: Icons.snooze_rounded,
              label: l.medsSnoozeFor(tx.duration(m)),
              onPressed: () => onSnooze(m),
              tone: ActionTone.info,
            ),
        if (open) QuickAction(icon: Icons.redo_rounded, label: l.medsSkip, onPressed: onSkip, tone: ActionTone.warning),
      ],
      child: card,
    );
  }

  /// Buttons outside the [ActionableItem] show the Undo toast themselves
  /// (the item does it for its swipe, menu and tray).
  static Future<void> _withToast(BuildContext context, FutureOr<UndoableAction?> Function() run) async {
    final action = await run();
    if (action != null && context.mounted) unawaited(showUndoToast(context, action));
  }

  static String _stateLabel(MedsTexts tx, TrackedDose t) => switch (t.state) {
    DoseState.taken when t.takenAt != null => tx.time(t.takenAt!),
    DoseState.snoozed => tx.l.medsSnooze,
    _ => tx.state(t),
  };
}

class _DoseButtons extends StatelessWidget {
  const _DoseButtons({required this.state, required this.onTake, required this.onSnooze, required this.onSkip});

  final DoseState state;
  final VoidCallback onTake;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final primary = state.needsAction || state == DoseState.missed;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: MadarButton(
            label: l.medsTake,
            icon: Icons.check_rounded,
            onPressed: onTake,
            size: MadarButtonSize.small,
            variant: primary ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
            sfx: Sfx.tap,
          ),
        ),
        if (state != DoseState.missed) ...[
          const SizedBox(width: Space.s),
          Expanded(
            flex: 2,
            child: MadarButton(
              label: l.medsSnooze,
              icon: Icons.snooze_rounded,
              onPressed: onSnooze,
              size: MadarButtonSize.small,
              variant: MadarButtonVariant.secondary,
              sfx: Sfx.sheetOpen,
            ),
          ),
        ],
        const SizedBox(width: Space.s),
        Expanded(
          flex: 2,
          child: MadarButton(
            label: l.medsSkip,
            onPressed: onSkip,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.ghost,
          ),
        ),
      ],
    );
  }
}
