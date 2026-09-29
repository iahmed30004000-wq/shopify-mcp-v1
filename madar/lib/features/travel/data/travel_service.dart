import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../../../core/domain/enums.dart';
import '../domain/packing.dart';
import '../domain/trip_timeline.dart';

/// Restores the exact state before a write.
typedef TravelUndo = Future<void> Function();

/// What a trip editor returns.
@immutable
class TripDraft {
  const TripDraft({
    required this.destination,
    this.country,
    this.latitude,
    this.longitude,
    this.startDate,
    this.endDate,
    this.notes,
    this.color,
    this.status,
  });

  final String destination;

  /// ISO code of a listed city's country, or free text.
  final String? country;
  final double? latitude;
  final double? longitude;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final int? color;

  /// A manual status, or null to follow the dates.
  final TripStatus? status;

  static TripDraft of(TripRow row, {TripStatus? manualStatus}) => TripDraft(
    destination: row.destination,
    country: row.country,
    latitude: row.latitude,
    longitude: row.longitude,
    startDate: row.startDate,
    endDate: row.endDate,
    notes: row.notes,
    color: row.color,
    status: manualStatus,
  );
}

/// What a document editor returns.
@immutable
class DocumentDraft {
  const DocumentDraft({
    required this.name,
    this.holder,
    this.number,
    this.expiry,
    this.remindDaysBefore = 30,
    this.notes,
  });

  final String name;
  final String? holder;
  final String? number;
  final DateTime? expiry;
  final int remindDaysBefore;
  final String? notes;
}

/// Activity kinds logged on the Travel planet.
abstract final class TravelActivity {
  static const planetKey = 'travel';
  static const tripAdded = 'trip.add';
  static const tripFinished = 'trip.done';
  static const itemPacked = 'packing.packed';
  static const allPacked = 'packing.complete';
  static const documentAdded = 'document.add';
  static const documentRenewed = 'document.renew';
}

/// KeyValues keys of the travel feature.
abstract final class TravelKeys {
  /// JSON list of trip ids whose status was set by hand.
  static const manualStatus = 'travel.manualStatus';
}

