import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_catalog.dart';
import '../domain/arabic_search.dart';
import '../domain/quran_meta.dart';
import '../domain/quran_text.dart';
import '../domain/tajweed.dart';

/// The bundled runtime files (see assets/quran/source/build_quran.py).
abstract final class QuranAssets {
  static const String dir = 'assets/quran/';
  static const String text = 'quran-uthmani.txt';
  static const String meta = 'quran-meta.json';
  static const String tajweed = 'quran-tajweed.txt';
}

/// Reads a bundled Quran file by name (tests read from disk).
abstract interface class QuranAssetSource {
  Future<String> read(String file);
}

/// The app bundle.
class BundleQuranAssetSource implements QuranAssetSource {
  const BundleQuranAssetSource([this.bundle]);

  final AssetBundle? bundle;

  // Not cached by the bundle: the store keeps the parsed form instead.
  @override
  Future<String> read(String file) => (bundle ?? rootBundle).loadString('${QuranAssets.dir}$file', cache: false);
}

/// Tajweed annotations per ayah (assets/quran/quran-tajweed.txt), decoded
/// on demand. Offsets index the verbatim line (basmala included).
class TajweedIndex {
  TajweedIndex._(this._encoded);

  factory TajweedIndex.parse(String source, QuranMeta meta) {
    final encoded = List<String>.filled(meta.ayahCount, '');
    var count = 0;
    for (final line in const LineSplitter().convert(source)) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final a = line.indexOf('|');
      final b = line.indexOf('|', a + 1);
      if (a < 0 || b < 0) throw FormatException('Bad tajweed line', line);
      final ref = AyahRef(int.parse(line.substring(0, a)), int.parse(line.substring(a + 1, b)));
      encoded[meta.indexOf(ref)] = line.substring(b + 1);
      count++;
    }
    if (count != meta.ayahCount) throw FormatException('Tajweed data covers $count ayat, expected ${meta.ayahCount}');
    return TajweedIndex._(encoded);
  }

  final List<String> _encoded;
  final Map<int, List<TajweedMark>> _cache = {};

  /// Marks of the whole line at absolute [index].
  List<TajweedMark> lineMarks(int index) => _cache.putIfAbsent(index, () => Tajweed.decode(_encoded[index]));
}

/// Loads and keeps the bundled Quran data. Structure (small) loads first;
/// the text (1.4 MB) and tajweed (0.5 MB) load lazily on first use.
class QuranStore {
  QuranStore(this._source);

  /// A store over already-parsed data (tests, previews).
  QuranStore.preloaded({required QuranMeta meta, QuranText? text, TajweedIndex? tajweed})
    : this._preloaded(null, meta, text, tajweed);

  QuranStore._preloaded(this._source, this._meta, this._text, this._tajweed);

  final QuranAssetSource? _source;
  QuranMeta? _meta;
  QuranText? _text;
  TajweedIndex? _tajweed;
  QuranSearchIndex? _search;
  Future<QuranMeta>? _metaLoading;
  Future<QuranText>? _textLoading;
  Future<TajweedIndex>? _tajweedLoading;

  QuranMeta? get loadedMeta => _meta;
  QuranText? get loadedText => _text;
  TajweedIndex? get loadedTajweed => _tajweed;

  Future<String> _read(String file) {
    final source = _source;
    if (source == null) throw StateError('Quran data $file was not preloaded');
    return source.read(file);
  }

  Future<QuranMeta> meta() {
    final m = _meta;
    if (m != null) return SynchronousFuture(m);
    return _metaLoading ??= _read(QuranAssets.meta).then((s) {
      final parsed = QuranMeta.fromJson((jsonDecode(s) as Map).cast<String, Object?>());
      return _meta = parsed;
    });
  }

  Future<QuranText> text() {
    final t = _text;
    if (t != null) return SynchronousFuture(t);
    return _textLoading ??= () async {
      final source = await _read(QuranAssets.text);
      return _text = QuranText.parse(source, await meta());
    }();
  }

  Future<TajweedIndex> tajweed() {
    final t = _tajweed;
    if (t != null) return SynchronousFuture(t);
    return _tajweedLoading ??= () async {
      final source = await _read(QuranAssets.tajweed);
      return _tajweed = TajweedIndex.parse(source, await meta());
    }();
  }

  /// The folded search index over every ayah (built once).
  Future<QuranSearchIndex> searchIndex() async {
    final s = _search;
    if (s != null) return s;
    final m = await meta();
    final t = await text();
    return _search ??= QuranSearchIndex(
      [for (var i = 0; i < m.ayahCount; i++) t.ayahText(i)],
      [for (var i = 0; i < m.ayahCount; i++) m.refAt(i)],
    );
  }
}

/// [QuranCatalog] over the bundled data.
class BundledQuranCatalog implements QuranCatalog {
  BundledQuranCatalog(this.store);

  final QuranStore store;

  QuranMeta get _m {
    final m = store.loadedMeta;
    if (m == null) throw StateError('QuranCatalog used before ensureLoaded()');
    return m;
  }

  @override
  Future<void> ensureLoaded() => store.meta();

  @override
  int get surahCount => QuranMeta.surahCount;

  @override
  int ayahCount(int surah) => _m.surah(surah).ayahCount;

  @override
  String surahName(int surah, {required bool arabic}) =>
      arabic ? _m.surah(surah).nameArabic : _m.surah(surah).nameEnglish;

  @override
  bool isMakki(int surah) => _m.surah(surah).makki;

  @override
  int pageOf(AyahRef ayah) => _m.pageOf(ayah);

  @override
  int juzOf(AyahRef ayah) => _m.juzOf(ayah);

  @override
  int hizbOf(AyahRef ayah) => _m.hizbOf(ayah);

  @override
  AyahRef pageStart(int page) => _m.pageStart(page);

  @override
  AyahRef juzStart(int juz) => _m.juzStart(juz);

  @override
  AyahRef hizbStart(int hizb) => _m.hizbStart(hizb);

  @override
  AyahRef? next(AyahRef ayah) => _m.next(ayah);

  @override
  AyahRef? previous(AyahRef ayah) => _m.previous(ayah);

  @override
  int countInRange(AyahRange range) => _m.countInRange(range);

  @override
  Future<String> ayahText(AyahRef ayah) async {
    final m = await store.meta();
    final t = await store.text();
    return t.ayahText(m.indexOf(ayah));
  }
}
