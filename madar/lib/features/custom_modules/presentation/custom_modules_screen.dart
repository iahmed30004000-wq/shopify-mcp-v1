import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../custom_texts.dart';
import '../data/custom_modules_providers.dart';
import '../domain/module_summary.dart';
import '../domain/module_templates.dart';
import 'custom_modules_actions.dart';
import 'custom_modules_navigation.dart';
import 'widgets/module_tile.dart';
import 'widgets/module_visuals.dart';

/// Trackers & lists: every module the user built, in their own drag-and-drop
/// order, each with its one-tap log, plus the archived ones and the entry
/// point to the builder (blank or from a template).
class CustomModulesScreen extends ConsumerWidget {
  const CustomModulesScreen({super.key, this.onOpenModule, this.animateBackdrop = true});

  /// Opens a module's page; default: [CustomModulesNavigation.openModule].
  final CustomOpenModule? onOpenModule;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final summaries = ref.watch(customModuleSummariesProvider);
    return MadarScaffold(
      title: l.cmodTitle,
      backdropSeed: 3.4,
      animateBackdrop:
          animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      floatingAction: MadarButton.icon(
        icon: Icons.add_rounded,
        onPressed: () => unawaited(CustomModulesNavigation.startNew(context)),
        semanticLabel: l.cmodNewModule,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
      ),
      body: switch (summaries) {
        AsyncData(value: final all) when all.isEmpty => const _Empty(),
        AsyncData(value: final all) => _ModulesList(summaries: all, onOpenModule: onOpenModule),
        AsyncError() => const Center(child: AnimatedEmptyState(kind: EmptyStateKind.noData)),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }
}

const _listPadding = EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl + Space.xxl);

class _ModulesList extends ConsumerStatefulWidget {
  const _ModulesList({required this.summaries, this.onOpenModule});

  final List<ModuleSummary> summaries;
  final CustomOpenModule? onOpenModule;

  @override
  ConsumerState<_ModulesList> createState() => _ModulesListState();
}

class _ModulesListState extends ConsumerState<_ModulesList> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final live = [
      for (final s in widget.summaries)
        if (!s.module.archived) s,
    ];
    final archived = [
      for (final s in widget.summaries)
        if (s.module.archived) s,
    ];
    return ReorderableGlassList<ModuleSummary>(
      items: live,
      itemKey: (s) => s.id,
      padding: _listPadding,
      spacing: Space.s,
      itemBorderRadius: BorderRadius.circular(t.radiusL),
      header: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Space.m),
        child: _Hero(summaries: live),
      ),
      itemBuilder: (context, s, index, handle) =>
          ModuleTile(key: ValueKey(s.id), summary: s, dragHandle: handle, onOpenModule: widget.onOpenModule),
      onReorder: (order) => unawaited(
        CustomModulesActions.reorderModules(ref, [...order.map((s) => s.id), ...archived.map((s) => s.id)]),
      ),
      footer: archived.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  button: true,
                  expanded: _showArchived,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(t.radiusM),
                    onTap: () {
                      Fx.fire(_showArchived ? Sfx.sheetClose : Sfx.sheetOpen);
                      setState(() => _showArchived = !_showArchived);
                    },
                    child: ModuleSectionTitle(
                      title: l.cmodArchivedSection,
                      count: tx.count(archived.length),
                      color: t.textTertiary,
                      trailing: AnimatedRotation(
                        turns: _showArchived ? 0.5 : 0,
                        duration: context.motion(MadarMotion.short),
                        child: Icon(Icons.expand_more_rounded, color: t.textTertiary),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: context.motion(MadarMotion.medium),
                  curve: MadarMotion.emphasized,
                  alignment: Alignment.topCenter,
                  child: _showArchived
                      ? Column(
                          children: [
                            for (final s in archived)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                                child: Opacity(
                                  opacity: 0.7,
                                  child: ModuleTile(key: ValueKey(s.id), summary: s, onOpenModule: widget.onOpenModule),
                                ),
                              ),
                          ],
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
    );
  }
}

/// Today at a glance: how many modules and entries, and the modules' orbs.
class _Hero extends ConsumerWidget {
  const _Hero({required this.summaries});

  final List<ModuleSummary> summaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    final today = summaries.fold<int>(0, (n, s) => n + (s.module.isTracker ? s.todayCount : 0));
    final checked = summaries.where((s) => s.checkedToday).length;
    final oneTap = summaries.where((s) => s.module.quickEntry != null).length;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusXL),
      padding: const EdgeInsets.all(Space.l),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.modules(summaries.length), style: text.headlineSmall!.copyWith(color: t.textPrimary)),
                const SizedBox(height: Space.xs),
                Text(tx.loggedToday(today), style: text.bodyMedium!.copyWith(color: t.textSecondary)),
                if (oneTap > 0) ...[
                  const SizedBox(height: Space.m),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: oneTap == 0 ? 0 : checked / oneTap,
                      minHeight: 5,
                      backgroundColor: t.glassBorder,
                      valueColor: AlwaysStoppedAnimation(t.gold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Space.m),
          _OrbCluster(summaries: summaries),
        ],
      ),
    );
  }
}

/// Up to five module orbs circling a brass star – the modules as little
/// worlds.
class _OrbCluster extends StatelessWidget {
  const _OrbCluster({required this.summaries});

  final List<ModuleSummary> summaries;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shown = summaries.take(5).toList();
    const size = 92.0;
    const radius = 34.0;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.metalBrass.withValues(alpha: 0.35), width: 0.8),
              ),
            ),
            IslamicStar(size: 18, color: t.metalGold, glow: true),
            for (var i = 0; i < shown.length; i++)
              Transform.translate(
                offset: Offset.fromDirection(-1.2 + i * (6.283 / 5), radius),
                child: ModuleOrb.of(shown[i].module, size: 22, glow: false),
              ),
          ],
        ),
      ),
    );
  }
}

/// No modules yet: what they are for, with generic starters.
class _Empty extends ConsumerWidget {
  const _Empty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = CustomTexts.of(context);
    final l = tx.l;
    const picks = [ModuleTemplateKey.readingLog, ModuleTemplateKey.dhikrCounter, ModuleTemplateKey.habitList];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.gutter),
        child: Column(
          children: [
            AnimatedEmptyState(
              kind: EmptyStateKind.emptyList,
              title: l.cmodEmptyTitle,
              body: l.cmodEmptyBody,
              actionLabel: l.cmodEmptyAction,
              actionIcon: Icons.add_rounded,
              onAction: () => unawaited(CustomModulesNavigation.startNew(context)),
            ),
            const SizedBox(height: Space.m),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final k in picks)
                  MadarChip(
                    label: tx.templateName(k),
                    icon: ModuleIcons.module(ModuleTemplates.build(k, tx.template).iconKey),
                    onSelected: (_) => unawaited(
                      CustomModulesNavigation.openBuilder(context, draft: ModuleTemplates.build(k, tx.template)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
