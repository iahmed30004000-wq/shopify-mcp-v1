// «أضيف صورة من جوالي»: the parent adds a picture (design 08a).
//
// Behind the parent gate: [askParent] runs first, and nothing else happens
// (no picker, no file read) unless it says yes. The picture is then checked,
// downscaled, optionally turned into an outline, and copied into Madar's own
// folder. Every problem is a soft message, never a crash, never "wrong".
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../learn/ui/kids_tokens.dart';
import '../../learn/ui/kids_widgets.dart';
import '../data/colouring_store.dart';
import '../data/image_import.dart';
import '../domain/flood_fill.dart';
import '../domain/outline.dart';
import 'art_image.dart';

/// The result of the parent's pick: a checked picture, or a reason.
class ImportOutcome {
  const ImportOutcome.picked(ImportCandidate this.candidate) : error = null;
  const ImportOutcome.failed(ImportError this.error) : candidate = null;
  const ImportOutcome.cancelled() : candidate = null, error = null;

  final ImportCandidate? candidate;
  final ImportError? error;
}

/// Gate, pick, check. Used by the import card; separate so it can be tested
/// without any widget.
Future<ImportOutcome> pickForColouring({
  required Future<bool> Function() askParent,
  required ColouringImagePicker picker,
  required ImageImporter importer,
}) async {
  if (!await askParent()) return const ImportOutcome.cancelled();
  final PickedImage? picked;
  try {
    picked = await picker.pick();
  } catch (_) {
    return const ImportOutcome.failed(ImportError.unreadable);
  }
  if (picked == null) return const ImportOutcome.cancelled();
  try {
    return ImportOutcome.picked(await importer.inspect(picked));
  } on ImportFailure catch (e) {
    return ImportOutcome.failed(e.error);
  }
}

String importErrorText(L10n l, ImportError e) => switch (e) {
  ImportError.notImage => l.kidsColNotImage,
  ImportError.tooBig => l.kidsColTooBig,
  ImportError.unreadable => l.kidsColCantRead,
};

/// The card at the top of the gallery.
class ImportCard extends StatelessWidget {
  const ImportCard({super.key, required this.onPick, this.busy = false});

  final VoidCallback onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return CustomPaint(
      painter: const _DashedBorder(color: KidsColors.rose500),
      child: Container(
        margin: const EdgeInsets.all(3),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: KidsColors.sun100.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ParentTag(text: l.kidsColParentOnly),
            ),
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: KidsColors.rose100, shape: BoxShape.circle),
              child: const Icon(Icons.image_outlined, color: KidsColors.rose700, size: 38),
            ),
            const SizedBox(height: 10),
            Text(l.kidsColAddTitle, textAlign: TextAlign.center, style: KidsType.title(26)),
            const SizedBox(height: 4),
            Text(
              l.kidsColAddSub,
              textAlign: TextAlign.center,
              style: KidsType.bodyText(18, color: KidsColors.ink2),
            ),
            const SizedBox(height: 14),
            KidsButton(
              label: busy ? l.kidsColWorking : l.kidsColPickFile,
              icon: busy ? null : Icons.add_rounded,
              kind: KidsButtonKind.rose,
              onTap: busy ? null : onPick,
            ),
          ],
        ),
      ),
    );
  }
}

class ParentTag extends StatelessWidget {
  const ParentTag({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(color: KidsColors.night100, borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: KidsType.bodyText(16, color: KidsColors.night800, weight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.lock_rounded, size: 18, color: KidsColors.night800),
      ],
    ),
  );
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(34)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = color
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 18) {
        canvas.drawPath(m.extractPath(d, (d + 10).clamp(0, m.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}

/// After the pick: preview, "as it is" or "turn into lines", then save.
class PrepView extends StatefulWidget {
  const PrepView({super.key, required this.candidate, required this.onSave, required this.onCancel});

  final ImportCandidate candidate;
  final Future<void> Function(LineArt art, PictureMode mode) onSave;
  final VoidCallback onCancel;

  @override
  State<PrepView> createState() => _PrepViewState();
}

class _PrepViewState extends State<PrepView> {
  late PictureMode _mode = widget.candidate.isPhoto ? PictureMode.outline : PictureMode.asIs;
  OutlineLevel _level = OutlineLevel.some;
  LineArt? _art;
  ui.Image? _preview;
  bool _busy = true;
  bool _saving = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<void> _compute() async {
    final token = ++_token;
    setState(() => _busy = true);
    LineArt art;
    try {
      art = _mode == PictureMode.asIs ? widget.candidate.asIs() : await widget.candidate.outline(_level);
    } catch (_) {
      art = widget.candidate.asIs();
    }
    final image = await imageFromArt(art, maxSide: 640);
    if (!mounted || token != _token) {
      image.dispose();
      return;
    }
    final old = _preview;
    setState(() {
      _art = art;
      _preview = image;
      _busy = false;
    });
    old?.dispose();
  }

  @override
  void dispose() {
    _token++;
    _preview?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final art = _art;
    if (art == null || _saving) return;
    setState(() => _saving = true);
    await widget.onSave(art, _mode);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final aspect = widget.candidate.art.width / widget.candidate.art.height;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.kidsColPrepTitle, style: KidsType.title(26)),
          const SizedBox(height: 4),
          Text(
            widget.candidate.isPhoto ? l.kidsColPrepPhotoHint : l.kidsColPrepLinesHint,
            style: KidsType.bodyText(18, color: KidsColors.ink2),
          ),
          const SizedBox(height: 12),
          KidsCard(
            color: Colors.white,
            padding: const EdgeInsets.all(10),
            child: AspectRatio(
              aspectRatio: aspect.clamp(0.5, 2.0),
              child: _preview == null || _busy
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: KidsColors.rose500),
                          const SizedBox(height: 10),
                          Text(
                            l.kidsColWorking,
                            textAlign: TextAlign.center,
                            style: KidsType.bodyText(16, color: KidsColors.ink2),
                          ),
                        ],
                      ),
                    )
                  : CustomPaint(painter: _PreviewPainter(_preview!)),
            ),
          ),
          const SizedBox(height: 14),
          KidsTabs(
            labels: [l.kidsColPrepAsIs, l.kidsColPrepOutline],
            selected: _mode == PictureMode.asIs ? 0 : 1,
            onSelect: (i) {
              final mode = i == 0 ? PictureMode.asIs : PictureMode.outline;
              if (mode == _mode) return;
              _mode = mode;
              _compute();
            },
          ),
          if (_mode == PictureMode.outline) ...[
            const SizedBox(height: 12),
            KidsTabs(
              labels: [l.kidsColLevelLow, l.kidsColLevelMid, l.kidsColLevelHigh],
              selected: _level.index,
              onSelect: (i) {
                if (OutlineLevel.values[i] == _level) return;
                _level = OutlineLevel.values[i];
                _compute();
              },
            ),
          ],
          const SizedBox(height: 18),
          KidsButton(
            label: l.kidsColSavePicture,
            icon: Icons.check_rounded,
            kind: KidsButtonKind.teal,
            onTap: (_busy || _saving) ? null : _save,
          ),
          const SizedBox(height: 12),
          KidsButton(label: l.kidsColCancel, kind: KidsButtonKind.paper, onTap: _saving ? null : widget.onCancel),
        ],
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.image != image;
}
