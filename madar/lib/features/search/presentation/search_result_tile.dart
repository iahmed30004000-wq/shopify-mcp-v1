import 'package:flutter/material.dart';

import '../../../core/design/themes.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../data/quran_search_source.dart';
import '../domain/search_doc.dart';
import 'search_visuals.dart';

/// One search result: a planet-coloured orb with the module's icon, the
/// title and subtitle with the matches lit, a snippet of the body around
/// the match, and the record's date at the trailing edge.
class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.hit,
    this.onTap,
    this.icon = Icons.search_rounded,
    this.color,
    this.moduleLabel,
    this.selected = false,
    this.now,
  });

  final SearchHit hit;
  final VoidCallback? onTap;

  /// The module's icon (in the orb).
  final IconData icon;

  /// The planet's colour (defaults to the accent).
  final Color? color;

  /// Shown under the text when results of several modules are mixed.
  final String? moduleLabel;

  /// Keyboard selection: drawn with an accent rim.
  final bool selected;

  /// "Now" for today / yesterday dates (default: the clock).
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final doc = hit.doc;
    final tint = color ?? t.accent;
    final lit = TextStyle(
      color: t.textPrimary,
      fontWeight: FontWeight.w700,
      backgroundColor: t.accent.withValues(alpha: t.isDark ? 0.28 : 0.18),
    );
    final date = doc.date == null ? null : SearchVisuals.date(doc.date!, now ?? DateTime.now(), l, fmt);
    final quran = doc.refTable == QuranSearchSource.refTable;
    // Each text runs in its own direction (see [searchTextDirection]) but
    // lines up with the app's reading start, like the rest of the list.
    final start = Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    final snippetStyle = quran
        ? MadarTypography.quran(t, size: 19).copyWith(height: 1.75, color: t.textSecondary)
        : text.bodySmall!.copyWith(color: t.textSecondary, height: 1.45);

    final semantics = [
      doc.title,
      if (doc.subtitle.isNotEmpty) doc.subtitle,
      if (hit.snippet.isNotEmpty) hit.snippet,
      ?moduleLabel,
      ?date,
    ].join('، ');

    return GlassCard(
      onTap: onTap,
      semanticLabel: semantics,
      borderColor: selected ? t.accent : null,
      glowColor: selected ? t.accentGlow : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.l, Space.m),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Orb(icon: icon, color: tint),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text.rich(
                        searchHighlightSpan(
                          doc.title,
                          hit.titleRanges,
                          text.titleSmall!.copyWith(color: t.textPrimary, height: 1.35),
                          lit,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textDirection: searchTextDirection(doc.title),
                        textAlign: start,
                      ),
                    ),
                    if (date != null)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(start: Space.s, top: 2),
                        child: Text(date, style: text.labelSmall!.copyWith(color: t.textTertiary)),
                      ),
                  ],
                ),
                if (doc.subtitle.isNotEmpty) ...[
                  const SizedBox(height: Space.xxs),
                  Text.rich(
                    searchHighlightSpan(doc.subtitle, hit.subtitleRanges, text.bodySmall!.copyWith(color: t.textSecondary), lit),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: searchTextDirection(doc.subtitle),
                    textAlign: start,
                  ),
                ],
                if (hit.snippet.isNotEmpty) ...[
                  const SizedBox(height: Space.xs),
                  Text.rich(
                    searchHighlightSpan(hit.snippet, hit.snippetRanges, snippetStyle, lit),
                    maxLines: quran ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: quran ? TextDirection.rtl : searchTextDirection(hit.snippet),
                    textAlign: quran ? null : start,
                  ),
                ],
                if (moduleLabel != null) ...[
                  const SizedBox(height: Space.xs),
                  Text(moduleLabel!, style: text.labelSmall!.copyWith(color: tint.withValues(alpha: 0.95))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small planet: the module's icon on a lit sphere of the planet colour.
class _Orb extends StatelessWidget {
  const _Orb({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static const double size = 36;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final palette = PlanetPalettes.fromColor(color);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 0.95,
            colors: [palette.glow, color, palette.deep],
            stops: const [0, 0.55, 1],
          ),
          boxShadow: [BoxShadow(color: color.withValues(alpha: t.isDark ? 0.45 : 0.25), blurRadius: 10)],
        ),
        // Dark ink on the bright planets (Money's mint, Faith's gold).
        child: Icon(icon, size: 18, color: color.computeLuminance() > 0.4 ? palette.deep : Colors.white),
      ),
    );
  }
}
