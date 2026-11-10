import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../rewards/presentation/play_kit.dart';
import '../domain/voice_story.dart';

/// Cover colours of a story, picked by the parent. White text reads on all.
const List<Color> voiceCoverColors = [
  KidsColors.night800,
  KidsColors.teal700,
  KidsColors.rose700,
  KidsColors.night500,
  Color(0xFF7A4A0A),
  KidsColors.night700,
];

Color voiceCover(int index) => voiceCoverColors[index % voiceCoverColors.length];

/// The ring of bars around the story's medallion. Bars before [progress] are
/// gold, the rest lavender; while playing they breathe a little (driven by
/// [breath], a repeating 0..1 animation; null for a still ring, as with
/// reduced motion).
///
/// Nothing is allocated while painting: the unit vectors of the bars are
/// worked out once per size and the paints are reused.
class RingWaveformPainter extends CustomPainter {
  RingWaveformPainter({required this.bars, required this.progress, this.breath}) : super(repaint: breath);

  /// Bar heights, 0..1 (see [pseudoWaveform]).
  final List<double> bars;

  /// 0..1: how much of the story has played.
  final double progress;

  final Animation<double>? breath;

  final Paint _played = Paint()
    ..color = KidsColors.sun500
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;
  final Paint _rest = Paint()
    ..color = KidsColors.night300
    ..strokeWidth = 5
    ..strokeCap = StrokeCap.round;

  Float32List? _unit; // cos, sin per bar
  int _unitFor = 0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    if (n == 0 || size.isEmpty) return;
    if (_unit == null || _unitFor != n) {
      final u = Float32List(n * 2);
      for (var i = 0; i < n; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / n;
        u[i * 2] = math.cos(a);
        u[i * 2 + 1] = math.sin(a);
      }
      _unit = u;
      _unitFor = n;
    }
    final u = _unit!;
    final c = size.center(Offset.zero);
    final outer = size.shortestSide / 2 - 3;
    final inner = outer * 0.74;
    final phase = (breath?.value ?? 0) * 2 * math.pi;
    final lit = (progress * n).floor();
    for (var i = 0; i < n; i++) {
      final wobble = breath == null ? 1.0 : 1 + 0.08 * math.sin(phase + i * 0.5);
      final len = (inner + (outer - inner) * bars[i] * wobble).clamp(inner, outer + 4);
      final dx = u[i * 2], dy = u[i * 2 + 1];
      canvas.drawLine(
        Offset(c.dx + dx * inner, c.dy + dy * inner),
        Offset(c.dx + dx * len, c.dy + dy * len),
        i < lit ? _played : _rest,
      );
    }
  }

  @override
  bool shouldRepaint(RingWaveformPainter old) =>
      old.progress != progress || !identical(old.bars, bars) || old.breath != breath;
}

/// Vertical bars in a row (the parent corner). [played] bars are coloured;
/// the rest are dim.
class BarsPainter extends CustomPainter {
  BarsPainter({required this.bars, required this.progress, required this.color, required this.dim, this.rtl = false});

  final List<double> bars;
  final double progress;
  final Color color, dim;

  /// Right to left: the first bar is on the right.
  final bool rtl;

  final Paint _p = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final n = bars.length;
    if (n == 0 || size.isEmpty) return;
    final step = size.width / n;
    _p.strokeWidth = math.max(3, step * 0.5);
    final lit = (progress * n).floor();
    for (var i = 0; i < n; i++) {
      final x = rtl ? size.width - step * (i + 0.5) : step * (i + 0.5);
      final h = size.height * (0.15 + 0.85 * bars[i].clamp(0.0, 1.0));
      _p.color = i < lit ? color : dim;
      canvas.drawLine(Offset(x, (size.height - h) / 2), Offset(x, (size.height + h) / 2), _p);
    }
  }

  @override
  bool shouldRepaint(BarsPainter old) =>
      old.progress != progress || !identical(old.bars, bars) || old.color != color || old.dim != dim || old.rtl != rtl;
}

