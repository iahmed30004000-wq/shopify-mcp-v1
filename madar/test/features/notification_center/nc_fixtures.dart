// Notification requests exactly as each Madar feature builds them (through
// the features' own request builders wherever they are public), for the
// notification center's tests.
import 'package:madar/core/domain/enums.dart' show PrayerWindow;
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_event.dart';
import 'package:madar/features/adhan/domain/adhan_plan.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhkar/data/adhkar_notifications.dart';
import 'package:madar/features/adhkar/domain/adhkar_models.dart';
import 'package:madar/features/adhkar/domain/adhkar_reminders.dart';
import 'package:madar/features/body/data/body_reminders.dart';
import 'package:madar/features/body/domain/body_reminder_plan.dart';
import 'package:madar/features/custom_modules/data/custom_modules_notifications.dart';
import 'package:madar/features/custom_modules/domain/module_reminders.dart';
import 'package:madar/features/family/data/family_notifications.dart';
import 'package:madar/features/family/domain/family_reminders.dart';
import 'package:madar/features/health/meds/data/meds_notifications.dart';
import 'package:madar/features/health/meds/data/meds_service.dart' show MedDoseAction, MedDoseActionKind;
import 'package:madar/features/health/meds/meds_texts.dart';
import 'package:madar/features/health/record/data/appointment_reminders.dart';
import 'package:madar/features/health/record/domain/appointment_plan.dart';
import 'package:madar/features/health/wellbeing/data/worry_reminders.dart';
import 'package:madar/features/health/wellbeing/domain/worry_window.dart';
import 'package:madar/features/money/goals/data/goals_notifications.dart';
import 'package:madar/features/money/goals/domain/due_reminders.dart';
import 'package:madar/features/travel/data/travel_notifications.dart';
import 'package:madar/features/travel/domain/document_reminders.dart';
import 'package:madar/features/travel/domain/documents.dart';
import 'package:madar/features/travel/travel_texts.dart';
import 'package:madar/features/wird/data/wird_notifications.dart';
import 'package:madar/features/wird/domain/wird_reminders.dart';

/// Wednesday 30 September 2026, 13:10 (local).
final DateTime ncNow = DateTime(2026, 9, 30, 13, 10);

DateTime ncAt(int dayOffset, int hour, [int minute = 0]) =>
    DateTime(ncNow.year, ncNow.month, ncNow.day + dayOffset, hour, minute);

DateTime _day(DateTime at) => DateTime.utc(at.year, at.month, at.day);

// -- prayer -----------------------------------------------------------------

NotificationRequest adhanCall(AdhanSlot slot, DateTime at) {
  final alarm = AdhanAlarm(
    id: AdhanIds.of(_day(at), AdhanKind.adhan, slot),
    kind: AdhanKind.adhan,
    slot: slot,
    at: at,
    prayerAt: at,
    day: _day(at),
  );
  return NotificationRequest(
    namespace: NotificationNamespaces.adhan,
    id: alarm.id,
    channelId: 'madar.adhan.call.tone-brass.v.1',
    title: 'حان الآن موعد أذان ${slot.name}',
    body: 'Call',
    at: at,
    data: AdhanEvent.fromAlarm(alarm).toData(),
    category: NotificationCategory.alarm,
    timing: NotificationTiming.alarmClock,
    actions: const [NotificationActionSpec(id: AdhanActions.stop, title: 'إيقاف')],
  );
}

NotificationRequest adhanPre(AdhanSlot slot, DateTime prayerAt, int minutes) {
  final alarm = AdhanAlarm(
    id: AdhanIds.of(_day(prayerAt), AdhanKind.preAdhan, slot),
    kind: AdhanKind.preAdhan,
    slot: slot,
    at: prayerAt.subtract(Duration(minutes: minutes)),
    prayerAt: prayerAt,
    day: _day(prayerAt),
    minutesBefore: minutes,
  );
  return NotificationRequest(
    namespace: NotificationNamespaces.adhan,
    id: alarm.id,
    channelId: 'madar.adhan.reminder.v.1',
    title: 'Pre',
    body: 'Pre body',
    at: alarm.at,
    data: AdhanEvent.fromAlarm(alarm).toData(),
    timing: NotificationTiming.alarmClock,
  );
}

