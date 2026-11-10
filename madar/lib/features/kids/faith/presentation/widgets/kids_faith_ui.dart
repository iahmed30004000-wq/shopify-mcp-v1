// Small building blocks shared by the kids faith screens (colours and sizes
// from docs/kids/DESIGN.md). Nothing religious lives here: only chrome.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/i18n/formatters.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../core/kids_section.dart' show kidsStarCountProvider;

/// Design palette (DESIGN.md section 2). There is deliberately NO red: a child
/// is never told he is wrong.
abstract final class KP {
  static const night900 = Color(0xFF17143F);
  static const night800 = Color(0xFF221E5A);
  static const night700 = Color(0xFF2F2A78);
  static const night300 = Color(0xFFA9A5E6);
  static const night100 = Color(0xFFE6E4FA);
  static const sun500 = Color(0xFFF5B431);
  static const sun300 = Color(0xFFFFD479);
  static const sun100 = Color(0xFFFFF0CC);
  static const sun700 = Color(0xFFA8680F);
  static const teal700 = Color(0xFF17706C);
  static const teal500 = Color(0xFF2FA59C);
  static const teal200 = Color(0xFFB6E6DF);
  static const teal100 = Color(0xFFE2F5F1);
  static const rose700 = Color(0xFFA93556);
  static const retry = Color(0xFFF7A94B);
  static const retryFill = Color(0xFFFFEBD0);
  static const retryText = Color(0xFF8A4B05);
  static const paper = Color(0xFFFFF8EA);
  static const sand = Color(0xFFF7E9CF);
  static const sand2 = Color(0xFFEBD5A8);
  static const ink = Color(0xFF26214F);
  static const ink2 = Color(0xFF5A5482);

  static const heading = 'ReemKufi';
  static const body = 'IBMPlexSansArabic';
  static const quran = 'AmiriQuran';
}

/// The 8-point star (two squares) that repeats through the design.
class KhatamBadge extends StatelessWidget {
  const KhatamBadge({super.key, required this.size, required this.color, this.child});

  final double size;
  final Color color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _KhatamPainter(color), child: Center(child: child)),
  );
}

class _KhatamPainter extends CustomPainter {
  _KhatamPainter(this.color) : _paint = Paint()..color = color;

  final Color color;
  final Paint _paint;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.765; // where the two squares cross
    final path = Path();
    for (var k = 0; k < 16; k++) {
      final r = k.isEven ? outer : inner;
      final a = -math.pi / 2 + k * math.pi / 8;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), _paint);
  }

  @override
  bool shouldRepaint(_KhatamPainter old) => old.color != color;
}

/// A page of the kids world: star chip, title, home button, then [child].
class KidsFaithScaffold extends ConsumerWidget {
  const KidsFaithScaffold({super.key, required this.title, required this.child, this.background, this.dark = false});

  final String title;
  final Widget child;
  final Decoration? background;

  /// Light text on a dark background.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final stars = ref.watch(kidsStarCountProvider);
    return Scaffold(
      backgroundColor: KP.paper,
      body: DecoratedBox(
        decoration: background ?? const BoxDecoration(color: KP.paper),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(color: dark ? Colors.white12 : KP.night800, borderRadius: BorderRadius.circular(32)),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(fmt.formatInt(stars), style: const TextStyle(color: Colors.white, fontFamily: KP.heading, fontSize: 22)),
                            const SizedBox(width: 6),
                            const KhatamBadge(size: 24, color: KP.sun500),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: KP.heading, fontSize: 28, color: dark ? Colors.white : KP.night900),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: l.kidsFaithHome,
                      child: Material(
                        color: KP.paper,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).maybePop(),
                          child: const SizedBox(width: 56, height: 56, child: Icon(Icons.home_rounded, color: KP.night800, size: 30)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// The calm «قريبًا» shown whenever nothing is approved (or the gate is shut).
class KidsSoonState extends StatelessWidget {
  const KidsSoonState({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KhatamBadge(size: 88, color: KP.sun300),
            const SizedBox(height: 20),
            Text(
              l.kidsFaithSoonTitle,
              style: TextStyle(fontFamily: KP.heading, fontSize: 34, color: dark ? Colors.white : KP.night900),
            ),
            const SizedBox(height: 8),
            Text(
              l.kidsFaithSoonBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: KP.body, fontSize: 20, height: 1.6, color: dark ? KP.night100 : KP.ink2),
            ),
          ],
        ),
      ),
    );
  }
}

