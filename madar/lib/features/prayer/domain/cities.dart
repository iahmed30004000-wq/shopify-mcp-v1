import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'qibla.dart';

/// A city of the offline list (assets/geo/cities.json).
@immutable
class City {
  const City({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.latitude,
    required this.longitude,
    required this.timeZone,
    required this.countryCode,
    this.population = 0,
    this.capital = false,
    this.aliases = const [],
  });

  /// Stable id (`jo-amman`), stored with the location.
  final String id;
  final String nameAr;
  final String nameEn;
  final double latitude;
  final double longitude;

  /// IANA time zone.
  final String timeZone;

  /// ISO 3166-1 alpha-2.
  final String countryCode;
  final int population;

  /// A national capital.
  final bool capital;

  /// Other spellings used for search only.
  final List<String> aliases;

  String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;

  double distanceKmTo(double lat, double lon) => QiblaMath.greatCircleKm(latitude, longitude, lat, lon);

  @override
  bool operator ==(Object other) => other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'City($id)';
}

/// A city with its distance from a point.
typedef NearestCity = ({City city, double distanceKm});

/// A search hit.
typedef CityMatch = ({City city, double score});

/// The offline city list with search and nearest-city lookup (pure).
class CityDatabase {
  CityDatabase(this.cities, this.countries)
    : _byId = {for (final c in cities) c.id: c},
      _index = CitySearchIndex(cities, countries);

  /// Parses the asset JSON (see `test/features/prayer/geo_tool/build_cities.py`).
  factory CityDatabase.fromJson(Map<String, Object?> json) {
    final countries = <String, ({String ar, String en})>{};
    final rawCountries = json['countries'];
    if (rawCountries is Map) {
      for (final e in rawCountries.entries) {
        final v = e.value;
        if (v is List && v.length >= 2) countries['${e.key}'] = (ar: '${v[0]}', en: '${v[1]}');
      }
    }
    final cities = <City>[];
    final raw = json['cities'];
    if (raw is List) {
      for (final r in raw) {
        if (r is! List || r.length < 7) continue;
        final aliases = r.length > 9 && r[9] is String && (r[9] as String).isNotEmpty
            ? (r[9] as String).split('|')
            : const <String>[];
        cities.add(
          City(
            id: '${r[0]}',
            nameAr: '${r[1]}',
            nameEn: '${r[2]}',
            latitude: (r[3] as num).toDouble(),
            longitude: (r[4] as num).toDouble(),
            timeZone: '${r[5]}',
            countryCode: '${r[6]}',
            population: r.length > 7 && r[7] is num ? (r[7] as num).toInt() : 0,
            capital: r.length > 8 && r[8] == 1,
            aliases: aliases,
          ),
        );
      }
    }
    return CityDatabase(cities, countries);
  }

  static CityDatabase parse(String source) => CityDatabase.fromJson(jsonDecode(source) as Map<String, Object?>);

  /// Asset path of the list.
  static const assetPath = 'assets/geo/cities.json';

  final List<City> cities;
  final Map<String, ({String ar, String en})> countries;
  final Map<String, City> _byId;
  final CitySearchIndex _index;

  City? byId(String? id) => id == null ? null : _byId[id];

  /// The country's name in [languageCode] (the code itself if unknown).
  String countryName(String code, String languageCode) {
    final c = countries[code];
    if (c == null) return code;
    return languageCode == 'ar' ? c.ar : c.en;
  }

  /// Search by Arabic or English name (diacritic-, hamza- and
  /// article-insensitive, typo-tolerant); an empty query lists [featured].
  List<CityMatch> search(String query, {int limit = 40}) {
    if (CityText.fold(query).isEmpty) return [for (final c in featured.take(limit)) (city: c, score: 0)];
    return _index.search(query, limit: limit);
  }

  /// The nearest city to a point.
  NearestCity? nearest(double latitude, double longitude) {
    City? best;
    var bestKm = double.infinity;
    for (final c in cities) {
      final d = c.distanceKmTo(latitude, longitude);
      if (d < bestKm) {
        bestKm = d;
        best = c;
      }
    }
    return best == null ? null : (city: best, distanceKm: bestKm);
  }

  /// Suggestions for an empty search: the two Holy Mosques' cities and
  /// al-Aqsa's, then capitals (Arab world first) by population.
  late final List<City> featured = () {
    const holy = ['sa-makkah', 'sa-madinah', 'ps-jerusalem'];
    final out = <City>[for (final id in holy) ?_byId[id]];
    final capitals = cities.where((c) => c.capital && !holy.contains(c.id)).toList()
      ..sort((a, b) {
        final arab =
            (CityText.arabWorld.contains(b.countryCode) ? 1 : 0) - (CityText.arabWorld.contains(a.countryCode) ? 1 : 0);
        return arab != 0 ? arab : b.population.compareTo(a.population);
      });
    return [...out, ...capitals];
  }();
}