NotificationRequest sunriseAlert(DateTime sunrise) {
  final alarm = AdhanAlarm(
    id: AdhanIds.of(_day(sunrise), AdhanKind.sunrise, AdhanSlot.sunrise),
    kind: AdhanKind.sunrise,
    slot: AdhanSlot.sunrise,
    at: sunrise,
    prayerAt: sunrise,
    day: _day(sunrise),
  );
  return NotificationRequest(
    namespace: NotificationNamespaces.adhan,
    id: alarm.id,
    channelId: 'madar.adhan.sunrise.v.1',
    title: 'Sunrise',
    body: 'Sunrise body',
    at: sunrise,
    data: AdhanEvent.fromAlarm(alarm).toData(),
  );
}

// -- adhkar / wird ----------------------------------------------------------

NotificationRequest adhkar(AdhkarCategoryId set, DateTime at) => NotificationAdhkarReminderScheduler.requestFor(
  AdhkarReminderNotice(
    reminder: AdhkarReminder(category: set, at: at),
    title: set == AdhkarCategoryId.morning ? 'أذكار الصباح' : 'أذكار المساء',
    body: 'حصّن يومك بذكر الله',
  ),
);

NotificationRequest wird(DateTime at, {String plan = 'plan-1'}) => NotificationWirdReminderScheduler.requestFor(
  WirdReminderNotice(
    reminder: WirdReminder(planId: plan, planName: 'ختمة', day: at, at: at, window: PrayerWindow.asr, slot: 0),
    title: 'وِرد اليوم',
    body: 'صفحتان من سورة البقرة',
  ),
);

// -- medications ------------------------------------------------------------

final MedsTexts _medsAr = MedsTexts.forLanguage('ar');

/// A dose reminder with the tracker's payload and buttons.
NotificationRequest medsDose(DateTime slot, {String medId = 'med-1', String name = 'Levo', int id = 120042}) =>
    NotificationRequest(
      namespace: NotificationNamespaces.meds,
      id: id,
      channelId: MedsReminderPlanner.channelId,
      title: _medsAr.l.medsNotifyTitle(name),
      body: '10 mg',
      at: slot,
      data: {
        'k': MedsNotificationTaps.kDose,
        'm': medId,
        's': slot.millisecondsSinceEpoch,
        'z': 10,
        'l': 'ar',
        'g': 'auto',
      },
      actions: [
        NotificationActionSpec(id: MedsNotificationTaps.actionTaken, title: _medsAr.l.medsTake),
        const NotificationActionSpec(id: MedsNotificationTaps.actionSnooze, title: 'Snooze'),
        NotificationActionSpec(id: MedsNotificationTaps.actionSkip, title: _medsAr.l.medsSkip),
      ],
    );

NotificationRequest medsRefill(DateTime at) =>
    MedsReminderPlanner.refill(medId: 'med-1', medName: 'Levo', stock: 3, texts: _medsAr, now: at);

NotificationRequest medsFailed(DateTime at) => MedsReminderPlanner.failedNotice(
  action: MedDoseAction(medId: 'med-1', slot: at, kind: MedDoseActionKind.taken, at: at),
  texts: _medsAr,
);

// -- health -----------------------------------------------------------------

NotificationRequest appointment(DateTime at) => NotificationAppointmentReminderScheduler.requestFor(
  AppointmentNotice(
    reminder: AppointmentReminder(
      id: AppointmentReminderIds.of(0, 0),
      appointmentId: 'appt-1',
      appointmentAt: at.add(const Duration(hours: 2)),
      offsetMinutes: 120,
      at: at,
    ),
    title: 'موعد د. سلمى',
    body: 'بعد ساعتين',
  ),
);

