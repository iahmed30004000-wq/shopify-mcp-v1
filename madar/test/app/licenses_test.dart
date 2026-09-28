import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/licenses.dart';

/// Binary distributions must reproduce the notices of the native code they
/// link: SQLCipher and the OpenSSL it links on Android.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native licences (SQLCipher, OpenSSL) and the fonts are registered', () async {
    LicenseRegistry.reset();
    MadarLicenses.debugReset();
    MadarLicenses.register();
    MadarLicenses.register(); // idempotent
    final entries = await LicenseRegistry.licenses.toList();
    final byPackage = {for (final e in entries) e.packages.single: e.paragraphs.map((p) => p.text).join(' ')};
    expect(byPackage.keys, containsAll(['sqlcipher', 'openssl', 'IBM Plex Sans Arabic', 'Reem Kufi', 'Amiri']));
    expect(entries, hasLength(MadarLicenses.native.length + MadarLicenses.fonts.length));
    expect(byPackage['sqlcipher'], contains('ZETETIC'));
    expect(byPackage['openssl'], contains('Apache License'));
    expect(byPackage['Reem Kufi'], contains('SIL OPEN FONT LICENSE'));
  });
}
