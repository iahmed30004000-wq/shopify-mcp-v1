import 'package:flutter/foundation.dart';

/// One hadith of a bundled collection (Arabic text).
@immutable
class HadithEntry {
  const HadithEntry({
    required this.number,
    required this.titleAr,
    required this.titleEn,
    required this.text,
    this.takhrij = '',
  });

  factory HadithEntry.fromJson(Map<String, Object?> json) {
    final title = json['title'];
    return HadithEntry(
      number: (json['n'] as num).toInt(),
      titleAr: title is Map ? '${title['ar'] ?? ''}' : '',
      titleEn: title is Map ? '${title['en'] ?? ''}' : '',
      text: '${json['text'] ?? ''}',
      takhrij: '${json['takhrij'] ?? ''}',
    );
  }

  final int number;
  final String titleAr;
  final String titleEn;

  /// The narration (with its isnad opening), Arabic.
  final String text;

  /// Who recorded it and its grading (`رواه البخاري ومسلم.`).
  final String takhrij;

  String title({required bool arabic}) => arabic || titleEn.isEmpty ? titleAr : titleEn;
}

/// A bundled hadith collection (`assets/hadith/*.json`).
@immutable
class HadithCollection {
  const HadithCollection({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.entries,
    this.compilerAr = '',
    this.compilerEn = '',
    this.source = '',
    this.license = '',
  });

  factory HadithCollection.fromJson(Map<String, Object?> json) {
    final title = json['title'] as Map;
    final compiler = json['compiler'];
    return HadithCollection(
      id: json['id'] as String,
      titleAr: '${title['ar']}',
      titleEn: '${title['en']}',
      compilerAr: compiler is Map ? '${compiler['ar'] ?? ''}' : '',
      compilerEn: compiler is Map ? '${compiler['en'] ?? ''}' : '',
      source: '${json['source'] ?? ''}',
      license: '${json['license'] ?? ''}',
      entries: [for (final h in json['hadiths'] as List) HadithEntry.fromJson((h as Map).cast<String, Object?>())],
    );
  }

  /// The bundled An-Nawawi's Forty (42 hadith).
  static const String nawawiAsset = 'assets/hadith/nawawi40.json';

  final String id;
  final String titleAr;
  final String titleEn;
  final String compilerAr;
  final String compilerEn;
  final String source;
  final String license;
  final List<HadithEntry> entries;

  String title({required bool arabic}) => arabic ? titleAr : titleEn;

  /// The `source` stored on a Hifz item: `nawawi40:12`.
  String keyOf(HadithEntry e) => '$id:${e.number}';

  /// The entry a stored `source` points to (null when it is not ours).
  HadithEntry? byKey(String? key) {
    if (key == null) return null;
    final i = key.indexOf(':');
    if (i < 0 || key.substring(0, i) != id) return null;
    final n = int.tryParse(key.substring(i + 1));
    for (final e in entries) {
      if (e.number == n) return e;
    }
    return null;
  }

  /// Problems with the data (empty when valid): numbering 1…N without gaps,
  /// Arabic text present, no leftover markup, titles in both languages.
  List<String> validate() {
    final problems = <String>[];
    final arabic = RegExp('[ء-ي]');
    final markup = RegExp(r'[<>\[\]"]|&[a-z]+;');
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (e.number != i + 1) problems.add('hadith ${e.number}: expected number ${i + 1}');
      if (!arabic.hasMatch(e.text)) problems.add('hadith ${e.number}: no Arabic text');
      if (markup.hasMatch(e.text) || markup.hasMatch(e.takhrij)) problems.add('hadith ${e.number}: markup left');
      if (RegExp(r'\s{2,}').hasMatch(e.text)) problems.add('hadith ${e.number}: double spaces');
      if (e.titleAr.trim().isEmpty || e.titleEn.trim().isEmpty) problems.add('hadith ${e.number}: missing title');
    }
    return problems;
  }
}
