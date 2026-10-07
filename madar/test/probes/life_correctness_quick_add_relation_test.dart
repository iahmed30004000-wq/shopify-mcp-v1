// Probe (Life integration, H2): «اتصلت بأبوي» / «كلمت امي» from the home
// quick-add must reach the one person saved with that relation – the
// everyday Jordanian spellings included – instead of creating a new person
// named after the word.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/quick_add/parser.dart';
import 'package:madar/features/home/domain/prayer_day.dart';
import 'package:madar/features/home/domain/quick_add_handlers.dart';

import '../helpers/test_app.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  final now = DateTime(2026, 9, 27, 13, 10);

  setUp(() async {
    db = testDatabase();
    await db.customSelect('SELECT 1').get();
    repos = Repositories(db);
  });

  tearDown(() => db.close());

  final handler = shellQuickAddHandler(
    QuickAddContext(
      repositories: () => repos,
      clock: () => now,
      prayerDay: () => PrayerDayTimes.placeholder,
      focusedWindow: () => PrayerWindow.dhuhr,
      defaultWalletName: () => 'المحفظة',
    ),
  );

  for (final (typed, relation) in const [
    ('اتصلت بأبوي', 'father'), // the parser's own example (parser_test)
    ('كلمت امي امبارح', 'mother'), // no hamza – how it is usually typed
    ('اتصلت بإمي', 'mother'),
    ('زرت اخوي', 'brother'),
  ]) {
    test('«$typed» reaches the one person whose relation is $relation', () async {
      final person = await repos.people.insert(PeopleCompanion.insert(name: 'سالم', relation: Value(relation)));
      final intent = QuickAddParser.parse(typed, now: now);
      expect(intent.kind, QuickAddKind.contact, reason: 'the parser reads a contact');
      expect(await handler.handle(intent), isTrue);
      final people = await repos.people.getAll();
      expect(people.map((p) => p.name).toList(), [
        'سالم',
      ], reason: 'no new person named «${intent.title}» next to the saved $relation');
      expect((await repos.contactLogs.getAll()).single.personId, person.id);
    });
  }
}
