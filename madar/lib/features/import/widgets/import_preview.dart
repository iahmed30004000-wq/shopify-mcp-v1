import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/import/import.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../import_controller.dart';
import '../import_presentation.dart';
import 'import_motion.dart';

/// The analysis preview: summary, duplicate warning, per-section counters,
/// generated modules, notes and what is only archived.
class ImportPreview extends StatelessWidget {
  const ImportPreview({super.key, required this.state, required this.formats});

  final ImportState state;
  final ImportFormats formats;

  /// Most unmapped entries listed before collapsing to a count.
  static const maxUnmapped = 40;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final report = state.plan!.report;
    final sections = [
      for (final e in report.sections.entries)
        if (e.value.planned > 0) e,
    ]..sort((a, b) => a.key.index.compareTo(b.key.index));
    final issues = report.issueCounts.where((e) => e.$1 != ImportIssueCode.duplicateFile).toList();
    var index = 0;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xl),
      children: [
        ImportRise(index: index++, child: _SummaryPanel(state: state, formats: formats)),
        if (state.needsDuplicateConfirmation) ...[
          const SizedBox(height: Space.l),
          ImportRise(index: index++, child: _DuplicateBanner(state: state, formats: formats)),
        ],
        if (sections.isEmpty) ...[
          const SizedBox(height: Space.l),
          ImportRise(
            index: index++,
            child: AnimatedEmptyState(kind: EmptyStateKind.noResults, title: l.importNothingFound, body: ''),
          ),
        ] else ...[
          SectionHeader(title: l.importSectionsTitle, padding: _headerPadding),
          _SectionGrid(sections: sections, formats: formats, startIndex: index),
        ],
        if (report.modules.isNotEmpty) ...[
          SectionHeader(title: l.importModulesTitle, subtitle: l.importModulesBody, padding: _headerPadding),
          ImportRise(index: index + 2, child: _ModulesCard(modules: report.modules, formats: formats)),
        ],
        if (issues.isNotEmpty) ...[
          SectionHeader(title: l.importWarningsTitle, padding: _headerPadding),
          ImportRise(
            index: index + 3,
            child: _IssuesCard(report: report, groups: issues, formats: formats),
          ),
        ],
        if (report.unmapped.isNotEmpty) ...[
          SectionHeader(title: l.importUnmappedTitle, subtitle: l.importUnmappedBody, padding: _headerPadding),
          ImportRise(index: index + 4, child: _UnmappedCard(entries: report.unmapped, formats: formats)),
        ],
      ],
    );
  }

  static const _headerPadding = EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m);
}

// -------------------------------------------------------------- summary --

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.state, required this.formats});

  final ImportState state;
  final ImportFormats formats;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final report = state.plan!.report;
    final total = report.totalPlanned;
    return GlassPanel(
      glowColor: t.accentGlow.withValues(alpha: t.accentGlow.a * 0.35),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.l, Space.xl, Space.xl),
      child: Column(
        children: [
          Row(
            children: [
              _Badge(icon: state.fileName == null ? Icons.content_paste_rounded : Icons.description_rounded, color: t.accent),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.importFileLabel, style: text.labelSmall),
                    Text(
                      state.fileName ?? l.importPastedLabel,
                      style: text.titleSmall!.copyWith(color: t.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.l),
          const MadarDivider(),
          const SizedBox(height: Space.s),
          ImportCountUp(
            value: total,
            format: formats.count,
            style: text.displayMedium!.copyWith(color: t.gold, shadows: [Shadow(color: t.accentGlow, blurRadius: 24)]),
          ),
          Text(
            l.importRecordsReady(total),
            style: text.bodyMedium!.copyWith(color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (report.budgetTotalMilli != null) ...[
            const SizedBox(height: Space.m),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pie_chart_rounded, size: 16, color: t.gold),
                const SizedBox(width: Space.s),
                Flexible(
                  child: Text(
                    l.importBudgetTotal(formats.money(report.budgetTotalMilli!, report.budgetCurrency ?? 'JOD')),
                    style: text.labelLarge!.copyWith(color: t.textPrimary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: Space.l),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final label in report.shape.labels(l))
                MadarChip(label: label, dense: true, icon: Icons.blur_on_rounded, sfx: null),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0.08)]),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 14)],
      ),
      child: Icon(icon, size: size * 0.5, color: Color.lerp(color, context.tokens.starTint, 0.25)),
    );
  }
}