/// The words for how long a story is («٣ دقايق»).
String voiceMinutes(BuildContext context, Duration d) {
  final m = math.max(1, (d.inSeconds / 60).round());
  return L10n.of(context).kidsPlayMinutes(m, kidsNumber(context, m));
}

/// What the parent typed in the story dialog.
class VoiceStoryDraft {
  const VoiceStoryDraft({required this.title, required this.narrator, required this.colorIndex});
  final String title;
  final String narrator;
  final int colorIndex;
}

/// «حكاية جديدة» / «تعديل»: the title, who is speaking and the cover colour,
/// all typed or chosen by the parent.
Future<VoiceStoryDraft?> showVoiceStoryDialog(BuildContext context, {VoiceStory? existing}) {
  return showDialog<VoiceStoryDraft>(
    context: context,
    builder: (_) => _VoiceStoryDialog(existing: existing),
  );
}

class _VoiceStoryDialog extends StatefulWidget {
  const _VoiceStoryDialog({this.existing});
  final VoiceStory? existing;

  @override
  State<_VoiceStoryDialog> createState() => _VoiceStoryDialogState();
}

class _VoiceStoryDialogState extends State<_VoiceStoryDialog> {
  late final TextEditingController _title = TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _narrator = TextEditingController(text: widget.existing?.narrator ?? '');
  late int _color = widget.existing?.colorIndex ?? 0;

  @override
  void dispose() {
    _title.dispose();
    _narrator.dispose();
    super.dispose();
  }

  bool get _valid => VoiceStory.cleanTitle(_title.text).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    InputDecoration deco(String label, String? hint) => InputDecoration(
      labelText: label,
      hintText: hint,
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    );
    return Dialog(
      backgroundColor: KidsColors.paper,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? l.kidsPlayNewStoryTitle : l.kidsPlayEditStoryTitle, style: KidsText.title),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: VoiceStory.maxTitleLength,
              textInputAction: TextInputAction.next,
              style: KidsText.body,
              decoration: deco(l.kidsPlayStoryNameLabel, l.kidsPlayStoryNameHint),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _narrator,
              maxLength: VoiceStory.maxNarratorLength,
              style: KidsText.body,
              decoration: deco(l.kidsPlayNarratorLabel, l.kidsPlayNarratorHint),
            ),
            const SizedBox(height: 16),
            Text(l.kidsPlayCoverLabel, style: KidsText.small),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < voiceCoverColors.length; i++)
                  Semantics(
                    button: true,
                    selected: i == _color,
                    label: l.kidsPlayCoverColour(kidsNumber(context, i + 1)),
                    excludeSemantics: true,
                    child: InkResponse(
                      onTap: () => setState(() => _color = i),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: voiceCoverColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(color: i == _color ? KidsColors.sun500 : Colors.transparent, width: 4),
                        ),
                        child: i == _color ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: BigPlayButton(
                    label: l.kidsPlaySave,
                    background: KidsColors.teal700,
                    foreground: Colors.white,
                    onPressed: _valid
                        ? () => Navigator.of(context).pop(
                            VoiceStoryDraft(
                              title: VoiceStory.cleanTitle(_title.text),
                              narrator: VoiceStory.cleanNarrator(_narrator.text),
                              colorIndex: _color,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BigPlayButton(
                    label: l.kidsPlayCancel,
                    background: KidsColors.sand,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before a story is deleted. True when the parent said yes.
Future<bool> confirmDeleteStory(BuildContext context, String title) async {
  final l = L10n.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: KidsColors.paper,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.kidsPlayDeleteTitle(title), style: KidsText.title),
            const SizedBox(height: 8),
            Text(l.kidsPlayDeleteBody, style: KidsText.body),
            const SizedBox(height: 16),
            BigPlayButton(
              label: l.kidsPlayDelete,
              background: KidsColors.rose300,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 10),
            BigPlayButton(
              label: l.kidsPlayKeep,
              background: KidsColors.sand,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      ),
    ),
  );
  return ok ?? false;
}
