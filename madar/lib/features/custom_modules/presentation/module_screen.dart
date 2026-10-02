import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show GlassSwitch, StarRating;
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../custom_texts.dart';
import '../data/custom_modules_providers.dart';
import '../domain/field_values.dart';
import '../domain/module_export.dart';
import '../domain/module_schema.dart';
import '../domain/module_summary.dart';
import 'custom_modules_actions.dart';
import 'custom_modules_navigation.dart';
import 'widgets/module_chart_view.dart';
import 'widgets/module_visuals.dart';

/// One module's page. Trackers: the one-tap log, the chart (style and
/// period configurable), reminders and the entries by day. Lists: progress,
/// reminders, the open items (check off, drag to reorder, swipe, undo) and
/// the done ones.
class ModuleScreen extends ConsumerWidget {
  const ModuleScreen({super.key, required this.moduleId, this.animateBackdrop = true});

  final String moduleId;

  /// Pass false in battery-saver mode.
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final module = ref.watch(customModuleProvider(moduleId));
    final entries = ref.watch(customModuleEntriesProvider(moduleId));
    final m = module.value;
    final animate =
        animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver));
    if (m == null) {
      return MadarScaffold(
        title: '',
        animateBackdrop: animate,
        body: Center(
          child: module.isLoading ? const OrbitLoader(size: 40) : const AnimatedEmptyState(kind: EmptyStateKind.noData),
        ),
      );
    }
    final list = entries.value;
    return MadarScaffold(
      title: tx.name(m.name),
      backdropSeed: 4.2,
      animateBackdrop: animate,
      actions: [
        MadarButton.icon(
          icon: Icons.tune_rounded,
          semanticLabel: l.cmodBuilderEditTitle,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.navigate,
          onPressed: () => unawaited(CustomModulesNavigation.openBuilder(context, moduleId: m.id)),
        ),
        MadarButton.icon(
          icon: Icons.more_horiz_rounded,
          semanticLabel: l.cmodModuleMenu,
          variant: MadarButtonVariant.ghost,
          sfx: Sfx.sheetOpen,
          onPressed: () => unawaited(_menu(context, ref, m)),
        ),
      ],
      floatingAction: MadarButton.icon(
        icon: m.isTracker ? Icons.add_rounded : Icons.playlist_add_rounded,
        semanticLabel: m.isTracker ? l.cmodAddEntry : l.cmodAddItem,
        variant: MadarButtonVariant.primary,
        size: MadarButtonSize.large,
        sfx: Sfx.sheetOpen,
        onPressed: () => unawaited(CustomModulesActions.addEntry(context, ref, m)),
      ),
      body: list == null
          ? const Center(child: OrbitLoader(size: 40))
          : m.isTracker
          ? _TrackerBody(module: m, entries: list)
          : _ListBody(module: m, entries: list),
    );
  }

  static Future<void> _menu(BuildContext context, WidgetRef ref, ModuleDefinition m) async {
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final choice = await showInteractionSheet<String>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        Widget row(String id, IconData icon, String label, {Color? color}) => ListTile(
          leading: Icon(icon, color: color ?? t.textSecondary),
          title: Text(label, style: Theme.of(ctx).textTheme.titleSmall!.copyWith(color: color)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusM)),
          onTap: () {
            Fx.fire(Sfx.tap);
            Navigator.of(ctx).pop(id);
          },
        );
        return InteractionSheetFrame(
          title: tx.name(m.name),
          icon: ModuleIcons.module(m.iconKey),
          body: Column(
            children: [
              row('edit', Icons.tune_rounded, l.cmodBuilderEditTitle),
              row('share', Icons.ios_share_rounded, l.cmodActionExport),
              row(
                'archive',
                m.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                m.archived ? l.cmodActionUnarchive : l.cmodActionArchive,
              ),
              row('delete', Icons.delete_outline_rounded, MaterialLocalizations.of(ctx).deleteButtonTooltip, color: t.danger),
            ],
          ),
        );
      },
    );
    if (choice == null || !context.mounted) return;
    switch (choice) {
      case 'edit':
        await CustomModulesNavigation.openBuilder(context, moduleId: m.id);
      case 'share':
        await CustomModulesActions.shareCsv(context, ref, m);
      case 'archive':
        await CustomModulesActions.setArchived(context, ref, m, !m.archived, toast: true);
      case 'delete':
        final nav = Navigator.of(context);
        await CustomModulesActions.deleteModule(context, ref, m, toast: true);
        if (nav.mounted) nav.pop();
    }
  }
}

