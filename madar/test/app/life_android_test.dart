import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phase 6 (life) on Android: a person's call, SMS and WhatsApp (wa.me over
/// https) links are visible to url_launcher on Android 11+ (package
/// visibility) – each opens only on the owner's tap, and Madar asks for no
/// permission to call or send by itself.
void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final queries = RegExp('<queries>(.*?)</queries>', dotAll: true).firstMatch(manifest)?.group(1) ?? '';

  bool viewIntent(String scheme) => RegExp(
    '<intent>\\s*<action android:name="android.intent.action.VIEW" />\\s*<data android:scheme="$scheme" />\\s*</intent>',
  ).hasMatch(queries);

  test('the dialler, the messages app and WhatsApp are reachable through VIEW queries', () {
    for (final scheme in ['tel', 'sms', 'https']) {
      expect(viewIntent(scheme), isTrue, reason: scheme);
    }
    // The health query (text processing, SystemUI) is still there.
    expect(queries, contains('android.intent.action.PROCESS_TEXT'));
    expect(queries, contains('com.android.systemui'));
  });

  test('no permission to call or send by itself', () {
    for (final permission in ['CALL_PHONE', 'SEND_SMS', 'READ_CONTACTS', 'READ_SMS']) {
      expect(manifest, isNot(contains('android.permission.$permission')), reason: permission);
    }
  });
}
