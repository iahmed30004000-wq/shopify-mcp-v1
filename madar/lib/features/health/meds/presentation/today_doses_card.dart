import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/meds_providers.dart';
import '../domain/dose_tracker.dart';
import '../meds_texts.dart';
import 'meds_actions.dart';
import 'meds_screen.dart';
import 'widgets/meds_widgets.dart';

/// Compact card for the Health hub (and later the home widget): today's
/// progress, the doses waiting now (else the next ones) with a one-tap
/// Taken, and a way into the medications screen.
class TodayDosesCard extends ConsumerWidget {
  const TodayDosesCard({super.key, this.onOpen, this.maxRows = 3});

  /// Opens the medications screen (default: pushes [MedsScreen]).
  final void Function(BuildContext context)? onOpen;
  final int maxRows;

  void _open(BuildContext context) {
    Fx.fire(Sfx.navigate);
    if (onOpen != null) {
      onOpen!(context);
    } else {
      unawaited(Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MedsScreen())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final tx = MedsTexts(l, fmt);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(medsTodayProvider);

    final header = Row(
      children: [
        Icon(Icons.medication_rounded, size: 18, color: t.accent),
        const SizedBox(width: Space.s),
        Expanded(child: Text(l.medsTodayHeader, style: text.titleMedium)),
        if (today != null && today.total > 0)
          Text(
            l.medsTodayCount(fmt.formatInt(today.taken), fmt.formatInt(today.total)),
            style: text.labelLarge!.copyWith(color: t.textSecondary),
          ),
        const SizedBox(width: Space.xs),
        MadarPressable(
          onTap: () => _open(context),
          sfx: null,
          semanticLabel: l.medsTitle,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(Space.xs),
            child: Icon(Icons.chevron_right_rounded, size: 20, color: t.accent),
          ),
        ),
      ],
    );

    Widget body;
    if (today == null) {
      body = const SizedBox(height: 56, child: Center(child: OrbitLoader(size: 26)));
    } else if (!today.hasMeds) {
      body = Row(
        children: [
          Expanded(child: Text(l.medsEmptyTitle, style: text.bodySmall)),
          MadarButton(
            label: l.medsAddMed,
            icon: Icons.add_rounded,
            size: MadarButtonSize.small,
            sfx: Sfx.sheetOpen,
            onPressed: () => MedsActions.addMed(context, ref),
          ),
        ],
      );
    } else {
      final due = today.dueNow;
      final upcoming = [
        for (final d in today.doses)
          if (d.state == DoseState.upcoming || d.state == DoseState.snoozed) d,
      ];
      final rows = [...due, ...upcoming].take(maxRows).toList();
      final complete = today.total > 0 && today.answered == today.total;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: today.total == 0 ? 0 : today.taken / today.total,
              minHeight: 4,
              backgroundColor: t.glassFill,
              color: complete ? t.success : t.accent,
            ),
          ),
          const SizedBox(height: Space.s),
          if (rows.isEmpty)
            Text(
              complete ? l.medsAllAnswered : l.medsNoDosesToday,
              style: text.bodySmall!.copyWith(color: complete ? t.success : t.textSecondary),
            ),
          for (final d in rows) _Row(dose: d, tx: tx),
        ],
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
      onTap: () => _open(context),
      semanticLabel: l.medsTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, const SizedBox(height: Space.s), body],
      ),
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.dose, required this.tx});

  final TrackedDose dose;
  final MedsTexts tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final d = dose.dose;
    final color = doseStateColor(dose.state, t);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.xs),
      child: Row(
        children: [
          MedOrb(med: d.med, size: 28, state: dose.state),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: tx.name(d.med.name), style: text.bodyMedium!.copyWith(color: t.textPrimary)),
                  if (d.dose != null)
                    TextSpan(text: ' · ${tx.dose(d.dose!)}', style: text.bodySmall!.copyWith(color: t.textSecondary)),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(tx.time(dose.dueAt), style: text.labelLarge!.copyWith(color: color)),
          const SizedBox(width: Space.xs),
          MadarButton.icon(
            icon: Icons.check_rounded,
            semanticLabel: '${tx.l.medsTake}: ${d.med.name}',
            size: MadarButtonSize.small,
            variant: dose.state.needsAction ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
            onPressed: () async {
              final action = await MedsActions.take(context, ref, dose, toast: false);
              if (action != null && context.mounted) unawaited(showUndoToast(context, action));
            },
          ),
        ],
      ),
    );
  }
}
