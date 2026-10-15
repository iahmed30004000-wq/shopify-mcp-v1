import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/motion/motion_kit.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/support_rule.dart';
import '../../domain/wellbeing_settings.dart';
import '../wellbeing_actions.dart';

/// The gentle support banner (see [SupportRule]): when several recent
/// check-ins had a low mood, it quietly offers the emergency number (911 in
/// Jordan by default, editable in settings) and can be hidden for a week.
/// It never names a condition or interprets anything. Renders nothing while
/// the rule does not apply.
class SupportBanner extends ConsumerWidget {
  const SupportBanner({super.key, this.compact = false, this.padding = EdgeInsets.zero});

  /// One line + call button (the hub card).
  final bool compact;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(supportStateProvider);
    final settings = ref.watch(wellbeingSettingsProvider).value ?? const WellbeingSettings();
    return AnimatedReveal(
      visible: state.show,
      appear: false,
      child: state.show
          ? Padding(
              padding: padding,
              child: compact
                  ? _Compact(state: state, number: settings.supportNumber)
                  : _Full(state: state, number: settings.supportNumber),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

Color _tone(MadarTokens t) => Color.lerp(t.info, t.accent, 0.3)!;

class _Full extends ConsumerWidget {
  const _Full({required this.state, required this.number});

  final SupportState state;
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final tone = _tone(t);
    final shownNumber = BidiIsolate.ltr(fmt.localizeDigits(number));
    return Semantics(
      container: true,
      liveRegion: true,
      child: GlassCard(
        tint: tone.withValues(alpha: t.isDark ? 0.1 : 0.08),
        borderColor: tone.withValues(alpha: 0.45),
        glowColor: tone.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(t.radiusL),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.s, Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tone.withValues(alpha: 0.16),
                    border: Border.all(color: tone.withValues(alpha: 0.5)),
                  ),
                  child: Icon(Icons.volunteer_activism_outlined, size: 20, color: tone),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.wbSupportTitle, style: text.titleMedium),
                      const SizedBox(height: Space.xxs),
                      Text(
                        fmt.localizeDigits(
                          l.wbSupportBody(fmt.formatInt(state.lowCount), fmt.formatInt(state.considered)),
                        ),
                        style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                MadarButton.icon(
                  icon: Icons.close_rounded,
                  semanticLabel: l.wbSupportHideWeek,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetClose,
                  onPressed: () => WellbeingActions.dismissSupport(context, ref),
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.s),
              child: Row(
                children: [
                  Expanded(
                    child: MadarButton(
                      label: l.wbSupportCall(shownNumber),
                      icon: Icons.call_rounded,
                      onPressed: () => WellbeingActions.callSupport(context, ref),
                    ),
                  ),
                  const SizedBox(width: Space.s),
                  MadarButton(
                    label: l.wbSupportHideWeek,
                    variant: MadarButtonVariant.ghost,
                    sfx: Sfx.sheetClose,
                    onPressed: () => WellbeingActions.dismissSupport(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Compact extends ConsumerWidget {
  const _Compact({required this.state, required this.number});

  final SupportState state;
  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final tone = _tone(t);
    final shownNumber = BidiIsolate.ltr(fmt.localizeDigits(number));
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs, Space.xs, Space.xs),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: t.isDark ? 0.12 : 0.09),
          borderRadius: BorderRadius.circular(t.radiusM),
          border: Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.volunteer_activism_outlined, size: 18, color: tone),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(l.wbSupportCompact, style: text.bodySmall?.copyWith(color: t.textPrimary)),
                ),
                MadarButton.icon(
                  icon: Icons.close_rounded,
                  semanticLabel: l.wbSupportHideWeek,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.sheetClose,
                  onPressed: () => WellbeingActions.dismissSupport(context, ref),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: Space.xs, bottom: Space.xs),
                child: MadarButton(
                  label: l.wbSupportCall(shownNumber),
                  icon: Icons.call_rounded,
                  size: MadarButtonSize.small,
                  onPressed: () => WellbeingActions.callSupport(context, ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
