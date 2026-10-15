import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../cinema/engine/core/catalog.dart' show GameCatalogEntry;
import '../../../cinema/games/catalog.dart';
import '../../../cinema/hall/hall.dart' show CinemaRecords, GameRecord, cinemaRecordsProvider;

/// His best scores on «الألعاب»'s page: the games he has scored on, best
/// first, with how often each was played and how many games have a score at
/// all. Before his first show it is one calm invitation, never a made-up
/// number.
///
/// The whole card is one button into the hall's ticket book ([onOpen]). It
/// reads the hall's own records ([cinemaRecordsProvider]), so a score set
/// inside a game is on this card the moment he comes back out.
///
/// Nothing here feeds the balance: this world weighs 0 (see
/// `MadarDefaults.planets`). A number on this card is a pleasure, never a
/// mark against him.
class GamesScoresCard extends ConsumerWidget {
  const GamesScoresCard({super.key, required this.onOpen, this.maxGames = 3});

  /// Opens the hall's ticket book.
  final void Function(BuildContext context) onOpen;

  /// How many games are listed before the line that counts the rest.
  final int maxGames;

  /// [records]'s scored games, best first (ties: more plays, then the id),
  /// each paired with the programme's entry while it is still on it.
  static List<(GameRecord, GameCatalogEntry?)> ranked(CinemaRecords records) {
    final scored =
        [
          for (final r in records.games.values)
            if (r.best > 0) r,
        ]..sort((a, b) {
          final byBest = b.best.compareTo(a.best);
          if (byBest != 0) return byBest;
          final byPlays = b.plays.compareTo(a.plays);
          return byPlays != 0 ? byPlays : a.gameId.compareTo(b.gameId);
        });
    return [for (final r in scored) (r, CinemaCatalog.byId(r.gameId))];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final f = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final records = ref.watch(cinemaRecordsProvider).value ?? CinemaRecords.empty;
    final rows = ranked(records);
    final shown = rows.take(maxGames).toList();
    final empty = shown.isEmpty;

    String nameOf((GameRecord, GameCatalogEntry?) row) => row.$2?.title(l) ?? row.$1.gameId;

    // One button, read once: the title, then each game with its best, then
    // how many games have a score at all.
    final label = [
      l.gamesWorldBestTitle,
      if (empty) l.gamesWorldBestEmpty,
      for (final row in shown) '${nameOf(row)} ${l.cinemaHallBestBadge(f.formatInt(row.$1.best))}',
      if (!empty) f.localizeDigits(l.gamesWorldPlayedGames(rows.length)),
    ].join(l.commonFactSeparator);

    final radius = BorderRadius.circular(t.radiusM);
    return MadarPressable(
      key: const ValueKey('games.scores'),
      onTap: () => onOpen(context),
      // It leads into the hall's ticket book: the app's navigation sound.
      sfx: Sfx.navigate,
      semanticLabel: label,
      excludeChildSemantics: true,
      focusRadius: radius,
      child: GlassCard(
        seed: 4,
        borderRadius: radius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_rounded, size: 20, color: t.gold),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    l.gamesWorldBestTitle,
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: t.textTertiary),
              ],
            ),
            const SizedBox(height: Space.m),
            if (empty)
              Text(l.gamesWorldBestEmpty, style: text.bodySmall?.copyWith(color: t.textTertiary, height: 1.4))
            else ...[
              for (final row in shown) ...[
                if (row != shown.first) const SizedBox(height: Space.s),
                _ScoreLine(name: nameOf(row), best: f.formatInt(row.$1.best), plays: row.$1.plays),
              ],
              const SizedBox(height: Space.m),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      f.localizeDigits(l.gamesWorldPlayedGames(rows.length)),
                      style: text.bodySmall?.copyWith(color: t.textTertiary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  Text(
                    l.gamesWorldBestSeeAll,
                    style: text.labelMedium?.copyWith(color: t.accent),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One game's line: its name, how often it was played, and its best score.
class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.name, required this.best, required this.plays});

  final String name;

  /// Already in the user's digits.
  final String best;
  final int plays;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final f = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                f.localizeDigits(l.savedGamesPlayCount(plays)),
                style: text.bodySmall?.copyWith(color: t.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: Space.m),
        Container(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s + 2, vertical: 3),
          decoration: BoxDecoration(
            color: t.accentSoft,
            borderRadius: BorderRadius.circular(t.radiusS),
            border: Border.all(color: t.glassBorder),
          ),
          child: Text(
            l.cinemaHallBestBadge(best),
            style: text.labelMedium?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
