import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';

/// The adhkar sets Madar ships (Hisn al-Muslim chapters).
enum AdhkarCategoryId {
  morning,
  evening,
  afterPrayer,
  sleep,
  waking;

  static AdhkarCategoryId? tryParse(Object? name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}

/// The obligatory prayers an after-prayer set can follow.
const List<Prayer> kObligatoryPrayers = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha];

/// Text carried in both app languages. [en] is optional: a dhikr without an
/// openly licensed translation shows its Arabic in both languages.
@immutable
class LocalizedText {
  const LocalizedText(this.ar, [this.en]);

  final String ar;
  final String? en;

  /// The text for [languageCode], falling back to Arabic.
  String of(String languageCode) => languageCode == 'en' && (en?.isNotEmpty ?? false) ? en! : ar;

  bool get hasEnglish => en?.isNotEmpty ?? false;

  static LocalizedText? fromJson(Object? json, String path) {
    if (json == null) return null;
    if (json is! Map) throw AdhkarFormatException('$path: expected an object');
    final ar = json['ar'];
    final en = json['en'];
    if (ar is! String || ar.trim().isEmpty) throw AdhkarFormatException('$path.ar: missing Arabic text');
    if (en != null && en is! String) throw AdhkarFormatException('$path.en: expected a string');
    return LocalizedText(ar, en as String?);
  }

  @override
  bool operator ==(Object other) => other is LocalizedText && other.ar == ar && other.en == en;

  @override
  int get hashCode => Object.hash(ar, en);
}

/// One piece of a dhikr: words said as they are, or Quran verses.
@immutable
sealed class DhikrSegment {
  const DhikrSegment();

  /// The segment's words (verses joined by a space).
  String get plainText;
}

/// Words of remembrance (fully vowelled Arabic).
final class DhikrTextSegment extends DhikrSegment {
  const DhikrTextSegment(this.text);

  final String text;

  @override
  String get plainText => text;
}

/// Consecutive Quran verses [firstAyah]…[lastAyah] of [surah], one string
/// per verse (the imla'i, fully vowelled reference text).
final class DhikrQuranSegment extends DhikrSegment {
  const DhikrQuranSegment({required this.surah, required this.firstAyah, required this.lastAyah, required this.verses});

  final int surah;
  final int firstAyah;
  final int lastAyah;
  final List<String> verses;

  /// The ayah number of `verses[i]`.
  int ayahAt(int i) => firstAyah + i;

  @override
  String get plainText => verses.join(' ');
}

/// How a dhikr is performed.
enum DhikrKind {
  /// Said [Dhikr.count] times (the counter ring counts).
  recite,

  /// Whole surahs to read (a single "done" tap).
  reading,
}

/// One dhikr of a set.
@immutable
class Dhikr {
  const Dhikr({
    required this.id,
    required this.segments,
    required this.count,
    required this.reference,
    this.countAfter = const {},
    this.onlyAfter = const {},
    this.note,
    this.virtue,
    this.translationEn,
    this.kind = DhikrKind.recite,
    this.origin,
  });

  /// Stable id, e.g. `morning.05`.
  final String id;
  final List<DhikrSegment> segments;

  /// Times to say it.
  final int count;

  /// A different count after particular prayers (e.g. the three surahs
  /// three times after Fajr and Maghrib).
  final Map<Prayer, int> countAfter;

  /// Said only after these prayers (empty = after every prayer).
  final Set<Prayer> onlyAfter;

  /// When / how to say it.
  final LocalizedText? note;

  /// Its virtue from the hadith.
  final LocalizedText? virtue;

  /// Hadith source.
  final LocalizedText reference;

  /// English meaning (only when openly licensed with the text).
  final String? translationEn;
  final DhikrKind kind;

  /// Where the entry came from (dataset + index), for audits.
  final String? origin;

  /// All the words, verses included.
  String get plainText => segments.map((s) => s.plainText).join(' ');

  bool get hasQuran => segments.any((s) => s is DhikrQuranSegment);

  Iterable<DhikrQuranSegment> get quranSegments => segments.whereType<DhikrQuranSegment>();

  /// Times to say it after [prayer] (null = not tied to a prayer).
  int countFor(Prayer? prayer) => prayer == null ? count : (countAfter[prayer] ?? count);

  /// Whether it belongs to the set said after [prayer].
  bool appliesAfter(Prayer? prayer) => onlyAfter.isEmpty || prayer == null || onlyAfter.contains(prayer);

