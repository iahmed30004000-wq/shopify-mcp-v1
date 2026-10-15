/// «خريطة الصفحات» · the mushaf coloured by strength (Part 14, step 2).
///
/// One cell per page of the Madani mushaf, coloured by the band
/// [HifzPageMap] computed from his own results – and the legend says what
/// each colour means, right above them, because a colour nobody can read
/// is a decoration and not a map.
///
/// A page he has never been tested on is **not** coloured warm: it is the
/// absence of a result, not a bad one, and it is drawn as an empty ring.
///
/// Tapping a page opens what is on it, and the two decisions that are his
/// alone: «مش عليّ» and «صفّر قوة هاي الصفحة».
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/sound/sound_api.dart';
import '../../../wird/data/wird_providers.dart' show quranCatalogReadyProvider;
import '../../data/hifz_plan_providers.dart';
import '../../domain/hifz_page_map.dart';
import '../../domain/hifz_strength.dart';
import 'hifz_plan_texts.dart';
import 'hifz_plan_widgets.dart';

/// The mushaf as a grid of pages, coloured by how strongly he holds them.
class HifzMapScreen extends ConsumerStatefulWidget {
  const HifzMapScreen({super.key, this.animateBackdrop = true});

  final bool animateBackdrop;

  @override
  ConsumerState<HifzMapScreen> createState() => _HifzMapScreenState();
}

