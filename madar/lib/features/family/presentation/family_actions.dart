import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/contact_launcher.dart';
import '../data/family_providers.dart';
import '../data/family_service.dart';
import '../domain/family_models.dart';
import '../family_texts.dart';
import 'contacted_sheet.dart';
import 'family_navigation.dart';
import 'family_settings_sheet.dart';
import 'person_sheet.dart';
import 'widgets/family_widgets.dart';

/// The Family user actions: each writes through [FamilyService], fires its
/// sound + haptic (and a celebration for a contact) and offers Undo.
abstract final class FamilyActions {
  /// (The toast plays the undo sound itself.)
  static UndoableAction _undoable(String label, FamilyUndo undo) => UndoableAction(label: label, undo: undo);

  /// The toast host, captured before any await (the row that asked may be
  /// rebuilt elsewhere – a contacted person moves to "in touch").
  static OverlayState? _overlay(BuildContext context) => Overlay.maybeOf(context, rootOverlay: true);

  static void _toast(OverlayState? overlay, UndoableAction action) {
    if (overlay != null && overlay.mounted) unawaited(UndoToast.show(overlay, action));
  }

  /// The chime and a stardust burst in the person's colour from [context]
  /// (the tapped control) – at once, before the write.
  static void _cheer(BuildContext context, String name, int? color, {bool sound = true}) {
    if (sound) Fx.fire(Sfx.complete);
    Celebrate.burstFrom(context, kind: CelebrationKind.stardust, color: personColor(name, color), intensity: 0.7);
  }

  /// One-tap "contacted": logs a contact now (the person's usual channel),
  /// celebrates from [context] (the tapped control) with a chime and – with
  /// [toast] – shows the undo toast. Returns the undoable action (for a
  /// swipe, whose toast and chime the row plays itself: pass
  /// `toast: false, sound: false`).
  static Future<UndoableAction?> contacted(
    BuildContext context,
    WidgetRef ref,
    PersonView person, {
    bool toast = true,
    bool sound = true,
  }) async {
    final tx = FamilyTexts.of(context);
    final service = ref.read(familyServiceProvider);
    final overlay = toast ? _overlay(context) : null;
    _cheer(context, person.name, person.row.color, sound: sound);
    final logged = await service.logContact(person.id, channel: person.lastChannel ?? ContactChannel.other);
    final action = _undoable(tx.l.familyContactedToast(tx.name(person.name)), logged.undo);
    _toast(overlay, action);
    return action;
  }

  /// "Contacted…" with the details sheet (channel, time, note).
  static Future<UndoableAction?> contactedWithDetails(
    BuildContext context,
    WidgetRef ref,
    PersonView person, {
    bool toast = true,
  }) async {
    final tx = FamilyTexts.of(context);
    final service = ref.read(familyServiceProvider);
    final overlay = toast ? _overlay(context) : null;
    final draft = await showContactedSheet(context, name: person.name, channel: person.lastChannel);
    if (draft == null) return null;
    if (context.mounted) _cheer(context, person.name, person.row.color);
    final logged = await service.logContact(person.id, channel: draft.channel, note: draft.note, at: draft.at);
    final action = _undoable(tx.l.familyContactedToast(tx.name(person.name)), logged.undo);
    _toast(overlay, action);
    return action;
  }

  // ------------------------------------------------------------------ people

  static Future<PersonRow?> addPerson(BuildContext context, WidgetRef ref) async {
    final tx = FamilyTexts.of(context);
    final service = ref.read(familyServiceProvider);
    final overlay = _overlay(context);
    final draft = await showPersonSheet(context);
    if (draft == null) return null;
    final row = await service.addPerson(draft);
    Fx.fire(Sfx.complete);
    _toast(overlay, _undoable(tx.l.familySavedToast(tx.name(row.name)), () => service.deletePerson(row.id)));
    return row;
  }

  static Future<void> editPerson(BuildContext context, WidgetRef ref, PersonRow person) async {
    final tx = FamilyTexts.of(context);
    final service = ref.read(familyServiceProvider);
    final overlay = _overlay(context);
    final draft = await showPersonSheet(context, person: person);
    if (draft == null) return;
    final undo = await service.updatePerson(person.id, draft);
    Fx.fire(Sfx.complete);
    _toast(overlay, _undoable(tx.l.familySavedToast(tx.name(draft.name)), undo));
  }

  /// Deletes [person] (and their contact history). The row's dissolve,
  /// sound and undo toast come from the caller (ActionableItem's Delete)
  /// unless [toast] / [sound].
  static Future<UndoableAction?> deletePerson(
    BuildContext context,
    WidgetRef ref,
    PersonRow person, {
    bool toast = false,
    bool sound = false,
  }) async {
    final tx = FamilyTexts.of(context);
    final service = ref.read(familyServiceProvider);
    final overlay = toast ? _overlay(context) : null;
    if (sound) Fx.fire(Sfx.delete);
    final undo = await service.deletePerson(person.id);
    final action = _undoable(tx.l.familyDeletedToast(tx.name(person.name)), undo);
    _toast(overlay, action);
    return action;
  }

