import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Licence notices of native code that Flutter's generated NOTICES does not
/// cover, shown by `showLicensePage` (Settings › About › Open-source
/// licences) next to every Dart / Flutter package:
///
/// * SQLCipher 4.19.0 (BSD-style, Zetetic LLC) – the encrypted SQLite build
///   the `sqlite3` package's build hook links on Android;
/// * OpenSSL 3.6.4 (Apache 2.0) – linked by that SQLCipher build;
/// * the four bundled font families (SIL OFL 1.1);
/// * the bundled content and its sources ([content]): the adhkar (Hisn
///   al-Muslim datasets, MIT / Unlicense), the offline city list (Natural
///   Earth, GeoNames CC BY 4.0, IANA, Unicode CLDR), the adhan tones
///   (Madar's own, with the record of the recordings search), the Quran
///   (Tanzil text and metadata CC BY 3.0, quran-tajweed CC BY 4.0),
///   An-Nawawi's Forty (hadith-api, Unlicense), the recitations (EveryAyah,
///   streamed or downloaded only on the user's request – nothing bundled)
///   and the qibla compass's magnetic model (WMM2025, public domain).
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

  /// Bundled content → its credits file (also listed on Settings › About ›
  /// Fonts & credits).
  static const content = {
    'Adhkar – Hisn al-Muslim': 'assets/licenses/adhkar_credits.txt',
    'Madar city list': 'assets/licenses/geo_cities.txt',
    'Madar adhan tones': 'assets/licenses/adhan_sounds.txt',
    'Quran – Tanzil text, metadata & quran-tajweed': 'assets/licenses/quran_credits.txt',
    "Hadith – An-Nawawi's Forty": 'assets/licenses/hadith_credits.txt',
    'Madar Quran recitation': 'assets/licenses/recitation_credits.txt',
    'Madar qibla compass (WMM2025)': 'assets/licenses/qibla_wmm.txt',
    'Madar Cinema – word & knowledge games': 'assets/licenses/games_words_credits.txt',
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
      for (final e in {...native, ...fonts, ...content}.entries) {
        try {
          yield LicenseEntryWithLineBreaks([e.key], await assets.loadString(e.value));
        } catch (err) {
          debugPrint('Missing licence text for ${e.key}: $err');
        }
      }
    });
  }
}
