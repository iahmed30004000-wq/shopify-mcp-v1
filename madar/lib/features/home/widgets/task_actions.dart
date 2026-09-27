import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/design/themes.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/home_tasks.dart';
import '../domain/prayer_day.dart';
import '../home_providers.dart';
import 'window_chips.dart';

/// UI glue between the interaction kit's sheets and [HomeTasksService]:
/// opens the right sheet, applies the result and wraps the service's undo
/// in a localised [UndoableAction]. No business rules live here.
class TaskActions {
  TaskActions(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  HomeTasksService get _service => ref.read(homeTasksServiceProvider);
  L10n get _l => L10n.of(context);

  /// Opens the edit sheet for a new task in [window] on [day].
  Future<void> add({required PrayerWindow window, required DateTime day}) async {
    final values = await _openSheet(title: _l.homeAddTask, initial: {'window': window, 'date': day}, autofocus: true);
    if (values == null) return;
    await _service.add(
      title: values['title']! as String,
      window: (values['window'] as PrayerWindow?) ?? window,
      date: (values['date'] as DateTime?) ?? day,
      notes: values['notes'] as String?,
      planetKey: values['planet'] as String?,
    );
    Fx.fire(Sfx.drop);
  }

  /// Opens the edit sheet for [task]; edits are saved in place.
  Future<void> edit(TaskRow task) async {
    final values = await _openSheet(
      title: _l.homeEditTask,
      initial: {
        'title': task.title,
        'window': task.window == PrayerWindow.anytime ? null : task.window,
        'date': task.date,
        'notes': task.notes,
        'planet': task.planetKey,
      },
    );
    if (values == null) return;
    await _service.edit(
      task,
      title: values['title']! as String,
      window: (values['window'] as PrayerWindow?) ?? task.window,
      date: values['date'] as DateTime?,
      notes: values['notes'] as String?,
      planetKey: values['planet'] as String?,
    );
  }

  Future<UndoableAction> toggleDone(TaskRow task) async {
    final undo = await _service.toggleDone(task);
    return UndoableAction(label: task.done ? _l.homeTaskReopened : _l.homeTaskCompleted, undo: undo);
  }

  Future<UndoableAction> duplicate(TaskRow task) async {
    final (_, undo) = await _service.duplicate(task);
    return UndoableAction(label: _l.itemDuplicated, undo: undo);
  }

  /// Move sheet listing the six windows; null when dismissed.
  Future<UndoableAction?> move(TaskRow task) async {
    final times = ref.read(prayerDayProvider);
    final fmt = MadarFormatter.of(context);
    final target = await showMoveSheet(
      context,
      title: _l.homeMoveTitle,
      subtitle: _l.homeMoveSubtitle,
      icon: Icons.schedule_rounded,
      targets: [
        for (final w in PrayerDayTimes.windows)
          MoveTarget(
            id: w.name,
            label: windowLabel(_l, w),
            icon: windowIcon(w),
            subtitle: fmt.formatClock(times.startOf(w).inHours, times.startOf(w).inMinutes.remainder(60)),
            isCurrent: w == task.window,
          ),
      ],
    );
    if (target == null) return null;
    final window = PrayerWindow.values.byName(target.id);
    final undo = await _service.move(task, window);
    return UndoableAction(label: _l.itemMoved, undo: undo);
  }

  /// Reminder sheet → Reminders table (an existing rule can be removed).
  Future<void> setReminder(TaskRow task) async {
    final existing = await _service.reminderOf(task.id);
    if (!context.mounted) return;
    final rule = await showReminderSheet(context, initial: existing, dueDate: task.date, allowRemove: existing != null);
    if (rule == null || !context.mounted) return;
    final undo = await _service.setReminder(task, rule);
    if (!context.mounted) return;
    unawaited(
      showUndoToast(
        context,
        UndoableAction(label: rule.isEmpty ? _l.homeReminderRemoved : _l.homeReminderSet, undo: undo),
      ),
    );
  }

  Future<UndoableAction> delete(TaskRow task) async {
    final undo = await _service.delete(task);
    return UndoableAction(label: _l.itemDeleted, undo: undo);
  }

  Future<Map<String, Object?>?> _openSheet({
    required String title,
    required Map<String, Object?> initial,
    bool autofocus = false,
  }) async {
    final Repositories repos = ref.read(repositoriesProvider);
    final planets = await repos.planets.getAll(where: (p) => p.hidden.equals(false));
    if (!context.mounted) return null;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return showEditSheet(
      context,
      title: title,
      icon: Icons.task_alt_rounded,
      initial: initial,
      fields: [
        FieldSpec.text(
          'title',
          _l.homeTaskTitleField,
          required: true,
          hint: _l.homeTaskTitleHint,
          maxLength: 160,
          autofocus: autofocus,
        ),
        FieldSpec.prayerWindow('window', _l.homeTaskWindowField, includeAnytime: false, icon: Icons.schedule_rounded),
        FieldSpec.date('date', _l.homeTaskDateField, icon: Icons.event_rounded),
        if (planets.isNotEmpty)
          FieldSpec.singleSelect(
            'planet',
            _l.homeTaskPlanetField,
            icon: Icons.public_rounded,
            options: [
              for (final p in planets)
                SelectOption(
                  id: p.key,
                  label: arabic ? p.nameAr : p.nameEn,
                  icon: InteractionIcons.resolve(p.icon),
                  color: PlanetPalettes.byKey[p.key]?.surface ?? Color(p.color),
                ),
            ],
          ),
        FieldSpec.multiline('notes', _l.homeTaskNotesField, icon: Icons.notes_rounded, maxLength: 2000),
      ],
    );
  }
}
