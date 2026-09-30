import 'package:flutter/material.dart';

import '../../../../core/design/themes.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../../domain/documents.dart';
import '../../domain/packing.dart';
import '../../domain/trip_timeline.dart';

/// A glass segmented control whose thumb springs between the tabs (follows
/// the reading direction: the first tab sits at the start – the right in
/// Arabic).
class TravelTabBar<T> extends StatelessWidget {
  const TravelTabBar({super.key, required this.tabs, required this.value, required this.labels, required this.onChanged});

  final List<T> tabs;
  final T value;
  final Map<T, String> labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final dir = Directionality.of(context);
    final index = tabs.indexOf(value);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        height: 52,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: t.glassFill,
          border: Border.all(color: t.glassBorder),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth / tabs.length;
            return Stack(
              children: [
                SpringBuilder(
                  value: index.toDouble(),
                  spring: MadarMotion.snappy,
                  builder: (context, v, _) {
                    final x = dir == TextDirection.rtl ? constraints.maxWidth - w * (v + 1) : w * v;
                    return Positioned(
                      left: x,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color.lerp(t.accent, t.starTint, 0.18)!, t.accent],
                          ),
                          boxShadow: t.isDark
                              ? [BoxShadow(color: t.accentGlow.withValues(alpha: 0.35), blurRadius: 14)]
                              : null,
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (final tab in tabs)
                      Expanded(
                        child: MadarPressable(
                          onTap: tab == value ? null : () => onChanged(tab),
                          sfx: Sfx.navigate,
                          selected: tab == value,
                          semanticLabel: labels[tab],
                          excludeChildSemantics: true,
                          focusRadius: BorderRadius.circular(99),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: context.motion(MadarMotion.short),
                              style: text.labelLarge!.copyWith(
                                color: tab == value ? t.textOnAccent : t.textSecondary,
                                height: 1.2,
                              ),
                              child: Text(labels[tab] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Keeps every tab alive and cross-fades to [index] (hidden tabs stop
/// ticking and ignore input).
class TravelFadeStack extends StatelessWidget {
  const TravelFadeStack({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = context.motion(MadarMotion.medium);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: ExcludeSemantics(
              excluding: i != index,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: duration,
                curve: MadarMotion.standard,
                child: AnimatedSlide(
                  offset: i == index ? Offset.zero : const Offset(0, 0.015),
                  duration: duration,
                  curve: MadarMotion.decelerate,
                  child: TickerMode(enabled: i == index, child: children[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Softens the top edge where a list scrolls under a pinned bar.
class TravelEdgeFade extends StatelessWidget {
  const TravelEdgeFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0x00FFFFFF), Color(0xFFFFFFFF)],
        stops: [0, (16 / rect.height).clamp(0.0, 1.0)],
      ).createShader(rect),
      child: child,
    );
  }
}

/// The palette of a trip: its own colour, else the Travel planet's.
PlanetPalette tripPalette(int? color) =>
    color == null ? PlanetPalettes.travel : PlanetPalettes.fromColor(Color(color));

/// A small world for a trip – its colour, lit from the upper start, with a
/// plane (or a check once finished).
class TripOrb extends StatelessWidget {
  const TripOrb({super.key, required this.color, this.size = 44, this.phase = TripPhase.upcoming});

  final int? color;
  final double size;
  final TripPhase phase;

  @override
  Widget build(BuildContext context) {
    final p = tripPalette(color);
    final past = phase == TripPhase.past;
    final icon = switch (phase) {
      TripPhase.current => Icons.flight_land_rounded,
      TripPhase.past => Icons.check_rounded,
      _ => Icons.flight_takeoff_rounded,
    };
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Opacity(
      opacity: past ? 0.7 : 1,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: Alignment(rtl ? 0.35 : -0.35, -0.4),
            colors: [p.glow, p.surface, p.deep],
            stops: const [0, 0.55, 1],
          ),
          boxShadow: [BoxShadow(color: p.surface.withValues(alpha: past ? 0.15 : 0.45), blurRadius: size * 0.3)],
        ),
        child: Icon(icon, size: size * 0.44, color: p.deep, textDirection: TextDirection.ltr),
      ),
    );
  }
}

/// Tone of a countdown pill.
enum PillTone { accent, success, warning, danger, neutral, gold }

Color pillColor(PillTone tone, MadarTokens t) => switch (tone) {
  PillTone.accent => t.accent,
  PillTone.success => t.success,
  PillTone.warning => t.warning,
  PillTone.danger => t.danger,
  PillTone.neutral => t.textSecondary,
  PillTone.gold => t.gold,
};

/// A soft glass pill with a tinted label.
class TravelPill extends StatelessWidget {
  const TravelPill({super.key, required this.label, this.tone = PillTone.accent, this.icon, this.dense = false});

  final String label;
  final PillTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = pillColor(tone, t);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsetsDirectional.symmetric(horizontal: dense ? Space.s : Space.m, vertical: dense ? 2 : Space.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: c.withValues(alpha: t.isDark ? 0.16 : 0.12),
        border: Border.all(color: c.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: dense ? 12 : 14, color: c), const SizedBox(width: Space.xs)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (dense ? text.labelSmall : text.labelMedium)!.copyWith(color: c, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The tone of a trip's countdown.
PillTone countdownTone(TripCountdown c) => switch (c.kind) {
  CountdownKind.undated => PillTone.neutral,
  CountdownKind.startsIn => c.days <= 3 ? PillTone.gold : PillTone.accent,
  CountdownKind.underway => PillTone.success,
  CountdownKind.ended || CountdownKind.finished => PillTone.neutral,
};

/// The tone of a document's expiry.
PillTone expiryTone(ExpiryState s) => switch (s) {
  ExpiryState.none => PillTone.neutral,
  ExpiryState.ok => PillTone.success,
  ExpiryState.soon => PillTone.warning,
  ExpiryState.today || ExpiryState.expired => PillTone.danger,
};

/// The tone of a trip warning.
PillTone conflictTone(DocumentConflict c) => switch (c) {
  DocumentConflict.beforeTrip => PillTone.danger,
  DocumentConflict.duringTrip => PillTone.warning,
  DocumentConflict.validityShort => PillTone.gold,
};

IconData docKindIcon(TravelDocKind k) => switch (k) {
  TravelDocKind.passport => Icons.menu_book_rounded,
  TravelDocKind.visa => Icons.approval_rounded,
  TravelDocKind.licence => Icons.directions_car_rounded,
  TravelDocKind.id => Icons.badge_rounded,
  TravelDocKind.insurance => Icons.health_and_safety_rounded,
  TravelDocKind.other => Icons.description_rounded,
};

IconData categoryIcon(String category) => switch (PackingCategories.of(category)) {
  PackingCategories.documents => Icons.airplane_ticket_rounded,
  PackingCategories.clothes => Icons.checkroom_rounded,
  PackingCategories.toiletries => Icons.clean_hands_rounded,
  PackingCategories.health => Icons.medical_services_rounded,
  PackingCategories.electronics => Icons.devices_rounded,
  PackingCategories.prayer => Icons.mosque_rounded,
  PackingCategories.misc => Icons.category_rounded,
  _ => Icons.label_rounded,
};

/// Packed / total ring with the count inside; glows in success colour when
/// everything is packed.
class PackingRing extends StatelessWidget {
  const PackingRing({super.key, required this.progress, this.size = 88, this.label, this.semanticLabel});

  final PackingProgress progress;
  final double size;

  /// The text inside (e.g. "٥/٨").
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final done = progress.complete;
    return ProgressRing(
      value: progress.fraction,
      size: size,
      strokeWidth: size >= 64 ? 7 : 4,
      color: done ? t.success : t.accent,
      gradientEnd: done ? Color.lerp(t.success, t.gold, 0.4) : t.gold,
      semanticLabel: semanticLabel,
      child: label == null
          ? (done ? Icon(Icons.check_rounded, color: t.success, size: size * 0.4) : null)
          : Text(
              label!,
              textDirection: TextDirection.ltr,
              style: (size >= 64 ? text.titleMedium : text.labelSmall)!.copyWith(
                color: done ? t.success : t.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

/// A caption row with a leading icon (used under titles).
class TravelMetaLine extends StatelessWidget {
  const TravelMetaLine({super.key, required this.icon, required this.text, this.color, this.maxLines = 1});

  final IconData icon;
  final String text;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(color: color ?? t.textSecondary, height: 1.35);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(top: 2, end: Space.xs),
          child: Icon(icon, size: 14, color: color ?? t.textTertiary),
        ),
        Expanded(
          child: Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style),
        ),
      ],
    );
  }
}
