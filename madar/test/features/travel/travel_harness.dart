// Test harness for the travel screens: the real theme, localisations, digit
// and motion scopes and the celebration overlay (like AppFrame), over an
// in-memory database, a silent sound engine, recording haptics, a frozen
// clock, the offline city list read from disk and a fake notification
// platform. Self-contained (does not build the whole app), so it keeps
// working while other packages change the router.
import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/notifications/fake_notification_platform.dart';
import 'package:madar/core/notifications/notification_providers.dart';
import 'package:madar/core/notifications/notification_service.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/application/prayer_providers.dart';
import 'package:madar/features/prayer/application/prayer_settings_controller.dart';
import 'package:madar/features/prayer/domain/cities.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/travel/data/travel_service.dart';
import 'package:madar/features/travel/domain/packing.dart';
import 'package:madar/features/travel/domain/starter_templates.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tuesday 29 Sep 2026, 13:10.
final DateTime travelTestNow = DateTime(2026, 9, 29, 13, 10);

/// Records haptics fired through [Fx].
class TravelHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

CityDatabase? _cities;

/// The bundled offline city list, read from disk once.
CityDatabase travelTestCities() {
  MadarTimeZones.ensure();
  return _cities ??= CityDatabase.parse(File('assets/geo/cities.json').readAsStringSync());
}

/// An in-memory database whose streams close synchronously (no pending
/// timers after a widget test).
MadarDatabase travelTestDatabase() =>
    MadarDatabase(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));

/// A user in Amman with the Jordanian preset (the app's defaults).
const PrayerSettings travelTestPrayerSettings = PrayerSettings(timeZone: 'Asia/Amman');

class _FixedPrayerSettings extends PrayerSettingsController {
  _FixedPrayerSettings(this.value);
  final PrayerSettings value;
  @override
  PrayerSettings build() => value;
}

class TravelTestEnv {
  TravelTestEnv(this.db, this.haptics, this.sound);

  final MadarDatabase db;
  final TravelHaptics haptics;
  final SilentSoundService sound;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();
  late ProviderContainer container;

  Repositories get repos => Repositories(db);
}

Future<(Widget, TravelTestEnv)> buildTravelApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  PrayerSettings prayerSettings = travelTestPrayerSettings,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = travelTestDatabase();
  await tester.runAsync(() => db.customSelect('SELECT 1').get());
  addTearDown(() => tester.runAsync(db.close));
  if (beforePump != null) await tester.runAsync(() => beforePump(db));
  final sound = SilentSoundService();
  final haptics = TravelHaptics();
  Fx.install(FeedbackService(sound, haptics));
  final clock = now ?? travelTestNow;
  final env = TravelTestEnv(db, haptics, sound);
  final cities = travelTestCities();
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
        final s = NotificationService(env.notifications, clock: () => clock);
        ref.onDispose(s.dispose);
        return s;
      }),
      cityDatabaseProvider.overrideWith((ref) async => cities),
      prayerSettingsControllerProvider.overrideWith(() => _FixedPrayerSettings(prayerSettings)),
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

Future<TravelTestEnv> pumpTravelApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  List<Override> overrides = const [],
  Future<void> Function(MadarDatabase db)? beforePump,
}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final (app, env) = await buildTravelApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    reducedMotion: reducedMotion,
    overrides: overrides,
    beforePump: beforePump,
  );
  await tester.pumpWidget(app);
  await settleTravel(tester);
  return env;
}

/// Lets database work (microtasks, stream hops) and finite animations finish.
Future<void> settleTravel(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(seconds: 1));
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
}

// ------------------------------------------------------------- scenario ----

/// Ids of the seeded scenario.
class TravelScenario {
  late String istanbul, umrah, cairo, doha, passport, visa, licence, essentials, business;
}

