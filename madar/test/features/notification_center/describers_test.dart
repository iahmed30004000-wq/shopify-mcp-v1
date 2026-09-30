import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/domain/adhan_event.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/health/meds/data/meds_notifications.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_fixtures.dart';

/// What the platform hands back for [r]: the envelope plus the texts.
CenterNotice noticeOf(NotificationRequest r) =>
    CenterNotice.fromPayload(r.id, NotificationEnvelope.encode(r), title: r.title, body: r.body);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = NotificationDescriberRegistry(builtInDescribers());
  final ar = CenterTexts.forLanguage('ar');
  final en = CenterTexts.forLanguage('en');
  final at = ncAt(0, 18, 12);
  final all = everyKind(at);

  test('every namespace (and every sub-block of reminders) lands in its group', () {
    const expected = {
      'adhan': NotificationGroup.prayer,
      'preAdhan': NotificationGroup.prayer,
      'sunrise': NotificationGroup.prayer,
      'adhkarMorning': NotificationGroup.adhkar,
      'adhkarEvening': NotificationGroup.adhkar,
      'dose': NotificationGroup.medications,
      'refill': NotificationGroup.medications,
      'medsNotice': NotificationGroup.medications,
      'appointment': NotificationGroup.health,
      'worry': NotificationGroup.health,
      'fastGoal': NotificationGroup.health,
      'eatingClose': NotificationGroup.health,
      'debt': NotificationGroup.money,
      'obligation': NotificationGroup.money,
      'familyDigest': NotificationGroup.family,
      'birthday': NotificationGroup.family,
      'birthdayEve': NotificationGroup.family,
      'travelAhead': NotificationGroup.travel,
      'travelToday': NotificationGroup.travel,
      'module': NotificationGroup.customModules,
      'wird': NotificationGroup.wird,
    };
    expect(all.keys.toSet(), expected.keys.toSet());
    for (final e in all.entries) {
      final n = noticeOf(e.value);
      expect(registry.groupOf(n), expected[e.key], reason: e.key);
      // describe agrees with groupOf
      expect(registry.describe(n, en).group, expected[e.key], reason: e.key);
    }
  });

  test('each kind is named, in both languages, and never with an empty title', () {
    const kindsEn = {
      'adhan': 'Maghrib adhan',
      'preAdhan': 'Before Isha',
      'sunrise': 'Sunrise',
      'adhkarMorning': 'Morning adhkar',
      'adhkarEvening': 'Evening adhkar',
      'dose': 'Dose reminder',
      'refill': 'Time to refill',
      'medsNotice': 'Answer not recorded',
      'appointment': 'Appointment',
      'worry': 'Worry window',
      'fastGoal': 'Fasting goal',
      'eatingClose': 'Eating window closing',
      'debt': 'Debt due',
      'obligation': 'Payment due',
      'familyDigest': 'Keep in touch',
      'birthday': 'Birthday today',
      'birthdayEve': 'Birthday tomorrow',
      'travelAhead': 'Document expiring soon',
      'travelToday': 'Document expires today',
      'module': 'Module reminder',
      'wird': 'Daily wird',
    };
    for (final e in all.entries) {
      final n = noticeOf(e.value);
      final d = registry.describe(n, en);
      expect(d.kind, kindsEn[e.key], reason: e.key);
      for (final t in [ar, en]) {
        final x = registry.describe(n, t);
        expect(x.title.trim(), isNotEmpty, reason: e.key);
        expect(x.kind.trim(), isNotEmpty, reason: e.key);
      }
    }
  });

  test('the adhan is titled from its payload in the current language, with the prayer time', () {
    final n = noticeOf(all['adhan']!);
    final dEn = registry.describe(n, en);
    final dAr = registry.describe(n, ar);
    expect(dEn.title, 'Maghrib adhan');
    expect(dAr.title, 'أذان المغرب');
    expect(dEn.body, isNull, reason: 'its time is the row\'s time');
    expect(dAr.title, isNot(contains('null')));
    expect(dEn.snoozable, isFalse);
    expect(dEn.icon, Icons.mosque_rounded);
    final pre = registry.describe(noticeOf(all['preAdhan']!), en);
    expect(pre.title, 'Isha in 10 min');
    expect(pre.body, 'at ${en.time(at)}', reason: 'the prayer time itself');
    expect(registry.describe(noticeOf(all['preAdhan']!), ar).body, contains('الساعة'));
  });

  test('titles the feature wrote are kept (they carry names the payload lacks)', () {
    final d = registry.describe(noticeOf(all['dose']!), ar);
    expect(d.title, contains('Levo'));
    expect(d.body, '10 mg');
    expect(registry.describe(noticeOf(all['module']!), en).title, 'سجّل قراءة الضغط');
    // …and a notice without texts (a tap) still gets a human title.
    final bare = CenterNotice.fromTap(all['dose']!.toTapLike());
    expect(registry.describe(bare, en).title, 'Dose reminder');
  });

  test('inline actions mirror the notification buttons and use the feature action ids', () {
    final dose = registry.describe(noticeOf(all['dose']!), en);
    expect(dose.actions.map((a) => a.id), [
      MedsNotificationTaps.actionTaken,
      MedsNotificationTaps.actionSnooze,
      MedsNotificationTaps.actionSkip,
    ]);
    expect(dose.actions.map((a) => a.label), ['Taken', 'Snooze', 'Skip']);
    expect(dose.actions.first.primary, isTrue);
    expect(dose.snoozable, isFalse, reason: 'the dose has its own snooze');
    final adhan = registry.describe(noticeOf(all['adhan']!), en);
    expect(adhan.actions.single.id, AdhanActions.stop);
    expect(adhan.actions.single.liveOnly, isTrue);
    // Nothing else has buttons.
    for (final k in ['adhkarMorning', 'refill', 'appointment', 'debt', 'birthday', 'travelAhead', 'module', 'wird']) {
      expect(registry.describe(noticeOf(all[k]!), en).actions, isEmpty, reason: k);
    }
  });

  test('actions are offered where they make sense: Stop only while in the tray, Taken early too', () {
    final n = noticeOf(all['adhan']!);
    final stop = registry.describe(n, en).actions.single;
    CenterItem item(CenterItemState s, {bool live = false}) =>
        CenterItem(notice: n, group: NotificationGroup.prayer, state: s, live: live);
    expect(stop.availableFor(item(CenterItemState.live, live: true)), isTrue);
    expect(stop.availableFor(item(CenterItemState.delivered)), isFalse);
    expect(stop.availableFor(item(CenterItemState.scheduled)), isFalse);
    final dose = registry.describe(noticeOf(all['dose']!), en).actions;
    final upcoming = item(CenterItemState.scheduled);
    expect(dose.where((a) => a.availableFor(upcoming)).map((a) => a.id), [
      MedsNotificationTaps.actionTaken,
      MedsNotificationTaps.actionSkip,
    ]);
    expect(dose.every((a) => !a.availableFor(item(CenterItemState.muted))), isTrue);
    expect(dose.every((a) => !a.availableFor(item(CenterItemState.acted))), isTrue);
    expect(dose.every((a) => a.availableFor(item(CenterItemState.delivered))), isTrue);
  });

  test('subjects name what the notification is about (for settings links)', () {
    String? subject(String k) => registry.describe(noticeOf(all[k]!), en).subject;
    expect(subject('dose'), 'meds:med-1');
    expect(subject('appointment'), 'appointment:appt-1');
    expect(subject('debt'), 'debt:debt-1');
    expect(subject('birthday'), 'person:person-1');
    expect(subject('travelAhead'), 'travelDocument:doc-1');
    expect(subject('module'), 'module:module-1');
    expect(subject('wird'), 'wirdPlan:plan-1');
    expect(subject('adhan'), 'prayer:maghrib');
  });

  test('foreign, legacy and unknown notifications fall back to Other with their own title', () {
    final foreign = CenterNotice.fromPayload(7, 'adhkar:morning', title: 'Legacy');
    expect(registry.groupOf(foreign), NotificationGroup.other);
    expect(registry.describe(foreign, en).title, 'Legacy');
    // A reminders id outside every known block.
    final stray = CenterNotice(id: 131000, namespace: 'reminders', data: const {'x': 1}, at: at);
    expect(registry.groupOf(stray), NotificationGroup.other);
    expect(registry.describe(stray, en).title, 'Notification');
    // A malformed adhan payload still lands with prayer.
    final broken = CenterNotice(id: 100001, namespace: 'adhan', data: const {'k': 'nope'}, title: 'Adhan');
    expect(registry.describe(broken, en).group, NotificationGroup.prayer);
    expect(registry.describe(broken, en).title, 'Adhan');
  });

  test('features can contribute describers; theirs win and replace by id', () {
    final r = NotificationDescriberRegistry(builtInDescribers());
    final n = noticeOf(all['wird']!);
    r.register(
      FunctionDescriber(
        id: 'wird.custom',
        classify: (x) => x.namespace == 'wird' ? NotificationGroup.other : null,
        build: (x, t) => const NotificationDescription(
          group: NotificationGroup.other,
          kind: 'k',
          title: 'Custom wird',
          icon: Icons.star,
        ),
      ),
    );
    expect(r.groupOf(n), NotificationGroup.other);
    expect(r.describe(n, en).title, 'Custom wird');
    r.unregister('wird.custom');
    expect(r.groupOf(n), NotificationGroup.wird);
  });

  test('a throwing describer never breaks the center', () {
    final r = NotificationDescriberRegistry([
      FunctionDescriber(
        id: 'boom',
        classify: (x) => NotificationGroup.health,
        build: (x, t) => throw StateError('boom'),
      ),
      ...builtInDescribers(),
    ]);
    final n = noticeOf(all['appointment']!);
    final d = r.describe(n, en);
    expect(d.group, NotificationGroup.health);
    expect(d.title, 'موعد د. سلمى');
  });

  test('the group names read naturally', () {
    expect(NotificationGroup.values.map(en.group), [
      'Prayer & adhan',
      'Adhkar',
      'Medications',
      'Health',
      'Money dues',
      'Family',
      'Travel documents',
      'Wird',
      'Custom modules',
      'Other',
    ]);
    expect(ar.group(NotificationGroup.prayer), 'الصلاة والأذان');
  });

  test('relative times', () {
    final now = ncNow;
    expect(en.when(now.add(const Duration(seconds: 20)), now), 'Now');
    expect(en.when(now.add(const Duration(minutes: 25)), now), 'in 25 min');
    expect(en.when(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
    expect(en.when(ncAt(0, 18), now), 'Today ${en.time(ncAt(0, 18))}');
    expect(en.when(ncAt(1, 4, 12), now), 'Tomorrow ${en.time(ncAt(1, 4, 12))}');
    expect(en.when(ncAt(-1, 21), now), 'Yesterday ${en.time(ncAt(-1, 21))}');
    expect(en.when(ncAt(2, 9), now), 'Friday, ${en.time(ncAt(2, 9))}');
    expect(ar.when(now.add(const Duration(minutes: 25)), now), 'بعد ٢٥ د');
    expect(ar.when(ncAt(1, 4, 12), now), startsWith('غدًا'));
  });

  test('adhan kinds cover every AdhanKind', () {
    expect(AdhanKind.values, hasLength(5));
    expect(AdhanSlot.prayers, hasLength(5));
  });
}

extension on NotificationRequest {
  /// The tap its body would produce (no texts).
  NotificationTap toTapLike() => NotificationEnvelope.decode(NotificationEnvelope.encode(this), id: id);
}
