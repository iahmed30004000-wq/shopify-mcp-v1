import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/formatters.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/motion/motion_kit.dart';
import '../../core/routing/route_pages.dart';
import '../../core/settings/app_settings.dart';
import '../quran/quran.dart';
import '../recitation/recitation.dart' show recitationSettingsProvider;
import 'widgets/settings_widgets.dart';

/// How many suras have the Quran.com tajweed text and the translation
/// ([QuranReaderPrefs.translationId]) on the device – read from the disk
/// cache, never from the network; null when the cache cannot be read.
final quranDownloadCountsProvider = FutureProvider.autoDispose.family<({int tajweed, int translation})?, int>((
  ref,
  translationId,
) async {
  ref.watch(quranDownloadsVersionProvider);
  try {
    final client = ref.watch(quranComClientProvider);
    final tajweed = await client.cachedTajweedSurahs();
    final translation = await client.cachedTranslationSurahs(translationId);
    return (tajweed: tajweed.length, translation: translation.length);
  } catch (_) {
    return null;
  }
});

/// Settings › Quran reading: the reader's layout (mushaf pages or a verse
/// list) and text size with a live preview; tajweed colours, their legend
/// and source (bundled, or Quran.com where downloaded); the English
/// translation. Every change is saved at once in the reader's own
/// preferences (the reader and its settings sheet follow live). Downloads
/// stay per sura, from the reader – this page only says what is on the
/// device.
class QuranSettingsScreen extends ConsumerWidget {
  const QuranSettingsScreen({super.key});

  static Future<void> _update(WidgetRef ref, QuranReaderPrefs Function(QuranReaderPrefs) change) =>
      ref.read(quranPrefsStoreProvider).updatePrefs(change);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final saver = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    final prefs = ref.watch(quranReaderPrefsProvider).value;
    final reciter = ref.watch(recitationSettingsProvider).value?.reciter;
    void update(QuranReaderPrefs Function(QuranReaderPrefs) change) => unawaited(_update(ref, change));

