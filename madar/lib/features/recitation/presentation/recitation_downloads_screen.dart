import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../application/recitation_providers.dart';
import '../domain/download_models.dart';
import '../domain/reciters.dart';
import '../domain/surah_ayah_counts.dart';
import 'recitation_labels.dart';
import 'recitation_settings_screen.dart' show confirmDeleteReciter, confirmRecitationDelete;

/// Opens the per-surah downloads of [reciter]: through the app's router
/// when it registered [recitationOpenDownloadsProvider], else pushed with
/// the shared-axis transition.
Future<void> openRecitationDownloads(BuildContext context, Reciter reciter) {
  Fx.fire(Sfx.navigate);
  final routed = ProviderScope.containerOf(context, listen: false).read(recitationOpenDownloadsProvider);
  if (routed != null) {
    routed(context, reciter);
    return Future.value();
  }
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'recitation/downloads'),
      pageBuilder: (_, _, _) => RecitationDownloadsScreen(reciter: reciter),
      transitionDuration: MadarMotion.medium,
      reverseTransitionDuration: MadarMotion.medium,
      transitionsBuilder: MadarTransitions.sharedAxisHorizontalTransitions,
    ),
  );
}

/// Every surah of one reciter: download, pause, resume, cancel or delete it;
/// progress per surah; the whole mushaf at the top.
class RecitationDownloadsScreen extends ConsumerWidget {
  const RecitationDownloadsScreen({super.key, required this.reciter});

