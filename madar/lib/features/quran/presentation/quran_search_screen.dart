import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show kitInputDecoration;
import '../../../core/quran/ayah.dart';
import '../../../core/sound/sound_api.dart';
import '../data/quran_providers.dart';
import '../domain/arabic_search.dart';
import '../domain/quran_goto.dart';
import '../domain/quran_meta.dart';
import 'quran_labels.dart';
import 'quran_reader_screen.dart';
import 'widgets/ayah_spans.dart';

/// Full-text search over the Arabic text (diacritics, hamza and alef forms
/// ignored), matches lit in each ayah; tap a hit to open it in the reader.
class QuranSearchScreen extends ConsumerStatefulWidget {
  const QuranSearchScreen({super.key, this.initialQuery = '', this.onOpenReader});

  final String initialQuery;

  /// Opens the reader (default: [QuranNavigation.openReader]).
  final QuranOpenReader? onOpenReader;

  static Future<void> open(BuildContext context, {QuranOpenReader? onOpenReader}) {
    Fx.fire(Sfx.navigate);
    return Navigator.of(context).push(
      QuranNavigation.route(QuranSearchScreen(onOpenReader: onOpenReader), 'quran/search'),
    );
  }

  @override
  ConsumerState<QuranSearchScreen> createState() => _QuranSearchScreenState();
}