const _pagePadding = EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl + Space.xxl);

// -------------------------------------------------------------- tracker --

class _TrackerBody extends ConsumerWidget {
  const _TrackerBody({required this.module, required this.entries});

  final ModuleDefinition module;
  final List<ModuleEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = CustomTexts.of(context);
    final l = tx.l;
    ref.watch(customModulesTodayProvider);
    final now = ref.watch(customModulesClockProvider)();
    final summary = ModuleSummary.build(module, entries, now);
    final sorted = [...entries]..sort((a, b) => b.at.compareTo(a.at));

    // Header cards, then day headers and entries.
    final items = <Widget>[
      _Hero(summary: summary),
      if (module.quickEntry != null) ...[const SizedBox(height: Space.m), _QuickCard(summary: summary)],
      const SizedBox(height: Space.m),
      ModuleChartCard(
        module: module,
        entries: entries,
        today: now,
        onConfigChanged: (c) => unawaited(CustomModulesActions.setChart(ref, module, c)),
      ),
      _RemindersSection(module: module),
      ModuleSectionTitle(title: l.cmodEntriesSection, count: tx.count(entries.length)),
      if (sorted.isEmpty) _Hint(icon: Icons.edit_note_rounded, text: l.cmodEntriesEmpty),
    ];
    DateTime? day;
    for (final e in sorted) {
      final d = DateTime(e.at.year, e.at.month, e.at.day);
      if (d != day) {
        day = d;
        items.add(_DayHeader(label: tx.dayLabel(d, now)));
      }
      items.add(
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: Space.s),
          child: _EntryRow(key: ValueKey(e.id), module: module, entry: e),
        ),
      );
    }
    return EntranceChoreo(
      id: 'cmod-module-${module.id}',
      child: ListView.builder(
        padding: _pagePadding,
        itemCount: items.length,
        itemBuilder: (context, i) => i < 8 ? StaggerItem(index: i, child: items[i]) : items[i],
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.summary});

  final ModuleSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    final m = summary.module;
    final c = ModuleColors.of(m.colorArgb, t);
    final planets = ref.watch(customPlanetChoicesProvider).value ?? const [];
    final planet = planets.where((p) => p.key == m.planetKey).firstOrNull;
    final now = ref.watch(customModulesClockProvider)();
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusXL),
      padding: const EdgeInsets.all(Space.l),
      glowColor: c.glow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ModuleOrb.of(m, size: 64, progress: m.isList && summary.entryCount > 0 ? summary.listProgress : null),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.isList
                          ? (summary.entryCount == 0 ? tx.items(0) : tx.itemsProgress(summary.doneCount, summary.entryCount))
                          : tx.lastEntry(summary, now),
                      style: text.titleMedium!.copyWith(color: t.textPrimary),
                    ),
                    const SizedBox(height: Space.xs),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        ModuleBadge(label: tx.kind(m.kind), color: c.ink, icon: ModuleIcons.kind(m.kind)),
                        if (planet != null)
                          ModuleBadge(
                            label: tx.arabic ? planet.nameAr : planet.nameEn,
                            color: ModuleColors.of(planet.color, t).ink,
                            icon: Icons.public_rounded,
                          ),
                        if (m.window != null && m.window != PrayerWindow.anytime)
                          ModuleBadge(label: tx.window(m.window)!, color: t.textSecondary, icon: Icons.mosque_rounded),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (m.isList && summary.entryCount > 0) ...[
            const SizedBox(height: Space.m),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: summary.listProgress),
                duration: context.motion(MadarMotion.long),
                curve: MadarMotion.standard,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: t.glassBorder,
                  valueColor: AlwaysStoppedAnimation(c.base),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The one-tap log, big: tick today, rate today, or +1.
class _QuickCard extends ConsumerWidget {
  const _QuickCard({required this.summary});

