// Static checks of the Android setup local_auth needs (there is no Android
// SDK on the development machine; CI builds the APK).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const res = 'android/app/src/main/res';

  test('launch and normal themes derive from Theme.AppCompat (biometric dialog on Android 8.x)', () {
    for (final dir in ['values', 'values-night']) {
      final xml = File('$res/$dir/styles.xml').readAsStringSync();
      for (final name in ['LaunchTheme', 'NormalTheme']) {
        final style = RegExp('<style name="$name" parent="([^"]+)"').firstMatch(xml);
        expect(style, isNotNull, reason: '$dir/$name');
        expect(style!.group(1), startsWith('Theme.AppCompat'), reason: '$dir/$name');
      }
      expect(xml, contains('@drawable/launch_background'));
      expect(xml, contains('@color/madar_space'));
    }
  });

  test('the app declares androidx.appcompat for those themes', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('implementation("androidx.appcompat:appcompat:'));
  });

  test('MainActivity is a FlutterFragmentActivity and USE_BIOMETRIC is declared', () {
    final activity = File('android/app/src/main/kotlin/app/madar/orbit/MainActivity.kt').readAsStringSync();
    expect(activity, contains('FlutterFragmentActivity()'));
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.USE_BIOMETRIC'));
  });
}