  static Dhikr fromJson(Object? json, String path) {
    if (json is! Map) throw AdhkarFormatException('$path: expected an object');
    final id = json['id'];
    if (id is! String || id.isEmpty) throw AdhkarFormatException('$path.id: missing');
    final p = '$path($id)';
    final rawSegments = json['segments'];
    if (rawSegments is! List || rawSegments.isEmpty) throw AdhkarFormatException('$p.segments: empty');
    final segments = <DhikrSegment>[
      for (var i = 0; i < rawSegments.length; i++) _segment(rawSegments[i], '$p.segments[$i]'),
    ];
    final count = json['count'];
    if (count is! int || count < 1) throw AdhkarFormatException('$p.count: must be ≥ 1');
    final reference = LocalizedText.fromJson(json['reference'], '$p.reference');
    if (reference == null) throw AdhkarFormatException('$p.reference: missing');
    final countAfter = <Prayer, int>{};
    final rawAfter = json['countAfter'];
    if (rawAfter != null) {
      if (rawAfter is! Map) throw AdhkarFormatException('$p.countAfter: expected an object');
      for (final e in rawAfter.entries) {
        final prayer = _prayer(e.key, '$p.countAfter');
        final v = e.value;
        if (v is! int || v < 1) throw AdhkarFormatException('$p.countAfter.${e.key}: must be ≥ 1');
        countAfter[prayer] = v;
      }
    }
    final onlyAfter = <Prayer>{};
    final rawOnly = json['onlyAfter'];
    if (rawOnly != null) {
      if (rawOnly is! List || rawOnly.isEmpty) throw AdhkarFormatException('$p.onlyAfter: expected a list');
      for (final v in rawOnly) {
        onlyAfter.add(_prayer(v, '$p.onlyAfter'));
      }
    }
    final translation = json['translation'];
    String? en;
    if (translation != null) {
      if (translation is! Map || translation['en'] is! String || (translation['en'] as String).trim().isEmpty) {
        throw AdhkarFormatException('$p.translation: expected {"en": "…"}');
      }
      en = translation['en'] as String;
    }
    final kindName = json['kind'];
    final kind = kindName == null
        ? DhikrKind.recite
        : DhikrKind.values.where((k) => k.name == kindName).firstOrNull ??
              (throw AdhkarFormatException('$p.kind: unknown "$kindName"'));
    return Dhikr(
      id: id,
      segments: List.unmodifiable(segments),
      count: count,
      countAfter: Map.unmodifiable(countAfter),
      onlyAfter: Set.unmodifiable(onlyAfter),
      note: LocalizedText.fromJson(json['note'], '$p.note'),
      virtue: LocalizedText.fromJson(json['virtue'], '$p.virtue'),
      reference: reference,
      translationEn: en,
      kind: kind,
      origin: json['origin'] as String?,
    );
  }

  static Prayer _prayer(Object? name, String path) {
    final p = kObligatoryPrayers.where((p) => p.name == name).firstOrNull;
    if (p == null) throw AdhkarFormatException('$path: "$name" is not an obligatory prayer');
    return p;
  }

  static DhikrSegment _segment(Object? json, String path) {
    if (json is! Map) throw AdhkarFormatException('$path: expected an object');
    if (json.containsKey('text')) {
      final text = json['text'];
      if (text is! String || text.trim().isEmpty) throw AdhkarFormatException('$path.text: empty');
      return DhikrTextSegment(text);
    }
    final surah = json['surah'];
    final ayahs = json['ayahs'];
    final verses = json['verses'];
    if (surah is! int || surah < 1 || surah > 114) throw AdhkarFormatException('$path.surah: 1…114');
    if (ayahs is! List || ayahs.length != 2 || ayahs.any((a) => a is! int || a < 1)) {
      throw AdhkarFormatException('$path.ayahs: expected [first, last]');
    }
    final first = ayahs[0] as int, last = ayahs[1] as int;
    if (last < first) throw AdhkarFormatException('$path.ayahs: last before first');
    if (verses is! List || verses.length != last - first + 1) {
      throw AdhkarFormatException('$path.verses: expected ${last - first + 1} verses');
    }
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      if (v is! String || v.trim().isEmpty) throw AdhkarFormatException('$path.verses[$i]: empty');
    }
    return DhikrQuranSegment(
      surah: surah,
      firstAyah: first,
      lastAyah: last,
      verses: List.unmodifiable(verses.cast<String>()),
    );
  }
}

