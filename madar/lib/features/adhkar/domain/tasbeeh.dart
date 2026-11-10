import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A phrase on the tasbeeh (user-editable list).
@immutable
class TasbeehPhrase {
  const TasbeehPhrase({required this.id, required this.text});

  /// Built-in phrases keep their well-known id (for their English gloss);
  /// user phrases get a generated one.
  final String id;

  /// Arabic (or whatever the user typed).
  final String text;

  TasbeehPhrase copyWith({String? text}) => TasbeehPhrase(id: id, text: text ?? this.text);

  Map<String, Object?> toJson() => {'id': id, 'text': text};

  static TasbeehPhrase? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], text = json['text'];
    if (id is! String || id.isEmpty || text is! String || text.trim().isEmpty) return null;
    return TasbeehPhrase(id: id, text: text);
  }

  @override
  bool operator ==(Object other) => other is TasbeehPhrase && other.id == id && other.text == text;

  @override
  int get hashCode => Object.hash(id, text);
}

/// Generic, well-known phrases a fresh install starts with (fully vowelled).
abstract final class TasbeehDefaults {
  static const List<TasbeehPhrase> phrases = [
    TasbeehPhrase(id: 'subhanallah', text: 'سُبْحَانَ اللَّهِ'),
    TasbeehPhrase(id: 'alhamdulillah', text: 'الْحَمْدُ لِلَّهِ'),
    TasbeehPhrase(id: 'allahuakbar', text: 'اللَّهُ أَكْبَرُ'),
    TasbeehPhrase(id: 'tahlil', text: 'لَا إِلَهَ إِلَّا اللَّهُ'),
    TasbeehPhrase(id: 'istighfar', text: 'أَسْتَغْفِرُ اللَّهَ'),
    TasbeehPhrase(id: 'subhanallahWaBihamdihi', text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ'),
    TasbeehPhrase(id: 'subhanallahilAzim', text: 'سُبْحَانَ اللَّهِ الْعَظِيمِ'),
    TasbeehPhrase(id: 'hawqala', text: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ'),
    TasbeehPhrase(id: 'salawat', text: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ'),
  ];

  static const List<int> targets = [33, 99, 100];
  static const int defaultTarget = 33;
  static const int maxTarget = 9999;

  static bool isBuiltIn(String id) => phrases.any((p) => p.id == id);
}

/// What a tap on the tasbeeh did.
enum TasbeehTapOutcome {
  /// One bead moved.
  bead,

  /// A round (target) was completed with this tap.
  round,
}

/// The tasbeeh counter: a running [count] against a per-round [target].
@immutable
class TasbeehCounter {
  const TasbeehCounter({required this.target, this.count = 0}) : assert(target > 0), assert(count >= 0);

  final int target;

  /// Every tap of the session.
  final int count;

  /// Completed rounds.
  int get rounds => count ~/ target;

  /// Position in the current round, 1…target (a just-finished round shows
  /// target/target until the next tap starts the next round).
  int get inRound => count == 0 ? 0 : ((count - 1) % target) + 1;

  bool get roundJustCompleted => count > 0 && count % target == 0;

  /// Beads drawn on the ring (targets above 100 share 100 beads).
  int get beads => math.min(target, 100);

  /// Beads lit for [inRound].
  int get litBeads => (inRound * beads / target).floor();

  /// 0…1 through the current round.
  double get roundProgress => inRound / target;

  (TasbeehCounter, TasbeehTapOutcome) tap() {
    final next = TasbeehCounter(target: target, count: count + 1);
    return (next, next.roundJustCompleted ? TasbeehTapOutcome.round : TasbeehTapOutcome.bead);
  }

  TasbeehCounter reset() => TasbeehCounter(target: target);

  /// Parses a custom target typed by the user (1…9999).
  static int? parseTarget(Object? value) {
    final n = switch (value) {
      final int v => v,
      final num v => v.round(),
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    if (n == null || n < 1 || n > TasbeehDefaults.maxTarget) return null;
    return n;
  }

  @override
  bool operator ==(Object other) => other is TasbeehCounter && other.target == target && other.count == count;

  @override
  int get hashCode => Object.hash(target, count);
}

/// A finished (or ongoing) tasbeeh session, as kept in the activity log.
@immutable
class TasbeehSession {
  const TasbeehSession({
    required this.id,
    required this.phrase,
    required this.count,
    required this.target,
    required this.at,
  });

  /// Activity-log row id.
  final String id;
  final String phrase;
  final int count;
  final int target;
  final DateTime at;

  int get rounds => target <= 0 ? 0 : count ~/ target;
}
