import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/travel_providers.dart';
import '../data/travel_service.dart';
import '../domain/packing.dart';
import '../domain/starter_templates.dart';
import '../travel_texts.dart';
import 'document_sheet.dart';
import 'packing_templates_screen.dart';
import 'trip_screen.dart';
import 'trip_sheet.dart';
import 'widgets/travel_widgets.dart';

/// The travel flows: sheets → service → undo toast, with sound, haptics
/// and celebration. Widgets stay thin and call these.
abstract final class TravelActions {
  static TravelService _service(WidgetRef ref) => ref.read(travelServiceProvider);

  static Future<void> _toast(BuildContext context, String label, TravelUndo undo) async {
    if (!context.mounted) return;
    unawaited(showUndoToast(context, UndoableAction(label: label, undo: undo)));
  }

  // ------------------------------------------------------------ opening --

  /// Opens a trip (pushes [TripScreen]).
  static void openTrip(BuildContext context, String tripId) {
    Fx.fire(Sfx.navigate);
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TripScreen(tripId: tripId))));
  }

  static void openTemplates(BuildContext context) {
    Fx.fire(Sfx.navigate);
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PackingTemplatesScreen())));
  }

  static void openTemplate(BuildContext context, String templateId) {
    Fx.fire(Sfx.navigate);
    unawaited(
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PackingTemplateScreen(templateId: templateId))),
    );
  }

  // -------------------------------------------------------------- trips --

  /// New trip; opens it after saving when [open] is true.
  static Future<TripRow?> addTrip(BuildContext context, WidgetRef ref, {bool open = true}) async {
    final service = _service(ref);
    final draft = await showTripSheet(context);
    if (draft == null) return null;
    final row = await service.addTrip(draft);
    if (open && context.mounted) openTrip(context, row.id);
    return row;
  }

  static Future<UndoableAction?> editTrip(BuildContext context, WidgetRef ref, TripRow trip) async {
    final service = _service(ref);
    final manual = (ref.read(travelManualStatusProvider).value ?? const {}).contains(trip.id);
    final draft = await showTripSheet(context, trip: trip, manualStatus: manual ? trip.status : null);
    if (draft == null || !context.mounted) return null;
    final label = L10n.of(context).travelUndoSaved;
    final undo = await service.editTrip(trip, draft);
    return UndoableAction(label: label, undo: undo);
  }

  static Future<UndoableAction?> duplicateTrip(BuildContext context, WidgetRef ref, TripRow trip) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final (_, undo) = await service.duplicateTrip(trip);
    return UndoableAction(label: l.travelUndoTripDuplicated, undo: undo);
  }

  static Future<UndoableAction?> deleteTrip(BuildContext context, WidgetRef ref, TripRow trip) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final undo = await service.deleteTrip(trip);
    return UndoableAction(label: l.travelUndoTripDeleted, undo: undo);
  }

  /// Sets a manual status (null: follow the dates again).
  static Future<UndoableAction?> setStatus(BuildContext context, WidgetRef ref, TripRow trip, TripStatus? status) async {
    final service = _service(ref);
    final tx = TravelTexts.of(context);
    final undo = await service.setStatus(trip, status);
    final now = (await service.repos.trips.byId(trip.id))?.status ?? status ?? trip.status;
    if (status == TripStatus.done) Fx.fire(Sfx.complete);
    return UndoableAction(label: tx.l.travelUndoStatus(tx.status(now)), undo: undo);
  }

  // ------------------------------------------------------------ packing --

  static Future<void> addItem(WidgetRef ref, String tripId, String body, {String? category}) async {
    final service = _service(ref);
    if (body.trim().isEmpty) return;
    Fx.fire(Sfx.drop);
    await service.addItem(tripId, body, category: category);
  }

  /// Packs / unpacks; celebrates from [celebrateFrom] (the progress ring)
  /// when this completes the list.
  static Future<UndoableAction?> togglePacked(
    BuildContext context,
    WidgetRef ref,
    TripItemRow item, {
    BuildContext? celebrateFrom,
  }) async {
    final service = _service(ref);
    final l = L10n.of(context);
    Fx.fire(item.packed ? Sfx.toggleOff : Sfx.toggleOn);
    final r = await service.togglePacked(item);
    if (r.after.completes(r.before)) {
      final target = celebrateFrom ?? context;
      if (target.mounted) {
        Celebrate.burstFrom(target, kind: CelebrationKind.orbitalRing, sfx: Sfx.levelUp, intensity: 1.1);
      }
    }
    return UndoableAction(label: item.packed ? l.travelUndoUnpacked : l.travelUndoPacked, undo: r.undo);
  }

  static Future<UndoableAction?> editItem(BuildContext context, WidgetRef ref, TripItemRow item) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final result = await showEditSheet(
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
        FieldSpec.singleSelect('category', l.travelFieldCategory, options: categoryOptions(context, extra: item.category)),
      ],
      initial: {'body': item.body, 'category': PackingCategories.of(item.category)},
    );
    if (result == null || !context.mounted) return null;
    final undo = await service.editItem(
      item,
      body: result['body'] as String? ?? item.body,
      category: result['category'] as String?,
    );
    return UndoableAction(label: l.travelUndoSaved, undo: undo);
  }

  /// Category options: the standard ones plus the trip's own.
  static List<SelectOption> categoryOptions(BuildContext context, {String? extra, Iterable<String> custom = const []}) {
    final tx = TravelTexts.of(context);
    final own = <String>{
      ...custom.where((c) => !PackingCategories.isStandard(c)),
      if (extra != null && !PackingCategories.isStandard(extra)) extra,
    };
    return [
      for (final c in PackingCategories.standard)
        SelectOption(id: c, label: tx.category(c), icon: categoryIcon(c)),
      for (final c in own) SelectOption(id: c, label: tx.category(c), icon: categoryIcon(c)),
    ];
  }

  /// Moves an item to another category (the move sheet; a new category can
  /// be typed).
  static Future<UndoableAction?> moveItem(
    BuildContext context,
    WidgetRef ref,
    TripItemRow item, {
    Iterable<String> custom = const [],
  }) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final tx = TravelTexts.of(context);
    const newId = '\u0000new';
    final current = PackingCategories.of(item.category);
    final target = await showMoveSheet(
      context,
      title: l.travelMoveToCategory,
      icon: Icons.category_rounded,
      targets: [
        for (final o in categoryOptions(context, extra: item.category, custom: custom))
          MoveTarget(id: o.id, label: o.label, icon: o.icon, isCurrent: o.id == current),
        MoveTarget(id: newId, label: l.travelCatNew, icon: Icons.add_rounded),
      ],
    );
    if (target == null || !context.mounted) return null;
    var category = target.id;
    if (category == newId) {
      final r = await showEditSheet(
        context,
        title: l.travelCatNew,
        icon: Icons.category_rounded,
        fields: [FieldSpec.text('name', l.travelCatNewHint, required: true, autofocus: true)],
      );
      final name = (r?['name'] as String?)?.trim();
      if (name == null || name.isEmpty || !context.mounted) return null;
      category = name;
    }
    if (category == current) return null;
    final undo = await service.moveItem(item, category);
    return UndoableAction(label: l.travelUndoMoved(tx.category(category)), undo: undo);
  }

  static Future<UndoableAction?> deleteItem(BuildContext context, WidgetRef ref, TripItemRow item) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final undo = await service.deleteItem(item);
    return UndoableAction(label: l.travelUndoItemDeleted, undo: undo);
  }

  static Future<void> unpackAll(BuildContext context, WidgetRef ref, String tripId) async {
    final service = _service(ref);
    final l = L10n.of(context);
    Fx.fire(Sfx.toggleOff);
    final undo = await service.unpackAll(tripId);
    if (context.mounted) await _toast(context, l.travelUndoUnpackedAll, undo);
  }

  /// Picks packing templates and merges them into the trip.
  static Future<void> addFromTemplates(BuildContext context, WidgetRef ref, String tripId) async {
    final service = _service(ref);
    final tx = TravelTexts.of(context);
    final templates = ref.read(travelTemplatesProvider).value ?? const [];
    final picked = await showTemplatePickerSheet(context, templates: templates);
    if (picked == null || picked.isEmpty || !context.mounted) return;
    final (added, undo) = await service.applyTemplates(tripId, picked);
    Fx.fire(added > 0 ? Sfx.sparkle : Sfx.tap);
    if (context.mounted) await _toast(context, tx.l.travelTemplatesApplied(added, tx.n(added)), undo);
  }

  /// Saves the trip's list as a new template (asks for a name).
  static Future<void> saveAsTemplate(BuildContext context, WidgetRef ref, String tripId, {String? suggestedName}) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final r = await showEditSheet(
      context,
      title: l.travelTemplateNameTitle,
      icon: Icons.bookmark_add_rounded,
      fields: [
        FieldSpec.text(
          'name',
          l.travelTemplateName,
          required: true,
          hint: l.travelTemplateNameHint,
          validator: (v, _) => (v as String?)?.trim().isEmpty ?? true ? l.travelTemplateNameRequired : null,
        ),
      ],
      initial: {'name': ?suggestedName},
    );
    final name = (r?['name'] as String?)?.trim();
    if (name == null || name.isEmpty || !context.mounted) return;
    final t = await service.saveAsTemplate(tripId, name);
    Fx.fire(Sfx.sparkle);
    if (context.mounted) {
      await _toast(context, l.travelTemplateSaved(name), () async {
        await service.deleteTemplate(t);
      });
    }
  }

  // ---------------------------------------------------------- templates --

  static Future<PackingTemplateRow?> addTemplate(BuildContext context, WidgetRef ref, {bool open = true}) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final r = await showEditSheet(
      context,
      title: l.travelTemplateNew,
      icon: Icons.inventory_2_rounded,
      fields: [
        FieldSpec.text(
          'name',
          l.travelTemplateName,
          required: true,
          hint: l.travelTemplateNameHint,
          autofocus: true,
          validator: (v, _) => (v as String?)?.trim().isEmpty ?? true ? l.travelTemplateNameRequired : null,
        ),
      ],
    );
    final name = (r?['name'] as String?)?.trim();
    if (name == null || name.isEmpty || !context.mounted) return null;
    final row = await service.addTemplate(name, const []);
    if (open && context.mounted) openTemplate(context, row.id);
    return row;
  }

  static Future<UndoableAction?> renameTemplate(BuildContext context, WidgetRef ref, PackingTemplateRow t) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final r = await showEditSheet(
      context,
      title: l.travelTemplateRename,
      icon: Icons.edit_rounded,
      fields: [
        FieldSpec.text(
          'name',
          l.travelTemplateName,
          required: true,
          validator: (v, _) => (v as String?)?.trim().isEmpty ?? true ? l.travelTemplateNameRequired : null,
        ),
      ],
      initial: {'name': t.name},
    );
    final name = (r?['name'] as String?)?.trim();
    if (name == null || name.isEmpty || !context.mounted) return null;
    final undo = await service.editTemplate(t, name: name);
    return UndoableAction(label: l.travelUndoSaved, undo: undo);
  }

  static Future<UndoableAction?> duplicateTemplate(BuildContext context, WidgetRef ref, PackingTemplateRow t) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final (_, undo) = await service.duplicateTemplate(t, name: l.travelTemplateCopy(t.name));
    return UndoableAction(label: l.travelUndoTemplateDuplicated, undo: undo);
  }

  static Future<UndoableAction?> deleteTemplate(BuildContext context, WidgetRef ref, PackingTemplateRow t) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final undo = await service.deleteTemplate(t);
    return UndoableAction(label: l.travelUndoTemplateDeleted, undo: undo);
  }

  static Future<void> addStarterTemplates(BuildContext context, WidgetRef ref) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final undo = await service.addTemplates(starterTemplates(l));
    Fx.fire(Sfx.sparkle);
    if (context.mounted) await _toast(context, l.travelTemplatesStarterAdded, undo);
  }

  /// Saves a template's edited item list (no toast: the editor shows one).
  static Future<TravelUndo> setTemplateItems(WidgetRef ref, PackingTemplateRow t, List<PackingTemplateItem> items) =>
      _service(ref).editTemplate(t, items: items);

  // ---------------------------------------------------------- documents --

  static Future<TravelDocumentRow?> addDocument(BuildContext context, WidgetRef ref) async {
    final service = _service(ref);
    final draft = await showDocumentSheet(context);
    if (draft == null) return null;
    return service.addDocument(draft);
  }

  static Future<UndoableAction?> editDocument(BuildContext context, WidgetRef ref, TravelDocumentRow d) async {
    final service = _service(ref);
    final draft = await showDocumentSheet(context, document: d);
    if (draft == null || !context.mounted) return null;
    final l = L10n.of(context);
    final undo = await service.editDocument(d, draft);
    return UndoableAction(label: l.travelUndoSaved, undo: undo);
  }

  static Future<UndoableAction?> duplicateDocument(BuildContext context, WidgetRef ref, TravelDocumentRow d) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final (_, undo) = await service.duplicateDocument(d);
    return UndoableAction(label: l.travelUndoDocDuplicated, undo: undo);
  }

  static Future<UndoableAction?> deleteDocument(BuildContext context, WidgetRef ref, TravelDocumentRow d) async {
    final service = _service(ref);
    final l = L10n.of(context);
    final undo = await service.deleteDocument(d);
    return UndoableAction(label: l.travelUndoDocDeleted, undo: undo);
  }

  /// Picks how far ahead a document reminds (the move sheet as a picker).
  static Future<UndoableAction?> pickReminder(BuildContext context, WidgetRef ref, TravelDocumentRow d) async {
    final service = _service(ref);
    final tx = TravelTexts.of(context);
    final choices = {...TravelTexts.remindChoices, d.remindDaysBefore}.toList()..sort();
    final target = await showMoveSheet(
      context,
      title: tx.l.travelDocRemind,
      icon: Icons.notifications_active_rounded,
      targets: [
        for (final c in choices)
          MoveTarget(
            id: '$c',
            label: tx.remindLabel(c),
            icon: c == 0 ? Icons.event_rounded : Icons.notifications_rounded,
            isCurrent: c == d.remindDaysBefore,
          ),
      ],
    );
    final days = int.tryParse(target?.id ?? '');
    if (days == null || days == d.remindDaysBefore || !context.mounted) return null;
    final undo = await service.setRemindDays(d, days);
    return UndoableAction(label: tx.l.travelUndoReminder(tx.remindLabel(days)), undo: undo);
  }
}
