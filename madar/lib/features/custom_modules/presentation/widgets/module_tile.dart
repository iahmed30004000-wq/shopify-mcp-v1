import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../custom_texts.dart';
import '../../data/custom_modules_providers.dart';
import '../../domain/module_schema.dart';
import '../../domain/module_summary.dart';
import '../custom_modules_actions.dart';
import '../custom_modules_navigation.dart';
import 'module_visuals.dart';
import 'quick_log_button.dart';

/// One module in the list: its orb, name, where it stands ("Last entry
/// today" / "3 of 5 done"), planet / window / streak badges, a faint
/// sparkline of the last week along its foot and the one-tap log control.
///
/// Tap = open; swipe right = one-tap log (check-in / counter); swipe left =
/// new entry / archive / delete; long-press = everything else.
class ModuleTile extends ConsumerWidget {
  const ModuleTile({super.key, required this.summary, this.dragHandle, this.onOpenModule, this.compact = false});

  final ModuleSummary summary;
  final Widget? dragHandle;
  final CustomOpenModule? onOpenModule;

  /// Tighter layout for planet cards.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final m = summary.module;
    final c = ModuleColors.of(m.colorArgb, t);
    final now = ref.watch(customModulesClockProvider)();
    final planets = ref.watch(customPlanetChoicesProvider).value ?? const [];
    final planet = planets.where((p) => p.key == m.planetKey).firstOrNull;
    final ar = tx.arabic;
    final streak = summary.chart?.currentStreak ?? 0;
    final quick = m.quickEntry;
    final oneTapSwipe = quick is QuickCheck || quick is QuickCount;

    final status = m.isList
        ? (summary.entryCount == 0 ? tx.items(0) : tx.itemsProgress(summary.doneCount, summary.entryCount))
        : tx.lastEntry(summary, now);

    void open() {
      final cb = onOpenModule;
      if (cb != null) {
        cb(context, m.id);
      } else {
        CustomModulesNavigation.openModule(context, m.id);
      }
    }

    final badges = <Widget>[
      if (planet != null)
        ModuleBadge(label: ar ? planet.nameAr : planet.nameEn, color: ModuleColors.of(planet.color, t).ink, icon: Icons.public_rounded),
      if (m.window != null && m.window != PrayerWindow.anytime)
        ModuleBadge(label: tx.window(m.window)!, color: t.textSecondary, icon: Icons.mosque_rounded),
      if (streak >= 2)
        ModuleBadge(label: tx.streakBadge(streak), color: t.gold, icon: Icons.local_fire_department_rounded, filled: true),
    ];

    final card = GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      borderColor: summary.checkedToday ? c.base.withValues(alpha: 0.45) : null,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (m.isTracker && summary.sparkline.any((v) => v > 0))
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              height: 34,
              child: Opacity(
                opacity: 0.9,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(t.radiusL)),
                  child: LayoutBuilder(
                    builder: (context, box) =>
                        ModuleSparkline(values: summary.sparkline, color: c.base, width: box.maxWidth, height: 34, line: false),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              Space.m,
              compact ? Space.s + 2 : Space.m,
              dragHandle == null ? Space.m : 0,
              compact ? Space.s + 2 : Space.m,
            ),
            child: Row(
              children: [
                ModuleOrb.of(
                  m,
                  size: compact ? 42 : 50,
                  progress: m.isList && summary.entryCount > 0 ? summary.listProgress : null,
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.name(m.name),
                        style: compact ? text.titleSmall : text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        compact ? status : '${tx.kind(m.kind)} · $status',
                        style: text.bodySmall!.copyWith(color: t.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!compact && badges.isNotEmpty) ...[
                        const SizedBox(height: Space.xs + 2),
                        Wrap(spacing: Space.xs, runSpacing: Space.xs, children: badges),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: Space.s),
                if (m.isTracker)
                  QuickLogButton(summary: summary, size: compact ? 38 : 44)
                else if (summary.openCount > 0)
                  _OpenCount(count: summary.openCount, colors: c)
                else if (summary.entryCount > 0)
                  Icon(Icons.task_alt_rounded, color: t.success, size: 26),
                ?dragHandle,
              ],
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return GestureDetector(onTap: () {
        Fx.fire(Sfx.navigate);
        open();
      }, child: card);
    }

    return ActionableItem(
      semanticLabel: '${m.name} · ${tx.kind(m.kind)} · $status',
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: () {
        Fx.fire(Sfx.navigate);
        open();
      },
      completeIcon: quick is QuickCount ? Icons.add_rounded : Icons.check_rounded,
      completeLabel: quick is QuickCount ? l.cmodQuickAddOne : l.cmodQuickDone,
      onCompleteSwipe: oneTapSwipe
          ? () => CustomModulesActions.quickLog(context, ref, m, toast: false, sound: false)
          : null,
      actions: ItemActions(
        onEdit: () => CustomModulesNavigation.openBuilder(context, moduleId: m.id),
        onDuplicate: () => CustomModulesActions.duplicateModule(context, ref, m),
        onDelete: () => CustomModulesActions.deleteModule(context, ref, m),
        extra: [
          ItemAction(
            icon: m.isTracker ? Icons.add_circle_outline_rounded : Icons.playlist_add_rounded,
            label: m.isTracker ? l.cmodActionAddEntry : l.cmodAddItem,
            tone: ActionTone.accent,
            onSelected: () async {
              await CustomModulesActions.addEntry(context, ref, m);
              return null;
            },
          ),
          ItemAction(
            icon: Icons.ios_share_rounded,
            label: l.cmodActionExport,
            onSelected: () async {
              await CustomModulesActions.shareCsv(context, ref, m);
              return null;
            },
          ),
          ItemAction(
            icon: m.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: m.archived ? l.cmodActionUnarchive : l.cmodActionArchive,
            tone: ActionTone.warning,
            onSelected: () => CustomModulesActions.setArchived(context, ref, m, !m.archived),
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: Icons.add_rounded,
          label: m.isTracker ? l.cmodActionAddEntry : l.cmodAddItem,
          onPressed: () async {
            await CustomModulesActions.addEntry(context, ref, m);
            return null;
          },
        ),
        QuickAction(
          icon: m.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
          label: m.archived ? l.cmodActionUnarchive : l.cmodActionArchive,
          tone: ActionTone.warning,
          onPressed: () => CustomModulesActions.setArchived(context, ref, m, !m.archived),
        ),
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: MaterialLocalizations.of(context).deleteButtonTooltip,
          tone: ActionTone.danger,
          onPressed: () {
            Fx.fire(Sfx.delete);
            return CustomModulesActions.deleteModule(context, ref, m);
          },
        ),
      ],
      child: card,
    );
  }
}

class _OpenCount extends StatelessWidget {
  const _OpenCount({required this.count, required this.colors});

  final int count;
  final ModuleColors colors;

  @override
  Widget build(BuildContext context) {
    final tx = CustomTexts.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: Space.s),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.soft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.base.withValues(alpha: 0.45)),
      ),
      child: Semantics(
        label: tx.openItems(count),
        excludeSemantics: true,
        child: Text(
          tx.count(count),
          style: Theme.of(context).textTheme.titleSmall!.copyWith(color: colors.ink, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
