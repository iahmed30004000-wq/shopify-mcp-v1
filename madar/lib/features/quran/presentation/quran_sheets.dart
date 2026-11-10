import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_audio.dart';
import '../../../core/sound/sound_api.dart';
import '../data/quran_com_client.dart';
import '../data/quran_providers.dart';
import '../domain/quran_meta.dart';
import '../domain/quran_prefs.dart';
import '../domain/quran_text.dart';
import '../domain/tajweed.dart';
import 'quran_labels.dart';
import 'tajweed_palette.dart';
import 'widgets/ayah_spans.dart';
import 'widgets/quran_ornaments.dart';
import 'widgets/quran_toast.dart';

/// The copy / share text of an ayah: «﴿…﴾ [البقرة: ٢٥٥]».
String quranShareText(L10n l, MadarFormatter fmt, SurahInfo surah, AyahContent ayah) =>
    '﴿${ayah.text}﴾ ${l.quranReference(surah, ayah.ref, fmt)}';

// ------------------------------------------------------------ ayah actions

/// What tapping an ayah offers: play from here, repeat, bookmark, copy,
/// share, add to Hifz (when the Hifz hook is set) and tafsir.
Future<void> showAyahActions(BuildContext context, WidgetRef ref, AyahContent ayah) {
  return showInteractionSheet<void>(context, builder: (_) => _AyahActionsSheet(ayah: ayah));
}

class _AyahActionsSheet extends ConsumerStatefulWidget {
  const _AyahActionsSheet({required this.ayah});

  final AyahContent ayah;

  @override
  ConsumerState<_AyahActionsSheet> createState() => _AyahActionsSheetState();
}

class _AyahActionsSheetState extends ConsumerState<_AyahActionsSheet> {
  static const repeatChoices = [3, 5, 7, 10];
  int _repeat = 3;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final meta = ref.watch(quranMetaProvider).requireValue;
    final prefs = ref.watch(quranReaderPrefsProvider).value ?? const QuranReaderPrefs();
    final bookmark = ref.watch(quranBookmarksByAyahProvider)[widget.ayah.ref];
    final hifz = ref.watch(quranAddToHifzProvider);
    final ayahRef = widget.ayah.ref;
    final surah = meta.surah(ayahRef.surah);
    final nav = Navigator.of(context);
    final root = Navigator.of(context, rootNavigator: true).context;

    Future<void> close() async {
      if (nav.canPop()) nav.pop();
    }

    final actions = <_ActionSpec>[
      _ActionSpec(Icons.play_circle_outline_rounded, l.quranActionPlay, () async {
        await close();
        await ref.read(quranAudioProvider).play(AyahRange(ayahRef, surah.last));
      }),
      _ActionSpec(Icons.repeat_one_rounded, l.quranActionRepeat, () async {
        await close();
        await ref.read(quranAudioProvider).play(AyahRange.single(ayahRef), repeatAyah: _repeat);
      }),
      _ActionSpec(
        bookmark == null ? Icons.bookmark_add_outlined : Icons.bookmark_rounded,
        bookmark == null ? l.quranActionBookmark : l.quranBookmarkEdit,
        () async {
          await close();
          if (root.mounted) await editBookmark(root, ref, ayahRef, existing: bookmark);
        },
      ),
      _ActionSpec(Icons.copy_rounded, l.quranActionCopy, () async {
        await ref.read(quranShareServiceProvider).copy(quranShareText(l, fmt, surah, widget.ayah));
        await close();
        if (root.mounted) QuranToast.show(root, l.quranCopied);
      }),
      _ActionSpec(Icons.ios_share_rounded, l.quranActionShare, () async {
        await close();
        await ref.read(quranShareServiceProvider).share(quranShareText(l, fmt, surah, widget.ayah));
      }),
      if (hifz != null)
        _ActionSpec(Icons.psychology_outlined, l.quranActionHifz, () async {
          await close();
          if (!root.mounted) return;
          final added = await hifz(root, AyahRange.single(ayahRef));
          if (added && root.mounted) QuranToast.show(root, l.quranHifzAdded);
        }),
      _ActionSpec(Icons.menu_book_outlined, l.quranActionTafsir, () async {
        final tafsir = ref.read(quranOpenTafsirProvider);
        await close();
        if (!root.mounted) return;
        if (tafsir != null) {
          tafsir(root, ayahRef);
        } else {
          QuranToast.show(root, l.quranTafsirSoon, icon: Icons.hourglass_top_rounded);
        }
      }, badge: ref.read(quranOpenTafsirProvider) == null ? l.quranSoon : null),
    ];

