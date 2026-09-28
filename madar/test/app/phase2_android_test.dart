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

  test('the notification receivers the plugin needs are registered', () {
    for (final r in ['ScheduledNotificationReceiver', 'ScheduledNotificationBootReceiver', 'ActionBroadcastReceiver']) {
      expect(manifest, contains('com.dexterous.flutterlocalnotifications.$r'), reason: r);
    }
  });
}
