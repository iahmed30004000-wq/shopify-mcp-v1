import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/quran/ayah.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/quran_com_client.dart';
import '../../data/quran_providers.dart';
import '../../domain/quran_meta.dart';
import '../quran_labels.dart';
import 'ayah_spans.dart';
import 'mushaf_page.dart';
import 'quran_ornaments.dart';

/// One ayah as a card: number medallion, sajdah / reciting badges, quick
/// actions, the text (tajweed) and optionally its translation.
class VerseCard extends StatelessWidget {
  const VerseCard({
    super.key,
    required this.content,
    required this.surah,
    required this.fontSize,
    required this.tajweed,
    this.translation,
    this.marks = const MushafMarks(),
    this.sajdah = false,
    this.onTap,
    this.onPlay,
    this.onBookmark,
  });

  final AyahContent content;
  final SurahInfo surah;
  final double fontSize;
  final bool tajweed;
  final String? translation;
  final MushafMarks marks;
  final bool sajdah;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onBookmark;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final ref = content.ref;
    final playing = marks.playing == ref;
    final selected = marks.selected == ref;
    final flash = marks.flash == ref;
    final bookmarked = marks.bookmarks.containsKey(ref);
    final bookmarkColor = bookmarked ? Color(marks.bookmarks[ref] ?? t.accent.toARGB32()) : null;
    final base = MadarTypography.quran(t, size: fontSize).copyWith(height: 1.9);
    return GlassCard(
      onTap: onTap,
      semanticLabel: l.quranAyahSemantics(fmt.formatInt(ref.ayah), l.quranSurahName(surah)),
      borderColor: playing
          ? t.gold
          : selected || flash
          ? t.accent
          : null,
      glowColor: playing ? t.accentGlow : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AyahMedallion(label: fmt.formatInt(ref.ayah), size: 38, active: playing, color: bookmarkColor),
              const SizedBox(width: Space.s),
              if (playing) _Badge(label: l.quranNowReciting, color: t.gold, icon: Icons.graphic_eq_rounded),
              if (sajdah) ...[
                if (playing) const SizedBox(width: Space.xs),
                _Badge(label: l.quranSajdah, color: t.info, icon: Icons.south_rounded),
              ],
              const Spacer(),
              if (onPlay != null)
                MadarButton.icon(
                  icon: playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                  onPressed: onPlay,
                  semanticLabel: l.quranActionPlay,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                ),
              if (onBookmark != null)
                MadarButton.icon(
                  icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  onPressed: onBookmark,
                  semanticLabel: l.quranActionBookmark,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                ),
            ],
          ),
          Text.rich(
            TextSpan(
              children: AyahSpans.ayah(
                content,
                base,
                t,
                paint: AyahPaint(
                  tajweed: tajweed,
                  markerColor: bookmarkColor,
                  highlight: playing ? t.gold.withValues(alpha: t.isDark ? 0.12 : 0.1) : null,
                ),
              ),
            ),
            textAlign: TextAlign.start,
            textDirection: TextDirection.rtl,
            textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: false),
          ),
          if (translation != null) ...[
            const SizedBox(height: Space.s),
            Container(height: 1, color: t.glassBorder),
            const SizedBox(height: Space.s),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                translation!,
                style: text.bodyMedium!.copyWith(
                  fontFamily: MadarTypography.uiFamily,
                  color: t.textSecondary,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(t.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: Space.xxs),
          Text(label, style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color)),
        ],
      ),
    );
  }
}

/// A sura's ayat as cards, opened at [anchor] (the list grows both ways
/// from it, so any ayah opens instantly), with the sura's title and basmala
/// on top and the next sura at the end. Reports which ayat are on screen.
class SurahVerseList extends StatefulWidget {
  const SurahVerseList({
    super.key,
    required this.surah,
    required this.anchor,
    required this.content,
    required this.fontSize,
    required this.tajweed,
    this.translation,
    this.marks = const MushafMarks(),
    this.onAyahTap,
    this.onPlay,
    this.onBookmark,
    this.onVisible,
    this.onOpenSurah,
    this.onActivity,
  });

  final SurahInfo surah;
  final int anchor;
  final QuranContent content;
  final double fontSize;
  final bool tajweed;
  final QuranTranslation? translation;
  final MushafMarks marks;
  final void Function(AyahRef ayah)? onAyahTap;
  final void Function(AyahRef ayah)? onPlay;
  final void Function(AyahRef ayah)? onBookmark;

  /// Absolute indices of the ayat on screen, top first.
  final void Function(List<int> indices)? onVisible;

  /// Go to another sura (the neighbours' buttons).
  final void Function(int surah)? onOpenSurah;

  /// Scrolling (the reading tracker's sign of life).
  final VoidCallback? onActivity;

  @override
  State<SurahVerseList> createState() => SurahVerseListState();
}

class SurahVerseListState extends State<SurahVerseList> {
  final ScrollController _controller = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  final GlobalKey _viewport = GlobalKey();
  final Key _center = UniqueKey();
  Timer? _visibleTimer;

