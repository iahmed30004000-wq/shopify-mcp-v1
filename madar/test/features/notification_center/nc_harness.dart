// Builds the notification center for widget and screenshot tests: a seeded
// in-memory database, a pinned clock, silent recording sound + haptics, the
// fake notifications plugin behind the center's gate, and recording action
// handlers (so a test sees exactly which feature action a button asked for).
import 'dart:convert';

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
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/adhan/domain/adhan_event.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/family/domain/family_reminders.dart';
import 'package:madar/features/health/meds/data/meds_notifications.dart';
import 'package:madar/features/home/home_providers.dart';
import 'package:madar/features/notification_center/notification_center.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import 'nc_fixtures.dart';

class NcEnv {
  NcEnv(this.db, this.sound, this.haptics);

  final MadarDatabase db;
  final SilentSoundService sound;
  final RecordingHaptics haptics;
  final FakeNotificationPlatform notifications = FakeNotificationPlatform();

  /// Every inline action the center asked a feature to perform.
  final List<CenterActionRequest> actions = [];

  /// Settings links opened (group names).
  final List<String> opened = [];
  late ProviderContainer container;

  NotificationCenterStore get store => NotificationCenterStore(Repositories(db).keyValues);

  /// Schedules [r] on the fake plugin as the notification service would.
  Future<void> schedule(NotificationRequest r) =>
      notifications.schedule(r, NotificationEnvelope.encode(r), timing: r.timing);

  /// Shows [r] (it is in the tray).
  Future<void> show(NotificationRequest r) => notifications.show(r, NotificationEnvelope.encode(r));
}

/// A copy of [r] with other texts (English fixtures).
NotificationRequest retitled(NotificationRequest r, String title, [String? body]) => NotificationRequest(
  namespace: r.namespace,
  id: r.id,
  channelId: r.channelId,
  title: title,
  body: body ?? r.body,
  at: r.at,
  data: r.data,
  category: r.category,
  timing: r.timing,
  actions: r.actions,
  dropIfLateBy: r.dropIfLateBy,
  timeout: r.timeout,
);

