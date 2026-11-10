/// Every user action of the gym: the machine's picture, the movement's
/// video, his named training days, and logging a workout set by set.
///
/// The two media rules live here, and nowhere else:
/// * a **picture** is copied into Madar's own folder when he picks it, and
///   its file is deleted only once the undo chance has passed;
/// * a **video** is never copied and never deleted – Madar stores where it
///   is and hands it to the phone when he asks to watch it.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/body_providers.dart';
import '../data/body_service.dart';
import '../data/gym_media.dart';
import '../domain/body_week.dart';
import '../domain/training.dart';
import 'body_texts.dart';
import 'widgets/body_widgets.dart';

UndoableAction _undo(String label, BodyUndo undo) => UndoableAction(label: label, undo: undo);

/// Every user action of the gym.
abstract final class GymActions {
  // ------------------------------------------------------- the picture ----

  /// Picks a picture of the machine, copies it into Madar's own folder and
  /// puts its name on the exercise. Every refusal is a sentence, never a
  /// silent no-op.
  static Future<void> pickPhoto(BuildContext context, WidgetRef ref, String exerciseId) async {
    final l = L10n.of(context);
    final fmt = BodyTexts.of(context).fmt;
    final media = ref.read(gymMediaProvider);
    final result = await media.pickPhoto();
    if (!context.mounted) return;
    if (!result.ok) {
      final error = result.error!;
      if (error == GymMediaError.cancelled) return;
      Fx.fire(Sfx.error);
      final message = switch (error) {
        GymMediaError.unsupported => l.gymPhotoWrongKind,
        GymMediaError.tooLarge => l.gymPhotoTooBig(fmt.formatInt(GymMedia.maxPhotoBytes ~/ (1024 * 1024))),
        GymMediaError.unreadable || GymMediaError.noPath || GymMediaError.cancelled => l.gymPhotoFailed,
      };
      unawaited(showUndoToast(context, UndoableAction(label: message, undo: () async {})));
      return;
    }
    final name = result.value!;
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    if (row == null || !context.mounted) {
      await media.removePhotos([name]);
      return;
    }
    final replaced = row.photo;
    final undo = await ref.read(bodyServiceProvider).setExercisePhoto(row, name);
    Fx.fire(Sfx.complete);
    if (!context.mounted) return;
    final undone = await showUndoToast(context, _undo(l.gymPhotoAdded, undo));
    // Only one of the two files is still the exercise's.
    if (undone) {
      await media.removePhotos([name]);
    } else if (replaced != null) {
      await media.removePhotos([replaced]);
    }
  }

  /// Takes the picture off the exercise, and deletes the file once the undo
  /// chance has passed.
  static Future<void> removePhoto(BuildContext context, WidgetRef ref, String exerciseId) async {
    final l = L10n.of(context);
    final media = ref.read(gymMediaProvider);
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    final photo = row?.photo;
    if (row == null || photo == null) return;
    final undo = await ref.read(bodyServiceProvider).setExercisePhoto(row, null);
    Fx.fire(Sfx.delete);
    if (!context.mounted) {
      await media.removePhotos([photo]);
      return;
    }
    final undone = await showUndoToast(context, _undo(l.gymPhotoRemoved, undo));
    if (!undone) await media.removePhotos([photo]);
  }

  // --------------------------------------------------------- the video ----

  /// Picks his own clip and remembers **where it is**. The file is not read
  /// and not copied.
  static Future<void> pickVideo(BuildContext context, WidgetRef ref, String exerciseId) async {
    final l = L10n.of(context);
    final result = await ref.read(gymMediaProvider).pickVideo();
    if (!context.mounted) return;
    if (!result.ok) {
      if (result.error == GymMediaError.cancelled) return;
      Fx.fire(Sfx.error);
      unawaited(showUndoToast(context, UndoableAction(label: l.gymVideoMissing, undo: () async {})));
      return;
    }
    await _saveVideo(context, ref, exerciseId, result.value!);
  }

