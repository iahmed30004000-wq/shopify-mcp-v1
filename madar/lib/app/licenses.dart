import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Licence notices of native code that Flutter's generated NOTICES does not
/// cover, shown by `showLicensePage` (Settings › About › Open-source
/// licences) next to every Dart / Flutter package:
///
/// * SQLCipher 4.19.0 (BSD-style, Zetetic LLC) – the encrypted SQLite build
///   the `sqlite3` package's build hook links on Android;
/// * OpenSSL 3.6.4 (Apache 2.0) – linked by that SQLCipher build;
/// * the four bundled font families (SIL OFL 1.1).
abstract final class MadarLicenses {
  static bool _registered = false;

  /// Native libraries → licence asset.
  static const native = {'sqlcipher': 'assets/licenses/sqlcipher.txt', 'openssl': 'assets/licenses/openssl.txt'};

  /// Font families → OFL asset.
  static const fonts = {
    'IBM Plex Sans Arabic': 'assets/fonts/licenses/ibmplexsansarabic-OFL.txt',
    'Reem Kufi': 'assets/fonts/licenses/reemkufi-OFL.txt',
    'Amiri': 'assets/fonts/licenses/amiri-OFL.txt',
    'Amiri Quran': 'assets/fonts/licenses/amiriquran-OFL.txt',
  };

  /// Lets a test register again after `LicenseRegistry.reset()`.
  @visibleForTesting
  static void debugReset() => _registered = false;

  /// Adds the notices to [LicenseRegistry] once per process.
  static void register({AssetBundle? bundle}) {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() async* {
      final assets = bundle ?? rootBundle;
      for (final e in {...native, ...fonts}.entries) {
        try {
          yield LicenseEntryWithLineBreaks([e.key], await assets.loadString(e.value));
        } catch (err) {
          debugPrint('Missing licence text for ${e.key}: $err');
        }
      }
    });
  }
}
