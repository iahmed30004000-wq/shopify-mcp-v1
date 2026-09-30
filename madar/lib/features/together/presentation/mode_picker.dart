import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart' show FieldShell;
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../data/together_providers.dart';
import '../domain/play_modes.dart';
import 'together_texts.dart';

/// Icon of a play mode.
IconData togetherModeIcon(PlayMode m) => switch (m) {
  PlayMode.passAndPlay => Icons.phone_android_rounded,
  PlayMode.splitScreen => Icons.splitscreen_rounded,
  PlayMode.nearby => Icons.bluetooth_rounded,
  PlayMode.online => Icons.public_rounded,
};

/// The four play modes as glass cards (two per row): the selected one lit,
/// modes without a transport marked "coming soon", modes the game lacks
/// marked (or left out with [hideUnsupported]).
class PlayModePicker extends ConsumerWidget {
  const PlayModePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.gameModes,
    this.hideUnsupported = true,
  });

  final PlayMode? selected;
  final ValueChanged<PlayMode> onChanged;

  /// The modes the game offers (null: all – the settings default picker).
  final Set<PlayMode>? gameModes;
  final bool hideUnsupported;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(togetherModeAvailabilityProvider);
    final modes = [
      for (final m in PlayMode.values)
        if (!hideUnsupported || availability(m, gameModes: gameModes) != ModeAvailability.unsupported) m,
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 320;
        final width = twoColumns ? (constraints.maxWidth - Space.m) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: Space.m,
          runSpacing: Space.m,
          children: [
            for (final m in modes)
              SizedBox(
                width: width,
                child: PlayModeCard(
                  mode: m,
                  availability: availability(m, gameModes: gameModes),
                  selected: m == selected,
                  onTap: () => onChanged(m),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One play mode.
class PlayModeCard extends StatelessWidget {
  const PlayModeCard({
    super.key,
    required this.mode,
    required this.availability,
    required this.selected,
    required this.onTap,
  });

  final PlayMode mode;
  final ModeAvailability availability;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final available = availability == ModeAvailability.available;
    final badge = tx.availability(availability);
    final motion = context.motion(MadarMotion.short);
    final accent = t.accent;
    return MadarPressable(
      key: ValueKey('together-mode-${mode.name}'),
      onTap: available ? onTap : () => Fx.fire(Sfx.error),
      sfx: available ? Sfx.tap : null,
      selected: selected,
      semanticLabel: [tx.mode(mode), ?badge].join(tx.arabic ? '، ' : ', '),
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusL),
      child: AnimatedContainer(
        duration: motion,
        curve: MadarMotion.standard,
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(t.radiusL),
          color: selected ? Color.alphaBlend(accent.withValues(alpha: 0.16), t.glassFill) : t.glassFill,
          border: Border.all(
            color: selected ? accent : t.glassBorder,
            width: selected ? 1.6 : 0.9,
          ),
          boxShadow: selected ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 18)] : null,
        ),
        child: Opacity(
          opacity: available ? 1 : 0.55,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [t.accentSoft, accent.withValues(alpha: 0.05)]),
                      border: Border.all(color: accent.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: Icon(togetherModeIcon(mode), size: 20, color: accent),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: motion,
                    child: selected
                        ? Icon(Icons.check_circle_rounded, key: const ValueKey('on'), size: 22, color: accent)
                        : const SizedBox(key: ValueKey('off'), width: 22, height: 22),
                  ),
                ],
              ),
              const SizedBox(height: Space.s),
              Text(
                tx.mode(mode),
                style: text.titleSmall?.copyWith(color: t.textPrimary, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Space.xxs),
              Text(
                tx.modeBody(mode),
                style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.35),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (badge != null) ...[
                const SizedBox(height: Space.s),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: t.gold.withValues(alpha: 0.6), width: 0.8),
                    color: t.gold.withValues(alpha: 0.1),
                  ),
                  child: Text(badge, style: text.labelSmall?.copyWith(color: t.gold)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ settings

/// A row for the app's Settings screen: "Together – default play mode";
/// opens [showTogetherSettingsSheet].
class TogetherSettingsTile extends ConsumerWidget {
  const TogetherSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(togetherSettingsProvider).value ?? const TogetherSettings();
    return GlassCard(
      key: const ValueKey('together-settings-tile'),
      onTap: () => unawaited(showTogetherSettingsSheet(context)),
      semanticLabel: '${tx.l.togetherSettingsDefaultMode}: ${tx.mode(settings.defaultMode)}',
      child: Row(
        children: [
          Icon(Icons.diversity_1_rounded, color: t.accent),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.l.togetherSettingsDefaultMode, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(tx.mode(settings.defaultMode), style: text.bodySmall?.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.textTertiary, textDirection: Directionality.of(context)),
        ],
      ),
    );
  }
}

/// Together settings: the default play mode, the split-screen layout,
/// hiding private turns from recents, and online play (off by default).
Future<void> showTogetherSettingsSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const TogetherSettingsSheet());