  /// Asks for a link and remembers it as it is.
  static Future<void> addVideoLink(BuildContext context, WidgetRef ref, String exerciseId) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    if (row == null || !context.mounted) return;
    final existing = GymVideo.parse(row.video);
    final v = await showEditSheet(
      context,
      title: l.gymVideo,
      subtitle: l.gymVideoKept,
      icon: Icons.play_circle_outline_rounded,
      saveLabel: l.bodySave,
      initial: {'link': existing?.kind == GymVideoKind.link ? existing!.raw : ''},
      fields: [
        FieldSpec.text(
          'link',
          l.gymVideoLinkLabel,
          hint: l.gymVideoLinkHint,
          required: true,
          icon: Icons.link_rounded,
          maxLength: 500,
          autofocus: true,
        ),
      ],
    );
    final link = (v?['link'] as String?)?.trim();
    if (link == null || link.isEmpty || !context.mounted) return;
    await _saveVideo(context, ref, exerciseId, link);
  }

  static Future<void> _saveVideo(BuildContext context, WidgetRef ref, String exerciseId, String value) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    if (row == null || !context.mounted) return;
    final undo = await ref.read(bodyServiceProvider).setExerciseVideo(row, value);
    Fx.fire(Sfx.complete);
    if (context.mounted) await showUndoToast(context, _undo(l.gymVideoSaved, undo));
  }

  /// Forgets where the clip was. **His file is left exactly where it is.**
  static Future<void> removeVideo(BuildContext context, WidgetRef ref, String exerciseId) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).exercises.byId(exerciseId);
    if (row == null || row.video == null || !context.mounted) return;
    final undo = await ref.read(bodyServiceProvider).setExerciseVideo(row, null);
    Fx.fire(Sfx.delete);
    if (context.mounted) await showUndoToast(context, _undo(l.gymVideoRemoved, undo));
  }

  /// Hands the clip to whatever plays it. A phone that refuses says so.
  static Future<void> openVideo(BuildContext context, WidgetRef ref, GymVideo video) async {
    final l = L10n.of(context);
    if (video.kind == GymVideoKind.file && !video.exists) {
      Fx.fire(Sfx.error);
      unawaited(showUndoToast(context, UndoableAction(label: l.gymVideoMissing, undo: () async {})));
      return;
    }
    final ok = await ref.read(gymVideoOpenerProvider).open(video);
    if (ok || !context.mounted) return;
    Fx.fire(Sfx.error);
    unawaited(showUndoToast(context, UndoableAction(label: l.gymVideoNoApp, undo: () async {})));
  }

  // ----------------------------------------------- his training days ----

  static List<FieldSpec> _templateFields(BuildContext context) {
    final l = L10n.of(context);
    final tx = BodyTexts.of(context);
    final start = BodyWeek.startFor(tx.fmt.languageCode);
    return [
      FieldSpec.text(
        'name',
        l.gymTemplateName,
        hint: l.gymTemplateNameHint,
        required: true,
        icon: Icons.event_note_rounded,
        maxLength: 60,
        autofocus: true,
      ),
      FieldSpec.multiSelect(
        'weekdays',
        l.gymTemplateWeekdays,
        options: [for (final d in BodyWeek.ordered(start)) SelectOption(id: '$d', label: tx.weekdayName(d))],
        icon: Icons.event_repeat_rounded,
      ),
      FieldSpec.multiline('notes', l.bodyNotes, hint: l.bodyNotesHint, maxLength: 300),
    ];
  }

  static TemplateDraft _templateDraft(Map<String, Object?> v, {bool active = true}) => TemplateDraft(
    name: (v['name'] as String?)?.trim() ?? '',
    weekdays: [
      for (final id in (v['weekdays'] as List<String>?) ?? const <String>[]) ?int.tryParse(id),
    ],
    notes: v['notes'] as String?,
    active: active,
  );

  /// A new named day, or an edit of one.
  static Future<String?> editTemplate(BuildContext context, WidgetRef ref, {WorkoutTemplateRow? row}) async {
    final l = L10n.of(context);
    final v = await showEditSheet(
      context,
      title: row == null ? l.gymAddTemplate : l.gymEditTemplate,
      subtitle: l.gymTemplatesSubtitle,
      icon: Icons.event_note_rounded,
      saveLabel: l.bodySave,
      initial: row == null
          ? const {}
          : {'name': row.name, 'weekdays': [for (final d in row.weekdays) '$d'], 'notes': row.notes ?? ''},
      fields: _templateFields(context),
    );
    if (v == null) return null;
    final draft = _templateDraft(v, active: row?.active ?? true);
    if (draft.name.isEmpty) return null;
    final service = ref.read(bodyServiceProvider);
    if (row == null) {
      final (created, _) = await service.addTemplate(draft);
      Fx.fire(Sfx.complete);
      return created.id;
    }
    final undo = await service.updateTemplate(row, draft);
    Fx.fire(Sfx.complete);
    if (context.mounted) await showUndoToast(context, _undo(l.gymTemplateSaved, undo));
    return row.id;
  }

  static Future<UndoableAction?> deleteTemplate(BuildContext context, WidgetRef ref, String templateId) async {
    final l = L10n.of(context);
    final isolate = BodyTexts.of(context).fmt.isolate;
    final row = await ref.read(repositoriesProvider).workoutTemplates.byId(templateId);
    if (row == null) return null;
    final undo = await ref.read(bodyServiceProvider).deleteTemplate(row);
    return _undo(l.gymTemplateDeleted(isolate(row.name)), undo);
  }

  static Future<UndoableAction?> toggleTemplateActive(BuildContext context, WidgetRef ref, String templateId) async {
    final l = L10n.of(context);
    final isolate = BodyTexts.of(context).fmt.isolate;
    final repos = ref.read(repositoriesProvider);
    final row = await repos.workoutTemplates.byId(templateId);
    if (row == null) return null;
    await repos.workoutTemplates.setColumn(row.id, 'active', !row.active);
    Fx.fire(row.active ? Sfx.toggleOff : Sfx.toggleOn);
    final name = isolate(row.name);
    return _undo(
      row.active ? l.bodyPausedName(name) : l.bodyResumedName(name),
      () => repos.workoutTemplates.setColumn(row.id, 'active', row.active),
    );
  }

  /// Puts one of his own exercises into the day. Only his library is
  /// offered: Madar has no exercises of its own to suggest.
  static Future<void> addTemplateItem(BuildContext context, WidgetRef ref, String templateId) async {
    final l = L10n.of(context);
    final isolate = BodyTexts.of(context).fmt.isolate;
    final library = ref.read(bodyExercisesProvider).where((e) => e.active).toList();
    if (library.isEmpty) {
      Fx.fire(Sfx.error);
      unawaited(showUndoToast(context, UndoableAction(label: l.gymNoLibraryTitle, undo: () async {})));
      return;
    }
    final v = await showEditSheet(
      context,
      title: l.gymAddTemplateItem,
      icon: Icons.add_rounded,
      saveLabel: l.bodySave,
      fields: [
        FieldSpec.singleSelect(
          'exercise',
          l.gymPickExercise,
          required: true,
          icon: Icons.fitness_center_rounded,
          options: [for (final e in library) SelectOption(id: e.id, label: e.name)],
        ),
      ],
    );
    final id = v?['exercise'] as String?;
    if (id == null || !context.mounted) return;
    final exercise = library.where((e) => e.id == id).firstOrNull;
    final (_, undo) = await ref.read(bodyServiceProvider).addTemplateItem(templateId, TemplateItemDraft(exerciseId: id));
    Fx.fire(Sfx.complete);
    if (context.mounted) {
      await showUndoToast(context, _undo(l.gymTemplateItemAdded(isolate(exercise?.name ?? '')), undo));
    }
  }

  /// The numbers this day gives that exercise; empty means "whatever the
  /// exercise says".
  static Future<void> editTemplateItem(BuildContext context, WidgetRef ref, String itemId) async {
    final l = L10n.of(context);
    final row = await ref.read(repositoriesProvider).workoutTemplateItems.byId(itemId);
    if (row == null || !context.mounted) return;
    final v = await showEditSheet(
      context,
      title: l.gymTemplateItemNumbers,
      subtitle: l.gymTemplateItemHint,
      icon: Icons.tune_rounded,
      saveLabel: l.bodySave,
      initial: {
        if (row.sets != null) 'sets': row.sets,
        if (row.reps != null) 'reps': row.reps,
        if (row.weight != null) 'weight': row.weight,
        if (row.restSec != null) 'rest': row.restSec,
        if (row.warmupSets != null) 'warmup': row.warmupSets,
      },
      fields: [
        FieldSpec.number('sets', l.bodySets, min: 1, max: 20, icon: Icons.format_list_numbered_rounded),
        FieldSpec.number('reps', l.bodyReps, min: 1, max: 300, icon: Icons.repeat_rounded),
        FieldSpec.number('weight', l.bodyWeight, min: 0, max: 500, decimals: 1, step: 2.5, unit: l.bodyUnitKg),
        FieldSpec.number('rest', l.gymRest, min: 0, max: 600, step: 15, unit: l.gymUnitSec),
        FieldSpec.number('warmup', l.gymWarmupSets, min: 0, max: 10),
      ],
    );
    if (v == null) return;
    final undo = await ref.read(bodyServiceProvider).updateTemplateItem(
      row,
      TemplateItemDraft(
        exerciseId: row.exerciseId,
        sets: (v['sets'] as num?)?.round(),
        reps: (v['reps'] as num?)?.round(),
        weight: (v['weight'] as num?)?.toDouble(),
        restSec: (v['rest'] as num?)?.round(),
        warmupSets: (v['warmup'] as num?)?.round(),
      ),
    );
    Fx.fire(Sfx.complete);
    if (context.mounted) await showUndoToast(context, _undo(l.gymTemplateSaved, undo));
  }

  static Future<UndoableAction?> removeTemplateItem(
    BuildContext context,
    WidgetRef ref,
    String itemId,
    String exerciseName,
  ) async {
    final l = L10n.of(context);
    final isolate = BodyTexts.of(context).fmt.isolate;
    final row = await ref.read(repositoriesProvider).workoutTemplateItems.byId(itemId);
    if (row == null) return null;
    final undo = await ref.read(bodyServiceProvider).removeTemplateItem(row);
    return _undo(l.gymTemplateItemRemoved(isolate(exerciseName)), undo);
  }

  // ------------------------------------------------ logging his sets ----

  /// Writes one exercise of a session: one log row with its sets, in the
  /// order he did them. Returns the undo the caller shows.
  static Future<UndoableAction?> logSets(
    BuildContext context,
    WidgetRef ref,
    PlannedExercise exercise,
    List<SetDraft> sets, {
    int? minutes,
  }) async {
    if (sets.isEmpty) return null;
    final l = L10n.of(context);
    final isolate = BodyTexts.of(context).fmt.isolate;
    final before = ref.read(bodyTrainingTodayProvider);
    final (_, undo) = await ref.read(bodyServiceProvider).logWorkout(
      WorkoutDraft(
        exerciseId: exercise.id,
        name: exercise.name,
        at: ref.read(bodyClockProvider)(),
        durationMin: minutes,
      ),
      sets: sets,
    );
    Fx.fire(Sfx.complete);
    if (context.mounted && before.completedBy(exercise.id)) {
      final size = MediaQuery.sizeOf(context);
      Celebrate.burst(context, Offset(size.width / 2, size.height * 0.32), color: BodyPalette.of(context).training);
    }
    return _undo(l.gymSessionLogged(isolate(exercise.name)), undo);
  }
}
