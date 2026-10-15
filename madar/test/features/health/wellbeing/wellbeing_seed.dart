// Example data for wellbeing tests and screenshots only (a fresh install
// starts empty). Deterministic: a seeded generator shapes 60 days so the
// local insights have something to observe.
import 'dart:math' as math;

import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/health/wellbeing/wellbeing.dart';

class WellbeingSeed {
  const WellbeingSeed({
    this.days = 60,
    this.checkIns = true,
    this.pain = true,
    this.habits = true,
    this.worries = true,
    this.worryWindow = true,
    this.lowMood = false,
    this.checkInToday = true,
  });

  static const full = WellbeingSeed();
  static const lowMoodWeek = WellbeingSeed(lowMood: true);
  static const empty = WellbeingSeed(
    checkIns: false,
    pain: false,
    habits: false,
    worries: false,
    worryWindow: false,
    checkInToday: false,
  );

  final int days;
  final bool checkIns;
  final bool pain;
  final bool habits;
  final bool worries;
  final bool worryWindow;
  final bool lowMood;
  final bool checkInToday;
}

Future<void> seedWellbeing(MadarDatabase db, WellbeingSeed seed, {required DateTime now}) async {
  final repos = Repositories(db);
  final service = WellbeingService(repos, clock: () => now);
  final rnd = math.Random(7);
  final today = WbDays.dateOf(now);
  Future<List<String>> labels(TagKind k) async => [
    for (final t in await repos.tagOptions.getAll(where: (t) => t.kind.equalsValue(k))) t.label,
  ];
  final locations = await labels(TagKind.painLocation);
  final triggers = await labels(TagKind.painTrigger);
  final factors = await labels(TagKind.moodFactor);

  // Day "profiles": short sleep → more stress and pain.
  final stressByDay = <int, int>{};
  if (seed.checkIns) {
    for (var ago = seed.days - 1; ago >= 0; ago--) {
      if (ago == 0 && !seed.checkInToday) continue;
      final skip = rnd.nextDouble() < 0.18;
      if (skip && ago > 0 && !(seed.lowMood && ago < 6)) continue; // a few missed days
      final wave = math.sin(ago / 4.0);
      final shortSleep = rnd.nextDouble() < 0.2 + 0.3 * (wave + 1) / 2;
      final sleep = shortSleep ? 4.5 + rnd.nextInt(3) * 0.5 : 6.5 + rnd.nextInt(4) * 0.5;
      final cups = shortSleep ? 2 + rnd.nextInt(3) : rnd.nextInt(3);
      final stress = ((shortSleep ? 6 : 3.5) + 1.2 * wave + rnd.nextDouble() * 2).round().clamp(0, 10);
      final anxiety = (stress - 1 + rnd.nextInt(3)).clamp(0, 10);
      final energy = (shortSleep ? 3 : 6) + rnd.nextInt(3);
      var mood = (3.3 - 1.1 * wave + (shortSleep ? -0.8 : 0.4) + (rnd.nextDouble() - 0.5) * 0.8).round();
      if (seed.lowMood && ago < 6) mood = const [1, 2, 3, 2, 4, 2][ago];
      if (!seed.lowMood && ago < 6 && mood < 3) mood = 3;
      stressByDay[ago] = stress;
      final day = WbDays.add(today, -ago);
      final at = ago == 0
          ? DateTime(day.year, day.month, day.day, 9, 40)
          : DateTime(day.year, day.month, day.day, 21, 5);
      await service.logMood(
        MoodDraft(
          at: at,
          mood: mood.clamp(1, 5),
          stress: stress,
          anxiety: anxiety,
          energy: energy,
          sleepHours: sleep,
          caffeineCups: cups,
          factors: [
            if (factors.isNotEmpty && shortSleep) factors[0],
            if (factors.length > 3 && rnd.nextBool()) factors[3],
            if (factors.length > 1 && rnd.nextDouble() < 0.3) factors[1],
          ],
        ),
      );
    }
  }

  if (seed.pain) {
    const neck = BodyPoint(0.5, 0.142, BodySide.back);
    const lowBack = BodyPoint(0.5, 0.42, BodySide.back);
    const knee = BodyPoint(0.4, 0.71, BodySide.front);
    const head = BodyPoint(0.46, 0.06, BodySide.front);
    for (var ago = seed.days - 1; ago >= 0; ago--) {
      if (rnd.nextDouble() < 0.45) continue;
      final stress = stressByDay[ago] ?? 4;
      final score = (stress - 2 + rnd.nextInt(3)).clamp(1, 9);
      final day = WbDays.add(today, -ago);
      final spot = [neck, lowBack, knee, head][rnd.nextInt(4)];
      final jitter = BodyPoint(
        (spot.x + (rnd.nextDouble() - 0.5) * 0.04).clamp(0.0, 1.0),
        (spot.y + (rnd.nextDouble() - 0.5) * 0.02).clamp(0.0, 1.0),
        spot.side,
      );
      String? loc(BodyPoint p) {
        final r = BodyFigure.regionAt(p.x, p.y, p.side);
        final i = switch (r) {
          BodyRegion.neck => 1,
          BodyRegion.lowerBack => 4,
          BodyRegion.knees => 10,
          BodyRegion.head => 0,
          _ => null,
        };
        return i == null || i >= locations.length ? null : locations[i];
      }

      await service.logPain(
        PainDraft(
          at: DateTime(day.year, day.month, day.day, 13 + rnd.nextInt(6), 10),
          score: score,
          locations: [?loc(jitter)],
          triggers: [
            if (triggers.length > 2 && rnd.nextDouble() < 0.6) triggers[2],
            if (triggers.length > 1 && stress > 6) triggers[1],
            if (triggers.isNotEmpty && rnd.nextDouble() < 0.3) triggers[0],
          ],
          points: [jitter],
        ),
      );
    }
  }

  if (seed.habits) {
    final habits = await service.watchHabits().first;
    for (var i = 0; i < habits.length; i++) {
      final streak = [6, 3, 12, 0, 2, 9, 1, 0, 4, 0, 5][i % 11];
      for (var d = 1; d <= streak; d++) {
        await repos.habitLogs.insert(
          HabitLogsCompanion.insert(habitId: habits[i].id, day: WbDays.key(WbDays.add(today, -d))),
        );
      }
      if (i.isEven && i < 6) {
        await repos.habitLogs.insert(HabitLogsCompanion.insert(habitId: habits[i].id, day: WbDays.key(today)));
      }
    }
  }

  if (seed.worries) {
    final ar = locations.isNotEmpty && RegExp(r'[؀-ۿ]').hasMatch(locations.first);
    final parked = ar
        ? ['موعد نتيجة الفحص يوم الخميس', 'هل أنهي تقرير العمل قبل نهاية الأسبوع؟', 'مصاريف المدرسة الشهر القادم']
        : [
            'The test result appointment on Thursday',
            'Will I finish the work report by the weekend?',
            "Next month's school fees",
          ];
    for (var i = 0; i < parked.length; i++) {
      final w = await service.parkWorry(parked[i]);
      await repos.worries.setColumns(w!.id, {'createdAt': now.subtract(Duration(hours: 5 + 26 * i))});
    }
    final resolved = ar ? 'تأخر الرد على الرسالة' : 'The late reply to my message';
    final w = await service.parkWorry(resolved);
    await service.resolveWorry(
      w!.id,
      reflection: ar ? 'كان مشغولًا فقط، وردّ في المساء.' : 'He was just busy; replied in the evening.',
    );
    await repos.worries.setColumns(w.id, {'createdAt': now.subtract(const Duration(days: 3))});
  }

  if (seed.worryWindow) {
    await service.updateSettings(
      (s) => s.copyWith(worry: const WorryWindowSettings(enabled: true, minuteOfDay: 20 * 60, durationMinutes: 20)),
    );
  }
}