  final Reciter reciter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final battery = ref.watch(appSettingsProvider.select((s) => s.powerMode == PowerMode.batterySaver));
    ref.watch(recitationDownloadsTickProvider);
    final downloads = ref.read(recitationDownloadsProvider);
    final s = downloads.summaryOf(reciter.id);
    final name = reciter.name(arabic: fmt.isArabic);
    return MadarScaffold(
      title: l.recitationDownloadsTitle(name),
      extendBodyBehindAppBar: true,
      animateBackdrop: !battery,
      backdropSeed: 0.61,
      // The scaffold's body knows the app bar and system insets.
      body: Builder(
        builder: (context) {
          final padding = MediaQuery.paddingOf(context);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, padding.top + Space.s, Space.gutter, Space.m),
                sliver: SliverToBoxAdapter(
                  child: GlassPanel(
                    glowColor: s.active > 0 ? t.accentGlow : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            ProgressRing(
                              value: s.completeSurahs / 114,
                              size: 56,
                              strokeWidth: 4,
                              color: t.metalGold,
                              gradientEnd: t.accent,
                              trackColor: t.brassDark.withValues(alpha: 0.4),
                              glow: s.active > 0,
                              child: Text(
                                fmt.formatPercent(s.completeSurahs / 114),
                                style: text.labelSmall!.copyWith(color: t.textPrimary),
                              ),
                            ),
                            const SizedBox(width: Space.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.recitationSurahProgress(fmt.formatInt(s.completeSurahs), fmt.formatInt(114)),
                                    style: text.titleMedium,
                                  ),
                                  Text(
                                    [
                                      RecitationLabels.size(l, fmt, s.bytes),
                                      RecitationLabels.style(l, reciter.style),
                                      RecitationLabels.bitrate(l, fmt, reciter),
                                    ].join(l.commonFactSeparator),
                                    style: text.bodySmall!.copyWith(color: t.textTertiary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: Space.m),
                        Wrap(
                          spacing: Space.s,
                          runSpacing: Space.s,
                          children: [
                            if (!s.wholeMushaf && s.active == 0)
                              MadarButton(
                                label: s.paused > 0 ? l.recitationResumeDownloads : l.recitationDownloadMushaf,
                                icon: s.paused > 0 ? Icons.play_arrow_rounded : Icons.download_rounded,
                                size: MadarButtonSize.small,
                                onPressed: () => unawaited(
                                  s.paused > 0
                                      ? downloads.resumeAll(reciter: reciter)
                                      : downloads.downloadMushaf(reciter),
                                ),
                              ),
                            if (s.active > 0)
                              MadarButton(
                                label: l.recitationPauseDownloads,
                                icon: Icons.pause_rounded,
                                variant: MadarButtonVariant.secondary,
                                size: MadarButtonSize.small,
                                onPressed: () => unawaited(downloads.pauseAll()),
                              ),
                            if (s.bytes > 0)
                              MadarButton(
                                label: l.recitationDeleteDownloads,
                                icon: Icons.delete_outline_rounded,
                                variant: MadarButtonVariant.danger,
                                size: MadarButtonSize.small,
                                sfx: Sfx.tap,
                                onPressed: () => unawaited(confirmDeleteReciter(context, ref, reciter)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, 0, Space.gutter, padding.bottom + Space.xxxl),
                sliver: SliverList.builder(
                  itemCount: 114,
                  itemBuilder: (context, i) => _SurahRow(key: ValueKey(i + 1), reciter: reciter, surah: i + 1),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SurahRow extends ConsumerWidget {
  const _SurahRow({super.key, required this.reciter, required this.surah});

  final Reciter reciter;
  final int surah;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    ref.watch(recitationDownloadsTickProvider);
    final catalog = ref.watch(recitationCatalogProvider).value;
    final downloads = ref.read(recitationDownloadsProvider);
    final d = downloads.statusOf(reciter.id, surah);
    final name = recitationSurahName(catalog, surah, l, fmt);
    final facts = <String>[
      fmt.localizeDigits(l.recitationAyatCount(SurahMath.ayahCount(surah))),
      if (d.status != DownloadStatus.none) RecitationLabels.status(l, d.status),
      if (d.status == DownloadStatus.failed && d.error != null) RecitationLabels.downloadError(l, d.error!),
      if (d.bytes > 0) RecitationLabels.size(l, fmt, d.bytes),
    ];
    final busy = d.status.pending;

    List<Widget> actions() {
      Widget button(IconData icon, String label, VoidCallback onPressed, {Sfx sfx = Sfx.tap}) => MadarButton.icon(
        icon: icon,
        onPressed: onPressed,
        semanticLabel: '$label – $name',
        variant: MadarButtonVariant.ghost,
        size: MadarButtonSize.small,
        sfx: sfx,
      );
      Future<void> delete() async {
        final ok = await confirmRecitationDelete(
          context,
          title: l.recitationDeleteSurahConfirm(name),
          body: l.recitationDeleteConfirmHint(RecitationLabels.size(l, fmt, d.bytes)),
        );
        if (ok) {
          Fx.fire(Sfx.delete);
          await downloads.delete(reciter, surah: surah);
        }
      }

      return switch (d.status) {
        DownloadStatus.none => [
          button(
            Icons.download_rounded,
            l.recitationDownloadSurah,
            () => unawaited(downloads.download(reciter, [surah])),
          ),
        ],
        DownloadStatus.queued || DownloadStatus.downloading => [
          button(Icons.pause_rounded, l.recitationPauseDownloads, () => unawaited(downloads.pause(reciter, surah))),
          button(
            Icons.close_rounded,
            l.recitationCancelDownload,
            () => unawaited(downloads.cancel(reciter, surah)),
            sfx: Sfx.delete,
          ),
        ],
        DownloadStatus.paused || DownloadStatus.waitingForWifi || DownloadStatus.failed => [
          button(
            Icons.play_arrow_rounded,
            l.recitationResumeDownloads,
            () => unawaited(downloads.resume(reciter, surah)),
          ),
          button(
            Icons.close_rounded,
            l.recitationCancelDownload,
            () => unawaited(downloads.cancel(reciter, surah)),
            sfx: Sfx.delete,
          ),
        ],
        DownloadStatus.complete => [
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s),
            child: Icon(Icons.download_done_rounded, color: t.success, size: 20),
          ),
          button(Icons.delete_outline_rounded, l.recitationDeleteDownloads, () => unawaited(delete())),
        ],
      };
    }

    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: Space.s),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.xs, Space.s),
      decoration: BoxDecoration(
        color: t.glassFill,
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(
          color: d.isComplete ? t.gold.withValues(alpha: 0.55) : t.glassBorder,
          width: d.isComplete ? 1.1 : 0.8,
        ),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                IslamicStar(size: 34, color: d.isComplete ? t.gold : t.brass.withValues(alpha: 0.55)),
                Text(fmt.formatInt(surah), style: text.labelSmall!.copyWith(color: t.textPrimary, height: 1)),
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: text.titleMedium!.copyWith(height: 1.3)),
                Text(
                  facts.join(l.commonFactSeparator),
                  style: text.bodySmall!.copyWith(
                    color: d.status == DownloadStatus.failed ? t.warning : t.textTertiary,
                    height: 1.35,
                  ),
                ),
                if (busy || (d.status.resumable && d.filesDone > 0))
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: Space.xs, end: Space.s),
                    child: Semantics(
                      label: l.recitationFilesProgress(fmt.formatInt(d.filesDone), fmt.formatInt(d.filesTotal)),
                      excludeSemantics: true,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: d.progress),
                        duration: context.motion(MadarMotion.short),
                        builder: (context, v, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: v,
                            minHeight: 3,
                            color: busy ? t.accent : t.brass,
                            backgroundColor: t.brassDark.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ...actions(),
        ],
      ),
    );
  }
}