enum KidsButtonTone { gold, teal, soft }

/// A big, forgiving button (>= 64 dp tall).
class KidsBigButton extends StatelessWidget {
  const KidsBigButton({super.key, required this.label, required this.onPressed, this.icon, this.tone = KidsButtonTone.gold});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final KidsButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      KidsButtonTone.gold => (KP.sun500, KP.night900),
      KidsButtonTone.teal => (KP.teal500, Colors.white),
      KidsButtonTone.soft => (KP.teal100, KP.teal700),
    };
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.45 : 1,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(36),
          child: InkWell(
            borderRadius: BorderRadius.circular(36),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64, minWidth: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, color: fg, size: 28), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontFamily: KP.heading, fontSize: 24, color: fg)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round icon button (64 dp).
class KidsRoundButton extends StatelessWidget {
  const KidsRoundButton({super.key, required this.icon, required this.label, required this.onPressed, this.color = KP.teal100, this.iconColor = KP.teal700});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    excludeSemantics: true,
    child: Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 64, height: 64, child: Icon(icon, color: iconColor, size: 32)),
        ),
      ),
    ),
  );
}

/// Two big tabs (wudu / prayer, morning / evening).
class KidsTabs extends StatelessWidget {
  const KidsTabs({super.key, required this.labels, required this.selected, required this.onSelected, required this.activeColor, this.activeText = Colors.white});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final Color activeColor;
  final Color activeText;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: DecoratedBox(
      decoration: BoxDecoration(color: KP.teal100, borderRadius: BorderRadius.circular(40)),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: i == selected,
                  label: labels[i],
                  excludeSemantics: true,
                  child: Material(
                    color: i == selected ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(34),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(34),
                      onTap: () => onSelected(i),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Center(
                          child: Text(
                            labels[i],
                            style: TextStyle(fontFamily: KP.heading, fontSize: 24, color: i == selected ? activeText : KP.teal700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Page dots (the current one is a gold pill).
class KidsDots extends StatelessWidget {
  const KidsDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 6,
    children: [
      for (var i = 0; i < count; i++)
        Container(
          width: i == index ? 36 : 14,
          height: 14,
          decoration: BoxDecoration(color: i == index ? KP.sun500 : KP.sand2, borderRadius: BorderRadius.circular(8)),
        ),
    ],
  );
}

/// Previous / next over a list of pages. The page content comes from
/// [pageBuilder]; the dots and the buttons are chrome.
class KidsPager extends StatefulWidget {
  const KidsPager({super.key, required this.count, required this.pageBuilder, this.nextLabel, this.onIndexChanged});

  final int count;
  final Widget Function(BuildContext context, int index) pageBuilder;

  /// Defaults to «التالي».
  final String? nextLabel;
  final ValueChanged<int>? onIndexChanged;

  @override
  State<KidsPager> createState() => _KidsPagerState();
}

class _KidsPagerState extends State<KidsPager> {
  int _i = 0;

  void _go(int to) {
    setState(() => _i = to);
    widget.onIndexChanged?.call(to);
  }

  @override
  void didUpdateWidget(KidsPager old) {
    super.didUpdateWidget(old);
    if (_i >= widget.count && widget.count > 0) _i = widget.count - 1;
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final last = _i >= widget.count - 1;
    return Column(
      children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16), child: widget.pageBuilder(context, _i))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: KidsDots(count: widget.count, index: _i)),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
          child: Row(
            children: [
              KidsRoundButton(
                icon: rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                label: l.kidsFaithPrevious,
                onPressed: _i == 0 ? null : () => _go(_i - 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KidsBigButton(
                  label: widget.nextLabel ?? l.kidsFaithNext,
                  icon: rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  onPressed: last ? null : () => _go(_i + 1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