    return InteractionSheetFrame(
      // Digits stay out of the display-face title (its numerals are Kufi).
      title: l.quranSurahFull(surah),
      subtitle: l.quranJoin([
        l.quranAyahLabel(fmt.formatInt(ayahRef.ayah)),
        l.quranJuzLabel(fmt.formatInt(meta.juzOf(ayahRef))),
        l.quranPageLabel(fmt.formatInt(meta.pageOf(ayahRef))),
      ]),
      icon: Icons.auto_stories_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.m, vertical: Space.s),
            decoration: BoxDecoration(
              color: t.glassFill,
              borderRadius: BorderRadius.circular(t.radiusM),
              border: Border.all(color: t.glassBorder),
            ),
            child: SingleChildScrollView(
              child: Text.rich(
                TextSpan(
                  children: AyahSpans.ayah(
                    widget.ayah,
                    MadarTypography.quran(t, size: 22).copyWith(height: 1.95),
                    t,
                    paint: AyahPaint(tajweed: prefs.tajweed),
                  ),
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.start,
              ),
            ),
          ),
          const SizedBox(height: Space.l),
          LayoutBuilder(
            builder: (context, box) {
              final columns = box.maxWidth > 420 ? 4 : 3;
              final w = (box.maxWidth - Space.s * (columns - 1)) / columns;
              return Wrap(
                spacing: Space.s,
                runSpacing: Space.s,
                children: [for (final a in actions) SizedBox(width: w, child: _ActionTile(spec: a))],
              );
            },
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: 16, color: t.textTertiary),
              const SizedBox(width: Space.s),
              Text(l.quranActionRepeat, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: Space.s),
              Expanded(
                child: ChoicePills<int>.single(
                  options: [
                    for (final n in repeatChoices)
                      ChoiceOption(value: n, label: fmt.localizeDigits(l.quranRepeatTimes(n))),
                  ],
                  selected: _repeat,
                  onChanged: (v) => setState(() => _repeat = v ?? _repeat),
                  dense: true,
                  scrollable: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionSpec {
  const _ActionSpec(this.icon, this.label, this.onTap, {this.badge});

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
  final String? badge;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.spec});

  final _ActionSpec spec;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return MadarPressable(
      onTap: () => unawaited(spec.onTap()),
      semanticLabel: spec.label,
      focusRadius: BorderRadius.circular(t.radiusM),
      child: Container(
        height: 84,
        padding: const EdgeInsets.symmetric(horizontal: Space.xs, vertical: Space.s),
        decoration: BoxDecoration(
          color: t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: t.glassBorder),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(spec.icon, color: t.accent, size: 26),
                  const SizedBox(height: Space.xs),
                  Text(
                    spec.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium!.copyWith(color: t.textPrimary, height: 1.2),
                  ),
                ],
              ),
            ),
            if (spec.badge != null)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: t.accentSoft,
                    borderRadius: BorderRadius.circular(t.radiusS),
                  ),
                  child: Text(spec.badge!, style: text.labelSmall!.copyWith(color: t.accent)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- bookmarks

/// Adds or edits the bookmark of [ayah] (label, note, colour); an existing
/// one can be removed from the sheet (with undo).
Future<void> editBookmark(BuildContext context, WidgetRef ref, AyahRef ayah, {QuranBookmarkRow? existing}) async {
  final l = L10n.of(context);
  final fmt = MadarFormatter.of(context);
  final meta = await ref.read(quranMetaProvider.future);
  if (!context.mounted) return;
  final service = ref.read(quranBookmarkServiceProvider);
  final surah = meta.surah(ayah.surah);
  final result = await showEditSheet(
    context,
    title: existing == null ? l.quranBookmarkNew : l.quranBookmarkEdit,
    subtitle: l.quranPlace(surah, ayah.ayah, fmt),
    icon: Icons.bookmark_rounded,
    fields: [
      FieldSpec.text('label', l.quranBookmarkLabel, hint: l.quranBookmarkLabelHint, maxLength: 60),
      FieldSpec.multiline('note', l.quranBookmarkNote, maxLength: 500),
      FieldSpec.color('color', l.quranBookmarkColor),
    ],
    initial: {
      if (existing?.label != null) 'label': existing!.label,
      if (existing?.note != null) 'note': existing!.note,
      if (existing?.color != null) 'color': existing!.color,
    },
  );
  if (result == null) return;
  if (existing == null) {
    await service.add(
      ayah,
      label: result['label'] as String?,
      note: result['note'] as String?,
      color: result['color'] as int?,
    );
  } else {
    await service.edit(
      existing.id,
      label: result['label'] as String?,
      note: result['note'] as String?,
      color: result['color'] as int?,
    );
  }
  Fx.fire(Sfx.complete);
  if (context.mounted) QuranToast.show(context, l.quranBookmarkSaved, icon: Icons.bookmark_rounded);
}

/// Deletes a bookmark with an undo toast.
Future<void> deleteBookmark(BuildContext context, WidgetRef ref, QuranBookmarkRow row) async {
  final l = L10n.of(context);
  final service = ref.read(quranBookmarkServiceProvider);
  final removed = await service.delete(row.id);
  if (removed == null || !context.mounted) return;
  unawaited(
    showUndoToast(context, UndoableAction(label: l.quranBookmarkDeleted, undo: () => service.restore(removed))),
  );
}

// --------------------------------------------------------------- settings

/// Reader settings: layout, text size, tajweed (and its source, with the
/// optional Quran.com download for [surah]) and the translation.
Future<void> showReaderSettings(BuildContext context, {required int surah}) =>
    showInteractionSheet<void>(context, builder: (_) => _SettingsSheet(surah: surah));

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet({required this.surah});

  final int surah;

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

enum _Download { idle, running, failedOffline, failed }

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  _Download _translation = _Download.idle;
  _Download _tajweed = _Download.idle;

  Future<void> _update(QuranReaderPrefs Function(QuranReaderPrefs) change) =>
      ref.read(quranPrefsStoreProvider).updatePrefs(change);

  Future<void> _download(bool translation, int id) async {
    setState(() => translation ? _translation = _Download.running : _tajweed = _Download.running);
    _Download outcome = _Download.idle;
    try {
      if (translation) {
        await ref.read(quranDownloadsProvider).translation(widget.surah, id);
      } else {
        await ref.read(quranDownloadsProvider).tajweed(widget.surah);
      }
      Fx.fire(Sfx.complete);
    } on QuranComException catch (e) {
      outcome = e.problem == QuranComProblem.offline ? _Download.failedOffline : _Download.failed;
      Fx.fire(Sfx.error);
    }
    if (mounted) setState(() => translation ? _translation = outcome : _tajweed = outcome);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final prefs = ref.watch(quranReaderPrefsProvider).value ?? const QuranReaderPrefs();
    final translation = ref.watch(quranTranslationProvider((widget.surah, prefs.translationId))).value;
    final remoteTajweed = ref.watch(quranComTajweedProvider(widget.surah)).value;
    final meta = ref.watch(quranMetaProvider).value;
    final surahName = meta == null ? '' : l.quranSurahFull(meta.surah(widget.surah));

    Widget section(String title) => Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s),
      child: Text(title, style: text.titleSmall!.copyWith(color: t.gold)),
    );

    Widget switchRow(IconData icon, String label, bool value, ValueChanged<bool> onChanged, {String? caption}) => Row(
      children: [
        Icon(icon, size: 20, color: t.accent),
        const SizedBox(width: Space.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.bodyLarge),
              if (caption != null) Text(caption, style: text.bodySmall),
            ],
          ),
        ),
        MadarSwitch(value: value, onChanged: onChanged, semanticLabel: label),
      ],
    );

    Widget downloadRow({required bool done, required _Download state, required String label, required VoidCallback onTap}) {
      final (icon, color, status) = switch (state) {
        _ when done => (Icons.cloud_done_rounded, t.success, l.quranDownloaded),
        _Download.running => (Icons.downloading_rounded, t.accent, l.quranDownloading),
        _Download.failedOffline => (Icons.cloud_off_rounded, t.warning, l.quranDownloadOffline),
        _Download.failed => (Icons.error_outline_rounded, t.danger, l.quranDownloadFailed),
        _Download.idle => (Icons.cloud_download_outlined, t.textSecondary, l.quranDownloadNote),
      };
      return Padding(
        padding: const EdgeInsetsDirectional.only(top: Space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: Space.s),
                Expanded(child: Text(status, style: text.bodySmall!.copyWith(color: color))),
              ],
            ),
            if (!done) ...[
              const SizedBox(height: Space.s),
              MadarButton(
                label: label,
                icon: Icons.download_rounded,
                variant: MadarButtonVariant.secondary,
                size: MadarButtonSize.small,
                loading: state == _Download.running,
                onPressed: state == _Download.running ? null : onTap,
              ),
            ],
          ],
        ),
      );
    }

    return InteractionSheetFrame(
      title: l.quranSettingsTitle,
      subtitle: surahName,
      icon: Icons.tune_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          section(l.quranReaderLayout),
          ChoicePills<QuranReaderMode>.single(
            options: [
              ChoiceOption(value: QuranReaderMode.mushaf, label: l.quranModeMushaf, icon: Icons.menu_book_rounded),
              ChoiceOption(value: QuranReaderMode.list, label: l.quranModeList, icon: Icons.view_agenda_outlined),
            ],
            selected: prefs.mode,
            onChanged: (v) {
              if (v != null) unawaited(_update((p) => p.copyWith(mode: v)));
            },
          ),
          section(l.quranFontSize),
          Row(
            children: [
              MadarButton.icon(
                icon: Icons.text_decrease_rounded,
                semanticLabel: l.quranFontSmaller,
                onPressed: prefs.fontSize <= QuranReaderPrefs.minFontSize
                    ? null
                    : () => unawaited(_update((p) => p.copyWith(fontSize: p.fontSize - QuranReaderPrefs.fontStep))),
              ),
              Expanded(
                child: Text(
                  QuranText.openingBasmala,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: MadarTypography.quran(t, size: prefs.fontSize).copyWith(height: 1.6),
                ),
              ),
              MadarButton.icon(
                icon: Icons.text_increase_rounded,
                semanticLabel: l.quranFontLarger,
                onPressed: prefs.fontSize >= QuranReaderPrefs.maxFontSize
                    ? null
                    : () => unawaited(_update((p) => p.copyWith(fontSize: p.fontSize + QuranReaderPrefs.fontStep))),
              ),
            ],
          ),
          section(l.quranTajweedSection),
          switchRow(
            Icons.palette_outlined,
            l.quranTajweedColors,
            prefs.tajweed,
            (v) => unawaited(_update((p) => p.copyWith(tajweed: v))),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              label: l.quranTajweedLegend,
              icon: Icons.color_lens_outlined,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              onPressed: () => unawaited(showTajweedLegend(context)),
            ),
          ),
          const SizedBox(height: Space.xs),
          Text(l.quranTajweedSource, style: text.labelMedium),
          const SizedBox(height: Space.xs),
          ChoicePills<TajweedSource>.single(
            options: [
              ChoiceOption(value: TajweedSource.bundled, label: l.quranTajweedSourceBundled),
              ChoiceOption(value: TajweedSource.quranCom, label: l.quranTajweedSourceQuranCom),
            ],
            selected: prefs.tajweedSource,
            dense: true,
            onChanged: (v) {
              if (v != null) unawaited(_update((p) => p.copyWith(tajweedSource: v)));
            },
          ),
          if (prefs.tajweedSource == TajweedSource.quranCom)
            downloadRow(
              done: remoteTajweed != null,
              state: _tajweed,
              label: l.quranDownloadTajweed,
              onTap: () => unawaited(_download(false, prefs.translationId)),
            ),
          section(l.quranTranslation),
          switchRow(
            Icons.translate_rounded,
            l.quranTranslationShow,
            prefs.translation,
            (v) => unawaited(_update((p) => p.copyWith(translation: v))),
            caption: l.quranTranslationName,
          ),
          if (prefs.translation)
            downloadRow(
              done: translation != null,
              state: _translation,
              label: l.quranDownloadTranslation,
              onTap: () => unawaited(_download(true, prefs.translationId)),
            ),
          const SizedBox(height: Space.s),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- legend

