import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show FieldShell, kitInputDecoration;
import '../../../core/sound/sound_api.dart';
import '../data/saved_games_providers.dart';
import '../domain/game_url.dart';
import '../domain/saved_web_game.dart';
import 'game_art.dart';
import 'saved_games_ui.dart';

/// Opens the add / edit sheet. Returns the finished record (not yet saved)
/// or null when dismissed. [initialText] may be a shared text containing a
/// link.
Future<SavedWebGame?> showGameEditorSheet(BuildContext context, {SavedWebGame? existing, String? initialText}) =>
    showInteractionSheet<SavedWebGame>(
      context,
      builder: (_) => GameEditorSheet(existing: existing, initialText: initialText),
    );

/// Link, name ("Fetch title" only on tap), icon (generated glyph/colour or –
/// on tap – the site's icon), orientation and notes of a saved game.
class GameEditorSheet extends ConsumerStatefulWidget {
  const GameEditorSheet({super.key, this.existing, this.initialText});

  final SavedWebGame? existing;
  final String? initialText;

  @override
  ConsumerState<GameEditorSheet> createState() => _GameEditorSheetState();
}

class _GameEditorSheetState extends ConsumerState<GameEditorSheet> {
  late final TextEditingController _url = TextEditingController(
    text: widget.existing?.url.toString() ?? _initialLink(widget.initialText),
  );
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late GameArt _art = widget.existing?.art ?? GameArt.seeded(_url.text.trim());
  late GameOrientation _orientation = widget.existing?.orientation ?? GameOrientation.auto;
  late bool _urlTouched = (widget.initialText ?? '').trim().isNotEmpty;
  bool _artChosen = false;
  bool _fetchingTitle = false;
  bool _fetchingIcon = false;
  String? _titleNote;
  String? _iconNote;
  String? _urlNote;

  static String _initialLink(String? text) {
    final t = (text ?? '').trim();
    return linkFromText(t);
  }