  GlobalKey _keyFor(int ayah) => _keys.putIfAbsent(ayah, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisible());
  }

  @override
  void didUpdateWidget(SurahVerseList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surah.number != widget.surah.number || oldWidget.anchor != widget.anchor) {
      _keys.clear();
      if (_controller.hasClients) _controller.jumpTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) => _reportVisible());
    }
  }

  @override
  void dispose() {
    _visibleTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Scrolls [ayah] of this sura into view; false when its card is not
  /// built (the reader then re-anchors the list).
  bool reveal(int ayah, {bool animate = true}) {
    final ctx = _keys[ayah]?.currentContext;
    if (ctx == null) return false;
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.12,
        duration: animate && !context.reducedMotion ? MadarMotion.long : Duration.zero,
        curve: MadarMotion.standard,
      ),
    );
    return true;
  }

  void _reportVisible() {
    if (!mounted || widget.onVisible == null) return;
    final viewport = _viewport.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final bottom = top + viewport.size.height;
    final visible = <(double, int)>[];
    _keys.forEach((ayah, key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) return;
      final y = box.localToGlobal(Offset.zero).dy;
      final h = box.size.height;
      final shown = (y + h).clamp(top, bottom) - y.clamp(top, bottom);
      if (shown >= h * 0.5 || shown >= viewport.size.height * 0.4) {
        visible.add((y, widget.surah.firstIndex + ayah - 1));
      }
    });
    visible.sort((a, b) => a.$1.compareTo(b.$1));
    widget.onVisible!([for (final v in visible) v.$2]);
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification && n.dragDetails != null) widget.onActivity?.call();
    if (n is ScrollEndNotification) {
      _visibleTimer?.cancel();
      _visibleTimer = Timer(const Duration(milliseconds: 250), _reportVisible);
    }
    return false;
  }

  Widget _card(BuildContext context, int ayah) {
    final surah = widget.surah;
    final index = surah.firstIndex + ayah - 1;
    final content = widget.content.ayah(index);
    final ref = content.ref;
    return Padding(
      key: _keyFor(ayah),
      padding: const EdgeInsets.only(bottom: Space.m),
      child: VerseCard(
        content: content,
        surah: surah,
        fontSize: widget.fontSize,
        tajweed: widget.tajweed,
        translation: widget.translation?.verses[ref],
        marks: widget.marks,
        sajdah: widget.content.meta.sajdahAt(ref) != null,
        onTap: widget.onAyahTap == null ? null : () => widget.onAyahTap!(ref),
        onPlay: widget.onPlay == null ? null : () => widget.onPlay!(ref),
        onBookmark: widget.onBookmark == null ? null : () => widget.onBookmark!(ref),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final surah = widget.surah;
    final basmala = widget.content.basmala(surah);
    final meta = widget.content.meta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (surah.number > 1 && widget.onOpenSurah != null)
          Align(
            alignment: AlignmentDirectional.center,
            child: MadarButton(
              label: l.quranPrevSurah(l.quranSurahName(meta.surah(surah.number - 1))),
              icon: Icons.keyboard_arrow_up_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              sfx: Sfx.navigate,
              onPressed: () => widget.onOpenSurah!(surah.number - 1),
            ),
          ),
        const SizedBox(height: Space.s),
        SurahCartouche(
          surah: surah,
          subtitle: l.quranJoin([
            if (!quranArabicUi(context)) '${surah.nameEnglish} · ${surah.meaningEnglish}',
            surah.makki ? l.quranMakki : l.quranMadani,
            fmt.localizeDigits(l.quranAyatCount(surah.ayahCount)),
          ]),
        ),
        if (basmala != null) ...[
          const SizedBox(height: Space.s),
          BasmalaLine(
            text: basmala.$1,
            marks: basmala.$2,
            fontSize: widget.fontSize,
            tajweed: widget.tajweed,
            highlight: widget.marks.playingBasmala == surah.number ? MushafMarks.playingColor(context.tokens) : null,
          ),
        ],
        const SizedBox(height: Space.m),
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final l = L10n.of(context);
    final meta = widget.content.meta;
    final next = widget.surah.number < QuranMeta.surahCount ? meta.surah(widget.surah.number + 1) : null;
    return Padding(
      padding: const EdgeInsets.only(top: Space.s, bottom: Space.xxxl),
      child: Column(
        children: [
          const MadarDivider(),
          if (next != null && widget.onOpenSurah != null)
            MadarButton(
              label: l.quranNextSurah(l.quranSurahName(next)),
              trailingIcon: Icons.keyboard_arrow_down_rounded,
              variant: MadarButtonVariant.secondary,
              sfx: Sfx.navigate,
              onPressed: () => widget.onOpenSurah!(next.number),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surah = widget.surah;
    final anchor = widget.anchor.clamp(1, surah.ayahCount);
    final before = anchor - 1;
    const padding = EdgeInsets.symmetric(horizontal: Space.gutter);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        key: _viewport,
        controller: _controller,
        center: _center,
        slivers: [
          if (anchor > 1)
            SliverPadding(
              padding: padding,
              sliver: SliverToBoxAdapter(child: _header(context)),
            ),
          SliverPadding(
            padding: padding,
            sliver: SliverList.builder(itemCount: before, itemBuilder: (context, i) => _card(context, anchor - 1 - i)),
          ),
          SliverPadding(
            key: _center,
            padding: padding.copyWith(top: Space.s),
            sliver: SliverList.builder(
              itemCount: surah.ayahCount - anchor + 1 + (anchor == 1 ? 1 : 0),
              itemBuilder: (context, i) {
                if (anchor == 1) {
                  if (i == 0) return _header(context);
                  return _card(context, i);
                }
                return _card(context, anchor + i);
              },
            ),
          ),
          SliverPadding(
            padding: padding,
            sliver: SliverToBoxAdapter(child: _footer(context)),
          ),
        ],
      ),
    );
  }
}