/// Text folding for search (pure).
abstract final class CityText {
  /// Arab League members (+ Western Sahara) – listed first in suggestions.
  static const arabWorld = {
    'JO',
    'PS',
    'SY',
    'LB',
    'IQ',
    'SA',
    'KW',
    'BH',
    'QA',
    'AE',
    'OM',
    'YE',
    'EG',
    'SD',
    'LY',
    'TN',
    'DZ',
    'MA', //
    'MR', 'SO', 'DJ', 'KM', 'EH',
  };

  static final RegExp _marks = RegExp('[\u064B-\u065F\u0670\u0640\u06D6-\u06ED\u0300-\u036F]');
  static final RegExp _separators = RegExp(
    '[\\s\\-_.,;:/\\\\()\\[\\]\'`|\u2018\u2019\u02BB\u02BC\u02BE\u02BF\u00B4\u200C-\u200F\u2066-\u2069]+',
  );

  static const Map<String, String> _latin = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'ā': 'a',
    'ă': 'a',
    'ą': 'a',
    'ạ': 'a', //
    'æ': 'ae',
    'ç': 'c',
    'ć': 'c',
    'č': 'c',
    'ĉ': 'c',
    'ď': 'd',
    'đ': 'd',
    'ḍ': 'd',
    'ḏ': 'd',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ē': 'e',
    'ė': 'e',
    'ę': 'e',
    'ě': 'e',
    'ẹ': 'e',
    'ğ': 'g',
    'ġ': 'g',
    'ħ': 'h',
    'ḥ': 'h',
    'ḩ': 'h',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ī': 'i',
    'ı': 'i',
    'İ': 'i',
    'ķ': 'k',
    'ł': 'l',
    'ľ': 'l',
    'ñ': 'n',
    'ń': 'n',
    'ň': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ō': 'o',
    'ő': 'o',
    'œ': 'oe',
    'ř': 'r',
    'ś': 's',
    'š': 's',
    'ş': 's',
    'ș': 's',
    'ṣ': 's',
    'ß': 'ss',
    'ť': 't',
    'ţ': 't',
    'ț': 't',
    'ṭ': 't',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ū': 'u',
    'ů': 'u',
    'ű': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ź': 'z',
    'ż': 'z',
    'ž': 'z',
    'ẓ': 'z',
    'ð': 'd',
    'þ': 'th',
  };

  /// Latin articles of transliterated Arabic names ("Az Zarqa", "Al-Ula").
  static const _latinArticles = {
    'al',
    'el',
    'ar',
    'as',
    'az',
    'ad',
    'at',
    'an',
    'ash',
    'ath',
    'adh',
    'es',
    'er',
    'ez',
    'ed',
    'et',
    'en',
    'ech', //
  };

  /// Lower-cases, removes diacritics / tashkeel / tatweel, unifies Arabic
  /// letter variants (أ إ آ ٱ → ا, ة → ه, ى ی → ي, ؤ → و, ئ → ي, ک → ك),
  /// converts digits of every script to Western digits and collapses
  /// punctuation to single spaces.
  static String fold(String input) {
    final lower = input.toLowerCase().replaceAll(_marks, '');
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final latin = _latin[ch];
      if (latin != null) {
        out.write(latin);
        continue;
      }
      out.writeCharCode(switch (rune) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 || 0x0672 || 0x0673 => 0x0627,
        0x0629 => 0x0647,
        0x0649 || 0x06CC || 0x06D2 => 0x064A,
        0x0624 => 0x0648,
        0x0626 => 0x064A,
        0x06A9 || 0x06AF => 0x0643,
        >= 0x0660 && <= 0x0669 => 0x30 + rune - 0x0660,
        >= 0x06F0 && <= 0x06F9 => 0x30 + rune - 0x06F0,
        _ => rune,
      });
    }
    return out.toString().replaceAll(_separators, ' ').trim();
  }

  /// [folded] split into words, without the Arabic article «ال» and Latin
  /// articles ("al", "az", "el"…) – "الزرقاء" and "Az Zarqa" both give
  /// `زرقاء` / `zarqa`.
  static List<String> words(String folded) {
    final raw = folded.split(' ').where((w) => w.isNotEmpty).toList();
    final out = <String>[];
    for (var i = 0; i < raw.length; i++) {
      var w = raw[i];
      if (raw.length > 1 && _latinArticles.contains(w)) continue;
      if (w.length > 3 && w.startsWith('ال')) w = w.substring(2);
      out.add(w);
    }
    return out.isEmpty ? raw : out;
  }

  /// Optimal-string-alignment edit distance, stopping early above [max].
  static int distance(String a, String b, {int max = 3}) {
    if ((a.length - b.length).abs() > max) return max + 1;
    final n = a.length, m = b.length;
    var prev2 = List<int>.filled(m + 1, 0);
    var prev = List<int>.generate(m + 1, (j) => j);
    var cur = List<int>.filled(m + 1, 0);
    for (var i = 1; i <= n; i++) {
      cur[0] = i;
      var rowMin = cur[0];
      for (var j = 1; j <= m; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var v = math.min(math.min(prev[j] + 1, cur[j - 1] + 1), prev[j - 1] + cost);
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          v = math.min(v, prev2[j - 2] + 1);
        }
        cur[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > max) return max + 1;
      final t = prev2;
      prev2 = prev;
      prev = cur;
      cur = t;
    }
    return prev[m];
  }
}

