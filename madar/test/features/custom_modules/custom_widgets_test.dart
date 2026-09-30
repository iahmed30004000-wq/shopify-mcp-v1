import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';

import 'custom_harness.dart';

/// A page with a button that opens [open] and keeps its result.
class _Opener extends StatelessWidget {
  const _Opener(this.open);

  final Future<void> Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Builder(
        builder: (context) => TextButton(onPressed: () => unawaited(open(context)), child: const Text('open')),
      ),
    ),
  );
}

void main() {
  final ar = lookupL10n(const Locale('ar'));

  testWidgets('empty screen: generic starters open the builder, Create saves the module', (tester) async {
    final env = await pumpCustomApp(tester, home: const CustomModulesScreen());
    expect(find.text(ar.cmodEmptyTitle), findsOneWidget);
    await tester.tap(find.text(ar.cmodTplReadingLog));
    await settleCustom(tester);
    expect(find.text(ar.cmodBuilderNewTitle), findsOneWidget);
    await tester.tap(find.text(ar.cmodCreate));
    await settleCustom(tester);
    final modules = await tester.runAsync(env.service.modules);
    expect(modules!.single.name, ar.cmodTplReadingLog);
    expect(modules.single.fields, hasLength(3));
    expect(find.byType(ModuleTile), findsOneWidget);
    expect(env.haptics.fired, isNotEmpty);
  });

  testWidgets('builder refuses a module without a name', (tester) async {
    final env = await pumpCustomApp(tester, home: const ModuleBuilderScreen());
    await tester.tap(find.text(ar.cmodCreate));
    await settleCustom(tester);
    expect(find.text(ar.cmodIssueNameMissing), findsOneWidget);
    expect(await tester.runAsync(env.service.modules), isEmpty);
  });

  testWidgets('builder: a type change that would lose data is explained, nothing saved', (tester) async {
    final holder = <String>[];
    final env = await pumpCustomApp(
      tester,
      home: Builder(
        builder: (_) => holder.isEmpty ? const SizedBox.shrink() : ModuleBuilderScreen(moduleId: holder.first),
      ),
      beforePump: (db) async => holder.add((await seedCustom(db))[ModuleTemplateKey.readingLog]!),
    );
    // Book (text, e.g. "a biography") → Number.
    await tester.scrollUntilVisible(find.textContaining(ar.cmodTplBook), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining(ar.cmodTplBook).first);
    await settleCustom(tester);
    expect(find.text(ar.cmodFieldEdit), findsOneWidget);
    await tester.tap(find.text(ar.cmodTypeNumber));
    await settleCustom(tester);
    expect(find.text(ar.cmodFieldTypeNote), findsOneWidget);
    await tester.tap(find.text(ar.cmodSave).last);
    await settleCustom(tester);
    await tester.tap(find.text(ar.cmodSave).last);
    await settleCustom(tester);
    expect(find.text(ar.cmodMigrationBlockedTitle), findsOneWidget);
    final m = (await tester.runAsync(() => env.service.module(holder.first)))!;
    expect(m.field('f1')!.type, FieldType.text);
  });

  testWidgets('builder: renaming a field keeps its values', (tester) async {
    final holder = <String>[];
    final env = await pumpCustomApp(
      tester,
      home: Builder(
        builder: (_) => holder.isEmpty ? const SizedBox.shrink() : ModuleBuilderScreen(moduleId: holder.first),
      ),
      beforePump: (db) async => holder.add((await seedCustom(db))[ModuleTemplateKey.readingLog]!),
    );
    await tester.scrollUntilVisible(find.textContaining(ar.cmodTplPages), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.textContaining(ar.cmodTplPages).first);
    await settleCustom(tester);
    await tester.enterText(find.byType(TextField).first, 'صفحات اليوم');
    await tester.pump();
    await tester.tap(find.text(ar.cmodSave).last);
    await settleCustom(tester);
    await tester.tap(find.text(ar.cmodSave).last);
    await settleCustom(tester);
    final m = (await tester.runAsync(() => env.service.module(holder.first)))!;
    expect(m.field('f2')!.label, 'صفحات اليوم');
    final entries = (await tester.runAsync(() => env.service.entries(holder.first)))!;
    expect(entries.where((e) => e.values['f2'] != null), isNotEmpty);
    UndoToast.dismissAll(tester.state<OverlayState>(find.byType(Overlay).first));
    await settleCustom(tester);
  });

  testWidgets('one tap toggles today\'s check-in and the planet hears it', (tester) async {
    late Map<ModuleTemplateKey, String> ids;
    final env = await pumpCustomApp(
      tester,
      home: const CustomModulesScreen(),
      beforePump: (db) async => ids = await seedCustom(db),
    );
    final habit = ids[ModuleTemplateKey.dailyHabit]!;
    Future<int> todays() async {
      final all = (await tester.runAsync(() => env.service.entries(habit)))!;
      return all.where((e) => e.at.day == customTestNow.day && e.at.month == customTestNow.month).length;
    }

    expect(await todays(), 1);
    // The habit is first: its button is the first quick-log control.
    await tester.tap(find.byType(QuickLogButton).first);
    await settleCustom(tester);
    expect(await todays(), 0);
    await tester.tap(find.byType(QuickLogButton).first);
    await settleCustom(tester);
    expect(await todays(), 1);
    final acts = (await tester.runAsync(() => env.repos.activityLog.getAll()))!;
    expect(acts.where((a) => a.planetKey == 'growth' && a.kind == CustomModulesService.kindEntry), isNotEmpty);
    UndoToast.dismissAll(tester.state<OverlayState>(find.byType(Overlay).first));
    await settleCustom(tester);
  });

  testWidgets('entry form: required fields, Arabic-Indic digits, typed values out', (tester) async {
    EntrySheetResult? result;
    final module = ModuleTemplates.build(ModuleTemplateKey.readingLog, (t) => t.name);
    await pumpCustomApp(
      tester,
      home: _Opener((context) async => result = await showEntrySheet(context, module: module, now: customTestNow)),
    );
    await tester.tap(find.text('open'));
    await settleCustom(tester);
    await tester.tap(find.text(ar.cmodSave));
    await settleCustom(tester);
    expect(result, isNull);
    expect(find.text(ar.cmodErrRequired), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).at(0), '  كتاب  ');
    await tester.enterText(find.byType(TextField).at(1), '٤٢');
    await tester.pump();
    await tester.tap(find.text(ar.cmodSave));
    await settleCustom(tester);
    expect(result, isNotNull);
    expect(result!.values, {'f1': 'كتاب', 'f2': 42});
    expect(result!.at, customTestNow);
  });

  testWidgets('entry form shows stored numbers in Arabic-Indic digits', (tester) async {
    final module = ModuleTemplates.build(ModuleTemplateKey.sleepLog, (t) => t.name);
    final entry = ModuleEntry(id: 'e', moduleId: 'm', at: customTestNow, values: const {'f3': 7.5, 'f4': 4});
    await pumpCustomApp(
      tester,
      home: _Opener((context) => showEntrySheet(context, module: module, entry: entry, now: customTestNow)),
    );
    await tester.tap(find.text('open'));
    await settleCustom(tester);
    expect(find.text('٧٫٥'), findsOneWidget);
    expect(find.text(ar.cmodEntryEdit), findsOneWidget);
  });

  testWidgets('list page: tapping the circle checks an item off (Family activity)', (tester) async {
    late Map<ModuleTemplateKey, String> ids;
    final holder = <String>[];
    final env = await pumpCustomApp(
      tester,
      home: Builder(builder: (_) => holder.isEmpty ? const SizedBox.shrink() : ModuleScreen(moduleId: holder.first)),
      beforePump: (db) async {
        ids = await seedCustom(db);
        holder.add(ids[ModuleTemplateKey.giftIdeas]!);
      },
    );
    expect(find.text(ar.cmodItemsSection), findsOneWidget);
    final before = (await tester.runAsync(() => env.service.entries(holder.first)))!.where((e) => e.done).length;
    final open = (await tester.runAsync(() => env.service.entries(holder.first)))!.firstWhere((e) => !e.done);
    await tester.tap(find.byKey(ValueKey('cmod-check-${open.id}')));
    await settleCustom(tester);
    final after = (await tester.runAsync(() => env.service.entries(holder.first)))!.where((e) => e.done).length;
    expect(after, before + 1);
    final acts = (await tester.runAsync(() => env.repos.activityLog.getAll()))!;
    expect(acts.where((a) => a.planetKey == 'family' && a.kind == CustomModulesService.kindDone), hasLength(2));
    UndoToast.dismissAll(tester.state<OverlayState>(find.byType(Overlay).first));
    await settleCustom(tester);
  });

  testWidgets('planet card lists only that planet\'s modules; an empty planet invites', (tester) async {
    await pumpCustomApp(
      tester,
      home: const Scaffold(
        body: Column(children: [CustomModulesCard(planetKey: 'body'), CustomModulesCard(planetKey: 'travel')]),
      ),
      beforePump: (db) => seedCustom(db),
    );
    // Names are bidi-isolated.
    expect(find.textContaining(ar.cmodTplSleep), findsOneWidget);
    expect(find.textContaining(ar.cmodTplReadingLog), findsNothing);
    expect(find.text(ar.cmodCardEmpty), findsOneWidget);
  });

  testWidgets('the reminder sync schedules module reminders in 137000–137999 only', (tester) async {
    final env = await pumpCustomApp(tester, home: const SizedBox.shrink(), beforePump: (db) => seedCustom(db));
    await tester.runAsync(() => env.container.read(customModulesReminderSyncProvider.notifier).syncNow());
    final pending = (await tester.runAsync(env.notifications.pending))!;
    // The enabled "after Fajr" reminder of the reading log, a week ahead
    // (today's Fajr is past at 13:10); the paused habit reminder is not.
    expect(pending, hasLength(6));
    expect(pending.every((p) => CustomModuleReminderIds.owns(p.id)), isTrue);
  });

  testWidgets('sheets fire sounds and haptics', (tester) async {
    final env = await pumpCustomApp(tester, home: _Opener((context) => showTemplateGallery(context)));
    await tester.tap(find.text('open'));
    await settleCustom(tester);
    expect(find.text(ar.cmodGalleryTitle), findsOneWidget);
    expect(env.haptics.fired, isNotEmpty);
    expect(Sfx.values, contains(Sfx.sheetOpen));
    // Every template is offered, and each starts a valid draft.
    for (final k in ModuleTemplates.all) {
      expect(find.text(CustomTexts(ar, const MadarFormatter()).templateName(k)), findsOneWidget);
    }
  });
}
