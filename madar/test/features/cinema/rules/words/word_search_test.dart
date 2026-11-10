import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/words/words.dart';

import 'words_test_utils.dart';

void main() {
  final generator = WordSearchGenerator(filter: wordFilter, letterWeights: lexicon.letterWeights());

  group('generator', () {
    test('every difficulty yields valid grids for every theme', () {
      for (final d in WordSearchDifficulty.values) {
        final config = WordSearchConfig.forDifficulty(d);
        for (final (i, theme) in themes.indexed) {
          final puzzle = generator.generate(theme.words, config, 1000 + i);
          expect(puzzle.rows, config.rows);
          expect(puzzle.cols, config.cols);
          expect(WordSearchGenerator.validate(puzzle, wordFilter), isEmpty, reason: '${d.name} ${theme.id}');
          expect(puzzle.placements.length, greaterThanOrEqualTo(theme.words.length < config.wordCount ? 3 : config.wordCount - 1),
              reason: '${d.name} ${theme.id}');
          for (final p in puzzle.placements) {
            expect(config.directions, contains(p.direction));
          }
          for (final row in puzzle.grid) {
            for (final l in row) {
              expect(ArabicText.isGameWord(l) && l.length == 1, isTrue);
            }
          }
        }
      }
    });

    test('easy grids read naturally; hard grids use reversed and diagonal words', () {
      final easy = generator.generate(themes.first.words, WordSearchConfig.forDifficulty(WordSearchDifficulty.easy), 5);
      expect(easy.placements.every((p) => p.direction.isReading), isTrue);
      final dirs = <GridDirection>{};
      for (var s = 0; s < 10; s++) {
        final hard = generator.generate(themes[s % themes.length].words, WordSearchConfig.forDifficulty(WordSearchDifficulty.hard), s);
        dirs.addAll(hard.placements.map((p) => p.direction));
      }
      expect(dirs.length, greaterThanOrEqualTo(6));
      expect(dirs.any((d) => d.isDiagonal), isTrue);
      expect(dirs, contains(GridDirection.backward));
    });

    test('is deterministic for a seed and varies across seeds', () {
      final config = WordSearchConfig.forDifficulty(WordSearchDifficulty.medium);
      final a = generator.generate(themes[3].words, config, 77);
      final b = generator.generate(themes[3].words, config, 77);
      final c2 = generator.generate(themes[3].words, config, 78);
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
      expect(jsonEncode(a.toJson()), isNot(jsonEncode(c2.toJson())));
      final restored = WordSearchPuzzle.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>);
      expect(jsonEncode(restored.toJson()), jsonEncode(a.toJson()));
    });

    test('generates in under 200 ms (expert grid)', () {
      final config = WordSearchConfig.forDifficulty(WordSearchDifficulty.expert);
      final ms = slowestMs((run) => generator.generate(themes[(run + 2) % themes.length].words, config, run));
      expect(ms, lessThan(200));
    });
  });

  group('game', () {
    test('words are found from either end; misses and bad lines are reported', () {
      final puzzle = generator.generate(themes.first.words, WordSearchConfig.forDifficulty(WordSearchDifficulty.hard), 9);
      final game = WordSearchGame(puzzle);
      final first = puzzle.placements.first;
      expect(game.select(first.end, first.start).$1, SelectionOutcome.found);
      expect(game.select(first.start, first.end).$1, SelectionOutcome.alreadyFound);
      expect(game.select(const GridPos(0, 0), const GridPos(1, 2)).$1, SelectionOutcome.invalidLine);
      for (final p in puzzle.placements.skip(1)) {
        expect(game.select(p.start, p.end).$1, SelectionOutcome.found);
      }
      expect(game.isComplete, isTrue);
      final saved = WordSearchGame.fromJson(jsonDecode(jsonEncode(game.toJson())) as Map<String, Object?>);
      expect(saved.isComplete, isTrue);
      expect(game.line(const GridPos(0, 0), const GridPos(3, 3))!.length, 4);
    });
  });
}
