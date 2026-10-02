import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../application/recitation_actions.dart';
import '../../application/recitation_providers.dart';
import '../../domain/reciters.dart';
import '../recitation_labels.dart';

/// One reciter to choose: selection mark, name, style · quality (and what
/// is downloaded), and a sample button.
class ReciterRow extends ConsumerWidget {
  const ReciterRow({
    super.key,
    required this.reciter,
    required this.selected,
    required this.onSelect,
    this.showSample = true,
  });

  final Reciter reciter;
  final bool selected;
  final VoidCallback onSelect;

  /// Offer the sample button (not while something else is being recited).
  final bool showSample;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    ref.watch(recitationStateProvider);
    ref.watch(recitationDownloadsTickProvider);
    final player = ref.read(recitationPlayerProvider);
    final sampling = player.isSampleOf(reciter);
    final downloads = ref.read(recitationDownloadsProvider).summaryOf(reciter.id);
    final facts = [
      RecitationLabels.style(l, reciter.style),
      RecitationLabels.bitrate(l, fmt, reciter),
      if (downloads.wholeMushaf)
        l.recitationWholeMushafDownloaded
      else if (downloads.completeSurahs > 0)
        fmt.localizeDigits(l.recitationSurahsDownloaded(downloads.completeSurahs)),
    ];
    final name = reciter.name(arabic: fmt.isArabic);
    return MadarPressable(
      onTap: onSelect,
      sfx: Sfx.toggleOn,
      selected: selected,
      semanticLabel: selected ? '$name، ${l.recitationChosen}' : l.recitationChoose(name),
      child: AnimatedContainer(
        duration: context.motion(MadarMotion.medium),
        curve: MadarMotion.standard,
        margin: const EdgeInsetsDirectional.only(bottom: Space.s),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s, Space.xs, Space.s),
        decoration: BoxDecoration(
          color: selected ? t.accentSoft : t.glassFill,
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(
            color: selected ? t.accent.withValues(alpha: 0.7) : t.glassBorder,
            width: selected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? t.accent : t.textTertiary,
              size: 22,
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: text.titleMedium!.copyWith(height: 1.3, color: selected ? t.textPrimary : null)),
                  Text(
                    facts.join(l.commonFactSeparator),
                    style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.35),
                  ),
                ],
              ),
            ),
            if (showSample)
              MadarButton.icon(
                icon: sampling ? Icons.stop_rounded : Icons.play_arrow_rounded,
                onPressed: () => unawaited(RecitationActions.toggleSample(ref, reciter)),
                semanticLabel: sampling ? l.recitationSampleStop : l.recitationSampleOf(name),
                variant: sampling ? MadarButtonVariant.primary : MadarButtonVariant.ghost,
                size: MadarButtonSize.small,
              ),
          ],
        ),
      ),
    );
  }
}

/// The reciters grouped by style, each group headed by its name and a
/// one-line explanation.
class ReciterList extends ConsumerWidget {
  const ReciterList({super.key, required this.selected, required this.onSelect, this.showSamples = true});

  final Reciter selected;
  final ValueChanged<Reciter> onSelect;
  final bool showSamples;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final style in ReciterStyle.values) ...[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.m, Space.xs, Space.s),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(RecitationLabels.styleIcon(style), size: 16, color: t.gold),
                const SizedBox(width: Space.s),
                Text(RecitationLabels.style(l, style), style: text.titleSmall!.copyWith(color: t.gold)),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    RecitationLabels.styleHint(l, style),
                    style: text.bodySmall!.copyWith(color: t.textTertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final r in Reciters.all.where((r) => r.style == style))
            ReciterRow(
              key: ValueKey('reciter-${r.id}'),
              reciter: r,
              selected: r == selected,
              onSelect: () => onSelect(r),
              showSample: showSamples,
            ),
        ],
      ],
    );
  }
}

/// A sheet to switch reciter (from the player). The choice is saved and
/// applied to what is playing.
Future<void> showReciterPickerSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const _ReciterPickerSheet());

class _ReciterPickerSheet extends ConsumerWidget {
  const _ReciterPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final state = ref.watch(recitationStateProvider);
    final chosen = ref.watch(recitationReciterProvider);
    final player = ref.read(recitationPlayerProvider);
    final current = state.active && !player.isSampleOf(state.reciter) ? state.reciter : chosen;
    return InteractionSheetFrame(
      title: l.recitationChangeReciter,
      subtitle: l.recitationSectionRecitersHint,
      icon: Icons.record_voice_over_rounded,
      footer: SheetButton(label: l.actionDone, primary: true, onPressed: () => Navigator.of(context).maybePop()),
      body: ReciterList(
        showSamples: !state.active || player.isSampleOf(state.reciter),
        selected: current,
        onSelect: (r) => unawaited(RecitationActions.chooseReciter(ref, r)),
      ),
    );
  }
}