class _Entry {
  _Entry(this.city, this.names, this.words, this.squashed, this.country);

  final City city;

  /// Folded names (article-free words joined by a space).
  final List<String> names;

  /// Every word of every name.
  final Set<String> words;

  /// Names without spaces ("abudhabi").
  final List<String> squashed;

  /// Folded country names (ar, en).
  final List<String> country;
}

/// Scored city search (pure; built once per [CityDatabase]).
class CitySearchIndex {
  CitySearchIndex(List<City> cities, Map<String, ({String ar, String en})> countries)
    : _entries = [
        for (final c in cities)
          () {
            final names = <String>{};
            for (final raw in [c.nameAr, c.nameEn, ...c.aliases]) {
              final words = CityText.words(CityText.fold(raw));
              if (words.isNotEmpty) names.add(words.join(' '));
            }
            final country = countries[c.countryCode];
            return _Entry(
              c,
              names.toList(),
              {for (final n in names) ...n.split(' ')},
              [for (final n in names) n.replaceAll(' ', '')],
              [
                if (country != null) ...[
                  CityText.words(CityText.fold(country.ar)).join(' '),
                  CityText.words(CityText.fold(country.en)).join(' '),
                ],
              ],
            );
          }(),
      ];

  final List<_Entry> _entries;

  List<CityMatch> search(String query, {int limit = 40}) {
    final qWords = CityText.words(CityText.fold(query));
    if (qWords.isEmpty) return const [];
    final q = qWords.join(' ');
    final qSquashed = q.replaceAll(' ', '');
    final hits = <CityMatch>[];
    for (final e in _entries) {
      final s = _score(e, q, qSquashed, qWords);
      if (s <= 0) continue;
      final pop = e.city.population;
      final bonus = (pop > 0 ? math.log(pop) / math.ln10 : 3.0) + (e.city.capital ? 1.5 : 0);
      hits.add((city: e.city, score: s + bonus));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  static int _allowedTypos(int length) => length >= 8 ? 2 : (length >= 4 ? 1 : 0);

  double _score(_Entry e, String q, String qSquashed, List<String> qWords) {
    var best = 0.0;
    for (var i = 0; i < e.names.length; i++) {
      final n = e.names[i];
      final sq = e.squashed[i];
      double s;
      if (n == q || sq == qSquashed) {
        s = 100;
      } else if (n.startsWith(q) || sq.startsWith(qSquashed)) {
        s = 90 - math.min(10, n.length - q.length).toDouble();
      } else if (n.contains(q)) {
        s = 62;
      } else {
        s = 0;
      }
      if (s > best) best = s;
    }
    if (best >= 62) return best;

    // Every query word must start a name word (or be a close typo of one).
    var wordScore = 0.0;
    var allWords = true;
    for (final w in qWords) {
      var ws = 0.0;
      for (final nw in e.words) {
        if (nw == w) {
          ws = math.max(ws, 76);
        } else if (nw.startsWith(w)) {
          ws = math.max(ws, 72);
        } else {
          final allowed = _allowedTypos(w.length);
          if (allowed > 0) {
            final full = CityText.distance(w, nw, max: allowed);
            final prefix = nw.length > w.length
                ? CityText.distance(w, nw.substring(0, w.length), max: allowed)
                : allowed + 1;
            final d = math.min(full, prefix);
            if (d <= allowed) ws = math.max(ws, (full <= allowed ? 56 : 50) - 8.0 * d);
          }
        }
      }
      if (ws == 0) {
        allWords = false;
        break;
      }
      wordScore += ws;
    }
    if (allWords) best = math.max(best, wordScore / qWords.length);

    // Whole-name typo ("dubay", "ريض").
    final allowed = _allowedTypos(qSquashed.length);
    if (allowed > 0) {
      for (final sq in e.squashed) {
        final d = CityText.distance(qSquashed, sq, max: allowed);
        if (d <= allowed) best = math.max(best, 54 - 8.0 * d);
      }
    }
    if (best > 0) return best;

    // A country name lists its cities (lower rank).
    for (final c in e.country) {
      if (c.isEmpty) continue;
      if (c == q || c.startsWith(q) || c.replaceAll(' ', '').startsWith(qSquashed)) return 30;
    }
    return 0;
  }
}
