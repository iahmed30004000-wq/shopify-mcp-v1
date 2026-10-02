import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/painters/painters.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/sound/sound_api.dart';
import '../data/quran_providers.dart';
import '../domain/quran_meta.dart';
import '../domain/quran_text.dart';
import 'quran_continue_card.dart';
import 'quran_labels.dart';
import 'quran_reader_screen.dart';
import 'quran_search_screen.dart';
import 'quran_sheets.dart';
import 'widgets/quran_ornaments.dart';

enum QuranHomeTab { surahs, juz, bookmarks }

/// The Quran's front page: continue reading, search, go to, and the index
/// – suras, juz with their hizb quarters, and the reader's bookmarks
/// (long-press menu, drag to reorder, delete with undo).
class QuranHomeScreen extends ConsumerStatefulWidget {
  const QuranHomeScreen({super.key, this.onOpenReader, this.onOpenSearch, this.initialTab = QuranHomeTab.surahs});

  /// Opens the reader (default: [QuranNavigation.openReader]).
  final QuranOpenReader? onOpenReader;

  /// Opens the search (default: [QuranSearchScreen.open], pushed).
  final void Function(BuildContext context)? onOpenSearch;
  final QuranHomeTab initialTab;

  @override
  ConsumerState<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends ConsumerState<QuranHomeScreen> {
  late QuranHomeTab _tab = widget.initialTab;
  final Set<int> _openJuz = {};

  void _open({AyahRef? ayah, int? page}) {
    if (widget.onOpenReader != null) {
      Fx.fire(Sfx.navigate);
      widget.onOpenReader!(context, ayah: ayah, page: page);
    } else {
      unawaited(QuranNavigation.openReader(context, ayah: ayah, page: page));
    }
  }

  void _openSearch() {
    if (widget.onOpenSearch != null) {
      Fx.fire(Sfx.navigate);
      widget.onOpenSearch!(context);
    } else {
      unawaited(QuranSearchScreen.open(context, onOpenReader: widget.onOpenReader));
    }
  }

  Future<void> _goTo() async {
    final target = await showQuranGoTo(context);
    if (target == null || !mounted) return;
    _open(ayah: target.page == null ? target.ref : null, page: target.page);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final metaAsync = ref.watch(quranMetaProvider);
    return MadarScaffold(
      title: l.quranTitle,
      body: switch (metaAsync) {
        AsyncData(:final value) => EntranceChoreo(id: 'quran-home', child: _body(context, value)),
        AsyncError() => Center(
          child: AnimatedEmptyState(
            kind: EmptyStateKind.noData,
            title: l.quranLoadError,
            body: '',
            actionLabel: l.quranRetry,
            onAction: () => ref.invalidate(quranMetaProvider),
          ),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _header(BuildContext context) {
    final l = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaggerItem(
          index: 0,
          child: QuranContinueCard(prominent: true, onOpen: (context, {ayah, page}) => _open(ayah: ayah, page: page)),
        ),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: 1,
          child: Row(
            children: [
              Expanded(child: _SearchEntry(onOpen: _openSearch)),
              const SizedBox(width: Space.s),
              MadarButton(
                label: l.quranGoTo,
                icon: Icons.near_me_outlined,
                variant: MadarButtonVariant.secondary,
                onPressed: () => unawaited(_goTo()),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        StaggerItem(
          index: 2,
          child: ChoicePills<QuranHomeTab>.single(
            options: [
              ChoiceOption(value: QuranHomeTab.surahs, label: l.quranTabSurahs, icon: Icons.format_list_numbered_rtl_rounded),
              ChoiceOption(value: QuranHomeTab.juz, label: l.quranTabJuz, icon: Icons.layers_outlined),
              ChoiceOption(value: QuranHomeTab.bookmarks, label: l.quranTabBookmarks, icon: Icons.bookmarks_outlined),
            ],
            selected: _tab,
            onChanged: (v) => setState(() => _tab = v ?? _tab),
          ),
        ),
        const SizedBox(height: Space.m),
      ],
    );
  }

  Widget _body(BuildContext context, QuranMeta meta) {
    const padding = EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl);
    switch (_tab) {
      case QuranHomeTab.surahs:
        return ListView.builder(
          key: const PageStorageKey('quran-surahs'),
          padding: padding,
          itemCount: meta.surahs.length + 1,
          itemBuilder: (context, i) => i == 0
              ? _header(context)
              : Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: StaggerItem(
                    index: i + 2,
                    child: _SurahRow(surah: meta.surahs[i - 1], meta: meta, onTap: () => _open(ayah: AyahRef(i, 1))),
                  ),
                ),
        );
      case QuranHomeTab.juz:
        return ListView.builder(
          key: const PageStorageKey('quran-juz'),
          padding: padding,
          itemCount: QuranMeta.juzCount + 1,
          itemBuilder: (context, i) => i == 0
              ? _header(context)
              : Padding(
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: StaggerItem(
                    index: i + 2,
                    child: _JuzTile(
                      juz: i,
                      meta: meta,
                      open: _openJuz.contains(i),
                      onToggle: () => setState(() => _openJuz.contains(i) ? _openJuz.remove(i) : _openJuz.add(i)),
                      onOpen: (ref) => _open(ayah: ref),
                    ),
                  ),
                ),
        );
      case QuranHomeTab.bookmarks:
        return _Bookmarks(header: _header(context), meta: meta, onOpen: (ref) => _open(ayah: ref));
    }
  }
}

class _SearchEntry extends StatelessWidget {
  const _SearchEntry({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    return GlassCard(
      onTap: onOpen,
      semanticLabel: l.quranSearchTitle,
      borderRadius: BorderRadius.circular(t.radiusXL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: t.accent, size: 20),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(
              l.quranSearchHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: t.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.surah, required this.meta, required this.onTap});

  final SurahInfo surah;
  final QuranMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final arabic = quranArabicUi(context);
    final page = meta.pageOf(surah.first);
    final info = l.quranJoin([
      surah.makki ? l.quranMakki : l.quranMadani,
      fmt.localizeDigits(l.quranAyatCount(surah.ayahCount)),
      l.quranPageLabel(fmt.formatInt(page)),
    ]);
    final naskh = TextStyle(
      fontFamily: MadarTypography.naskhFamily,
      fontWeight: FontWeight.w700,
      fontSize: arabic ? 22 : 21,
      height: 1.3,
      color: t.gold,
    );
    return GlassCard(
      onTap: onTap,
      semanticLabel: '${l.quranSurahFull(surah)}, $info',
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.l, Space.s),
      child: Row(
        children: [
          AyahMedallion(label: fmt.formatInt(surah.number), size: 42),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (arabic)
                  Text(surah.nameArabic, style: naskh, maxLines: 1)
                else
                  Text(surah.nameEnglish, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (!arabic)
                  Text(
                    surah.meaningEnglish,
                    style: text.bodySmall!.copyWith(color: t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  info,
                  style: arabic ? text.bodySmall : text.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!arabic) ...[
            const SizedBox(width: Space.s),
            Text(surah.nameArabic, textDirection: TextDirection.rtl, style: naskh),
          ],
        ],
      ),
    );
  }
}

/// First words of an ayah (the traditional names of the hizb quarters).
String quranOpeningWords(QuranText? text, QuranMeta meta, AyahRef ref, {int words = 4}) {
  if (text == null) return '';
  final t = text.ayahText(meta.indexOf(ref)).replaceFirst('۞ ', '');
  final parts = t.split(' ').where((w) => w.isNotEmpty && !RegExp('^[ۖ-ۜ۩]\$').hasMatch(w)).toList();
  return parts.take(words).join(' ');
}

class _JuzTile extends ConsumerWidget {
  const _JuzTile({required this.juz, required this.meta, required this.open, required this.onToggle, required this.onOpen});

  final int juz;
  final QuranMeta meta;
  final bool open;
  final VoidCallback onToggle;
  final void Function(AyahRef ref) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final quranText = ref.watch(quranTextProvider).value;
    final start = meta.juzStart(juz);
    final surah = meta.surah(start.surah);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          MadarPressable(
            onTap: () => onOpen(start),
            semanticLabel: l.quranJuzLabel(fmt.formatInt(juz)),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.xs, Space.s),
              child: Row(
                children: [
                  AyahMedallion(label: fmt.formatInt(juz), size: 42),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.quranJuzLabel(fmt.formatInt(juz)), style: text.titleMedium),
                        Text(
                          l.quranJoin([l.quranPlace(surah, start.ayah, fmt), l.quranPageLabel(fmt.formatInt(meta.pageOf(start)))]),
                          style: text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  MadarButton.icon(
                    icon: open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    semanticLabel: l.quranJuzQuarters,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    onPressed: onToggle,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: context.reducedMotion ? MadarMotion.reduced : MadarMotion.medium,
            curve: MadarMotion.standard,
            alignment: AlignmentDirectional.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : Column(
                    children: [
                      Container(height: 1, color: t.glassBorder),
                      for (var q = (juz - 1) * 8 + 1; q <= juz * 8; q++)
                        _QuarterRow(
                          position: meta.quarterPosition(q),
                          start: meta.quarterStart(q),
                          meta: meta,
                          words: quranOpeningWords(quranText, meta, meta.quarterStart(q)),
                          onTap: () => onOpen(meta.quarterStart(q)),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuarterRow extends StatelessWidget {
  const _QuarterRow({required this.position, required this.start, required this.meta, required this.words, required this.onTap});

  final QuarterPosition position;
  final AyahRef start;
  final QuranMeta meta;
  final String words;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final surah = meta.surah(start.surah);
    return MadarPressable(
      onTap: onTap,
      semanticLabel: '${l.quranQuarterLabel(position, fmt)}, ${l.quranPlace(surah, start.ayah, fmt)}',
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.l, Space.s),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 30,
              child: CustomPaint(painter: _QuarterGlyph(quarter: position.quarter, color: t.brass, fill: t.gold)),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.quranQuarterLabel(position, fmt), style: text.labelLarge),
                  if (words.isNotEmpty)
                    Text(
                      words,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MadarTypography.quran(t, size: 18).copyWith(height: 1.7, color: t.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(l.quranSurahName(surah), style: text.labelMedium),
                Text(l.quranPageLabel(fmt.formatInt(meta.pageOf(start))), style: text.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A rub-el-hizb circle filled by quarter: ○ ◔ ◑ ◕ (hizb start = a star).
class _QuarterGlyph extends CustomPainter {
  const _QuarterGlyph({required this.quarter, required this.color, required this.fill});

  final int quarter;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;
    if (quarter == 1) {
      IslamicStarPainter(style: IslamicStarStyle.rubElHizb, fillColor: fill, strokeColor: color).paint(canvas, size);
      return;
    }
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.15));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -1.5708,
      6.28318 * (quarter - 1) / 4,
      true,
      Paint()..color = fill,
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_QuarterGlyph old) => old.quarter != quarter || old.color != color || old.fill != fill;
}

class _Bookmarks extends ConsumerWidget {
  const _Bookmarks({required this.header, required this.meta, required this.onOpen});

  final Widget header;
  final QuranMeta meta;
  final void Function(AyahRef ref) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final rows = ref.watch(quranBookmarksProvider).value ?? const <QuranBookmarkRow>[];
    final quranText = ref.watch(quranTextProvider).value;
    const padding = EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl);
    if (rows.isEmpty) {
      return ListView(
        padding: padding,
        children: [
          header,
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.quranBookmarksEmptyTitle,
            body: l.quranBookmarksEmptyBody,
            illustrationSize: 120,
          ),
        ],
      );
    }
    return ReorderableGlassList<QuranBookmarkRow>(
      items: rows,
      itemKey: (b) => b.id,
      header: header,
      padding: padding,
      onReorder: (order) => unawaited(ref.read(quranBookmarkServiceProvider).reorder([for (final b in order) b.id])),
      itemBuilder: (context, b, index, handle) {
        final ayah = AyahRef(b.surah, b.ayah);
        final valid = meta.isValid(ayah);
        final surah = meta.surah(b.surah.clamp(1, 114));
        final color = b.color == null ? t.accent : Color(b.color!);
        final place = l.quranPlace(surah, b.ayah, fmt);
        return ActionableItem(
          key: ValueKey('bookmark-${b.id}'),
          semanticLabel: b.label ?? place,
          onTap: valid ? () => onOpen(ayah) : null,
          actions: ItemActions(
            onEdit: () => editBookmark(context, ref, ayah, existing: b),
            onDelete: () async {
              final service = ref.read(quranBookmarkServiceProvider);
              final removed = await service.delete(b.id);
              if (removed == null) return null;
              return UndoableAction(label: l.quranBookmarkDeleted, undo: () => service.restore(removed));
            },
          ),
          child: StripeBox(
            stripe: color,
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.s, Space.m, Space.s),
            child: Row(
              children: [
                handle,
                const SizedBox(width: Space.xs),
                Icon(Icons.bookmark_rounded, color: color, size: 22),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.label ?? place, style: text.titleSmall!.copyWith(color: t.textPrimary)),
                      if (b.label != null) Text(place, style: text.labelMedium),
                      if (valid && quranText != null)
                        Text(
                          quranOpeningWords(quranText, meta, ayah, words: 7),
                          textDirection: TextDirection.rtl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MadarTypography.quran(t, size: 18).copyWith(height: 1.7, color: t.textSecondary),
                        ),
                      if (b.note != null)
                        Text(b.note!, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