class TogetherSettingsSheet extends ConsumerWidget {
  const TogetherSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final tx = TogetherTexts.of(context);
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final settings = ref.watch(togetherSettingsProvider).value ?? const TogetherSettings();
    final repo = ref.read(togetherRepositoryProvider);
    final onlineTransport = ref.watch(togetherTransportFactoriesProvider).containsKey(PlayMode.online);
    void save(TogetherSettings s) => unawaited(repo.saveSettings(s));

    Widget switchRow({required String title, required String hint, required bool value, ValueChanged<bool>? onChanged}) =>
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text(hint, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: Space.m),
            MadarSwitch(value: value, onChanged: onChanged, semanticLabel: title),
          ],
        );

    return InteractionSheetFrame(
      title: l.togetherSettingsTitle,
      icon: Icons.diversity_1_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldShell(
            label: l.togetherSettingsDefaultMode,
            icon: Icons.sports_esports_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l.togetherSettingsDefaultModeHint, style: text.bodySmall?.copyWith(color: t.textSecondary)),
                const SizedBox(height: Space.m),
                PlayModePicker(
                  selected: settings.defaultMode,
                  hideUnsupported: false,
                  onChanged: (m) => save(settings.copyWith(defaultMode: m)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          FieldShell(
            label: l.togetherSplitLayout,
            icon: Icons.splitscreen_rounded,
            child: ChoicePills<SplitLayout>.single(
              dense: true,
              options: [
                for (final s in SplitLayout.values) ChoiceOption(value: s, label: tx.layout(s)),
              ],
              selected: settings.splitLayout,
              onChanged: (s) {
                if (s != null) save(settings.copyWith(splitLayout: s));
              },
            ),
          ),
          const SizedBox(height: Space.xl),
          switchRow(
            title: l.togetherSettingsPrivacy,
            hint: l.togetherSettingsPrivacyHint,
            value: settings.hideInRecents,
            onChanged: (v) => save(settings.copyWith(hideInRecents: v)),
          ),
          const SizedBox(height: Space.l),
          switchRow(
            title: l.togetherSettingsOnline,
            hint: onlineTransport ? l.togetherSettingsOnlineHint : '${l.togetherSettingsOnlineHint} ${l.togetherComingSoon}.',
            value: settings.onlineEnabled && onlineTransport,
            onChanged: onlineTransport ? (v) => save(settings.copyWith(onlineEnabled: v)) : null,
          ),
          const SizedBox(height: Space.xl),
          const TogetherPrivacyNote(),
        ],
      ),
    );
  }
}

/// "Only game state ever travels…" – shown wherever two phones are offered.
class TogetherPrivacyNote extends StatelessWidget {
  const TogetherPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_moon_rounded, size: 18, color: t.success),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text(
            TogetherTexts.of(context).l.togetherOnlyGameState,
            style: text.bodySmall?.copyWith(color: t.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }
}