  final ModuleSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final m = summary.module;
    final c = ModuleColors.of(m.colorArgb, t);
    final quick = m.quickEntry;
    if (quick is QuickRate) {
      return GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
        child: Row(
          children: [
            Expanded(child: Text(l.cmodQuickRate, style: text.titleSmall)),
            StarRating(
              value: summary.todayRating,
              max: quick.max,
              allowClear: false,
              semanticLabel: l.cmodQuickRate,
              onChanged: (v) {
                if (v != null) unawaited(CustomModulesActions.quickLog(context, ref, m, rating: v));
              },
            ),
          ],
        ),
      );
    }
    final checked = summary.checkedToday;
    final (IconData icon, String label, String sub) = switch (quick) {
      QuickCheck() => (
        checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        checked ? l.cmodQuickChecked : l.cmodQuickDone,
        checked ? l.cmodQuickCheckedHint : l.cmodQuickDoneHint,
      ),
      _ => (Icons.add_circle_rounded, l.cmodQuickAddOne, tx.loggedToday(summary.todayCount)),
    };
    return Semantics(
      button: true,
      toggled: quick is QuickCheck ? checked : null,
      label: label,
      hint: sub,
      excludeSemantics: true,
      child: SpringPress(
        sfx: null,
        onTap: () => unawaited(CustomModulesActions.quickLog(context, ref, m)),
        child: AnimatedContainer(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radiusL),
            gradient: checked
                ? LinearGradient(colors: [c.base, HSLColor.fromColor(c.base).withLightness(0.62).toColor()])
                : null,
            color: checked ? null : c.soft,
            border: Border.all(color: c.base.withValues(alpha: checked ? 0.9 : 0.5), width: 1.2),
            boxShadow: checked ? [BoxShadow(color: c.glow, blurRadius: 18, spreadRadius: -2)] : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 30, color: checked ? c.onBase : c.ink),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.titleMedium!.copyWith(color: checked ? c.onBase : t.textPrimary)),
                    Text(
                        sub,
                        style: text.bodySmall!.copyWith(
                          color: checked ? c.onBase.withValues(alpha: 0.8) : t.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if ((summary.chart?.currentStreak ?? 0) > 0) ...[
                Icon(Icons.local_fire_department_rounded, size: 20, color: checked ? c.onBase : t.gold),
                const SizedBox(width: 2),
                Text(
                  tx.count(summary.chart!.currentStreak),
                  style: text.titleMedium!.copyWith(color: checked ? c.onBase : t.gold, fontWeight: FontWeight.w700),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Space.xs, top: Space.s, bottom: Space.s),
      child: Semantics(
        header: true,
        child: Text(label, style: Theme.of(context).textTheme.labelLarge!.copyWith(color: t.textTertiary)),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Space.xs, bottom: Space.s),
      child: Row(
        children: [
          Icon(icon, size: 18, color: t.textTertiary),
          const SizedBox(width: Space.s),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textSecondary))),
        ],
      ),
    );
  }
}

/// One tracker entry: its time and values.
class _EntryRow extends ConsumerWidget {
  const _EntryRow({super.key, required this.module, required this.entry});

  final ModuleDefinition module;
  final ModuleEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    final c = ModuleColors.of(module.colorArgb, t);
    final values = _values(tx, module, entry);
    return ActionableItem(
      semanticLabel: [tx.clock(entry.at), ...values.map((v) => '${v.$1}: ${v.$2}')].join(tx.arabic ? '، ' : ', '),
      borderRadius: BorderRadius.circular(t.radiusM),
      onTap: () => unawaited(CustomModulesActions.editEntry(context, ref, module, entry)),
      actions: ItemActions(
        onEdit: () => CustomModulesActions.editEntry(context, ref, module, entry),
        onDuplicate: () => CustomModulesActions.duplicateEntry(context, ref, entry),
        onDelete: () => CustomModulesActions.deleteEntry(context, ref, entry),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: MaterialLocalizations.of(context).deleteButtonTooltip,
          tone: ActionTone.danger,
          onPressed: () {
            Fx.fire(Sfx.delete);
            return CustomModulesActions.deleteEntry(context, ref, entry);
          },
        ),
      ],
      swipeEnabled: true,
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusM),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, Space.m, Space.s + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 34,
              margin: const EdgeInsetsDirectional.only(end: Space.m, top: 2),
              decoration: BoxDecoration(
                color: c.base,
                borderRadius: BorderRadius.circular(99),
                boxShadow: [BoxShadow(color: c.glow, blurRadius: 6)],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.clock(entry.at), style: text.labelMedium!.copyWith(color: t.textTertiary)),
                  const SizedBox(height: 2),
                  if (values.isEmpty)
                    Text(tx.l.cmodChecked, style: text.bodyMedium)
                  else
                    Wrap(
                      spacing: Space.m,
                      runSpacing: 2,
                      children: [
                        for (final v in values) _ValueText(entry: entry, value: v),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// (label, value, is the title, field) of every non-empty visible value.
List<(String, String, bool, ModuleField)> _values(CustomTexts tx, ModuleDefinition m, ModuleEntry e) {
  final title = m.titleField;
  return [
    for (final f in m.visibleFields)
      if (tx.value(f, e.values[f.id]) case final String v)
        (tx.name(f.label), f.type == FieldType.text ? tx.name(v) : v, f.id == title?.id, f),
  ];
}

/// One value in a row: "label value", a checkbox as a tick and its label,
/// a rating as stars.
class _ValueText extends StatelessWidget {
  const _ValueText({required this.entry, required this.value, this.dim = false});

  final ModuleEntry entry;
  final (String, String, bool, ModuleField) value;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (label, shown, isTitle, f) = value;
    final labelStyle = text.bodySmall!.copyWith(color: t.textTertiary);
    final valueStyle = (isTitle ? text.titleSmall : text.bodyMedium)!.copyWith(color: dim ? t.textTertiary : t.textPrimary);
    final c = ModuleColors.of(0xFFF2C14E, t);
    switch (f.type) {
      case FieldType.checkbox:
        final on = FieldValues.checkbox(entry.values[f.id]) ?? false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 16, color: on ? t.success : t.textTertiary),
            const SizedBox(width: 4),
            Text(label, style: valueStyle),
          ],
        );
      case FieldType.rating:
        final r = FieldValues.rating(entry.values[f.id]) ?? 0;
        return Semantics(
          label: '$label $shown',
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$label ', style: labelStyle),
              for (var i = 0; i < f.ratingMax; i++)
                Icon(i < r ? Icons.star_rounded : Icons.star_outline_rounded, size: 15, color: i < r ? c.ink : t.textTertiary),
            ],
          ),
        );
      default:
        return Text.rich(
          TextSpan(
            children: [
              if (!isTitle) TextSpan(text: '$label ', style: labelStyle),
              TextSpan(text: shown, style: valueStyle),
            ],
          ),
        );
    }
  }
}

