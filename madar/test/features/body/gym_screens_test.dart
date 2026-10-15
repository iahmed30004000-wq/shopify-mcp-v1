// The gym's screens inside the real app, in Arabic and in English
// (Part 8, «#24 – Body / gym»): the empty library, an exercise with the
// machine's picture and the movement's video, today's session walked set by
// set with the rest between them, the chart and the heaviest set, his next
// load being his own numbers and saying so, and his named training days.
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/interaction/interaction.dart';
import 'package:madar/features/body/body.dart';

import 'body_harness.dart';

final L10n ar = lookupL10n(const Locale('ar'));
final L10n en = lookupL10n(const Locale('en'));

Future<T> db<T>(WidgetTester tester, Future<T> Function() work) async => (await tester.runAsync(work)) as T;

Future<void> frames(WidgetTester tester, {int n = 12, Duration step = const Duration(milliseconds: 80)}) async {
  for (var i = 0; i < n; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    await tester.pump(step);
  }
}

/// Scrolls [finder] into view inside the page being tested (a tall page
/// builds lazily: a card below the fold is not in the tree yet).
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 220, scrollable: find.byType(Scrollable).first, duration: const Duration(milliseconds: 40));
  await frames(tester, n: 4);
}

/// Lets undo toasts count down and leave.
Future<void> expireToasts(WidgetTester tester) => frames(tester, n: 8, step: const Duration(seconds: 1));

class _Picker implements GymFilePicker {
  PickedGymFile? image;
  PickedGymFile? video;

  @override
  Future<PickedGymFile?> pickImage() async => image;

  @override
  Future<PickedGymFile?> pickVideo() async => video;
}

PickedGymFile _picked(String name, {String? path}) =>
    PickedGymFile(name: name, path: path, read: () async => Uint8List.fromList(List.filled(32, 3)));

/// Everything the gym's screens need overridden: its own folder, a scripted
/// picker, a recording video opener, a recording navigator, and a clock the
/// test can move (the rest between sets follows it, like every running
/// number on the planet).
class _GymFixture {
  _GymFixture() : dir = Directory.systemTemp.createTempSync('gym_screens') {
    media = GymMedia.at(dir, picker: picker);
  }

  final Directory dir;
  final _Picker picker = _Picker();
  final RecordingGymVideoOpener opener = RecordingGymVideoOpener();
  final List<String> hops = [];
  late final GymMedia media;
  DateTime now = bodyTestNow;

  List<Override> get overrides => [
    gymMediaProvider.overrideWithValue(media),
    gymVideoOpenerProvider.overrideWithValue(opener),
    gymNavigatorProvider.overrideWithValue((context, location) => hops.add(location)),
    bodyClockProvider.overrideWithValue(() => now),
  ];

  void dispose() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// The first exercise of his library, on its own page: the screen needs an
/// id, and the id is his database's.
/// Keeps the planet's streams alive while a test reads a provider off the
/// container (a provider nobody watches has not read the database yet).
class _Watching extends ConsumerWidget {
  const _Watching();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(bodyExercisesProvider);
    ref.watch(bodyWorkoutsProvider);
    ref.watch(bodyTemplatesProvider);
    ref.watch(bodyTrainingTodayProvider);
    return const SizedBox.shrink();
  }
}

class _FirstExercise extends ConsumerWidget {
  const _FirstExercise();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(bodyExercisesProvider).firstOrNull;
    return e == null ? const SizedBox.shrink() : GymExerciseScreen(exerciseId: e.id, animateBackdrop: false);
  }
}

/// His own library and history: one exercise with the machine, the
/// movement and three rising days — 40, then 45, then 47.5 kg.
Future<String> seedGym(
  MadarDatabase database, {
  required String name,
  bool rising = true,
  String? photo,
  String? video,
  List<int> weekdays = const [2],
}) async {
  final service = BodyService(Repositories(database), clock: () => bodyTestNow);
  final (row, _) = await service.addExercise(
    ExerciseDraft(
      name: name,
      weekdays: weekdays,
      sets: 3,
      reps: 10,
      weight: 50,
      restSec: 60,
      warmupSets: 1,
      muscles: const ['أرجل', 'ظهر'],
      photo: photo,
      video: video,
    ),
  );
  if (rising) {
    for (final (days, weight) in [(-14, 40.0), (-7, 45.0), (-2, 47.5)]) {
      await service.logWorkout(
        WorkoutDraft(exerciseId: row.id, name: row.name, at: bodyTestNow.add(Duration(days: days))),
        sets: [SetDraft(reps: 8, weight: weight - 10, warmup: true), SetDraft(reps: 10, weight: weight)],
      );
    }
  }
  return row.id;
}

