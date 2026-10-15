import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/wellbeing_settings.dart';
import '../sheets/worry_sheets.dart';
import '../wellbeing_actions.dart';
import '../wellbeing_screen.dart';
import '../wellbeing_texts.dart';
import '../widgets/wb_widgets.dart';

/// The worry window: park a worry any time, review the parked ones at the
/// user's daily time. Parked worries reorder by drag; resolved ones keep
/// their reflection.
class WorriesTab extends ConsumerStatefulWidget {
  const WorriesTab({super.key});

  @override
  ConsumerState<WorriesTab> createState() => _WorriesTabState();
}

class _WorriesTabState extends ConsumerState<WorriesTab> {
  final TextEditingController _park = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _showResolved = false;

  @override
  void initState() {
    super.initState();
    _park.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _park.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _parkNow() async {
    final text = _park.text.trim();
    if (text.isEmpty) {
      Fx.fire(Sfx.error);
      return;
    }
    await ref.read(wellbeingServiceProvider).parkWorry(text);
    Fx.fire(Sfx.drop);
    _park.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final parked = ref.watch(parkedWorriesProvider);
    final all = ref.watch(worriesProvider).value ?? const <WorryRow>[];
    final resolved = [
      for (final w in all.reversed)
        if (w.resolved) w,
    ];
    return ReorderableGlassList<WorryRow>(
      items: parked,
      itemKey: (w) => w.id,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, wbTabBottomPadding),
      spacing: Space.s,
      onReorder: (order) => ref.read(wellbeingServiceProvider).reorderWorries([for (final w in order) w.id]),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _WindowCard(),
          const SizedBox(height: Space.m),
          WbCard(
            title: l.wbWorryParkTitle,
            icon: Icons.inventory_2_outlined,
            seed: 7.2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.wbWorryParkExplain, style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.5)),
                const SizedBox(height: Space.m),
                TextField(
                  controller: _park,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _parkNow(),
                  decoration: InputDecoration(hintText: l.wbWorryParkHint),
                ),
                const SizedBox(height: Space.s),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: MadarButton(
                    label: l.wbWorryPark,
                    icon: Icons.move_to_inbox_rounded,
                    size: MadarButtonSize.small,
                    sfx: Sfx.tap,
                    onPressed: _park.text.trim().isEmpty ? null : _parkNow,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.m),
          SectionHeader(
            title: context.formatter.localizeDigits(
              l.wbWorriesParked(parked.length, context.formatter.formatInt(parked.length)),
            ),
          ),
          if (parked.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.m),
              child: WbHint(l.wbWorriesNone),
            ),
        ],
      ),
      footer: resolved.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Space.m),
                SectionHeader(
                  title: context.formatter.localizeDigits(
                    l.wbWorriesResolved(resolved.length, context.formatter.formatInt(resolved.length)),
                  ),
                  actionLabel: _showResolved ? l.wbShowLess : l.wbShowAll,
                  onAction: () => setState(() => _showResolved = !_showResolved),
                ),
                AnimatedSize(
                  duration: context.motion(MadarMotion.medium),
                  alignment: AlignmentDirectional.topStart,
                  child: !_showResolved
                      ? const SizedBox(width: double.infinity)
                      : Column(
                          children: [
                            for (final w in resolved)
                              Padding(
                                padding: const EdgeInsets.only(bottom: Space.s),
                                child: WorryTile(worry: w),
                              ),
                          ],
                        ),
                ),
              ],
            ),
      itemBuilder: (context, w, index, grip) => WorryTile(worry: w, grip: grip),
    );
  }
}

