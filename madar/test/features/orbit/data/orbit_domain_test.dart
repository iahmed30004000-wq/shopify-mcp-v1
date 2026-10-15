import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/orbit_moons.dart';
import 'package:madar/features/orbit/domain/planet_archetypes.dart';
import 'package:madar/features/orbit/domain/planet_extras.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';
import 'package:madar/features/orbit/domain/score_sources.dart';

void main() {
  const engine = PlanetScoreEngine();
  final now = DateTime(2026, 9, 27, 16);

  group('ScoreSources', () {
    test('seeded aliases map onto the engine keys and are merged', () {
      expect(ScoreSources.canonical('medications'), 'doses');
      expect(ScoreSources.canonical('boards'), 'cards');
      expect(ScoreSources.canonical('learning'), 'goals');
      expect(ScoreSources.canonicalWeights({'medications': 0.3, 'doses': 0.2, 'mood': 'x', 'pain': -1, 'tasks': 1}), {
        'doses': 0.5,
        'tasks': 1.0,
      });
      expect(ScoreSources.isKnown('module:abc'), isTrue);
      expect(ScoreSources.isKnown('labs'), isFalse);
      expect(ScoreSources.suggestedFor('body').take(4), ['workouts', 'fasting', 'water', 'tasks']);
    });
  });

  group('engine extensions', () {
    test('a switched-off source neither counts nor produces reasons', () {
      final inputs = ScoreInputs(now: now, workoutsExpected7d: 4, workoutsDone7d: 4, waterTargetMl: 2000);
      final on = engine.compute(inputs)['body']!;
      expect(on.reasons.map((r) => r.code), contains(ReasonCode.waterLow));
      final off = engine.compute(
        inputs,
        weights: {
          'body': {'water': 0},
        },
      )['body']!;
      expect(off.reasons.map((r) => r.code), isNot(contains(ReasonCode.waterLow)));
      expect(off.sources.keys, isNot(contains('water')));
    });

    test('a custom planet derives the sources its weights ask for', () {
      final inputs = ScoreInputs(now: now, workoutsExpected7d: 4, workoutsDone7d: 1);
      final scores = engine.compute(
        inputs,
        planetKeys: ['custom_sport', 'body'],
        weights: {
          'custom_sport': {'workouts': 1},
        },
      );
      expect(scores['custom_sport']!.dormant, isFalse);
      expect(scores['custom_sport']!.sources['workouts'], 0.25);
      expect(scores['custom_sport']!.reasons.single.planetKey, 'custom_sport');
      // A custom planet without sources stays dormant.
      expect(engine.compute(inputs, planetKeys: ['custom_x'])['custom_x']!.dormant, isTrue);
    });

    test('seeded alias weights work (medications → doses)', () {
      final today = DateTime(2026, 9, 27);
      final inputs = ScoreInputs(
        now: now,
        doses3d: [DoseIn(medId: 'm', medName: 'M', scheduledAt: today.add(const Duration(hours: 8)), taken: false)],
      );
      final off = engine.compute(
        inputs,
        weights: {
          'health': {'medications': 0},
        },
      )['health']!;
      expect(off.dormant, isTrue);
    });

    test('habits: only tracked habits count; slipping ones are named', () {
      final scores = engine.compute(
        ScoreInputs(
          now: now,
          habits: [
            HabitIn(id: 'h1', name: 'Walk', planetKey: 'body', doneDays7d: 5, lastDone: DateTime(2026, 9, 27)),
            HabitIn(id: 'h2', name: 'Stretch', planetKey: 'body', doneDays7d: 1, lastDone: DateTime(2026, 9, 22)),
            const HabitIn(id: 'h3', name: 'Seeded, never used', planetKey: 'body', doneDays7d: 0),
            HabitIn(id: 'h4', name: 'Breathing', doneDays7d: 7, lastDone: DateTime(2026, 9, 27)),
          ],
        ),
      );
      final body = scores['body']!;
      expect(body.sources['habits'], closeTo(((5 / 7) + (1 / 7)) / 2 / 0.7, 1e-9));
      final slip = body.reasons.single;
      expect(slip.code, ReasonCode.habitsSlipping);
      expect(slip.args, {'count': 1, 'name': 'Stretch', 'days': 5});
      // A habit without a planet belongs to Health.
      expect(scores['health']!.sources['habits'], 1.0);
    });

    test('mood and pain are gentle mirrors without reasons', () {
      final scores = engine.compute(
        ScoreInputs(
          now: now,
          moods7d: [MoodIn(at: now, mood: 1, stress: 10)],
          pains7d: [PainIn(at: now, score: 10)],
        ),
      );
      final health = scores['health']!;
      expect(health.sources['mood'], 0.5);
      expect(health.sources['pain'], closeTo(0.4, 1e-9));
      expect(health.reasons, isEmpty);
    });

    test('projects, jars, transactions and adhkar produce their reasons', () {
      final scores = engine.compute(
        ScoreInputs(
          now: now,
          projectItems: [
            ProjectItemIn(id: 'i1', projectId: 'p', projectName: 'Madar', done: false, dueDate: DateTime(2026, 9, 20)),
            ProjectItemIn(id: 'i2', projectId: 'p', projectName: 'Madar', done: false, dueDate: DateTime(2026, 9, 25)),
          ],
          jars: [
            JarIn(
              id: 'j',
              name: 'Hajj',
              targetMilli: 1000,
              savedMilli: 100,
              start: DateTime(2026, 7, 1),
              deadline: DateTime(2026, 11, 1),
            ),
          ],
          lastTransactionAt: DateTime(2026, 9, 17),
          practices: {'adhkar': PracticeIn(daysDone7d: 2, last: DateTime(2026, 9, 23))},
        ),
      );
      final work = scores['work']!;
      expect(work.reasons.single.code, ReasonCode.projectItemsOverdue);
      expect(work.reasons.single.args, {'count': 2, 'project': 'Madar'});
      final money = scores['money']!;
      expect(money.reasons.map((r) => r.code), containsAll([ReasonCode.jarBehind, ReasonCode.sourceStale]));
      final faith = scores['faith']!;
      expect(faith.sources['adhkar'], closeTo(0.4, 1e-9));
      expect(faith.reasons.single.args, {'source': 'adhkar', 'days': 4});
    });

    test('a quiet planet gets a noActivity reason', () {
      final scores = engine.compute(
        ScoreInputs(
          now: now,
          tasks: const [TaskIn(id: 't', planetKey: 'growth', done: false)],
          lastActivity: {'growth': DateTime(2026, 9, 15)},
        ),
      );
      expect(scores['growth']!.reasons.single.code, ReasonCode.noActivity);
      expect(scores['growth']!.reasons.single.args, {'days': 12});
    });

    test('overdue cards per board carry the board id', () {
      final scores = engine.compute(
        ScoreInputs(
          now: now,
          cards: [
            CardIn(id: 'c1', boardName: 'Jordan', boardId: 'b1', done: false, dueDate: DateTime(2026, 9, 20)),
            CardIn(id: 'c2', boardName: 'Jordan', boardId: 'b1', done: false, dueDate: DateTime(2026, 9, 21)),
          ],
        ),
      );
      final r = scores['work']!.reasons.single;
      expect((r.refTable, r.refId, r.args['count']), ('boards', 'b1', 2));
    });
  });

  group('moons', () {
    final palettes = {for (final e in PlanetPalettes.byKey.entries) e.key: e.value};

    test('person state follows the contact rhythm', () {
      PersonMoonIn p(int? rhythm, int daysAgo) => PersonMoonIn(
        id: 'p',
        name: 'P',
        rhythmDays: rhythm,
        lastContact: now.subtract(Duration(days: daysAgo)),
        createdAt: DateTime(2026),
      );
      expect(MoonRules.personScore(p(null, 90), now), 0.85);
      expect(MoonRules.personScore(p(10, 2), now), 1.0);
      expect(MoonRules.personScore(p(10, 10), now), closeTo(0.6, 1e-9));
      expect(MoonRules.personScore(p(10, 15), now), closeTo(0.3, 1e-9));
      expect(MoonRules.personScore(p(10, 25), now), 0.0);
    });

    test('wallet, board, trip and module states', () {
      expect(MoonRules.walletScore(const WalletMoonIn(id: 'w', name: 'W', balanceBaseMilli: -5), now), 0.15);
      expect(MoonRules.walletScore(WalletMoonIn(id: 'w', name: 'W', balanceBaseMilli: 5, lastTx: now), now), 1.0);
      expect(MoonRules.boardScore(const BoardMoonIn(id: 'b', name: 'B', open: 4, overdue: 4)), closeTo(0.15, 1e-9));
      expect(MoonRules.boardScore(const BoardMoonIn(id: 'b', name: 'B', open: 4)), closeTo(0.9, 1e-9));
      final soon = TripMoonIn(id: 't', destination: 'T', startDate: now.add(const Duration(days: 2)), itemsTotal: 10);
      expect(MoonRules.tripScore(soon, now), closeTo(0.2, 1e-9));
      expect(
        MoonRules.moduleScore(
          ModuleMoonIn(id: 'm', name: 'M', color: 0, planetKey: 'x', createdAt: now, lastEntry: now),
          now,
        ),
        1.0,
      );
      expect(
        MoonRules.moduleScore(
          ModuleMoonIn(id: 'm', name: 'M', color: 0, planetKey: 'x', createdAt: now, tracker: false),
          now,
        ),
        0.8,
      );
    });

    test('hosts, kinds, stable seeds and the palette-derived colours', () {
      final sets = MoonBuilder.build(
        MoonInputs(
          people: [
            PersonMoonIn(id: 'p1', name: 'A', createdAt: now),
            PersonMoonIn(id: 'p2', name: 'B', createdAt: now, color: 0xFF112233),
          ],
          wallets: const [
            WalletMoonIn(id: 'w1', name: 'Cash', balanceBaseMilli: 100),
            WalletMoonIn(id: 'w2', name: 'Bank', balanceBaseMilli: 900),
          ],
          modules: [ModuleMoonIn(id: 'm1', name: 'Quran log', color: 0xFFAA8800, planetKey: 'faith', createdAt: now)],
        ),
        now: now,
        palettes: palettes,
      );
      expect(sets['family']!.moons.map((m) => m.kind), [MoonKind.rocky, MoonKind.rocky]);
      expect(sets['family']!.moons.last.color, const Color(0xFF112233));
      expect(sets['family']!.moons.first.color, isNot(PlanetPalettes.family.surface.withValues(alpha: 0)));
      expect(sets['money']!.moons.map((m) => m.size), [
        closeTo(0.35 + 0.65 * 0.316, 0.01),
        closeTo(0.35 + 0.65 * 0.949, 0.01),
      ]);
      expect(sets['faith']!.moons.single.refTable, 'custom_modules');
      expect(MoonBuilder.seedOf('abc'), MoonBuilder.seedOf('abc'));
      expect(MoonBuilder.seedOf('abc'), isNot(MoonBuilder.seedOf('abd')));
      expect(MoonKind.metallic.shaderLook, 2);
      // A hidden (absent) planet gets no moons.
      final hidden = MoonBuilder.build(
        MoonInputs(
          people: [PersonMoonIn(id: 'p', name: 'A', createdAt: now)],
        ),
        now: now,
        palettes: {'faith': PlanetPalettes.faith},
      );
      expect(hidden, isEmpty);
    });

    test('trips: upcoming first (soonest first), finished and past ones dropped', () {
      final sets = MoonBuilder.build(
        MoonInputs(
          trips: [
            TripMoonIn(id: 'late', destination: 'Later', startDate: now.add(const Duration(days: 30))),
            TripMoonIn(id: 'soon', destination: 'Soon', startDate: now.add(const Duration(days: 3))),
            TripMoonIn(
              id: 'past',
              destination: 'Past',
              startDate: now.subtract(const Duration(days: 30)),
              endDate: now.subtract(const Duration(days: 20)),
            ),
            TripMoonIn(
              id: 'done',
              destination: 'Done',
              status: TripStatus.done,
              startDate: now.add(const Duration(days: 1)),
            ),
            const TripMoonIn(id: 'someday', destination: 'Someday'),
          ],
        ),
        now: now,
        palettes: palettes,
      );
      expect(sets['travel']!.moons.map((m) => m.refId), ['soon', 'late', 'someday']);
    });

    test('the cap keeps the most important and reports the overflow', () {
      final wallets = [for (var i = 0; i < 14; i++) WalletMoonIn(id: 'w$i', name: 'W$i', balanceBaseMilli: i * 100)];
      final set = MoonBuilder.build(
        MoonInputs(wallets: wallets),
        now: now,
        palettes: palettes,
      )['money']!;
      expect(set.moons, hasLength(12));
      expect(set.overflow, 2);
      expect(set.moons.map((m) => m.refId), isNot(contains('w0')));
      expect(set.moons.first.refId, 'w2');
    });
  });

  group('extras', () {
    test('natural owners read their data', () {
      const data = ExtrasInputs(
        peopleCount: 10,
        boardCount: 11,
        cardsTouched7d: 6,
        savingsRatio: 0,
        growthFraction: 0.5,
        fastingNow: true,
        workoutsToday: 1,
        workoutsExpectedToday: 2,
        workoutMinutesToday: 45,
        upcomingTrips: 9,
      );
      expect(PlanetExtras.of(key: 'family', archetype: PlanetArchetype.terracotta, data: data), [2.0, 0, 0, 0]);
      final work = PlanetExtras.of(key: 'work', archetype: PlanetArchetype.industrial, data: data);
      expect(work[0], 8);
      expect(work[1], closeTo(0.3 + 0.7 * (1 - 0.36788), 1e-3));
      expect(PlanetExtras.of(key: 'money', archetype: PlanetArchetype.crystal, data: data), [0, 0.05, 0, 0]);
      expect(PlanetExtras.of(key: 'growth', archetype: PlanetArchetype.verdant, data: data), [0.5, 0, 0, 0]);
      expect(PlanetExtras.of(key: 'body', archetype: PlanetArchetype.volcanic, data: data), [1, 0.75, 0, 0]);
      expect(PlanetExtras.of(key: 'travel', archetype: PlanetArchetype.gasGiant, data: data), [6, 0, 0, 0]);
      expect(PlanetExtras.of(key: 'faith', archetype: PlanetArchetype.faith, data: data), [0, 0, 0, 0]);
    });

    test('without data or in a borrowed style: shader defaults', () {
      const empty = ExtrasInputs();
      expect(PlanetExtras.of(key: 'family', archetype: PlanetArchetype.terracotta, data: empty), [0, 0, 0, 0]);
      expect(PlanetExtras.of(key: 'work', archetype: PlanetArchetype.industrial, data: empty), [0, 0.6, 0, 0]);
      expect(PlanetExtras.of(key: 'money', archetype: PlanetArchetype.crystal, data: empty), [0, 0, 0, 0]);
      const busy = ExtrasInputs(boardCount: 4, upcomingTrips: 3);
      // The Work planet dressed as a gas giant does not borrow Travel's ships.
      expect(PlanetExtras.of(key: 'work', archetype: PlanetArchetype.gasGiant, data: busy), [0, 0, 0, 0]);
      expect(PlanetExtras.of(key: 'custom_x', archetype: PlanetArchetype.ice, data: busy), [1.55, 0.06, 0, 0]);
      expect(PlanetExtras.of(key: 'custom_x', archetype: PlanetArchetype.desert, data: busy), [0.5, 0, 0, 0]);
    });
  });

  group('archetypes', () {
    test('ice and desert reuse existing shaders; palettes', () {
      expect(OrbitArchetypes.shaderFor(PlanetArchetype.ice), PlanetArchetype.crystal);
      expect(OrbitArchetypes.shaderFor(PlanetArchetype.desert), PlanetArchetype.terracotta);
      expect(OrbitArchetypes.shaderFor(PlanetArchetype.volcanic), PlanetArchetype.volcanic);
      expect(OrbitArchetypes.forBuiltInKey('travel'), PlanetArchetype.gasGiant);
      expect(OrbitArchetypes.naturalKey(PlanetArchetype.ocean), 'health');
      expect(OrbitArchetypes.paletteFor('faith', PlanetPalettes.faith.surface.toARGB32()), same(PlanetPalettes.faith));
      expect(OrbitArchetypes.paletteFor('custom_a', 0xFF123456).surface.toARGB32(), 0xFF123456);
      for (final a in OrbitArchetypes.choices) {
        expect(OrbitArchetypes.defaultColor(a).a, 1.0);
      }
    });
  });

  group('activity fallback', () {
    const custom = ['custom_garden'];

    test('a planet with no data stays dormant until something is done for it', () {
      expect(engine.compute(ScoreInputs(now: now), planetKeys: custom)['custom_garden']!.dormant, isTrue);
      final fresh = engine.compute(
        ScoreInputs(now: now, lastActivity: {'custom_garden': now.subtract(const Duration(hours: 2))}),
        planetKeys: custom,
      )['custom_garden']!;
      expect(fresh.dormant, isFalse);
      expect(fresh.sources.keys, [ScoreSources.activity]);
      expect(fresh.state, PlanetState.thriving);
    });

    test('a quiet spell lets it fade, with a noActivity reason', () {
      final quiet = engine.compute(
        ScoreInputs(now: now, lastActivity: {'custom_garden': DateTime(2026, 9, 17, 9)}),
        planetKeys: custom,
      )['custom_garden']!;
      expect(quiet.sources[ScoreSources.activity], closeTo(0.25, 1e-9)); // 10 days, half-life 5
      expect(quiet.state, PlanetState.neglected);
      expect(quiet.reasons.single.code, ReasonCode.noActivity);
      expect(quiet.reasons.single.args, {'days': 10});
    });

    test('never replaces real data, and a weight of 0 switches it off', () {
      final scores = engine.compute(
        ScoreInputs(
          now: now,
          tasks: [TaskIn(id: 't', planetKey: 'custom_garden', done: false, date: DateTime(2026, 9, 20))],
          lastActivity: {'custom_garden': now, 'custom_off': now},
        ),
        planetKeys: const ['custom_garden', 'custom_off'],
        weights: const {
          'custom_off': {ScoreSources.activity: 0},
        },
      );
      expect(scores['custom_garden']!.sources.keys, [ScoreSources.tasks]);
      expect(scores['custom_off']!.dormant, isTrue);
      expect(ScoreSources.isKnown(ScoreSources.activity), isTrue);
      expect(ScoreSources.all, isNot(contains(ScoreSources.activity)));
    });
  });

  group('calendar days', () {
    test('documents count whole days to expiry (not 24-hour spans)', () {
      final scores = engine.compute(
        ScoreInputs(
          now: now,
          documents: [
            DocumentIn(id: 'p', name: 'Passport', expiry: DateTime(2026, 10, 7)),
            DocumentIn(id: 'v', name: 'Visa', expiry: DateTime(2026, 9, 27)),
            DocumentIn(id: 'l', name: 'Licence', expiry: DateTime(2026, 9, 26, 23)),
          ],
        ),
      );
      final byId = {for (final r in scores['travel']!.reasons) r.refId: r.args['days']};
      expect(byId, {'p': 10, 'v': 0, 'l': -1});
    });

    test('a trip dated today (stored at midnight) is still being packed for', () {
      final scores = engine.compute(
        ScoreInputs(
          now: now,
          trips: [
            TripIn(id: 'today', destination: 'Amman', startDate: DateTime(2026, 9, 27), itemsTotal: 10, itemsPacked: 3),
            TripIn(
              id: 'in5',
              destination: 'Istanbul',
              startDate: DateTime(2026, 10, 2),
              itemsTotal: 10,
              itemsPacked: 0,
            ),
            TripIn(id: 'gone', destination: 'Cairo', startDate: DateTime(2026, 9, 26), itemsTotal: 10, itemsPacked: 0),
          ],
        ),
      );
      final byId = {for (final r in scores['travel']!.reasons) r.refId: r.args['days']};
      expect(byId, {'today': 0, 'in5': 5});
      // Leaving today with 30 % packed → 0.3; in five days with nothing → 0.
      expect(scores['travel']!.sources['trips'], closeTo(0.15, 1e-9));
      expect(
        MoonRules.tripScore(
          TripMoonIn(
            id: 'today',
            destination: 'Amman',
            startDate: DateTime(2026, 9, 27),
            itemsTotal: 10,
            itemsPacked: 3,
          ),
          now,
        ),
        closeTo(0.2 + 0.8 * 0.3, 1e-9),
      );
      expect(
        MoonRules.tripScore(TripMoonIn(id: 'gone', destination: 'Cairo', startDate: DateTime(2026, 9, 26)), now),
        0.9,
      );
    });
  });

  group('moons under the cap', () {
    test('custom modules attached to a crowded planet are always kept', () {
      final palettes = {for (final e in PlanetPalettes.byKey.entries) e.key: e.value};
      final sets = MoonBuilder.build(
        MoonInputs(
          people: [
            for (var i = 0; i < 14; i++)
              PersonMoonIn(
                id: 'p$i',
                name: 'P$i',
                rhythmDays: 7,
                lastContact: now.subtract(Duration(days: 20 - i)),
                createdAt: DateTime(2026),
              ),
          ],
          modules: [
            ModuleMoonIn(
              id: 'm',
              name: 'Family log',
              color: 0xFFCC8855,
              planetKey: 'family',
              createdAt: now,
              lastEntry: now,
            ),
          ],
        ),
        now: now,
        palettes: palettes,
      );
      final family = sets['family']!;
      expect(family.moons, hasLength(12));
      expect(family.overflow, 3);
      expect(family.moons.last.refTable, 'custom_modules'); // modules orbit after the people
      // The dropped people are the freshest ones (the most overdue stay visible).
      expect(family.moons.map((m) => m.refId), isNot(anyOf(contains('p13'), contains('p12'), contains('p11'))));
    });
  });
}
