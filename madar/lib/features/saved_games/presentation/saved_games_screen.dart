import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'saved_games_ui.dart';

/// All saved web games: a poster grid or a reorderable list, add / edit /
/// delete (with undo), and an empty state explaining how to add one.
class SavedGamesScreen extends ConsumerStatefulWidget {
  const SavedGamesScreen({super.key, this.initialSharedText});

  /// Text shared to Madar (e.g. from a browser's Share menu): the add sheet
  /// opens pre-filled with the link it contains.
  final String? initialSharedText;

  @override
  ConsumerState<SavedGamesScreen> createState() => _SavedGamesScreenState();
}

class _SavedGamesScreenState extends ConsumerState<SavedGamesScreen> {
  @override
  void initState() {
    super.initState();
    final shared = widget.initialSharedText;
    if (shared != null && shared.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(SavedGamesActions.add(context, ref, initialText: shared));
      });
    }
  }

  Future<void> _pasteAndAdd() async {
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on Object {
      data = null;
    }
    if (!mounted) return;
    await SavedGamesActions.add(context, ref, initialText: data?.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final async = ref.watch(savedWebGamesProvider);
    final state = async.value;
    final hasGames = state != null && state.games.isNotEmpty;
    final layout = state?.layout ?? SavedGamesLayout.grid;
    return MadarScaffold(
      title: l.savedGamesTitle,
      actions: [
        if (hasGames)
          MadarButton.icon(
            key: const ValueKey('savedGames.layout'),
            icon: layout == SavedGamesLayout.grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            semanticLabel: layout == SavedGamesLayout.grid ? l.savedGamesLayoutList : l.savedGamesLayoutGrid,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.toggleOn,
            onPressed: () => ref
                .read(savedWebGamesStoreProvider)
                .setLayout(layout == SavedGamesLayout.grid ? SavedGamesLayout.list : SavedGamesLayout.grid),
          ),
        if (hasGames)
          MadarButton.icon(
            key: const ValueKey('savedGames.clearAll'),
            icon: Icons.cleaning_services_outlined,
            semanticLabel: l.savedGamesClearAll,
            variant: MadarButtonVariant.ghost,
            onPressed: () => SavedGamesActions.clearAllData(context, ref),
          ),
      ],
      floatingAction: hasGames
          ? MadarButton(
              key: const ValueKey('savedGames.fab'),
              label: l.savedGamesAdd,
              icon: Icons.add_rounded,
              size: MadarButtonSize.large,
              onPressed: () => SavedGamesActions.add(context, ref),
            )
          : null,
      body: switch (async) {
        AsyncData(:final value) when value.games.isEmpty => _EmptyGames(
          onAdd: () => SavedGamesActions.add(context, ref),
          onPaste: _pasteAndAdd,
        ),
        AsyncData(:final value) =>
          value.layout == SavedGamesLayout.grid ? _PosterGrid(games: value.games) : _ReorderList(games: value.games),
        AsyncError() => _EmptyGames(onAdd: () => SavedGamesActions.add(context, ref), onPaste: _pasteAndAdd),
        _ => const Center(child: OrbitLoader()),
      },
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.xxxl + Space.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_moon_outlined, size: 16, color: t.textTertiary),
          const SizedBox(width: Space.s),
          Expanded(child: Text(L10n.of(context).savedGamesPrivacyNote, style: text.labelMedium)),
        ],
      ),
    );
  }
}

/// Poster grid (cinema one-sheets), two or more columns.
class _PosterGrid extends ConsumerWidget {
  const _PosterGrid({required this.games});

  final List<SavedWebGame> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final f = context.formatter;
    final t = context.tokens;
    final now = ref.watch(savedGamesClockProvider)();
    return LayoutBuilder(
      builder: (context, box) {
        final columns = (box.maxWidth / 190).floor().clamp(2, 5);
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, 0),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: Space.l,
                  crossAxisSpacing: Space.l,
                  childAspectRatio: 0.7,
                ),
                itemCount: games.length,
                itemBuilder: (context, i) {
                  final g = games[i];
                  return StaggerItem(
                    index: i,
                    child: ActionableItem(
                      key: ValueKey('savedGames.poster.${g.id}'),
                      onTap: () => SavedGamesActions.play(context, g),
                      actions: SavedGamesActions.itemActions(context, ref, g),
                      swipeEnabled: false,
                      borderRadius: BorderRadius.circular(t.radiusM),
                      semanticLabel: l.savedGamesPlayGame(g.title),
                      child: GamePoster(
                        art: g.art,
                        seed: g.id,
                        title: g.title,
                        caption: g.lastPlayedAt == null ? BidiIsolate.ltr(g.host) : lastPlayedLabel(l, f, g, now),
                        badge: g.playCount == 0 ? l.savedGamesNew : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: _PrivacyNote()),
          ],
        );
      },
    );
  }
}

/// Reorderable rows with drag handles.
class _ReorderList extends ConsumerWidget {
  const _ReorderList({required this.games});