  @override
  void initState() {
    super.initState();
    _artChosen = widget.existing != null;
    _url.addListener(_onUrlChanged);
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  GameUrlCheck get _check => validateGameUrl(_url.text);

  void _onUrlChanged() {
    setState(() {
      _urlNote = null;
      if (!_artChosen && _art.favicon == null) _art = GameArt.seeded(_check.url?.toString() ?? _url.text.trim());
    });
  }

  SavedWebGame? _duplicateOf(Uri url) {
    final state = ref.read(savedWebGamesProvider).value;
    final dup = state?.byUrl(url);
    return dup == null || dup.id == widget.existing?.id ? null : dup;
  }

  String? _urlError(L10n l) {
    if (!_urlTouched) return null;
    final check = _check;
    final url = check.url;
    if (url != null) {
      final dup = _duplicateOf(url);
      return dup == null ? null : l.savedGamesUrlDuplicate(BidiIsolate.isolate(dup.title));
    }
    return switch (check.error!) {
      GameUrlError.empty => l.savedGamesUrlEmpty,
      GameUrlError.tooLong => l.savedGamesUrlTooLong,
      GameUrlError.notHttps => l.savedGamesUrlNotHttps,
      GameUrlError.unsupportedScheme => l.savedGamesUrlScheme,
      GameUrlError.malformed => l.savedGamesUrlMalformed,
      GameUrlError.credentials => l.savedGamesUrlCredentials,
    };
  }

  Future<void> _paste() async {
    final l = L10n.of(context);
    ClipboardData? data;
    try {
      data = await Clipboard.getData(Clipboard.kTextPlain);
    } on Object {
      data = null;
    }
    if (!mounted) return;
    final text = (data?.text ?? '').trim();
    final candidate = linkFromText(text);
    final link = candidate.isEmpty || validateGameUrl(candidate).error == GameUrlError.malformed ? null : candidate;
    if (link == null) {
      Fx.fire(Sfx.error);
      setState(() => _urlNote = l.savedGamesClipboardEmpty);
      return;
    }
    _url.text = link;
    _url.selection = TextSelection.collapsed(offset: link.length);
    setState(() => _urlTouched = true);
  }

  void _useHttps() {
    final fixed = httpsVersionOf(_url.text);
    if (fixed == null) return;
    _url.text = fixed;
    _url.selection = TextSelection.collapsed(offset: fixed.length);
  }

  Future<void> _fetchTitle() async {
    final url = _check.url;
    if (url == null || _fetchingTitle) return;
    final l = L10n.of(context);
    setState(() {
      _fetchingTitle = true;
      _titleNote = null;
    });
    final title = await ref.read(gameMetaFetcherProvider).fetchTitle(url);
    if (!mounted) return;
    setState(() {
      _fetchingTitle = false;
      if (title == null || title.isEmpty) {
        _titleNote = l.savedGamesFetchFailed;
      } else {
        _title.text = title;
        _title.selection = TextSelection.collapsed(offset: title.length);
      }
    });
    Fx.fire(title == null ? Sfx.error : Sfx.sparkle);
  }

  Future<void> _fetchIcon() async {
    final url = _check.url;
    if (url == null || _fetchingIcon) return;
    final l = L10n.of(context);
    setState(() {
      _fetchingIcon = true;
      _iconNote = null;
    });
    final png = await ref.read(gameMetaFetcherProvider).fetchIcon(url);
    if (!mounted) return;
    setState(() {
      _fetchingIcon = false;
      if (png == null) {
        _iconNote = l.savedGamesIconFailed;
      } else {
        _art = _art.copyWith(favicon: png);
        _artChosen = true;
      }
    });
    Fx.fire(png == null ? Sfx.error : Sfx.sparkle);
  }

  void _pick({int? glyph, int? hue}) {
    setState(() {
      _art = _art.copyWith(glyph: glyph, hue: hue, clearFavicon: glyph != null);
      _artChosen = true;
    });
  }

  void _shuffle() {
    final seed = DateTime.now().microsecondsSinceEpoch;
    _pick(
      glyph: (_art.glyph + 1 + seed % (SavedGamesLimits.glyphCount - 1)) % SavedGamesLimits.glyphCount,
      hue: (_art.hue + 1 + (seed ~/ 7) % (SavedGamesLimits.hueCount - 1)) % SavedGamesLimits.hueCount,
    );
  }

  void _save() {
    final url = _check.url;
    setState(() => _urlTouched = true);
    if (url == null || _duplicateOf(url) != null) {
      Fx.fire(Sfx.error);
      return;
    }
    final typed = clampText(_title.text, SavedGamesLimits.maxTitle);
    final title = typed.isEmpty ? url.host : typed;
    final notes = clampText(_notes.text, SavedGamesLimits.maxNotes, singleLine: false);
    final existing = widget.existing;
    final game = existing != null
        ? existing.copyWith(title: title, url: url, notes: notes, orientation: _orientation, art: _art)
        : SavedWebGame(
            id: ref.read(savedGamesIdProvider)(),
            title: title,
            url: url,
            notes: notes,
            orientation: _orientation,
            art: _art,
            addedAt: ref.read(savedGamesClockProvider)(),
          );
    Navigator.of(context).pop(game.bounded());
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final check = _check;
    final url = check.url;
    final urlError = _urlError(l);
    final existing = widget.existing;
    final title = _title.text.trim().isEmpty ? (url?.host ?? l.savedGamesNameHint) : _title.text.trim();

    return InteractionSheetFrame(
      title: existing == null ? l.savedGamesAddTitle : l.savedGamesEditTitle,
      subtitle: l.savedGamesAddSubtitle,
      icon: Icons.sports_esports_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PreviewRow(art: _art, seed: existing?.id ?? _url.text, title: title, host: url?.host),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.savedGamesUrlLabel,
            icon: Icons.link_rounded,
            error: urlError ?? _urlNote,
            trailing: _MiniAction(icon: Icons.content_paste_rounded, label: l.savedGamesPaste, onTap: _paste),
            child: TextField(
              key: const ValueKey('savedGames.url'),
              controller: _url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
              textDirection: TextDirection.ltr,
              maxLength: SavedGamesLimits.maxUrl,
              style: text.bodyMedium,
              decoration: kitInputDecoration(context, hint: l.savedGamesUrlHint, error: urlError != null),
              onSubmitted: (_) => setState(() => _urlTouched = true),
              onTapOutside: (_) {
                if (_url.text.trim().isNotEmpty && !_urlTouched) setState(() => _urlTouched = true);
              },
            ),
          ),
          if (check.error == GameUrlError.notHttps && _urlTouched)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.s),
                child: MadarChip(label: l.savedGamesUseHttps, icon: Icons.lock_rounded, onSelected: (_) => _useHttps()),
              ),
            ),
          if (url != null && urlError == null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.s),
              child: Wrap(
                spacing: Space.s,
                runSpacing: Space.xs,
                children: [
                  _Badge(icon: Icons.lock_rounded, label: l.savedGamesSecureBadge, color: t.success),
                  if (isClaudeArtifactUrl(url))
                    _Badge(icon: Icons.auto_awesome_rounded, label: l.savedGamesArtifactBadge, color: t.gold),
                ],
              ),
            ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.savedGamesNameLabel,
            icon: Icons.title_rounded,
            trailing: _MiniAction(
              icon: Icons.travel_explore_rounded,
              label: l.savedGamesFetchTitle,
              busy: _fetchingTitle,
              onTap: url == null ? null : _fetchTitle,
            ),
            error: _titleNote,
            child: TextField(
              key: const ValueKey('savedGames.title'),
              controller: _title,
              textInputAction: TextInputAction.next,
              maxLength: SavedGamesLimits.maxTitle,
              style: text.bodyMedium,
              decoration: kitInputDecoration(context, hint: url?.host ?? l.savedGamesNameHint),
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.savedGamesIconLabel,
            icon: Icons.palette_outlined,
            error: _iconNote,
            child: _IconPicker(
              art: _art,
              busy: _fetchingIcon,
              onGlyph: (g) => _pick(glyph: g),
              onHue: (h) => _pick(hue: h),
              onShuffle: _shuffle,
              onSiteIcon: url == null ? null : _fetchIcon,
              onRemoveSiteIcon: () => setState(() => _art = _art.copyWith(clearFavicon: true)),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.s, start: Space.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: t.textTertiary),
                const SizedBox(width: Space.xs),
                Expanded(child: Text(l.savedGamesFetchNote, style: text.labelSmall)),
              ],
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.savedGamesOrientationLabel,
            icon: Icons.screen_rotation_rounded,
            child: ChoicePills<GameOrientation>.single(
              options: [
                ChoiceOption(
                  value: GameOrientation.auto,
                  label: l.savedGamesOrientationAuto,
                  icon: Icons.screen_rotation_alt_rounded,
                ),
                ChoiceOption(
                  value: GameOrientation.portrait,
                  label: l.savedGamesOrientationPortrait,
                  icon: Icons.stay_current_portrait_rounded,
                ),
                ChoiceOption(
                  value: GameOrientation.landscape,
                  label: l.savedGamesOrientationLandscape,
                  icon: Icons.stay_current_landscape_rounded,
                ),
              ],
              selected: _orientation,
              onChanged: (o) => setState(() => _orientation = o ?? _orientation),
            ),
          ),
          const SizedBox(height: Space.l),
          FieldShell(
            label: l.savedGamesNotesLabel,
            icon: Icons.sticky_note_2_outlined,
            optional: true,
            child: TextField(
              key: const ValueKey('savedGames.notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              maxLength: SavedGamesLimits.maxNotes,
              style: text.bodyMedium,
              decoration: kitInputDecoration(context, hint: l.savedGamesNotesHint),
            ),
          ),
          if (existing != null) ...[const SizedBox(height: Space.l), _ExistingFooter(game: existing)],
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: l.savedGamesCancel,
              sfx: Sfx.back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: SheetButton(
              key: const ValueKey('savedGames.save'),
              label: existing == null ? l.savedGamesAdd : l.savedGamesSave,
              primary: true,
              icon: existing == null ? Icons.add_rounded : Icons.check_rounded,
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.art, required this.seed, required this.title, required this.host});

  final GameArt art;
  final String seed;
  final String title;
  final String? host;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(
          width: 78,
          height: 108,
          child: GamePoster(art: art, seed: seed),
        ),
        const SizedBox(width: Space.l),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textDirection: BidiIsolate.directionOf(title),
                textAlign: uiStartAlign(context),
                style: text.titleLarge,
              ),
              if (host != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xxs),
                  child: Text(
                    BidiIsolate.ltr(host!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.xxs, Space.s + 2, Space.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: Space.xs),
          Text(label, style: text.labelMedium?.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// A compact text action beside a field label.
class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.icon, required this.label, required this.onTap, this.busy = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null && !busy;
    final color = enabled ? t.accent : t.textTertiary;
    return MadarPressable(
      onTap: enabled ? onTap : null,
      enabled: enabled,
      semanticLabel: label,
      focusRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox.square(dimension: 14, child: OrbitLoader(size: 14, color: t.accent))
            else
              Icon(icon, size: 15, color: color),
            const SizedBox(width: Space.xs),
            Text(label, style: text.labelLarge?.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({
    required this.art,
    required this.busy,
    required this.onGlyph,
    required this.onHue,
    required this.onShuffle,
    required this.onSiteIcon,
    required this.onRemoveSiteIcon,
  });

  final GameArt art;
  final bool busy;
  final ValueChanged<int> onGlyph;
  final ValueChanged<int> onHue;
  final VoidCallback onShuffle;
  final VoidCallback? onSiteIcon;
  final VoidCallback onRemoveSiteIcon;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final f = context.formatter;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            GameIconTile(art: art, size: 56),
            const SizedBox(width: Space.m),
            Expanded(
              child: Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [
                  MadarButton(
                    label: l.savedGamesShuffleIcon,
                    icon: Icons.shuffle_rounded,
                    variant: MadarButtonVariant.secondary,
                    size: MadarButtonSize.small,
                    onPressed: onShuffle,
                  ),
                  if (art.hasFavicon)
                    MadarButton(
                      label: l.savedGamesRemoveSiteIcon,
                      icon: Icons.hide_image_outlined,
                      variant: MadarButtonVariant.ghost,
                      size: MadarButtonSize.small,
                      onPressed: onRemoveSiteIcon,
                    )
                  else
                    MadarButton(
                      label: l.savedGamesUseSiteIcon,
                      icon: Icons.language_rounded,
                      variant: MadarButtonVariant.ghost,
                      size: MadarButtonSize.small,
                      loading: busy,
                      onPressed: onSiteIcon,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.m),
        LayoutBuilder(
          builder: (context, box) {
            // Eight chips a row: two even rows of glyphs, one of colours.
            const perRow = 8;
            final size = ((box.maxWidth - Space.s * (perRow - 1)) / perRow).floorToDouble().clamp(32.0, 48.0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (var i = 0; i < SavedGamesLimits.glyphCount; i++)
                      _Choice(
                        size: size,
                        selected: !art.hasFavicon && art.glyph == i,
                        semanticLabel: l.savedGamesGlyph(f.formatInt(i + 1)),
                        onTap: () => onGlyph(i),
                        child: Icon(GameArtPalette.glyph(i), size: size * 0.5, color: t.textPrimary),
                      ),
                  ],
                ),
                const SizedBox(height: Space.m),
                Wrap(
                  spacing: Space.s,
                  runSpacing: Space.s,
                  children: [
                    for (var i = 0; i < SavedGamesLimits.hueCount; i++)
                      _Choice(
                        size: size,
                        selected: art.hue == i,
                        circle: true,
                        semanticLabel: l.savedGamesColor(f.formatInt(i + 1)),
                        onTap: () => onHue(i),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [GameArtPalette.colors(i).light, GameArtPalette.colors(i).deep],
                            ),
                          ),
                          child: SizedBox.square(dimension: size * 0.65),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
    this.circle = false,
    this.size = 40,
  });

  final double size;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = circle ? BorderRadius.circular(99) : BorderRadius.circular(t.radiusS);
    return MadarPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: semanticLabel,
      focusRadius: radius,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: radius,
          color: selected ? t.accentSoft : t.glassFill,
          border: Border.all(color: selected ? t.accent : t.glassBorder, width: selected ? 1.6 : 0.8),
          boxShadow: selected ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 10)] : null,
        ),
        child: child,
      ),
    );
  }
}

class _ExistingFooter extends ConsumerWidget {
  const _ExistingFooter({required this.game});

  final SavedWebGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final f = context.formatter;
    final text = Theme.of(context).textTheme;
    final now = ref.read(savedGamesClockProvider)();
    final game = ref.watch(savedWebGamesProvider).value?.byId(this.game.id) ?? this.game;
    return GlassCard(
      padding: const EdgeInsetsDirectional.all(Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.savedGamesStats(
              l.savedGamesAddedOn(f.formatDate(game.addedAt, style: MadarDateStyle.dayMonth)),
              playCountLabel(l, f, game),
            ),
            style: text.bodySmall,
          ),
          if (game.lastPlayedAt != null)
            Text(lastPlayedLabel(l, f, game, now), style: text.bodySmall?.copyWith(color: t.textSecondary)),
          const SizedBox(height: Space.s),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              label: game.clearDataPending ? l.savedGamesClearDataPending : l.savedGamesClearData,
              icon: Icons.cleaning_services_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              onPressed: game.clearDataPending ? null : () => SavedGamesActions.scheduleClearData(context, ref, game),
            ),
          ),
        ],
      ),
    );
  }
}
