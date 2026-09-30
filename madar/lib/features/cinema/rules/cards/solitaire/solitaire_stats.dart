/// Solitaire statistics (S-72), kept separately for draw one and draw three.
library;

import 'dart:math' as math;

import 'solitaire_game.dart';

/// The record of one draw mode.
class SolitaireModeStats {
  SolitaireModeStats({
    this.played = 0,
    this.won = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestScore,
    this.bestTimeSeconds,
    this.fewestMoves,
    this.totalCardsHome = 0,
  });

  factory SolitaireModeStats.fromJson(Map<String, Object?> j) => SolitaireModeStats(
    played: j['played']! as int,
    won: j['won']! as int,
    currentStreak: j['currentStreak']! as int,
    bestStreak: j['bestStreak']! as int,
    bestScore: j['bestScore'] as int?,
    bestTimeSeconds: j['bestTimeSeconds'] as int?,
    fewestMoves: j['fewestMoves'] as int?,
    totalCardsHome: j['totalCardsHome']! as int,
  );

  int played;
  int won;

  /// Wins in a row; a deal left unfinished counts as a loss.
  int currentStreak;
  int bestStreak;

  /// Best score, best time and fewest moves count won deals only.
  int? bestScore;
  int? bestTimeSeconds;
  int? fewestMoves;
  int totalCardsHome;

  double get winRate => played == 0 ? 0 : won / played;
  double get averageCardsHome => played == 0 ? 0 : totalCardsHome / played;

  void record(SolitaireGame game) {
    final s = game.state;
    played++;
    totalCardsHome += s.cardsHome;
    if (!game.isSolved) {
      currentStreak = 0;
      return;
    }
    won++;
    currentStreak++;
    bestStreak = math.max(bestStreak, currentStreak);
    bestScore = bestScore == null ? s.score : math.max(bestScore!, s.score);
    final t = s.elapsedMs ~/ 1000;
    bestTimeSeconds = bestTimeSeconds == null ? t : math.min(bestTimeSeconds!, t);
    fewestMoves = fewestMoves == null ? s.moves : math.min(fewestMoves!, s.moves);
  }

  Map<String, Object?> toJson() => {
    'played': played,
    'won': won,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'bestScore': bestScore,
    'bestTimeSeconds': bestTimeSeconds,
    'fewestMoves': fewestMoves,
    'totalCardsHome': totalCardsHome,
  };
}

class SolitaireStats {
  SolitaireStats({SolitaireModeStats? drawOne, SolitaireModeStats? drawThree})
    : drawOne = drawOne ?? SolitaireModeStats(),
      drawThree = drawThree ?? SolitaireModeStats();

  factory SolitaireStats.fromJson(Map<String, Object?> j) => SolitaireStats(
    drawOne: SolitaireModeStats.fromJson((j['drawOne']! as Map).cast<String, Object?>()),
    drawThree: SolitaireModeStats.fromJson((j['drawThree']! as Map).cast<String, Object?>()),
  );

  final SolitaireModeStats drawOne;
  final SolitaireModeStats drawThree;

  SolitaireModeStats forDrawCount(int drawCount) => drawCount == 3 ? drawThree : drawOne;

  /// Records a deal when it is won or abandoned (a new deal is started).
  void record(SolitaireGame game) => forDrawCount(game.options.drawCount).record(game);

  Map<String, Object?> toJson() => {'drawOne': drawOne.toJson(), 'drawThree': drawThree.toJson()};
}