void main() {
  group('the library', () {
    testWidgets('a fresh install has no exercise, and no gym to walk into', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      await pumpBodyApp(tester, home: const BodyScreen(initialTab: BodyTab.plan), overrides: fx.overrides);
      expect(find.text(ar.bodyPlanEmptyTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('body.plan.session')), findsNothing);
      expect(find.byKey(const ValueKey('body.plan.templates')), findsNothing);
      expect(find.byType(GymPhotoView), findsNothing);
    });

    testWidgets('with a library, the two ways in are there and a row opens the exercise', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      late String id;
      await pumpBodyApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.plan),
        overrides: fx.overrides,
        beforePump: (database) async => id = await seedGym(database, name: 'قرفصاء بالبار'),
      );
      expect(find.byKey(const ValueKey('body.plan.session')), findsOneWidget);
      expect(find.byKey(const ValueKey('body.plan.templates')), findsOneWidget);
      // His muscles are on the row, in his own words.
      expect(find.text('أرجل'), findsOneWidget);
      await tester.tap(find.text('قرفصاء بالبار'));
      await frames(tester);
      expect(fx.hops, ['/body/gym/exercise/$id']);
      await tester.tap(find.byKey(const ValueKey('body.plan.templates')));
      await frames(tester);
      expect(fx.hops.last, '/body/gym/days');
    });

    testWidgets("the add sheet copies the machine's picture in and remembers the video's place", (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      fx.picker.image = _picked('IMG_9001.jpg');
      final env = await pumpBodyApp(
        tester,
        home: const BodyScreen(initialTab: BodyTab.plan),
        overrides: fx.overrides,
      );
      await tester.tap(find.byKey(const ValueKey('body.fab')));
      await frames(tester);
      await tester.enterText(find.byKey(const ValueKey('body.exercise.name')), 'ضغط بنش');
      await tester.enterText(find.byKey(const ValueKey('body.exercise.muscles')), 'صدر، ترايسبس');
      await tester.enterText(find.byKey(const ValueKey('body.exercise.video')), 'https://example.com/bench');
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('body.exercise.photoPick')));
      await frames(tester);
      // The picture is already Madar's own, before anything is saved.
      expect(fx.dir.listSync().whereType<File>(), hasLength(1));
      await tester.tap(find.widgetWithText(SheetButton, ar.bodySave));
      await frames(tester);

      final row = (await db(tester, () => env.repos.exercises.getAll())).single;
      expect(row.name, 'ضغط بنش');
      expect(row.muscles, ['صدر', 'ترايسبس']);
      expect(row.video, 'https://example.com/bench');
      expect(row.photo, isNotNull);
      expect(row.photo!.contains('/'), isFalse, reason: 'a file name of ours, not a path into his gallery');
      final file = await db(tester, () => fx.media.photoFile(row.photo!));
      expect(file?.existsSync(), isTrue);
    });
  });

  group('one exercise, and his own numbers', () {
    for (final lang in ['ar', 'en']) {
      final l = lang == 'ar' ? ar : en;
      testWidgets('[$lang] the chart, the heaviest set, and a next load that says it is not advice', (tester) async {
        final fx = _GymFixture();
        addTearDown(fx.dispose);
        await pumpBodyApp(
          tester,
          locale: Locale(lang),
          home: const _FirstExercise(),
          overrides: fx.overrides,
          beforePump: (database) async => seedGym(database, name: lang == 'ar' ? 'قرفصاء' : 'Squat'),
        );
        await frames(tester);
        // The machine and his own words are at the top of the page.
        expect(find.byKey(const ValueKey('gym.exercise.media')), findsOneWidget);
        expect(find.byType(GymPhotoView), findsWidgets);

        // Down the page: the number for next time, where it came from, and
        // the health rule in the words on the screen.
        await scrollTo(tester, find.byKey(const ValueKey('gym.next')));
        expect(find.text(l.gymNotAdvice), findsOneWidget);
        expect(find.textContaining(l.gymYourStep('')), findsOneWidget);
        expect(find.textContaining(l.gymLastTimeValue('')), findsOneWidget);
        expect(find.byKey(const ValueKey('gym.next.use')), findsOneWidget);

        // Then the heaviest set he ever did, and the chart of his days.
        await scrollTo(tester, find.byKey(const ValueKey('gym.exercise.best')));
        expect(find.text(l.gymBestSet), findsWidgets);
        await scrollTo(tester, find.byType(ProgressLineChart));
        expect(find.byType(ProgressLineChart), findsOneWidget, reason: 'three days make a line');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('his step is read off his own days: 40 → 45 → 47.5 makes 50', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      final env = await pumpBodyApp(
        tester,
        home: const _Watching(),
        overrides: fx.overrides,
        beforePump: (database) async => seedGym(database, name: 'قرفصاء'),
      );
      await frames(tester);
      final row = (await db(tester, () => env.repos.exercises.getAll())).single;
      final load = env.container.read(bodyNextLoadProvider(row.id));
      expect(load.basis, LoadBasis.sameStep);
      expect(load.last, 47.5);
      expect(load.step, 2.5);
      expect(load.weight, 50);
      expect(load.reps, 10, reason: 'his last reps, never raised for him');
      expect(load.sessions, 3);
    });

    testWidgets('the video he pointed at is handed to the phone', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      await pumpBodyApp(
        tester,
        home: const _FirstExercise(),
        overrides: fx.overrides,
        beforePump: (database) async => seedGym(database, name: 'قرفصاء', video: 'https://example.com/squat'),
      );
      await frames(tester);
      expect(find.text('example.com'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gym.video.open')));
      await frames(tester);
      expect(fx.opener.opened.single.raw, 'https://example.com/squat');
      expect(fx.opener.opened.single.kind, GymVideoKind.link);
    });
  });

  group("today's session, set by set", () {
    testWidgets('three sets with a warm-up, the rest between them, and one log at the end', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      final env = await pumpBodyApp(
        tester,
        home: const GymSessionScreen(animateBackdrop: false),
        overrides: fx.overrides,
        beforePump: (database) async => seedGym(database, name: 'قرفصاء بالبار', rising: false),
      );
      await frames(tester);
      // Set 1 of 3 is the warm-up he asked for.
      expect(find.text(ar.gymWarmup), findsWidgets);
      expect(find.byKey(const ValueKey('gym.session.setDone')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('gym.session.setDone')));
      await frames(tester);
      // The rest between sets is running, counting down to the 60 s he set.
      expect(find.byKey(const ValueKey('gym.rest')), findsOneWidget);
      expect(find.text(ar.gymResting), findsOneWidget);
      fx.now = bodyTestNow.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      await frames(tester, n: 3);
      expect(find.text(ar.gymRestOver), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('gym.rest.done')));
      await frames(tester);
      expect(find.byKey(const ValueKey('gym.rest')), findsNothing);

      // Nothing is written until the exercise is finished.
      expect(await db(tester, () => env.repos.workoutLogs.count()), 0);
      await tester.tap(find.byKey(const ValueKey('gym.session.setDone')));
      await frames(tester);
      fx.now = bodyTestNow.add(const Duration(seconds: 120));
      await tester.tap(find.byKey(const ValueKey('gym.rest.done')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('gym.session.setDone')));
      await frames(tester);

      final logs = await db(tester, () => env.repos.workoutLogs.getAll());
      expect(logs, hasLength(1));
      expect(logs.single.name, 'قرفصاء بالبار');
      expect(logs.single.sets, 2, reason: 'two working sets; the warm-up is not work');
      expect(logs.single.weight, 50);
      final sets = await db(tester, () => env.repos.workoutSets.getAll());
      expect(sets, hasLength(3));
      expect(sets.first.warmup, isTrue);
      expect([for (final s in sets) s.reps], [10, 10, 10]);
      // And the session is over, with what he did on the face of it.
      expect(find.byKey(const ValueKey('gym.session.done')), findsOneWidget);
      expect(find.text(ar.gymSessionDoneTitle), findsOneWidget);
      await expireToasts(tester);
    });

    testWidgets('a rest he never set counts up instead of putting a number in his mouth', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      await pumpBodyApp(
        tester,
        home: const GymSessionScreen(animateBackdrop: false),
        overrides: fx.overrides,
        beforePump: (database) async {
          final service = BodyService(Repositories(database), clock: () => bodyTestNow);
          await service.addExercise(const ExerciseDraft(name: 'عقلة', weekdays: [2], sets: 2, reps: 8));
        },
      );
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('gym.session.setDone')));
      await frames(tester);
      expect(find.text(ar.gymRestCountingUp), findsOneWidget);
      expect(find.byKey(const ValueKey('gym.rest.add')), findsOneWidget);
      expect(find.text(ar.gymRestOver), findsNothing);
      await expireToasts(tester);
    });

    testWidgets('[en] a rest day sends him back to his plan, not to a workout of ours', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      await pumpBodyApp(
        tester,
        locale: const Locale('en'),
        home: const GymSessionScreen(animateBackdrop: false),
        overrides: fx.overrides,
        beforePump: (database) async => seedGym(database, name: 'Squat', rising: false, weekdays: const [5]),
      );
      await frames(tester);
      expect(find.text(en.gymSessionEmptyTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('gym.session.setDone')), findsNothing);
    });
  });

  group('his named training days', () {
    testWidgets('a fresh install has no named day', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      await pumpBodyApp(tester, home: const GymTemplatesScreen(animateBackdrop: false), overrides: fx.overrides);
      expect(find.text(ar.gymTemplatesEmptyTitle), findsOneWidget);
      expect(find.byType(WeekdayDots), findsNothing);
    });

    testWidgets('a day shows its name, its weekdays and his exercises in order', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      await pumpBodyApp(
        tester,
        home: const GymTemplatesScreen(animateBackdrop: false),
        overrides: fx.overrides,
        beforePump: (database) async {
          final service = BodyService(Repositories(database), clock: () => bodyTestNow);
          final id = await seedGym(database, name: 'قرفصاء بالبار');
          final (day, _) = await service.addTemplate(const TemplateDraft(name: 'يوم أرجل', weekdays: [1, 4]));
          await service.addTemplateItem(day.id, TemplateItemDraft(exerciseId: id));
        },
      );
      expect(find.text('يوم أرجل'), findsOneWidget);
      expect(find.text('قرفصاء بالبار'), findsOneWidget);
      expect(find.textContaining(ar.gymTemplateCount(1)), findsOneWidget);
      expect(find.byType(WeekdayDots), findsWidgets);
      expect(find.text(ar.gymTemplatesEmptyTitle), findsNothing);
    });

    testWidgets('removing an exercise from a day offers the undo, and his library keeps it', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      final env = await pumpBodyApp(
        tester,
        home: const GymTemplatesScreen(animateBackdrop: false),
        overrides: fx.overrides,
        beforePump: (database) async {
          final service = BodyService(Repositories(database), clock: () => bodyTestNow);
          final id = await seedGym(database, name: 'قرفصاء بالبار');
          final (day, _) = await service.addTemplate(const TemplateDraft(name: 'يوم أرجل', weekdays: [1]));
          await service.addTemplateItem(day.id, TemplateItemDraft(exerciseId: id));
        },
      );
      await frames(tester);
      final item = (await db(tester, () => env.repos.workoutTemplateItems.getAll())).single;
      await tester.tap(find.byKey(ValueKey('gym.template.item.remove.${item.id}')));
      await frames(tester);
      expect(await db(tester, () => env.repos.workoutTemplateItems.count()), 0);
      expect(find.text(ar.actionUndo), findsOneWidget, reason: 'every destructive step is undoable');
      expect(await db(tester, () => env.repos.exercises.count()), 1, reason: 'his exercise is not the day');
      await expireToasts(tester);
    });

    testWidgets('a template day decides what today asks for, in his order', (tester) async {
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      final env = await pumpBodyApp(
        tester,
        home: const _Watching(),
        overrides: fx.overrides,
        beforePump: (database) async {
          final service = BodyService(Repositories(database), clock: () => bodyTestNow);
          final (a, _) = await service.addExercise(const ExerciseDraft(name: 'أ', weekdays: [2]));
          final (b, _) = await service.addExercise(const ExerciseDraft(name: 'ب'));
          // Tuesday is «يوم صدر»: ب first, then أ – his order, not the library's.
          final (day, _) = await service.addTemplate(const TemplateDraft(name: 'يوم صدر', weekdays: [2]));
          await service.addTemplateItem(day.id, TemplateItemDraft(exerciseId: b.id, sets: 4, reps: 6, weight: 70));
          await service.addTemplateItem(day.id, TemplateItemDraft(exerciseId: a.id));
        },
      );
      await frames(tester);
      final today = env.container.read(bodyTrainingTodayProvider);
      expect([for (final i in today.items) i.exercise.name], ['ب', 'أ']);
      expect(today.items.first.exercise.sets, 4);
      expect(today.items.first.exercise.weight, 70);
    });
  });

  group('text scale 1.3', () {
    testWidgets('the session holds at the largest text he uses', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      await pumpBodyApp(
        tester,
        home: const GymSessionScreen(animateBackdrop: false),
        overrides: fx.overrides,
        beforePump: (database) async => seedGym(database, name: 'قرفصاء بالبار'),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('gym.session.setDone')), findsOneWidget);
    });

    testWidgets('and so does the exercise, with his picture, his chart and his numbers', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final fx = _GymFixture();
      addTearDown(fx.dispose);
      await pumpBodyApp(
        tester,
        home: const _FirstExercise(),
        overrides: fx.overrides,
        beforePump: (database) async => seedGym(database, name: 'قرفصاء بالبار'),
      );
      await frames(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(ar.gymNotAdvice), findsOneWidget);
    });
  });
}
