import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/quran/ayah.dart';
import '../domain/tajweed.dart';

/// A GET over HTTPS (the real one is dart:io; tests use recorded fixtures).
abstract interface class QuranHttp {
  /// Returns the status code and body; throws [QuranComException] with
  /// [QuranComProblem.offline] when the network cannot be reached.
  Future<(int, String)> get(Uri uri);
}

enum QuranComProblem {
  /// No connection / DNS / TLS / timeout.
  offline,

  /// The server answered with an error status.
  server,

  /// The answer was not what the API documents.
  format,
}

class QuranComException implements Exception {
  const QuranComException(this.problem, [this.detail]);

  final QuranComProblem problem;
  final String? detail;

  @override
  String toString() => 'QuranComException(${problem.name}${detail == null ? '' : ': $detail'})';
}

/// dart:io [QuranHttp].
class IoQuranHttp implements QuranHttp {
  IoQuranHttp({this.timeout = const Duration(seconds: 25), HttpClient Function()? client})
    : _client = client ?? HttpClient.new;

  final Duration timeout;
  final HttpClient Function() _client;

  @override
  Future<(int, String)> get(Uri uri) async {
    final client = _client()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      final body = await response.transform(utf8.decoder).join().timeout(timeout);
      return (response.statusCode, body);
    } on SocketException catch (e) {
      throw QuranComException(QuranComProblem.offline, e.message);
    } on HandshakeException catch (e) {
      throw QuranComException(QuranComProblem.offline, e.message);
    } on TimeoutException {
      throw const QuranComException(QuranComProblem.offline, 'timeout');
    } on HttpException catch (e) {
      throw QuranComException(QuranComProblem.offline, e.message);
    } finally {
      client.close(force: true);
    }
  }
}

/// Where downloaded Quran.com answers are kept (raw JSON, by key).
abstract interface class QuranCacheStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<Set<String>> keys();
  Future<int> sizeBytes();
  Future<void> clear();
}

/// Files in the app-support folder `quran_cache/`.
class FileQuranCacheStore implements QuranCacheStore {
  FileQuranCacheStore([Future<Directory> Function()? dir]) : _dir = dir ?? _defaultDir;

  static Future<Directory> _defaultDir() async =>
      Directory(p.join((await getApplicationSupportDirectory()).path, 'quran_cache'));

  final Future<Directory> Function() _dir;

  static final RegExp _safe = RegExp(r'^[a-z0-9._-]+$');

  Future<File> _file(String key) async {
    if (!_safe.hasMatch(key)) throw ArgumentError.value(key, 'key');
    return File(p.join((await _dir()).path, '$key.json'));
  }

  @override
  Future<String?> read(String key) async {
    final f = await _file(key);
    return await f.exists() ? f.readAsString() : null;
  }