  final List<SavedWebGame> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return ReorderableGlassList<SavedWebGame>(
      items: games,
      itemKey: (g) => g.id,
      onReorder: (order) => ref.read(savedWebGamesStoreProvider).reorder([for (final g in order) g.id]),
      header: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Space.m, start: Space.xxs),
        child: Text(l.savedGamesReorderHint, style: text.labelMedium),
      ),
      footer: const _PrivacyNote(),
      itemBuilder: (context, g, index, handle) => _GameRow(game: g, handle: handle),
    );
  }
}

class _GameRow extends ConsumerWidget {
  const _GameRow({required this.game, required this.handle});

  final SavedWebGame game;
  final Widget handle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final f = context.formatter;
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final now = ref.watch(savedGamesClockProvider)();
    return ActionableItem(
      key: ValueKey('savedGames.row.${game.id}'),
      onTap: () => SavedGamesActions.play(context, game),
      actions: SavedGamesActions.itemActions(context, ref, game),
      semanticLabel: l.savedGamesPlayGame(game.title),
      quickActions: [
        QuickAction(
          icon: Icons.edit_rounded,
          label: l.savedGamesEdit,
          onPressed: () async {
            await SavedGamesActions.edit(context, ref, game);
            return null;
          },
        ),
        QuickAction(
          icon: Icons.open_in_new_rounded,
          label: l.savedGamesOpenExternal,
          tone: ActionTone.info,
          onPressed: () async {
            await SavedGamesActions.openExternally(context, ref, game);
            return null;
          },
        ),
      ],
      child: GlassCard(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.xs, Space.m),
        child: Row(
          children: [
            GameIconTile(art: game.art, size: 52),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: BidiIsolate.directionOf(game.title),
                    textAlign: uiStartAlign(context),
                    style: text.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    BidiIsolate.ltr(game.host),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(color: t.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.clearDataPending
                        ? l.savedGamesClearDataPending
                        : '${lastPlayedLabel(l, f, game, now)} · ${playCountLabel(l, f, game)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: game.clearDataPending ? t.warning : null),
                  ),
                ],
              ),
            ),
            MadarButton.icon(
              icon: Icons.play_arrow_rounded,
              semanticLabel: l.savedGamesPlayGame(game.title),
              variant: MadarButtonVariant.primary,
              size: MadarButtonSize.small,
              sfx: Sfx.navigate,
              onPressed: () => SavedGamesActions.play(context, game),
            ),
            handle,
          ],
        ),
      ),
    );
  }
}

/// How to add a game (no games are ever pre-filled).
class _EmptyGames extends StatelessWidget {
  const _EmptyGames({required this.onAdd, required this.onPaste});

  final VoidCallback onAdd;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final steps = [l.savedGamesEmptyStep1, l.savedGamesEmptyStep2(savedGamesLinkExample), l.savedGamesEmptyStep3];
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.m, Space.gutter, Space.xl),
      children: [
        StaggerIn(
          children: [
            const _PosterFan(),
            const SizedBox(height: Space.xl),
            Text(l.savedGamesEmptyTitle, textAlign: TextAlign.center, style: text.headlineMedium),
            const SizedBox(height: Space.s),
            Text(
              l.savedGamesEmptyBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: Space.xl),
            GlassPanel(
              padding: const EdgeInsetsDirectional.all(Space.l),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++) ...[
                    if (i > 0) const SizedBox(height: Space.m),
                    _Step(number: context.formatter.formatInt(i + 1), text: steps[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Space.xl),
            MadarButton(
              key: const ValueKey('savedGames.emptyAdd'),
              label: l.savedGamesAdd,
              icon: Icons.add_rounded,
              size: MadarButtonSize.large,
              expand: true,
              onPressed: onAdd,
            ),
            const SizedBox(height: Space.m),
            MadarButton(
              label: l.savedGamesPaste,
              icon: Icons.content_paste_rounded,
              variant: MadarButtonVariant.secondary,
              expand: true,
              onPressed: onPaste,
            ),
            const _PrivacyNote(),
          ],
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.accentSoft,
            border: Border.all(color: t.gold.withValues(alpha: 0.6), width: 0.9),
          ),
          child: Text(number, style: style.labelLarge?.copyWith(color: t.gold)),
        ),
        const SizedBox(width: Space.m),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, style: style.bodyMedium),
          ),
        ),
      ],
    );
  }
}

/// Three generated posters fanned like a marquee (illustration only: no
/// titles, no real games).
class _PosterFan extends StatelessWidget {
  const _PosterFan();

  @override
  Widget build(BuildContext context) {
    const arts = [GameArt(glyph: 1, hue: 3), GameArt(glyph: 0, hue: 0), GameArt(glyph: 2, hue: 5)];
    return ExcludeSemantics(
      child: SizedBox(
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final (i, angle, dx) in const [(0, -0.16, -84.0), (2, 0.16, 84.0), (1, 0.0, 0.0)])
              Transform.translate(
                offset: Offset(dx, i == 1 ? -4 : 10),
                child: Transform.rotate(
                  angle: angle,
                  child: SizedBox(
                    width: i == 1 ? 124 : 108,
                    height: i == 1 ? 172 : 150,
                    child: Opacity(
                      opacity: i == 1 ? 1 : 0.82,
                      child: GamePoster(art: arts[i], seed: 'madar-empty-$i', glyphScale: 1.1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
