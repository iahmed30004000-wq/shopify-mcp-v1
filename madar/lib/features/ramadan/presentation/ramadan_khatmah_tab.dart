import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/islamic_geometry/islamic_geometry.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/routing/route_pages.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../application/ramadan_providers.dart';
import '../data/ramadan_texts.dart';
import '../domain/khatmah_plan.dart';
import 'ramadan_hub_card.dart' show ramadanUndoToast;

/// «ختمة رمضان»: a reading plan that finishes the Quran inside the month.
///
/// Today's portion (fixed from what was left when the day began), one tap to
/// mark it read, a way into the reader at that page, and - when days were
/// missed - the re-plan said in plain words: how far behind, how much a day
/// the rest now asks for, and, if it cannot fit, how short it falls and how
/// many extra days would absorb it. **Never above the ceiling he sets.**
class RamadanKhatmahTab extends ConsumerWidget {
  const RamadanKhatmahTab({super.key});

  static const List<int> ceilingChoices = [10, 15, 20, 25, 30, 40, 50, 60, 80, 100];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final texts = ref.watch(ramadanTextsProvider);
    final record = ref.watch(ramadanKhatmahProvider);
    final k = ref.watch(ramadanKhatmahTodayProvider);
    final plan = record.plan;
    final service = ref.read(ramadanServiceProvider);
    final read = record.progress.frontier.clamp(0, plan.totalPages);
    final canMark = k.status == KhatmahStatus.active || k.status == KhatmahStatus.overdue;
    final done = k.todayDone;
    final choices = ({...ceilingChoices, plan.ceilingPages}.toList()..sort());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l.ramadanKhatmahSection,
          seed: 0.3,
          children: [
            Padding(
              key: const ValueKey('ramadan.khatmah.summary'),
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
              child: Row(
                children: [
                  StarProgressRing(
                    value: plan.totalPages == 0 ? 0 : read / plan.totalPages,
                    progressColor: t.accent,
                    trackColor: t.glassBorder.withValues(alpha: 0.5),
                    size: 72,
                    strokeWidth: 4,
                    semanticLabel: l.ramadanKhatmahProgressSemantics(texts.pages(read), texts.pages(plan.totalPages)),
                    child: Icon(k.status == KhatmahStatus.finished ? Icons.check_rounded : Icons.auto_stories_rounded, color: t.accent),
                  ),
                  const SizedBox(width: Space.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.ramadanKhatmahDayOf(texts.number(k.dayIndex + 1), texts.number(plan.days)),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          l.ramadanKhatmahRead(texts.pages(read), texts.pages(plan.totalPages)),
                          style: Theme.of(context).textTheme.bodySmall!.copyWith(color: t.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (k.status != KhatmahStatus.finished && !k.portion.isEmpty)
              SettingsTile(
                key: const ValueKey('ramadan.khatmah.portion'),
                icon: done ? Icons.check_circle_rounded : Icons.bookmark_added_outlined,
                iconColor: done ? t.success : null,
                title: done ? l.ramadanKhatmahDoneToday : l.ramadanKhatmahPortion,
                subtitle: l.ramadanKhatmahPages(texts.number(k.portion.fromPage), texts.number(k.portion.toPage)),
              ),
            if (k.status != KhatmahStatus.finished)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MadarButton(
                      key: const ValueKey('ramadan.khatmah.mark'),
                      label: done ? l.ramadanKhatmahUnmark : l.ramadanKhatmahMarkRead,
                      icon: done ? Icons.undo_rounded : Icons.check_rounded,
                      variant: done ? MadarButtonVariant.ghost : MadarButtonVariant.primary,
                      expand: true,
                      onPressed: canMark ? () => unawaited(_mark(context, service, !done)) : null,
                    ),
                    if (!k.portion.isEmpty) ...[
                      const SizedBox(height: Space.s),
                      MadarButton(
                        key: const ValueKey('ramadan.khatmah.openQuran'),
                        label: l.ramadanKhatmahOpenQuran,
                        icon: Icons.menu_book_rounded,
                        variant: MadarButtonVariant.secondary,
                        expand: true,
                        onPressed: () => FaithNav.quranReader(context, page: k.portion.fromPage),
                      ),
                    ],
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xs, Space.l, Space.xs),
              child: _Replan(texts: texts, k: k, ceiling: plan.ceilingPages),
            ),
          ],
        ),
        SettingsSection(
          title: null,
          seed: 0.4,
          children: [
            SettingsChoiceTile<int>(
              key: const ValueKey('ramadan.khatmah.ceiling'),
              icon: Icons.speed_rounded,
              title: l.ramadanKhatmahCeiling,
              subtitle: texts.pages(plan.ceilingPages),
              options: [for (final n in choices) ChoiceOption(value: n, label: texts.pages(n))],
              selected: plan.ceilingPages,
              onChanged: (n) async {
                final undo = await service.setKhatmahCeiling(n);
                if (context.mounted) ramadanUndoToast(context, l.ramadanKhatmahCeilingToast, undo);
              },
            ),
            SettingsNote(l.ramadanKhatmahCeilingHint),
          ],
        ),
      ],
    );
  }

  Future<void> _mark(BuildContext context, RamadanService service, bool read) async {
    final l = L10n.of(context);
    final undo = await service.setKhatmahTodayRead(read);
    if (context.mounted) ramadanUndoToast(context, read ? l.ramadanKhatmahMarkedToast : l.ramadanKhatmahUnmarkedToast, undo);
  }
}

/// The re-plan, in plain words.
class _Replan extends StatelessWidget {
  const _Replan({required this.texts, required this.k, required this.ceiling});

  final RamadanTexts texts;
  final KhatmahToday k;
  final int ceiling;

  @override
  Widget build(BuildContext context) {
    final l = texts.l10n;
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.textSecondary, height: 1.5);
    final warn = style.copyWith(color: t.warning, fontWeight: FontWeight.w600);
    final lines = <(String, TextStyle)>[];
    switch (k.status) {
      case KhatmahStatus.finished:
        lines.add((l.ramadanKhatmahFinished, style.copyWith(color: t.success, fontWeight: FontWeight.w600)));
      case KhatmahStatus.notStarted:
        lines.add((l.ramadanKhatmahNotStarted, style));
      case KhatmahStatus.overdue:
        lines.add((l.ramadanKhatmahOverdue(texts.pages(k.remainingPages), texts.days(k.suggestedExtensionDays)), warn));
      case KhatmahStatus.active:
        if (k.pagesBehind > 0) {
          final perDay = k.upcoming.isEmpty ? k.portion.pages : k.upcoming.first;
          lines.add((l.ramadanKhatmahBehind(texts.pages(k.pagesBehind), texts.pages(perDay), texts.pages(ceiling)), style));
        }
        if (k.shortfallPages > 0) {
          lines.add((l.ramadanKhatmahShortfall(texts.pages(k.shortfallPages), texts.days(k.suggestedExtensionDays)), warn));
        }
        if (lines.isEmpty) lines.add((l.ramadanKhatmahOnTrack, style));
    }
    return Column(
      key: const ValueKey('ramadan.khatmah.replan'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (text, s) in lines)
          Padding(padding: const EdgeInsetsDirectional.only(bottom: Space.xs), child: Text(text, style: s)),
      ],
    );
  }
}
