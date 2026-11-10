import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../core/kids_section.dart';
import '../../rewards/presentation/play_kit.dart';
import '../domain/pairs_game.dart';
import 'pair_card.dart';

/// The star a finished game asks for. One a day (the rewards de-duplicate).
const String pairsStarReason = 'game.pairs';

/// «أزواج النجوم»: the board. No timer, no score to lose, no "wrong": a miss
/// turns the two cards back after a moment and says something kind.
class PairsPlayScreen extends ConsumerStatefulWidget {
  const PairsPlayScreen({
    super.key,
    required this.size,
    this.seed,
    this.missDelay = const Duration(milliseconds: 900),
    this.finishDelay = const Duration(milliseconds: 700),
    this.cardTurn,
  });

  final PairsSize size;

  /// Fixes the shuffle (tests); null means a fresh one.
  final int? seed;
  final Duration missDelay;
  final Duration finishDelay;
  final Duration? cardTurn;

  @override
  ConsumerState<PairsPlayScreen> createState() => _PairsPlayScreenState();
}

enum _Feedback { none, cheer, retry }

class _PairsPlayScreenState extends ConsumerState<PairsPlayScreen> {
  late PairsGame _game;
  Timer? _missTimer, _finishTimer;
  _Feedback _feedback = _Feedback.none;
  bool _finished = false;
  bool? _gotStar;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _game = PairsGame(size: widget.size, seed: widget.seed ?? DateTime.now().microsecondsSinceEpoch);
    _feedback = _Feedback.none;
    _finished = false;
    _gotStar = null;
  }

  @override
  void dispose() {
    _missTimer?.cancel();
    _finishTimer?.cancel();
    super.dispose();
  }

  void _tap(int i) {
    if (_finished) return;
    _missTimer?.cancel();
    final r = _game.flip(i);
    if (r == FlipResult.ignored) return;
    setState(() {
      _feedback = switch (r) {
        FlipResult.matched => _Feedback.cheer,
        FlipResult.missed => _Feedback.retry,
        _ => _Feedback.none,
      };
    });
    if (r == FlipResult.missed) {
      final serial = _game.missSerial;
      _missTimer = Timer(widget.missDelay, () {
        if (mounted && _game.settleIf(serial)) setState(() {});
      });
    } else if (_game.won) {
      _finishTimer = Timer(widget.finishDelay, _finish);
    }
  }

  Future<void> _finish() async {
    if (!mounted) return;
    final before = ref.read(kidsStarCountProvider);
    await ref.read(kidsStarAwardProvider)(pairsStarReason);
    if (!mounted) return;
    setState(() {
      _finished = true;
      _gotStar = ref.read(kidsStarCountProvider) > before;
    });
  }

  String _feedbackText(L10n l) {
    final k = _game.moves % 3;
    return switch (_feedback) {
      _Feedback.cheer => [l.kidsPlayCheer1, l.kidsPlayCheer2, l.kidsPlayCheer3][k],
      _Feedback.retry => [l.kidsPlayRetry1, l.kidsPlayRetry2, l.kidsPlayRetry3][k],
      _Feedback.none => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final size = widget.size;
    return Scaffold(
      backgroundColor: KidsColors.night100,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                PlayHeader(title: l.kidsPlayPairsTitle),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l.kidsPlayPairsFound(kidsNumber(context, _game.matchedPairs), kidsNumber(context, size.pairs)),
                    style: KidsText.small.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _Board(game: _game, onTap: _tap, turn: widget.cardTurn, cardLabel: (i) => _cardLabel(l, i)),
                  ),
                ),
                SizedBox(
                  height: 64,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _feedback == _Feedback.none
                        ? const SizedBox(key: ValueKey('none'))
                        : Container(
                            key: ValueKey('${_feedback.name}${_game.moves}'),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            decoration: BoxDecoration(
                              color: _feedback == _Feedback.cheer ? KidsColors.teal100 : KidsColors.retryFill,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Text(
                              _feedbackText(l),
                              style: KidsText.small.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _feedback == _Feedback.cheer ? KidsColors.teal700 : KidsColors.retryText,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
            if (_finished)
              Positioned.fill(
                child: _FinishCard(
                  gotStar: _gotStar ?? false,
                  onAgain: () => setState(_newGame),
                  onDone: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _cardLabel(L10n l, int i) {
    final n = kidsNumber(context, i + 1);
    if (!_game.isFaceUp(i)) return l.kidsPlayCardDown(n);
    return l.kidsPlayCardUp(n, _symbolName(l, _game.deck[i]));
  }

  static String _symbolName(L10n l, int s) => switch (s) {
    0 => l.kidsPlaySymLantern,
    1 => l.kidsPlaySymStar,
    2 => l.kidsPlaySymSun,
    3 => l.kidsPlaySymMoon,
    4 => l.kidsPlaySymTree,
    5 => l.kidsPlaySymFlower,
    6 => l.kidsPlaySymDrop,
    7 => l.kidsPlaySymLeaf,
    8 => l.kidsPlaySymHeart,
    9 => l.kidsPlaySymCloud,
    10 => l.kidsPlaySymKite,
    _ => l.kidsPlaySymGem,
  };
}

class _Board extends StatelessWidget {
  const _Board({required this.game, required this.onTap, required this.cardLabel, this.turn});

  final PairsGame game;
  final void Function(int) onTap;
  final String Function(int) cardLabel;
  final Duration? turn;

  @override
  Widget build(BuildContext context) {
    final size = game.size;
    const gap = 10.0;
    return LayoutBuilder(
      builder: (context, c) {
        final cellW = (c.maxWidth - gap * (size.columns - 1)) / size.columns;
        final cellH = (c.maxHeight - gap * (size.rows - 1)) / size.rows;
        // Portrait cards, never thinner than 0.62; when the screen is too short
        // the board scrolls rather than shrinking the targets below 64 dp.
        final aspect = (cellW / cellH).clamp(0.62, 1.0);
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: size.columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: aspect,
          ),
          itemCount: game.deck.length,
          itemBuilder: (context, i) => Semantics(
            button: true,
            label: cardLabel(i),
            excludeSemantics: true,
            onTap: () => onTap(i),
            child: GestureDetector(
              key: ValueKey('pair-card-$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: FlipCard(
                faceUp: game.isFaceUp(i),
                symbol: game.deck[i],
                matched: game.isMatched(i),
                duration: turn,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FinishCard extends StatelessWidget {
  const _FinishCard({required this.gotStar, required this.onAgain, required this.onDone});

  final bool gotStar;
  final VoidCallback onAgain, onDone;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return ColoredBox(
      color: KidsColors.night900.withValues(alpha: .78),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: KidsColors.paper, borderRadius: BorderRadius.circular(34)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KhatamStarIcon(size: 96),
                const SizedBox(height: 12),
                Text(l.kidsPlayWellDone, style: KidsText.display, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(
                  gotStar ? l.kidsPlayNewStar : l.kidsPlayStarAlreadyToday,
                  style: KidsText.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                BigPlayButton(label: l.kidsPlayAgain, icon: Icons.replay_rounded, onPressed: onAgain),
                const SizedBox(height: 12),
                BigPlayButton(
                  label: l.kidsPlayDone,
                  background: KidsColors.teal500,
                  foreground: Colors.white,
                  onPressed: onDone,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
