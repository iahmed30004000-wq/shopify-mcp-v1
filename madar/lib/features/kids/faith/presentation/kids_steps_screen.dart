// «الصلاة والوضوء» (design 05): the steps in order, one at a time, with a step
// badge. Every word on a step comes from an approved [KidsReligiousItem]; with
// none approved the screen is the calm «قريبًا».
import 'package:flutter/material.dart';

import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../application/faith_providers.dart';
import '../domain/kids_religious_item.dart';
import 'widgets/approved_gate.dart';
import 'widgets/kids_faith_ui.dart';
import 'widgets/kids_scene_art.dart';

class PrayerWuduScreen extends StatefulWidget {
  const PrayerWuduScreen({super.key});

  @override
  State<PrayerWuduScreen> createState() => _PrayerWuduScreenState();
}

class _PrayerWuduScreenState extends State<PrayerWuduScreen> {
  int? _tab;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return KidsFaithScaffold(
      title: l.kidsFaithPrayerWuduTitle,
      background: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [KP.teal100, KP.paper],
        ),
      ),
      child: KidsApprovedItems(
        kinds: const {KidsReligiousKind.wuduStep, KidsReligiousKind.prayerStep},
        builder: (context, items) {
          final wudu = kidsItemsOfKind(items, KidsReligiousKind.wuduStep);
          final prayer = kidsItemsOfKind(items, KidsReligiousKind.prayerStep);
          final tab = _tab ?? (wudu.isNotEmpty ? 0 : 1);
          final steps = tab == 0 ? wudu : prayer;
          return Column(
            children: [
              KidsTabs(
                labels: [l.kidsFaithTabWudu, l.kidsFaithTabPrayer],
                selected: tab,
                onSelected: (i) => setState(() => _tab = i),
                activeColor: KP.teal500,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: steps.isEmpty
                    ? const KidsSoonState()
                    : KidsPager(
                        key: ValueKey(tab),
                        count: steps.length,
                        pageBuilder: (context, i) => _StepPage(step: steps[i], number: i + 1, total: steps.length),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.number, required this.total});

  final KidsReligiousItem step;
  final int number;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    return Column(
      children: [
        Stack(
          children: [
            KidsSceneArt(art: step.art, height: 240, dayTone: true),
            PositionedDirectional(
              top: 12,
              end: 12,
              child: Semantics(
                label: l.kidsFaithStepBadge(fmt.formatInt(number)),
                child: ExcludeSemantics(
                  child: KhatamBadge(
                    size: 64,
                    color: KP.sun500,
                    child: Text(
                      fmt.formatInt(number),
                      style: const TextStyle(fontFamily: KP.heading, fontSize: 28, color: KP.night900),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          l.kidsFaithPageOfTotal(fmt.formatInt(number), fmt.formatInt(total)),
          style: const TextStyle(fontFamily: KP.body, fontSize: 16, color: KP.ink2),
        ),
        if (step.title != null && step.title!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            step.title!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: KP.heading, fontSize: 30, color: KP.night900),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          step.arabicText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: KP.body,
            fontWeight: FontWeight.w500,
            fontSize: 22,
            height: 1.7,
            color: KP.ink,
          ),
        ),
      ],
    );
  }
}
