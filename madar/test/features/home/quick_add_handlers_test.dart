import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/quick_add/parser.dart';
import 'package:madar/features/home/domain/prayer_day.dart';
import 'package:madar/features/home/domain/quick_add_handlers.dart';

import '../../helpers/test_app.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  final now = DateTime(2026, 9, 27, 13, 10);
  var focused = PrayerWindow.dhuhr;

  setUp(() async {
    db = testDatabase();
    await db.customSelect('SELECT 1').get(); // migrate + seed (currencies, planets …)
    repos = Repositories(db);
    focused = PrayerWindow.dhuhr;
  });

  tearDown(() => db.close());

  final handler = shellQuickAddHandler(
    QuickAddContext(
      repositories: () => repos,
      clock: () => now,
      prayerDay: () => PrayerDayTimes.placeholder,
      focusedWindow: () => focused,
      defaultWalletName: () => 'المحفظة',
    ),
  );

  Future<bool> add(String text) => handler.handle(QuickAddParser.parse(text, now: now));

  test('an unscheduled task lands in the focused window, today', () async {
    focused = PrayerWindow.maghrib;
    expect(await add('اشتري خبز'), isTrue);
    final task = (await repos.tasks.getAll()).single;
    expect(task.window, PrayerWindow.maghrib);
    expect(task.date, DateTime(2026, 9, 27));
    expect(task.done, isFalse);
  });

  test('a stated prayer window and day are kept', () async {
    expect(await add('بكرا بعد المغرب اجتماع مع فريق مصر'), isTrue);
    final task = (await repos.tasks.getAll()).single;
    expect(task.window, PrayerWindow.maghrib);
    expect(task.date, DateTime(2026, 9, 28));
    expect(task.title, contains('اجتماع'));
    expect(task.planetKey, 'work');
  });

  test('a clock time picks its window', () async {
    final intent = QuickAddParser.parse('meeting at 16:30', now: now);
    expect(intent.kind, QuickAddKind.task);
    expect(await handler.handle(intent), isTrue);
    expect((await repos.tasks.getAll()).single.window, PrayerWindow.asr);
  });

  test('an expense goes into a wallet created on demand in the base currency', () async {
    expect(await repos.wallets.count(), 0);
    expect(await add('صرفت 12.5 دينار بنزين'), isTrue);
    final wallet = (await repos.wallets.getAll()).single;
    expect(wallet.name, 'المحفظة');
    expect(wallet.currency, 'JOD');
    final tx = (await repos.transactions.getAll()).single;
    expect(tx.kind, TxKind.expense);
    expect(tx.amountMilli, 12500);
    expect(tx.walletId, wallet.id);
    final activity = await repos.activity.since(DateTime(2026, 9, 27));
    expect(activity.single.planetKey, 'money');
  });

  test('income in another currency gets its own wallet; the same currency reuses it', () async {
    expect(await add('spent 5 JD coffee'), isTrue);
    expect(await add('received 100 USD salary'), isTrue);
    expect(await add('spent 3 JD tea'), isTrue);
    final wallets = await repos.wallets.getAll();
    expect(wallets.map((w) => w.currency).toSet(), {'JOD', 'USD'});
    expect(wallets.firstWhere((w) => w.currency == 'USD').name, 'المحفظة · USD');
    final txs = await repos.transactions.getAll();
    expect(txs, hasLength(3));
    expect(txs.where((t) => t.kind == TxKind.income).single.amountMilli, 100000);
  });

  test('a contact by relation reaches the one person with it; never a guess between two', () async {
    final mum = await repos.people.insert(PeopleCompanion.insert(name: 'فاطمة', relation: const Value('mother')));
    expect(await add('اتصلت بأمي'), isTrue);
    expect(await repos.people.count(), 1, reason: 'no new «أمي»');
    expect((await repos.contactLogs.getAll()).single.personId, mum.id);
    expect((await repos.people.byId(mum.id))!.lastContact, isNotNull);

    // Two paternal uncles: nobody is picked; a new person keeps the relation.
    await repos.people.insert(PeopleCompanion.insert(name: 'سمير', relation: const Value('uncle')));
    await repos.people.insert(PeopleCompanion.insert(name: 'نبيل', relation: const Value('uncle')));
    expect(await add('كلمت عمي امبارح'), isTrue);
    final created = (await repos.people.getAll()).where((p) => p.name == 'عمي').single;
    expect(created.relation, 'uncle', reason: 'a relation word is stored as its key (marks ignored)');
  });

  // How people in Amman actually type it: no hamza, dialect words.
  for (final (typed, relation) in const [
    ('اتصلت بأبوي', 'father'), // the parser's own example (parser_test)
    ('كلمت امي امبارح', 'mother'),
    ('اتصلت بإمي', 'mother'),
    ('زرت اخوي', 'brother'),
    ('اتصلت بستي', 'grandmother'),
    ('كلمت خالو', 'maternalUncle'),
  ]) {
    test('«$typed» reaches the one person whose relation is $relation', () async {
      final person = await repos.people.insert(PeopleCompanion.insert(name: 'سالم', relation: Value(relation)));
      final intent = QuickAddParser.parse(typed, now: now);
      expect(intent.kind, QuickAddKind.contact, reason: 'the parser reads a contact');
      expect(await handler.handle(intent), isTrue);
      expect(
        (await repos.people.getAll()).map((p) => p.name).toList(),
        ['سالم'],
        reason: 'no new person named «${intent.title}» next to the saved $relation',
      );
      expect((await repos.contactLogs.getAll()).single.personId, person.id);
    });
  }

  test('a name is found whatever the hamza: «امي» is the person saved as «أمي»', () async {
    final mum = await repos.people.insert(PeopleCompanion.insert(name: 'أمي'));
    expect(await add('كلمت امي امبارح'), isTrue);
    expect(await repos.people.count(), 1);
    expect((await repos.contactLogs.getAll()).single.personId, mum.id);
  });

  test('water, pain, mood and contact are recorded too', () async {
    expect(await add('شربت 500 مل ماء'), isTrue);
    expect((await repos.waterLogs.getAll()).single.ml, 500);

    final pain = QuickAddParser.parse('ألم ظهر 6', now: now);
    if (pain.kind == QuickAddKind.pain) {
      expect(await handler.handle(pain), isTrue);
      expect((await repos.painEntries.getAll()).single.score, 6);
    }

    final contact = QuickAddParser.parse('called Mum', now: now);
    if (contact.kind == QuickAddKind.contact) {
      expect(await handler.handle(contact), isTrue);
      expect(await handler.handle(contact), isTrue);
      expect(await repos.people.count(), 1);
      expect(await repos.contactLogs.count(), 2);
    }
  });

  test('empty intents are refused', () async {
    expect(await handler.handle(const QuickAddIntent(kind: QuickAddKind.expense, title: 'x', raw: 'x')), isFalse);
    expect(await handler.handle(const QuickAddIntent(kind: QuickAddKind.task, title: '', raw: '  ')), isFalse);
  });
}
