import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'star_catalog_data.dart';

/// A bright star (J2000 equatorial coordinates).
class CatalogStar {
  const CatalogStar(this.raDeg, this.decDeg, this.magnitude, this.temperatureK);

  final double raDeg;
  final double decDeg;
  final double magnitude;
  final double temperatureK;

  /// Unit vector in the equatorial frame (x → RA 0h, z → north celestial pole).
  (double, double, double) get unitVector {
    final ra = raDeg * math.pi / 180;
    final dec = decDeg * math.pi / 180;
    return (math.cos(dec) * math.cos(ra), math.cos(dec) * math.sin(ra), math.sin(dec));
  }

  /// Approximate sRGB colour of a black body at [temperatureK]
  /// (Tanner Helland's fit), normalised so the brightest channel is 1.
  Color get color => blackBodyColor(temperatureK);
}

/// The Yale Bright Star Catalog subset shipped with Madar (V ≤ 5.2).
abstract final class StarCatalog {
  static List<CatalogStar>? _cache;

  static List<CatalogStar> get stars => _cache ??= _decode();

  static List<CatalogStar> _decode() {
    final bytes = base64Decode(kStarCatalogBase64);
    final data = ByteData.sublistView(bytes);
    final out = List<CatalogStar>.generate(kStarCount, (i) {
      final o = i * 16;
      return CatalogStar(
        data.getFloat32(o, Endian.little),
        data.getFloat32(o + 4, Endian.little),
        data.getFloat32(o + 8, Endian.little),
        data.getFloat32(o + 12, Endian.little),
      );
    }, growable: false);
    return out;
  }
}

Color blackBodyColor(double kelvin) {
  final t = (kelvin.clamp(1000.0, 40000.0)) / 100.0;
  double r, g, b;
  if (t <= 66) {
    r = 255;
    g = 99.4708025861 * math.log(t) - 161.1195681661;
    b = t <= 19 ? 0 : 138.5177312231 * math.log(t - 10) - 305.0447927307;
  } else {
    r = 329.698727446 * math.pow(t - 60, -0.1332047592);
    g = 288.1221695283 * math.pow(t - 60, -0.0755148492);
    b = 255;
  }
  r = r.clamp(0, 255);
  g = g.clamp(0, 255);
  b = b.clamp(0, 255);
  final m = math.max(r, math.max(g, b));
  return Color.fromARGB(255, (r / m * 255).round(), (g / m * 255).round(), (b / m * 255).round());
}

/// Traditional Arabic names of bright stars (many modern names derive from
/// them). Keyed by approximate J2000 position (RA°, Dec°) of the star.
const List<({String ar, String en, double ra, double dec})> kArabicStarNames = [
  (ar: 'الشعرى اليمانية', en: 'Sirius', ra: 101.287, dec: -16.716),
  (ar: 'سهيل', en: 'Canopus', ra: 95.988, dec: -52.696),
  (ar: 'السماك الرامح', en: 'Arcturus', ra: 213.915, dec: 19.183),
  (ar: 'النسر الواقع', en: 'Vega', ra: 279.235, dec: 38.784),
  (ar: 'العيوق', en: 'Capella', ra: 79.172, dec: 45.998),
  (ar: 'رجل الجبار', en: 'Rigel', ra: 78.634, dec: -8.202),
  (ar: 'الشعرى الشامية', en: 'Procyon', ra: 114.825, dec: 5.225),
  (ar: 'آخر النهر', en: 'Achernar', ra: 24.429, dec: -57.237),
  (ar: 'يد الجوزاء', en: 'Betelgeuse', ra: 88.793, dec: 7.407),
  (ar: 'النسر الطائر', en: 'Altair', ra: 297.696, dec: 8.868),
  (ar: 'الدبران', en: 'Aldebaran', ra: 68.980, dec: 16.509),
  (ar: 'قلب العقرب', en: 'Antares', ra: 247.352, dec: -26.432),
  (ar: 'السماك الأعزل', en: 'Spica', ra: 201.298, dec: -11.161),
  (ar: 'رأس التوأم المؤخر', en: 'Pollux', ra: 116.329, dec: 28.026),
  (ar: 'فم الحوت', en: 'Fomalhaut', ra: 344.413, dec: -29.622),
  (ar: 'ذنب الدجاجة', en: 'Deneb', ra: 310.358, dec: 45.280),
  (ar: 'قلب الأسد', en: 'Regulus', ra: 152.093, dec: 11.967),
  (ar: 'العذارى', en: 'Adhara', ra: 104.656, dec: -28.972),
  (ar: 'الشولة', en: 'Shaula', ra: 263.402, dec: -37.104),
  (ar: 'المرزم', en: 'Bellatrix', ra: 81.283, dec: 6.350),
  (ar: 'النطح', en: 'Elnath', ra: 81.573, dec: 28.608),
  (ar: 'النظام', en: 'Alnilam', ra: 84.053, dec: -1.202),
  (ar: 'النير', en: 'Alnair', ra: 332.058, dec: -46.961),
  (ar: 'الجون', en: 'Alioth', ra: 193.507, dec: 55.960),
  (ar: 'مرفق الثريا', en: 'Mirfak', ra: 51.081, dec: 49.861),
  (ar: 'الدب', en: 'Dubhe', ra: 165.932, dec: 61.751),
  (ar: 'الوزن', en: 'Wezen', ra: 107.098, dec: -26.393),
  (ar: 'القائد', en: 'Alkaid', ra: 206.885, dec: 49.313),
  (ar: 'الهنعة', en: 'Alhena', ra: 99.428, dec: 16.399),
  (ar: 'الجدي', en: 'Polaris', ra: 37.955, dec: 89.264),
  (ar: 'رأس الغول', en: 'Algol', ra: 47.042, dec: 40.956),
  (ar: 'الثريا', en: 'Pleiades', ra: 56.871, dec: 24.105),
];