  static Future<UndoableAction?> toggleMoon(BuildContext context, WidgetRef ref, PersonRow person) async {
    final tx = FamilyTexts.of(context);
    final show = !person.showAsMoon;
    Fx.fire(show ? Sfx.toggleOn : Sfx.toggleOff);
    final undo = await ref.read(familyServiceProvider).setShowAsMoon(person.id, show);
    return _undoable(
      show ? tx.l.familyMoonShownToast(tx.name(person.name)) : tx.l.familyMoonHiddenToast(tx.name(person.name)),
      undo,
    );
  }

  static Future<void> reorder(WidgetRef ref, List<String> ids) => ref.read(familyServiceProvider).reorder(ids);

  static Future<void> setSortMode(WidgetRef ref, FamilySettings current, FamilySortMode mode) async {
    if (current.sortMode == mode) return;
    await ref.read(familyServiceProvider).saveSettings(current.copyWith(sortMode: mode));
  }

  static Future<void> editNotes(BuildContext context, WidgetRef ref, PersonRow person) async {
    final tx = FamilyTexts.of(context);
    final service = ref.read(familyServiceProvider);
    final overlay = _overlay(context);
    final result = await showEditSheet(
      context,
      title: tx.l.familyNotesTitle,
      subtitle: tx.name(person.name),
      icon: Icons.sticky_note_2_rounded,
      fields: [FieldSpec.multiline('notes', tx.l.familyFieldNotes, hint: tx.l.familyFieldNotesHint)],
      initial: {'notes': person.notes},
      saveLabel: tx.l.familySave,
    );
    if (result == null) return;
    final undo = await service.setNotes(person.id, result['notes'] as String?);
    Fx.fire(Sfx.complete);
    _toast(overlay, _undoable(tx.l.familySavedToast(tx.name(person.name)), undo));
  }

  // ------------------------------------------------------------- contacts

  static Future<void> editContact(BuildContext context, WidgetRef ref, ContactLogRow log, String personName) async {
    final l = L10n.of(context);
    final service = ref.read(familyServiceProvider);
    final overlay = _overlay(context);
    final draft = await showContactedSheet(
      context,
      name: personName,
      initial: ContactDraft(channel: log.channel, at: log.at, note: log.note),
    );
    if (draft == null) return;
    final undo = await service.updateContact(log.id, draft);
    Fx.fire(Sfx.complete);
    _toast(overlay, _undoable(l.familyContactUpdatedToast, undo));
  }

  static Future<UndoableAction?> deleteContact(BuildContext context, WidgetRef ref, ContactLogRow log) async {
    final l = L10n.of(context);
    final undo = await ref.read(familyServiceProvider).deleteContact(log.id);
    return _undoable(l.familyContactDeletedToast, undo);
  }

  // --------------------------------------------------------------- launch

  /// Opens the dialer / messages / WhatsApp for [person] (explicit tap only;
  /// nothing is logged – the user taps "contacted" when done).
  static Future<void> launch(BuildContext context, WidgetRef ref, PersonView person, ContactLaunch kind) async {
    final l = L10n.of(context);
    final phone = person.phone;
    if (phone == null) return;
    final launcher = ref.read(familyContactLauncherProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    Fx.fire(Sfx.navigate);
    final ok = await launcher.open(kind, phone);
    if (!ok) {
      Fx.fire(Sfx.error);
      messenger?.showSnackBar(SnackBar(content: Text(l.familyLaunchFailed)));
    }
  }

  // ------------------------------------------------------------- navigation

  static Future<void> openPerson(BuildContext context, String personId) =>
      FamilyNavigation.openPerson(context, personId);

  static Future<void> openSettings(BuildContext context, WidgetRef ref) async {
    final current = ref.read(familySettingsProvider).value ?? const FamilySettings();
    final service = ref.read(familyServiceProvider);
    final sync = ref.read(familyReminderSyncProvider.notifier);
    final next = await showFamilySettingsSheet(context, settings: current);
    if (next == null || next == current) return;
    if (FamilySettingsChange.turnedOn(current, next)) unawaited(sync.engine.ensurePermission());
    await service.saveSettings(next);
    Fx.fire(Sfx.complete);
  }
}

/// Settings transitions.
abstract final class FamilySettingsChange {
  /// Whether [next] turns on a notification [current] had off.
  static bool turnedOn(FamilySettings current, FamilySettings next) =>
      (next.digestEnabled && !current.digestEnabled) || (next.birthdaysEnabled && !current.birthdaysEnabled);
}