/// Where each rule's example word comes from (its first clear occurrence).
const Map<TajweedRule, AyahRef> tajweedExamples = {
  TajweedRule.hamzatWasl: AyahRef(1, 1),
  TajweedRule.lamShamsiyyah: AyahRef(1, 1),
  TajweedRule.silent: AyahRef(2, 3),
  TajweedRule.maddNatural: AyahRef(1, 1),
  TajweedRule.maddPermissible: AyahRef(1, 1),
  TajweedRule.maddSeparated: AyahRef(2, 4),
  TajweedRule.maddConnected: AyahRef(2, 5),
  TajweedRule.maddNecessary: AyahRef(1, 7),
  TajweedRule.qalqalah: AyahRef(2, 3),
  TajweedRule.ghunnah: AyahRef(2, 3),
  TajweedRule.ikhfa: AyahRef(2, 3),
  TajweedRule.ikhfaShafawi: AyahRef(3, 50),
  TajweedRule.iqlab: AyahRef(2, 10),
  TajweedRule.idghamGhunnah: AyahRef(2, 5),
  TajweedRule.idghamShafawi: AyahRef(2, 29),
  TajweedRule.idghamNoGhunnah: AyahRef(2, 12),
  TajweedRule.idghamMutajanisayn: AyahRef(2, 233),
  TajweedRule.idghamMutaqaribayn: AyahRef(4, 158),
};

