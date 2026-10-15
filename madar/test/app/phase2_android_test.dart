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
    // Prayer times and the qibla take approximate location only. Precise
    // location exists in the manifest for exactly one reason – a Bluetooth /
    // Wi-Fi scan on Android 12L and older, which Together Mode's "two phones
    // nearby" needs – so it must be bounded to API 32 and never declared
    // open-endedly. Background location is never asked for at all.
    final declarations = manifest.replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
    final fine = RegExp(
      r'<uses-permission\s+android:name="android.permission.ACCESS_FINE_LOCATION"([^>]*)/>',
    ).allMatches(declarations).map((m) => m.group(1)!).toList();
    expect(fine, hasLength(1), reason: 'precise location is declared exactly once');
    expect(fine.single, contains('android:maxSdkVersion="32"'));
    expect(declarations, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
  });

  test('Together Mode\'s nearby permissions are declared, and none of them derives location', () {
    for (final p in [
      'BLUETOOTH_SCAN',
      'BLUETOOTH_ADVERTISE',
      'BLUETOOTH_CONNECT',
      'NEARBY_WIFI_DEVICES',
      'ACCESS_WIFI_STATE',
      'CHANGE_WIFI_STATE',
    ]) {
      expect(manifest, contains('android.permission.$p'), reason: p);
    }
    // The two scanning permissions must say they are not used for location,
    // or Android treats them as location access.
    for (final p in ['BLUETOOTH_SCAN', 'NEARBY_WIFI_DEVICES']) {
      final line = RegExp('<uses-permission[^>]*$p[^>]*/>').firstMatch(manifest)?.group(0);
      expect(line, isNotNull, reason: p);
      expect(line, contains('android:usesPermissionFlags="neverForLocation"'), reason: p);
    }
    // Nothing here may keep Madar off a phone without the radios.
    for (final f in ['android.hardware.bluetooth', 'android.hardware.wifi.direct']) {
      expect(
        RegExp('<uses-feature\\s+android:name="$f"\\s+android:required="false"\\s*/>').hasMatch(manifest),
        isTrue,
        reason: f,
      );
    }
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
