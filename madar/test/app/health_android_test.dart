import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 4 (health) on Android: the dose notifications' Taken / Snooze /
/// Skip buttons reach the plugin's background receiver, and the support
/// note's tel: link is visible to url_launcher on Android 11+.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('notification action buttons are received without opening the app', () {
    expect(
      manifest,
      contains(
        '<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />',
      ),
    );
  });

  test('the dialler is reachable through a tel: query (package visibility)', () {
    final queries = RegExp('<queries>(.*?)</queries>', dotAll: true).firstMatch(manifest)?.group(1) ?? '';
    expect(
      RegExp(
        r'<intent>\s*<action android:name="android.intent.action.VIEW" />\s*<data android:scheme="tel" />\s*</intent>',
      ).hasMatch(queries),
      isTrue,
    );
    // Only a dial link: no CALL_PHONE permission (the user presses call).
    expect(manifest, isNot(contains('android.permission.CALL_PHONE')));
  });
}