class _QuranSearchScreenState extends ConsumerState<QuranSearchScreen> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  String _submitted = '';

  @override
  void initState() {
    super.initState();
    _submitted = widget.initialQuery;
    _query.addListener(_changed);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      if (mounted && _query.text != _submitted) setState(() => _submitted = _query.text);
    });
  }

  void _open(AyahRef ref) {
    if (widget.onOpenReader != null) {
      Fx.fire(Sfx.navigate);
      widget.onOpenReader!(context, ayah: ref);
    } else {
      unawaited(QuranNavigation.openReader(context, ayah: ref));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final index = ref.watch(quranSearchIndexProvider);
    final meta = ref.watch(quranMetaProvider).value;
    final folded = ArabicSearch.normalizeQuery(_submitted);
    final result = index.hasValue && folded.length >= QuranSearchIndex.minQueryLength
        ? index.requireValue.search(_submitted)
        : QuranSearchResult.empty;
    final surahHits = meta == null || _submitted.trim().isEmpty ? const <SurahInfo>[] : QuranGoTo.matchSurahs(_submitted, meta);

    Widget status() {
      if (_submitted.trim().isEmpty) return Text(l.quranSearchIntro, style: text.bodySmall);
      if (!index.hasValue) {
        return Row(
          children: [
            const OrbitLoader(size: 18),
            const SizedBox(width: Space.s),
            Text(l.quranSearchPreparing, style: text.bodySmall),
          ],
        );
      }
      if (folded.length < QuranSearchIndex.minQueryLength) return Text(l.quranSearchTooShort, style: text.bodySmall);
      final parts = [
        fmt.localizeDigits(l.quranSearchResults(result.total)),
        if (result.total > 0) fmt.localizeDigits(l.quranSearchOccurrences(result.occurrences)),
        if (result.total > result.hits.length) l.quranSearchShowingFirst(fmt.formatInt(result.hits.length)),
      ];
      return Text(l.quranJoin(parts), style: text.labelMedium!.copyWith(color: t.gold));
    }

    return MadarScaffold(
      title: l.quranSearchTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.s),
            child: TextField(
              controller: _query,
              autofocus: widget.initialQuery.isEmpty,
              textInputAction: TextInputAction.search,
              textDirection: TextDirection.rtl,
              style: text.bodyLarge!.copyWith(fontFamily: MadarTypography.naskhFamily, fontSize: 19),
              onSubmitted: (v) => setState(() => _submitted = v),
              decoration: kitInputDecoration(context, hint: l.quranSearchFieldHint).copyWith(
                prefixIcon: Icon(Icons.search_rounded, color: t.accent),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close_rounded, color: t.textTertiary),
                        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                        onPressed: () {
                          Fx.fire(Sfx.tap);
                          _query.clear();
                          setState(() => _submitted = '');
                        },
                      ),
              ),
            ),
          ),
          Padding(padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter), child: status()),
          const SizedBox(height: Space.s),
          Expanded(
            child: meta == null
                ? const SizedBox.shrink()
                : result.hits.isEmpty && surahHits.isEmpty && folded.length >= QuranSearchIndex.minQueryLength && index.hasValue
                ? Center(
                    child: AnimatedEmptyState(kind: EmptyStateKind.noResults, title: l.quranSearchNoResults, body: ''),
                  )
                : ListView.builder(
                    padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
                    itemCount: surahHits.take(3).length + result.hits.length,
                    itemBuilder: (context, i) {
                      final surahs = surahHits.take(3).toList();
                      if (i < surahs.length) {
                        final s = surahs[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: Space.s),
                          child: GlassCard(
                            onTap: () => _open(s.first),
                            padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
                            child: Row(
                              children: [
                                Icon(Icons.menu_book_rounded, color: t.accent, size: 20),
                                const SizedBox(width: Space.m),
                                Expanded(child: Text(l.quranSurahFull(s), style: text.titleMedium)),
                                Text(
                                  fmt.localizeDigits(l.quranAyatCount(s.ayahCount)),
                                  style: text.labelMedium,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final hit = result.hits[i - surahs.length];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Space.s),
                        child: _HitCard(hit: hit, meta: meta, onTap: () => _open(hit.ref)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HitCard extends ConsumerWidget {
  const _HitCard({required this.hit, required this.meta, required this.onTap});

  final QuranSearchHit hit;
  final QuranMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final quran = ref.watch(quranTextProvider).value;
    if (quran == null) return const SizedBox.shrink();
    final surah = meta.surah(hit.ref.surah);
    var ayahText = quran.ayahText(hit.index);
    var ranges = hit.ranges;
    // Long ayat: start a little before the first match.
    if (ayahText.length > 260 && ranges.isNotEmpty && ranges.first.$1 > 140) {
      final cut = ayahText.lastIndexOf(' ', ranges.first.$1 - 90) + 1;
      ayahText = ayahText.substring(cut);
      ranges = [for (final r in ranges) (r.$1 - cut, r.$2 - cut)];
      ayahText = '… $ayahText';
      ranges = [for (final r in ranges) (r.$1 + 2, r.$2 + 2)];
    }
    final content = AyahContent(ref: hit.ref, index: hit.index, text: ayahText, marks: const []);
    return GlassCard(
      onTap: onTap,
      semanticLabel: l.quranAyahSemantics(fmt.formatInt(hit.ref.ayah), l.quranSurahName(surah)),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l.quranPlace(surah, hit.ref.ayah, fmt), style: text.labelLarge!.copyWith(color: t.gold))),
              Text(l.quranPageLabel(fmt.formatInt(meta.pageOf(hit.ref))), style: text.labelSmall),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text.rich(
            TextSpan(
              children: AyahSpans.ayah(
                content,
                MadarTypography.quran(t, size: 21).copyWith(height: 1.9),
                t,
                paint: AyahPaint(tajweed: false, matches: ranges),
              ),
            ),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ go to

/// The go-to sheet: type `2:255`, a sura name (+ ayah), `صفحة ٥٠`, `جزء ٣`…
/// and pick one of the live matches.
Future<GoToTarget?> showQuranGoTo(BuildContext context) =>
    showInteractionSheet<GoToTarget>(context, builder: (_) => const _GoToSheet());

class _GoToSheet extends ConsumerStatefulWidget {
  const _GoToSheet();

  @override
  ConsumerState<_GoToSheet> createState() => _GoToSheetState();
}

class _GoToSheetState extends ConsumerState<_GoToSheet> {
  final TextEditingController _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _label(L10n l, MadarFormatter fmt, QuranMeta meta, GoToTarget g) => switch (g.kind) {
    GoToKind.surah => l.quranSurahFull(meta.surah(g.number)),
    GoToKind.ayah => l.quranPlace(meta.surah(g.ref.surah), g.ref.ayah, fmt),
    GoToKind.page => l.quranPageLabel(fmt.formatInt(g.number)),
    GoToKind.juz => l.quranJuzLabel(fmt.formatInt(g.number)),
    GoToKind.hizb => l.quranHizbLabel(fmt.formatInt(g.number)),
  };

  IconData _icon(GoToKind k) => switch (k) {
    GoToKind.surah => Icons.menu_book_rounded,
    GoToKind.ayah => Icons.format_quote_rounded,
    GoToKind.page => Icons.description_outlined,
    GoToKind.juz || GoToKind.hizb => Icons.layers_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final meta = ref.watch(quranMetaProvider).value;
    final targets = meta == null ? const <GoToTarget>[] : QuranGoTo.parse(_input.text, meta);
    void pick(GoToTarget g) {
      Fx.fire(Sfx.navigate);
      Navigator.of(context).pop(g);
    }

    return InteractionSheetFrame(
      title: l.quranGoToTitle,
      icon: Icons.near_me_outlined,
      toolbar: TextField(
        controller: _input,
        autofocus: true,
        textInputAction: TextInputAction.go,
        onSubmitted: (_) {
          if (targets.isNotEmpty) pick(targets.first);
        },
        decoration: kitInputDecoration(context, hint: fmt.localizeDigits('2:255')).copyWith(
          prefixIcon: Icon(Icons.near_me_outlined, color: t.accent, size: 20),
          isDense: true,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.quranGoToHint(fmt.localizeDigits('2:255'), fmt.formatInt(255), fmt.formatInt(50)),
            style: text.bodySmall,
          ),
          const SizedBox(height: Space.m),
          if (_input.text.trim().isNotEmpty && targets.isEmpty)
            Text(l.quranGoToNone(fmt.localizeDigits('18:10')), style: text.bodyMedium!.copyWith(color: t.warning)),
          for (final g in targets.take(8))
            Padding(
              padding: const EdgeInsets.only(bottom: Space.s),
              child: GlassCard(
                onTap: () => pick(g),
                padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
                child: Row(
                  children: [
                    Icon(_icon(g.kind), color: t.accent, size: 20),
                    const SizedBox(width: Space.m),
                    Expanded(child: Text(_label(l, fmt, meta!, g), style: text.titleSmall!.copyWith(color: t.textPrimary))),
                    Text(l.quranPageLabel(fmt.formatInt(g.page ?? meta.pageOf(g.ref))), style: text.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
