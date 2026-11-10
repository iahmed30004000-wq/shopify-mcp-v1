// A QuranCatalog for tests: the real mushaf structure (ayah counts, Madani
// page / juz / hizb starts, Makki flags) and a small sample of the Tanzil
// Uthmani text, read synchronously from fixtures (works in fake-async widget
// tests). The real catalog is implemented by lib/features/quran.
import 'dart:convert';
import 'dart:io';

import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_catalog.dart';

class FakeQuranCatalog implements QuranCatalog {
  FakeQuranCatalog._(
    this._counts,
    this._namesAr,
    this._namesEn,
    this._makki,
    this._pages,
    this._juz,
    this._hizb,
    this._text,
  ) : _prefix = List<int>.filled(115, 0) {
    for (var s = 1; s <= 114; s++) {
      _prefix[s] = _prefix[s - 1] + _counts[s - 1];
    }
  }

  factory FakeQuranCatalog() => _instance ??= _load();

  static FakeQuranCatalog? _instance;

  static const _dir = 'test/features/wird/fixtures';

  static FakeQuranCatalog _load() {
    final json = jsonDecode(File('$_dir/quran_structure.json').readAsStringSync()) as Map<String, dynamic>;
    List<AyahRef> refs(String key) => [for (final p in json[key] as List) AyahRef((p as List)[0] as int, p[1] as int)];
    final text = <AyahRef, String>{};
    final lines = File('$_dir/quran_sample.txt').readAsLinesSync();
    // The basmala exactly as the text spells it (Al-Fatihah 1).
    final basmala = '${lines.firstWhere((l) => l.startsWith('1|1|')).split('|')[2]} ';
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length != 3) continue;
      final s = int.tryParse(parts[0]), a = int.tryParse(parts[1]);
      if (s == null || a == null) continue;
      var t = parts[2];
      // The reader shows the basmala as a header, not as part of ayah 1.
      if (s != 1 && a == 1 && t.startsWith(basmala)) t = t.substring(basmala.length);
      text[AyahRef(s, a)] = t;
    }
    return FakeQuranCatalog._(
      (json['ayahCounts'] as List).cast<int>(),
      (json['namesAr'] as List).cast<String>(),
      (json['namesEn'] as List).cast<String>(),
      (json['makki'] as List).cast<bool>(),
      refs('pageStarts'),
      refs('juzStarts'),
      refs('hizbStarts'),
      text,
    );
  }

  final List<int> _counts;
  final List<String> _namesAr, _namesEn;
  final List<bool> _makki;
  final List<AyahRef> _pages, _juz, _hizb;
  final Map<AyahRef, String> _text;
  final List<int> _prefix;

  /// Ayat whose text is in the sample.
  Iterable<AyahRef> get sampled => _text.keys;

  int _index(AyahRef a) => _prefix[a.surah - 1] + a.ayah - 1;

  AyahRef _at(int i) {
    var s = 1;
    while (_prefix[s] <= i) {
      s++;
    }
    return AyahRef(s, i - _prefix[s - 1] + 1);
  }

  int _unitOf(List<AyahRef> starts, AyahRef a) {
    var k = 0;
    for (var i = 0; i < starts.length; i++) {
      if (starts[i] <= a) k = i;
    }
    return k + 1;
  }

  @override
  int get surahCount => 114;

  @override
  int ayahCount(int surah) => _counts[surah - 1];

  @override
  String surahName(int surah, {required bool arabic}) => arabic ? _namesAr[surah - 1] : _namesEn[surah - 1];

  @override
  bool isMakki(int surah) => _makki[surah - 1];

  @override
  int pageOf(AyahRef ayah) => _unitOf(_pages, ayah);

  @override
  int juzOf(AyahRef ayah) => _unitOf(_juz, ayah);

  @override
  int hizbOf(AyahRef ayah) => _unitOf(_hizb, ayah);

  @override
  AyahRef pageStart(int page) => _pages[page - 1];

  @override
  AyahRef juzStart(int juz) => _juz[juz - 1];

  @override
  AyahRef hizbStart(int hizb) => _hizb[hizb - 1];

  @override
  AyahRef? next(AyahRef ayah) {
    final i = _index(ayah) + 1;
    return i >= 6236 ? null : _at(i);
  }

  @override
  AyahRef? previous(AyahRef ayah) {
    final i = _index(ayah) - 1;
    return i < 0 ? null : _at(i);
  }

  @override
  int countInRange(AyahRange range) => _index(range.last) - _index(range.first) + 1;

  @override
  Future<String> ayahText(AyahRef ayah) async {
    final t = _text[ayah];
    if (t == null) throw StateError('FakeQuranCatalog: no sample text for $ayah');
    return t;
  }

  @override
  Future<void> ensureLoaded() async {}
}
