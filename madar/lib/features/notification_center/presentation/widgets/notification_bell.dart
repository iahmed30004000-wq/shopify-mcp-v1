import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/center_controller.dart';
import '../../domain/center_texts.dart';
import '../notification_center_screen.dart';

/// Opens the notification center (a plain push; the lead may route it).
Future<void> openNotificationCenter(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationCenterScreen()));

/// The bell for an app bar or the home panel: a round glass button with the
/// count of new notifications in a small badge that springs in and out.
/// Opens the center ([onPressed] overrides, e.g. with a route).
class NotificationBell extends ConsumerWidget {
  const NotificationBell({
    super.key,
    this.onPressed,
    this.variant = MadarButtonVariant.ghost,
    this.size = MadarButtonSize.medium,
  });

  final VoidCallback? onPressed;
  final MadarButtonVariant variant;
  final MadarButtonSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = CenterTexts.of(context);
    final count = ref.watch(notificationUnreadCountProvider);
    final label = count > 99 ? '${tx.count(99)}+' : tx.count(count);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        MadarButton.icon(
          icon: count > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          semanticLabel: tx.digits(tx.l.ncBellLabel(count)),
          variant: variant,
          size: size,
          sfx: Sfx.navigate,
          onPressed: onPressed ?? () => openNotificationCenter(context),
        ),
        PositionedDirectional(
          top: -2,
          end: -2,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: SpringBuilder(
                value: count > 0 ? 1 : 0,
                spring: MadarMotion.bouncy,
                builder: (context, v, child) =>
                    v <= 0.01 ? const SizedBox.shrink() : Transform.scale(scale: v.clamp(0, 1.3), child: child),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: t.accent,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: t.space1, width: 1.5),
                    boxShadow: [BoxShadow(color: t.accentGlow.withValues(alpha: 0.55), blurRadius: 8)],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: text.labelSmall!.copyWith(
                      color: t.textOnAccent,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
