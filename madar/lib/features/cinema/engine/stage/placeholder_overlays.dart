import 'package:flutter/material.dart';

import '../core/cinema_game.dart';
import '../core/cinema_kit.dart';
import 'placeholder_hud.dart' show hudDigits;

/// Minimal Flutter overlays for the intermission and results cards.
/// Placeholder – the stage agent replaces them with period-styled cards.
Map<String, CinemaOverlayBuilder> placeholderOverlays() => {
  CinemaOverlays.pause: (context, game) => _Card(
    game: game,
    title: game.l10n.cinemaIntermission,
    actions: [
      (game.l10n.cinemaResume, game.resumeGame),
      (game.l10n.cinemaRestart, game.requestRestart),
      (game.l10n.cinemaLeave, game.requestExit),
    ],
  ),
  CinemaOverlays.results: (context, game) {
    final r = game.result;
    final score = hudDigits('${r?.score ?? game.hud.score}', game.env.languageCode);
    return _Card(
      game: game,
      title: (r?.won ?? false) ? game.l10n.cinemaTheEnd : game.l10n.cinemaGameOver,
      subtitle: game.l10n.cinemaScoreLine(score),
      actions: [(game.l10n.cinemaPlayAgain, game.requestRestart), (game.l10n.cinemaLeave, game.requestExit)],
    );
  },
};

class _Card extends StatelessWidget {
  const _Card({required this.game, required this.title, required this.actions, this.subtitle});

  final CinemaGame game;
  final String title;
  final String? subtitle;
  final List<(String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    final pal = game.skin.palette;
    final font = game.skin.titles.fontFamily;
    return ColoredBox(
      color: pal.ink.withValues(alpha: 0.55),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: pal.paper,
            border: Border.all(color: pal.ink, width: 3),
            boxShadow: [BoxShadow(color: pal.ink, offset: const Offset(0, 5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: font, fontSize: 34, fontWeight: FontWeight.w700, color: pal.ink),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(subtitle!, style: TextStyle(fontFamily: font, fontSize: 18, color: pal.shadow)),
                ),
              const SizedBox(height: 18),
              for (final (label, onTap) in actions)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: pal.ink,
                        side: BorderSide(color: pal.ink, width: 2),
                        shape: const RoundedRectangleBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      child: Text(label),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
