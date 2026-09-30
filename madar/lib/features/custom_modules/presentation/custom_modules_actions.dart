import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../custom_texts.dart';
import '../data/custom_modules_providers.dart';
import '../data/custom_modules_service.dart';
import '../domain/module_export.dart';
import '../domain/module_reminders.dart';
import '../domain/module_schema.dart';
import 'entry_sheet.dart';

/// The Custom Modules user actions: each writes through
/// [CustomModulesService], fires its sound + haptic (and a stardust burst in
/// the module's colour for a log) and offers Undo.
///
/// Actions invoked from an `ActionableItem` return their [UndoableAction]
/// (the row shows the toast); buttons pass `toast: true`.
abstract final class CustomModulesActions {
  static OverlayState? _overlay(BuildContext context) => Overlay.maybeOf(context, rootOverlay: true);

  static void _toast(OverlayState? overlay, UndoableAction action) {
    if (overlay != null && overlay.mounted) unawaited(UndoToast.show(overlay, action));
  }

  static void _cheer(BuildContext context, ModuleDefinition m, {bool sound = true}) {
    if (sound) Fx.fire(Sfx.complete);
    if (context.mounted) {
      Celebrate.burstFrom(context, kind: CelebrationKind.stardust, color: Color(m.colorArgb), intensity: 0.7);
    }
  }

  static CustomModulesService _service(WidgetRef ref) => ref.read(customModulesServiceProvider);

  // ------------------------------------------------------------ entries --

  /// One-tap logging (check-in toggle, a rating, a counter tick). Returns
  /// null when [m] needs the form (then [addEntry] is opened instead).
  static Future<UndoableAction?> quickLog(
    BuildContext context,
    WidgetRef ref,
    ModuleDefinition m, {
    int? rating,
    bool toast = true,
    bool sound = true,
  }) async {
    if (m.quickEntry == null) {
      await addEntry(context, ref, m);
      return null;
    }
    final tx = CustomTexts.of(context);
    final overlay = toast ? _overlay(context) : null;
    final result = await _service(ref).quickLog(m.id, rating: rating);
    if (result == null) return null;
    if (result.added) {
      if (context.mounted) _cheer(context, m, sound: sound);
    } else if (sound) {
      Fx.fire(Sfx.toggleOff);
    }
    final action = UndoableAction(
      label: result.added ? tx.l.cmodToastLogged(tx.name(m.name)) : tx.l.cmodToastUnchecked,
      undo: result.undo,
    );
    _toast(overlay, action);
    return action;
  }

  /// Opens the entry form and saves a new entry (or list item).
  static Future<UndoableAction?> addEntry(BuildContext context, WidgetRef ref, ModuleDefinition m, {bool toast = true}) async {
    final tx = CustomTexts.of(context);
    final overlay = toast ? _overlay(context) : null;
    final now = ref.read(customModulesClockProvider)();
    final result = await showEntrySheet(context, module: m, now: now);
    if (result == null) return null;
    final (_, undo) = await _service(ref).addEntry(m.id, result.values, at: m.isTracker ? result.at : null);
    if (context.mounted && m.isTracker) _cheer(context, m, sound: false);
    final action = UndoableAction(label: tx.l.cmodToastLogged(tx.name(m.name)), undo: undo);
    _toast(overlay, action);
    return action;
  }

  static Future<UndoableAction?> editEntry(
    BuildContext context,
    WidgetRef ref,
    ModuleDefinition m,
    ModuleEntry entry,
  ) async {
    final tx = CustomTexts.of(context);
    final now = ref.read(customModulesClockProvider)();
    final result = await showEntrySheet(context, module: m, entry: entry, now: now);
    if (result == null) return null;
    final service = _service(ref);
    final undo = await service.updateEntry(entry.id, result.values, at: m.isTracker ? result.at : null);
    CustomUndo? undoDone;
    if (m.isList && result.done != entry.done) undoDone = await service.setDone(entry.id, result.done);
    return UndoableAction(
      label: tx.l.cmodToastSaved(tx.name(ModuleExport.entryTitle(m, entry.copyWith(values: result.values)) ?? m.name)),
      undo: () async {
        await undoDone?.call();
        await undo();
      },
    );
  }