// ------------------------------------------------------------ reminders --

class _RemindersSection extends ConsumerWidget {
  const _RemindersSection({required this.module});

  final ModuleDefinition module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final reminders = ref.watch(customModuleRemindersProvider(module.id)).value ?? const <ReminderRow>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ModuleSectionTitle(
          title: l.cmodReminders,
          count: reminders.isEmpty ? null : tx.count(reminders.length),
          trailing: MadarButton(
            label: l.cmodAddReminder,
            icon: Icons.add_alarm_rounded,
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: Sfx.sheetOpen,
            onPressed: () => unawaited(CustomModulesActions.addReminder(context, ref, module)),
          ),
        ),
        if (reminders.isEmpty) _Hint(icon: Icons.notifications_none_rounded, text: l.cmodRemindersEmpty),
        for (final r in reminders)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Space.s),
            child: ActionableItem(
              key: ValueKey(r.id),
              semanticLabel: describeReminder(context, r.rule) ?? l.cmodReminders,
              borderRadius: BorderRadius.circular(t.radiusM),
              swipeEnabled: false,
              onTap: () => unawaited(CustomModulesActions.editReminder(context, ref, r)),
              actions: ItemActions(
                onEdit: () => CustomModulesActions.editReminder(context, ref, r),
                onDelete: () => CustomModulesActions.deleteReminder(context, ref, r),
              ),
              child: GlassCard(
                borderRadius: BorderRadius.circular(t.radiusM),
                padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs, Space.s, Space.xs),
                child: Row(
                  children: [
                    Icon(
                      r.rule['kind'] == 'prayer' ? Icons.mosque_rounded : Icons.alarm_rounded,
                      size: 20,
                      color: r.enabled ? t.metalGold : t.textTertiary,
                    ),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Text(
                        tx.fmt.localizeDigits(describeReminder(context, r.rule) ?? '—'),
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: r.enabled ? t.textPrimary : t.textTertiary,
                        ),
                      ),
                    ),
                    GlassSwitch(
                      value: r.enabled,
                      semanticLabel: l.cmodReminderToggle,
                      onChanged: (v) => unawaited(CustomModulesActions.setReminderEnabled(ref, r, v)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------------------- list --

class _ListBody extends ConsumerWidget {
  const _ListBody({required this.module, required this.entries});

  final ModuleDefinition module;
  final List<ModuleEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final now = ref.watch(customModulesClockProvider)();
    final summary = ModuleSummary.build(module, entries, now);
    final open = [
      for (final e in entries)
        if (!e.done) e,
    ];
    final done = [
      for (final e in entries)
        if (e.done) e,
    ];
    return ReorderableGlassList<ModuleEntry>(
      items: open,
      itemKey: (e) => e.id,
      padding: _pagePadding,
      spacing: Space.s,
      itemBorderRadius: BorderRadius.circular(t.radiusM),
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Hero(summary: summary),
          _RemindersSection(module: module),
          ModuleSectionTitle(title: l.cmodItemsSection, count: tx.count(open.length)),
          if (entries.isEmpty) _Hint(icon: Icons.playlist_add_rounded, text: l.cmodItemsEmpty),
          if (entries.isNotEmpty && open.isEmpty) _Hint(icon: Icons.celebration_rounded, text: l.cmodAllDone),
        ],
      ),
      itemBuilder: (context, e, index, handle) =>
          _ItemRow(key: ValueKey(e.id), module: module, entry: e, dragHandle: handle),
      onReorder: (order) => unawaited(
        CustomModulesActions.reorderEntries(ref, [...order.map((e) => e.id), ...done.map((e) => e.id)]),
      ),
      footer: done.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ModuleSectionTitle(
                  title: l.cmodDoneSection,
                  count: tx.count(done.length),
                  color: t.success,
                  trailing: MadarButton(
                    label: l.cmodClearDone,
                    icon: Icons.cleaning_services_rounded,
                    variant: MadarButtonVariant.ghost,
                    size: MadarButtonSize.small,
                    sfx: Sfx.delete,
                    onPressed: () => unawaited(CustomModulesActions.clearDone(context, ref, module)),
                  ),
                ),
                for (final e in done)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                    child: _ItemRow(key: ValueKey(e.id), module: module, entry: e),
                  ),
              ],
            ),
    );
  }
}

