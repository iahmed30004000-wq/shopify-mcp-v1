import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/key_value_repository.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/data/data.dart';

import '../../core/db/fixtures.dart';
import 'data_fixtures.dart';
import 'data_harness.dart';

const strongPass = 'amber lanterns over quiet water';

/// A backup of [populateAllTables] sealed with [strongPass].
Future<Uint8List> makeBackup(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final db = dataTestDatabase();
    await populateAllTables(db);
    final dir = await Directory.systemTemp.createTemp('madar_mk_');
    final file = await BackupService(db, codec: fastTestCodec, safetyDirectory: () async => dir).create(strongPass);
    await db.close();
    await dir.delete(recursive: true);
    return file.bytes;
  });
  return bytes!;
}

Finder sheetButton(String label) => find.widgetWithText(SheetButton, label);

void main() {
  group('DataCentreScreen', () {
    testWidgets('shows backup, export and import; JSON export goes to the share sheet only on tap', (tester) async {
      usePhone(tester);
      final (app, env) = await buildDataApp(tester, home: const DataCentreScreen(), beforePump: (db) => seedSummaryScenario(db));
      await tester.pumpWidget(app);
      await settleAsync(tester);

      expect(find.text('Your data'), findsOneWidget);
      expect(find.text('Your data stays with you'), findsOneWidget);
      expect(find.text('Create backup'), findsOneWidget);
      expect(find.text('Choose a backup file'), findsOneWidget);
      expect(find.text('Not yet'), findsOneWidget); // last backup
      await tester.scrollUntilVisible(find.text('Everything (JSON)'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('AI-ready summary'), findsOneWidget);
      expect(find.text('Spreadsheets (CSV)'), findsOneWidget);
      expect(env.bridge.shared, isEmpty);

      await tester.ensureVisible(find.text('Everything (JSON)'));
      await frames(tester, 6);
      await tester.tap(find.text('Everything (JSON)'));
      await settleAsync(tester);
      await frames(tester);
      expect(find.text('Your file is ready'), findsOneWidget);
      expect(find.textContaining('madar-export-2026-09-30.json'), findsOneWidget);
      expect(find.text('Not encrypted: anyone who gets this file can read it.'), findsOneWidget);
      expect(env.bridge.shared, isEmpty, reason: 'nothing leaves before the user taps Share');

      await tester.tap(sheetButton('Share'));
      await settleAsync(tester, rounds: 4);
      expect(env.bridge.shared.single.name, 'madar-export-2026-09-30.json');
      final decoded = jsonDecode(utf8.decode(env.bridge.shared.single.bytes)) as Map<String, Object?>;
      expect(decoded['format'], 'madar.snapshot');
      expect(find.text('Handed to the share sheet.'), findsOneWidget);
      expect(env.sound.played, contains(Sfx.complete));
    });

    testWidgets('import entry calls back', (tester) async {
      usePhone(tester);
      var opened = 0;
      final (app, _) = await buildDataApp(tester, home: DataCentreScreen(onOpenImport: () => opened++));
      await tester.pumpWidget(app);
      await settleAsync(tester);
      await tester.scrollUntilVisible(find.text('Import from the Madar prototype'), 200, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Import from the Madar prototype'));
      await frames(tester, 6);
      await tester.tap(find.text('Import from the Madar prototype'));
      await frames(tester, 4);
      expect(opened, 1);
    });
  });

  group('BackupSheet', () {
    testWidgets('strength meter and confirmation gate the button; the file is shared only on tap', (tester) async {
      usePhone(tester);
      final (app, env) = await buildDataApp(tester, home: const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: BackupSheet())));
      await tester.pumpWidget(app);
      await frames(tester);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      SheetButton create() => tester.widget<SheetButton>(sheetButton('Create backup'));
      expect(create().enabled, isFalse);

      await tester.enterText(fields.at(0), 'password1');
      await frames(tester, 4);
      expect(find.text('Very weak'), findsOneWidget);
      expect(find.text('This is a common password that’s easy to guess.'), findsOneWidget);
      expect(create().enabled, isFalse);

      await tester.enterText(fields.at(0), strongPass);
      await frames(tester, 4);
      expect(find.text('Very strong'), findsOneWidget);
      await tester.enterText(fields.at(1), '$strongPass!');
      await frames(tester, 4);
      expect(find.text('The two don’t match.'), findsOneWidget);
      expect(create().enabled, isFalse);

      await tester.enterText(fields.at(1), strongPass);
      await frames(tester, 4);
      expect(find.text('The two don’t match.'), findsNothing);
      expect(create().enabled, isTrue);
      // The passphrase is hidden and never learnt by the keyboard.
      final field = tester.widget<TextField>(fields.at(0));
      expect(field.obscureText, isTrue);
      expect(field.enableIMEPersonalizedLearning, isFalse);
      expect(field.enableSuggestions, isFalse);

      await tester.tap(sheetButton('Create backup'));
      await settleAsync(tester, rounds: 20);
      expect(find.text('Backup ready'), findsOneWidget);
      expect(find.textContaining('.madarbackup'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(env.bridge.shared, isEmpty);

      await tester.tap(sheetButton('Save to…'));
      await settleAsync(tester, rounds: 6);
      final saved = env.bridge.saved.single;
      expect(saved.encrypted, isTrue);
      expect(saved.name, 'madar-backup-2026-09-30-1000.madarbackup');
      expect(utf8.decode(saved.bytes.sublist(0, 8)), 'MADARBAK');
      final last = await tester.runAsync(() => KeyValueRepository(env.db).getJson(lastBackupKey));
      expect(last, dataTestNow.toUtc().toIso8601String());
      expect(env.haptics.fired, isNotEmpty);
    });
  });

  group('RestoreFlow', () {
    testWidgets('pick → wrong passphrase → unlock → preview → confirm → restored', (tester) async {
      usePhone(tester);
      final backup = await makeBackup(tester);
      RestoreResult? restored;
      final (app, env) = await buildDataApp(
        tester,
        home: RestoreFlow(onRestored: (r) => restored = r),
        beforePump: (db) => db.into(db.tasks).insert(TasksCompanion.insert(title: 'current task')),
      );
      env.bridge.picked = (name: 'phone.madarbackup', bytes: backup);
      await tester.pumpWidget(app);
      await settleAsync(tester, rounds: 4);

      expect(find.text('Bring your data back'), findsOneWidget);
      await tester.tap(find.text('Choose backup file'));
      await settleAsync(tester, rounds: 4);
      await frames(tester);
      expect(find.textContaining('phone.madarbackup'), findsOneWidget);
      expect(find.textContaining('Made on'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'not the passphrase');
      await tester.tap(find.text('Unlock backup'));
      await settleAsync(tester, rounds: 10);
      await frames(tester);
      expect(find.text('That passphrase doesn’t open this backup. Check for typos and try again.'), findsOneWidget);
      expect(env.sound.played, contains(Sfx.error));

      await tester.enterText(find.byType(TextField), strongPass);
      await tester.tap(find.text('Unlock backup'));
      await settleAsync(tester, rounds: 10);
      await frames(tester);
      expect(find.text('The backup is intact'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Replace my data'), 200, scrollable: find.byType(Scrollable).first);
      MadarButton replace() => tester.widget<MadarButton>(find.widgetWithText(MadarButton, 'Replace my data'));
      expect(replace().onPressed, isNull, reason: 'needs the explicit “I understand” first');
      await tester.ensureVisible(find.byType(MadarSwitch));
      await frames(tester, 6);
      await tester.tap(find.byType(MadarSwitch));
      await frames(tester, 6);
      expect(replace().onPressed, isNotNull);

      await tester.ensureVisible(find.text('Replace my data'));
      await frames(tester, 6);
      await tester.tap(find.text('Replace my data'));
      await settleAsync(tester, rounds: 30);
      await frames(tester);
      expect(find.text('Restored'), findsOneWidget);
      expect(restored, isNotNull);
      expect(restored!.previousRecords, 1);
      final tasks = await tester.runAsync(() => env.db.select(env.db.tasks).get());
      expect(tasks!.map((t) => t.title), isNot(contains('current task')));
      final copies = await tester.runAsync(() => env.safetyDir.list().toList());
      expect(copies, hasLength(1));
    });

    testWidgets('a file that is not a backup is explained, nothing changes', (tester) async {
      usePhone(tester);
      final (app, env) = await buildDataApp(tester, home: const RestoreFlow());
      env.bridge.picked = (name: 'photo.jpg', bytes: Uint8List.fromList(List.filled(64, 3)));
      await tester.pumpWidget(app);
      await settleAsync(tester, rounds: 4);
      await tester.tap(find.text('Choose backup file'));
      await settleAsync(tester, rounds: 4);
      await frames(tester);
      expect(find.text('This isn’t a Madar backup'), findsOneWidget);
      expect(find.text('Nothing in your data was changed.'), findsOneWidget);
      await tester.tap(find.text('Choose another file'));
      await frames(tester);
      expect(find.text('Bring your data back'), findsOneWidget);
    });

    testWidgets('a truncated backup is explained', (tester) async {
      usePhone(tester);
      final backup = await makeBackup(tester);
      final (app, env) = await buildDataApp(tester, home: const RestoreFlow());
      env.bridge.picked = (name: 'cut.madarbackup', bytes: Uint8List.sublistView(backup, 0, backup.length - 100));
      await tester.pumpWidget(app);
      await settleAsync(tester, rounds: 4);
      await tester.tap(find.text('Choose backup file'));
      await settleAsync(tester, rounds: 4);
      await frames(tester);
      expect(find.text('The file is incomplete'), findsOneWidget);
    });
  });

  group('ExportPreviewSheet', () {
    testWidgets('per-section switches change exactly what is shared', (tester) async {
      usePhone(tester);
      late SummaryInput input;
      final (app, env) = await buildDataApp(
        tester,
        home: Builder(builder: (_) => const SizedBox()),
        beforePump: (db) async {
          await seedSummaryScenario(db);
          input = await DataExportRepository(db, useIsolate: false).loadSummaryInput(dataTestNow);
        },
      );
      await tester.pumpWidget(app);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      showInteractionSheet<String>(nav.context, builder: (_) => ExportPreviewSheet(input: input));
      await settleAsync(tester, rounds: 8);
      await frames(tester);

      String preview() => tester.widget<SelectableText>(find.byType(SelectableText)).data!;
      expect(preview(), contains('## Faith'));
      expect(preview(), contains('## Health'));
      expect(preview(), isNot(contains('## Profile')));

      await tester.tap(find.byWidgetPredicate((w) => w is MadarSwitch && w.semanticLabel == 'Faith'));
      await frames(tester, 6);
      expect(preview(), isNot(contains('## Faith')));
      expect(preview(), contains('## Health'));

      await tester.tap(sheetButton('Copy'));
      await settleAsync(tester, rounds: 4);
      expect(env.bridge.copied.single.trimRight(), preview());
      expect(env.bridge.copied.single, isNot(contains('## Faith')));
      expect(env.bridge.copied.single, contains('## Money'));

      await tester.tap(sheetButton('Share'));
      await settleAsync(tester, rounds: 4);
      expect(env.bridge.shared.single.name, 'madar-summary-2026-09-30.md');
      expect(utf8.decode(env.bridge.shared.single.bytes), env.bridge.copied.single);

      // The choice is remembered in the encrypted database.
      await settleAsync(tester, rounds: 4);
      final stored = await tester.runAsync(() => DataExportRepository(env.db, useIsolate: false).summaryOptions());
      expect(stored!.included, isNot(contains(SummarySectionId.faith)));
      await frames(tester, 20); // let the debounce timer finish
    });

    testWidgets('select mode returns the reviewed Markdown to the caller', (tester) async {
      usePhone(tester);
      late SummaryInput input;
      final (app, _) = await buildDataApp(
        tester,
        home: const SizedBox(),
        beforePump: (db) async {
          await seedSummaryScenario(db);
          input = await DataExportRepository(db, useIsolate: false).loadSummaryInput(dataTestNow);
        },
      );
      await tester.pumpWidget(app);
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      String? result;
      showInteractionSheet<String>(
        nav.context,
        builder: (_) => ExportPreviewSheet(input: input, mode: ExportPreviewMode.select),
      ).then((v) => result = v);
      await settleAsync(tester, rounds: 8);
      await frames(tester);
      await tester.tap(sheetButton('Use this summary'));
      await frames(tester, 20);
      expect(result, startsWith('# Madar summary — 2026-09-30'));
      expect(result, contains('## Travel'));
      expect(result, isNot(contains('N1234567')));
    });
  });

  group('CsvExportSheet', () {
    testWidgets('pick a table and range, then save', (tester) async {
      usePhone(tester);
      final (app, env) = await buildDataApp(
        tester,
        home: const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: CsvExportSheet())),
        beforePump: (db) => seedSummaryScenario(db),
      );
      await tester.pumpWidget(app);
      await settleAsync(tester, rounds: 6);
      expect(find.text('Labs · 2'), findsOneWidget); // default range: 90 days
      await tester.tap(find.text('Mood · 3'));
      await frames(tester, 4);
      await tester.tap(find.text('30 days'));
      await settleAsync(tester, rounds: 6);
      expect(find.text('Mood · 2'), findsOneWidget);
      await tester.tap(sheetButton('Create file (2 rows)'));
      await settleAsync(tester, rounds: 6);
      await frames(tester);
      expect(find.textContaining('madar-mood-2026-09-01_2026-09-30.csv'), findsOneWidget);
      await tester.tap(sheetButton('Save to…'));
      await settleAsync(tester, rounds: 4);
      expect(env.bridge.saved.single.mimeType, 'text/csv');
      expect(env.bridge.saved.single.records, 2);
    });
  });
}