  static Future<UndoableAction?> deleteEntry(BuildContext context, WidgetRef ref, ModuleEntry entry, {bool toast = false}) async {
    final tx = CustomTexts.of(context);
    final overlay = toast ? _overlay(context) : null;
    if (toast) Fx.fire(Sfx.delete);
    final undo = await _service(ref).deleteEntry(entry.id);
    final action = UndoableAction(label: tx.l.cmodToastEntryDeleted, undo: undo);
    _toast(overlay, action);
    return action;
  }

  static Future<UndoableAction?> duplicateEntry(BuildContext context, WidgetRef ref, ModuleEntry entry) async {
    final tx = CustomTexts.of(context);
    final (_, undo) = await _service(ref).duplicateEntry(entry.id);
    return UndoableAction(label: tx.l.cmodToastEntryDuplicated, undo: undo);
  }

  /// Checks a list item off (with a burst) or reopens it.
  static Future<UndoableAction?> setDone(
    BuildContext context,
    WidgetRef ref,
    ModuleDefinition m,
    ModuleEntry entry,
    bool done, {
    bool toast = false,
    bool sound = true,
  }) async {
    final tx = CustomTexts.of(context);
    final overlay = toast ? _overlay(context) : null;
    if (done) {
      _cheer(context, m, sound: sound);
    } else if (sound) {
      Fx.fire(Sfx.toggleOff);
    }
    final undo = await _service(ref).setDone(entry.id, done);
    final action = UndoableAction(label: done ? tx.l.cmodToastItemDone : tx.l.cmodToastItemReopened, undo: undo);
    _toast(overlay, action);
    return action;
  }

  static Future<void> clearDone(BuildContext context, WidgetRef ref, ModuleDefinition m) async {
    final tx = CustomTexts.of(context);
    final overlay = _overlay(context);
    final undo = await _service(ref).clearDone(m.id);
    _toast(overlay, UndoableAction(label: tx.l.cmodToastCleared, undo: undo));
  }

  static Future<void> reorderEntries(WidgetRef ref, List<String> ids) => _service(ref).reorderEntries(ids);

  // ------------------------------------------------------------ modules --

  static Future<UndoableAction?> setArchived(
    BuildContext context,
    WidgetRef ref,
    ModuleDefinition m,
    bool archived, {
    bool toast = false,
  }) async {
    final tx = CustomTexts.of(context);
    final overlay = toast ? _overlay(context) : null;
    Fx.fire(archived ? Sfx.toggleOff : Sfx.toggleOn);
    final undo = await _service(ref).setArchived(m.id, archived);
    final name = tx.name(m.name);
    final action = UndoableAction(
      label: archived ? tx.l.cmodToastArchived(name) : tx.l.cmodToastUnarchived(name),
      undo: undo,
    );
    _toast(overlay, action);
    return action;
  }

  static Future<UndoableAction?> deleteModule(
    BuildContext context,
    WidgetRef ref,
    ModuleDefinition m, {
    bool toast = false,
  }) async {
    final tx = CustomTexts.of(context);
    final overlay = toast ? _overlay(context) : null;
    if (toast) Fx.fire(Sfx.delete);
    final undo = await _service(ref).deleteModule(m.id);
    final action = UndoableAction(label: tx.l.cmodToastDeleted(tx.name(m.name)), undo: undo);
    _toast(overlay, action);
    return action;
  }