/// Travel data over the repositories: trips and their packing lists,
/// packing templates and documents. Every write returns an undo that
/// restores the exact prior state; activity is logged on the Travel planet
/// so the orbit and the Neglect Radar see it.
class TravelService {
  TravelService(this.repos, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final Repositories repos;
  final DateTime Function() _clock;

  DateTime get now => _clock();

  // ------------------------------------------------------------- reads --

  Stream<List<TripRow>> watchTrips() => repos.trips.watchAll();
  Stream<TripRow?> watchTrip(String id) => repos.trips.watchById(id);
  Stream<List<TripItemRow>> watchItems(String tripId) => repos.tripItems.watchAll(where: (t) => t.tripId.equals(tripId));
  Stream<List<TripItemRow>> watchAllItems() => repos.tripItems.watchAll();
  Stream<List<PackingTemplateRow>> watchTemplates() => repos.packingTemplates.watchAll();
  Stream<PackingTemplateRow?> watchTemplate(String id) => repos.packingTemplates.watchById(id);
  Stream<List<TravelDocumentRow>> watchDocuments() => repos.travelDocuments.watchAll();

  Stream<Set<String>> watchManualStatus() => repos.keyValues.watchJson(TravelKeys.manualStatus).map(_idSet);

  Future<Set<String>> manualStatusIds() async => _idSet(await repos.keyValues.getJson(TravelKeys.manualStatus));

  static Set<String> _idSet(Object? json) => json is List ? {for (final v in json) '$v'} : <String>{};

  Future<void> _setManual(String id, bool manual) async {
    final ids = await manualStatusIds();
    final changed = manual ? ids.add(id) : ids.remove(id);
    if (changed) await repos.keyValues.setJson(TravelKeys.manualStatus, (ids.toList()..sort()));
  }

  // ------------------------------------------------------------- trips --

  TripsCompanion _tripCompanion(TripDraft d, TripStatus status) => TripsCompanion(
    destination: Value(d.destination.trim()),
    country: Value(_blank(d.country)),
    latitude: Value(d.latitude),
    longitude: Value(d.longitude),
    startDate: Value(d.startDate),
    endDate: Value(d.endDate),
    status: Value(status),
    notes: Value(_blank(d.notes)),
    color: Value(d.color),
  );

  TripStatus _statusFor(TripDraft d) =>
      d.status ?? TripTimeline(start: d.startDate, end: d.endDate).derive(TravelToday.at(now));

  Future<TripRow> addTrip(TripDraft draft) async {
    final row = await repos.trips.insert(_tripCompanion(draft, _statusFor(draft)));
    if (draft.status != null) await _setManual(row.id, true);
    await repos.activity.log(
      planetKey: TravelActivity.planetKey,
      kind: TravelActivity.tripAdded,
      refTable: 'trips',
      refId: row.id,
    );
    return row;
  }

  Future<TravelUndo> editTrip(TripRow before, TripDraft draft) async {
    final wasManual = (await manualStatusIds()).contains(before.id);
    final status = _statusFor(draft);
    await repos.trips.update(
      before.copyWith(
        destination: draft.destination.trim(),
        country: Value(_blank(draft.country)),
        latitude: Value(draft.latitude),
        longitude: Value(draft.longitude),
        startDate: Value(draft.startDate),
        endDate: Value(draft.endDate),
        status: status,
        notes: Value(_blank(draft.notes)),
        color: Value(draft.color),
      ),
    );
    await _setManual(before.id, draft.status != null);
    return () async {
      await repos.trips.update(before);
      await _setManual(before.id, wasManual);
    };
  }

  /// Sets a manual [status], or (null) goes back to following the dates.
  Future<TravelUndo> setStatus(TripRow trip, TripStatus? status) async {
    final wasManual = (await manualStatusIds()).contains(trip.id);
    final next =
        status ??
        TripTimeline(start: trip.startDate, end: trip.endDate).derive(TravelToday.at(now));
    await repos.trips.setColumn(trip.id, 'status', next);
    await _setManual(trip.id, status != null);
    final logged = status == TripStatus.done && trip.status != TripStatus.done
        ? await repos.activity.log(
            planetKey: TravelActivity.planetKey,
            kind: TravelActivity.tripFinished,
            refTable: 'trips',
            refId: trip.id,
          )
        : null;
    return () async {
      await repos.trips.setColumn(trip.id, 'status', trip.status);
      await _setManual(trip.id, wasManual);
      if (logged != null) {
        await repos.activity.removeFor(refTable: 'trips', refId: trip.id, kind: TravelActivity.tripFinished);
      }
    };
  }

  /// Stores the date-derived status of every trip that follows its dates
  /// (the orbit reads the stored column). Returns how many changed.
  Future<int> syncStatuses({Map<String, TravelToday>? todayByTrip}) async {
    final manual = await manualStatusIds();
    var changed = 0;
    for (final t in await repos.trips.getAll()) {
      if (manual.contains(t.id)) continue;
      final today = todayByTrip?[t.id] ?? TravelToday.at(now);
      final derived = TripTimeline(start: t.startDate, end: t.endDate).derive(today);
      if (derived != t.status) {
        await repos.trips.setColumn(t.id, 'status', derived);
        changed++;
      }
    }
    return changed;
  }

  /// A copy of [trip] right after it (its packing list unpacked, no dates
  /// kept manual).
  Future<(TripRow, TravelUndo)> duplicateTrip(TripRow trip) async {
    final copy = await repos.trips.duplicate(trip.id);
    final items = await repos.tripItems.getAll(where: (t) => t.tripId.equals(trip.id));
    for (final i in items) {
      await repos.tripItems.insert(
        TripItemsCompanion.insert(tripId: copy.id, body: i.body, category: Value(i.category)),
      );
    }
    if ((await manualStatusIds()).contains(trip.id)) await _setManual(copy.id, true);
    return (
      copy,
      () async {
        await repos.tripItems.deleteWhere((t) => t.tripId.equals(copy.id));
        await repos.trips.delete(copy.id);
        await _setManual(copy.id, false);
      },
    );
  }

  /// Deletes [trip], its packing list and its activity.
  Future<TravelUndo> deleteTrip(TripRow trip) async {
    final wasManual = (await manualStatusIds()).contains(trip.id);
    final items = await repos.tripItems.deleteWhere((t) => t.tripId.equals(trip.id));
    final activity = <ActivityRow>[
      ...await repos.activity.removeFor(refTable: 'trips', refId: trip.id),
      for (final i in items) ...await repos.activity.removeFor(refTable: 'trip_items', refId: i.id),
    ];
    final row = await repos.trips.delete(trip.id);
    await _setManual(trip.id, false);
    return () async {
      if (row != null) await repos.trips.restore(row);
      await repos.tripItems.restoreAll(items);
      await repos.activityLog.restoreAll(activity);
      if (wasManual) await _setManual(trip.id, true);
    };
  }

  // ----------------------------------------------------------- packing --

  Future<TripItemRow> addItem(String tripId, String body, {String? category}) => repos.tripItems.insert(
    TripItemsCompanion.insert(tripId: tripId, body: body.trim(), category: Value(_category(category))),
  );

  Future<TravelUndo> editItem(TripItemRow before, {required String body, String? category}) async {
    await repos.tripItems.update(before.copyWith(body: body.trim(), category: Value(_category(category))));
    return () => repos.tripItems.update(before);
  }

  Future<TravelUndo> moveItem(TripItemRow before, String? category) async {
    await repos.tripItems.setColumn(before.id, 'category', _category(category));
    return () => repos.tripItems.setColumn(before.id, 'category', before.category);
  }

  /// Packs / unpacks [item]. Packing logs activity; packing the last item
  /// also logs "all packed". The undo removes both again.
  Future<({TravelUndo undo, PackingProgress before, PackingProgress after})> togglePacked(TripItemRow item) async {
    final list = await repos.tripItems.getAll(where: (t) => t.tripId.equals(item.tripId));
    final before = PackingProgress.of(list.map((i) => i.packed));
    final packed = !item.packed;
    await repos.tripItems.setColumn(item.id, 'packed', packed);
    final after = PackingProgress.of(list.map((i) => i.id == item.id ? packed : i.packed));
    if (packed) {
      await repos.activity.log(
        planetKey: TravelActivity.planetKey,
        kind: TravelActivity.itemPacked,
        refTable: 'trip_items',
        refId: item.id,
      );
      if (after.completes(before)) {
        await repos.activity.log(
          planetKey: TravelActivity.planetKey,
          kind: TravelActivity.allPacked,
          refTable: 'trips',
          refId: item.tripId,
          value: after.total.toDouble(),
        );
      }
    } else {
      await repos.activity.removeFor(refTable: 'trip_items', refId: item.id, kind: TravelActivity.itemPacked);
      if (before.complete) {
        await repos.activity.removeFor(refTable: 'trips', refId: item.tripId, kind: TravelActivity.allPacked);
      }
    }
    Future<void> undo() async {
      await repos.tripItems.setColumn(item.id, 'packed', item.packed);
      if (packed) {
        await repos.activity.removeFor(refTable: 'trip_items', refId: item.id, kind: TravelActivity.itemPacked);
        if (after.completes(before)) {
          await repos.activity.removeFor(refTable: 'trips', refId: item.tripId, kind: TravelActivity.allPacked);
        }
      }
    }

    return (undo: undo, before: before, after: after);
  }

  /// Unpacks every item of a trip (to reuse the list for the way back).
  Future<TravelUndo> unpackAll(String tripId) async {
    final items = await repos.tripItems.getAll(where: (t) => t.tripId.equals(tripId));
    final packed = [for (final i in items) if (i.packed) i];
    for (final i in packed) {
      await repos.tripItems.setColumn(i.id, 'packed', false);
    }
    return () async {
      for (final i in packed) {
        await repos.tripItems.setColumn(i.id, 'packed', true);
      }
    };
  }

  Future<TravelUndo> deleteItem(TripItemRow item) async {
    final row = await repos.tripItems.delete(item.id);
    final activity = await repos.activity.removeFor(refTable: 'trip_items', refId: item.id);
    return () async {
      if (row != null) await repos.tripItems.restore(row);
      await repos.activityLog.restoreAll(activity);
    };
  }

  /// Stores a dropped packing order: [orderedIds] in order, and new
  /// categories for items dropped under another header.
  Future<void> reorderItems(List<String> orderedIds, {Map<String, String> recategorize = const {}}) async {
    for (final e in recategorize.entries) {
      await repos.tripItems.setColumn(e.key, 'category', _category(e.value));
    }
    await repos.tripItems.reorder(orderedIds);
  }

  /// Adds the items of [templates] the trip does not have yet (see
  /// [PackingTemplateMath.merge]). Returns the number added and the undo.
  Future<(int, TravelUndo)> applyTemplates(String tripId, List<PackingTemplateRow> templates) async {
    final existing = await repos.tripItems.getAll(where: (t) => t.tripId.equals(tripId));
    final toAdd = PackingTemplateMath.merge([
      for (final t in templates) PackingTemplateMath.decodeAll(t.items),
    ], existingBodies: existing.map((i) => i.body));
    final added = <String>[];
    for (final item in toAdd) {
      added.add((await addItem(tripId, item.body, category: item.category)).id);
    }
    return (
      added.length,
      () async {
        await repos.tripItems.deleteWhere((t) => t.id.isIn(added));
      },
    );
  }

  /// Saves a trip's list (items and categories, in order) as a new template.
  Future<PackingTemplateRow> saveAsTemplate(String tripId, String name) async {
    final items = await repos.tripItems.getAll(where: (t) => t.tripId.equals(tripId));
    final groups = PackingLayout.group(items, categoryOf: (i) => i.category, packedOf: (i) => i.packed);
    return addTemplate(name, [
      for (final g in groups)
        for (final i in g.items) PackingTemplateItem(i.body, i.category),
    ]);
  }

  // --------------------------------------------------------- templates --

  Future<PackingTemplateRow> addTemplate(String name, List<PackingTemplateItem> items) =>
      repos.packingTemplates.insert(
        PackingTemplatesCompanion.insert(name: name.trim(), items: Value(PackingTemplateMath.encodeAll(items))),
      );

  Future<TravelUndo> editTemplate(PackingTemplateRow before, {String? name, List<PackingTemplateItem>? items}) async {
    await repos.packingTemplates.update(
      before.copyWith(
        name: name?.trim() ?? before.name,
        items: items == null ? before.items : PackingTemplateMath.encodeAll(items),
      ),
    );
    return () => repos.packingTemplates.update(before);
  }

  Future<(PackingTemplateRow, TravelUndo)> duplicateTemplate(PackingTemplateRow t, {String? name}) async {
    final copy = await repos.packingTemplates.duplicate(t.id, overrides: {'name': ?name});
    return (
      copy,
      () async {
        await repos.packingTemplates.delete(copy.id);
      },
    );
  }

  Future<TravelUndo> deleteTemplate(PackingTemplateRow t) async {
    final row = await repos.packingTemplates.delete(t.id);
    return () async {
      if (row != null) await repos.packingTemplates.restore(row);
    };
  }

  Future<void> reorderTemplates(List<String> ids) => repos.packingTemplates.reorder(ids);

  /// Inserts generic starter templates (names and items in the UI
  /// language). Returns the undo.
  Future<TravelUndo> addTemplates(List<({String name, List<PackingTemplateItem> items})> templates) async {
    final ids = <String>[];
    for (final t in templates) {
      ids.add((await addTemplate(t.name, t.items)).id);
    }
    return () async {
      await repos.packingTemplates.deleteWhere((t) => t.id.isIn(ids));
    };
  }

  // --------------------------------------------------------- documents --

  TravelDocumentsCompanion _docCompanion(DocumentDraft d) => TravelDocumentsCompanion(
    name: Value(d.name.trim()),
    holder: Value(_blank(d.holder)),
    number: Value(_blank(d.number)),
    expiry: Value(d.expiry),
    remindDaysBefore: Value(d.remindDaysBefore.clamp(0, 3650)),
    notes: Value(_blank(d.notes)),
  );

  Future<TravelDocumentRow> addDocument(DocumentDraft draft) async {
    final row = await repos.travelDocuments.insert(_docCompanion(draft));
    await repos.activity.log(
      planetKey: TravelActivity.planetKey,
      kind: TravelActivity.documentAdded,
      refTable: 'travel_documents',
      refId: row.id,
    );
    return row;
  }

  /// Saves [draft] over [before]; a later expiry counts as a renewal.
  Future<TravelUndo> editDocument(TravelDocumentRow before, DocumentDraft draft) async {
    await repos.travelDocuments.update(
      before.copyWith(
        name: draft.name.trim(),
        holder: Value(_blank(draft.holder)),
        number: Value(_blank(draft.number)),
        expiry: Value(draft.expiry),
        remindDaysBefore: draft.remindDaysBefore.clamp(0, 3650),
        notes: Value(_blank(draft.notes)),
      ),
    );
    final renewed = before.expiry != null && draft.expiry != null && draft.expiry!.isAfter(before.expiry!);
    final logged = renewed
        ? await repos.activity.log(
            planetKey: TravelActivity.planetKey,
            kind: TravelActivity.documentRenewed,
            refTable: 'travel_documents',
            refId: before.id,
          )
        : null;
    return () async {
      await repos.travelDocuments.update(before);
      if (logged != null) {
        await repos.activity.removeFor(
          refTable: 'travel_documents',
          refId: before.id,
          kind: TravelActivity.documentRenewed,
        );
      }
    };
  }

  Future<(TravelDocumentRow, TravelUndo)> duplicateDocument(TravelDocumentRow d) async {
    final copy = await repos.travelDocuments.duplicate(d.id);
    return (
      copy,
      () async {
        await repos.travelDocuments.delete(copy.id);
      },
    );
  }

  Future<TravelUndo> deleteDocument(TravelDocumentRow d) async {
    final row = await repos.travelDocuments.delete(d.id);
    final activity = await repos.activity.removeFor(refTable: 'travel_documents', refId: d.id);
    return () async {
      if (row != null) await repos.travelDocuments.restore(row);
      await repos.activityLog.restoreAll(activity);
    };
  }

  /// Changes only how many days ahead a document reminds.
  Future<TravelUndo> setRemindDays(TravelDocumentRow d, int days) async {
    await repos.travelDocuments.setColumn(d.id, 'remindDaysBefore', days.clamp(0, 3650));
    return () => repos.travelDocuments.setColumn(d.id, 'remindDaysBefore', d.remindDaysBefore);
  }

  // ----------------------------------------------------------- helpers --

  static String? _blank(String? s) {
    final v = s?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  static String? _category(String? c) {
    final v = c?.trim();
    return v == null || v.isEmpty || v == PackingCategories.misc ? null : v;
  }
}
