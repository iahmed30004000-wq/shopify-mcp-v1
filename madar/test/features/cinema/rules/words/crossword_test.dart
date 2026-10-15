import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/words/words.dart';

import 'words_test_utils.dart';

void main() {
  final generator = CrosswordGenerator(clues);

  group('generator', () {
    test('valid, connected, dense grids at every difficulty', () {
      for (final d in CrosswordDifficulty.values) {
        final config = CrosswordConfig.forDifficulty(d);
        for (var seed = 0; seed < 12; seed++) {
          final puzzle = generator.generate(config, seed);
          expect(puzzle.validate(), isEmpty, reason: '${d.name} seed $seed');
          expect(puzzle.rows, lessThanOrEqualTo(config.size));
          expect(puzzle.cols, lessThanOrEqualTo(config.size));
          expect(puzzle.entries.length, greaterThanOrEqualTo(config.targetWords - 3), reason: '${d.name} seed $seed');
          expect(puzzle.crossings, greaterThanOrEqualTo(puzzle.entries.length - 1));
          expect(puzzle.density, greaterThan(0.3), reason: '${d.name} seed $seed');
          expect(puzzle.entries.every((e) => e.level <= config.maxLevel), isTrue);
          expect(puzzle.entries.map((e) => ArabicText.fold(e.answer)).toSet().length, puzzle.entries.length);
        }
      }
    });

    test('numbering starts at the top right and follows reading order', () {
      final puzzle = generator.generate(CrosswordConfig.forDifficulty(CrosswordDifficulty.medium), 4);
      expect(puzzle.entries.first.number, 1);
      final starts = [for (final e in puzzle.entries) e.start];
      for (var i = 1; i < puzzle.entries.length; i++) {
        final a = puzzle.entries[i - 1], b = puzzle.entries[i];
        expect(b.number >= a.number, isTrue);
        if (b.number > a.number) {
          expect(b.start.row > a.start.row || (b.start.row == a.start.row && b.start.col > a.start.col), isTrue);
        }
      }
      expect(starts.toSet().length, puzzle.entries.map((e) => e.number).toSet().length);
    });

    test('is deterministic for a seed', () {
      final config = CrosswordConfig.forDifficulty(CrosswordDifficulty.hard);
      final a = generator.generate(config, 99), b = generator.generate(config, 99);
      expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
      expect(jsonEncode(generator.generate(config, 100).toJson()), isNot(jsonEncode(a.toJson())));
    });

    test('generates in under 200 ms', () {
      for (final d in CrosswordDifficulty.values) {
        final ms = slowestMs((run) => generator.generate(CrosswordConfig.forDifficulty(d), run));
        expect(ms, lessThan(200), reason: d.name);
      }
    });
  });

  group('game', () {
    test('enter, check, reveal and solve with folded letters', () {
      final puzzle = generator.generate(CrosswordConfig.forDifficulty(CrosswordDifficulty.easy), 3);
      final game = CrosswordGame(puzzle);
      final entry = puzzle.entries.first;
      final cell = entry.cells.first;
      final wrong = ArabicText.foldLetter(puzzle.solutionAt(cell)!) == 'ض' ? 'ظ' : 'ض';
      expect(game.setLetter(cell, wrong), isTrue);
      expect(game.checkCell(cell), isTrue);
      expect(game.checkEntry(entry), {cell});
      expect(game.setLetter(cell, 'ab'), isFalse);
      // A folded variant counts as right (ا for أ, ه for ة …).
      final sol = puzzle.solutionAt(cell)!;
      game.setLetter(cell, sol == 'أ' ? 'ا' : sol);
      expect(game.checkCell(cell), isFalse);
      game.revealEntry(puzzle.entries.last);
      expect(game.isEntrySolved(puzzle.entries.last), isTrue);
      expect(game.setLetter(puzzle.entries.last.cells.first, 'ض'), isFalse); // revealed cells are locked
      for (final e in puzzle.entries) {
        for (final (i, p) in e.cells.indexed) {
          if (!game.isRevealed(p)) game.setLetter(p, e.answer[i]);
        }
      }
      expect(game.isSolved, isTrue);
      expect(game.checkAll(), isEmpty);
      final saved = CrosswordGame.fromJson(jsonDecode(jsonEncode(game.toJson())) as Map<String, Object?>);
      expect(saved.isSolved, isTrue);
      expect(saved.revealedCount, game.revealedCount);
      final fresh = CrosswordGame(puzzle)..revealAll();
      expect(fresh.isSolved, isTrue);
      expect(fresh.revealedCount, puzzle.cells.length);
    });
  });
}
