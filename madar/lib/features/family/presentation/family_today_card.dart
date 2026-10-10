import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../data/family_providers.dart';
import '../domain/family_models.dart';
import '../family_texts.dart';
import 'family_actions.dart';
import 'family_navigation.dart';
import 'widgets/family_widgets.dart';

/// Compact card for the Family planet page: who is due or overdue today
/// (most urgent first, each with the one-tap "contacted" heart) and the
/// birthdays of the next two weeks. Tap opens the Family screen ([onOpen],
/// else pushed with [FamilyNavigation]); a person opens their page
/// ([onOpenPerson] likewise).
class FamilyTodayCard extends ConsumerWidget {
  const FamilyTodayCard({super.key, this.onOpen, this.onOpenPerson, this.maxPeople = 3, this.birthdayDays = 14});

  final void Function(BuildContext context)? onOpen;
  final FamilyOpenPerson? onOpenPerson;

  /// People listed by name; the rest are counted.
  final int maxPeople;

  /// Birthdays shown within this many days.
  final int birthdayDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final overview = ref.watch(familyOverviewProvider).value;

    void open() {
      if (onOpen != null) {
        Fx.fire(Sfx.navigate);
        onOpen!(context);
      } else {
        unawaited(FamilyNavigation.openFamily(context));
      }
    }

    void openPerson(String id) {
      if (onOpenPerson != null) {
        Fx.fire(Sfx.navigate);
        onOpenPerson!(context, id);
      } else {
        unawaited(FamilyNavigation.openPerson(context, id));
      }
    }

    final empty = overview != null && overview.isEmpty;
    final due = overview?.due ?? const <PersonView>[];
    final birthdays = overview?.upcomingBirthdays(withinDays: birthdayDays) ?? const <PersonView>[];
    final allGood = overview != null && !empty && due.isEmpty;

    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom_rounded, size: 18, color: t.accent),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.familyTodayTitle, style: text.titleMedium)),
              if (!empty)
                MadarPressable(
                  onTap: open,
                  sfx: null,
                  semanticLabel: l.familyOpenAll,
                  excludeChildSemantics: true,
                  // A 48 dp target (Android) around the small link.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.familyOpenAll, style: text.labelLarge!.copyWith(color: t.accent)),
                        Icon(Icons.chevron_right_rounded, size: 18, color: t.accent),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.s),
          if (overview == null)
            const SizedBox(height: 56, child: Center(child: OrbitLoader(size: 28)))
          else if (empty)
            Row(
              children: [
                Expanded(child: Text(l.familyCardEmpty, style: text.bodySmall)),
                const SizedBox(width: Space.m),
                MadarButton(
                  label: l.familyAddPerson,
                  icon: Icons.person_add_alt_1_rounded,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => FamilyActions.addPerson(context, ref),
                ),
              ],
            )
          else ...[
            if (allGood)
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xs),
                child: Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 20, color: t.success),
                    const SizedBox(width: Space.s),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: l.familyHeroAllGood,
                              style: text.titleSmall!.copyWith(color: t.success),
                            ),
                            TextSpan(
                              text: '${l.familyDot}${l.familyHeroBlessing}',
                              style: text.bodySmall!.copyWith(color: t.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            for (final p in due.take(maxPeople))
              AnimatedSwitcher(
                duration: context.motion(MadarMotion.short),
                child: _DueRow(key: ValueKey(p.id), person: p, onOpen: () => openPerson(p.id)),
              ),
            if (due.length > maxPeople)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.xs),
                child: MadarPressable(
                  onTap: open,
                  sfx: null,
                  semanticLabel: l.familyOpenAll,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l.familyCardMore(tx.count(due.length - maxPeople)),
                        style: text.labelMedium!.copyWith(color: t.accent),
                      ),
                    ),
                  ),
                ),
              ),
            if (birthdays.isNotEmpty) ...[
              const SizedBox(height: Space.s),
              Container(height: 0.8, color: t.glassBorder),
              const SizedBox(height: Space.s),
              for (final p in birthdays.take(2))
                MadarPressable(
                  onTap: () => openPerson(p.id),
                  sfx: null,
                  // No semanticLabel: the line and the age are read once each.
                  // 48 dp high (Android).
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Icon(Icons.cake_rounded, size: 16, color: t.gold),
                        const SizedBox(width: Space.s),
                        Expanded(
                          child: Text(
                            tx.birthdayUpcoming(p.name, p.birthday!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall!.copyWith(color: t.textPrimary),
                          ),
                        ),
                        if (tx.age(p.birthday!.turning) case final age?)
                          Text(age, style: text.labelSmall!.copyWith(color: t.gold)),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DueRow extends ConsumerWidget {
  const _DueRow({super.key, required this.person, required this.onOpen});

  final PersonView person;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final text = Theme.of(context).textTheme;
    final r = person.rhythm;
    final relation = tx.relationBeside(person.name, person.relation);
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: Space.xxs),
      child: Row(
        children: [
          Expanded(
            child: MadarPressable(
              onTap: onOpen,
              sfx: null,
              // No semanticLabel: name, relation and status are read once each.
              // 48 dp high (Android).
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    PersonAvatar(person: person, size: 38),
                    const SizedBox(width: Space.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: tx.name(person.name), style: text.titleSmall),
                                if (relation != null)
                                  TextSpan(
                                    text: '${tx.l.familyDot}${tx.name(relation)}',
                                    style: text.labelSmall!.copyWith(color: t.textTertiary),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            tx.status(r),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall!.copyWith(color: familyStatusColor(r.status, t)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ContactedButton(
            size: 40,
            emphasis: true,
            semanticLabel: tx.l.familyContactedTitle(BidiIsolate.strip(person.name)),
            onPressed: (ctx) async {
              await FamilyActions.contacted(ctx, ref, person);
            },
          ),
        ],
      ),
    );
  }
}
