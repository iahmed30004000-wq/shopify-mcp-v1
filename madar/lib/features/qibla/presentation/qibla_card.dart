import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../application/qibla_providers.dart';
import '../domain/qibla_fix.dart';
import 'qibla_labels.dart';
import 'widgets/qibla_dial.dart';
import 'widgets/qibla_dial_painter.dart';

/// A compact qibla card for the Faith hub: a small north-up astrolabe with
/// the needle on the qibla, the bearing (degrees + compass point) and the
/// distance to the Kaaba. No sensors run – tap to open [QiblaScreen].
class QiblaCard extends ConsumerWidget {
  const QiblaCard({super.key, required this.onOpen, this.place});

  /// Opens the compass (the host routes to `QiblaScreen`).
  final VoidCallback onOpen;

  /// Overrides the prayer location.
  final QiblaPlace? place;

  static final ValueNotifier<double?> _northUp = ValueNotifier(null);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final text = Theme.of(context).textTheme;
    final fix = place == null ? ref.watch(qiblaFixProvider) : QiblaFix.of(place!);
    final lang = Localizations.localeOf(context).languageCode;
    final name = fix.place.name(lang);
    final bearing = l.qiblaBearingText(fix.bearing, fmt);
    final distance = l.qiblaDistanceText(fix.distanceKm, fmt);
    return GlassCard(
      onTap: () {
        Fx.fire(Sfx.navigate);
        onOpen();
      },
      semanticLabel: '${l.qiblaCardTitle}: $bearing, $distance. ${l.qiblaCardOpen}',
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.m, Space.m, Space.m),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 96,
            child: ExcludeSemantics(
              child: QiblaDial(
                facing: _northUp,
                qiblaBearing: fix.bearing,
                kind: QiblaDialKind.diagram,
                detail: false,
                showArrow: false,
                style: QiblaDialStyle.of(
                  t,
                  cardinals: l.qiblaCardinals,
                  arabicDigits: fmt.arabicIndic,
                  degreeLabel: (d) => QiblaFormat.degrees(d, fmt),
                  compact: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.qiblaCardTitle, style: text.titleMedium?.copyWith(color: t.textPrimary)),
                const SizedBox(height: Space.xs),
                Text(
                  bearing,
                  style: text.titleLarge?.copyWith(color: t.gold, fontWeight: FontWeight.w700, fontSize: 24),
                ),
                const SizedBox(height: Space.xxs),
                Text(
                  name == null ? distance : '$distance · ${l.qiblaFromPlace(name)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: Space.xs),
                Text(l.qiblaCardOpen, style: text.labelLarge?.copyWith(color: t.accent)),
              ],
            ),
          ),
          const SizedBox(width: Space.s),
          // Mirrors itself in RTL.
          Icon(Icons.chevron_right_rounded, color: t.accent),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<QiblaPlace?>('place', place));
  }
}
