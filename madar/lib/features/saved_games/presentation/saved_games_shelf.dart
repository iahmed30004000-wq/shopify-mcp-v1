import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/saved_games_providers.dart';
import '../domain/saved_web_game.dart';
import 'game_art.dart';
import 'saved_games_screen.dart';
import 'saved_games_ui.dart';

/// A cinema-style shelf of the user's saved web games for the Madar Cinema
/// hall: a header, a row of poster cards (tap to play, long-press for
/// edit / delete / open in browser / clear data) and an "Add" card. With no
/// games it shows one inviting card (never pre-filled games).
///
/// Place it anywhere; it sizes its own height ([posterWidth] × 1.42 plus the
/// header).
class SavedGamesShelf extends ConsumerWidget {
  const SavedGamesShelf({
    super.key,
    this.onSeeAll,
    this.showHeader = true,
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
    this.posterWidth = 124,
    this.maxPosters = 12,
    this.onDarkBackdrop = false,
  });

  /// "See all": defaults to pushing [SavedGamesScreen].
  final VoidCallback? onSeeAll;
  final bool showHeader;

  /// Horizontal inset of the header and the first / last poster.
  final EdgeInsetsGeometry padding;
  final double posterWidth;

  /// Posters shown before "See all" (the Add card follows them).
  final int maxPosters;

  /// Set when the host paints its own dark backdrop (e.g. a cinema lobby):
  /// under a light theme (Pearl) the shelf then uses the night palette so
  /// its text stays readable.
  final bool onDarkBackdrop;

  double get _posterHeight => posterWidth * 1.42;

  void _seeAll(BuildContext context) {
    final cb = onSeeAll;
    if (cb != null) {
      cb();
    } else {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SavedGamesScreen()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final async = ref.watch(savedWebGamesProvider);
    final games = async.value?.games ?? const <SavedWebGame>[];
    final loading = async.isLoading && async.value == null;
    final body = SizedBox(
      height: _posterHeight + Space.s,
      child: loading
          ? const Center(child: OrbitLoader(size: 28))
          : games.isEmpty
          ? Padding(
              padding: padding,
              child: _EmptyShelfCard(onAdd: () => SavedGamesActions.add(context, ref)),
            )
          : ListView.separated(
              key: const ValueKey('savedGames.shelf'),
              scrollDirection: Axis.horizontal,
              padding: padding.resolve(Directionality.of(context)).copyWith(bottom: Space.s),
              itemCount: games.take(maxPosters).length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: Space.m),
              itemBuilder: (context, i) {
                final shown = games.take(maxPosters).toList();
                if (i == shown.length) {
                  return _AddPoster(
                    width: posterWidth,
                    height: _posterHeight,
                    onTap: () => SavedGamesActions.add(context, ref),
                  );
                }
                return StaggerItem(
                  index: i,
                  from: EntranceFrom.start,
                  child: _ShelfPoster(game: shown[i], width: posterWidth, height: _posterHeight),
                );
              },
            ),
    );
    final content = !showHeader
        ? body
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: l.savedGamesShelfTitle,
                subtitle: l.savedGamesShelfSubtitle,
                actionLabel: games.isEmpty ? null : l.savedGamesSeeAll,
                onAction: games.isEmpty ? null : () => _seeAll(context),
                padding: padding,
              ),
              const SizedBox(height: Space.s),
              body,
            ],
          );
    if (!onDarkBackdrop || context.tokens.isDark) return content;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Theme(
      data: buildMadarTheme(MadarThemeId.lapis, arabic: arabic),
      child: content,
    );
  }
}

class _ShelfPoster extends ConsumerWidget {
  const _ShelfPoster({required this.game, required this.width, required this.height});

  final SavedWebGame game;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final f = context.formatter;
    final t = context.tokens;
    final now = ref.watch(savedGamesClockProvider)();
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusM),
          boxShadow: [
            BoxShadow(
              color: GameArtPalette.colors(game.art.hue).base.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ActionableItem(
          key: ValueKey('savedGames.shelf.${game.id}'),
          onTap: () => SavedGamesActions.play(context, game),
          actions: SavedGamesActions.itemActions(context, ref, game),
          swipeEnabled: false,
          borderRadius: BorderRadius.circular(t.radiusM),
          semanticLabel: l.savedGamesPlayGame(game.title),
          child: GamePoster(
            art: game.art,
            seed: game.id,
            title: game.title,
            caption: game.lastPlayedAt == null ? BidiIsolate.ltr(game.host) : lastPlayedLabel(l, f, game, now),
            badge: game.playCount == 0 ? l.savedGamesNew : null,
          ),
        ),
      ),
    );
  }
}

/// A ticket-stub "Add" card with a dashed outline.
class _AddPoster extends StatelessWidget {
  const _AddPoster({required this.width, required this.height, required this.onTap});

  final double width;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      key: const ValueKey('savedGames.shelfAdd'),
      onTap: onTap,
      sfx: Sfx.sheetOpen,
      semanticLabel: l.savedGamesAdd,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _DashedFramePainter(color: t.gold.withValues(alpha: 0.7), fill: t.glassFill, radius: t.radiusM),
          child: Padding(
            padding: const EdgeInsets.all(Space.m),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.accentSoft,
                    border: Border.all(color: t.accent.withValues(alpha: 0.6)),
                  ),
                  child: Icon(Icons.add_rounded, color: t.accent),
                ),
                const SizedBox(height: Space.m),
                Text(
                  l.savedGamesAdd,
                  textAlign: TextAlign.center,
                  style: text.titleSmall?.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: Space.xxs),
                Text(l.savedGamesAddCardHint, textAlign: TextAlign.center, style: text.labelSmall, maxLines: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyShelfCard extends StatelessWidget {
  const _EmptyShelfCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      key: const ValueKey('savedGames.shelfEmpty'),
      onTap: onAdd,
      semanticLabel: l.savedGamesAdd,
      padding: const EdgeInsetsDirectional.all(Space.l),
      child: Row(
        children: [
          const SizedBox(
            width: 72,
            height: 100,
            child: GamePoster(art: GameArt(glyph: 0, hue: 0), seed: 'madar-shelf-empty'),
          ),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.savedGamesShelfEmpty, style: text.bodyMedium),
                const SizedBox(height: Space.xs),
                Text(l.savedGamesEmptyStep2(savedGamesLinkExample), style: text.labelSmall),
                const SizedBox(height: Space.m),
                Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: t.accent),
                    const SizedBox(width: Space.xs),
                    Flexible(
                      child: Text(l.savedGamesAdd, style: text.labelLarge?.copyWith(color: t.accent)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedFramePainter extends CustomPainter {
  _DashedFramePainter({required this.color, required this.fill, required this.radius});

  final Color color;
  final Color fill;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(0.75), Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..color = fill);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = color;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 11) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter old) => old.color != color || old.fill != fill || old.radius != radius;
}
