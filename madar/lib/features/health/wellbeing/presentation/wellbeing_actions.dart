import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/wellbeing_providers.dart';
import '../domain/support_rule.dart';
import '../domain/wellbeing_drafts.dart';
import 'widgets/wb_widgets.dart';

/// The wellbeing screens' shared actions (writes + feedback + undo).
abstract final class WellbeingActions {
  static Future<UndoableAction?> deletePain(BuildContext context, WidgetRef ref, PainEntryRow e) async {
    final l = L10n.of(context);
    final undo = await ref.read(wellbeingServiceProvider).deletePain(e.id);
    return wbUndo(l.wbPainDeleted, undo);
  }

  static Future<UndoableAction?> deleteMood(BuildContext context, WidgetRef ref, MoodEntryRow e) async {
    final l = L10n.of(context);
    final undo = await ref.read(wellbeingServiceProvider).deleteMood(e.id);
    return wbUndo(l.wbCheckInDeleted, undo);
  }

  /// Quick pain log (score only, now).
  static Future<void> quickPain(BuildContext context, WidgetRef ref, int score) async {
    final l = L10n.of(context);
    final service = ref.read(wellbeingServiceProvider);
    final row = await service.logPain(PainDraft(at: ref.read(wellbeingClockProvider)(), score: score));
    Fx.fire(Sfx.complete);
    if (!context.mounted) return;
    await showUndoToast(
      context,
      UndoableAction(
        label: l.wbPainLogged(context.formatter.formatInt(score)),
        undo: () async {
          await service.deletePain(row.id);
        },
      ),
    );
  }

  /// Marks a habit done / not done today, with a sparkle when done.
  static Future<UndoableAction?> toggleHabit(
    BuildContext context,
    WidgetRef ref,
    HabitRow habit, {
    required bool done,
  }) async {
    final l = L10n.of(context);
    final today = ref.read(wellbeingTodayProvider);
    final undo = await ref.read(wellbeingServiceProvider).setHabitDone(habit.id, today, done);
    if (done) {
      Fx.fire(Sfx.complete);
      if (context.mounted) Celebrate.burstFrom(context, kind: CelebrationKind.stardust, intensity: 0.5);
    } else {
      Fx.fire(Sfx.toggleOff);
    }
    return UndoableAction(label: done ? l.wbHabitDone(BidiIsolate.isolate(habit.name)) : l.wbHabitUndone, undo: undo);
  }

  static Future<void> renameHabit(BuildContext context, WidgetRef ref, HabitRow habit) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.wbHabitEditTitle,
      icon: Icons.edit_rounded,
      initial: {'name': habit.name},
      fields: [FieldSpec.text('name', l.wbHabitName, required: true, autofocus: true, maxLength: 80)],
    );
    final name = (result?['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return;
    await ref.read(wellbeingServiceProvider).renameHabit(habit.id, name);
  }

  static Future<void> addHabit(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.wbHabitAddTitle,
      subtitle: l.wbHabitAddSubtitle,
      icon: Icons.add_task_rounded,
      fields: [FieldSpec.text('name', l.wbHabitName, required: true, autofocus: true, maxLength: 80)],
      saveLabel: l.wbAdd,
    );
    final name = (result?['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return;
    await ref.read(wellbeingServiceProvider).addHabit(name);
    Fx.fire(Sfx.complete);
  }

  static Future<UndoableAction?> deleteHabit(BuildContext context, WidgetRef ref, HabitRow habit) async {
    final l = L10n.of(context);
    final undo = await ref.read(wellbeingServiceProvider).deleteHabit(habit.id);
    return wbUndo(l.wbHabitDeleted(BidiIsolate.isolate(habit.name)), undo);
  }

  static Future<UndoableAction?> toggleHabitActive(BuildContext context, WidgetRef ref, HabitRow habit) async {
    final l = L10n.of(context);
    final service = ref.read(wellbeingServiceProvider);
    await service.setHabitActive(habit.id, !habit.active);
    Fx.fire(habit.active ? Sfx.toggleOff : Sfx.toggleOn);
    return UndoableAction(
      label: habit.active ? l.wbHabitPaused : l.wbHabitResumed,
      undo: () => service.setHabitActive(habit.id, habit.active),
    );
  }

  // ------------------------------------------------------------ worries --

  static Future<UndoableAction?> resolveWorry(BuildContext context, WidgetRef ref, WorryRow w) async {
    final l = L10n.of(context);
    final undo = await ref.read(wellbeingServiceProvider).resolveWorry(w.id);
    Fx.fire(Sfx.complete);
    return wbUndo(l.wbWorryMarkedResolved, undo);
  }

  static Future<UndoableAction?> reopenWorry(BuildContext context, WidgetRef ref, WorryRow w) async {
    final l = L10n.of(context);
    final service = ref.read(wellbeingServiceProvider);
    await service.reopenWorry(w.id);
    return UndoableAction(label: l.wbWorryReopened, undo: () => service.resolveWorry(w.id));
  }

  static Future<UndoableAction?> deleteWorry(BuildContext context, WidgetRef ref, WorryRow w) async {
    final l = L10n.of(context);
    final undo = await ref.read(wellbeingServiceProvider).deleteWorry(w.id);
    return wbUndo(l.wbWorryDeleted, undo);
  }

  static Future<void> editWorry(BuildContext context, WidgetRef ref, WorryRow w) async {
    final l = L10n.of(context);
    final result = await showEditSheet(
      context,
      title: l.wbWorryEditTitle,
      icon: Icons.edit_rounded,
      initial: {'body': w.body},
      fields: [FieldSpec.multiline('body', l.wbWorryBody, required: true, maxLength: 400)],
    );
    final body = (result?['body'] as String?)?.trim();
    if (body == null || body.isEmpty) return;
    await ref.read(wellbeingServiceProvider).editWorry(w.id, body);
  }

  // ------------------------------------------------------------ support --

  /// Opens the dialer with the support number.
  static Future<void> callSupport(BuildContext context, WidgetRef ref) async {
    final l = L10n.of(context);
    final settings = await ref.read(wellbeingServiceProvider).settings();
    final number = settings.dialable ?? settings.supportNumber;
    final ok = await ref.read(phoneDialerProvider).dial(number);
    if (!ok && context.mounted) {
      Fx.fire(Sfx.error);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(l.wbDialFailed(BidiIsolate.ltr(context.formatter.localizeDigits(number))))),
      );
    }
  }

  static Future<void> dismissSupport(BuildContext context, WidgetRef ref) async {
    final now = ref.read(wellbeingClockProvider)();
    await ref.read(wellbeingServiceProvider).dismissSupport(SupportRule.dismissUntil(now));
  }
}
