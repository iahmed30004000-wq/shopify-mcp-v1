// Shared helpers for the kids shell tests: sections, overrides, a settable
// clock, PIN typing and a "no HTTP client is ever created" recorder.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/kids/core/kids_section.dart';
import 'package:madar/features/kids/shell/kids_shell.dart';
import 'package:madar/features/lock/data/biometric_auth.dart';

import '../../lock/lock_test_utils.dart';
import '../../../helpers/test_app.dart';

/// 28 Sep 2026, 21:40 (the lock fixture's own default "now").
final DateTime kidsNow = DateTime(2026, 9, 28, 21, 40);
final int kidsToday = kidsDayKey(kidsNow);

KidsSection testSection(String id, {int order = 100, bool religious = false, String? label}) => KidsSection(
  id: id,
  title: (l) => label ?? id,
  icon: Icons.star_rounded,
  accent: KidsColors.teal500,
  order: order,
  religious: religious,
  builder: (context) => Center(child: Text('body-$id', key: ValueKey('section-body-$id'))),
);

/// Everything a kids test overrides, in one place.
class KidsHarness {
  KidsHarness({
    required this.lock,
    KidsModeState initial = KidsModeState.off,
    this.sections = const [],
    this.religiousUnlocked = false,
    this.stars = 0,
    bool pinningSupported = true,
  }) : store = MemoryKidsStore(initial),
       pinning = FakeKidsPinning(isSupported: pinningSupported);

  final LockFixture lock;
  final MemoryKidsStore store;
  final FakeKidsPinning pinning;
  final List<KidsSection> sections;
  final bool religiousUnlocked;
  final int stars;

  TestClock get clock => lock.clock;

  static Future<KidsHarness> create({
    KidsModeState initial = KidsModeState.off,
    List<KidsSection> sections = const [],
    bool religiousUnlocked = false,
    int stars = 0,
    String? pin = '2580',
    bool biometrics = false,
    BiometricAvailability available = BiometricAvailability.available,
    bool pinningSupported = true,
  }) async {
    final lock = pin == null
        ? LockFixture.empty(now: kidsNow, available: available)
        : await LockFixture.configured(pin: pin, biometrics: biometrics, now: kidsNow, available: available);
    return KidsHarness(
      lock: lock,
      initial: initial,
      sections: sections,
      religiousUnlocked: religiousUnlocked,
      stars: stars,
      pinningSupported: pinningSupported,
    );
  }

  List<Override> get overrides => [
    ...lock.overrides,
    kidsStoreProvider.overrideWithValue(store),
    kidsPinningProvider.overrideWithValue(pinning),
    kidsClockProvider.overrideWithValue(clock.call),
    kidsSectionsProvider.overrideWithValue(sections),
    kidsReligiousUnlockedProvider.overrideWithValue(religiousUnlocked),
    kidsStarCountProvider.overrideWithValue(stars),
  ];

  /// Kids mode on, with a limit and today's ledger.
  static KidsModeState on({int limit = 0, int used = 0}) => KidsModeState(
    on: true,
    limitMinutes: limit,
    ledger: ScreenTimeLedger(dayKey: kidsToday, usedSeconds: used),
  );
}

/// The app with the kids harness. The app lock is OFF by default (the PIN
/// still exists in the vault, which is what the gate checks); pass
/// `lockEnabled: true` for the lock-interplay tests.
Future<TestApp> pumpKids(
  WidgetTester tester,
  KidsHarness h, {
  String initialLocation = '/',
  bool settle = true,
  bool lockEnabled = false,
  String languageCode = 'ar',
}) => pumpMadarApp(
  tester,
  settings: AppSettings(onboarded: true, lockEnabled: lockEnabled, languageCode: languageCode),
  overrides: h.overrides,
  initialLocation: initialLocation,
  settle: settle,
);

/// The router's current path.
String pathOf(TestApp app) => app.router.routerDelegate.currentConfiguration.uri.path;

/// Taps the gate's keys for [digits] (Western digits).
Future<void> typeKidsPin(WidgetTester tester, String digits) async {
  for (final c in digits.split('')) {
    await tester.tap(find.byKey(ValueKey('kids-key-$c')));
    await tester.pump(const Duration(milliseconds: 50));
  }
  // The PBKDF2 check runs on the fake inline runner; let its futures finish.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Plays [seconds] of foreground time one second at a time.
Future<void> playSeconds(WidgetTester tester, TestClock clock, int seconds) async {
  for (var i = 0; i < seconds; i++) {
    clock.advance(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }
}

void leaveForeground(WidgetTester tester) {
  for (final s in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

void returnToForeground(WidgetTester tester) {
  for (final s in [AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
}

/// Counts every HttpClient the app creates while it is installed.
class RecordingHttpOverrides extends HttpOverrides {
  int clients = 0;
  HttpOverrides? previous;

  void install() {
    previous = HttpOverrides.current;
    HttpOverrides.global = this;
  }

  void restore() => HttpOverrides.global = previous;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    return super.createHttpClient(context);
  }
}