/// The words of [ayah] around the first mark of [rule], as their own text
/// and marks (the example shown in the legend).
AyahContent? tajweedExample(QuranContent content, TajweedRule rule) {
  final ref = tajweedExamples[rule];
  if (ref == null) return null;
  final ayah = content.ayah(content.meta.indexOf(ref));
  final mark = ayah.marks.where((m) => m.rule == rule).firstOrNull;
  if (mark == null) return null;
  final text = ayah.text;
  final start = text.lastIndexOf(' ', mark.start) + 1;
  var end = text.indexOf(' ', (mark.end - 1).clamp(0, text.length));
  if (end < 0) end = text.length;
  return AyahContent(
    ref: ref,
    index: ayah.index,
    text: text.substring(start, end),
    marks: Tajweed.slice(ayah.marks, start, end),
  );
}

Future<void> showTajweedLegend(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const TajweedLegendSheet());

/// The colour guide: every rule in its family with its colour, a short
/// explanation and a real example word drawn in that colour.
class TajweedLegendSheet extends ConsumerWidget {
  const TajweedLegendSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final palette = TajweedPalette.of(t);
    final meta = ref.watch(quranMetaProvider).value;
    final quran = ref.watch(quranTextProvider).value;
    final tajweed = ref.watch(quranTajweedProvider).value;
    final content = meta == null || quran == null ? null : QuranContent(meta: meta, text: quran, tajweed: tajweed);
    return InteractionSheetFrame(
      title: l.quranLegendTitle,
      icon: Icons.color_lens_outlined,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.quranLegendNote, style: text.bodySmall),
          for (final family in TajweedFamily.values) ...[
            Padding(
              padding: const EdgeInsetsDirectional.only(top: Space.l, bottom: Space.s),
              child: Text(l.quranFamilyName(family), style: text.titleSmall!.copyWith(color: t.gold)),
            ),
            for (final rule in TajweedRule.values.where((r) => r.family == family))
              Padding(
                padding: const EdgeInsets.only(bottom: Space.s),
                child: _LegendRow(rule: rule, color: palette[rule], example: content == null ? null : tajweedExample(content, rule)),
              ),
          ],
          const SizedBox(height: Space.m),
          Text(l.quranLegendCredits, style: text.bodySmall!.copyWith(color: t.textTertiary)),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.rule, required this.color, this.example});

  final TajweedRule rule;
  final Color color;
  final AyahContent? example;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return StripeBox(
      stripe: color,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.m, Space.s),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.quranRuleName(rule), style: text.titleSmall!.copyWith(color: color)),
                Text(l.quranRuleHint(rule), style: text.bodySmall),
              ],
            ),
          ),
          if (example != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: Space.s),
              child: Text.rich(
                TextSpan(
                  children: AyahSpans.plain(
                    example!.text,
                    example!.marks.where((m) => m.rule == rule).toList(),
                    MadarTypography.quran(t, size: 24).copyWith(height: 1.7),
                    t,
                  ),
                ),
                textDirection: TextDirection.rtl,
              ),
            ),
        ],
      ),
    );
  }
}
