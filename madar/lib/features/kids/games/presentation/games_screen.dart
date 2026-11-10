import 'package:flutter/material.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../rewards/presentation/play_kit.dart';
import '../domain/pairs_game.dart';
import 'pair_card.dart';
import 'pairs_play_screen.dart';

/// «الألعاب» (design 10): the featured game, its three sizes, one big «العب».
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, this.seed});

  /// Fixes the shuffle of the game it starts (tests).
  final int? seed;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  PairsSize _size = PairsSize.small;

  void _play() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PairsPlayScreen(size: _size, seed: widget.seed),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      backgroundColor: KidsColors.night100,
      body: SafeArea(
        child: Column(
          children: [
            PlayHeader(title: l.kidsPlayGamesTitle),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: KidsColors.night800, borderRadius: BorderRadius.circular(34)),
                      child: Column(
                        children: [
                          const _Preview(),
                          const SizedBox(height: 16),
                          Text(
                            l.kidsPlayPairsTitle,
                            style: KidsText.display.copyWith(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.kidsPlayPairsBlurb,
                            style: KidsText.small.copyWith(color: KidsColors.night100),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(l.kidsPlayChooseSize, style: KidsText.subtitle),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final s in PairsSize.values)
                          _SizeChip(
                            label: l.kidsPlayPairsCount(s.pairs, kidsNumber(context, s.pairs)),
                            selected: s == _size,
                            onTap: () => setState(() => _size = s),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    BigPlayButton(label: l.kidsPlayPlay, icon: Icons.play_arrow_rounded, height: 76, onPressed: _play),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? KidsColors.sun500 : KidsColors.paper,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64, minWidth: 96),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Center(
              widthFactor: 1,
              child: Text(label, style: KidsText.subtitle.copyWith(color: KidsColors.night900)),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Six cards, two of them turned over: a still preview of the game.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, c) {
        final w = ((c.maxWidth - 24) / 3).clamp(48.0, 84.0);
        Widget card(Widget child) => SizedBox(width: w, height: w * 1.25, child: child);
        Widget row(List<Widget> cards) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < cards.length; i++) ...[if (i > 0) const SizedBox(width: 12), card(cards[i])],
          ],
        );
        return Column(
          children: [
            row(const [PairCardBack(), PairCardBack(), PairCardFace(symbol: 0)]),
            const SizedBox(height: 12),
            row(const [PairCardBack(), PairCardFace(symbol: 0), PairCardBack()]),
          ],
        );
      },
    ),
  );
}
