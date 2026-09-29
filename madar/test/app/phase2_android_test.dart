// The Android side of the Phase 2 wiring, checked statically (CI builds the
// first real APK): what the manifest must and must not ask for.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('the adhan, reminders and GPS permissions are declared – approximate location only', () {
    for (final p in [
      'POST_NOTIFICATIONS',
      'RECEIVE_BOOT_COMPLETED',
      'USE_EXACT_ALARM',
      'USE_FULL_SCREEN_INTENT',
      'USE_BIOMETRIC',
      'ACCESS_COARSE_LOCATION',
    ]) {
      expect(manifest, contains('android.permission.$p'), reason: p);
    }
    expect(manifest, isNot(contains('ACCESS_FINE_LOCATION')));
    expect(manifest, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
  });

  test("geolocator's unused location foreground service permission is removed from the merged manifest", () {
    expect(manifest, contains('xmlns:tools="http://schemas.android.com/tools"'));
    expect(
      RegExp(
        r'<uses-permission\s+android:name="android.permission.FOREGROUND_SERVICE_LOCATION"\s+tools:node="remove"\s*/>',
      ).hasMatch(manifest),
      isTrue,
    );
  });

  test("MainActivity hosts audio_service's shared engine (no second main() in the process)", () {
    // audio_service looks its cached engine up whenever it attaches to an
    // activity and starts another one – running main() a second time – when
    // the activity does not provide it.
    final activity = File('android/app/src/main/kotlin/app/madar/orbit/MainActivity.kt').readAsStringSync();
    expect(activity, contains('class MainActivity : AudioServiceFragmentActivity()'));
    // The engine outlives the activity: notification launches into a running
    // app are forwarded like a new intent.
    expect(activity, contains('activityControlSurface.onNewIntent('));
  });

  test("the boot guard runs before the plugin's boot receiver without a system-reserved priority", () {
    final filter = RegExp(
      r'android:name="\.AdhanBootGuard">\s*<intent-filter android:priority="(\d+)"',
    ).firstMatch(manifest);
    expect(filter, isNotNull);
    final priority = int.parse(filter!.group(1)!);
    expect(priority, greaterThan(0));
    expect(priority, lessThan(1000));
  });

  test('the notification receivers the plugin needs are registered', () {
    for (final r in ['ScheduledNotificationReceiver', 'ScheduledNotificationBootReceiver', 'ActionBroadcastReceiver']) {
      expect(manifest, contains('com.dexterous.flutterlocalnotifications.$r'), reason: r);
    }
  });
}
