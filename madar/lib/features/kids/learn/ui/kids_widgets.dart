// Small building blocks shared by the letters, maths and colouring screens:
// big forgiving buttons (>= 64 dp), paper cards, a speaker button.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../voice/kids_voice.dart';
import 'kids_tokens.dart';

enum KidsButtonKind { gold, teal, rose, paper }

/// The filled "pill" button of the design: gradient face, darker lip beneath.
class KidsButton extends StatelessWidget {
  const KidsButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.kind = KidsButtonKind.gold,
    this.height = kKidsTarget,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final KidsButtonKind kind;
  final double height;
  final String? semanticLabel;

  (Color, Color, Color, Color) get _scheme => switch (kind) {
    KidsButtonKind.gold => (KidsColors.sun300, KidsColors.sun500, KidsColors.night900, KidsColors.sun700),
    KidsButtonKind.teal => (KidsColors.teal500, KidsColors.teal700, Colors.white, KidsColors.teal700),
    KidsButtonKind.rose => (KidsColors.rose300, KidsColors.rose500, KidsColors.night900, KidsColors.rose700),
    KidsButtonKind.paper => (KidsColors.paper, KidsColors.sand, KidsColors.ink, KidsColors.sand2),
  };

  @override
  Widget build(BuildContext context) {
    final (top, bottom, fg, lip) = _scheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
              boxShadow: [BoxShadow(color: lip, offset: const Offset(0, 4))],
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, color: fg, size: 26), const SizedBox(width: 10)],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: KidsType.title(22, color: fg).copyWith(height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 64 dp round icon button (paper face, soft lip).
class KidsRoundButton extends StatelessWidget {
  const KidsRoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.background = KidsColors.paper,
    this.foreground = KidsColors.night900,
    this.lip = KidsColors.sand2,
    this.size = kKidsTarget,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;
  final Color background;
  final Color foreground;
  final Color lip;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    label: semanticLabel,
    excludeSemantics: true,
    child: Opacity(
      opacity: onTap != null ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: lip, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: foreground, size: size * 0.44),
        ),
      ),
    ),
  );
}

/// The speaker next to every text. Plays [voiceId] through [kidsVoiceProvider]
/// (silent while the recording does not exist yet).
class SpeakerButton extends ConsumerWidget {
  const SpeakerButton({super.key, required this.voiceId, this.size = kKidsTarget});

  final String voiceId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    return KidsRoundButton(
      icon: Icons.volume_up_rounded,
      semanticLabel: l.kidsLearnHear,
      background: KidsColors.teal100,
      foreground: KidsColors.teal700,
      lip: KidsColors.teal200,
      size: size,
      onTap: () => ref.read(kidsVoiceProvider).play(voiceId),
    );
  }
}

/// A white rounded card with the design's soft drop shadow.
class KidsCard extends StatelessWidget {
  const KidsCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? const Color(0xFFFFFCF5),
      borderRadius: BorderRadius.circular(32),
      boxShadow: const [BoxShadow(color: Color(0x1F26214F), blurRadius: 14, offset: Offset(0, 6))],
    ),
    child: child,
  );
}

/// The soft amber "try again" line. There is no red and no cross anywhere.
class SoftRetryBanner extends StatelessWidget {
  const SoftRetryBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: KidsColors.retryFill,
        border: Border.all(color: KidsColors.retry, width: 2),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: KidsType.bodyText(20, color: KidsColors.retryText, weight: FontWeight.w700),
      ),
    ),
  );
}

/// The teal "well done" line.
class GoodBanner extends StatelessWidget {
  const GoodBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(color: KidsColors.teal100, borderRadius: BorderRadius.circular(28)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: KidsType.bodyText(20, color: KidsColors.teal700, weight: FontWeight.w700),
      ),
    ),
  );
}

/// A 64 dp segmented tab row (design 07b).
class KidsTabs extends StatelessWidget {
  const KidsTabs({super.key, required this.labels, required this.selected, required this.onSelect});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(color: KidsColors.teal100, borderRadius: BorderRadius.circular(40)),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              label: labels[i],
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i),
                child: Container(
                  constraints: const BoxConstraints(minHeight: kKidsTarget - 12),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    gradient: i == selected
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [KidsColors.teal500, KidsColors.teal700],
                          )
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: KidsType.title(20, color: i == selected ? Colors.white : KidsColors.teal700),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The soft tinted full-area background each section sits on. The shell draws
/// its own bar above; this only paints the body.
class KidsBackdrop extends StatelessWidget {
  const KidsBackdrop({super.key, required this.top, required this.child});

  final Color top;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, KidsColors.paper],
      ),
    ),
    child: SizedBox.expand(child: child),
  );
}

/// Eight-point star (khatam): the section's quiet ornament and the fallback
/// picture of a letter that has no drawing.
class KhatamStarPainter extends CustomPainter {
  const KhatamStarPainter({this.fill = KidsColors.sun300, this.line = KidsColors.sun500});

  final Color fill;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = -math.pi / 2 + i * math.pi / 8;
      final rad = i.isEven ? r : r * 0.62;
      final p = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06
          ..strokeJoin = StrokeJoin.round
          ..color = line,
      );
  }

  @override
  bool shouldRepaint(KhatamStarPainter old) => old.fill != fill || old.line != line;
}