Future<(Widget, NcEnv)> buildNcApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  bool reducedMotion = false,
  NotificationCenterLinks? links,
  Map<NotificationGroup, GroupReminderSettings>? groupSettings,
  List<Override> overrides = const [],
  Future<void> Function(NcEnv env)? seed,
}) async {
  SharedPreferences.setMockInitialValues({
    'madar.settings.v1': jsonEncode(AppSettings(languageCode: locale.languageCode, onboarded: true).toJson()),
  });
  final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
  final db = await openTestDatabase(tester, languageCode: locale.languageCode, seed: true);
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  final env = NcEnv(db, sound, haptics);
  if (seed != null) await tester.runAsync(() => seed(env));
  Fx.install(FeedbackService(sound, haptics));
  final clock = now ?? ncNow;
  Future<bool> record(CenterActionRequest r) async {
    env.actions.add(r);
    return true;
  }

  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      databaseProvider.overrideWithValue(db),
      homeClockProvider.overrideWithValue(() => clock),
      notificationCenterClockProvider.overrideWithValue(() => clock),
      notificationPlatformProvider.overrideWith((ref) => gatedNotificationPlatform(ref, env.notifications)),
      notificationServiceProvider.overrideWith((ref) {
        final service = NotificationService(ref.watch(notificationPlatformProvider), clock: () => clock);
        ref.onDispose(service.dispose);
        return service;
      }),
      notificationActionHandlersProvider.overrideWithValue(
        NotificationActionHandlers({
          MedsNotificationTaps.actionTaken: record,
          MedsNotificationTaps.actionSnooze: record,
          MedsNotificationTaps.actionSkip: record,
          AdhanActions.stop: record,
        }),
      ),
      notificationCenterLinksProvider.overrideWithValue(
        links ??
            NotificationCenterLinks(
              open: (context, tap) => true,
              settings: {
                for (final g in NotificationGroup.values)
                  if (g != NotificationGroup.other) g: (context, group, notice) => env.opened.add(group.name),
              },
            ),
      ),
      if (groupSettings != null) notificationGroupSettingsProvider.overrideWithValue(groupSettings),
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

/// [buildNcApp] + pump on a phone-sized surface, settled.
Future<NcEnv> pumpNcApp(
  WidgetTester tester, {
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  DateTime? now,
  NotificationCenterLinks? links,
  Map<NotificationGroup, GroupReminderSettings>? groupSettings,
  Future<void> Function(NcEnv env)? seed,
  bool tall = false,
}) async {
  usePhoneSurface(tester);
  // Tall: every section is built at once (the lists build lazily).
  if (tall) tester.view.physicalSize = const Size(412, 2600) * 2;
  final (app, env) = await buildNcApp(
    tester,
    home: home,
    theme: theme,
    locale: locale,
    now: now,
    reducedMotion: true,
    links: links,
    groupSettings: groupSettings,
    seed: seed,
  );
  await tester.pumpWidget(app);
  await settleNc(tester);
  return env;
}

/// Lets database work and the center's refreshes finish, then settles.
Future<void> settleNc(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pumpAndSettle();
}

/// Switches to both tabs' worth of content: a realistic Wednesday
/// afternoon – a week of prayer, adhkar, doses, appointments, dues, family,
/// travel, wird and module reminders ahead; a dose waiting in the tray; a
/// morning's worth of notifications behind (one answered, one opened); the
/// Family group muted until tomorrow morning.
Future<void> seedWeek(NcEnv env, {String lang = 'ar'}) async {
  final en = lang == 'en';
  NotificationRequest t(NotificationRequest r, String arTitle, String enTitle, [String? arBody, String? enBody]) =>
      retitled(r, en ? enTitle : arTitle, en ? enBody : arBody);

  final upcoming = [
    adhanCall(AdhanSlot.asr, ncAt(0, 15, 42)),
    adhanPre(AdhanSlot.maghrib, ncAt(0, 18, 8), 10),
    adhanCall(AdhanSlot.maghrib, ncAt(0, 18, 8)),
    adhanCall(AdhanSlot.isha, ncAt(0, 19, 31)),
    adhanCall(AdhanSlot.fajr, ncAt(1, 4, 32)),
    adhanCall(AdhanSlot.dhuhr, ncAt(1, 11, 36)),
    t(
      adhkar(AdhkarCategoryId.evening, ncAt(0, 16, 5)),
      'أذكار المساء',
      'Evening adhkar',
      'حصّن مساءك بذكر الله',
      'Guard your evening with remembrance',
    ),
    t(
      adhkar(AdhkarCategoryId.morning, ncAt(1, 4, 55)),
      'أذكار الصباح',
      'Morning adhkar',
      'ابدأ يومك بذكر الله',
      'Begin your day with remembrance',
    ),
    t(medsDose(ncAt(0, 20)), 'حان موعد Levo', 'Time for Levo', '١٠ مغ · مع العشاء', '10 mg · with dinner'),
    t(
      medsDose(ncAt(1, 8), id: 120077),
      'حان موعد Levo',
      'Time for Levo',
      '١٠ مغ · مع الفطور',
      '10 mg · with breakfast',
    ),
    t(
      appointment(ncAt(1, 9, 30)),
      'موعد د. سلمى',
      'Dr. Salma',
      'غدًا ١١:٣٠ ص · عيادة القلب',
      'Tomorrow 11:30 AM · Cardiology',
    ),
    t(
      worry(ncAt(0, 18, 30)),
      'نافذة القلق',
      'Worry window',
      'ربع ساعة لما يشغلك',
      'Fifteen minutes for what weighs on you',
    ),
    t(
      moneyDue(ncAt(2, 9)),
      'دَين لسامر',
      'Debt to Samer',
      'يستحق ٥٠ دينارًا بعد غد',
      '50 JOD due the day after tomorrow',
    ),
    t(
      family(ncAt(0, 18), FamilyNoticeKind.digest),
      'حان وقت السؤال عن ٣ أحبّة',
      'Time to check on 3 loved ones',
      'أمي، خالد، ريم',
      'Mum, Khaled, Reem',
    ),
    t(
      travelDoc(ncAt(4, 10)),
      'جواز السفر ينتهي بعد ٣٠ يومًا',
      'Passport expires in 30 days',
      'جدّده قبل رحلة إسطنبول',
      'Renew it before the Istanbul trip',
    ),
    t(wird(ncAt(0, 16, 10)), 'وِرد اليوم', "Today's wird", 'صفحتان من سورة البقرة', 'Two pages of al-Baqarah'),
    t(moduleReminder(ncAt(0, 21)), 'سجّل قراءة الضغط', 'Log your blood pressure', 'قياس المساء', 'Evening reading'),
  ];
  for (final r in upcoming) {
    await env.schedule(r);
  }
  // In the tray now: the 13:00 dose, with Taken / Snooze / Skip.
  await env.show(
    t(
      medsDose(ncAt(0, 13), id: 120011),
      'حان موعد فيتامين د',
      'Time for Vitamin D',
      '١٠٠٠ وحدة · مع الغداء',
      '1000 IU · with lunch',
    ),
  );
  // Earlier today.
  final store = env.store;
  final seenAt = ncAt(0, 9);
  final history = NotificationHistory.empty.recordAll([
    HistoryEntry(
      notice: CenterNotice.fromRequest(
        t(
          adhkar(AdhkarCategoryId.morning, ncAt(0, 4, 55)),
          'أذكار الصباح',
          'Morning adhkar',
          'ابدأ يومك بذكر الله',
          'Begin your day with remembrance',
        ),
      ),
      status: HistoryStatus.opened,
      recordedAt: ncAt(0, 5, 2),
    ),
    HistoryEntry(
      notice: CenterNotice.fromRequest(
        t(
          medsDose(ncAt(0, 8), id: 120033),
          'حان موعد Levo',
          'Time for Levo',
          '١٠ مغ · مع الفطور',
          '10 mg · with breakfast',
        ),
      ),
      status: HistoryStatus.acted,
      actionId: MedsNotificationTaps.actionTaken,
      recordedAt: ncAt(0, 8, 4),
    ),
    HistoryEntry(
      notice: CenterNotice.fromRequest(
        t(
          family(ncAt(0, 9, 30), FamilyNoticeKind.birthday),
          'عيد ميلاد مريم اليوم',
          "It's Maryam's birthday",
          'تتمّ ٣٠ عامًا',
          'She turns 30',
        ),
      ),
      status: HistoryStatus.delivered,
      recordedAt: ncAt(0, 9, 30),
    ),
    HistoryEntry(
      notice: CenterNotice.fromRequest(
        t(
          travelDoc(ncAt(0, 10), onDay: true),
          'تنتهي الإقامة اليوم',
          'Residence permit expires today',
          'آخر يوم للتجديد',
          'Last day to renew',
        ),
      ),
      status: HistoryStatus.delivered,
      recordedAt: ncAt(0, 10),
    ),
    HistoryEntry(
      notice: CenterNotice.fromRequest(adhanCall(AdhanSlot.dhuhr, ncAt(0, 11, 36))),
      status: HistoryStatus.delivered,
      recordedAt: ncAt(0, 11, 36),
    ),
  ], now: ncNow);
  await store.saveHistory(history);
  await store.saveSeenAt(seenAt);
  await store.savePolicy(CenterPolicy.empty.mute(NotificationGroup.family, ncAt(1, 7)));
}

/// Every group's switches as a fresh-ish install would have them.
const Map<NotificationGroup, GroupReminderSettings> ncGroupSettings = {
  NotificationGroup.prayer: GroupReminderSettings(group: NotificationGroup.prayer, on: 5, total: 6),
  NotificationGroup.adhkar: GroupReminderSettings(group: NotificationGroup.adhkar, on: 2, total: 2),
  NotificationGroup.medications: GroupReminderSettings(group: NotificationGroup.medications, on: 1, total: 1),
  NotificationGroup.health: GroupReminderSettings(group: NotificationGroup.health, on: 2, total: 3),
  NotificationGroup.money: GroupReminderSettings(group: NotificationGroup.money, on: 1, total: 1),
  NotificationGroup.family: GroupReminderSettings(group: NotificationGroup.family, on: 2, total: 2),
  NotificationGroup.travel: GroupReminderSettings.perItem(NotificationGroup.travel),
  NotificationGroup.wird: GroupReminderSettings(group: NotificationGroup.wird, on: 1, total: 1),
  NotificationGroup.customModules: GroupReminderSettings(group: NotificationGroup.customModules, on: 0, total: 2),
  NotificationGroup.other: GroupReminderSettings.perItem(NotificationGroup.other),
};
