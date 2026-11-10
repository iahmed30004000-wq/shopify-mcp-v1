import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/health/meds/data/meds_notifications.dart';
import 'package:madar/features/notification_center/notification_center.dart';

import 'nc_fixtures.dart';
import 'nc_harness.dart';

Future<void> frames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [f] inside the Upcoming (or Recent) list only – both lists stay built.
Finder inList(Finder f, {bool recent = false}) =>
    find.descendant(of: find.byKey(ValueKey(recent ? 'nc.recent' : 'nc.upcoming')), matching: f);

void main() {
  const upcoming = NotificationCenterScreen(initialTab: CenterTab.upcoming);
  const recent = NotificationCenterScreen(initialTab: CenterTab.recent);

  Future<NcEnv> pump(
    WidgetTester tester, {
    Widget home = upcoming,
    Locale locale = const Locale('ar'),
    bool seed = true,
    NotificationCenterLinks? links,
    Map<NotificationGroup, GroupReminderSettings>? groupSettings = ncGroupSettings,
    bool tall = true,
  }) => pumpNcApp(
    tester,
    tall: tall,
    home: home,
    locale: locale,
    links: links,
    groupSettings: groupSettings,
    seed: seed ? (env) => seedWeek(env, lang: locale.languageCode) : null,
  );

  NotificationCenterState state(NcEnv env) => env.container.read(notificationCenterProvider);

  testWidgets('Upcoming (Arabic, RTL): the week grouped by feature, with counts and states', (tester) async {
    final env = await pump(tester);
    expect(Directionality.of(tester.element(find.byType(NotificationCenterScreen))), TextDirection.rtl);
    expect(find.text('الإشعارات'), findsOneWidget);
    // Sections with their counts (screen-reader headers).
    expect(find.bySemanticsLabel('الصلاة والأذان، ٦'), findsOneWidget);
    expect(find.text('الصلاة والأذان'), findsOneWidget);
    // Human titles from the payloads, in the UI language.
    expect(find.text('أذان العصر'), findsOneWidget);
    expect(find.text('المغرب بعد ١٠ د'), findsOneWidget);
    // Six prayer alarms: four shown, the rest a tap away.
    expect(find.text('أذان الظهر'), findsNothing);
    await tester.ensureVisible(find.text('عرض اثنين آخرين'));
    await tester.tap(find.text('عرض اثنين آخرين'));
    await tester.pumpAndSettle();
    expect(find.text('أذان الظهر'), findsOneWidget);
    expect(inList(find.text('الأدوية')), findsOneWidget);
    expect(state(env).upcomingSections.firstWhere((x) => x.group == NotificationGroup.medications).count, 2);
    // Family is muted until tomorrow morning: its digest is listed, marked.
    final family = state(env).upcoming.firstWhere((i) => i.group == NotificationGroup.family);
    expect(family.state, CenterItemState.muted);
    expect(env.notifications.scheduled.containsKey(family.id), isFalse, reason: 'held back by the gate');
    expect(state(env).upcoming, hasLength(17), reason: 'the passport reminder is in 4 days, still inside the week');
  });

  testWidgets('opens on Recent when something is new; the tab bar shows both counts', (tester) async {
    await pump(tester, home: const NotificationCenterScreen());
    expect(find.text('حان موعد فيتامين د'), findsOneWidget, reason: 'Recent is on screen');
    expect(find.bySemanticsLabel('القادمة، ١٧'), findsOneWidget);
    expect(
      find.bySemanticsLabel('الأخيرة، ٤'),
      findsOneWidget,
      reason: 'the tray dose, the birthday, the residence, Dhuhr',
    );
  });

  testWidgets('Recent (English): the dose in the tray offers Taken / Snooze / Skip; Taken goes to the meds handler', (
    tester,
  ) async {
    final env = await pump(tester, home: recent, locale: const Locale('en'));
    expect(find.text('Time for Vitamin D'), findsOneWidget);
    expect(find.text('Showing now'), findsOneWidget);
    expect(find.text('Answered: Taken'), findsOneWidget, reason: "this morning's Levo");
    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    env.haptics.fired.clear();
    await tester.tap(find.text('Taken'));
    await settleNc(tester);
    expect(env.actions.single.actionId, MedsNotificationTaps.actionTaken);
    expect(env.actions.single.live, isTrue);
    expect(MedsNotificationTaps.doseOf(env.actions.single.tap), isNotNull);
    expect(env.haptics.fired, contains(Haptic.success));
    expect(env.notifications.shown, isEmpty, reason: 'out of the tray');
    expect(find.text('Answered: Taken'), findsNWidgets(2));
  });

  testWidgets('swipe right skips an upcoming one; undo brings it back', (tester) async {
    final env = await pump(tester, locale: const Locale('en'));
    final isha = find.text('Isha adhan');
    expect(isha, findsOneWidget);
    await tester.drag(isha, const Offset(300, 0));
    await frames(tester);
    final item = state(env).upcoming.firstWhere((i) => i.notice.data['s'] == 'isha');
    expect(item.state, CenterItemState.skipped);
    expect(env.notifications.scheduled.containsKey(item.id), isFalse);
    expect(find.text("This one won't arrive"), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settleNc(tester);
    expect(state(env).upcoming.firstWhere((i) => i.id == item.id).state, CenterItemState.scheduled);
    expect(env.notifications.scheduled.containsKey(item.id), isTrue);
  });

  testWidgets('long-press → mute the group for an hour → it is quiet, and one tap unmutes', (tester) async {
    final env = await pump(tester, locale: const Locale('en'));
    await tester.longPress(inList(find.text('Time for Levo')).first);
    await tester.pumpAndSettle();
    expect(find.text('Skip this one'), findsOneWidget);
    expect(find.text('Reminder settings'), findsOneWidget);
    await tester.tap(find.text('Mute Medications'));
    await tester.pumpAndSettle();
    expect(find.text('Mute Medications'), findsOneWidget, reason: 'the mute sheet');
    await tester.tap(find.text('1 hour'));
    await settleNc(tester);
    expect(state(env).mutes[NotificationGroup.medications], ncNow.add(const Duration(hours: 1)));
    // The 20:00 dose is after the hour: still armed.
    expect(state(env).upcoming.where((i) => i.group == NotificationGroup.medications).map((i) => i.state).toSet(), {
      CenterItemState.scheduled,
    });
    final chip = find.text('Muted until ${CenterTexts.forLanguage('en').time(ncNow.add(const Duration(hours: 1)))}');
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await settleNc(tester);
    expect(state(env).mutes.containsKey(NotificationGroup.medications), isFalse);
  });

  testWidgets('the reminder-settings link opens the owning feature for an item', (tester) async {
    final env = await pump(tester, locale: const Locale('en'));
    await tester.longPress(inList(find.text('Dr. Salma')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminder settings'));
    await tester.pumpAndSettle();
    expect(env.opened, ['health']);
  });

  testWidgets('clear all empties Recent and the tray; undo restores the list', (tester) async {
    final env = await pump(tester, home: recent, locale: const Locale('en'));
    await tester.tap(find.text('Clear all'));
    await frames(tester);
    expect(find.text('All caught up'), findsOneWidget);
    expect(env.notifications.shown, isEmpty);
    expect(find.text('Cleared 6 notifications'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await settleNc(tester);
    expect(state(env).recent, hasLength(6));
  });

  testWidgets('empty states, both tabs', (tester) async {
    await pump(tester, seed: false, locale: const Locale('en'));
    expect(find.text('Nothing scheduled'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Recent'));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);
  });

  testWidgets('leaving Recent marks everything seen (the bell goes quiet)', (tester) async {
    final env = await pump(tester, home: recent);
    expect(state(env).unread, 4);
    await tester.tap(find.bySemanticsLabel('القادمة، ١٧'));
    await settleNc(tester);
    expect(env.container.read(notificationUnreadCountProvider), 0);
  });

  testWidgets('the bell shows the new count, reads it out, and opens the center', (tester) async {
    await pump(
      tester,
      home: const Scaffold(body: Center(child: NotificationBell())),
    );
    expect(find.text('٤'), findsOneWidget);
    expect(find.bySemanticsLabel('الإشعارات، ٤ جديدة'), findsOneWidget);
    await tester.tap(find.byType(NotificationBell));
    await settleNc(tester);
    expect(find.byType(NotificationCenterScreen), findsOneWidget);
    expect(find.text('حان موعد فيتامين د'), findsOneWidget);
  });

  testWidgets('the bell is quiet with nothing new', (tester) async {
    await pump(
      tester,
      seed: false,
      home: const Scaffold(body: Center(child: NotificationBell())),
      locale: const Locale('en'),
    );
    expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
  });

  testWidgets('settings summary: each group\'s switches, what is coming, its mute and its link', (tester) async {
    final env = await pump(
      tester,
      home: const Scaffold(body: SingleChildScrollView(child: NotificationSettingsSummary())),
      locale: const Locale('en'),
    );
    expect(find.text('Prayer & adhan'), findsOneWidget);
    expect(find.textContaining('5 of 6 on'), findsOneWidget);
    expect(find.textContaining('Set per item'), findsOneWidget, reason: 'travel has no global switch');
    expect(find.textContaining('6 coming'), findsOneWidget);
    expect(find.text('Other'), findsNothing, reason: 'nothing of it is coming');
    expect(find.textContaining('Muted until'), findsOneWidget, reason: 'family');
    await tester.tap(find.text('Medications'));
    await tester.pumpAndSettle();
    expect(env.opened, ['medications']);
  });

  testWidgets('settings summary reads the features\' own switches from the database', (tester) async {
    await pump(
      tester,
      home: const Scaffold(body: SingleChildScrollView(child: NotificationSettingsSummary())),
      locale: const Locale('en'),
      groupSettings: null,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Medications'), findsOneWidget);
    expect(find.textContaining('Set per item'), findsOneWidget);
  });

  testWidgets('without links the rows offer neither Open nor Reminder settings', (tester) async {
    await pump(tester, locale: const Locale('en'), links: const NotificationCenterLinks());
    await tester.longPress(inList(find.text('Dr. Salma')));
    await tester.pumpAndSettle();
    expect(find.text('Reminder settings'), findsNothing);
    expect(find.text('Open'), findsNothing);
    expect(find.text('Skip this one'), findsOneWidget);
  });

  testWidgets('every row has a readable label and 48dp targets hold', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, home: recent, locale: const Locale('en'));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('MadarScaffold hosts it (smoke)', (tester) async {
    await pump(tester, locale: const Locale('en'));
    expect(find.byType(MadarScaffold), findsOneWidget);
  });
}
