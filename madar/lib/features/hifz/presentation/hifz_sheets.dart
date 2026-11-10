import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show PickerButton;
import '../../../core/motion/motion_kit.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/sound/sound_api.dart';
import '../../wird/data/wird_providers.dart';
import '../../wird/presentation/surah_picker_sheet.dart';
import '../../wird/presentation/wird_labels.dart';
import '../data/hifz_providers.dart';
import '../data/hifz_service.dart';
import '../domain/hadith_collection.dart';
import '../domain/hifz_models.dart';
import '../domain/hifz_reveal.dart';
import 'hifz_labels.dart';
import 'widgets/hifz_reveal_text.dart';

/// What to add.
enum HifzAddKind { ayat, hadith, custom }

/// Asks what kind of item to add.
Future<HifzAddKind?> showHifzAddChooser(BuildContext context) =>
    showInteractionSheet<HifzAddKind>(context, builder: (_) => const _AddChooser());

class _AddChooser extends StatelessWidget {
  const _AddChooser();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    Widget option(HifzAddKind k, IconData icon, String title, String hint) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
      child: GlassCard(
        onTap: () => Navigator.of(context).pop(k),
        semanticLabel: '$title. $hint',
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
        child: Row(
          children: [
            _Medallion(icon: icon),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: Space.xxs),
                  Text(hint, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.tokens.textTertiary),
          ],
        ),
      ),
    );
    return InteractionSheetFrame(
      title: l.hifzAddTitle,
      subtitle: l.hifzAddSubtitle,
      icon: Icons.bookmark_add_rounded,
      body: Column(
        children: [
          option(HifzAddKind.ayat, Icons.auto_stories_rounded, l.hifzAddAyat, l.hifzAddAyatHint),
          option(HifzAddKind.hadith, Icons.format_quote_rounded, l.hifzAddHadith, l.hifzAddHadithHint),
          option(HifzAddKind.custom, Icons.edit_note_rounded, l.hifzAddCustom, l.hifzAddCustomHint),
        ],
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.accentSoft,
        border: Border.all(color: t.brass.withValues(alpha: 0.6)),
      ),
      child: Icon(icon, size: 22, color: t.accent),
    );
  }
}

// ------------------------------------------------------------------ ayat --

/// Picks a surah, an ayah range and a chunk size; returns them (null when
/// dismissed).
Future<(AyahRange, int)?> showHifzAyatSheet(BuildContext context, {AyahRange? initial}) =>
    showInteractionSheet<(AyahRange, int)>(context, builder: (_) => _AyatSheet(initial: initial));

class _AyatSheet extends ConsumerStatefulWidget {
  const _AyatSheet({this.initial});

  final AyahRange? initial;

  @override
  ConsumerState<_AyatSheet> createState() => _AyatSheetState();
}

