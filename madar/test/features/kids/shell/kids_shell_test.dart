// The kids shell, end to end through the real app: the home (empty, twelve
// sections, religious hidden, text scale 1.3), entering with one tap, the
// parent gate (wrong PIN, the 30-second pause, PIN, fingerprint, PIN-only),
// leaving, screen time (boundary, warning, midnight, clock changes, the
// background, limit 0, the stepper), the pin-the-screen offer, and "no network
// from inside the section".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/kids/shell/kids_shell.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../../../helpers/test_app.dart';
import 'kids_test_utils.dart';

Finder _key(String k) => find.byKey(ValueKey(k));

void main() {
  group('the kids home', () {
    testWidgets('an empty registry shows the empty state, the lock and the star chip', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await pumpKids(tester, h);
      expect(pathOf(app), '/kids');
      expect(_key('kids-home'), findsOneWidget);
      expect(_key('kids-empty'), findsOneWidget);
      expect(_key('kids-lock'), findsOneWidget);
      expect(_key('kids-stars-chip'), findsOneWidget);
      expect(_key('kids-time-chip'), findsNothing, reason: 'no limit, no time chip');
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('twelve sections at text scale 1.3, right to left, all on 64+ targets, no overflow', (tester) async {
      final h = await KidsHarness.create(
        initial: KidsHarness.on(),
        sections: [for (var i = 0; i < 12; i++) testSection('w$i', order: i, label: 'عالم $i')],
        stars: 24,
      );
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await pumpKids(tester, h);
      expect(app.settings.languageCode, 'ar');
      expect(Directionality.of(tester.element(_key('kids-home'))), TextDirection.rtl);
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 12; i++) {
        final tile = _key('kids-tile-w$i');
        await tester.dragUntilVisible(tile, _key('kids-grid'), const Offset(0, -150));
        final size = tester.getSize(tile);
        expect(size.width, greaterThanOrEqualTo(64), reason: 'tile $i');
        expect(size.height, greaterThanOrEqualTo(64), reason: 'tile $i');
        expect(tester.takeException(), isNull, reason: 'tile $i overflowed');
      }
      // The lock button and the chips are big enough too.
      expect(tester.getSize(_key('kids-lock')).shortestSide, greaterThanOrEqualTo(64));
      expect(tester.getSize(_key('kids-stars-chip')).height, greaterThanOrEqualTo(64));
      // Numbers are Arabic-Indic on kids screens.
      expect(find.textContaining('٢٤'), findsOneWidget);
    });

    testWidgets('religious sections are not shown (and cannot be opened) while the flag is false', (tester) async {
      final h = await KidsHarness.create(
        initial: KidsHarness.on(),
        sections: [testSection('maths', order: 1), testSection('quran', order: 2, religious: true)],
      );
      final app = await pumpKids(tester, h);
      expect(_key('kids-tile-maths'), findsOneWidget);
      expect(_key('kids-tile-quran'), findsNothing);
      app.router.go('/kids/s/quran');
      await tester.pumpAndSettle();
      expect(pathOf(app), '/kids', reason: 'a deep link to a hidden section lands on the home');
      expect(find.text('body-quran'), findsNothing);
    });

    testWidgets('religious sections appear once the flag is flipped', (tester) async {
      final h = await KidsHarness.create(
        initial: KidsHarness.on(),
        sections: [testSection('maths', order: 1), testSection('quran', order: 2, religious: true)],
        religiousUnlocked: true,
      );
      await pumpKids(tester, h);
      expect(_key('kids-tile-quran'), findsOneWidget);
    });

    testWidgets('a section opens inside /kids/s/<id>; Back returns to the home, never out', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), sections: [testSection('maths', label: 'الحساب')]);
      final app = await pumpKids(tester, h);
      await tester.tap(_key('kids-tile-maths'));
      await tester.pumpAndSettle();
      expect(pathOf(app), '/kids/s/maths');
      expect(find.text('body-maths'), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(pathOf(app), '/kids');
      expect(_key('kids-parent-gate'), findsNothing, reason: 'Back inside a section only goes up one level');
    });

    testWidgets('English works too, left to right', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), sections: [testSection('maths')]);
      await pumpKids(tester, h, languageCode: 'en');
      expect(Directionality.of(tester.element(_key('kids-home'))), TextDirection.ltr);
      expect(find.text('Hello, star!'), findsOneWidget);
    });
  });

  group('entering', () {
    testWidgets('Settings starts with the card; ONE tap on «ادخل» goes in and offers pinning', (tester) async {
      final h = await KidsHarness.create();
      final app = await pumpKids(tester, h, initialLocation: '/settings');
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(_key('kids-entry-card'), findsOneWidget);
      final card = tester.getTopLeft(_key('kids-entry-card')).dy;
      expect(card, lessThan(tester.getTopLeft(find.byType(Scrollable).first).dy + 200), reason: 'at the very top');

      await tester.tap(_key('kids-enter'));
      await tester.pumpAndSettle();
      expect(pathOf(app), '/kids');
      expect(h.store.state.on, isTrue, reason: 'written the moment it changes');
      expect(find.byType(SettingsScreen), findsNothing);
      expect(_key('kids-pin-offer'), findsOneWidget);
      expect(find.text('تثبيت الشاشة بيخلّي الجوال على مدار الصغار فقط، وما بيطلع منه إلا الأهل.'), findsOneWidget);

      await tester.tap(_key('kids-offer-pin'));
      await tester.pumpAndSettle();
      expect(h.pinning.starts, 1);
      expect(_key('kids-pin-offer'), findsNothing);
      expect(_key('kids-home'), findsOneWidget);
    });

    testWidgets('«مش هلأ» continues without pinning', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await pumpKids(tester, h);
      app.container.read(kidsModeProvider.notifier).enter();
      await tester.pumpAndSettle();
      expect(_key('kids-pin-offer'), findsOneWidget);
      await tester.tap(_key('kids-offer-skip'));
      await tester.pumpAndSettle();
      expect(h.pinning.starts, 0);
      expect(_key('kids-home'), findsOneWidget);
    });

    testWidgets('a relaunch is not offered pinning again', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      await pumpKids(tester, h);
      expect(_key('kids-pin-offer'), findsNothing);
    });

    testWidgets('with no PIN the parent is asked to set one first; backing out does not enter', (tester) async {
      final h = await KidsHarness.create(pin: null);
      final app = await pumpKids(tester, h, initialLocation: '/settings');
      await tester.tap(_key('kids-enter'));
      await tester.pumpAndSettle();
      expect(_key('kids-need-pin-action'), findsOneWidget);
      // Dismiss the dialog without setting a PIN.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(h.store.state.on, isFalse);
      expect(pathOf(app), '/settings');
    });

    testWidgets('the unavailable pinning feature is skipped quietly', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), pinningSupported: false);
      final app = await pumpKids(tester, h);
      app.container.read(kidsModeProvider.notifier).enter();
      await tester.pumpAndSettle();
      await tester.tap(_key('kids-offer-pin'));
      await tester.pumpAndSettle();
      expect(_key('kids-home'), findsOneWidget, reason: 'no crash, no dead end');
    });
  });

  group('the parent gate', () {
    Future<TestApp> openGate(WidgetTester tester, KidsHarness h) async {
      final app = await pumpKids(tester, h);
      await tester.tap(_key('kids-lock'));
      await tester.pumpAndSettle();
      expect(_key('kids-parent-gate'), findsOneWidget);
      return app;
    }

    testWidgets('a wrong PIN does not unlock, empties the dots and says it softly', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await openGate(tester, h);
      await typeKidsPin(tester, '1111');
      expect(_key('kids-parent-corner'), findsNothing);
      expect(find.text('جرّب مرّة ثانية'), findsOneWidget);
      expect(app.container.read(kidsModeProvider).on, isTrue);
      expect(pathOf(app), '/kids');
    });

    testWidgets('three wrong PINs: a calm pause that never blames, then it opens again', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      await openGate(tester, h);
      for (var i = 0; i < 3; i++) {
        await typeKidsPin(tester, '1111');
      }
      expect(find.textContaining('استراحة صغيرة'), findsOneWidget);
      // No red, no "wrong", no "error" anywhere in the message.
      expect(find.textContaining('غلط'), findsNothing);
      expect(find.textContaining('خطأ'), findsNothing);
      // The right PIN is not accepted during the pause.
      await typeKidsPin(tester, '2580');
      expect(_key('kids-parent-corner'), findsNothing);

      h.clock.advance(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('استراحة صغيرة'), findsNothing);
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      expect(_key('kids-parent-corner'), findsOneWidget);
    });

    testWidgets('the pause survives a relaunch (the app killed to get fresh tries)', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      await openGate(tester, h);
      for (var i = 0; i < 3; i++) {
        await typeKidsPin(tester, '1111');
      }
      expect(h.store.state.backoff.pausedAt(h.clock.now), isTrue, reason: 'written to storage');
      // A new app over the same storage, same clock.
      await tester.pumpWidget(const SizedBox());
      final app = await pumpKids(tester, h);
      await tester.tap(_key('kids-lock'));
      await tester.pumpAndSettle();
      expect(find.textContaining('استراحة صغيرة'), findsOneWidget);
      await typeKidsPin(tester, '2580');
      expect(_key('kids-parent-corner'), findsNothing);
      expect(app.container.read(kidsModeProvider).on, isTrue);
    });

    testWidgets('the right PIN opens the parent corner, and «اطلع» goes to the adult home', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await openGate(tester, h);
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      expect(_key('kids-parent-corner'), findsOneWidget);
      expect(app.container.read(kidsModeProvider).on, isTrue, reason: 'still on until «اطلع»');

      await tester.tap(_key('kids-corner-leave'));
      await tester.pumpAndSettle();
      expect(pathOf(app), '/');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(h.store.state.on, isFalse, reason: 'persisted');
      expect(h.pinning.stops, greaterThanOrEqualTo(1), reason: 'the screen is unpinned');
      expect(_key('kids-home'), findsNothing);
    });

    testWidgets('the fingerprint unlocks when it is enrolled and switched on', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), biometrics: true);
      await openGate(tester, h);
      expect(_key('kids-key-fingerprint'), findsOneWidget);
      await tester.tap(_key('kids-key-fingerprint'));
      await tester.pumpAndSettle();
      expect(h.lock.bio.prompts, hasLength(1));
      expect(_key('kids-parent-corner'), findsOneWidget);
    });

    testWidgets('a cancelled fingerprint does not unlock and does not count as a wrong PIN', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), biometrics: true);
      h.lock.bio.fallback = BiometricOutcome.cancelled;
      final app = await openGate(tester, h);
      await tester.tap(_key('kids-key-fingerprint'));
      await tester.pumpAndSettle();
      expect(_key('kids-parent-corner'), findsNothing);
      expect(app.container.read(kidsModeProvider).backoff, GateBackoff.none);
    });

    testWidgets('no fingerprint enrolled: PIN only (no fingerprint key)', (tester) async {
      final h = await KidsHarness.create(
        initial: KidsHarness.on(),
        biometrics: true,
        available: BiometricAvailability.notEnrolled,
      );
      await openGate(tester, h);
      expect(_key('kids-key-fingerprint'), findsNothing);
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      expect(_key('kids-parent-corner'), findsOneWidget);
    });

    testWidgets('fingerprint switched off in Madar: PIN only', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), biometrics: false);
      await openGate(tester, h);
      expect(_key('kids-key-fingerprint'), findsNothing);
    });

    testWidgets('«رجوع للّعب» and the system Back close the gate; Back never leaves', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await openGate(tester, h);
      await tester.tap(find.text('رجوع للّعب'));
      await tester.pumpAndSettle();
      expect(_key('kids-parent-gate'), findsNothing);

      // Back at the root opens the gate; Back again closes it; again, opens...
      for (var i = 0; i < 6; i++) {
        expect(await tester.binding.handlePopRoute(), isTrue, reason: 'press $i is handled');
        await tester.pumpAndSettle();
        expect(pathOf(app), '/kids');
        expect(_key('kids-parent-gate'), i.isEven ? findsOneWidget : findsNothing);
      }
      expect(app.container.read(kidsModeProvider).on, isTrue);
    });

    testWidgets('the corner closes by itself when the app leaves the foreground', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      await openGate(tester, h);
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      expect(_key('kids-parent-corner'), findsOneWidget);
      leaveForeground(tester);
      await tester.pump();
      returnToForeground(tester);
      await tester.pumpAndSettle();
      expect(_key('kids-parent-corner'), findsNothing);
      expect(_key('kids-home'), findsOneWidget);
    });
  });

  group('the parent corner', () {
    Future<TestApp> openCorner(WidgetTester tester, KidsHarness h) async {
      final app = await pumpKids(tester, h);
      await tester.tap(_key('kids-lock'));
      await tester.pumpAndSettle();
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      expect(_key('kids-parent-corner'), findsOneWidget);
      return app;
    }

    testWidgets('the limit stepper moves in five minutes, persists, and 0 means no limit', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      await openCorner(tester, h);
      expect(find.text('بدون حدّ'), findsOneWidget);
      await tester.tap(_key('kids-limit-more'));
      await tester.tap(_key('kids-limit-more'));
      await tester.pump();
      expect(h.store.state.limitMinutes, 10);
      expect(find.text('١٠ دقائق'), findsOneWidget);
      await tester.tap(_key('kids-limit-less'));
      await tester.tap(_key('kids-limit-less'));
      await tester.pump();
      expect(h.store.state.limitMinutes, 0);
      expect(find.text('بدون حدّ'), findsOneWidget);
    });

    testWidgets('re-offers pinning, and says the religious section is hidden', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      await openCorner(tester, h);
      expect(find.text('الشاشة مش مثبّتة.'), findsOneWidget);
      await tester.tap(_key('kids-corner-pin'));
      await tester.pumpAndSettle();
      expect(h.pinning.starts, 1);
      expect(find.text('الشاشة مثبّتة هلأ.'), findsOneWidget);
      expect(_key('kids-religious-line'), findsOneWidget);
      expect(find.text('مخفي لحد ما يتسمّى الشيخ المراجع.'), findsOneWidget);
    });

    testWidgets('on a phone that cannot pin it says so instead of offering', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), pinningSupported: false);
      await openCorner(tester, h);
      expect(_key('kids-corner-pin'), findsNothing);
      expect(find.text('هالجوال ما بيدعم تثبيت الشاشة من هون.'), findsOneWidget);
    });

    testWidgets('the religious line is gone once the section is unlocked', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), religiousUnlocked: true);
      await openCorner(tester, h);
      expect(_key('kids-religious-line'), findsNothing);
    });

    testWidgets('fits at text scale 1.3 on a small phone', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openCorner(tester, h);
      expect(tester.takeException(), isNull);
    });
  });

  group('screen time', () {
    testWidgets('limit - 1 second plays on; at the limit the gentle end scene; limit + 1 stays ended', (tester) async {
      // 10 minutes; 598 seconds already played today.
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 10, used: 598));
      final app = await pumpKids(tester, h);
      expect(_key('kids-end-screen'), findsNothing);
      await playSeconds(tester, h.clock, 1); // 599
      expect(app.container.read(kidsModeProvider).ledger.usedSeconds, 599);
      expect(_key('kids-end-screen'), findsNothing);
      await playSeconds(tester, h.clock, 1); // 600 = the limit
      expect(_key('kids-end-screen'), findsOneWidget);
      expect(find.text('خلص وقت اللعب اليوم'), findsOneWidget);
      expect(find.text('أخذت استراحة حلوة. منكمّل بكرا!'), findsOneWidget);
      await playSeconds(tester, h.clock, 5); // limit + 5
      expect(app.container.read(kidsModeProvider).ledger.usedSeconds, 600, reason: 'nothing counted after the end');
      expect(_key('kids-end-screen'), findsOneWidget);
      expect(h.store.state.ledger.usedSeconds, 600, reason: 'written at once when the limit is reached');
    });

    testWidgets('«تمام» leads to the parent gate; more time lifts the end scene', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 10, used: 600));
      final app = await pumpKids(tester, h);
      expect(_key('kids-end-screen'), findsOneWidget);
      await tester.tap(_key('kids-end-ok'));
      await tester.pumpAndSettle();
      expect(_key('kids-parent-gate'), findsOneWidget);
      // The child cannot get past it.
      await typeKidsPin(tester, '0000');
      expect(_key('kids-parent-corner'), findsNothing);
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      expect(_key('kids-parent-corner'), findsOneWidget);
      await tester.tap(_key('kids-limit-more'));
      await tester.pumpAndSettle();
      expect(app.container.read(kidsModeProvider).limitMinutes, 15);
      await tester.tap(_key('kids-corner-back'));
      await tester.pumpAndSettle();
      expect(_key('kids-end-screen'), findsNothing);
      expect(_key('kids-home'), findsOneWidget);
    });

    testWidgets('the end scene closes under Back too (Back opens the gate, never the app)', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 5, used: 400));
      final app = await pumpKids(tester, h);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(_key('kids-parent-gate'), findsOneWidget);
      expect(pathOf(app), '/kids');
    });

    testWidgets('five minutes before the end a small warning pill appears', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 10, used: 290));
      await pumpKids(tester, h);
      expect(_key('kids-warning-pill'), findsNothing, reason: '310 seconds left');
      await playSeconds(tester, h.clock, 10); // 300 used, 300 left
      expect(_key('kids-warning-pill'), findsOneWidget);
      expect(_key('kids-time-chip'), findsOneWidget);
    });

    testWidgets('limit 0 is off: hours of play never end the day', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 0, used: 100000));
      await pumpKids(tester, h);
      await playSeconds(tester, h.clock, 30);
      expect(_key('kids-end-screen'), findsNothing);
      expect(_key('kids-time-chip'), findsNothing);
    });

    testWidgets('across midnight a new day begins and the end scene lifts', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 10, used: 600));
      h.clock.now = DateTime(2026, 9, 28, 23, 59, 58);
      final app = await pumpKids(tester, h);
      expect(_key('kids-end-screen'), findsOneWidget);
      await playSeconds(tester, h.clock, 3); // 00:00:01
      expect(app.container.read(kidsModeProvider).ledger.dayKey, 20260929);
      expect(app.container.read(kidsModeProvider).ledger.usedSeconds, 0);
      expect(_key('kids-end-screen'), findsNothing);
      expect(_key('kids-home'), findsOneWidget);
      expect(h.store.state.ledger.dayKey, 20260929, reason: 'the new day is written');
    });

    testWidgets('a clock set forward an hour burns almost nothing', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 30, used: 0));
      final app = await pumpKids(tester, h);
      h.clock.advance(const Duration(hours: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(app.container.read(kidsModeProvider).ledger.usedSeconds, lessThanOrEqualTo(2));
    });

    testWidgets('a clock set BACK a day gives no fresh day and no negative time', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 30, used: 1500));
      final app = await pumpKids(tester, h);
      h.clock.advance(const Duration(days: -1));
      await tester.pump(const Duration(seconds: 1));
      await playSeconds(tester, h.clock, 3);
      final s = app.container.read(kidsModeProvider);
      expect(s.ledger.dayKey, kidsToday, reason: 'still the day it was');
      expect(s.ledger.usedSeconds, greaterThanOrEqualTo(1500));
    });

    testWidgets('the background does not count: a phone call mid-lesson', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 60, used: 0));
      final app = await pumpKids(tester, h);
      await playSeconds(tester, h.clock, 5);
      final before = app.container.read(kidsModeProvider).ledger.usedSeconds;
      expect(before, 5);
      leaveForeground(tester);
      await tester.pump();
      // A ten-minute call.
      for (var i = 0; i < 600; i += 10) {
        h.clock.advance(const Duration(seconds: 10));
        await tester.pump(const Duration(seconds: 10));
      }
      expect(app.container.read(kidsModeProvider).ledger.usedSeconds, before);
      expect(h.store.state.ledger.usedSeconds, before, reason: 'flushed when it went to the background');
      returnToForeground(tester);
      await tester.pump();
      await playSeconds(tester, h.clock, 2);
      expect(app.container.read(kidsModeProvider).ledger.usedSeconds, lessThanOrEqualTo(before + 4));
    });

    testWidgets('time behind the parent gate is not the child\'s', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 60, used: 0));
      final app = await pumpKids(tester, h);
      await tester.tap(_key('kids-lock'));
      await tester.pumpAndSettle();
      await playSeconds(tester, h.clock, 20);
      expect(app.container.read(kidsModeProvider).ledger.usedSeconds, 0);
    });

    testWidgets('play time is written at least every ten seconds (a dying battery)', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(limit: 60, used: 0));
      await pumpKids(tester, h);
      await playSeconds(tester, h.clock, 12);
      expect(h.store.state.ledger.usedSeconds, greaterThanOrEqualTo(10));
    });
  });

  group('the app lock', () {
    testWidgets('with kids mode on, a locked app shows the kids home, not the lock screen', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on(), biometrics: true);
      final app = await pumpKids(tester, h, lockEnabled: true);
      expect(app.container.read(lockControllerProvider).phase, LockPhase.locked, reason: 'the lock is armed');
      expect(_key('kids-home'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('after the kids PIN the adult home opens WITHOUT a second lock screen', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await pumpKids(tester, h, lockEnabled: true);
      await tester.tap(_key('kids-lock'));
      await tester.pumpAndSettle();
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      await tester.tap(_key('kids-corner-leave'));
      await tester.pumpAndSettle();
      expect(pathOf(app), '/');
      expect(app.container.read(lockControllerProvider).phase, LockPhase.open);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('after kids mode is left, the app lock works as before', (tester) async {
      final h = await KidsHarness.create(initial: KidsHarness.on());
      final app = await pumpKids(tester, h, lockEnabled: true);
      await tester.tap(_key('kids-lock'));
      await tester.pumpAndSettle();
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      await tester.tap(_key('kids-corner-leave'));
      await tester.pumpAndSettle();
      leaveForeground(tester);
      h.clock.advance(const Duration(minutes: 3));
      returnToForeground(tester);
      await tester.pump();
      expect(app.container.read(lockControllerProvider).phase, LockPhase.locked);
    });
  });

  group('no network from inside the section', () {
    testWidgets('no HTTP client is created while the shell is used', (tester) async {
      final h = await KidsHarness.create(
        initial: KidsHarness.on(limit: 10),
        sections: [testSection('maths'), testSection('letters')],
      );
      final app = await pumpKids(tester, h);
      final recorder = RecordingHttpOverrides()..install();
      addTearDown(recorder.restore);
      await tester.tap(_key('kids-tile-maths'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(_key('kids-lock'));
      await tester.pumpAndSettle();
      await typeKidsPin(tester, '9999');
      await typeKidsPin(tester, '2580');
      await tester.pumpAndSettle();
      await tester.tap(_key('kids-limit-more'));
      await tester.tap(_key('kids-corner-back'));
      await tester.pumpAndSettle();
      await playSeconds(tester, h.clock, 5);
      expect(pathOf(app), '/kids');
      expect(recorder.clients, 0, reason: 'the kids shell never touches the network');
    });
  });

  group('the settings entry', () {
    testWidgets('is reachable in two taps from the home', (tester) async {
      final h = await KidsHarness.create();
      final app = await pumpKids(tester, h);
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.tap(find.byIcon(Icons.tune_rounded)); // tap 1: the home's settings button
      await tester.pumpAndSettle();
      expect(pathOf(app), '/settings');
      expect(_key('kids-enter'), findsOneWidget, reason: 'tap 2 is «ادخل» itself');
      expect(app.settings, isA<AppSettings>());
    });
  });
}