  @override
  Future<void> write(String key, String value) async {
    final f = await _file(key);
    await f.parent.create(recursive: true);
    // Write-then-rename so a crash never leaves half a file.
    final tmp = File('${f.path}.part');
    await tmp.writeAsString(value, flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<Set<String>> keys() async {
    final d = await _dir();
    if (!await d.exists()) return {};
    return {
      await for (final e in d.list())
        if (e is File && e.path.endsWith('.json')) p.basenameWithoutExtension(e.path),
    };
  }

  @override
  Future<int> sizeBytes() async {
    final d = await _dir();
    if (!await d.exists()) return 0;
    var total = 0;
    await for (final e in d.list()) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  @override
  Future<void> clear() async {
    final d = await _dir();
    if (await d.exists()) await d.delete(recursive: true);
  }
}

/// In memory (tests).
class MemoryQuranCacheStore implements QuranCacheStore {
  final Map<String, String> entries = {};

  @override
  Future<String?> read(String key) async => entries[key];

  @override
  Future<void> write(String key, String value) async => entries[key] = value;

  @override
  Future<Set<String>> keys() async => entries.keys.toSet();

  @override
  Future<int> sizeBytes() async => entries.values.fold<int>(0, (a, v) => a + utf8.encode(v).length);

  @override
  Future<void> clear() async => entries.clear();
}

/// A downloaded translation of some ayat.
@immutable
class QuranTranslation {
  const QuranTranslation({required this.resourceId, required this.name, required this.verses});

  final int resourceId;

  /// E.g. "Saheeh International" (from the API's meta, when given).
  final String? name;

  /// Plain text per ayah (footnote markers removed).
  final Map<AyahRef, String> verses;
}

/// Quran.com API v4 (https://api.quran.com/api/v4), used ONLY on an
/// explicit user action (a download button); every answer is kept on disk
/// and read back offline. Endpoints (documented shapes, recorded in
/// test/features/quran/fixtures/):
///
/// * `GET /quran/verses/uthmani_tajweed?chapter_number=N` (or
///   `page_number=N`) → verses with `verse_key` and `text_uthmani_tajweed`
///   (rules as `tajweed` elements with a class, the ayah number in a
///   `span` of class `end`).
/// * `GET /quran/translations/{id}?chapter_number=N&fields=verse_key` (or
///   `page_number=N`) → `{"translations":[{"resource_id":20,
///   "verse_key":"1:1","text":"…<sup foot_note=1>1</sup>"}],
///   "meta":{"translation_name":"…"}}` (ayat in order when `verse_key` is
///   absent).
class QuranComClient {
  QuranComClient({required this.http, required this.cache, Uri? base})
    : base = base ?? Uri.parse('https://api.quran.com/api/v4/');

  final QuranHttp http;
  final QuranCacheStore cache;
  final Uri base;

  static String tajweedKey(int surah) => 'tajweed-s$surah';
  static String translationKey(int id, int surah) => 'translation-$id-s$surah';
  static String tajweedPageKey(int page) => 'tajweed-p$page';
  static String translationPageKey(int id, int page) => 'translation-$id-p$page';

  Uri tajweedUri({int? surah, int? page}) => base.resolveUri(
    Uri(
      path: 'quran/verses/uthmani_tajweed',
      queryParameters: {'chapter_number': ?surah?.toString(), 'page_number': ?page?.toString()},
    ),
  );

  Uri translationUri(int id, {int? surah, int? page}) => base.resolveUri(
    Uri(
      path: 'quran/translations/$id',
      queryParameters: {
        'chapter_number': ?surah?.toString(),
        'page_number': ?page?.toString(),
        'fields': 'verse_key',
      },
    ),
  );

  Future<String> _fetch(Uri uri) async {
    final (status, body) = await http.get(uri);
    if (status != 200) throw QuranComException(QuranComProblem.server, 'HTTP $status');
    return body;
  }

  // ------------------------------------------------------------- tajweed

  /// Downloads a sura's tajweed text (network), validates it against
  /// [expectedAyat] (in order 1…N) and caches it.
  Future<Map<AyahRef, TajweedText>> downloadTajweed(int surah, {required List<AyahRef> expectedAyat}) async {
    final body = await _fetch(tajweedUri(surah: surah));
    final parsed = parseTajweed(body, expectedAyat);
    await cache.write(tajweedKey(surah), body);
    return parsed;
  }

  /// The cached tajweed of a sura, or null (never touches the network).
  Future<Map<AyahRef, TajweedText>?> cachedTajweed(int surah, {required List<AyahRef> expectedAyat}) async {
    final body = await cache.read(tajweedKey(surah));
    if (body == null) return null;
    try {
      return parseTajweed(body, expectedAyat);
    } on QuranComException {
      return null;
    }
  }

  /// Downloads the tajweed text of a mushaf page.
  Future<Map<AyahRef, TajweedText>> downloadTajweedPage(int page, {required List<AyahRef> expectedAyat}) async {
    final body = await _fetch(tajweedUri(page: page));
    final parsed = parseTajweed(body, expectedAyat);
    await cache.write(tajweedPageKey(page), body);
    return parsed;
  }

  // --------------------------------------------------------- translation

  Future<QuranTranslation> downloadTranslation(int surah, {required int id, required List<AyahRef> expectedAyat}) async {
    final body = await _fetch(translationUri(id, surah: surah));
    final parsed = parseTranslation(body, id, expectedAyat);
    await cache.write(translationKey(id, surah), body);
    return parsed;
  }

  Future<QuranTranslation?> cachedTranslation(int surah, {required int id, required List<AyahRef> expectedAyat}) async {
    final body = await cache.read(translationKey(id, surah));
    if (body == null) return null;
    try {
      return parseTranslation(body, id, expectedAyat);
    } on QuranComException {
      return null;
    }
  }

  Future<QuranTranslation> downloadTranslationPage(int page, {required int id, required List<AyahRef> expectedAyat}) async {
    final body = await _fetch(translationUri(id, page: page));
    final parsed = parseTranslation(body, id, expectedAyat);
    await cache.write(translationPageKey(id, page), body);
    return parsed;
  }

  /// Suras whose translation [id] is on disk.
  Future<Set<int>> cachedTranslationSurahs(int id) async {
    final prefix = 'translation-$id-s';
    return {
      for (final k in await cache.keys())
        if (k.startsWith(prefix)) ?int.tryParse(k.substring(prefix.length)),
    };
  }

  /// Suras whose Quran.com tajweed text is on disk.
  Future<Set<int>> cachedTajweedSurahs() async => {
    for (final k in await cache.keys())
      if (k.startsWith('tajweed-s')) ?int.tryParse(k.substring('tajweed-s'.length)),
  };

  // -------------------------------------------------------------- parsing

  static Map<String, Object?> _object(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) return json.cast<String, Object?>();
    } on FormatException {
      // fall through
    }
    throw const QuranComException(QuranComProblem.format, 'not a JSON object');
  }

  static List<Map<String, Object?>> _list(Map<String, Object?> json, String key) {
    final list = json[key];
    if (list is! List) throw QuranComException(QuranComProblem.format, 'no "$key" list');
    return [
      for (final e in list)
        if (e is Map) e.cast<String, Object?>() else throw QuranComException(QuranComProblem.format, 'bad $key item'),
    ];
  }

  static AyahRef? _key(Object? v) => v is String ? AyahRef.tryParse(v) : null;

  /// Parses a `uthmani_tajweed` answer; the verses must be exactly
  /// [expected], in order.
  static Map<AyahRef, TajweedText> parseTajweed(String body, List<AyahRef> expected) {
    final verses = _list(_object(body), 'verses');
    if (verses.length != expected.length) {
      throw QuranComException(QuranComProblem.format, '${verses.length} verses, expected ${expected.length}');
    }
    final out = <AyahRef, TajweedText>{};
    for (var i = 0; i < verses.length; i++) {
      final v = verses[i];
      final ref = _key(v['verse_key']) ?? expected[i];
      final markup = v['text_uthmani_tajweed'];
      if (ref != expected[i] || markup is! String || markup.trim().isEmpty) {
        throw QuranComException(QuranComProblem.format, 'verse ${i + 1}');
      }
      out[ref] = Tajweed.parseQuranCom(markup);
    }
    return out;
  }

  /// Parses a translation answer (footnote markers and tags removed).
  static QuranTranslation parseTranslation(String body, int id, List<AyahRef> expected) {
    final json = _object(body);
    final items = _list(json, 'translations');
    if (items.length != expected.length) {
      throw QuranComException(QuranComProblem.format, '${items.length} translations, expected ${expected.length}');
    }
    final verses = <AyahRef, String>{};
    for (var i = 0; i < items.length; i++) {
      final t = items[i];
      final ref = _key(t['verse_key']) ?? expected[i];
      final text = t['text'];
      if (ref != expected[i] || text is! String) throw QuranComException(QuranComProblem.format, 'translation ${i + 1}');
      verses[ref] = cleanTranslation(text);
    }
    final meta = json['meta'];
    final name = meta is Map ? meta['translation_name'] : null;
    return QuranTranslation(resourceId: id, name: name is String ? name : null, verses: verses);
  }

  static final RegExp _spaces = RegExp(r'\s+');

  /// Translation text without footnote markers / tags, whitespace tidied.
  static String cleanTranslation(String text) =>
      Tajweed.stripMarkup(text).replaceAll(_spaces, ' ').replaceAll(' ,', ',').replaceAll(' .', '.').trim();
}