class _HifzMapScreenState extends ConsumerState<HifzMapScreen> {
  /// Only the pages something of his sits on, by default: 604 grey cells
  /// say nothing.
  bool _mineOnly = true;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final map = ref.watch(hifzPageMapProvider);
    final texts = HifzPlanTexts.of(context, catalog: ref.watch(quranCatalogReadyProvider).value);
    return MadarScaffold(
      title: l.hifzMapTitle,
      backdropSeed: 4.6,
      animateBackdrop:
          widget.animateBackdrop &&
          ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      body: switch (map) {
        AsyncData(value: final m) => _body(m, texts),
        AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.hifzCatalogError, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  Widget _body(HifzPageMap map, HifzPlanTexts texts) {
    final l = L10n.of(context);
    final t = context.tokens;
    final pages = _mineOnly ? map.touchedPages : map.pages;
    return ListView(
      key: const PageStorageKey('hifz.map'),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl),
      children: [
        HifzPanel(
          key: const ValueKey('hifz.map.legend'),
          title: l.hifzMapColourMeans,
          icon: Icons.palette_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HifzBandLegend(texts: texts),
              const SizedBox(height: Space.s),
              Text(
                l.hifzMapLegend,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        Wrap(
          spacing: Space.s,
          children: [
            MadarChip(
              key: const ValueKey('hifz.map.mine'),
              label: l.hifzMapOnlyMine,
              selected: _mineOnly,
              dense: true,
              onSelected: (_) => setState(() => _mineOnly = true),
            ),
            MadarChip(
              key: const ValueKey('hifz.map.all'),
              label: l.hifzMapWholeMushaf,
              selected: !_mineOnly,
              dense: true,
              onSelected: (_) => setState(() => _mineOnly = false),
            ),
          ],
        ),
        const SizedBox(height: Space.m),
        if (pages.isEmpty)
          AnimatedEmptyState(
            key: const ValueKey('hifz.map.empty'),
            kind: EmptyStateKind.emptyList,
            title: l.hifzMapTitle,
            body: l.hifzMapEmpty,
          )
        else
          GridView.builder(
            key: const ValueKey('hifz.map.grid'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 56,
              mainAxisSpacing: Space.s,
              crossAxisSpacing: Space.s,
              childAspectRatio: 1,
            ),
            itemCount: pages.length,
            itemBuilder: (context, i) => _PageCell(
              page: pages[i],
              texts: texts,
              onTap: () => unawaited(showHifzPageSheet(context, ref, pages[i], texts)),
            ),
          ),
        const HifzHonestyNote(),
      ],
    );
  }
}

/// One page: its number over its colour. Big enough to tap (48 dp) and
/// labelled for TalkBack with the band's own name, never by colour alone.
class _PageCell extends StatelessWidget {
  const _PageCell({required this.page, required this.texts, required this.onTap});

  final PageStrength page;
  final HifzPlanTexts texts;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fmt = MadarFormatter.of(context);
    final color = texts.bandColor(page.band);
    final untested = page.band == StrengthBand.unknown;
    return MadarPressable(
      key: ValueKey('hifz.map.page.${page.page}'),
      onTap: onTap,
      minTapTarget: const Size(48, 48),
      semanticLabel: [
        L10n.of(context).hifzMapPageTitle(fmt.formatInt(page.page, grouping: false)),
        texts.band(page.band),
      ].join('. '),
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusS),
      child: Container(
        decoration: BoxDecoration(
          color: untested ? Colors.transparent : color.withValues(alpha: 0.28),
          border: Border.all(color: color.withValues(alpha: untested ? 0.5 : 0.9), width: 1.2),
          borderRadius: BorderRadius.circular(t.radiusS),
        ),
        alignment: Alignment.center,
        child: Text(
          fmt.formatInt(page.page, grouping: false),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: untested ? t.textTertiary : t.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// What is on a page, and the two decisions that are his: «مش عليّ» and
/// «صفّر قوة هاي الصفحة». Nothing is deleted either way – the log keeps
/// every attempt.
Future<void> showHifzPageSheet(
  BuildContext context,
  WidgetRef ref,
  PageStrength page,
  HifzPlanTexts texts,
) async {
  final l = L10n.of(context);
  final fmt = MadarFormatter.of(context);
  await showInteractionSheet<void>(
    context,
    builder: (sheetContext) => InteractionSheetFrame(
      title: l.hifzMapPageTitle(fmt.formatInt(page.page, grouping: false)),
      subtitle: texts.range(page.range),
      icon: Icons.menu_book_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HifzBandDot(band: page.band, texts: texts, size: 14),
              const SizedBox(width: Space.s),
              Text(texts.band(page.band), style: Theme.of(sheetContext).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(
            fmt.localizeDigits(
              l.hifzMapPageLine(
                fmt.formatInt(page.page, grouping: false),
                fmt.formatInt(page.memorised),
                fmt.formatInt(page.ayatOnPage),
              ),
            ),
            style: Theme.of(sheetContext).textTheme.bodyMedium,
          ),
          Text(
            fmt.localizeDigits(l.hifzMapTestedLine(texts.ayat(page.tested))),
            style: Theme.of(sheetContext).textTheme.bodySmall,
          ),
          const SizedBox(height: Space.m),
          Text(l.hifzMarkResetBody, style: Theme.of(sheetContext).textTheme.bodySmall),
          const SizedBox(height: Space.m),
          MadarButton(
            key: const ValueKey('hifz.map.reset'),
            label: l.hifzMarkResetPage,
            icon: Icons.restart_alt_rounded,
            variant: MadarButtonVariant.secondary,
            onPressed: () async {
              final service = await ref.read(hifzPlanServiceProvider.future);
              final (_, undo) = await service.resetPage(page.page);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              if (!context.mounted) return;
              Fx.fire(Sfx.complete);
              unawaited(showUndoToast(context, UndoableAction(label: l.hifzMarkResetPage, undo: undo)));
            },
          ),
          const SizedBox(height: Space.s),
          MadarButton(
            key: const ValueKey('hifz.map.skip'),
            label: l.hifzMarkSkip,
            icon: Icons.do_not_disturb_on_outlined,
            variant: MadarButtonVariant.ghost,
            onPressed: () async {
              final service = await ref.read(hifzPlanServiceProvider.future);
              final (_, undo) = await service.markSkipped(page.range);
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              if (!context.mounted) return;
              Fx.fire(Sfx.complete);
              unawaited(showUndoToast(context, UndoableAction(label: l.hifzMarkSkipDone, undo: undo)));
            },
          ),
        ],
      ),
    ),
  );
}
