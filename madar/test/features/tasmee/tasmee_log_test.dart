// The mistake log: what a finished recitation writes, the statistics read
// off it, the round trip through the database and through a real backup
// file, and the documented JSON «فلك» will read.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/db/snapshot.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/data/domain/backup_codec.dart';
import 'package:madar/features/data/domain/backup_format.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'tasmee_fixtures.dart';

/// Cheap key derivation: the backup's own tests pay the production cost.
const _fastKdf = BackupKdfParams(memoryKiB: 64, iterations: 1, parallelism: 1);
const _codec = MadarBackupCodec(kdf: _fastKdf, useIsolate: false);

const _stub = RecogniserInfo(id: 'fake', version: '1', name: 'Madar scripted stub', licence: 'none (test stub)');

void main() {
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  const fatiha2 = AyahRef(1, 2);
  final startedAt = DateTime(2026, 10, 15, 20, 12, 3);

  late MadarDatabase db;
  late TasmeeService service;
  late RecitationTarget target;

  setUp(() async {
    db = await openInMemoryMadarDatabase();
    service = TasmeeService(Repositories(db), clock: () => startedAt);
    target = targetOfAyah(fatiha2);
  });

  tearDown(() => db.close());

  /// A recitation of 1:2–1:3 with one wrong word, one skipped word and one
  /// inserted word – and a peek on the word he then got wrong.
  RecitationCheck messyCheck() {
    final machine = HiddenVerseMachine(target: targetOf(const AyahRange(AyahRef(1, 2), AyahRef(1, 3))));
    final t = machine.target;
    machine.peek(1);
    machine.hearAll(
      RecitationScript.of(verifiedWords(t))
          .replace(1, 'ملك') // a different word in word 1's place
          .drop(3) // word 3 never said
          .insert(4, 'الكريم') // and a word that is not there at all
          .heardWords(),
    );
    return machine.check;
  }

  group('what a finished recitation writes', () {
    test('only real mistakes become rows, and each carries its word and its place', () {
      final check = messyCheck();
      final draft = TasmeeSessionDraft.ofCheck(
        check,
        startedAt: startedAt,
        mode: TasmeeMode.hidden,
        recogniser: _stub,
      );
      expect(draft.range, check.range);
      expect(draft.recogniserId, 'fake');
      expect(draft.textSource, 'tanzil-uthmani');
      expect(draft.ayat, hasLength(2));
      expect(draft.mistakes.map((m) => m.kind).toSet(), {MistakeKind.wrong, MistakeKind.skipped, MistakeKind.extra});
      final wrong = draft.mistakes.firstWhere((m) => m.kind == MistakeKind.wrong);
      expect(wrong.ref, fatiha2);
      expect(wrong.wordIndex, 1);
      expect(wrong.heard, 'ملك');
      expect(wrong.hinted, isTrue, reason: 'he had been shown this word');
      expect(ayahText(fatiha2).substring(wrong.start, wrong.end), wrong.expected);
      final extra = draft.mistakes.firstWhere((m) => m.kind == MistakeKind.extra);
      expect(extra.expected, isEmpty, reason: 'the text expected nothing there');
      expect(extra.start, extra.end);
      expect(extra.heard, 'الكريم');
    });

    test('a clean recitation writes a session and an ayah row, and no mistake at all', () async {
      final check = TasmeeAligner.align(target, cleanScript(target).heardWords());
      final (session, _) = await service.recordCheck(check, mode: TasmeeMode.recite, recogniser: _stub);
      expect(session.mistakes, isEmpty);
      expect(session.ayat, hasLength(1));
      expect(session.ayat.single.isClean, isTrue, reason: 'the attempt itself is recorded, right or wrong');
      expect(session.counts.right, target.wordCount);
      expect(session.recogniserId, 'fake');
      expect(session.mode, TasmeeMode.recite);
      expect(session.day, DateTime(2026, 10, 15));
    });

    test('the basmala and a repeated verse leave no mistake behind', () async {
      final t = targetOfAyah(const AyahRef(112, 1));
      final check = TasmeeAligner.align(
        t,
        RecitationScript.of([...basmalaWords(), ...verifiedWords(t), ...verifiedWords(t)]).heardWords(),
      );
      final (session, _) = await service.recordCheck(check, mode: TasmeeMode.recite, recogniser: _stub);
      expect(session.mistakes, isEmpty);
      expect(session.counts.extras, 0);
      expect(session.ayat.single.isClean, isTrue);
    });
  });

  group('the round trip through the database', () {
    test('a session, its ayat and its mistakes come back exactly as they went in', () async {
      final (written, _) = await service.recordCheck(
        messyCheck(),
        mode: TasmeeMode.hidden,
        recogniser: _stub,
        seed: 1234,
        note: 'بعد العشاء',
      );
      final read = await service.session(written.id);
      expect(read, isNotNull);
      expect(read!.range, written.range);
      expect(read.counts.toJson(), written.counts.toJson());
      expect(read.seed, 1234);
      expect(read.note, 'بعد العشاء');
      expect(read.tashkeelChecked, isFalse);
      expect(read.ayat.map((a) => a.ref).toList(), written.ayat.map((a) => a.ref).toList());
      expect(read.mistakes.length, written.mistakes.length);
      for (final m in read.mistakes) {
        expect(m.sessionId, written.id);
        expect(m.day, DateTime(2026, 10, 15));
        if (m.kind != MistakeKind.extra) {
          expect(ayahText(m.ref).substring(m.start, m.end), m.expected);
        }
      }
      expect(await service.log(), hasLength(1));
    });

    test('the undo of a write takes all three tables back', () async {
      final (written, undo) = await service.recordCheck(messyCheck(), mode: TasmeeMode.hidden, recogniser: _stub);
      expect(await service.mistakeRows(), isNotEmpty);
      await undo();
      expect(await service.sessionRows(), isEmpty);
      expect(await service.ayahRows(), isEmpty);
      expect(await service.mistakeRows(), isEmpty);
      expect(await service.session(written.id), isNull);
    });

    test('deleting a session can be undone, children and all', () async {
      final (written, _) = await service.recordCheck(messyCheck(), mode: TasmeeMode.hidden, recogniser: _stub);
      final before = await service.session(written.id);
      final undo = await service.deleteSession(written.id);
      expect(await service.session(written.id), isNull);
      expect(await service.ayahRows(), isEmpty);
      await undo();
      final after = await service.session(written.id);
      expect(after!.mistakes.length, before!.mistakes.length);
      expect(after.ayat.length, before.ayat.length);
      expect(after.counts.toJson(), before.counts.toJson());
    });

    test('clearing the whole log can be undone', () async {
      await service.recordCheck(messyCheck(), mode: TasmeeMode.hidden, recogniser: _stub);
      final undo = await service.clearLog();
      expect(await service.log(), isEmpty);
      await undo();
      expect(await service.log(), hasLength(1));
      expect((await service.log()).single.mistakes, isNotEmpty);
    });

    test('turning «keep what was heard» off leaves the positions and drops the words', () async {
      await service.setSettings(const TasmeeSettings(keepHeardWords: false));
      final (written, _) = await service.recordCheck(messyCheck(), mode: TasmeeMode.hidden, recogniser: _stub);
      expect(written.mistakes, isNotEmpty);
      expect(written.mistakes.map((m) => m.heard).toSet(), {null});
      expect(written.mistakes.every((m) => m.expected.isNotEmpty || m.kind == MistakeKind.extra), isTrue);
    });
  });

  group('the round trip through a real backup file', () {
    test('the log survives export, sealing, opening and restoring', () async {
      await service.recordCheck(messyCheck(), mode: TasmeeMode.hidden, recogniser: _stub, seed: 7);
      final before = await service.log();
      expect(before.single.mistakes, isNotEmpty);

      final snapshot = await exportSnapshot(db, exportedAt: DateTime.utc(2026, 10, 15, 17));
      expect(snapshot['schemaVersion'], db.schemaVersion);
      expect((snapshot['tables']! as Map)['tasmee_mistakes'], isNotEmpty);

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
      final after = await TasmeeService(Repositories(target), clock: () => startedAt).log();

      expect(after, hasLength(before.length));
      expect(after.single.id, before.single.id);
      expect(after.single.counts.toJson(), before.single.counts.toJson());
      expect(after.single.seed, 7);
      expect(after.single.recogniserId, before.single.recogniserId);
      expect(after.single.mistakes.map((m) => m.expected), before.single.mistakes.map((m) => m.expected));
      expect(after.single.mistakes.map((m) => m.heard), before.single.mistakes.map((m) => m.heard));
      expect(after.single.mistakes.map((m) => m.start), before.single.mistakes.map((m) => m.start));
      expect(after.single.mistakes.map((m) => m.hinted), before.single.mistakes.map((m) => m.hinted));
      expect(after.single.ayat.map((a) => a.ref), before.single.ayat.map((a) => a.ref));
    });

    test('the snapshot of the recitation log holds nothing that looks like audio', () async {
      await service.recordCheck(messyCheck(), mode: TasmeeMode.hidden, recogniser: _stub);
      final snapshot = await exportSnapshot(db, exportedAt: DateTime.utc(2026, 10, 15, 17));
      final tables = (snapshot['tables']! as Map).cast<String, Object?>();
      for (final name in ['tasmee_sessions', 'tasmee_ayat', 'tasmee_mistakes']) {
        for (final row in tables[name]! as List) {
          for (final key in (row as Map).keys) {
            expect(
              RegExp('audio|record|waveform|path|file').hasMatch('$key'),
              isFalse,
              reason: '$name.$key',
            );
          }
        }
      }
    });
  });

  group('the statistics', () {
    test('they are read off the log, with the weak words worst first', () async {
      final days = [
        DateTime(2026, 10, 13, 20),
        DateTime(2026, 10, 14, 20),
        DateTime(2026, 10, 15, 20),
      ];
      for (final day in days) {
        final s = TasmeeService(Repositories(db), clock: () => day);
        await s.recordCheck(
          TasmeeAligner.align(target, cleanScript(target).replace(2, 'ملك').heardWords()),
          mode: TasmeeMode.recite,
          recogniser: _stub,
          startedAt: day,
        );
      }
      final stats = await TasmeeService(Repositories(db), clock: () => days.last).stats();
      expect(stats.sessions, 3);
      expect(stats.ayatRecited, 3);
      expect(stats.distinctAyat, 1);
      expect(stats.counts.wrong, 3);
      expect(stats.days, hasLength(3));
      expect(stats.streakDays, 3, reason: 'three days in a row');
      final weak = stats.weakWords.first;
      expect(weak.ref, fatiha2);
      expect(weak.wordIndex, 2);
      expect(weak.times, 3);
      expect(weak.expected, target.words[2].text);
      expect(weak.lastHeard, 'ملك');
      expect(weak.kinds, {MistakeKind.wrong});
      final ayah = stats.weakAyat.single;
      expect(ayah.ref, fatiha2);
      expect(ayah.attempts, 3);
      expect(ayah.cleanAttempts, 0);
      expect(ayah.mistakes, 3);
      expect(ayah.accuracy, closeTo(0.75, 1e-9));
      expect(await TasmeeService(Repositories(db), clock: () => days.last).weakWordsOf(fatiha2), hasLength(1));
    });

    test('an empty log is empty, not a row of zeros pretending to be progress', () async {
      final stats = await service.stats();
      expect(stats.isEmpty, isTrue);
      expect(stats.counts.accuracy, isNull);
      expect(stats.streakDays, 0);
      expect(stats.weakWords, isEmpty);
    });

    test('a tashkeel-only difference never becomes a weak spot', () async {
      final said = verifiedWords(target);
      final check = TasmeeAligner.align(
        target,
        RecitationScript.of([said[0].replaceAll('ُ', 'ِ'), ...said.skip(1)]).heardWords(),
        options: const AlignmentOptions(checkTashkeel: true),
      );
      final (session, _) = await service.recordCheck(check, mode: TasmeeMode.recite, recogniser: _stub);
      expect(session.mistakes.single.tashkeelOnly, isTrue);
      expect(session.counts.mistakes, 0);
      final stats = await service.stats();
      expect(stats.weakWords, isEmpty, reason: 'experimental, so it is not held against him');
      expect(stats.counts.tashkeelDifferent, 1);
    });
  });

  group('the documented JSON export', () {
    test('it matches the format written down in TasmeeExport', () async {
      await service.recordCheck(
        messyCheck(),
        mode: TasmeeMode.hidden,
        recogniser: _stub,
        seed: 1234,
        note: 'بعد العشاء',
      );
      final export = await service.exportJson(exportedAt: DateTime.utc(2026, 10, 15, 17, 20));
      // Through real JSON text, as the file would be.
      final json = jsonDecode(jsonEncode(export)) as Map<String, Object?>;

      expect(json['format'], tasmeeExportFormat);
      expect(json['format'], 'madar.tasmee.log');
      expect(json['formatVersion'], 1);
      expect(json['exportedAt'], '2026-10-15T17:20:00.000Z');
      expect((json['text']! as Map)['source'], 'tanzil-uthmani');
      expect((json['text']! as Map)['script'], 'uthmani');
      expect((json['text']! as Map)['riwaya'], 'hafs');
      expect(json['notice'], isA<String>());
      expect(json['notice'], contains('heard'));

      final session = (json['sessions']! as List).single as Map<String, Object?>;
      expect(session.keys, containsAll([
        'id', 'startedAt', 'day', 'mode', 'range', 'seconds', 'recogniser', //
        'textSource', 'tashkeelChecked', 'seed', 'note', 'counts', 'ayat', 'mistakes',
      ]));
      expect(session['day'], '2026-10-15');
      expect(session['startedAt'], isA<String>());
      expect(session['mode'], 'hidden');
      expect(session['seed'], 1234);
      expect(session['range'], {'from': '1:2', 'to': '1:3'});
      expect(session['recogniser'], {'id': 'fake', 'version': '1'});
      expect((session['counts']! as Map).keys, [
        'words', 'right', 'wrong', 'skipped', 'unsure', 'pending', 'extras', 'hints', 'tashkeelDifferent', //
      ]);

      final ayah = (session['ayat']! as List).first as Map<String, Object?>;
      expect(ayah['ref'], '1:2');
      expect(ayah['surah'], 1);
      expect(ayah['ayah'], 2);
      expect(ayah['clean'], isA<bool>());
      expect((ayah['counts']! as Map).keys.length, 9);

      final mistakes = (session['mistakes']! as List).cast<Map<String, Object?>>();
      expect(mistakes, isNotEmpty);
      for (final m in mistakes) {
        expect(m.keys, containsAll([
          'ref', 'surah', 'ayah', 'word', 'kind', 'expected', 'span', 'heard', //
          'hinted', 'confidence', 'tashkeelOnly', 'at',
        ]));
        expect(['wrong', 'skipped', 'extra'], contains(m['kind']));
        final span = (m['span']! as Map).cast<String, Object?>();
        expect(span.keys, ['start', 'end']);
        final start = span['start']! as int;
        final end = span['end']! as int;
        final text = ayahText(AyahRef(m['surah']! as int, m['ayah']! as int));
        if (m['kind'] == 'extra') {
          expect(start, end);
          expect(m['expected'], '');
        } else {
          expect(text.substring(start, end), m['expected']);
        }
        expect(m['at'], endsWith('Z'), reason: 'an instant in UTC');
      }

      final stats = (json['stats']! as Map).cast<String, Object?>();
      expect(stats.keys, containsAll([
        'sessions', 'ayatRecited', 'distinctAyat', 'seconds', 'streakDays', //
        'firstAt', 'lastAt', 'counts', 'days', 'weakWords', 'weakAyat',
      ]));
      expect(stats['sessions'], 1);
      final day = (stats['days']! as List).single as Map<String, Object?>;
      expect(day['day'], '2026-10-15');
      final weakWord = (stats['weakWords']! as List).first as Map<String, Object?>;
      expect(weakWord.keys, containsAll(['ref', 'surah', 'ayah', 'word', 'expected', 'times', 'hinted', 'kinds', 'lastHeard', 'lastAt']));
      final weakAyah = (stats['weakAyat']! as List).first as Map<String, Object?>;
      expect(weakAyah['lastAt'], '2026-10-15', reason: 'a calendar day, not an instant');
    });

    test('an export without what was heard still carries every position', () async {
      await service.recordCheck(messyCheck(), mode: TasmeeMode.hidden, recogniser: _stub);
      final export = await service.exportJson(exportedAt: DateTime.utc(2026, 10, 15), includeHeard: false);
      final session = ((export['sessions']! as List).single as Map<String, Object?>);
      for (final m in (session['mistakes']! as List).cast<Map<String, Object?>>()) {
        expect(m.containsKey('heard'), isFalse);
        expect(m['span'], isA<Map<String, Object?>>());
      }
      final weak = (((export['stats']! as Map)['weakWords'])! as List).first as Map<String, Object?>;
      expect(weak.containsKey('lastHeard'), isFalse);
    });

    test('an empty log exports an empty, valid file', () async {
      final export = await service.exportJson(exportedAt: DateTime.utc(2026, 10, 15));
      expect(export['format'], tasmeeExportFormat);
      expect(export['sessions'], isEmpty);
      expect((export['stats']! as Map)['sessions'], 0);
      expect(jsonEncode(export), isA<String>());
    });
  });

  group('his settings', () {
    test('the tashkeel check is off until he turns it on, and the change can be undone', () async {
      expect((await service.settings()).checkTashkeel, isFalse);
      final undo = await service.setSettings(const TasmeeSettings(checkTashkeel: true));
      expect((await service.settings()).checkTashkeel, isTrue);
      expect((await service.settings()).alignment.checkTashkeel, isTrue);
      await undo();
      expect((await service.settings()).checkTashkeel, isFalse);
    });

    test('they survive their own JSON round trip', () {
      const settings = TasmeeSettings(
        checkTashkeel: true,
        confidenceFloor: 0.5,
        blankShare: 0.4,
        blankSpread: BlankSpread.ayahEnds,
        hideAyahMarkers: true,
        keepHeardWords: false,
      );
      expect(TasmeeSettings.fromJson(jsonDecode(jsonEncode(settings.toJson()))), settings);
      expect(TasmeeSettings.fromJson(null), const TasmeeSettings());
      expect(TasmeeSettings.fromJson({'confidenceFloor': 'nonsense'}), const TasmeeSettings());
    });
  });

  group('sessions of one ayah', () {
    test('every attempt at an ayah can be found again', () async {
      await service.recordCheck(messyCheck(), mode: TasmeeMode.hidden, recogniser: _stub);
      expect(await service.sessionsOf(const AyahRef(1, 3)), hasLength(1));
      expect(await service.sessionsOf(const AyahRef(2, 255)), isEmpty);
    });
  });
}
