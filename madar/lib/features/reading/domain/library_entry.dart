/// One book in the reading planet's library (Part 17): where it comes from,
/// under which licence, and how big it is. Every field a catalogue needs to
/// prove "open source with a clear licence" is here, so the build-time
/// licence test (see `licence_policy.dart`) can check an entry on its own.
library;

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'book_direction.dart';

enum LibrarySourceKind {
  gutenberg,
  wikisource,
  kiwix,

  /// Shipped inside the app.
  bundled,

  /// A PDF he picked from his phone. Never uploaded, never exported.
  localPdf;

  static LibrarySourceKind parse(Object? value) {
    for (final k in values) {
      if (k.name == value) return k;
    }
    throw FormatException('Unknown sourceKind: $value');
  }

  /// Kinds that are fetched over the network, so need a size and a checksum.
  bool get isDownloadable => this == gutenberg || this == wikisource || this == kiwix;
}

/// One piece of a multi-part download of an entry: the entry's file is the
/// concatenation of its parts in order. [sha256] (lowercase hex) lets a
/// corrupt part be caught and refetched on its own.
@immutable
final class LibraryPart {
  const LibraryPart({required this.sizeBytes, this.sha256});

  final int sizeBytes;
  final String? sha256;

  Map<String, Object?> toJson() => {'sizeBytes': sizeBytes, if (sha256 != null) 'sha256': sha256};

  factory LibraryPart.fromJson(Map<String, Object?> json) =>
      LibraryPart(sizeBytes: _int(json['sizeBytes']), sha256: json['sha256'] as String?);

  @override
  bool operator ==(Object other) => other is LibraryPart && other.sizeBytes == sizeBytes && other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(sizeBytes, sha256);
}

@immutable
final class LibraryEntry {
  const LibraryEntry({
    required this.id,
    required this.title,
    this.authors = const [],
    this.language = '',
    required this.sourceKind,
    this.sourceUrl,
    this.licenceId = '',
    this.licenceUrl,
    this.credit = '',
    this.sizeBytes = 0,
    this.sha256,
    this.parts = const [],
    this.directionOverride,
  });

  final String id;
  final String title;
  final List<String> authors;

  /// BCP-47 tag; empty when the book has none (a PDF often does not).
  final String language;
  final LibrarySourceKind sourceKind;

  /// The page the book comes from (and the file it is fetched from when it is
  /// downloadable).
  final String? sourceUrl;

  /// Identifier from the licence allow-list (`licence_policy.dart`).
  final String licenceId;
  final String? licenceUrl;

  /// The attribution line shown on the book's own screen.
  final String credit;
  final int sizeBytes;

  /// Lowercase hex SHA-256 of the whole file.
  final String? sha256;
  final List<LibraryPart> parts;

  /// Set by hand when the language tag is missing or wrong; wins over it.
  final BookDirection? directionOverride;

  BookDirection get direction => bookDirectionOf(language, directionOverride: directionOverride);

  /// True for a PDF he added himself. Derived from the source kind (never
  /// stored) so a hand-edited JSON file cannot clear it.
  bool get deviceOnly => sourceKind == LibrarySourceKind.localPdf;

  LibraryEntry copyWith({
    String? title,
    List<String>? authors,
    String? language,
    BookDirection? directionOverride,
    bool clearDirectionOverride = false,
  }) => LibraryEntry(
    id: id,
    title: title ?? this.title,
    authors: authors ?? this.authors,
    language: language ?? this.language,
    sourceKind: sourceKind,
    sourceUrl: sourceUrl,
    licenceId: licenceId,
    licenceUrl: licenceUrl,
    credit: credit,
    sizeBytes: sizeBytes,
    sha256: sha256,
    parts: parts,
    directionOverride: clearDirectionOverride ? null : (directionOverride ?? this.directionOverride),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'authors': authors,
    'language': language,
    'sourceKind': sourceKind.name,
    if (sourceUrl != null) 'sourceUrl': sourceUrl,
    'licenceId': licenceId,
    if (licenceUrl != null) 'licenceUrl': licenceUrl,
    'credit': credit,
    'sizeBytes': sizeBytes,
    if (sha256 != null) 'sha256': sha256,
    if (parts.isNotEmpty) 'parts': [for (final p in parts) p.toJson()],
    if (directionOverride != null) 'directionOverride': directionOverride!.name,
  };

  factory LibraryEntry.fromJson(Map<String, Object?> json) {
    final dir = json['directionOverride'];
    return LibraryEntry(
      id: _str(json['id']),
      title: _str(json['title']),
      authors: [for (final a in (json['authors'] as List? ?? const [])) a as String],
      language: json['language'] as String? ?? '',
      sourceKind: LibrarySourceKind.parse(json['sourceKind']),
      sourceUrl: json['sourceUrl'] as String?,
      licenceId: json['licenceId'] as String? ?? '',
      licenceUrl: json['licenceUrl'] as String?,
      credit: json['credit'] as String? ?? '',
      sizeBytes: json['sizeBytes'] == null ? 0 : _int(json['sizeBytes']),
      sha256: json['sha256'] as String?,
      parts: [
        for (final p in (json['parts'] as List? ?? const [])) LibraryPart.fromJson((p as Map).cast<String, Object?>()),
      ],
      directionOverride: dir == null ? null : BookDirection.values.byName(dir as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LibraryEntry &&
      const DeepCollectionEquality().equals(toJson(), other.toJson());

  @override
  int get hashCode => Object.hash(id, title, sourceKind, licenceId, sizeBytes, sha256);
}

/// A catalogue file: `{"entries": [ ... ]}`.
abstract final class LibraryCatalogCodec {
  static List<LibraryEntry> decode(String source) {
    final root = jsonDecode(source);
    final list = root is Map ? root['entries'] : root;
    if (list is! List) throw const FormatException('Catalogue must hold an "entries" list');
    return [for (final e in list) LibraryEntry.fromJson((e as Map).cast<String, Object?>())];
  }

  static String encode(List<LibraryEntry> entries) =>
      jsonEncode({'entries': [for (final e in entries) e.toJson()]});
}

String _str(Object? v) {
  if (v is String) return v;
  throw FormatException('Expected a string, got $v');
}

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  throw FormatException('Expected an integer, got $v');
}