NotificationRequest worry(DateTime at) => NotificationWorryReminderScheduler.requestFor(
  WorryNotice(id: WorryReminderIds.of(0), at: at, title: 'نافذة القلق', body: 'ربع ساعة لما يشغلك'),
);

NotificationRequest fasting(DateTime at, {bool eating = false}) => NotificationBodyReminderScheduler.requestFor(
  BodyNotice(
    id: eating ? BodyReminderIds.eating(0) : BodyReminderIds.goal,
    kind: eating ? BodyNoticeKind.eatingClose : BodyNoticeKind.fastGoal,
    at: at,
    title: eating ? 'نافذة الأكل تُغلق' : 'بلغت هدف الصيام',
    body: 'Body',
  ),
);

// -- reminders namespace ----------------------------------------------------

NotificationRequest moneyDue(DateTime at, {bool debt = true}) => NotificationGoalsReminderScheduler.requestFor(
  GoalsNotice(
    id: GoalsReminderIds.of(debt ? 0 : 1),
    at: at,
    title: debt ? 'دَين لسامر' : 'قسط السيارة',
    body: '٥٠ دينارًا',
    kind: debt ? DueReminderKind.debt : DueReminderKind.obligation,
    refId: debt ? 'debt-1' : 'obl-1',
  ),
);

NotificationRequest family(DateTime at, FamilyNoticeKind kind) => FamilyReminderEngine.requestFor(
  FamilyNotice(
    id: kind == FamilyNoticeKind.digest ? FamilyNotificationIds.digest(at) : FamilyNotificationIds.birthdayFirst + 7,
    kind: kind,
    at: at,
    title: kind == FamilyNoticeKind.digest ? 'حان وقت السؤال عن ٣ أحبّة' : 'عيد ميلاد مريم',
    body: 'Family',
    personId: kind == FamilyNoticeKind.digest ? null : 'person-1',
  ),
);

NotificationRequest travelDoc(DateTime at, {bool onDay = false}) => TravelDocumentNotifier.requestFor(
  DocumentReminderPlan(
    id: TravelReminderIds.idFor(0, onDay ? DocumentReminderKind.onDay : DocumentReminderKind.ahead),
    at: at,
    doc: DocFacts(id: 'doc-1', name: 'جواز السفر', expiry: at.add(const Duration(days: 30))),
    kind: onDay ? DocumentReminderKind.onDay : DocumentReminderKind.ahead,
    daysLeft: onDay ? 0 : 30,
  ),
  TravelTexts.forLanguage('ar'),
);

NotificationRequest moduleReminder(DateTime at) => CustomModulesReminderEngine.requestFor(
  ModuleNotice(
    id: CustomModuleReminderIds.first + 11,
    at: at,
    title: 'سجّل قراءة الضغط',
    body: 'Modules',
    moduleId: 'module-1',
    reminderId: 'rem-1',
  ),
);

/// One of every notification Madar posts, keyed by a readable name.
Map<String, NotificationRequest> everyKind(DateTime at) => {
  'adhan': adhanCall(AdhanSlot.maghrib, at),
  'preAdhan': adhanPre(AdhanSlot.isha, at, 10),
  'sunrise': sunriseAlert(at),
  'adhkarMorning': adhkar(AdhkarCategoryId.morning, at),
  'adhkarEvening': adhkar(AdhkarCategoryId.evening, at),
  'dose': medsDose(at),
  'refill': medsRefill(at),
  'medsNotice': medsFailed(at),
  'appointment': appointment(at),
  'worry': worry(at),
  'fastGoal': fasting(at),
  'eatingClose': fasting(at, eating: true),
  'debt': moneyDue(at),
  'obligation': moneyDue(at, debt: false),
  'familyDigest': family(at, FamilyNoticeKind.digest),
  'birthday': family(at, FamilyNoticeKind.birthday),
  'birthdayEve': family(at, FamilyNoticeKind.birthdayEve),
  'travelAhead': travelDoc(at),
  'travelToday': travelDoc(at, onDay: true),
  'module': moduleReminder(at),
  'wird': wird(at),
};
