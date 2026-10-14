/// What the chat remembers: the lines he typed, and what he decided about
/// every piece of them.
///
/// It exists for two reasons: the chat screen can show the day again after
/// the app was closed, and applying the same piece twice writes nothing the
/// second time – the decision is remembered, not guessed.
///
/// Pure Dart (JSON in, JSON out). It is stored in `key_values` inside the
/// encrypted database, exactly like the AI chat's conversations – no schema
/// change.
library;

import 'package:meta/meta.dart';

import 'day_chat_piece.dart';

/// What he did with one piece.
enum DayChatState {
  /// Shown, nothing decided yet.
  pending,

  /// Written into its feature.
  applied,

  /// He said no.
  rejected,

  /// It was applied and then undone.
  undone,
}

/// One decision, with where the write landed so an undo and a second apply
/// both know what to do.
@immutable
class DayChatDecision {
  const DayChatDecision({
    required this.pieceId,
    required this.state,
    required this.at,
    this.kind,
    this.refTable,
    this.refId,
    this.text,
    this.edited = false,
  });

  static DayChatDecision? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['pieceId'];
    final state = json['state'];
    final at = json['at'];
    if (id is! String || state is! String || at is! String) return null;
    final when = DateTime.tryParse(at);
    if (when == null) return null;
    return DayChatDecision(
      pieceId: id,
      state: DayChatState.values.firstWhere((s) => s.name == state, orElse: () => DayChatState.pending),
      at: when,
      kind: DayChatKind.values.where((k) => k.name == json['kind']).firstOrNull,
      refTable: json['refTable'] as String?,
      refId: json['refId'] as String?,
      text: json['text'] as String?,
      edited: json['edited'] == true,
    );
  }

  final String pieceId;
  final DayChatState state;
  final DateTime at;

  /// What kind of piece it was (for the day summary and the history).
  final DayChatKind? kind;

  /// The table and row the apply wrote, when it wrote one.
  final String? refTable;
  final String? refId;

  /// His own words of the piece (so the history reads like his day).
  final String? text;

  /// True when he changed the piece before applying it.
  final bool edited;

  bool get isApplied => state == DayChatState.applied;

  Map<String, Object?> toJson() => {
    'pieceId': pieceId,
    'state': state.name,
    'at': at.toIso8601String(),
    'kind': ?kind?.name,
    'refTable': ?refTable,
    'refId': ?refId,
    'text': ?text,
    if (edited) 'edited': true,
  };

  DayChatDecision copyWith({DayChatState? state, String? refTable, String? refId, DateTime? at, bool? edited}) =>
      DayChatDecision(
        pieceId: pieceId,
        state: state ?? this.state,
        at: at ?? this.at,
        kind: kind,
        refTable: refTable ?? this.refTable,
        refId: refId ?? this.refId,
        text: text,
        edited: edited ?? this.edited,
      );
}

/// One line he typed, as the chat shows it again.
@immutable
class DayChatLine {
  const DayChatLine({required this.id, required this.at, required this.text, this.pieceIds = const []});

  static DayChatLine? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final text = json['text'];
    final at = json['at'];
    if (id is! String || text is! String || at is! String) return null;
    final when = DateTime.tryParse(at);
    if (when == null) return null;
    return DayChatLine(
      id: id,
      at: when,
      text: text,
      pieceIds: [
        if (json['pieces'] is List)
          for (final p in json['pieces'] as List)
            if (p is String) p,
      ],
    );
  }

  final String id;
  final DateTime at;

  /// Exactly what he typed (every span of the reading indexes into this).
  final String text;

  /// The pieces this line was read into, in order.
  final List<String> pieceIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'text': text,
    if (pieceIds.isNotEmpty) 'pieces': pieceIds,
  };
}

/// One day of the chat.
@immutable
class DayChatDay {
  const DayChatDay({required this.day, this.lines = const [], this.decisions = const {}});

  factory DayChatDay.fromJson(DateTime day, Object? json) {
    if (json is! Map) return DayChatDay(day: _dayOf(day));
    return DayChatDay(
      day: _dayOf(day),
      lines: [
        if (json['lines'] is List)
          for (final l in json['lines'] as List) ?DayChatLine.fromJson(l),
      ],
      decisions: {
        if (json['decisions'] is Map)
          for (final e in (json['decisions'] as Map).entries)
            for (final d in [?DayChatDecision.fromJson(e.value)]) d.pieceId: d,
      },
    );
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  /// `yyyy-mm-dd` – the key of a day.
  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? dayOfKey(String key) => DateTime.tryParse(key);

  final DateTime day;

  /// Oldest first, the way the chat reads.
  final List<DayChatLine> lines;

  /// Piece id → what he decided.
  final Map<String, DayChatDecision> decisions;

  bool get isEmpty => lines.isEmpty && decisions.isEmpty;

  DayChatDecision? decision(String pieceId) => decisions[pieceId];

  DayChatState stateOf(String pieceId) => decisions[pieceId]?.state ?? DayChatState.pending;

  /// Everything he applied today, in the order he applied it.
  List<DayChatDecision> get applied {
    final out = [
      for (final d in decisions.values)
        if (d.isApplied) d,
    ];
    out.sort((a, b) => a.at.compareTo(b.at));
    return out;
  }

  DayChatDay withLine(DayChatLine line) => DayChatDay(
    day: day,
    lines: [
      for (final l in lines)
        if (l.id != line.id) l,
      line,
    ]..sort((a, b) => a.at.compareTo(b.at)),
    decisions: decisions,
  );

  DayChatDay withDecision(DayChatDecision decision) =>
      DayChatDay(day: day, lines: lines, decisions: {...decisions, decision.pieceId: decision});

  DayChatDay withoutLine(String id) => DayChatDay(
    day: day,
    lines: [
      for (final l in lines)
        if (l.id != id) l,
    ],
    decisions: decisions,
  );

  Map<String, Object?> toJson() => {
    'lines': [for (final l in lines) l.toJson()],
    'decisions': {for (final e in decisions.entries) e.key: e.value.toJson()},
  };
}
