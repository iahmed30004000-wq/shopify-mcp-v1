// Builds Custom Modules screens for widget and screenshot tests: an
// in-memory database (planets seeded like a fresh install), a fixed clock,
// silent recording sound + haptics and fake notifications.
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_providers.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/custom_modules/custom_modules.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Wednesday 30 September 2026, 13:10.
final DateTime customTestNow = DateTime(2026, 9, 30, 13, 10);

class CustomTestEnv {
  CustomTestEnv(this.db, this.sound, this.haptics);

  final MadarDatabase db;
  final SilentSoundService sound;
  final RecordingHaptics haptics;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
  CustomModulesService get service => CustomModulesService(repos, clock: () => customTestNow);
}

Future<(Widget, CustomTestEnv)> buildCustomApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({
    'madar.settings.v1': jsonEncode(AppSettings(languageCode: locale.languageCode, onboarded: true).toJson()),
  });
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode, seed: true);
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final clock = now ?? customTestNow;
  final env = CustomTestEnv(db, sound, haptics);
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      notificationPlatformProvider.overrideWithValue(env.notifications),
      notificationServiceProvider.overrideWith((ref) {
        final service = NotificationService(env.notifications, clock: () => clock);
        ref.onDispose(service.dispose);
        return service;
      }),
      ...overrides,
    ],
    child: Consumer(
      builder: (context, ref, _) {
        env.container = ProviderScope.containerOf(context);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildMadarTheme(theme, arabic: arabic),
          locale: locale,
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          builder: (context, child) => MadarFormatScope(
            digits: DigitStyle.auto,
            child: MotionScope(
              reduced: reducedMotion,
              child: CelebrationOverlay(child: child!),
            ),
          ),
          home: home,
        );
      },
    ),
  );
  return (app, env);
}

/// [buildCustomApp] + pump on a phone-sized surface.
Future<CustomTestEnv> pumpCustomApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = true,
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  usePhoneSurface(tester);
  final (app, env) = await buildCustomApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    reducedMotion: reducedMotion,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleCustom(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleCustom(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------- seed --

/// Generic sample modules (template names in [languageCode]) with a month
/// of entries ending at [customTestNow]. Returns module ids by template.
Future<Map<ModuleTemplateKey, String>> seedCustom(MadarDatabase db, {String languageCode = 'ar'}) async {
  final repos = Repositories(db);
  final service = CustomModulesService(repos, clock: () => customTestNow);
  final tx = CustomTexts.forLanguage(languageCode);
  final ids = <ModuleTemplateKey, String>{};
  Future<String> create(ModuleTemplateKey k, {ModuleDefinition Function(ModuleDefinition)? edit}) async {
    var d = ModuleTemplates.build(k, tx.template);
    if (edit != null) d = edit(d);
    final m = await service.createModule(d);
    ids[k] = m.id;
    return m.id;
  }

  DateTime day(int back, int hour, [int minute = 0]) =>
      DateTime(customTestNow.year, customTestNow.month, customTestNow.day - back, hour, minute);

  // A habit ticked most days: a live streak of 6 (today included).
  final habit = await create(ModuleTemplateKey.dailyHabit);
  for (final b in [0, 1, 2, 3, 4, 5, 8, 9, 10, 11, 12, 13, 14, 15, 16, 20, 21, 23, 24, 25, 27]) {
    await service.addEntry(habit, {'f1': true}, at: day(b, 6, 30));
  }

  // Reading after Fajr: pages most days.
  final books = languageCode == 'ar' ? ['كتاب في السيرة', 'رواية قصيرة'] : ['A biography', 'A short novel'];
  final reading = await create(ModuleTemplateKey.readingLog);
  const pages = [12, 18, 0, 25, 9, 30, 14, 0, 22, 16, 11, 0, 27, 19, 8, 15, 0, 21, 13, 17, 24, 0, 10, 20, 26];
  for (var b = 0; b < pages.length; b++) {
    if (pages[b] == 0) continue;
    await service.addEntry(reading, {
      'f1': books[b < 12 ? 0 : 1],
      'f2': pages[b],
      if (b % 4 == 1) 'f3': 4 + (b % 2),
    }, at: day(b, 5, 20 + b % 30));
  }

  // Dhikr counts after prayers.
  final dhikr = await create(ModuleTemplateKey.dhikrCounter);
  for (var b = 0; b < 12; b++) {
    await service.addEntry(dhikr, {'f1': 'o${1 + b % 5}', 'f2': 33 + (b * 7) % 67}, at: day(b, 13 - b % 3, 5));
  }

  // Sleep hours.
  final sleep = await create(ModuleTemplateKey.sleepLog);
  const hours = [7.5, 6.0, 6.5, 8.0, 7.0, 5.5, 7.5, 6.5, 7.0, 8.5, 6.0, 7.0, 7.5, 6.5];
  for (var b = 0; b < hours.length; b++) {
    await service.addEntry(sleep, {'f1': '23:${(b * 5 % 60).toString().padLeft(2, '0')}', 'f2': '06:30', 'f3': hours[b], 'f4': 3 + b % 3}, at: day(b, 7));
  }

  // A list with one item done.
  final gifts = await create(ModuleTemplateKey.giftIdeas);
  final items = languageCode == 'ar'
      ? [('كتاب مصوّر', 'الأطفال', 12000), ('وشاح شتوي', null, 18500), ('نبتة صغيرة', 'زملاء المكتب', 7000), ('ألبوم صور', null, null)]
      : [('A picture book', 'The kids', 12000), ('A winter scarf', null, 18500), ('A small plant', 'The office', 7000), ('A photo album', null, null)];
  for (final (idea, whom, budget) in items) {
    await service.addEntry(gifts, {
      'f1': idea,
      'f2': ?whom,
      if (budget != null) 'f3': {'milli': budget, 'currency': 'JOD'},
    });
  }
  final first = (await repos.customEntries.getAll(where: (t) => t.moduleId.equals(gifts))).last;
  await service.setDone(first.id, true);

  // Reminders: after Fajr on the reading log, a paused one on the habit.
  await service.addReminder(reading, {'kind': 'prayer', 'window': 'fajr', 'offsetMin': 15});
  await repos.reminders.insert(
    RemindersCompanion.insert(
      ownerTable: CustomModulesService.ownerTable,
      ownerId: habit,
      rule: const {'kind': 'daily', 'time': '06:15'},
      enabled: const Value(false),
    ),
  );
  return ids;
}
