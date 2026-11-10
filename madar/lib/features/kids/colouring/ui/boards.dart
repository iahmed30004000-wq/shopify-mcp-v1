// The two boards: a built-in geometric page and one of his own pictures.
// Both save after every change (so a dying battery loses at most one tap) and
// both undo by replaying the list of fills.
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/design/islamic_geometry/islamic_geometry.dart' show Vec2;
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../learn/ui/kids_tokens.dart';
import '../../learn/ui/kids_widgets.dart';
import '../data/colouring_store.dart';
import '../domain/flood_fill.dart';
import '../domain/vector_colouring.dart';
import '../domain/vector_pages.dart';
import 'art_image.dart';
import 'controls.dart';
import 'palette.dart';
import 'surfaces.dart';

/// A built-in page being coloured.
class VectorBoard extends ConsumerStatefulWidget {
  const VectorBoard({super.key, required this.page, required this.store, required this.onDone});

  final VectorPage page;
  final ColouringStore store;
  final VoidCallback onDone;

  @override
  ConsumerState<VectorBoard> createState() => _VectorBoardState();
}

class _VectorBoardState extends ConsumerState<VectorBoard> {
  VectorColouring? _model;
  int _selected = 0;
  bool _eraser = false;
  Future<void> _saving = Future.value();

  @override
  void initState() {
    super.initState();
    widget.store.loadPageOps(widget.page.id).then((ops) {
      if (mounted) setState(() => _model = VectorColouring(widget.page, ops));
    });
  }

  void _persist() {
    final ops = _model!.ops;
    _saving = _saving.then((_) => widget.store.savePageOps(widget.page.id, ops)).catchError((Object _) {});
  }

  void _tap(Offset local, Size size) {
    final m = _model;
    if (m == null) return;
    final region = widget.page.regionAt(Vec2(local.dx / size.width, local.dy / size.height));
    if (region == null) return;
    final argb = _eraser ? 0 : argbOf(kColouringColours[_selected]);
    if (m.fill(region, argb)) {
      setState(() {});
      _persist();
    }
  }

  void _act(bool Function(VectorColouring m) change) {
    final m = _model;
    if (m == null) return;
    if (change(m)) {
      setState(() {});
      _persist();
    }
  }

  Future<void> _done() async {
    await _saving;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final m = _model;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: KidsCard(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: AspectRatio(
                aspectRatio: 1,
                child: m == null
                    ? const SizedBox.shrink()
                    : LayoutBuilder(
                        builder: (context, box) => GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _tap(d.localPosition, box.biggest),
                          child: RepaintBoundary(
                            child: CustomPaint(size: box.biggest, painter: VectorPagePainter(widget.page, m.colours)),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ColouringControls(
            selected: _selected,
            eraser: _eraser,
            canUndo: m?.canUndo ?? false,
            onSelect: (i) => setState(() {
              _selected = i;
              _eraser = false;
            }),
            onEraser: () => setState(() => _eraser = !_eraser),
            onUndo: () => _act((m) => m.undo()),
            onClear: () => _act((m) {
              if (!m.canUndo) return false;
              m.clear();
              return true;
            }),
            onDone: _done,
          ),
        ],
      ),
    );
  }
}

/// One of his own pictures being coloured.
class PictureBoard extends ConsumerStatefulWidget {
  const PictureBoard({super.key, required this.record, required this.store, required this.onDone});

  final PictureRecord record;
  final ColouringStore store;
  final VoidCallback onDone;

  @override
  ConsumerState<PictureBoard> createState() => _PictureBoardState();
}

class _PictureBoardState extends ConsumerState<PictureBoard> {
  ColourCanvas? _canvas;
  ui.Image? _image;
  bool _missing = false;
  int _selected = 0;
  bool _eraser = false;
  Future<void> _saving = Future.value();
  int _renderToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final art = await widget.store.loadArt(widget.record.id);
    if (!mounted) return;
    if (art == null) {
      setState(() => _missing = true);
      return;
    }
    final canvas = ColourCanvas(art)..replay(widget.record.ops);
    _canvas = canvas;
    await _render();
  }

  Future<void> _render() async {
    final canvas = _canvas;
    if (canvas == null) return;
    final token = ++_renderToken;
    final image = await imageFromRgba(canvas.toRgba(), canvas.width, canvas.height);
    if (!mounted || token != _renderToken) {
      image.dispose();
      return;
    }
    final old = _image;
    setState(() => _image = image);
    old?.dispose();
  }

  void _persist() {
    final ops = _canvas!.ops;
    _saving = _saving.then((_) => widget.store.savePictureOps(widget.record.id, ops)).catchError((Object _) {});
  }

  void _tap(Offset local, Size size) {
    final c = _canvas;
    if (c == null) return;
    final x = (local.dx / size.width * c.width).floor();
    final y = (local.dy / size.height * c.height).floor();
    final argb = _eraser ? ColourCanvas.paper : argbOf(kColouringColours[_selected]);
    if (c.fill(x, y, argb) > 0) {
      _persist();
      unawaited(_render());
    }
  }

  void _change(void Function(ColourCanvas c) f) {
    final c = _canvas;
    if (c == null) return;
    f(c);
    _persist();
    unawaited(_render());
  }

  Future<void> _done() async {
    await _saving;
    widget.onDone();
  }

  @override
  void dispose() {
    _renderToken++;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final c = _canvas;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: KidsCard(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: _missing
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: SoftRetryBanner(text: l.kidsColCantRead),
                    )
                  : AspectRatio(
                      aspectRatio: c == null ? 1 : c.width / c.height,
                      child: _image == null
                          ? const Center(child: CircularProgressIndicator(color: KidsColors.rose500))
                          : LayoutBuilder(
                              builder: (context, box) => GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapUp: (d) => _tap(d.localPosition, box.biggest),
                                child: RepaintBoundary(
                                  child: CustomPaint(size: box.biggest, painter: PicturePainter(_image!)),
                                ),
                              ),
                            ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          ColouringControls(
            selected: _selected,
            eraser: _eraser,
            canUndo: c?.canUndo ?? false,
            onSelect: (i) => setState(() {
              _selected = i;
              _eraser = false;
            }),
            onEraser: () => setState(() => _eraser = !_eraser),
            onUndo: () => _change((c) => c.undo()),
            onClear: () => _change((c) => c.clear()),
            onDone: _done,
          ),
        ],
      ),
    );
  }
}