/// A set of adhkar (one Hisn al-Muslim chapter).
@immutable
class AdhkarCategory {
  const AdhkarCategory({required this.id, required this.items});

  final AdhkarCategoryId id;
  final List<Dhikr> items;

  /// The items said after [prayer] (every item when null or when the set is
  /// not the after-prayer set).
  List<Dhikr> itemsFor(Prayer? prayer) => id == AdhkarCategoryId.afterPrayer && prayer != null
      ? [
          for (final d in items)
            if (d.appliesAfter(prayer)) d,
        ]
      : items;
}

/// Where the content came from (shown on the About page and in credits).
@immutable
class AdhkarSource {
  const AdhkarSource({required this.id, required this.url, required this.commit, required this.license});

  final String id;
  final String url;
  final String commit;
  final String license;
}

/// The whole bundled library.
@immutable
class AdhkarLibrary {
  const AdhkarLibrary({required this.title, required this.author, required this.sources, required this.categories});

  static const int schemaVersion = 1;

  final LocalizedText title;
  final LocalizedText author;
  final List<AdhkarSource> sources;
  final List<AdhkarCategory> categories;

  AdhkarCategory category(AdhkarCategoryId id) => categories.firstWhere((c) => c.id == id);

  Dhikr? dhikrById(String id) {
    for (final c in categories) {
      for (final d in c.items) {
        if (d.id == id) return d;
      }
    }
    return null;
  }

  Iterable<Dhikr> get allDhikr => categories.expand((c) => c.items);

  /// Parses and validates the bundled JSON. Throws [AdhkarFormatException]
  /// naming the offending path.
  static AdhkarLibrary fromJson(Object? json) {
    if (json is! Map) throw const AdhkarFormatException('root: expected an object');
    if (json['schema'] != schemaVersion) throw AdhkarFormatException('schema: expected $schemaVersion');
    final title = LocalizedText.fromJson(json['title'], 'title');
    final author = LocalizedText.fromJson(json['author'], 'author');
    if (title == null || author == null) throw const AdhkarFormatException('title/author: missing');
    final rawSources = json['sources'];
    if (rawSources is! List || rawSources.isEmpty) throw const AdhkarFormatException('sources: empty');
    final sources = <AdhkarSource>[
      for (final s in rawSources)
        if (s is Map && s['id'] is String && s['url'] is String && s['license'] is String)
          AdhkarSource(
            id: s['id'] as String,
            url: s['url'] as String,
            commit: '${s['commit'] ?? ''}',
            license: s['license'] as String,
          )
        else
          throw const AdhkarFormatException('sources: each needs id, url and license'),
    ];
    final rawCats = json['categories'];
    if (rawCats is! List) throw const AdhkarFormatException('categories: expected a list');
    final ids = <String>{};
    final cats = <AdhkarCategory>[];
    for (var i = 0; i < rawCats.length; i++) {
      final c = rawCats[i];
      if (c is! Map) throw AdhkarFormatException('categories[$i]: expected an object');
      final id = AdhkarCategoryId.tryParse(c['id']);
      if (id == null) throw AdhkarFormatException('categories[$i].id: unknown "${c['id']}"');
      final rawItems = c['items'];
      if (rawItems is! List || rawItems.isEmpty) throw AdhkarFormatException('${id.name}.items: empty');
      final items = <Dhikr>[];
      for (var j = 0; j < rawItems.length; j++) {
        final d = Dhikr.fromJson(rawItems[j], '${id.name}[$j]');
        if (!ids.add(d.id)) throw AdhkarFormatException('${id.name}[$j]: duplicate id ${d.id}');
        items.add(d);
      }
      cats.add(AdhkarCategory(id: id, items: List.unmodifiable(items)));
    }
    for (final id in AdhkarCategoryId.values) {
      if (!cats.any((c) => c.id == id)) throw AdhkarFormatException('categories: missing ${id.name}');
    }
    return AdhkarLibrary(
      title: title,
      author: author,
      sources: List.unmodifiable(sources),
      categories: List.unmodifiable(cats),
    );
  }
}

/// The bundled adhkar JSON is malformed.
class AdhkarFormatException implements Exception {
  const AdhkarFormatException(this.message);

  final String message;

  @override
  String toString() => 'AdhkarFormatException: $message';
}
