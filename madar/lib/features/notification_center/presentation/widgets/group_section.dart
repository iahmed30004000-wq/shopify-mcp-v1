import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/center_providers.dart';
import '../../domain/center_models.dart';
import '../../domain/center_texts.dart';
import '../center_actions.dart';
import '../center_visuals.dart';
import 'notification_row.dart';

/// One group of the center: its name and count, its mute (tap to unmute),
/// and its notifications – the first few, the rest one tap away.
class CenterGroupSection extends ConsumerStatefulWidget {
  const CenterGroupSection({super.key, required this.section, this.collapsedCount = 4});

  final CenterSection section;

  /// Rows shown before "Show N more".
  final int collapsedCount;

  @override
  ConsumerState<CenterGroupSection> createState() => _CenterGroupSectionState();
}

class _CenterGroupSectionState extends ConsumerState<CenterGroupSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = CenterTexts.of(context);
    final l = tx.l;
    final s = widget.section;
    final now = ref.watch(notificationCenterClockProvider)();
    final hidden = s.count - widget.collapsedCount;
    final collapsible = hidden > 1;
    final items = collapsible && !_expanded ? s.items.take(widget.collapsedCount) : s.items;
    final hue = groupColor(s.group, t);
    final name = tx.group(s.group);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, 0, Space.s),
          child: Row(
            children: [
              CenterGroupDisc(group: s.group, size: 26),
              const SizedBox(width: Space.s),
              Expanded(
                child: Semantics(
                  header: true,
                  label: l.ncSectionLabel(name, tx.count(s.count)),
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium!.copyWith(color: t.textPrimary),
                        ),
                      ),
                      const SizedBox(width: Space.s),
                      CenterBadge(label: tx.count(s.count), color: hue),
                    ],
                  ),
                ),
              ),
              if (s.mutedUntil != null)
                Flexible(
                  child: MadarPressable(
                    onTap: () => CenterActions.unmute(context, ref, s.group),
                    sfx: null,
                    semanticLabel: tx.join([l.ncMutedUntil(tx.until(s.mutedUntil!, now)), l.ncActionUnmute]),
                    excludeChildSemantics: true,
                    focusRadius: BorderRadius.circular(99),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        widthFactor: 1,
                        child: CenterBadge(
                          label: l.ncMutedUntil(tx.until(s.mutedUntil!, now)),
                          color: t.warning,
                          icon: Icons.notifications_paused_rounded,
                        ),
                      ),
                    ),
                  ),
                )
              else
                MadarButton.icon(
                  icon: Icons.notifications_paused_outlined,
                  semanticLabel: l.ncActionMuteGroup(name),
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetOpen,
                  onPressed: () => CenterActions.pickMute(context, ref, s.group),
                ),
            ],
          ),
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.standard,
          alignment: AlignmentDirectional.topStart,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in items)
                Padding(
                  key: ValueKey(item.key),
                  padding: const EdgeInsets.only(bottom: Space.s),
                  child: NotificationRow(item: item),
                ),
            ],
          ),
        ),
        if (collapsible)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              label: _expanded ? l.ncShowLess : tx.digits(l.ncShowMore(hidden)),
              trailingIcon: _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              variant: MadarButtonVariant.ghost,
              size: MadarButtonSize.small,
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ),
      ],
    );
  }
}
