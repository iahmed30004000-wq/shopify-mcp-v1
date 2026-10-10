import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/features/orbit/presentation/planet/moon_sheet.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late MoonRecords records;
  final now = DateTime(2026, 9, 27, 18, 40);

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    records = MoonRecords(repos, clock: () => now);
  });
  tearDown(() => db.close());

  test('reads every kind of record behind a moon; a gone record is null', () async {
    final mum = await repos.people.insert(
      PeopleCompanion.insert(name: 'Mum', lastContact: Value(DateTime(2026, 9, 20))),
    );
    final wallet = await repos.wallets.insert(WalletsCompanion.insert(name: 'Cash', currency: 'JOD'));
    final board = await repos.boards.insert(BoardsCompanion.insert(name: 'Jordan'));
    final trip = await repos.trips.insert(
      TripsCompanion.insert(destination: 'Istanbul', startDate: Value(DateTime(2026, 10, 2))),
    );
    final module = await repos.customModules.insert(CustomModulesCompanion.insert(name: 'Reading', color: 0xFF4CC96B));

    final person = await records.read('people', mum.id);
    expect(person?.name, 'Mum');
    expect(person?.lastContact, DateTime(2026, 9, 20));
    expect((await records.read('wallets', wallet.id))?.name, 'Cash');
    expect((await records.read('boards', board.id))?.name, 'Jordan');
    final t = await records.read('trips', trip.id);
    expect(t?.name, 'Istanbul');
    expect(t?.startDate, DateTime(2026, 10, 2));
    expect((await records.read('custom_modules', module.id))?.name, 'Reading');
    expect(await records.read('people', 'missing'), isNull);
    expect(await records.read('unknown_table', mum.id), isNull);
  });

  test('rename writes the name column (a trip\'s destination) and undoes exactly', () async {
    final trip = await repos.trips.insert(TripsCompanion.insert(destination: 'Istanbul'));
    final wallet = await repos.wallets.insert(WalletsCompanion.insert(name: 'Cash', currency: 'JOD'));
    expect(MoonRecords.nameColumn('trips'), 'destination');
    expect(MoonRecords.nameColumn('wallets'), 'name');

    final undoTrip = await records.rename('trips', trip.id, 'Amman');
    final undoWallet = await records.rename('wallets', wallet.id, 'Pocket');
    expect((await repos.trips.byId(trip.id))!.destination, 'Amman');
    expect((await repos.wallets.byId(wallet.id))!.name, 'Pocket');

    await undoTrip();
    await undoWallet();
    expect((await repos.trips.byId(trip.id))!.destination, 'Istanbul');
    expect((await repos.wallets.byId(wallet.id))!.name, 'Cash');
  });

  test('in touch today logs a contact like the quick-add bar; the undo removes only it', () async {
    final before = DateTime(2026, 9, 20);
    final mum = await repos.people.insert(PeopleCompanion.insert(name: 'Mum', lastContact: Value(before)));
    final earlier = await repos.contactLogs.insert(ContactLogsCompanion.insert(personId: mum.id, at: before));
    final recorded = <(String, String, String, String, DateTime)>[];
    Future<void> record(String planet, String kind, String table, String id, DateTime at) async {
      recorded.add((planet, kind, table, id, at));
      await repos.activity.log(planetKey: planet, kind: kind, refTable: table, refId: id, at: at);
    }

    final undo = await records.logContact(mum.id, planetKey: 'family', record: record);

    expect((await repos.people.byId(mum.id))!.lastContact, now);
    final logs = await repos.contactLogs.getAll();
    expect(logs, hasLength(2));
    final added = logs.singleWhere((l) => l.id != earlier.id);
    expect((added.personId, added.at), (mum.id, now));
    expect(recorded.single, ('family', MoonRecords.contactKind, MoonRecords.contactTable, added.id, now));
    expect(await repos.activity.since(DateTime(2026), kind: MoonRecords.contactKind), hasLength(1));

    await undo();

    expect((await repos.people.byId(mum.id))!.lastContact, before);
    expect((await repos.contactLogs.getAll()).map((l) => l.id), [earlier.id], reason: 'the earlier contact stays');
    expect(await repos.activity.since(DateTime(2026), kind: MoonRecords.contactKind), isEmpty);
  });

  test('a later last contact is never moved back by "in touch today"', () async {
    final later = now.add(const Duration(days: 1));
    final p = await repos.people.insert(PeopleCompanion.insert(name: 'Dad', lastContact: Value(later)));
    final undo = await records.logContact(p.id, planetKey: 'family', record: (_, _, _, _, _) async {});
    expect((await repos.people.byId(p.id))!.lastContact, later);
    await undo();
    expect((await repos.people.byId(p.id))!.lastContact, later);
    expect(await repos.contactLogs.getAll(), isEmpty);
  });
}