    return MadarScaffold(
      title: l.settingsQuran,
      extendBodyBehindAppBar: true,
      animateBackdrop: !saver,
      backdropSeed: 0.41,
      body: prefs == null
          ? const Center(child: OrbitLoader())
          : SettingsListView(
              children: [
                StaggerIn(
                  id: 'quran-settings',
                  fade: false,
                  children: [
                    SettingsSection(
                      title: l.settingsQuranReading,
                      seed: 0.12,
                      children: [
                        SettingsChoiceTile<QuranReaderMode>(
                          icon: Icons.auto_stories_rounded,
                          title: l.quranReaderLayout,
                          options: [
                            ChoiceOption(
                              value: QuranReaderMode.mushaf,
                              label: l.quranModeMushaf,
                              icon: Icons.menu_book_rounded,
                            ),
                            ChoiceOption(
                              value: QuranReaderMode.list,
                              label: l.quranModeList,
                              icon: Icons.view_agenda_outlined,
                            ),
                          ],
                          selected: prefs.mode,
                          onChanged: (v) => update((p) => p.copyWith(mode: v)),
                        ),
                        _TextSizeTile(
                          size: prefs.fontSize,
                          onChanged: (v) => update((p) => p.copyWith(fontSize: v)),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: l.quranTajweedSection,
                      seed: 0.22,
                      children: [
                        SettingsSwitchTile(
                          icon: Icons.palette_outlined,
                          title: l.quranTajweedColors,
                          value: prefs.tajweed,
                          onChanged: (v) => update((p) => p.copyWith(tajweed: v)),
                        ),
                        SettingsTile(
                          icon: Icons.legend_toggle_rounded,
                          title: l.quranTajweedLegend,
                          navigates: true,
                          onTap: () => unawaited(showTajweedLegend(context)),
                        ),
                        SettingsChoiceTile<TajweedSource>(
                          icon: Icons.auto_awesome_rounded,
                          title: l.quranTajweedSource,
                          subtitle: prefs.tajweedSource == TajweedSource.quranCom
                              ? _downloaded(ref, l, fmt, prefs, tajweed: true)
                              : null,
                          options: [
                            ChoiceOption(value: TajweedSource.bundled, label: l.quranTajweedSourceBundled),
                            ChoiceOption(value: TajweedSource.quranCom, label: l.quranTajweedSourceQuranCom),
                          ],
                          selected: prefs.tajweedSource,
                          onChanged: (v) => update((p) => p.copyWith(tajweedSource: v)),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: l.quranTranslation,
                      seed: 0.32,
                      children: [
                        SettingsSwitchTile(
                          icon: Icons.translate_rounded,
                          title: l.quranTranslationShow,
                          subtitle: switch (prefs.translation
                              ? _downloaded(ref, l, fmt, prefs, tajweed: false)
                              : null) {
                            final downloaded? => l.orbitUiListSeparator(l.quranTranslationName, downloaded),
                            null => l.quranTranslationName,
                          },
                          value: prefs.translation,
                          onChanged: (v) => update((p) => p.copyWith(translation: v)),
                        ),
                        SettingsNote(l.settingsQuranDownloadNote, icon: Icons.cloud_download_outlined),
                      ],
                    ),
                    SettingsSection(
                      title: l.recitationTitle,
                      seed: 0.42,
                      children: [
                        SettingsTile(
                          icon: Icons.graphic_eq_rounded,
                          title: l.settingsRecitation,
                          subtitle: reciter?.name(arabic: fmt.isArabic),
                          navigates: true,
                          onTap: () => FaithNav.recitation(context),
                        ),
                      ],
                    ),
                    SettingsNote(l.settingsQuranSourceNote, icon: Icons.verified_outlined),
                  ],
                ),
              ],
            ),
    );
  }

  /// "Downloaded for 12 suras" (null while unknown).
  static String? _downloaded(WidgetRef ref, L10n l, MadarFormatter fmt, QuranReaderPrefs prefs, {required bool tajweed}) {
    final counts = ref.watch(quranDownloadCountsProvider(prefs.translationId)).value;
    if (counts == null) return null;
    return fmt.localizeDigits(l.settingsQuranDownloaded(tajweed ? counts.tajweed : counts.translation));
  }
}

/// Text size: smaller / larger around a live line of the mushaf's script at
/// the chosen size.
class _TextSizeTile extends StatelessWidget {
  const _TextSizeTile({required this.size, required this.onChanged});

  final double size;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SettingsIcon(Icons.format_size_rounded),
              const SizedBox(width: Space.m),
              Expanded(child: Text(l.quranFontSize, style: text.titleMedium)),
              Text(
                fmt.formatInt(size.round()),
                style: MadarTypography.numerals(t, size: 15, color: t.accent).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: Space.s),
          Row(
            children: [
              MadarButton.icon(
                icon: Icons.text_decrease_rounded,
                semanticLabel: l.quranFontSmaller,
                size: MadarButtonSize.small,
                onPressed: size <= QuranReaderPrefs.minFontSize
                    ? null
                    : () => onChanged(size - QuranReaderPrefs.fontStep),
              ),
              Expanded(
                child: Semantics(
                  label: l.settingsQuranPreviewLabel,
                  excludeSemantics: true,
                  // The whole basmala at the true size (it wraps when
                  // large, never shrinks to fit).
                  child: AnimatedSize(
                    duration: context.motion(MadarMotion.short),
                    curve: MadarMotion.standard,
                    child: Text(
                      QuranText.openingBasmala,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: MadarTypography.quran(t, size: size).copyWith(height: 1.7, color: t.textPrimary),
                    ),
                  ),
                ),
              ),
              MadarButton.icon(
                icon: Icons.text_increase_rounded,
                semanticLabel: l.quranFontLarger,
                size: MadarButtonSize.small,
                onPressed: size >= QuranReaderPrefs.maxFontSize
                    ? null
                    : () => onChanged(size + QuranReaderPrefs.fontStep),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