/// A realistic travel picture on 29 Sep 2026 (generic sample data, test
/// only): a business trip to Istanbul in 9 days, half packed; an Umrah trip
/// in December; a trip to Cairo under way; a past trip to Doha; a passport
/// expiring during the Umrah trip, a Turkish e-visa running out soon, a
/// licence fine; two packing templates.
Future<TravelScenario> seedTravelScenario(MadarDatabase db, {String lang = 'ar'}) async {
  final ar = lang == 'ar';
  final s = TravelScenario();
  final cities = travelTestCities();
  final service = TravelService(Repositories(db), clock: () => travelTestNow);
  City c(String id) => cities.byId(id)!;

  Future<String> trip(City city, DateTime start, DateTime end, {int? color, String? notes}) async => (await service
          .addTrip(
            TripDraft(
              destination: city.name(lang),
              country: city.countryCode,
              latitude: city.latitude,
              longitude: city.longitude,
              startDate: start,
              endDate: end,
              color: color,
              notes: notes,
            ),
          ))
      .id;

  s.istanbul = await trip(
    c('tr-istanbul'),
    DateTime(2026, 10, 8),
    DateTime(2026, 10, 14),
    color: 0xFF7FB2E5,
    notes: ar ? 'الفندق قرب السلطان أحمد — تأكيد الحجز في البريد' : 'Hotel near Sultanahmet — booking in the mail',
  );
  s.umrah = await trip(c('sa-makkah'), DateTime(2026, 12, 20), DateTime(2026, 12, 28), color: 0xFFE8C872);
  s.cairo = await trip(c('eg-cairo'), DateTime(2026, 9, 27), DateTime(2026, 10, 2), color: 0xFFE59A7F);
  s.doha = await trip(c('qa-doha'), DateTime(2026, 8, 3), DateTime(2026, 8, 6));

  final items = <(String, String, bool)>[
    (ar ? 'جواز السفر' : 'Passport', PackingCategories.documents, true),
    (ar ? 'التذاكر والحجوزات' : 'Tickets & bookings', PackingCategories.documents, true),
    (ar ? 'نقود بالليرة التركية' : 'Turkish lira', PackingCategories.documents, false),
    (ar ? 'قمصان رسمية' : 'Formal shirts', PackingCategories.clothes, true),
    (ar ? 'معطف خفيف' : 'Light jacket', PackingCategories.clothes, false),
    (ar ? 'الحاسوب وشاحنه' : 'Laptop & charger', PackingCategories.electronics, true),
    (ar ? 'محوّل كهرباء' : 'Plug adapter', PackingCategories.electronics, false),
    (ar ? 'سجادة صلاة للسفر' : 'Travel prayer mat', PackingCategories.prayer, true),
  ];
  for (final (body, cat, packed) in items) {
    final row = await service.addItem(s.istanbul, body, category: cat);
    if (packed) await Repositories(db).tripItems.setColumn(row.id, 'packed', true);
  }
  for (final body in ar ? ['جواز السفر', 'ملابس', 'شاحن'] : ['Passport', 'Clothes', 'Charger']) {
    final row = await service.addItem(s.cairo, body);
    await Repositories(db).tripItems.setColumn(row.id, 'packed', true);
  }

  s.passport = (await service.addDocument(
    DocumentDraft(
      name: ar ? 'جواز السفر' : 'Passport',
      holder: ar ? 'أنا' : 'Me',
      number: 'N0123456',
      expiry: DateTime(2026, 12, 24),
      remindDaysBefore: 180,
    ),
  )).id;
  s.visa = (await service.addDocument(
    DocumentDraft(
      name: ar ? 'تأشيرة تركيا الإلكترونية' : 'Turkey e-visa',
      expiry: DateTime(2026, 10, 20),
      remindDaysBefore: 14,
    ),
  )).id;
  s.licence = (await service.addDocument(
    DocumentDraft(name: ar ? 'رخصة القيادة' : 'Driving licence', number: '9981-554', expiry: DateTime(2029, 5, 3)),
  )).id;
  await service.addDocument(DocumentDraft(name: ar ? 'تأمين السفر' : 'Travel insurance', remindDaysBefore: 7));

  await service.addTemplates(starterTemplates(lookupL10n(Locale(lang))));
  final templates = await Repositories(db).packingTemplates.getAll();
  s.essentials = templates[0].id;
  s.business = templates[1].id;
  // A trip with a manual status (to exercise the badge): none by default.
  await Repositories(db).trips.setColumn(s.doha, 'status', TripStatus.done);
  return s;
}
