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
