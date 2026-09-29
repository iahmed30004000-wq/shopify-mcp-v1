import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../application/adhan_providers.dart';
import '../data/adhan_permissions.dart';

/// Explains and requests what the adhan needs – notifications, exact alarms,
/// the lock-screen display (Android 14+) and the battery-optimisation
/// exemption – with each one's live status (re-checked when the user comes
/// back from system settings). When everything is allowed it folds into a
/// single calm line. A muted alarm volume is flagged too.
class AdhanPermissionsCard extends ConsumerWidget {
  const AdhanPermissionsCard({super.key, this.compactWhenReady = true, this.showHeader = true});

  /// Collapse to one line once everything is granted.
  final bool compactWhenReady;

  /// The card's own title and subtitle – off where the page already says
  /// it (the onboarding step's heading; a sheet's frame never shows it).
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(adhanPermissionStatusProvider);
    return AnimatedSize(
      duration: context.motion(MadarMotion.medium),
      curve: MadarMotion.standard,
      alignment: AlignmentDirectional.topCenter,
      child: switch (status) {
        AsyncData(:final value) => _Card(status: value, compactWhenReady: compactWhenReady, showHeader: showHeader),
        AsyncError() => _Card(status: AdhanPermissionStatus.unknown, compactWhenReady: false, showHeader: false),
        _ => const _Loading(),
      },
    );
  }
}

/// The permission card in a sheet (e.g. right after the user turns an adhan
/// on and something is missing).
Future<void> showAdhanPermissionsSheet(BuildContext context) => showInteractionSheet<void>(
  context,
  builder: (sheetContext) {
    final l = L10n.of(sheetContext);
    return InteractionSheetFrame(
      title: l.adhanPermTitle,
      subtitle: l.adhanPermSubtitle,
      icon: Icons.mosque_rounded,
      body: const AdhanPermissionsCard(compactWhenReady: false),
    );
  },
);

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(Space.l),
    child: Center(child: OrbitLoader(size: 28)),
  );
}

class _Card extends ConsumerWidget {
  const _Card({required this.status, required this.compactWhenReady, this.showHeader = true});

  final AdhanPermissionStatus status;
  final bool compactWhenReady;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final volume = status.alarmVolume;
    final volumeWarning = status.alarmMuted
        ? _VolumeWarning(onOpen: () => unawaited(ref.read(adhanSystemProvider).openSoundSettings()))
        : null;

    if (status.allGranted && compactWhenReady) {
      return GlassPanel(
        key: const ValueKey('ready'),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
        glow: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.verified_rounded, color: t.success, size: 22),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Text(l.adhanPermReady, style: text.bodyMedium!.copyWith(color: t.textPrimary)),
                ),
              ],
            ),
            ?volumeWarning,
          ],
        ),
      );
    }

    return GlassPanel(
      key: const ValueKey('ask'),
      padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
      glowColor: t.accentGlow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compactWhenReady && showHeader)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.xs),
              child: Row(
                children: [
                  IslamicStar(size: 18, color: t.gold, glow: true),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.adhanPermTitle, style: text.titleMedium),
                        Text(l.adhanPermSubtitle, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          for (final p in AdhanPermission.values)
            _PermissionRow(
              permission: p,
              granted: status.isGranted(p),
              refused: status.isRefused(p),
              onRequest: () async {
                final ok = await ref.read(adhanPermissionStatusProvider.notifier).request(p);
                Fx.fire(ok ? Sfx.toggleOn : Sfx.error);
              },
            ),
          // A row refused in this session says so itself.
          if (!status.allGranted && !AdhanPermission.values.any(status.isRefused))
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.xs, Space.l, Space.s),
              child: Text(l.adhanPermDeniedHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
            ),
          if (volume != null && volumeWarning != null)
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l),
              child: volumeWarning,
            ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.granted,
    required this.onRequest,
    this.refused = false,
  });

  final AdhanPermission permission;
  final bool granted;

  /// Refused in the system dialog: the button opens the settings page.
  final bool refused;
  final Future<void> Function() onRequest;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final (icon, title, hint) = switch (permission) {
      AdhanPermission.notifications => (
        Icons.notifications_active_rounded,
        l.adhanPermNotifications,
        l.adhanPermNotificationsHint,
      ),
      AdhanPermission.exactAlarms => (Icons.alarm_on_rounded, l.adhanPermExact, l.adhanPermExactHint),
      AdhanPermission.fullScreen => (Icons.fullscreen_rounded, l.adhanPermFullScreen, l.adhanPermFullScreenHint),
      AdhanPermission.battery => (Icons.battery_saver_rounded, l.adhanPermBattery, l.adhanPermBatteryHint),
    };
    final required = permission == AdhanPermission.notifications;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.m),
        child: Row(
          children: [
            AnimatedContainer(
              duration: context.motion(MadarMotion.medium),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (granted ? t.success : t.accent).withValues(alpha: 0.14),
                border: Border.all(color: (granted ? t.success : t.accent).withValues(alpha: 0.4), width: 0.8),
              ),
              child: Icon(granted ? Icons.check_rounded : icon, size: 18, color: granted ? t.success : t.accent),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: Space.s,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (required && !granted)
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.s, vertical: 1),
                          decoration: BoxDecoration(
                            color: t.warning.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(t.radiusS),
                          ),
                          child: Text(l.adhanPermRequired, style: text.labelSmall!.copyWith(color: t.warning)),
                        ),
                    ],
                  ),
                  Text(
                    refused ? l.adhanPermRefusedHint : hint,
                    style: text.bodySmall!.copyWith(color: refused ? t.warning : t.textTertiary, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s),
            AnimatedSwitcher(
              duration: context.motion(MadarMotion.medium),
              child: granted
                  ? Text(
                      l.adhanPermAllowed,
                      key: const ValueKey('granted'),
                      style: text.labelLarge!.copyWith(color: t.success),
                    )
                  : MadarButton(
                      key: ValueKey(refused ? 'settings' : 'ask'),
                      label: refused ? l.adhanPermOpenSettings : l.adhanPermAllow,
                      icon: refused ? Icons.open_in_new_rounded : null,
                      onPressed: () => unawaited(onRequest()),
                      size: MadarButtonSize.small,
                      variant: required ? MadarButtonVariant.primary : MadarButtonVariant.secondary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeWarning extends StatelessWidget {
  const _VolumeWarning({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.s, bottom: Space.s),
      child: Row(
        children: [
          Icon(Icons.volume_off_rounded, color: t.warning, size: 20),
          const SizedBox(width: Space.m),
          Expanded(
            child: Text(l.adhanAlarmMuted, style: text.bodySmall!.copyWith(color: t.warning)),
          ),
          MadarButton(
            label: l.adhanOpenSoundSettings,
            onPressed: onOpen,
            size: MadarButtonSize.small,
            variant: MadarButtonVariant.ghost,
          ),
        ],
      ),
    );
  }
}

/// Formats the alarm volume for the settings row (`٧٠٪`).
String alarmVolumeLabel(MadarFormatter fmt, AdhanPermissionStatus status) {
  final v = status.alarmVolume;
  return v == null ? '' : fmt.formatPercent(v.fraction);
}
