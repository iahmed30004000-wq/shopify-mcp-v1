// Propose → apply one → the feature's own data really changed (read back
// from the database) → undo → it is back. And applying the same piece twice
// changes nothing the second time, even through a new service.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/day_chat/day_chat.dart';
import 'package:madar/features/home/domain/prayer_day.dart';

import '../../helpers/test_app.dart';

void main() {
  late MadarDatabase db;
  late Repositories repos;
  late DayChatService service;
  late String moduleId;

  // Wednesday 14 October 2026, 20:30 – after Isha, so the prayer day is
  // still the 14th.
  final now = DateTime(2026, 10, 14, 20, 30);
  final today = DateTime(2026, 10, 14);

  DayChatService build() => DayChatService(
    repos,
    clock: () => now,
    prayerDay: () => PrayerDayTimes.placeholder,
    focusedWindow: () => PrayerWindow.isha,
    defaultWalletName: () => 'المحفظة',
  );

  setUp(() async {
    db = testDatabase();
    await db.customSelect('SELECT 1').get(); // migrate + seed (currencies, planets …)
    repos = Repositories(db);
    service = build();
    final module = await CustomModulesService(repos, clock: () => now).createModule(
      const ModuleDefinition(
        id: '',
        name: 'سكر الدم',
        colorArgb: 0xFF112233,
        planetKey: 'health',
        fields: [ModuleField(id: 'f1', label: 'القراءة', type: FieldType.number, min: 40, max: 500)],
      ),
    );
    moduleId = module.id;
    await repos.foods.insert(FoodsCompanion.insert(name: 'منسف', unit: Value('طبق'), defaultPortion: Value(1)));
    await repos.exercises.insert(ExercisesCompanion.insert(name: 'صدر'));
    await repos.people.insert(PeopleCompanion.insert(name: 'رنا'));
    await repos.tasks.insert(TasksCompanion.insert(title: 'تقرير الشغل', window: Value(PrayerWindow.dhuhr)));
  });

  tearDown(() => db.close());

  Future<DayChatPiece> only(String text) async {
    final reading = await service.read(text);
    expect(reading.pieces, hasLength(1), reason: 'the test line holds one fact');
    await service.remember(reading);
    return reading.pieces.single;
  }

  /// Applies [piece], checks what the feature holds, undoes it, and checks
  /// it is gone again. [after] gets the outcome.
  Future<void> roundTrip(
    String line, {
    required Future<void> Function(DayChatOutcome outcome) applied,
    required Future<void> Function() undone,
  }) async {
    final piece = await only(line);
    expect(piece.canApply, isTrue, reason: '$line: ${piece.gaps}');
    final outcome = await service.apply(piece);
    expect(outcome.alreadyApplied, isFalse);
    await applied(outcome);
    expect((await service.day()).stateOf(piece.id), DayChatState.applied);

    // Applying the same piece again writes nothing – through a brand new
    // service, so it is the stored decision that stops it, not memory.
    final again = await build().apply(piece);
    expect(again.alreadyApplied, isTrue);
    expect(again.refId, outcome.refId);
    await applied(outcome);

    await outcome.undo();
    await undone();
    expect((await service.day()).stateOf(piece.id), DayChatState.undone);
  }

  test('money: the entry lands in the ledger and comes back out', () async {
    await roundTrip(
      'صرفت ٥ دنانير قهوة',
      applied: (outcome) async {
        final rows = await repos.transactions.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.id, outcome.refId);
        expect(rows.single.amountMilli, 5000);
        expect(rows.single.kind, TxKind.expense);
        expect(rows.single.note, 'قهوة');
        final wallet = await repos.wallets.byId(rows.single.walletId);
        expect(wallet?.currency, 'JOD');
        // Filed like an entry added by hand: the activity is there too.
        expect(await repos.activityLog.getAll(), isNotEmpty);
      },
      undone: () async {
        expect(await repos.transactions.getAll(), isEmpty);
        expect(await repos.activityLog.getAll(), isEmpty);
      },
    );
  });

  test('a meal lands in the food log, linked to his own food', () async {
    await roundTrip(
      'أكلت منسف الساعة ٢',
      applied: (outcome) async {
        final rows = await repos.foodLogs.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.id, outcome.refId);
        expect(rows.single.name, 'منسف');
        expect(rows.single.at, DateTime(2026, 10, 14, 14));
        expect(rows.single.foodId, isNotNull, reason: 'his library food');
      },
      undone: () async => expect(await repos.foodLogs.getAll(), isEmpty),
    );
  });

  test('a workout lands in the body log with its sets, reps and weight', () async {
    await roundTrip(
      'تمرين صدر ٤×١٢ وزن ٤٠ كيلو',
      applied: (outcome) async {
        final rows = await repos.workoutLogs.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.id, outcome.refId);
        expect((rows.single.sets, rows.single.reps), (4, 12));
        expect(rows.single.weight, 40);
        expect(rows.single.exerciseId, isNotNull, reason: 'his own exercise');
      },
      undone: () async => expect(await repos.workoutLogs.getAll(), isEmpty),
    );
  });

  test('water lands in the water log', () async {
    await roundTrip(
      'شربت ٥٠٠ مل مي',
      applied: (outcome) async {
        final rows = await repos.waterLogs.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.ml, 500);
        expect(rows.single.id, outcome.refId);
      },
      undone: () async => expect(await repos.waterLogs.getAll(), isEmpty),
    );
  });

  test('pain lands in Health with its score and where it hurt', () async {
    await roundTrip(
      'وجع الركبة ٦',
      applied: (outcome) async {
        final rows = await repos.painEntries.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.score, 6);
        expect(rows.single.locations, ['الركبة']);
        expect(rows.single.id, outcome.refId);
      },
      undone: () async => expect(await repos.painEntries.getAll(), isEmpty),
    );
  });

  test('a mood lands in Health', () async {
    await roundTrip(
      'مزاجي ٤',
      applied: (outcome) async {
        final rows = await repos.moodEntries.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.mood, 4);
        expect(rows.single.id, outcome.refId);
      },
      undone: () async => expect(await repos.moodEntries.getAll(), isEmpty),
    );
  });

  test('a prayer lands in the tracker, at the mosque, and comes back out', () async {
    await roundTrip(
      'صليت العصر بالمسجد',
      applied: (outcome) async {
        final rows = await repos.prayerLogs.getAll();
        expect(rows, hasLength(1));
        expect(rows.single.prayer, Prayer.asr);
        expect(rows.single.status, PrayerStatus.prayed);
        expect(rows.single.atMosque, isTrue);
        expect(rows.single.inJamaah, isTrue);
        expect(outcome.refTable, 'prayer_logs');
      },
      undone: () async => expect(await repos.prayerLogs.getAll(), isEmpty),
    );
  });

  test('a module entry lands in his own module', () async {
    await roundTrip(
      'سكر الدم ١٢٠',
      applied: (outcome) async {
        final entries = await repos.customEntries.getAll();
        expect(entries, hasLength(1));
        expect(entries.single.moduleId, moduleId);
        expect(entries.single.entryValues, {'f1': 120});
        expect(entries.single.id, outcome.refId);
      },
      undone: () async => expect(await repos.customEntries.getAll(), isEmpty),
    );
  });

  test('a contact lands in Family and moves his last contact', () async {
    await roundTrip(
      'كلمت رنا',
      applied: (outcome) async {
        final logs = await repos.contactLogs.getAll();
        expect(logs, hasLength(1));
        expect(logs.single.channel, ContactChannel.call);
        expect(logs.single.id, outcome.refId);
        final rana = (await repos.people.getAll()).firstWhere((p) => p.name == 'رنا');
        expect(rana.lastContact, isNotNull);
      },
      undone: () async {
        expect(await repos.contactLogs.getAll(), isEmpty);
        final rana = (await repos.people.getAll()).firstWhere((p) => p.name == 'رنا');
        expect(rana.lastContact, isNull);
      },
    );
  });

  test('a person he never saved is added by the apply, and the undo removes him again', () async {
    final piece = await only('زرت ابو محمود');
    expect(piece.gaps.map((g) => g.kind), [DayChatGapKind.person]);
    final outcome = await service.apply(piece);
    final people = await repos.people.getAll();
    expect(people.map((p) => p.name), containsAll(['رنا', 'ابو محمود']));
    expect((await repos.contactLogs.getAll()).single.channel, ContactChannel.visit);
    await outcome.undo();
    expect((await repos.people.getAll()).map((p) => p.name), ['رنا']);
    expect(await repos.contactLogs.getAll(), isEmpty);
  });

  test('a task of his is ticked off, and the undo opens it again', () async {
    await roundTrip(
      'خلصت تقرير الشغل',
      applied: (outcome) async {
        final task = (await repos.tasks.getAll()).single;
        expect(task.done, isTrue);
        expect(task.doneAt, now);
        expect(outcome.refId, task.id);
      },
      undone: () async {
        final task = (await repos.tasks.getAll()).single;
        expect(task.done, isFalse);
        expect(task.doneAt, isNull);
      },
    );
  });

  test('something he finished that was never a task is filed as a finished task', () async {
    final piece = await only('خلصت غسيل السيارة');
    final outcome = await service.apply(piece);
    final created = (await repos.tasks.getAll()).firstWhere((t) => t.title == 'غسيل السيارة');
    expect(created.done, isTrue);
    expect(created.date, today);
    await outcome.undo();
    expect((await repos.tasks.getAll()).map((t) => t.title), ['تقرير الشغل']);
  });

  test('a to-do lands in the window he said, on the day he said', () async {
    await roundTrip(
      'لازم اروح للبنك بكرا',
      applied: (outcome) async {
        final task = (await repos.tasks.getAll()).firstWhere((t) => t.id == outcome.refId);
        expect(task.done, isFalse);
        expect(task.date, DateTime(2026, 10, 15));
        expect(task.window, PrayerWindow.isha, reason: 'the window he is looking at');
      },
      undone: () async => expect((await repos.tasks.getAll()).map((t) => t.title), ['تقرير الشغل']),
    );
  });

  test('a sentence with a dose is written as his own note and never as medicine', () async {
    final piece = await only('اخذت حبة بنادول ٥٠٠ ملغ');
    expect(piece.kind, DayChatKind.note);
    final outcome = await service.apply(piece);
    final note = (await repos.tasks.getAll()).firstWhere((t) => t.id == outcome.refId);
    expect(note.title, 'اخذت حبة بنادول ٥٠٠ ملغ', reason: 'his words, whole');
    expect(await repos.medications.getAll(), isEmpty, reason: 'nothing medical is ever written');
    expect(await repos.medDoses.getAll(), isEmpty);
    await outcome.undo();
    expect((await repos.tasks.getAll()).map((t) => t.title), ['تقرير الشغل']);
  });

  test('a piece that still needs him is refused, and writes nothing', () async {
    final vague = await only('صليت');
    expect(vague.canApply, isFalse);
    await expectLater(service.apply(vague), throwsA(isA<DayChatRefused>()));
    expect(await repos.prayerLogs.getAll(), isEmpty);

    final sign = await only('ضغط الدم ١٤');
    await expectLater(service.apply(sign), throwsA(isA<DayChatRefused>()));
    expect(await repos.customEntries.getAll(), isEmpty);

    final unread = await only('اليوم كان يوم طويل');
    await expectLater(service.apply(unread), throwsA(isA<DayChatRefused>()));
    expect(await repos.tasks.getAll(), hasLength(1));
  });

  test('he corrects a piece before applying it', () async {
    final piece = await only('وجع راسي');
    expect(piece.canApply, isFalse, reason: 'no score was said');
    final fact = piece.fact as PainFact;
    final outcome = await service.applyEdited(piece, fact.copyWith(score: 7));
    final rows = await repos.painEntries.getAll();
    expect(rows.single.score, 7);
    expect(rows.single.locations, ['راسي']);
    expect((await service.day()).decision(piece.id)?.edited, isTrue);
    await outcome.undo();
    expect(await repos.painEntries.getAll(), isEmpty);
  });

  test('he says no: nothing is written, and the no is undoable', () async {
    final piece = await only('صرفت ٥ دنانير قهوة');
    final undo = await service.reject(piece);
    expect((await service.day()).stateOf(piece.id), DayChatState.rejected);
    expect(await repos.transactions.getAll(), isEmpty);
    await undo();
    expect((await service.day()).stateOf(piece.id), DayChatState.pending);
    expect(await repos.transactions.getAll(), isEmpty);
  });

  test('a rejected piece can still be applied afterwards, an applied one cannot be rejected', () async {
    final piece = await only('شربت ٥٠٠ مل مي');
    await service.reject(piece);
    await service.apply(piece);
    expect(await repos.waterLogs.getAll(), hasLength(1));
    await expectLater(service.reject(piece), throwsA(isA<DayChatRefused>()));
  });

  test('one line, five facts: each is applied on its own, and only the ones he picked are written', () async {
    const line = 'صرفت ٥ دنانير قهوة، صليت العصر بالمسجد، تمرين صدر ٤×١٢، وجع الركبة ٦، أكلت منسف الساعة ٢';
    final reading = await service.read(line);
    await service.remember(reading);
    expect(reading.pieces, hasLength(5));
    await service.apply(reading.pieces[1]); // the prayer only
    await service.apply(reading.pieces[4]); // and the meal
    expect(await repos.prayerLogs.getAll(), hasLength(1));
    expect(await repos.foodLogs.getAll(), hasLength(1));
    expect(await repos.transactions.getAll(), isEmpty, reason: 'there is no apply-all');
    expect(await repos.workoutLogs.getAll(), isEmpty);
    expect(await repos.painEntries.getAll(), isEmpty);
    final day = await service.day();
    expect(day.applied, hasLength(2));
    expect(day.lines.single.text, line);
    expect(day.lines.single.pieceIds, [for (final p in reading.pieces) p.id]);
  });

  test('the chat is still there after the app was closed', () async {
    final reading = await service.read('صرفت ٥ دنانير قهوة');
    await service.remember(reading);
    await service.apply(reading.pieces.single);
    // A new service over the same database (as if the app restarted).
    final fresh = build();
    final day = await fresh.day();
    expect(day.lines.single.text, 'صرفت ٥ دنانير قهوة');
    expect(day.applied.single.refTable, 'transactions');
    expect(day.applied.single.text, 'صرفت ٥ دنانير قهوة');
    expect(await fresh.stateOf(reading.pieces.single), DayChatState.applied);
  });

  test('a row he deleted himself does not block a new apply', () async {
    final piece = await only('شربت ٥٠٠ مل مي');
    final outcome = await service.apply(piece);
    await repos.waterLogs.delete(outcome.refId!);
    final again = await service.apply(piece);
    expect(again.alreadyApplied, isFalse, reason: 'the row is gone – filing it again is right');
    expect(await repos.waterLogs.getAll(), hasLength(1));
  });
}
