import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/open.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/rewards/application/rewards_providers.dart';
import 'package:madar/features/kids/rewards/data/rewards_store.dart';
import 'package:madar/features/kids/rewards/domain/lanterns.dart';
import 'package:madar/features/kids/rewards/domain/rewards_ledger.dart';
import 'package:madar/features/kids/rewards/presentation/rewards_screen.dart';
import 'package:madar/features/kids/rewards/rewards.dart';

import 'kids_fakes.dart';
import '../../../helpers/screenshot_harness.dart' show loadMadarFonts;

final _day1 = DateTime(2026, 11, 10, 15);
final _day2 = DateTime(2026, 11, 11, 9);

ProviderContainer _container(MemoryKidsStore store, DateTime Function() clock) {
  final c = ProviderContainer(
    overrides: [
      kidsRewardsStoreProvider.overrideWithValue(RewardsStore(store)),
      kidsRewardsClockProvider.overrideWithValue(clock),
      ...kidsRewardsOverrides,
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('ledger', () {
    test('one star per reason per day', () {
      final a = RewardsLedger.empty.award('game.pairs', _day1)!;
      expect(a.count, 1);
      expect(a.award('game.pairs', _day1.add(const Duration(hours: 3))), isNull, reason: 'same day: no farming');
      expect(a.award('story.little_star', _day1)!.count, 2, reason: 'another reason');
      expect(a.award('game.pairs', _day2)!.count, 2, reason: 'next day');
    });

    test('nothing in the type can lower the count', () {
      var l = RewardsLedger.empty;
      for (var i = 0; i < 5; i++) {
        l = l.award('r$i', _day1)!;
      }
      expect(l.count, 5);
      final merged = l.union(RewardsLedger.empty);
      expect(merged.count, 5);
      expect(RewardsLedger.empty.union(l).count, 5);
    });

    test('an empty reason and a very long one are tidied, not rejected', () {
      expect(RewardsLedger.empty.award('  ', _day1)!.entries.single.reason, 'star');
      expect(RewardsLedger.empty.award('x' * 200, _day1)!.entries.single.reason.length, RewardsLedger.maxReasonLength);
    });

    test('json round trip, and a damaged document is skipped not thrown', () {
      final l = RewardsLedger.empty.award('a', _day1)!.award('b', _day2)!;
      expect(RewardsLedger.fromJson(l.toJson()).count, 2);
      expect(RewardsLedger.fromJson('nonsense').count, 0);
      expect(
        RewardsLedger.fromJson([
          ['ok', '2026-11-10', 1],
          5,
          [],
          ['', 'd'],
          ['ok', '2026-11-10', 2],
        ]).count,
        1,
      );
    });

    test('the day is the local calendar day', () {
      expect(RewardsLedger.dayKey(DateTime(2026, 1, 2, 23, 59)), '2026-01-02');
    });
  });

  group('lanterns', () {
    test('they light as the count crosses each threshold and never go out', () {
      expect(Lanterns.litCount(0), 0);
      expect(Lanterns.litCount(2), 0);
      expect(Lanterns.litCount(3), 1);
      expect(Lanterns.litCount(24), 5);
      expect(Lanterns.nextThreshold(24), 30);
      expect(Lanterns.starsToNext(24), 6);
      var prev = 0;
      for (var s = 0; s < 120; s++) {
        final n = Lanterns.litCount(s);
        expect(n, greaterThanOrEqualTo(prev));
        prev = n;
      }
      expect(Lanterns.litCount(10000), Lanterns.total);
      expect(Lanterns.nextThreshold(10000), isNull);
      expect(Lanterns.starsToNext(10000), 0);
      expect(Lanterns.progress(10000), 1);
    });

    test('progress runs between the last lantern and the next', () {
      expect(Lanterns.progress(0), 0);
      expect(Lanterns.progress(25), closeTo(0.5, 1e-9));
    });
  });

  group('store: write then confirm', () {
    test('a clean save leaves only the real slot', () async {
      final mem = MemoryKidsStore();
      final store = RewardsStore(mem);
      await store.save(RewardsLedger.empty.award('a', _day1)!);
      expect(mem.data.containsKey(RewardsStore.pendingKey), isFalse);
      expect((await RewardsStore(mem).load()).count, 1);
    });

    for (var dieAfter = 0; dieAfter <= 3; dieAfter++) {
      test('the phone dies after $dieAfter of the 3 writes of a star: nothing earned before is lost', () async {
        final mem = MemoryKidsStore();
        final first = RewardsLedger.empty.award('a', _day1)!;
        await RewardsStore(mem).save(first);
        mem.writes = 0;
        mem.writesBeforeDeath = dieAfter;
        final second = first.award('b', _day1)!;
        await expectLater(RewardsStore(mem).save(second), dieAfter >= 3 ? completes : throwsA(isA<PhoneDied>()));

        // Restart on the same storage.
        mem.writesBeforeDeath = null;
        final after = await RewardsStore(mem).load();
        expect(after.count, greaterThanOrEqualTo(1), reason: 'the first star is never lost');
        if (dieAfter >= 1) {
          expect(after.count, 2, reason: 'the pending slot was written, so the star is recovered');
        } else {
          expect(after.count, 1, reason: 'died before anything was written');
        }
        expect(mem.data.containsKey(RewardsStore.pendingKey), isFalse, reason: 'recovery finishes the job');
      });
    }

    test('a damaged real slot falls back to what is pending', () async {
      final mem = MemoryKidsStore({
        RewardsStore.ledgerKey: 'garbage',
        RewardsStore.pendingKey: RewardsLedger.empty.award('a', _day1)!.toJson(),
      });
      expect((await RewardsStore(mem).load()).count, 1);
    });
  });

  group('providers (the overrides the integrator adds)', () {
    test('award writes one star with its reason, de-duplicated per day', () async {
      final mem = MemoryKidsStore();
      var now = _day1;
      final c = _container(mem, () => now);
      await c.read(kidsRewardsProvider.notifier).ready;
      expect(c.read(kidsStarCountProvider), 0);

      final award = c.read(kidsStarAwardProvider);
      await award('game.pairs');
      await award('game.pairs');
      await award('game.pairs');
      expect(c.read(kidsStarCountProvider), 1, reason: 'three taps, one star');
      expect((mem.data[RewardsStore.ledgerKey]! as List).single[0], 'game.pairs');

      now = _day2;
      await award('game.pairs');
      expect(c.read(kidsStarCountProvider), 2);
    });

    test('stars survive a restart', () async {
      final mem = MemoryKidsStore();
      final c1 = _container(mem, () => _day1);
      await c1.read(kidsRewardsProvider.notifier).ready;
      await c1.read(kidsStarAwardProvider)('story.little_star');
      c1.dispose();

      final c2 = _container(mem, () => _day1);
      expect(c2.read(kidsStarCountProvider), 0, reason: 'not loaded yet');
      await c2.read(kidsRewardsProvider.notifier).ready;
      expect(c2.read(kidsStarCountProvider), 1);
    });

    test('an award made before the load finishes is not lost or doubled', () async {
      final mem = MemoryKidsStore({RewardsStore.ledgerKey: RewardsLedger.empty.award('old', _day1)!.toJson()});
      final c = _container(mem, () => _day2);
      await c.read(kidsStarAwardProvider)('new'); // straight away, no wait
      expect(c.read(kidsStarCountProvider), 2);
    });

    test('a star is shown only after it is on the device', () async {
      final mem = MemoryKidsStore();
      final c = _container(mem, () => _day1);
      await c.read(kidsRewardsProvider.notifier).ready;
      mem.writesBeforeDeath = 1; // dies on the second write of the save
      final added = await c.read(kidsRewardsProvider.notifier).award('a');
      expect(added, isFalse);
      expect(c.read(kidsStarCountProvider), 0, reason: 'the child never sees a star that was not kept');
      // Restart: the pending star is recovered.
      mem.writesBeforeDeath = null;
      final c2 = _container(mem, () => _day1);
      await c2.read(kidsRewardsProvider.notifier).ready;
      expect(c2.read(kidsStarCountProvider), 1);
    });

    test('works on the real key/value repository (encrypted database), offline', () async {
      final db = await openInMemoryMadarDatabase();
      addTearDown(db.close);
      final c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          kidsRewardsClockProvider.overrideWithValue(() => _day1),
          ...kidsRewardsOverrides,
        ],
      );
      addTearDown(c.dispose);
      await c.read(kidsRewardsProvider.notifier).ready;
      await c.read(kidsStarAwardProvider)('a');
      expect(c.read(kidsStarCountProvider), 1);
      final c2 = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db), ...kidsRewardsOverrides]);
      addTearDown(c2.dispose);
      await c2.read(kidsRewardsProvider.notifier).ready;
      expect(c2.read(kidsStarCountProvider), 1);
    });
  });

  group('screen', () {
    Future<void> pump(
      WidgetTester tester,
      int stars, {
      double scale = 1.0,
      Size size = const Size(360, 780),
      Locale locale = const Locale('ar'),
    }) async {
      await tester.runAsync(loadMadarFonts);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [kidsStarCountProvider.overrideWithValue(stars)],
          child: MaterialApp(
            locale: locale,
            supportedLocales: L10n.supportedLocales,
            localizationsDelegates: L10n.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const RewardsScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('24 stars: five lanterns lit, six to the next', (tester) async {
      await pump(tester, 24);
      expect(find.bySemanticsLabel(RegExp('مضوي')), findsNWidgets(5));
      expect(find.bySemanticsLabel(RegExp('لسا ما انضوى')), findsNWidgets(4));
      expect(find.textContaining('٢٤'), findsWidgets);
      expect(find.textContaining('٦'), findsWidgets);
      expect(find.text('نجومك محفوظة على جوالك'), findsOneWidget);
    });

    testWidgets('no stars yet: calm, nothing lit, no error', (tester) async {
      await pump(tester, 0);
      expect(find.bySemanticsLabel(RegExp('مضوي')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('text scale 1.3 at 320 dp does not overflow, in Arabic and English', (tester) async {
      await pump(tester, 24, scale: 1.3, size: const Size(320, 640));
      expect(tester.takeException(), isNull);
      await pump(tester, 80, scale: 1.3, size: const Size(320, 640), locale: const Locale('en'));
      expect(tester.takeException(), isNull);
      expect(find.text('All the lanterns are lit!'), findsOneWidget);
    });

    test('the section is the one the shell lists', () {
      expect(rewardsSection.id, 'rewards');
      expect(rewardsSection.religious, isFalse);
    });
  });
}
