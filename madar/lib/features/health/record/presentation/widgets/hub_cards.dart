import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/record_providers.dart';
import '../../domain/appointment_plan.dart';
import '../record_actions.dart';
import '../record_navigation.dart';
import '../record_screen.dart' show RecordTab;
import '../record_ui.dart';
import 'lab_bits.dart';
import 'record_tiles.dart';

/// Compact card for the Health hub: the next appointment with its
/// countdown and waiting questions (or a quiet "add" when there is none).
class NextAppointmentCard extends ConsumerWidget {
  const NextAppointmentCard({super.key, this.onOpen, this.hideWhenEmpty = false});

  /// Defaults to the Appointments screen with this appointment lit.
  final VoidCallback? onOpen;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final next = ref.watch(nextAppointmentProvider);
    final now = ref.watch(recordClockProvider)();
    final nav = ref.watch(recordNavigationProvider);
    final a = next.value;
    if (!next.hasValue) return const SizedBox.shrink();
    if (a == null) {
      if (hideWhenEmpty) return const SizedBox.shrink();
      return GlassCard(
        onTap: RecordActions(context, ref).addAppointment,
        semanticLabel: l.recordAppointmentAdd,
        padding: const EdgeInsets.all(Space.l),
        child: Row(
          children: [
            Icon(RecordIcons.appointments, color: t.textTertiary),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(l.recordAppointmentsEmpty, style: text.bodyMedium!.copyWith(color: t.textSecondary)),
            ),
            Icon(Icons.add_rounded, color: t.accent),
          ],
        ),
      );
    }
    final questions = (ref.watch(doctorQuestionsProvider).value ?? const <DoctorQuestionRow>[])
        .where((q) => q.appointmentId == a.id && !q.answered)
        .length;
    final days = AppointmentTimeline.daysUntil(a.at, now);
    return GlassCard(
      onTap: onOpen ?? () => nav.openAppointments(context, highlightId: a.id),
      semanticLabel: '${l.recordNextAppointment}: ${a.title}, ${texts.relativeDay(days)} ${fmt.formatTime(a.at)}',
      padding: const EdgeInsets.all(Space.l),
      child: Row(
        children: [
          DateMedallion(date: a.at, highlight: days <= 1),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.recordNextAppointment, style: text.labelMedium!.copyWith(color: t.accent)),
                const SizedBox(height: 2),
                Text(a.title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [
                    l.recordDateAtTime(texts.relativeDay(days), fmt.formatTime(a.at)),
                    if (a.doctor?.trim().isNotEmpty ?? false) BidiIsolate.isolate(a.doctor!.trim()),
                  ].join(l.recordListSeparator),
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (questions > 0) ...[
                  const SizedBox(height: Space.xs),
                  Row(
                    children: [
                      Icon(RecordIcons.questions, size: 14, color: t.info),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l.recordAppointmentQuestions(questions, fmt.formatInt(questions)),
                          style: text.labelSmall!.copyWith(color: t.info),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Mirrors itself in right-to-left layouts.
          Icon(Icons.chevron_right_rounded, color: t.textTertiary),
        ],
      ),
    );
  }
}

/// Compact card for the Health hub: latest lab results outside or near
/// the user's own ranges (neutral flags only).
class LabFlagsCard extends ConsumerWidget {
  const LabFlagsCard({super.key, this.onOpen, this.maxRows = 3, this.hideWhenEmpty = true});

  /// Defaults to the record's Labs tab.
  final VoidCallback? onOpen;
  final int maxRows;

  /// No lab tests at all → no card.
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = MadarFormatter.of(context);
    final texts = context.recordTexts;
    final nav = ref.watch(recordNavigationProvider);
    final all = ref.watch(labTestViewsProvider).value;
    final flagged = ref.watch(flaggedLabTestsProvider).value ?? const [];
    if (all == null) return const SizedBox.shrink();
    final withReadings = all.where((v) => v.latest != null).toList();
    if (withReadings.isEmpty && hideWhenEmpty) return const SizedBox.shrink();
    final open = onOpen ?? () => nav.openRecord(context, tab: RecordTab.labs);
    return GlassCard(
      onTap: open,
      semanticLabel: l.recordLabFlagsTitle,
      padding: const EdgeInsets.all(Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(RecordIcons.labs, size: 20, color: t.accent),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(
                  l.recordLabFlagsTitle,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (flagged.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 28, top: 2),
              child: Text(
                l.recordLabFlaggedCount(flagged.length, fmt.formatInt(flagged.length)),
                style: text.bodySmall!.copyWith(color: t.textSecondary),
              ),
            ),
          const SizedBox(height: Space.s),
          if (flagged.isEmpty)
            Text(
              withReadings.isEmpty ? l.recordLabsEmpty : l.recordLabAllInRange,
              style: text.bodyMedium!.copyWith(color: t.textSecondary),
            )
          else
            for (final v in flagged.take(maxRows))
              MadarPressable(
                onTap: () => nav.openLabTest(context, v.test.id),
                sfx: Sfx.navigate,
                semanticLabel:
                    '${v.test.name}: ${texts.reading(v.latest!, unit: v.test.unit, decimals: v.decimals)}, ${texts.flag(v.latestFlag!)}',
                excludeChildSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(v.test.name, style: text.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(
                        texts.reading(v.latest!, decimals: v.decimals),
                        style: text.titleSmall!.copyWith(
                          color: RecordColors.flag(t, v.latestFlag!),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      LabFlagChip(flag: v.latestFlag!, dense: true),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
