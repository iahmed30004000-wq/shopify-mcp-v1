/// A highlight anchored to TEXT, not to a page: pages change when the text
/// scale or the screen changes, characters of a section do not. [reanchor]
/// finds the same words again when the text around them shifted.
library;

import 'package:meta/meta.dart';

/// How many characters of context are kept on each side of the selection.
const int highlightContextLength = 32;

@immutable
final class Highlight {
  const Highlight({
    required this.id,
    required this.bookId,
    required this.sectionId,
    required this.start,
    required this.end,
    required this.text,
    this.before = '',
    this.after = '',
    this.colorKey = 'yellow',
    this.note,
    required this.createdAt,
  });

  /// Cuts [start]..[end] (UTF-16 offsets into [sectionText]) out of a section
  /// and keeps a short context on both sides for re-anchoring.
  factory Highlight.fromSelection({
    required String id,
    required String bookId,
    required String sectionId,
    required String sectionText,
    required int start,
    required int end,
    required DateTime createdAt,
    String colorKey = 'yellow',
    String? note,
  }) {
    RangeError.checkValidRange(start, end, sectionText.length);
    if (start == end) throw ArgumentError('A highlight needs at least one character');
    return Highlight(
      id: id,
      bookId: bookId,
      sectionId: sectionId,
      start: start,
      end: end,
      text: sectionText.substring(start, end),
      before: _beforeOf(sectionText, start),
      after: _afterOf(sectionText, end),
      colorKey: colorKey,
      note: note,
      createdAt: createdAt,
    );
  }

  final String id;
  final String bookId;

  /// Chapter / section the offsets are relative to.
  final String sectionId;
  final int start;
  final int end;

  /// The highlighted words themselves.
  final String text;
  final String before;
  final String after;

  /// A palette key the screen maps to a colour (never a colour value).
  final String colorKey;
  final String? note;
  final DateTime createdAt;

  int get length => end - start;

  Highlight _moved(String sectionText, int newStart) => Highlight(
    id: id,
    bookId: bookId,
    sectionId: sectionId,
    start: newStart,
    end: newStart + text.length,
    text: text,
    before: _beforeOf(sectionText, newStart),
    after: _afterOf(sectionText, newStart + text.length),
    colorKey: colorKey,
    note: note,
    createdAt: createdAt,
  );

  Highlight copyWith({String? colorKey, String? note, bool clearNote = false}) => Highlight(
    id: id,
    bookId: bookId,
    sectionId: sectionId,
    start: start,
    end: end,
    text: text,
    before: before,
    after: after,
    colorKey: colorKey ?? this.colorKey,
    note: clearNote ? null : (note ?? this.note),
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'bookId': bookId,
    'sectionId': sectionId,
    'start': start,
    'end': end,
    'text': text,
    'before': before,
    'after': after,
    'colorKey': colorKey,
    if (note != null) 'note': note,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Highlight.fromJson(Map<String, Object?> json) => Highlight(
    id: json['id'] as String,
    bookId: json['bookId'] as String,
    sectionId: json['sectionId'] as String,
    start: (json['start'] as num).toInt(),
    end: (json['end'] as num).toInt(),
    text: json['text'] as String,
    before: json['before'] as String? ?? '',
    after: json['after'] as String? ?? '',
    colorKey: json['colorKey'] as String? ?? 'yellow',
    note: json['note'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is Highlight && other.id == id && other.sectionId == sectionId && other.start == start && other.end == end && other.text == text;

  @override
  int get hashCode => Object.hash(id, sectionId, start, end, text);
}

String _beforeOf(String s, int start) => s.substring(start < highlightContextLength ? 0 : start - highlightContextLength, start);

String _afterOf(String s, int end) => s.substring(end, end + highlightContextLength > s.length ? s.length : end + highlightContextLength);

enum ReanchorOutcome {
  /// The words are still exactly where they were.
  unchanged,

  /// Found again, at another offset, with matching surroundings.
  moved,

  /// Found again but the surroundings no longer tell the copies apart; the
  /// copy nearest to the old place was taken.
  ambiguous,

  /// The words are gone from the section.
  lost,
}

@immutable
final class ReanchorResult {
  const ReanchorResult(this.outcome, this.highlight);

  final ReanchorOutcome outcome;

  /// The highlight at its new place; null when [outcome] is lost (the screen
  /// keeps the old one in a "could not place" list rather than deleting it).
  final Highlight? highlight;
}

/// Finds [h] again in [sectionText], the section as it reads now.
///
/// 1. same offsets still hold the same words: unchanged;
/// 2. else every copy of the words is a candidate, scored by how much of the
///    stored context matches around it; best score wins, nearest to the old
///    offset breaks ties;
/// 3. no copy: lost.
ReanchorResult reanchor(Highlight h, String sectionText) {
  if (h.end <= sectionText.length && sectionText.substring(h.start, h.end) == h.text) {
    return ReanchorResult(ReanchorOutcome.unchanged, h);
  }
  final candidates = <int>[];
  for (var i = sectionText.indexOf(h.text); i >= 0; i = sectionText.indexOf(h.text, i + 1)) {
    candidates.add(i);
  }
  if (candidates.isEmpty) return const ReanchorResult(ReanchorOutcome.lost, null);

  int score(int c) {
    var s = 0;
    final b = _beforeOf(sectionText, c);
    for (var k = 1; k <= b.length && k <= h.before.length; k++) {
      if (b[b.length - k] != h.before[h.before.length - k]) break;
      s++;
    }
    final a = _afterOf(sectionText, c + h.text.length);
    for (var k = 0; k < a.length && k < h.after.length; k++) {
      if (a[k] != h.after[k]) break;
      s++;
    }
    return s;
  }

  var best = candidates.first;
  var bestScore = score(best);
  for (final c in candidates.skip(1)) {
    final s = score(c);
    final nearer = (c - h.start).abs() < (best - h.start).abs();
    if (s > bestScore || (s == bestScore && nearer)) {
      best = c;
      bestScore = s;
    }
  }
  final ambiguous = candidates.length > 1 && bestScore == 0;
  return ReanchorResult(ambiguous ? ReanchorOutcome.ambiguous : ReanchorOutcome.moved, h._moved(sectionText, best));
}
