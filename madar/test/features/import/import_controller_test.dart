import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/import/import.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/import/import_controller.dart';

String fixture(String name) => File('test/fixtures/import/$name.json').readAsStringSync();

void main() {
  late MadarDatabase db;
  late ProviderContainer container;
  final labels = ImportLabels.forLanguage('en');

  ProviderContainer make({Future<PickedJson?> Function()? picker}) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        if (picker != null) importFilePickerProvider.overrideWithValue(picker),
      ],
    );
    c.listen(importControllerProvider, (_, _) {}); // keep the auto-dispose controller alive
    return c;
  }

  setUp(() {
    db = MadarDatabase(NativeDatabase.memory());
    container = make();
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ImportController ctrl([ProviderContainer? c]) => (c ?? container).read(importControllerProvider.notifier);
  ImportState state([ProviderContainer? c]) => (c ?? container).read(importControllerProvider);

  test('starts idle', () {
    expect(state().stage, ImportStage.idle);
    expect(state().canImport, isFalse);
  });

  test('paste → preview → import → done', () async {
    await ctrl().analyzeText(fixture('prototype_nested_en'), labels: labels);
    expect(state().stage, ImportStage.preview);
    expect(state().plan!.report.count(ImportSection.medications), 4);
    expect(state().needsDuplicateConfirmation, isFalse);
    expect(state().canImport, isTrue);

    await ctrl().commit();
    expect(state().stage, ImportStage.done);
    expect(state().progress, 1);
    expect(state().result!.totalInserted, state().plan!.report.totalPlanned);
    expect((await db.select(db.medications).get()), hasLength(4));
  });

  test('a file imported before asks for confirmation and never duplicates', () async {
    await ctrl().analyzeText(fixture('prototype_flat_ar'), labels: labels);
    await ctrl().commit();
    final medsAfterFirst = (await db.select(db.medications).get()).length;

    ctrl().reset();
    await ctrl().analyzeText(fixture('prototype_flat_ar'), labels: labels);
    expect(state().stage, ImportStage.preview);
    expect(state().needsDuplicateConfirmation, isTrue);
    expect(state().canImport, isFalse);
    await ctrl().commit(); // ignored until confirmed
    expect(state().stage, ImportStage.preview);

    ctrl().setAllowDuplicate(true);
    expect(state().canImport, isTrue);
    await ctrl().commit();
    expect(state().stage, ImportStage.done);
    expect(state().result!.totalInserted, 0);
    expect((await db.select(db.medications).get()).length, medsAfterFirst);
  });

  test('invalid, empty and scalar input end in a failure state', () async {
    await ctrl().analyzeText('{oops', labels: labels);
    expect((state().stage, state().failure), (ImportStage.failure, ImportFailure.invalidJson));
    await ctrl().analyzeText('', labels: labels);
    expect(state().failure, ImportFailure.empty);
    await ctrl().analyzeText('"text"', labels: labels);
    expect(state().failure, ImportFailure.notAnObject);
    ctrl().reset();
    expect(state().stage, ImportStage.idle);
  });

  test('picking a file analyses it; cancelling keeps the state; errors are reported', () async {
    final picked = make(picker: () async => (name: 'export.json', text: fixture('prototype_nested_en')));
    addTearDown(picked.dispose);
    await ctrl(picked).pickFile(labels);
    expect(state(picked).stage, ImportStage.preview);
    expect(state(picked).fileName, 'export.json');

    final cancelled = make(picker: () async => null);
    addTearDown(cancelled.dispose);
    await ctrl(cancelled).pickFile(labels);
    expect(state(cancelled).stage, ImportStage.idle);

    final broken = make(picker: () async => throw const FileSystemException('denied'));
    addTearDown(broken.dispose);
    await ctrl(broken).pickFile(labels);
    expect((state(broken).stage, state(broken).failure), (ImportStage.failure, ImportFailure.unreadable));
  });
}
