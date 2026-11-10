// «الأذكار» (design 13): morning / evening tabs, the dhikr, and a bead counter
// that fills as the child taps. The text and the count come from approved
// [KidsReligiousItem]s (kind dhikr, `repeat`); none approved => «قريبًا».
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../application/faith_providers.dart';
import '../domain/kids_religious_item.dart';
import 'widgets/approved_gate.dart';
import 'widgets/kids_faith_ui.dart';

class KidsAdhkarScreen extends StatefulWidget {
  const KidsAdhkarScreen({super.key});

  @override
  State<KidsAdhkarScreen> createState() => _KidsAdhkarScreenState();
}

class _KidsAdhkarScreenState extends State<KidsAdhkarScreen> {
  int? _tab;
  final Map<String, int> _counts = {};

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return KidsFaithScaffold(
      title: l.kidsFaithAdhkarTitle,
      background: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [KP.teal100, KP.paper]),
      ),
      child: KidsApprovedItems(
        kinds: const {KidsReligiousKind.dhikr},
        builder: (context, items) {
          final all = kidsItemsOfKind(items, KidsReligiousKind.dhikr);
          final morning = [for (final i in all) if (i.group == KidsDhikrGroup.morning) i];
          final evening = [for (final i in all) if (i.group == KidsDhikrGroup.evening) i];
          final tab = _tab ?? (morning.isNotEmpty ? 0 : 1);
          final list = tab == 0 ? morning : evening;
          return Column(
            children: [
              KidsTabs(
                labels: [l.kidsFaithMorning, l.kidsFaithEvening],
                selected: tab,
                onSelected: (i) => setState(() => _tab = i),
                activeColor: KP.sun500,
                activeText: KP.night900,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: list.isEmpty
                    ? const KidsSoonState()
                    : KidsPager(
                        key: ValueKey(tab),
                        count: list.length,
                        nextLabel: l.kidsFaithNextDhikr,
                        pageBuilder: (context, i) {
                          final d = list[i];
                          final total = d.repeat ?? 1;
                          final count = _counts[d.id] ?? 0;
                          return _DhikrPage(
                            dhikr: d,
                            count: count,
                            total: total,
                            onTap: () => setState(() => _counts[d.id] = math.min(total, count + 1)),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DhikrPage extends StatelessWidget {
  const _DhikrPage({required this.dhikr, required this.count, required this.total, required this.onTap});

  final KidsReligiousItem dhikr;
  final int count;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final fmt = MadarFormatter.of(context);
    final done = count >= total;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(dhikr.arabicText, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Amiri', fontWeight: FontWeight.w700, fontSize: 26, height: 1.8, color: KP.ink)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        BeadCounter(count: count, total: total, onTap: done ? null : onTap, centerLabel: l.kidsFaithBeadsOfTotal(fmt.formatInt(total)), numberText: fmt.formatInt(count)),
        const SizedBox(height: 16),
        Text(
          done ? l.kidsFaithBeadsDone : l.kidsFaithTapCircle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: KP.body, fontWeight: FontWeight.w700, fontSize: 20, color: KP.teal700),
        ),
      ],
    );
  }
}

/// A ring of beads around a big number. Beads fill (gold) as [count] grows;
/// with more than [maxBeads] to say, each bead stands for several.
class BeadCounter extends StatelessWidget {
  const BeadCounter({super.key, required this.count, required this.total, required this.onTap, required this.centerLabel, required this.numberText, this.size = 280});

  static const int maxBeads = 40;

  final int count;
  final int total;
  final VoidCallback? onTap;
  final String centerLabel;
  final String numberText;
  final double size;

  /// How many beads are drawn, and how many of them are filled.
  static int beadsShown(int total) => math.min(math.max(total, 1), maxBeads);
  static int beadsFilled(int count, int total) => total <= 0 ? 0 : (count.clamp(0, total) * beadsShown(total) / total).floor();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$numberText $centerLabel',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _BeadPainter(beadsShown(total), beadsFilled(count, total)),
            child: Center(
              child: Container(
                width: size * 0.62,
                height: size * 0.62,
                decoration: const BoxDecoration(color: KP.teal700, shape: BoxShape.circle),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(numberText, style: const TextStyle(fontFamily: KP.heading, fontSize: 64, height: 1.1, color: Colors.white)),
                    Text(centerLabel, style: const TextStyle(fontFamily: KP.body, fontSize: 16, color: KP.sun300)),
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

class _BeadPainter extends CustomPainter {
  _BeadPainter(this.beads, this.filled);

  final int beads;
  final int filled;

  static final Paint _fill = Paint()..isAntiAlias = true;
  static final Paint _edge = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final ring = size.shortestSide / 2 - 16;
    final r = math.min(16.0, math.pi * ring / beads * 0.8);
    for (var i = 0; i < beads; i++) {
      // Clockwise from the top; in RTL the eye starts at the top too.
      final a = -math.pi / 2 + i * 2 * math.pi / beads;
      final p = Offset(c.dx + ring * math.cos(a), c.dy + ring * math.sin(a));
      final on = i < filled;
      canvas.drawCircle(p, r, _fill..color = on ? KP.sun500 : KP.teal200);
      canvas.drawCircle(p, r, _edge..color = on ? KP.sun700 : KP.teal500);
    }
  }

  @override
  bool shouldRepaint(_BeadPainter old) => old.beads != beads || old.filled != filled;
}
