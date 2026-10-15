import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/contact_launcher.dart';
import '../../domain/family_models.dart';
import '../../domain/rhythm.dart';
import '../../family_texts.dart';
import '../family_actions.dart';
import '../family_navigation.dart';
import 'family_widgets.dart';

/// One person in the Family list: their orb and rhythm ring, name and
/// relation, where they stand ("3 days overdue · last contact 9 days ago"),
/// and the one-tap "contacted" heart. Swipe right = contacted; swipe left =
/// call / WhatsApp / delete; long-press = everything else.
class PersonTile extends ConsumerWidget {
  const PersonTile({super.key, required this.person, this.dragHandle, this.onOpenPerson});

  final PersonView person;
  final Widget? dragHandle;
  final FamilyOpenPerson? onOpenPerson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = FamilyTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final r = person.rhythm;
    final status = r.status;
    final statusColor = familyStatusColor(status, t);
    final relation = tx.relationBeside(person.name, person.relation);
    final statusText = r.hasRhythm ? tx.status(r) : null;
    final lastText = tx.lastContact(r);
    final statusLine = [?statusText, lastText].join(l.familyDot);
    final birthday = person.birthday;
    final soonBirthday = birthday != null && birthday.daysUntil <= 14;

    void open() {
      if (onOpenPerson != null) {
        onOpenPerson!(context, person.id);
      } else {
        FamilyNavigation.openPerson(context, person.id);
      }
    }

    return ActionableItem(
      semanticLabel: [person.name, ?relation, statusLine].join(l.familyDot),
      borderRadius: BorderRadius.circular(t.radiusL),
      onTap: open,
      completeIcon: Icons.favorite_rounded,
      completeLabel: l.familyContacted,
      onCompleteSwipe: () => FamilyActions.contacted(context, ref, person, toast: false, sound: false),
      actions: ItemActions(
        onEdit: () => FamilyActions.editPerson(context, ref, person.row),
        onDelete: () => FamilyActions.deletePerson(context, ref, person.row),
        extra: [
          ItemAction(
            icon: Icons.favorite_rounded,
            label: l.familyContactedDetails,
            tone: ActionTone.success,
            onSelected: () => FamilyActions.contactedWithDetails(context, ref, person, toast: false),
          ),
          if (person.hasPhone) ...[
            ItemAction(
              icon: Icons.call_rounded,
              label: l.familyCall,
              onSelected: () async {
                await FamilyActions.launch(context, ref, person, ContactLaunch.call);
                return null;
              },
            ),
            ItemAction(
              icon: Icons.sms_rounded,
              label: l.familySms,
              onSelected: () async {
                await FamilyActions.launch(context, ref, person, ContactLaunch.sms);
                return null;
              },
            ),
            ItemAction(
              icon: Icons.chat_rounded,
              label: l.familyWhatsApp,
              onSelected: () async {
                await FamilyActions.launch(context, ref, person, ContactLaunch.whatsapp);
                return null;
              },
            ),
          ],
          ItemAction(
            icon: person.row.showAsMoon ? Icons.brightness_3_outlined : Icons.brightness_3_rounded,
            label: person.row.showAsMoon ? l.familyMoonHide : l.familyMoonShow,
            onSelected: () => FamilyActions.toggleMoon(context, ref, person.row),
          ),
          ItemAction(
            icon: Icons.person_rounded,
            label: l.familyOpenProfile,
            onSelected: () {
              open();
              return null;
            },
          ),
        ],
      ),
      quickActions: [
        if (person.hasPhone) ...[
          QuickAction(
            icon: Icons.call_rounded,
            label: l.familyCall,
            tone: ActionTone.success,
            onPressed: () async {
              await FamilyActions.launch(context, ref, person, ContactLaunch.call);
              return null;
            },
          ),
          QuickAction(
            icon: Icons.chat_rounded,
            label: l.familyWhatsApp,
            tone: ActionTone.info,
            onPressed: () async {
              await FamilyActions.launch(context, ref, person, ContactLaunch.whatsapp);
              return null;
            },
          ),
        ],
        QuickAction(
          icon: Icons.delete_outline_rounded,
          label: l.familyDelete,
          tone: ActionTone.danger,
          onPressed: () {
            Fx.fire(Sfx.delete);
            return FamilyActions.deletePerson(context, ref, person.row);
          },
        ),
      ],
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusL),
        borderColor: status == RhythmStatus.overdue ? t.danger.withValues(alpha: 0.45) : null,
        padding: EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, dragHandle == null ? Space.s : 0, Space.m),
        child: Row(
          children: [
            PersonAvatar(person: person, size: 50),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: tx.name(person.name), style: text.titleMedium),
                        if (relation != null)
                          TextSpan(
                            text: '${l.familyDot}${tx.name(relation)}',
                            style: text.bodySmall!.copyWith(color: t.textTertiary),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        if (statusText != null)
                          TextSpan(
                            text: '$statusText${l.familyDot}',
                            style: TextStyle(
                              color: status == RhythmStatus.ok ? t.textSecondary : statusColor,
                              fontWeight: status == RhythmStatus.overdue ? FontWeight.w600 : null,
                            ),
                          ),
                        TextSpan(text: lastText),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: t.textSecondary),
                  ),
                  if (r.hasRhythm || soonBirthday) ...[
                    const SizedBox(height: Space.xs + 2),
                    Wrap(
                      spacing: Space.xs,
                      runSpacing: Space.xs,
                      children: [
                        if (r.hasRhythm)
                          FamilyBadge(
                            label: tx.rhythm(r.rhythmDays),
                            color: t.textSecondary,
                            icon: Icons.autorenew_rounded,
                          ),
                        if (person.lastChannel != null && r.lastContact != null)
                          FamilyBadge(
                            label: tx.channel(person.lastChannel!),
                            color: t.textTertiary,
                            icon: channelIcon(person.lastChannel!),
                          ),
                        if (soonBirthday)
                          FamilyBadge(
                            label: tx.birthdayWhen(birthday),
                            color: t.gold,
                            icon: Icons.cake_rounded,
                            filled: true,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Space.xs),
            ContactedButton(
              semanticLabel: l.familyContactedTitle(BidiIsolate.strip(person.name)),
              emphasis: r.isDue,
              onPressed: (ctx) async {
                await FamilyActions.contacted(ctx, ref, person);
              },
            ),
            ?dragHandle,
          ],
        ),
      ),
    );
  }
}
