import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/features/custom_modules/domain/module_reminders.dart';

class _Texts implements CustomReminderTexts {
  @override
  String reminderTitle(String moduleName) => 'T:$moduleName';

  @override
  String reminderBody(CustomModuleKind kind, String moduleName) => 'B:${kind.name}:$moduleName';
}

DateTime? _prayer(DateTime day, PrayerWindow w) => switch (w) {
  PrayerWindow.fajr => DateTime(day.year, day.month, day.day, 4, 40),
  PrayerWindow.duha => DateTime(day.year, day.month, day.day, 6, 5),
  PrayerWindow.dhuhr => DateTime(day.year, day.month, day.day, 12, 30),
  PrayerWindow.asr => DateTime(day.year, day.month, day.day, 15, 55),
  PrayerWindow.maghrib => DateTime(day.year, day.month, day.day, 18, 35),
  PrayerWindow.isha => DateTime(day.year, day.month, day.day, 19, 55),
  PrayerWindow.anytime => null,
};

ModuleReminderInput _r(String id, Map<String, Object?> rule, {bool enabled = true, String? note, String module = 'Reading'}) =>
    ModuleReminderInput(
      reminderId: id,
      moduleId: 'm-$module',
      moduleName: module,
      kind: CustomModuleKind.tracker,
      rule: rule,
      enabled: enabled,
      note: note,
    );

void main() {
  final now = DateTime(2026, 9, 30, 13, 0); // a Wednesday

  List<ModuleNotice> plan(List<ModuleReminderInput> r) =>
      CustomReminderPlanner.plan(reminders: r, now: now, prayerStart: _prayer, texts: _Texts());

  test('the id block is 137000–137999 inside the reminders namespace', () {
    expect(CustomModuleReminderIds.first, 137000);
    expect(CustomModuleReminderIds.last, 137999);
    expect(NotificationNamespaces.reminders.contains(CustomModuleReminderIds.first), isTrue);
    expect(NotificationNamespaces.reminders.contains(CustomModuleReminderIds.last), isTrue);
    // Neighbours stay untouched.
    expect(CustomModuleReminderIds.owns(136999), isFalse); // Family
    expect(CustomModuleReminderIds.owns(138000), isFalse); // Travel
  });

  test('daily: 7 days ahead, skipping a time already past today', () {
    final notices = plan([
      _r('r1', {'kind': 'daily', 'time': '08:30'}),
    ]);
    expect(notices, hasLength(6));
    expect(notices.first.at, DateTime(2026, 10, 1, 8, 30));
    expect(notices.last.at, DateTime(2026, 10, 6, 8, 30));
    final later = plan([
      _r('r1', {'kind': 'daily', 'time': '21:00'}),
    ]);
    expect(later.first.at, DateTime(2026, 9, 30, 21, 0));
    expect(later, hasLength(7));
  });

  test('weekly picks only its weekdays', () {
    final notices = plan([
      _r('r1', {
        'kind': 'weekly',
        'time': '09:00',
        'weekdays': [5, 6],
      }),
    ]);
    expect(notices.map((n) => n.at), [DateTime(2026, 10, 2, 9), DateTime(2026, 10, 3, 9)]);
  });

  test('after a prayer: the window start plus the offset', () {
    final notices = plan([
      _r('r1', {'kind': 'prayer', 'window': 'asr', 'offsetMin': 15}),
      _r('r2', {'kind': 'prayer', 'window': 'fajr', 'offsetMin': -10}),
    ]);
    final asr = notices.where((n) => n.reminderId == 'r1').toList();
    expect(asr.first.at, DateTime(2026, 9, 30, 16, 10));
    expect(asr, hasLength(7));
    final fajr = notices.where((n) => n.reminderId == 'r2').toList();
    expect(fajr.first.at, DateTime(2026, 10, 1, 4, 30));
    expect(fajr, hasLength(6));
  });

  test('once: only in the future, however far', () {
    expect(plan([
      _r('r1', {'kind': 'once', 'at': '2026-12-01T10:00:00'}),
    ]).single.at, DateTime(2026, 12, 1, 10));
    expect(plan([
      _r('r1', {'kind': 'once', 'at': '2026-09-30T12:00:00'}),
    ]), isEmpty);
  });

  test('disabled, malformed and before-due rules are skipped', () {
    expect(
      plan([
        _r('r1', {'kind': 'daily', 'time': '08:30'}, enabled: false),
        _r('r2', {'kind': 'daily'}),
        _r('r3', {'kind': 'beforeDue', 'minutes': 60}),
        _r('r4', {'kind': 'prayer', 'window': 'anytime'}),
      ]),
      isEmpty,
    );
  });

  test('ids are unique, in the block, and stable across re-plans', () {
    final rules = [
      for (var i = 0; i < 10; i++) _r('r$i', {'kind': 'daily', 'time': '0${i % 10}:15'}),
      _r('p', {'kind': 'prayer', 'window': 'maghrib', 'offsetMin': 0}),
    ];
    final a = plan(rules);
    final ids = a.map((n) => n.id).toSet();
    expect(ids, hasLength(a.length));
    expect(ids.every(CustomModuleReminderIds.owns), isTrue);
    final b = plan(rules.reversed.toList());
    expect({for (final n in b) '${n.reminderId}|${n.at}': n.id}, {for (final n in a) '${n.reminderId}|${n.at}': n.id});
  });

  test('capped to the nearest notices', () {
    final rules = [for (var i = 0; i < 30; i++) _r('r$i', {'kind': 'daily', 'time': '22:${(i + 10).toString()}'})];
    final notices = plan(rules);
    expect(notices, hasLength(CustomReminderPlanner.cap));
    final sorted = [...notices]..sort((x, y) => x.at.compareTo(y.at));
    expect(notices.map((n) => n.at), sorted.map((n) => n.at));
  });

  test('texts and tap payload', () {
    final n = plan([
      _r('r1', {'kind': 'daily', 'time': '21:00'}),
      _r('r2', {'kind': 'daily', 'time': '21:30'}, note: '  Read 10 pages '),
    ]);
    expect(n.first.title, 'T:Reading');
    expect(n.first.body, 'B:tracker:Reading');
    expect(n[1].body, 'Read 10 pages');
    final tap = NotificationTap(id: n.first.id, namespace: 'reminders', data: n.first.data);
    expect(CustomModuleNotificationTaps.moduleOf(tap), 'm-Reading');
    expect(
      CustomModuleNotificationTaps.moduleOf(NotificationTap(id: 136001, namespace: 'reminders', data: n.first.data)),
      isNull,
    );
    expect(CustomModuleNotificationTaps.moduleOf(const NotificationTap(id: 137001, namespace: 'reminders', data: {'k': 'fam'})), isNull);
  });
}