class _WindowCard extends ConsumerWidget {
  const _WindowCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final settings = (ref.watch(wellbeingSettingsProvider).value ?? const WellbeingSettings()).worry;
    final status = ref.watch(worryWindowStatusProvider);
    final parked = ref.watch(parkedWorriesProvider).length;
    final now = ref.watch(wellbeingNowProvider).value ?? ref.watch(wellbeingClockProvider)();
    if (!settings.enabled) {
      return WbCard(
        title: l.wbWorryWindowTitle,
        icon: Icons.hourglass_empty_rounded,
        seed: 8.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.wbWorryWindowExplain, style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.5)),
            const SizedBox(height: Space.m),
            MadarButton(
              label: l.wbWorryWindowSet,
              icon: Icons.schedule_rounded,
              variant: MadarButtonVariant.secondary,
              expand: true,
              sfx: Sfx.sheetOpen,
              onPressed: () => showWorryWindowSheet(context),
            ),
          ],
        ),
      );
    }
    final open = status.isOpen;
    final remaining = status.remaining(now);
    final statusText = open
        ? l.wbWorryWindowOpenNow(fmt.formatDurationWords(l, remaining))
        : l.wbWorryWindowOpensIn(fmt.formatDurationWords(l, remaining));
    final summary = fmt.localizeDigits(
      l.wbWorryWindowSummary(
        fmt.formatClock(settings.hour, settings.minute),
        l.wbMinutes(settings.durationMinutes, fmt.formatInt(settings.durationMinutes)),
      ),
    );
    return WbCard(
      title: l.wbWorryWindowTitle,
      icon: open ? Icons.hourglass_bottom_rounded : Icons.hourglass_empty_rounded,
      seed: 8.4,
      tint: open ? t.gold.withValues(alpha: 0.07) : null,
      trailing: MadarButton.icon(
        icon: Icons.edit_outlined,
        semanticLabel: l.wbWorryWindowEdit,
        variant: MadarButtonVariant.ghost,
        size: MadarButtonSize.small,
        sfx: Sfx.sheetOpen,
        onPressed: () => showWorryWindowSheet(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(summary, style: text.titleSmall?.copyWith(color: t.gold)),
          const SizedBox(height: Space.xxs),
          Text(statusText, style: text.bodySmall?.copyWith(color: open ? t.textPrimary : t.textSecondary)),
          const SizedBox(height: Space.m),
          MadarButton(
            label: parked == 0
                ? l.wbWorryReviewNothing
                : fmt.localizeDigits(l.wbWorryReviewStart(parked, fmt.formatInt(parked))),
            icon: Icons.playlist_add_check_rounded,
            variant: open ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
            expand: true,
            sfx: Sfx.sheetOpen,
            onPressed: parked == 0 ? null : () => showWorryReviewSheet(context),
          ),
        ],
      ),
    );
  }
}

/// A worry row (parked: drag grip; resolved: its reflection).
class WorryTile extends ConsumerWidget {
  const WorryTile({super.key, required this.worry, this.grip});

  final WorryRow worry;
  final Widget? grip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final today = ref.watch(wellbeingTodayProvider);
    final resolved = worry.resolved;
    return ActionableItem(
      semanticLabel: worry.body,
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () => WellbeingActions.editWorry(context, ref, worry),
      completeLabel: resolved ? l.wbWorryReopen : l.wbWorryResolved,
      completeIcon: resolved ? Icons.replay_rounded : Icons.check_rounded,
      onCompleteSwipe: () => resolved
          ? WellbeingActions.reopenWorry(context, ref, worry)
          : WellbeingActions.resolveWorry(context, ref, worry),
      actions: ItemActions(
        onEdit: () => WellbeingActions.editWorry(context, ref, worry),
        onDelete: () => WellbeingActions.deleteWorry(context, ref, worry),
        extra: [
          ItemAction(
            icon: resolved ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
            label: resolved ? l.wbWorryReopen : l.wbWorryResolved,
            tone: resolved ? ActionTone.neutral : ActionTone.success,
            onSelected: () => resolved
                ? WellbeingActions.reopenWorry(context, ref, worry)
                : WellbeingActions.resolveWorry(context, ref, worry),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.wbDelete,
          tone: ActionTone.danger,
          onPressed: () => WellbeingActions.deleteWorry(context, ref, worry),
        ),
      ],
      child: GlassCard(
        padding: EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, grip == null ? Space.l : Space.xs, Space.m),
        borderRadius: BorderRadius.circular(t.radiusL),
        glow: false,
        child: Row(
          children: [
            Icon(
              resolved ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: resolved ? t.success : t.textTertiary,
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worry.body,
                    style: text.bodyMedium?.copyWith(color: resolved ? t.textSecondary : t.textPrimary, height: 1.45),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: Space.xxs),
                  Text(
                    l.wbWorryParkedOn(tx.relativeDay(worry.createdAt, today)),
                    style: text.labelSmall?.copyWith(color: t.textTertiary),
                  ),
                  if (worry.reflection != null) ...[
                    const SizedBox(height: Space.xs),
                    Text(
                      worry.reflection!,
                      style: text.bodySmall?.copyWith(color: t.gold, fontStyle: FontStyle.italic),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            ?grip,
          ],
        ),
      ),
    );
  }
}