  static Future<UndoableAction?> duplicateModule(BuildContext context, WidgetRef ref, ModuleDefinition m) async {
    final tx = CustomTexts.of(context);
    final (copy, undo) = await _service(ref).duplicateModule(m.id, name: tx.l.cmodFieldCopyLabel(m.name));
    return UndoableAction(label: tx.l.cmodToastDuplicated(tx.name(copy.name)), undo: undo);
  }

  static Future<void> reorderModules(WidgetRef ref, List<String> ids) => _service(ref).reorderModules(ids);

  /// Stores a chart choice made on the module page.
  static Future<void> setChart(WidgetRef ref, ModuleDefinition m, ModuleChartConfig chart) =>
      _service(ref).setChart(m.id, chart);

  /// Shares the module as a CSV file (UTF-8 with BOM so spreadsheets read
  /// Arabic correctly).
  static Future<void> shareCsv(BuildContext context, WidgetRef ref, ModuleDefinition m) async {
    final tx = CustomTexts.of(context);
    Fx.fire(Sfx.tap);
    final csv = await _service(ref).csv(m.id, texts: tx);
    if (csv == null) return;
    final bytes = utf8.encode('﻿$csv');
    final safe = m.name.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: '$safe.csv')],
        fileNameOverrides: ['$safe.csv'],
        subject: m.name,
      ),
    );
  }

  // ---------------------------------------------------------- reminders --

  static Future<void> _resync(WidgetRef ref) async {
    try {
      final sync = ref.read(customModulesReminderSyncProvider.notifier);
      await sync.engine.ensurePermission();
      await sync.syncNow();
    } catch (e) {
      debugPrint('custom module reminders: $e');
    }
  }

  static Future<void> addReminder(BuildContext context, WidgetRef ref, ModuleDefinition m) async {
    final tx = CustomTexts.of(context);
    final overlay = _overlay(context);
    final rule = await showReminderSheet(
      context,
      title: tx.l.cmodAddReminder,
      initial: m.window != null && m.window != PrayerWindow.anytime
          ? {'kind': 'prayer', 'window': m.window!.name, 'offsetMin': 10}
          : null,
      now: ref.read(customModulesClockProvider)(),
    );
    if (rule == null || rule.isEmpty || !_allowed(rule)) return;
    final (_, undo) = await _service(ref).addReminder(m.id, rule);
    _toast(overlay, UndoableAction(label: tx.l.cmodToastReminderAdded, undo: undo));
    await _resync(ref);
  }

  static Future<void> editReminder(BuildContext context, WidgetRef ref, ReminderRow row) async {
    final tx = CustomTexts.of(context);
    final overlay = _overlay(context);
    final rule = await showReminderSheet(
      context,
      initial: row.rule,
      allowRemove: true,
      now: ref.read(customModulesClockProvider)(),
    );
    if (rule == null) return;
    if (rule.isEmpty) {
      final undo = await _service(ref).deleteReminder(row.id);
      _toast(overlay, UndoableAction(label: tx.l.cmodToastReminderDeleted, undo: undo));
    } else if (_allowed(rule)) {
      await _service(ref).updateReminder(row.id, rule);
    }
    await _resync(ref);
  }

  static Future<UndoableAction?> deleteReminder(BuildContext context, WidgetRef ref, ReminderRow row) async {
    final tx = CustomTexts.of(context);
    final undo = await _service(ref).deleteReminder(row.id);
    unawaited(_resync(ref));
    return UndoableAction(
      label: tx.l.cmodToastReminderDeleted,
      undo: () async {
        await undo();
        await _resync(ref);
      },
    );
  }

  static Future<void> setReminderEnabled(WidgetRef ref, ReminderRow row, bool enabled) async {
    Fx.fire(enabled ? Sfx.toggleOn : Sfx.toggleOff);
    await _service(ref).setReminderEnabled(row.id, enabled);
    await _resync(ref);
  }

  static bool _allowed(Map<String, Object?> rule) =>
      CustomReminderPlanner.kinds.any((k) => k.name == rule['kind']);
}