/// One list item: the check circle, its title and other values.
class _ItemRow extends ConsumerWidget {
  const _ItemRow({super.key, required this.module, required this.entry, this.dragHandle});

  final ModuleDefinition module;
  final ModuleEntry entry;
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final c = ModuleColors.of(module.colorArgb, t);
    final values = _values(tx, module, entry);
    final title = ModuleExport.entryTitle(module, entry, fmt: tx);
    final rest = [
      for (final v in values)
        if (!v.$3 && v.$2 != title) v,
    ];
    final done = entry.done;
    return ActionableItem(
      semanticLabel: [title ?? '—', ...rest.map((v) => '${v.$1}: ${v.$2}'), if (done) l.cmodChecked].join(tx.arabic ? '، ' : ', '),
      borderRadius: BorderRadius.circular(t.radiusM),
      onTap: () => unawaited(CustomModulesActions.editEntry(context, ref, module, entry)),
      completeIcon: done ? Icons.undo_rounded : Icons.check_rounded,
      completeLabel: done ? l.cmodActionUncheck : l.cmodActionCheck,
      onCompleteSwipe: () => CustomModulesActions.setDone(context, ref, module, entry, !done, sound: false),
      actions: ItemActions(
        onEdit: () => CustomModulesActions.editEntry(context, ref, module, entry),
        onDuplicate: () => CustomModulesActions.duplicateEntry(context, ref, entry),
        onDelete: () => CustomModulesActions.deleteEntry(context, ref, entry),
      ),
      quickActions: [
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: MaterialLocalizations.of(context).deleteButtonTooltip,
          tone: ActionTone.danger,
          onPressed: () {
            Fx.fire(Sfx.delete);
            return CustomModulesActions.deleteEntry(context, ref, entry);
          },
        ),
      ],
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusM),
        padding: EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, dragHandle == null ? Space.m : 0, Space.xs),
        child: Row(
          children: [
            Semantics(
              button: true,
              toggled: done,
              label: done ? l.cmodActionUncheck : l.cmodActionCheck,
              excludeSemantics: true,
              child: InkResponse(
                key: ValueKey('cmod-check-${entry.id}'),
                radius: 24,
                onTap: () => unawaited(CustomModulesActions.setDone(context, ref, module, entry, !done, toast: true)),
                child: SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: AnimatedContainer(
                      duration: context.motion(MadarMotion.short),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done ? c.base : Colors.transparent,
                        border: Border.all(color: done ? c.base : c.base.withValues(alpha: 0.7), width: 1.6),
                        boxShadow: done ? [BoxShadow(color: c.glow, blurRadius: 8)] : null,
                      ),
                      child: done ? Icon(Icons.check_rounded, size: 16, color: c.onBase) : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.xs),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title == null ? '—' : tx.name(title),
                      style: text.titleSmall!.copyWith(
                        color: done ? t.textTertiary : t.textPrimary,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: t.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (rest.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: Space.m,
                        runSpacing: 2,
                        children: [
                          for (final v in rest) _ValueText(entry: entry, value: v, dim: done),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ?dragHandle,
          ],
        ),
      ),
    );
  }
}
