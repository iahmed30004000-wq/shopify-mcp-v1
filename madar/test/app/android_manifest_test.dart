import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The encrypted database, its wrapped key and the onboarding flag must never
/// move to another device without the Keystore key that unwraps it.
void main() {
  test('backup and device-to-device transfer are disabled for every domain', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:dataExtractionRules="@xml/data_extraction_rules"'));

    final rules = File('android/app/src/main/res/xml/data_extraction_rules.xml').readAsStringSync();
    const domains = [
      'root', 'file', 'database', 'sharedpref', 'external', //
      'device_root', 'device_file', 'device_database', 'device_sharedpref',
    ];
    for (final section in ['cloud-backup', 'device-transfer']) {
      final body = RegExp('<$section>(.*?)</$section>', dotAll: true).firstMatch(rules)?.group(1);
      expect(body, isNotNull, reason: section);
      for (final d in domains) {
        expect(body, contains('<exclude domain="$d" path="." />'), reason: '$section / $d');
      }
      expect(body, isNot(contains('<include')), reason: section);
    }
  });
}