class _AyatSheetState extends ConsumerState<_AyatSheet> {
  late int _surah = widget.initial?.first.surah ?? 67;
  late int _from = widget.initial?.first.ayah ?? 1;
  late int? _to = widget.initial?.last.ayah;
  int? _chunk;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final catalog = ref.watch(quranCatalogReadyProvider).value;
    final settings = ref.watch(hifzSettingsProvider).value ?? const HifzSettings();
    if (catalog == null) {
      return InteractionSheetFrame(
        title: l.hifzAddAyat,
        icon: Icons.auto_stories_rounded,
        body: const Padding(
          padding: EdgeInsets.all(Space.xl),
          child: Center(child: OrbitLoader(size: 36)),
        ),
      );
    }
    final texts = WirdTexts(l, fmt, catalog);
    final count = catalog.ayahCount(_surah);
    final to = math.min(count, _to ?? math.min(count, 10));
    final from = math.min(_from, to);
    final chunk = _chunk ?? settings.chunkSize;
    final chunks = HifzChunker.split(from, to, chunk);
    final preview = chunks
        .take(4)
        .map((c) => c.$1 == c.$2 ? texts.number(c.$1) : '${texts.number(c.$1)}–${texts.number(c.$2)}')
        .join(l.wirdSep);
    Widget label(String s) => Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s),
      child: Text(s, style: text.titleSmall),
    );
    Widget stepper(String title, int value, int min, int max, ValueChanged<int> onChanged) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.labelMedium),
          const SizedBox(height: Space.xs),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: t.glassFill,
              borderRadius: BorderRadius.circular(t.radiusM),
              border: Border.all(color: t.glassBorder),
            ),
            child: Row(
              children: [
                MadarButton.icon(
                  icon: Icons.remove_rounded,
                  onPressed: value > min ? () => onChanged(value - 1) : null,
                  semanticLabel: l.wirdDecrease,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.ghost,
                  sfx: Sfx.countTick,
                ),
                Expanded(
                  child: Text(texts.number(value), textAlign: TextAlign.center, style: text.titleMedium),
                ),
                MadarButton.icon(
                  icon: Icons.add_rounded,
                  onPressed: value < max ? () => onChanged(value + 1) : null,
                  semanticLabel: l.wirdIncrease,
                  size: MadarButtonSize.small,
                  variant: MadarButtonVariant.ghost,
                  sfx: Sfx.countTick,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return InteractionSheetFrame(
      title: l.hifzAddAyat,
      subtitle: l.hifzAddAyatHint,
      icon: Icons.auto_stories_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label(l.wirdSurah),
          PickerButton(
            icon: Icons.menu_book_rounded,
            text: '${texts.number(_surah)}. ${texts.surah(_surah)}',
            semanticLabel: l.wirdSurah,
            onTap: () async {
              final s = await showSurahPicker(context, catalog: catalog, selected: _surah);
              if (s != null) {
                setState(() {
                  _surah = s;
                  _from = 1;
                  _to = null;
                });
              }
            },
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              stepper(l.hifzFromAyah, from, 1, to, (v) => setState(() => _from = v)),
              const SizedBox(width: Space.m),
              stepper(l.hifzToAyah, to, from, count, (v) => setState(() => _to = v)),
            ],
          ),
          label(l.hifzChunkSize),
          ChoicePills<int>.single(
            options: [for (final c in HifzSettings.chunkChoices) ChoiceOption(value: c, label: texts.number(c))],
            selected: chunk,
            onChanged: (c) => c == null ? null : setState(() => _chunk = c),
          ),
          const SizedBox(height: Space.m),
          Text(
            l.hifzChunkPreview(
              fmt.localizeDigits(l.hifzChunks(chunks.length)),
              chunks.length > 4 ? '$preview…' : preview,
            ),
            textAlign: TextAlign.center,
            style: text.bodySmall!.copyWith(color: t.accent),
          ),
          const SizedBox(height: Space.m),
          FutureBuilder<String>(
            key: ValueKey((_surah, from)),
            future: catalog.ayahText(AyahRef(_surah, from)).catchError((_) => ''),
            builder: (context, snap) => Text(
              snap.data ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: MadarTypography.quran(t, size: 20).copyWith(color: t.textSecondary, height: 1.9),
            ),
          ),
        ],
      ),
      footer: SheetButton(
        label: l.hifzAddButton,
        primary: true,
        icon: Icons.add_rounded,
        sfx: Sfx.complete,
        onPressed: () => Navigator.of(context).pop((AyahRange(AyahRef(_surah, from), AyahRef(_surah, to)), chunk)),
      ),
    );
  }
}

// ---------------------------------------------------------------- hadith --

/// Picks hadith from the bundled collection (several at once); returns them.
Future<List<HadithEntry>?> showHadithPicker(BuildContext context) =>
    showInteractionSheet<List<HadithEntry>>(context, builder: (_) => const _HadithPicker());

class _HadithPicker extends ConsumerStatefulWidget {
  const _HadithPicker();

  @override
  ConsumerState<_HadithPicker> createState() => _HadithPickerState();
}

