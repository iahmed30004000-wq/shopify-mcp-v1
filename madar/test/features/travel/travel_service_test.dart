import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:madar/features/travel/data/travel_service.dart';
import 'package:madar/features/travel/domain/packing.dart';
import 'package:madar/features/travel/domain/starter_templates.dart';
import 'package:madar/features/travel/domain/trip_timeline.dart';

import 'travel_harness.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late TravelService service;
  final now = DateTime(2026, 9, 29, 13, 10);

  setUp(() {
    db = travelTestDatabase();
    repos = Repositories(db);
    service = TravelService(repos, clock: () => now);
  });

  tearDown(() => db.close());

  Future<List<ActivityRow>> travelActivity() => repos.activity.since(DateTime(2000), planetKey: 'travel');

  TripDraft draft({String dest = 'Istanbul', DateTime? start, DateTime? end, TripStatus? status}) =>
      TripDraft(destination: dest, startDate: start, endDate: end, status: status, latitude: 41.0, longitude: 28.97);

  group('trips', () {
    test('a new trip takes its status from its dates and logs activity', () async {
      final soon = await service.addTrip(draft(start: DateTime(2026, 10, 8), end: DateTime(2026, 10, 14)));
      final now_ = await service.addTrip(draft(dest: 'Cairo', start: DateTime(2026, 9, 27), end: DateTime(2026, 10, 2)));
      final gone = await service.addTrip(draft(dest: 'Doha', start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 5)));
      expect(soon.status, TripStatus.planned);
      expect(now_.status, TripStatus.active);
      expect(gone.status, TripStatus.done);
      expect((await travelActivity()).where((a) => a.kind == TravelActivity.tripAdded).length, 3);
      expect(await service.manualStatusIds(), isEmpty);
    });

    test('a manual status sticks, and "follow the dates" gives it back', () async {
      final trip = await service.addTrip(draft(start: DateTime(2026, 10, 8), end: DateTime(2026, 10, 14)));
      final undo = await service.setStatus(trip, TripStatus.done);
      expect((await repos.trips.byId(trip.id))!.status, TripStatus.done);
      expect(await service.manualStatusIds(), {trip.id});
      expect((await travelActivity()).any((a) => a.kind == TravelActivity.tripFinished), isTrue);
      // The sync leaves manual trips alone.
      expect(await service.syncStatuses(), 0);
      await undo();
      expect((await repos.trips.byId(trip.id))!.status, TripStatus.planned);
      expect(await service.manualStatusIds(), isEmpty);
      expect((await travelActivity()).any((a) => a.kind == TravelActivity.tripFinished), isFalse);

      await service.setStatus(trip, TripStatus.active);
      await service.setStatus((await repos.trips.byId(trip.id))!, null);
      expect((await repos.trips.byId(trip.id))!.status, TripStatus.planned);
      expect(await service.manualStatusIds(), isEmpty);
    });

    test('the status sync writes date-derived statuses', () async {
      final trip = await service.addTrip(draft(start: DateTime(2026, 10, 8), end: DateTime(2026, 10, 14)));
      final later = TravelService(repos, clock: () => DateTime(2026, 10, 9, 9));
      expect(await later.syncStatuses(), 1);
      expect((await repos.trips.byId(trip.id))!.status, TripStatus.active);
      // The destination's calendar decides the last day.
      final after = TravelService(repos, clock: () => DateTime(2026, 10, 15, 9));
      expect(
        await after.syncStatuses(todayByTrip: {trip.id: TravelToday(home: DateTime(2026, 10, 15), destination: DateTime(2026, 10, 14))}),
        0,
      );
      expect(await after.syncStatuses(), 1);
      expect((await repos.trips.byId(trip.id))!.status, TripStatus.done);
    });

    test('editing restores exactly on undo', () async {
      final trip = await service.addTrip(draft(start: DateTime(2026, 10, 8)));
      final undo = await service.editTrip(
        trip,
        const TripDraft(destination: '  Madinah ', notes: '  ', status: TripStatus.active),
      );
      final edited = (await repos.trips.byId(trip.id))!;
      expect(edited.destination, 'Madinah');
      expect(edited.notes, isNull);
      expect(edited.startDate, isNull);
      expect(edited.status, TripStatus.active);
      expect(await service.manualStatusIds(), {trip.id});
      await undo();
      final back = (await repos.trips.byId(trip.id))!;
      expect(back.destination, trip.destination);
      expect(back.startDate, trip.startDate);
      expect(await service.manualStatusIds(), isEmpty);
    });

    test('deleting a trip takes its list and activity; undo brings them back', () async {
      final trip = await service.addTrip(draft(start: DateTime(2026, 10, 8)));
      final item = await service.addItem(trip.id, 'Charger', category: PackingCategories.electronics);
      await service.togglePacked(item);
      final undo = await service.deleteTrip(trip);
      expect(await repos.trips.byId(trip.id), isNull);
      expect(await repos.tripItems.count(), 0);
      expect(await travelActivity(), isEmpty);
      await undo();
      expect(await repos.trips.byId(trip.id), isNotNull);
      expect((await repos.tripItems.byId(item.id))!.packed, isTrue);
      expect(await travelActivity(), hasLength(3));
    });

    test('duplicating copies the list unpacked', () async {
      final trip = await service.addTrip(draft(start: DateTime(2026, 10, 8)));
      final item = await service.addItem(trip.id, 'Charger');
      await service.togglePacked(item);
      final (copy, undo) = await service.duplicateTrip(trip);
      final copied = await repos.tripItems.getAll(where: (t) => t.tripId.equals(copy.id));
      expect(copied.single.body, 'Charger');
      expect(copied.single.packed, isFalse);
      await undo();
      expect(await repos.trips.byId(copy.id), isNull);
      expect(await repos.tripItems.count(), 1);
    });
  });

  group('packing', () {
    test('packing the last item logs "all packed"; undo removes it', () async {
      final trip = await service.addTrip(draft());
      final a = await service.addItem(trip.id, 'A');
      final b = await service.addItem(trip.id, 'B');
      final first = await service.togglePacked(a);
      expect(first.after, const PackingProgress(1, 2));
      final last = await service.togglePacked(b);
      expect(last.after.completes(last.before), isTrue);
      final kinds = (await travelActivity()).map((x) => x.kind).toList();
      expect(kinds.where((k) => k == TravelActivity.itemPacked).length, 2);
      expect(kinds, contains(TravelActivity.allPacked));
      await last.undo();
      expect((await repos.tripItems.byId(b.id))!.packed, isFalse);
      expect((await travelActivity()).map((x) => x.kind), isNot(contains(TravelActivity.allPacked)));
      // Unpacking removes the item's activity too.
      await service.togglePacked((await repos.tripItems.byId(a.id))!);
      expect((await travelActivity()).where((x) => x.kind == TravelActivity.itemPacked), isEmpty);
    });

    test('drag results: order and new categories are stored', () async {
      final trip = await service.addTrip(draft());
      final a = await service.addItem(trip.id, 'A', category: PackingCategories.clothes);
      final b = await service.addItem(trip.id, 'B', category: PackingCategories.clothes);
      await service.reorderItems([b.id, a.id], recategorize: {a.id: PackingCategories.documents});
      final items = await repos.tripItems.getAll(where: (t) => t.tripId.equals(trip.id));
      expect(items.map((i) => i.body), ['B', 'A']);
      expect(items.last.category, PackingCategories.documents);
      // "Other" is stored as no category.
      await service.moveItem(items.last, PackingCategories.misc);
      expect((await repos.tripItems.byId(a.id))!.category, isNull);
    });

    test('templates merge without duplicates; undo removes what was added', () async {
      final trip = await service.addTrip(draft());
      await service.addItem(trip.id, 'Phone charger', category: PackingCategories.electronics);
      final t1 = await service.addTemplate('Essentials', const [
        PackingTemplateItem('phone charger', PackingCategories.electronics),
        PackingTemplateItem('Passport', PackingCategories.documents),
      ]);
      final t2 = await service.addTemplate('Business', const [
        PackingTemplateItem('Passport', PackingCategories.documents),
        PackingTemplateItem('Laptop', PackingCategories.electronics),
      ]);
      final (added, undo) = await service.applyTemplates(trip.id, [t1, t2]);
      expect(added, 2);
      final items = await repos.tripItems.getAll(where: (t) => t.tripId.equals(trip.id));
      expect(items.map((i) => (i.body, i.category)), [
        ('Phone charger', PackingCategories.electronics),
        ('Passport', PackingCategories.documents),
        ('Laptop', PackingCategories.electronics),
      ]);
      await undo();
      expect(await repos.tripItems.count(), 1);
    });

    test('a trip list saved as a template keeps categories, grouped', () async {
      final trip = await service.addTrip(draft());
      await service.addItem(trip.id, 'Laptop', category: PackingCategories.electronics);
      await service.addItem(trip.id, 'Passport', category: PackingCategories.documents);
      await service.addItem(trip.id, 'Book');
      final t = await service.saveAsTemplate(trip.id, 'My list');
      expect(PackingTemplateMath.decodeAll(t.items), const [
        PackingTemplateItem('Passport', PackingCategories.documents),
        PackingTemplateItem('Laptop', PackingCategories.electronics),
        PackingTemplateItem('Book'),
      ]);
    });

    test('starter templates are ordinary, deletable templates', () async {
      final l = lookupL10n(const Locale('ar'));
      final undo = await service.addTemplates(starterTemplates(l));
      final all = await repos.packingTemplates.getAll();
      expect(all.map((t) => t.name), [l.travelStarterEssentials, l.travelStarterBusiness, l.travelStarterUmrah, l.travelStarterWinter]);
      final del = await service.deleteTemplate(all.first);
      expect(await repos.packingTemplates.count(), 3);
      await del();
      await undo();
      expect(await repos.packingTemplates.count(), 0);
    });
  });

  group('documents', () {
    test('add, renew (logged), delete with undo', () async {
      final d = await service.addDocument(DocumentDraft(name: ' Passport ', expiry: DateTime(2027, 1, 1), holder: ''));
      expect(d.name, 'Passport');
      expect(d.holder, isNull);
      expect(d.remindDaysBefore, 30);
      final undo = await service.editDocument(d, DocumentDraft(name: 'Passport', expiry: DateTime(2037, 1, 1)));
      expect((await travelActivity()).map((a) => a.kind), contains(TravelActivity.documentRenewed));
      await undo();
      expect((await repos.travelDocuments.byId(d.id))!.expiry, DateTime(2027, 1, 1));
      expect((await travelActivity()).map((a) => a.kind), isNot(contains(TravelActivity.documentRenewed)));
      final del = await service.deleteDocument(d);
      expect(await repos.travelDocuments.count(), 0);
      await del();
      expect(await repos.travelDocuments.count(), 1);
    });
  });
}
