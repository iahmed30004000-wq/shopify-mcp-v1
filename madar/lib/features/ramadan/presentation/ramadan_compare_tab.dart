import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../application/ramadan_providers.dart';
import '../data/ramadan_texts.dart';
import '../domain/ramadan_year_log.dart';

/// «مقارنة مع السنة الماضية»: this year's log beside the year before it -
/// the totals with what changed in plain words, and the nights side by side.
/// With only one year kept, the empty state says when the second appears.
class RamadanCompareTab extends ConsumerWidget {
  const RamadanCompareTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final texts = ref.watch(ramadanTextsProvider);
    final today = ref.watch(ramadanTodayProvider);
    final year = ref.watch(ramadanLogYearProvider);
    final book = ref.watch(ramadanLogBookProvider).value ?? RamadanLogBook();
    final last = year == null ? null : book.previousOf(year);

    if (year == null || last == null) {
      return SettingsSection(
        title: l.ramadanCompareSection,
        seed: 0.5,
        children: [
          AnimatedEmptyState(
            key: const ValueKey('ramadan.compare.empty'),
            kind: EmptyStateKind.noData,
            title: l.ramadanCompareEmptyTitle,
            body: l.ramadanCompareEmptyBody,
            illustrationSize: 88,
          ),
        ],
      );
    }

    final length = year == today.hijriYear ? today.monthLength : ref.watch(ramadanCalendarProvider).spanOfYear(year).length;
    final cmp = RamadanComparison.compare(book.ofOrEmpty(year), last, nightCount: length);
    final text = Theme.of(context).textTheme;

    String delta(int d, String Function(int) unit) =>
        d > 0 ? l.ramadanCompareMore(unit(d)) : (d < 0 ? l.ramadanCompareLess(unit(-d)) : l.ramadanCompareSame);

    Widget row(String key, IconData icon, String label, int now, int before, String Function(int) unit, int d) {
      final yearBefore = texts.number(last.hijriYear);
      return SettingsTile(
        key: ValueKey('ramadan.compare.$key'),
        icon: icon,
        title: label,
        subtitle: delta(d, unit),
        semanticLabel: l.ramadanCompareRow(label, unit(now), unit(before)),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(texts.number(now), style: text.titleMedium!.copyWith(color: t.accent, fontWeight: FontWeight.w700)),
            Text('${texts.number(before)} · $yearBefore', style: text.bodySmall!.copyWith(color: t.textTertiary)),
          ],
        ),
      );
    }

    final fastNow = cmp.thisYear.fastingDays, fastBefore = cmp.lastYear.fastingDays, fastDelta = cmp.fastingDaysDelta;
    final counts = {for (final d in NightDifference.values) d: cmp.nights.where((n) => n.difference == d).length};

    return SettingsSection(
      title: l.ramadanCompareSection,
      seed: 0.5,
      children: [
        Padding(
          key: const ValueKey('ramadan.compare.years'),
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.s),
          child: Row(
            children: [
              Expanded(child: Text(l.ramadanCompareYear(texts.number(year)), style: text.titleSmall!.copyWith(color: t.accent))),
              Text(l.ramadanCompareYear(texts.number(last.hijriYear)), style: text.titleSmall!.copyWith(color: t.textTertiary)),
            ],
          ),
        ),
        row('nights', Icons.mosque_rounded, l.ramadanCompareNights, cmp.thisYear.nightsPrayed, cmp.lastYear.nightsPrayed, texts.nights, cmp.nightsPrayedDelta),
        row('rakaat', Icons.format_list_numbered_rounded, l.ramadanCompareRakaat, cmp.thisYear.rakaat, cmp.lastYear.rakaat, texts.rakaat, cmp.rakaatDelta),
        row('pages', Icons.auto_stories_rounded, l.ramadanComparePages, cmp.thisYear.pagesRead, cmp.lastYear.pagesRead, texts.pages, cmp.pagesReadDelta),
        if (fastNow != null && fastBefore != null && fastDelta != null)
          row('fasting', Icons.restaurant_rounded, l.ramadanCompareFasting, fastNow, fastBefore, texts.days, fastDelta),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
          child: _NightStrip(cmp: cmp, texts: texts, counts: counts),
        ),
      ],
    );
  }
}

/// The nights of the month, each coloured by which year prayed it.
class _NightStrip extends StatelessWidget {
  const _NightStrip({required this.cmp, required this.texts, required this.counts});

  final RamadanComparison cmp;
  final RamadanTexts texts;
  final Map<NightDifference, int> counts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = texts.l10n;
    final text = Theme.of(context).textTheme;
    Color colorOf(NightDifference d) => switch (d) {
      NightDifference.both => t.success,
      NightDifference.onlyThisYear => t.accent,
      NightDifference.onlyLastYear => t.warning,
      NightDifference.neither => t.glassBorder,
    };
    String labelOf(NightDifference d) => switch (d) {
      NightDifference.both => l.ramadanCompareBoth,
      NightDifference.onlyThisYear => l.ramadanCompareOnlyThis,
      NightDifference.onlyLastYear => l.ramadanCompareOnlyLast,
      NightDifference.neither => l.ramadanCompareNeither,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Wrap(
            key: const ValueKey('ramadan.compare.strip'),
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final n in cmp.nights)
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: colorOf(n.difference),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.s),
        Wrap(
          spacing: Space.m,
          runSpacing: Space.xs,
          children: [
            for (final d in NightDifference.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: colorOf(d), shape: BoxShape.circle)),
                  const SizedBox(width: Space.xs),
                  Flexible(
                    child: Text('${labelOf(d)} ${texts.number(counts[d] ?? 0)}', style: text.bodySmall!.copyWith(color: t.textSecondary)),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
