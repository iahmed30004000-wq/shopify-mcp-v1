/// Where he stopped, bookmarks, and highlights (Part 17). Pure, immutable,
/// JSON round-trippable; the integrator stores the JSON (or maps the fields to
/// tables) and nothing here knows how.
library;

import 'package:meta/meta.dart';

/// The exact place he stopped in a book. [page] is the zero-based page index
/// the reader shows; [scrollOffsetFraction] (0..1) is how far down a tall page
/// (a PDF page zoomed in, a long web article) he had scrolled.
@immutable
final class ReadingPosition {
  ReadingPosition({
    required this.bookId,
    required this.page,
    double scrollOffsetFraction = 0,
    required this.updatedAt,
  }) : scrollOffsetFraction = scrollOffsetFraction.isNaN ? 0 : scrollOffsetFraction.clamp(0.0, 1.0),
       assert(page >= 0, 'page is zero-based');

  final String bookId;
  final int page;
  final double scrollOffsetFraction;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'bookId': bookId,
    'page': page,
    'scrollOffsetFraction': scrollOffsetFraction,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ReadingPosition.fromJson(Map<String, Object?> json) => ReadingPosition(
    bookId: json['bookId'] as String,
    page: (json['page'] as num).toInt(),
    scrollOffsetFraction: (json['scrollOffsetFraction'] as num? ?? 0).toDouble(),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition &&
      other.bookId == bookId &&
      other.page == page &&
      other.scrollOffsetFraction == scrollOffsetFraction &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(bookId, page, scrollOffsetFraction, updatedAt);
}

@immutable
final class Bookmark {
  Bookmark({
    required this.id,
    required this.bookId,
    required this.page,
    double scrollOffsetFraction = 0,
    this.label,
    required this.createdAt,
  }) : scrollOffsetFraction = scrollOffsetFraction.isNaN ? 0 : scrollOffsetFraction.clamp(0.0, 1.0);

  final String id;
  final String bookId;
  final int page;
  final double scrollOffsetFraction;

  /// His own words, if he gave one; never generated.
  final String? label;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'bookId': bookId,
    'page': page,
    'scrollOffsetFraction': scrollOffsetFraction,
    if (label != null) 'label': label,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Bookmark.fromJson(Map<String, Object?> json) => Bookmark(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    page: (json['page'] as num).toInt(),
    scrollOffsetFraction: (json['scrollOffsetFraction'] as num? ?? 0).toDouble(),
    label: json['label'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  @override
  bool operator ==(Object other) => other is Bookmark && other.id == id && other.page == page && other.label == label;

  @override
  int get hashCode => Object.hash(id, page, label);
}