// ------------------------------------------------------------ duplicate --

class _DuplicateBanner extends ConsumerWidget {
  const _DuplicateBanner({required this.state, required this.formats});

  final ImportState state;
  final ImportFormats formats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final previous = state.duplicate!;
    return GlassCard(
      borderColor: t.warning.withValues(alpha: 0.6),
      glowColor: t.warning.withValues(alpha: 0.25),
      tint: Color.alphaBlend(t.warning.withValues(alpha: 0.08), t.glassFill),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Badge(icon: Icons.history_rounded, color: t.warning, size: 36),
              const SizedBox(width: Space.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.importDuplicateTitle, style: text.titleMedium!.copyWith(color: t.warning)),
                    const SizedBox(height: Space.xxs),
                    Text(
                      l.importDuplicateBody(formats.date(previous.importedAt)),
                      style: text.bodySmall!.copyWith(color: t.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              Expanded(child: Text(l.importDuplicateAnyway, style: text.labelLarge)),
              MadarSwitch(
                value: state.allowDuplicate,
                activeColor: t.warning,
                semanticLabel: l.importDuplicateAnyway,
                onChanged: ref.read(importControllerProvider.notifier).setAllowDuplicate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- sections --

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.sections, required this.formats, required this.startIndex});

  final List<MapEntry<ImportSection, ImportSectionReport>> sections;
  final ImportFormats formats;
  final int startIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 620 ? 3 : 2;
        const gap = Space.m;
        final width = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < sections.length; i++)
              SizedBox(
                width: width,
                child: ImportRise(
                  index: startIndex + i,
                  child: _SectionTile(
                    section: sections[i].key,
                    count: sections[i].value.planned,
                    skipped: sections[i].value.skipped,
                    formats: formats,
                    index: startIndex + i,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.section,
    required this.count,
    required this.skipped,
    required this.formats,
    required this.index,
  });

  final ImportSection section;
  final int count;
  final int skipped;
  final ImportFormats formats;
  final int index;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = section.color(t);
    return GlassCard(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      semanticLabel: '${section.label(l)}: ${formats.count(count)}',
      child: Row(
        children: [
          _Badge(icon: section.icon, color: color, size: 36),
          const SizedBox(width: Space.s + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImportCountUp(
                  value: count,
                  index: index,
                  format: formats.count,
                  style: text.titleLarge!.copyWith(color: t.textPrimary, height: 1.1),
                ),
                Text(
                  section.label(l),
                  style: text.labelMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (skipped > 0)
                  Text(
                    '− ${formats.count(skipped)}',
                    style: text.labelSmall!.copyWith(color: t.warning),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- modules --

class _ModulesCard extends StatelessWidget {
  const _ModulesCard({required this.modules, required this.formats});

  final List<ImportedModuleSummary> modules;
  final ImportFormats formats;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < modules.length; i++) ...[
            if (i > 0) const MadarDivider(ornament: false, height: Space.xl),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(icon: Icons.widgets_rounded, color: t.highlight, size: 36),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(modules[i].name, style: text.titleMedium),
                      Text(
                        formats.digitsOf(l.importModuleEntries(modules[i].entries)),
                        style: text.bodySmall!.copyWith(color: t.textSecondary),
                      ),
                      const SizedBox(height: Space.s),
                      Wrap(
                        spacing: Space.xs,
                        runSpacing: Space.xs,
                        children: [
                          for (final f in modules[i].fieldTypes.keys)
                            MadarChip(label: f, dense: true, sfx: null, color: t.highlight),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- issues --

class _IssuesCard extends StatelessWidget {
  const _IssuesCard({required this.report, required this.groups, required this.formats});

  final ImportReport report;
  final List<(ImportIssueCode, int)> groups;
  final ImportFormats formats;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.xs),
      child: Column(
        children: [
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const MadarDivider(ornament: false, height: Space.xs),
            _IssueGroup(
              code: groups[i].$1,
              count: groups[i].$2,
              issues: report.issues.where((x) => x.code == groups[i].$1).toList(),
              formats: formats,
            ),
          ],
        ],
      ),
    );
  }
}

class _IssueGroup extends StatefulWidget {
  const _IssueGroup({required this.code, required this.count, required this.issues, required this.formats});

  final ImportIssueCode code;
  final int count;
  final List<ImportIssue> issues;
  final ImportFormats formats;

  static const maxDetails = 6;

  @override
  State<_IssueGroup> createState() => _IssueGroupState();
}

class _IssueGroupState extends State<_IssueGroup> {
  bool _open = false;

  String _detail(L10n l, ImportIssue i) {
    if (i.code == ImportIssueCode.budget) return widget.formats.budgetIssue(l, i);
    final parts = [?i.section?.label(l), ?i.detail, ?i.path];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = widget.code.isWarning ? t.warning : t.info;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MadarPressable(
          sfx: _open ? Sfx.sheetClose : Sfx.sheetOpen,
          semanticLabel: widget.code.label(l),
          toggled: _open,
          focusRadius: BorderRadius.circular(t.radiusS),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.m),
            child: Row(
              children: [
                Icon(widget.code.icon, size: 20, color: color),
                const SizedBox(width: Space.m),
                Expanded(child: Text(widget.code.label(l), style: text.bodyMedium)),
                const SizedBox(width: Space.s),
                _CountPill(text: widget.formats.count(widget.count), color: color),
                const SizedBox(width: Space.xs),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: context.motion(MadarMotion.short),
                  child: Icon(Icons.expand_more_rounded, size: 20, color: t.textTertiary),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.emphasized,
          alignment: AlignmentDirectional.topStart,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.xxl + Space.s, 0, Space.s, Space.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final i in widget.issues.take(_IssueGroup.maxDetails))
                        Padding(
                          padding: const EdgeInsetsDirectional.only(bottom: Space.xs),
                          child: Text(_detail(l, i), style: text.bodySmall),
                        ),
                      if (widget.issues.length > _IssueGroup.maxDetails)
                        Text('…', style: text.bodySmall!.copyWith(color: t.textTertiary)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: Space.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.7),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: color)),
    );
  }
}

// ------------------------------------------------------------- unmapped --

class _UnmappedCard extends StatelessWidget {
  const _UnmappedCard({required this.entries, required this.formats});

  final List<UnmappedEntry> entries;
  final ImportFormats formats;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final shown = entries.take(ImportPreview.maxUnmapped).toList();
    return GlassCard(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in shown)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(top: 5),
                    child: Icon(Icons.inventory_2_outlined, size: 14, color: t.textTertiary),
                  ),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.path, style: text.labelMedium!.copyWith(color: t.textPrimary)),
                        if (e.preview != null)
                          Text(
                            e.preview!,
                            style: text.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (e.count > 1) Text(l.importTimesCount(formats.count(e.count)), style: text.labelSmall),
                ],
              ),
            ),
          if (entries.length > shown.length)
            Text('+ ${formats.count(entries.length - shown.length)}', style: text.labelSmall),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------- action bar --

/// Sticky bottom bar of the preview: Import (primary) and Another file.
class ImportActionBar extends ConsumerWidget {
  const ImportActionBar({super.key, required this.state, required this.formats});

  final ImportState state;
  final ImportFormats formats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final controller = ref.read(importControllerProvider.notifier);
    final total = state.plan?.report.totalPlanned ?? 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.space0.withValues(alpha: 0), t.space0.withValues(alpha: t.isDark ? 0.92 : 0.85)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.m),
          child: Row(
            children: [
              MadarButton(
                label: l.importChooseAnother,
                variant: MadarButtonVariant.ghost,
                sfx: Sfx.back,
                onPressed: controller.reset,
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: MadarButton(
                  label: formats.digitsOf(l.importStartAction(total)),
                  icon: Icons.download_done_rounded,
                  size: MadarButtonSize.large,
                  expand: true,
                  sfx: Sfx.navigate,
                  onPressed: state.canImport ? controller.commit : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
