import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../transport/pairing_state.dart';
import 'pairing_texts.dart';

/// Why Madar asks before Android's permission dialog – and what to do when
/// the permission was refused or location services are off. Buttons are the
/// sheet's footer.
class NearbyPermissionPanel extends StatelessWidget {
  const NearbyPermissionPanel({super.key, required this.state});

  /// [PairingPhase.needsPermission], [PairingPhase.permissionDenied] or
  /// [PairingPhase.serviceOff].
  final PairingState state;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final px = PairingTexts.of(context);
    final l = px.l;
    final need = state.need ?? NearbyPermissionNeed.nearbyDevices;
    final serviceOff = state.phase == PairingPhase.serviceOff;
    final denied = state.phase == PairingPhase.permissionDenied;
    final location = need != NearbyPermissionNeed.nearbyDevices;

    final title = serviceOff
        ? l.togetherNetLocationOff
        : denied
        ? l.togetherNetPermDenied
        : l.togetherNetPermTitle;
    final bodies = <String>[
      if (serviceOff) l.togetherNetLocationOffBody,
      if (!serviceOff && denied && state.permanentlyDenied) l.togetherNetPermDeniedForever,
      if (!serviceOff && need != NearbyPermissionNeed.location) l.togetherNetPermNearbyBody,
      if (!serviceOff && location) l.togetherNetPermLocationBody,
    ];
    final icon = serviceOff
        ? Icons.location_off_rounded
        : denied
        ? (need == NearbyPermissionNeed.location ? Icons.location_disabled_rounded : Icons.bluetooth_disabled_rounded)
        : need == NearbyPermissionNeed.location
        ? Icons.location_searching_rounded
        : Icons.bluetooth_searching_rounded;
    final tone = denied || serviceOff ? t.warning : t.accent;

    Widget point(IconData i, String s) => Padding(
      padding: const EdgeInsets.only(top: Space.s),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 18, color: t.success),
          const SizedBox(width: Space.s),
          Expanded(child: Text(s, style: text.bodyMedium?.copyWith(color: t.textSecondary))),
        ],
      ),
    );

    return Column(
      key: ValueKey('together-permission-${state.phase.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [tone.withValues(alpha: 0.3), tone.withValues(alpha: 0.04)]),
              border: Border.all(color: tone.withValues(alpha: 0.7), width: 1.2),
              boxShadow: [BoxShadow(color: tone.withValues(alpha: 0.35), blurRadius: 22)],
            ),
            child: Icon(icon, size: 36, color: tone),
          ),
        ),
        const SizedBox(height: Space.l),
        Semantics(
          header: true,
          child: Text(title, textAlign: TextAlign.center, style: text.titleLarge),
        ),
        for (final b in bodies) ...[
          const SizedBox(height: Space.s),
          Text(b, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.45)),
        ],
        if (!serviceOff && !denied) ...[
          const SizedBox(height: Space.m),
          point(Icons.timer_outlined, l.togetherNetPermPointPairing),
          point(Icons.shield_moon_rounded, l.togetherNetPermPointGameOnly),
          point(Icons.bluetooth_disabled_rounded, l.togetherNetPermPointStops),
        ],
      ],
    );
  }
}
