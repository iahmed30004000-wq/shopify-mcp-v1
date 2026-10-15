// «الحفظ» against the database (schema v8): his goals and his marks with
// their undo, a drill written into Part 13's own log, the page map that
// matches the strengths, the export that extends Part 13's file, and the
// whole thing surviving a real backup and restore.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/snapshot.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/data/domain/backup_codec.dart';
import 'package:madar/features/data/domain/backup_format.dart';
import 'package:madar/features/hifz/hifz_memorisation.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import '../tasmee/tasmee_fixtures.dart';
import 'hifz_plan_fixtures.dart';

/// Cheap key derivation: the backup's own tests pay the production cost.
const _fastKdf = BackupKdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);
const _codec = MadarBackupCodec(kdf: _fastKdf, useIsolate: false);

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  final shape = testShape();
  final now = DateTime(2026, 10, 15, 20, 0);
  const kahfStart = AyahRange(AyahRef(18, 1), AyahRef(18, 3));

  late MadarDatabase db;
  late Repositories repos;
  late HifzPlanService service;

  HifzPlanService serviceOver(MadarDatabase database) {
    final r = Repositories(database);
    return HifzPlanService(repos: r, tasmee: TasmeeService(r, clock: () => now), shape: shape, clock: () => now);
  }

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    repos = Repositories(db);
    service = serviceOver(db);
  });

  tearDown(() => db.close());

  Future<void> addToHifzList(AyahRange range, {bool suspended = false}) => db.into(db.hifzItems).insert(
    HifzItemsCompanion.insert(
      surah: Value(range.first.surah),
      ayahFrom: Value(range.first.ayah),
      ayahTo: Value(range.last.ayah),
      suspended: Value(suspended),
    ),
  );

  Future<TasmeeSession> writeDrill(AyahRange range, {String? wrongWord}) async {
    final target = targetOf(range);
    final words = verifiedWords(target);
    if (wrongWord != null) words[1] = wrongWord;
    final drill = WritingDrill(target)..write(words.join(' '));
    final (session, _) = await service.recordWriting(drill.result);
    return session;
  }

  group('his settings', () {
    test('default, saved, and undone', () async {
      expect(await service.settings(), const HifzPlanSettings());
      final undo = await service.setSettings(const HifzPlanSettings(newAyatPerDay: 10, newFrom: AyahRef(18, 1)));
      final saved = await service.settings();
      expect(saved.newAyatPerDay, 10);
      expect(saved.newFrom, const AyahRef(18, 1));
      await undo();
      expect(await service.settings(), const HifzPlanSettings());
    });

    test('the cursor of the new portion moves on its own', () async {
      await service.setNewFrom(const AyahRef(18, 6));
      expect((await service.settings()).newFrom, const AyahRef(18, 6));
      await service.setNewFrom(null);
      expect((await service.settings()).newFrom, isNull);
    });
  });

  group('his goals', () {
    test('added in his own words, changed, switched off and deleted – each with its undo', () async {
      final (goal, undoAdd) = await service.addGoal(
        title: 'الكهف كل جمعة',
        kind: HifzGoalKind.rangeOnWeekday,
        range: const AyahRange(AyahRef(18, 1), AyahRef(18, 110)),
        weekday: DateTime.friday,
        window: PrayerWindow.fajr,
      );
      expect(goal.title, 'الكهف كل جمعة');
      expect(goal.range, const AyahRange(AyahRef(18, 1), AyahRef(18, 110)));
      expect(goal.window, PrayerWindow.fajr);
      expect(goal.canRemind, isTrue);

      final undoEdit = await service.editGoal(goal.id, offsetMinutes: 30);
      expect((await service.goal(goal.id))!.offsetMinutes, 30);
      await undoEdit();
      expect((await service.goal(goal.id))!.offsetMinutes, 15);

      final undoOff = await service.setGoalActive(goal.id, false);
      expect((await service.goal(goal.id))!.active, isFalse);
      expect((await service.goal(goal.id))!.canRemind, isFalse);
      await undoOff();
      expect((await service.goal(goal.id))!.active, isTrue);

      final undoDelete = await service.deleteGoal(goal.id);
      expect(await service.goals(), isEmpty);
      await undoDelete();
      expect((await service.goals()).single.title, 'الكهف كل جمعة');

      await undoAdd();
      expect(await service.goals(), isEmpty);
    });

    test('their progress is read off the log, not off a flag', () async {
      await service.addGoal(
        title: 'صفحتين باليوم',
        kind: HifzGoalKind.amountPerDay,
        amount: 2,
        window: PrayerWindow.isha,
      );
      expect((await service.goalProgress()).single.done, 0);
      await writeDrill(const AyahRange(AyahRef(18, 1), AyahRef(18, 20)));
      final after = (await service.goalProgress()).single;
      expect(after.done, greaterThanOrEqualTo(2));
      expect(after.met, isTrue);
    });
  });

  group('his marks', () {
    test('«مش عليّ» takes a stretch out of the plan, and the undo puts it back', () async {
      await addToHifzList(const AyahRange(AyahRef(18, 1), AyahRef(18, 10)));
      expect((await service.plan()).memorisedAyat, 10);

      final (mark, undo) = await service.markSkipped(const AyahRange(AyahRef(18, 1), AyahRef(18, 4)));
      expect(mark.kind, HifzMarkKind.skipReview);
      expect((await service.plan()).memorisedAyat, 6);
      expect((await service.strengths()).of(const AyahRef(18, 2)).band, StrengthBand.skipped);

      await undo();
      expect((await service.plan()).memorisedAyat, 10);
    });

    test('resetting a page starts its strength again without deleting a thing', () async {
      await addToHifzList(kahfStart);
      await writeDrill(kahfStart);
      expect((await service.strengths()).of(const AyahRef(18, 1)).band, StrengthBand.solid);

      final page = shape.pageOf(const AyahRef(18, 1));
      final (mark, undo) = await service.resetPage(page);
      expect(mark.kind, HifzMarkKind.resetStrength);
      expect(mark.day, DateTime(2026, 10, 15));

      final after = (await service.strengths()).of(const AyahRef(18, 1));
      expect(after.band, StrengthBand.unknown, reason: 'what he recited before the reset is behind the line');
      expect(after.resetSince, DateTime(2026, 10, 15));
      expect((await TasmeeService(repos, clock: () => now).log()).single.ayat, isNotEmpty, reason: 'nothing deleted');

      await undo();
      expect((await service.strengths()).of(const AyahRef(18, 1)).band, StrengthBand.solid);
    });
  });

  group('a drill goes into Part 13\'s log and nowhere else', () {
    test('writing from memory is written under «write», judged by nobody but the text', () async {
      final session = await writeDrill(kahfStart);
      expect(session.mode, TasmeeMode.write);
      expect(session.recogniserId, 'typed', reason: 'no speech model judged this');
      expect(session.ayat, hasLength(3));
      expect(session.counts.isClean, isTrue);

      final rows = await repos.tasmeeAyat.getAll();
      expect(rows, hasLength(3), reason: 'the attempt itself is a row, even when nothing went wrong');
      expect(await repos.tasmeeMistakes.getAll(), isEmpty);

      final strengths = await service.strengths();
      expect(strengths.of(const AyahRef(18, 1)).band, StrengthBand.solid);
      expect(strengths.of(const AyahRef(18, 4)).band, StrengthBand.unknown, reason: 'he did not write that one');
    });

    test('a word he got wrong lands in the mistake log with its place in the original', () async {
      await writeDrill(const AyahRange(AyahRef(18, 1), AyahRef(18, 1)), wrongWord: 'كلمة');
      final mistakes = await repos.tasmeeMistakes.getAll();
      expect(mistakes, hasLength(1));
      expect(mistakes.single.kind, MistakeKind.wrong);
      expect(mistakes.single.heard, 'كلمة');
      expect(mistakes.single.expected, isNot('كلمة'));
      expect(mistakes.single.spanEnd, greaterThan(mistakes.single.spanStart));
      expect((await service.strengths()).of(const AyahRef(18, 1)).band, isNot(StrengthBand.solid));
    });

    test('a mode that judges nothing refuses to write a result', () async {
      final target = targetOf(kahfStart);
      final check = TasmeeAligner.align(target, const []);
      expect(
        () => service.recordDrill(check, method: HifzMethod.listenRepeat),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  test('with no model on the phone the service still plans a whole day, and says «سمّع» is not ready', () async {
    await addToHifzList(const AyahRange(AyahRef(18, 1), AyahRef(18, 10)));
    await service.setSettings(const HifzPlanSettings(newFrom: AyahRef(18, 11)));
    final plan = await service.plan();
    expect(plan.has(HifzPlanNote.recitingUnavailable), isTrue);
    expect(plan.portions, isNotEmpty);
    expect([for (final p in plan.portions) p.method], isNot(contains(HifzMethod.reciting)));
    expect([for (final p in plan.portions) p.method], contains(anyOf(HifzMethod.writing, HifzMethod.listenRepeat)));
  });

  test('the inventory is his Hifz list, with the paused ones left out', () async {
    await addToHifzList(const AyahRange(AyahRef(18, 1), AyahRef(18, 5)));
    await addToHifzList(const AyahRange(AyahRef(78, 1), AyahRef(78, 10)), suspended: true);
    expect(await service.memorised(), const [AyahRange(AyahRef(18, 1), AyahRef(18, 5))]);
    expect(await service.memorised(includeSuspended: true), hasLength(2));
  });

  test('the page map\'s numbers are the strengths themselves', () async {
    await addToHifzList(const AyahRange(AyahRef(18, 1), AyahRef(18, 10)));
    await writeDrill(const AyahRange(AyahRef(18, 1), AyahRef(18, 2)));
    final strengths = await service.strengths();
    final map = await service.pageMap();
    final page = map.page(shape.pageOf(const AyahRef(18, 1)))!;
    final tested = [
      for (final ref in Mushaf.ayatIn(shape, page.range))
        if (strengths.of(ref).isKnown) strengths.of(ref).strength,
    ];
    expect(page.tested, tested.length);
    expect(page.strength, closeTo(tested.reduce((a, b) => a + b) / tested.length, 1e-12));
    expect(page.band, strengths.model.bandOf(page.strength!));
    expect(page.memorised, greaterThan(0));

    final untouched = map.page(1)!;
    expect(untouched.strength, isNull);
    expect(untouched.band, StrengthBand.unknown, reason: 'never tested is never coloured');
  });

  test('the export is Part 13\'s file with «الحفظ» inside it, not a second format', () async {
    await addToHifzList(kahfStart);
    await service.setSettings(const HifzPlanSettings(newFrom: AyahRef(18, 4)));
    await service.addGoal(
      title: 'الكهف كل جمعة',
      kind: HifzGoalKind.rangeOnWeekday,
      range: const AyahRange(AyahRef(18, 1), AyahRef(18, 110)),
      weekday: DateTime.friday,
      window: PrayerWindow.fajr,
    );
    await writeDrill(kahfStart);

    final json = await service.exportJson(exportedAt: DateTime.utc(2026, 10, 15, 18));
    expect(json['format'], 'madar.tasmee.log');
    expect(json['formatVersion'], 1, reason: 'a Part 13 reader keeps working');
    expect(json['sessions'], isNotEmpty);

    final hifz = json['hifz']! as Map<String, Object?>;
    expect(hifz['blockVersion'], 1);
    expect((hifz['goals']! as List).single, isA<Map<String, Object?>>());
    final goal = (hifz['goals']! as List).single as Map<String, Object?>;
    expect(goal['title'], 'الكهف كل جمعة');
    expect((goal['progress']! as Map)['target'], 110);
    final plan = hifz['plan']! as Map<String, Object?>;
    expect(plan['day'], '2026-10-15');
    expect((plan['portions']! as List), isNotEmpty);
    expect((hifz['strength']! as List), hasLength(3));
    expect((hifz['settings']! as Map)['newFrom'], '18:4');
    expect(jsonEncode(json), isNotEmpty, reason: 'it is plain data a reader can encode');
  });

  test('every mode\'s state survives a real backup and restore', () async {
    await addToHifzList(const AyahRange(AyahRef(18, 1), AyahRef(18, 10)));
    await service.setSettings(const HifzPlanSettings(newAyatPerDay: 7, newFrom: AyahRef(18, 11), dailyCapAyat: 60));
    await service.addGoal(
      title: 'راجع جزء عمّ',
      kind: HifzGoalKind.rangeReview,
      range: const AyahRange(AyahRef(78, 1), AyahRef(114, 6)),
      window: PrayerWindow.isha,
      offsetMinutes: 30,
    );
    await service.markSkipped(const AyahRange(AyahRef(18, 9), AyahRef(18, 10)), note: 'مش عليّ');
    await service.resetStrength(const AyahRange(AyahRef(18, 7), AyahRef(18, 8)), since: DateTime(2026, 10, 1));
    await writeDrill(kahfStart);
    final planBefore = await service.plan();
    final strengthsBefore = await service.strengths();

    final snapshot = await exportSnapshot(db, exportedAt: DateTime.utc(2026, 10, 15, 17));
    expect(snapshot['schemaVersion'], 8);
    expect((snapshot['tables']! as Map)['hifz_goals'], isNotEmpty);
    expect((snapshot['tables']! as Map)['hifz_marks'], isNotEmpty);

    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(snapshot)));
    final (sealed, key) = await _codec.seal(
      bytes,
      'كلمة سر',
      createdAt: DateTime.utc(2026, 10, 15, 17),
      schemaVersion: db.schemaVersion,
    );
    key.destroy();
    final opened = await _codec.open(sealed, 'كلمة سر');
    final restoredJson = jsonDecode(utf8.decode(opened.json)) as Map<String, Object?>;

    final target = await openInMemoryMadarDatabase();
    addTearDown(target.close);
    await restoreSnapshot(target, restoredJson);
    final restored = serviceOver(target);

    expect((await restored.settings()).newAyatPerDay, 7);
    expect((await restored.settings()).newFrom, const AyahRef(18, 11));
    expect((await restored.goals()).single.title, 'راجع جزء عمّ');
    expect((await restored.goals()).single.window, PrayerWindow.isha);
    expect((await restored.goals()).single.offsetMinutes, 30);
    final marks = await restored.marks();
    expect(marks.skipped(const AyahRef(18, 9)), isTrue);
    expect(marks.resetDay(const AyahRef(18, 7)), DateTime(2026, 10, 1));
    final strengthsAfter = await restored.strengths();
    expect(strengthsAfter.byRef.length, strengthsBefore.byRef.length);
    expect(
      strengthsAfter.of(const AyahRef(18, 1)).strength,
      closeTo(strengthsBefore.of(const AyahRef(18, 1)).strength, 1e-12),
    );
    final planAfter = await restored.plan();
    expect(planAfter.toString(), planBefore.toString());
    expect([for (final p in planAfter.portions) '${p.track}${p.range}${p.seed}'], [
      for (final p in planBefore.portions) '${p.track}${p.range}${p.seed}',
    ]);
  });
}
