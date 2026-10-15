import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/licenses.dart';

/// Binary distributions must reproduce the notices of the native code they
/// link: SQLCipher and the OpenSSL it links on Android; every bundled content
/// source is credited too.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native licences (SQLCipher, OpenSSL), the fonts and the content credits are registered', () async {
    LicenseRegistry.reset();
    MadarLicenses.debugReset();
    MadarLicenses.register();
    MadarLicenses.register(); // idempotent
    final entries = await LicenseRegistry.licenses.toList();
    final byPackage = {for (final e in entries) e.packages.single: e.paragraphs.map((p) => p.text).join(' ')};
    expect(byPackage.keys, containsAll(['sqlcipher', 'openssl', 'IBM Plex Sans Arabic', 'Reem Kufi', 'Amiri']));
    expect(byPackage.keys, containsAll(MadarLicenses.content.keys));
    expect(entries, hasLength(MadarLicenses.native.length + MadarLicenses.fonts.length + MadarLicenses.content.length));
    expect(byPackage['sqlcipher'], contains('ZETETIC'));
    expect(byPackage['openssl'], contains('Apache License'));
    expect(byPackage['Reem Kufi'], contains('SIL OPEN FONT LICENSE'));
    // The Phase 2 content: adhkar datasets (MIT, Unlicense), the city list
    // (Natural Earth, GeoNames CC BY 4.0) and the adhan tones.
    expect(byPackage['Adhkar – Hisn al-Muslim'], allOf(contains('MIT License'), contains('Unlicense')));
    expect(byPackage['Madar city list'], allOf(contains('Natural Earth'), contains('CC BY 4.0')));
    expect(byPackage['Madar adhan tones'], contains('No human adhan recordings are bundled'));
  });

  test('every credits file in assets/licenses is registered or linked', () {
    final registered = {...MadarLicenses.native.values, ...MadarLicenses.content.values};
    final files = Directory('assets/licenses').listSync().whereType<File>().map((f) => f.path.replaceAll(r'\', '/'));
    for (final f in files) {
      expect(registered, contains(f), reason: '$f is shipped but not credited on Settings › About');
    }
  });
}