class _HadithPickerState extends ConsumerState<_HadithPicker> {
  final Set<int> _picked = {};

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final collection = ref.watch(hadithCollectionProvider).value;
    final cards = ref.watch(hifzCardsProvider).value ?? const <HifzCard>[];
    final arabic = l.localeName.startsWith('ar');
    if (collection == null) {
      return InteractionSheetFrame(
        title: l.hifzAddHadith,
        icon: Icons.format_quote_rounded,
        body: const Padding(
          padding: EdgeInsets.all(Space.xl),
          child: Center(child: OrbitLoader(size: 36)),
        ),
      );
    }
    final added = {
      for (final c in cards)
        if (c.kind == HifzKind.hadith) c.source,
    };
    return InteractionSheetFrame(
      title: collection.title(arabic: arabic),
      subtitle: arabic ? collection.compilerAr : collection.compilerEn,
      icon: Icons.format_quote_rounded,
      body: Column(
        children: [
          for (final e in collection.entries)
            Builder(
              builder: (context) {
                final inHifz = added.contains(collection.keyOf(e));
                final picked = _picked.contains(e.number);
                return Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
                  child: MadarPressable(
                    onTap: inHifz
                        ? null
                        : () => setState(() => picked ? _picked.remove(e.number) : _picked.add(e.number)),
                    sfx: picked ? Sfx.toggleOff : Sfx.toggleOn,
                    toggled: picked,
                    semanticLabel: '${l.hifzHadithNumber(fmt.formatInt(e.number))}: ${e.title(arabic: arabic)}',
                    child: AnimatedContainer(
                      duration: context.motion(MadarMotion.short),
                      padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.s, Space.m, Space.s),
                      decoration: BoxDecoration(
                        color: picked ? t.accentSoft : null,
                        borderRadius: BorderRadius.circular(t.radiusM),
                        border: Border.all(color: picked ? t.accent.withValues(alpha: 0.6) : Colors.transparent),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                IslamicStar(size: 34, filled: false, color: t.brass),
                                Text(fmt.formatInt(e.number), style: text.labelSmall!.copyWith(color: t.textPrimary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.title(arabic: arabic),
                                  style: text.titleSmall!.copyWith(color: t.textPrimary),
                                ),
                                Text(
                                  e.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textDirection: TextDirection.rtl,
                                  style: text.bodySmall!.copyWith(fontFamily: MadarTypography.naskhFamily),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: Space.s),
                          if (inHifz)
                            Text(l.hifzInHifz, style: text.labelSmall!.copyWith(color: t.success))
                          else
                            Icon(
                              picked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                              color: picked ? t.accent : t.textTertiary,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      footer: SheetButton(
        label: _picked.isEmpty ? l.hifzAddButton : '${l.hifzAddButton} (${fmt.formatInt(_picked.length)})',
        primary: true,
        enabled: _picked.isNotEmpty,
        icon: Icons.add_rounded,
        sfx: Sfx.complete,
        onPressed: () => Navigator.of(context).pop([
          for (final e in collection.entries)
            if (_picked.contains(e.number)) e,
        ]),
      ),
    );
  }
}

// --------------------------------------------------------------- preview --

/// Shows an item in full with its SM-2 standing; "review now" / "edit".
Future<void> showHifzPreview(
  BuildContext context, {
  required HifzCard card,
  required HifzTexts texts,
  required DateTime today,
  VoidCallback? onReviewNow,
  VoidCallback? onEdit,
}) => showInteractionSheet<void>(
  context,
  builder: (_) => _Preview(card: card, texts: texts, today: today, onReviewNow: onReviewNow, onEdit: onEdit),
);

class _Preview extends ConsumerWidget {
  const _Preview({required this.card, required this.texts, required this.today, this.onReviewNow, this.onEdit});

  final HifzCard card;
  final HifzTexts texts;
  final DateTime today;
  final VoidCallback? onReviewNow;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = texts.l;
    final fmt = texts.fmt;
    final text = Theme.of(context).textTheme;
    final tokens = ref.watch(hifzTokensProvider(card)).value;
    final entry = texts.entryOf(card);
    final style = card.kind == HifzKind.ayat
        ? MadarTypography.quran(t, size: 24).copyWith(height: 2.0)
        : TextStyle(fontFamily: MadarTypography.naskhFamily, fontSize: 19, height: 1.9, color: t.textPrimary);
    final facts = [
      texts.due(card, today),
      if (!card.isNew) hifzIntervalText(l, fmt, card.sm2.intervalDays),
      if (!card.isNew) l.hifzEase(fmt.formatNumber(card.sm2.easeFactor, maxDecimals: 2)),
      if (card.sm2.lapses > 0) fmt.localizeDigits(l.hifzLapses(card.sm2.lapses)),
    ];
    return InteractionSheetFrame(
      title: texts.title(card),
      subtitle: texts.subtitle(card),
      icon: hifzKindIcon(card.kind),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.s,
            runSpacing: Space.xs,
            children: [
              for (final f in facts)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Space.s, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: t.glassFill,
                    border: Border.all(color: t.glassBorder),
                  ),
                  child: Text(f, style: text.labelMedium),
                ),
            ],
          ),
          const SizedBox(height: Space.l),
          if (tokens == null)
            const Center(child: OrbitLoader(size: 28))
          else
            HifzRevealText(tokens: tokens, reveal: HifzRevealStage.full.asReveal(tokens), style: style),
          if (entry != null && entry.takhrij.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            Text(
              entry.takhrij,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: text.bodySmall!.copyWith(fontFamily: MadarTypography.naskhFamily, color: t.textTertiary),
            ),
          ],
        ],
      ),
      footer: Row(
        children: [
          if (onEdit != null) ...[
            Expanded(
              child: SheetButton(
                label: l.hifzEdit,
                icon: Icons.edit_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit!();
                },
              ),
            ),
            const SizedBox(width: Space.s),
          ],
          if (onReviewNow != null && !card.suspended)
            Expanded(
              child: SheetButton(
                label: l.hifzReviewNow,
                primary: true,
                icon: Icons.play_arrow_rounded,
                sfx: Sfx.navigate,
                onPressed: () {
                  Navigator.of(context).pop();
                  onReviewNow!();
                },
              ),
            ),
        ],
      ),
    );
  }
}

extension on HifzRevealStage {
  HifzReveal asReveal(List<HifzToken> tokens) =>
      HifzReveal(words: tokens.where((t) => !t.marker).length, stage: this, shown: tokens.length);
}
