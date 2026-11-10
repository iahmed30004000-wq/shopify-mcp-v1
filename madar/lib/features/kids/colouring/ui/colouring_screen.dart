// «التلوين» (design 08a, 08b): the gallery, the boards and the parent's import.
//
// Everything happens inside this widget (no routes): the system back button
// walks back to the gallery first.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';

import '../../learn/ui/kids_tokens.dart';
import '../../learn/ui/kids_widgets.dart';
import '../data/colouring_store.dart';
import '../data/image_import.dart';
import '../domain/vector_colouring.dart';
import '../domain/vector_pages.dart';
import 'art_image.dart';
import 'boards.dart';
import 'colouring_providers.dart';
import 'import_flow.dart';
import 'surfaces.dart';

enum _Stage { gallery, page, picture, prep }

class ColouringScreen extends ConsumerStatefulWidget {
  /// [askParent] is the parent gate (PIN or fingerprint). Left out, it comes
  /// from [colouringParentGateProvider], which refuses until the shell wires
  /// the real gate in.
  const ColouringScreen({super.key, this.askParent});

  final Future<bool> Function()? askParent;

  @override
  ConsumerState<ColouringScreen> createState() => _ColouringScreenState();
}

class _ColouringScreenState extends ConsumerState<ColouringScreen> {
  _Stage _stage = _Stage.gallery;
  VectorPage? _page;
  PictureRecord? _record;
  ImportCandidate? _candidate;
  ImportError? _problem;
  bool _busy = false;
  PictureRecord? _deleting;
  int _refresh = 0;

  Future<bool> _ask() {
    final ParentGate gate = widget.askParent ?? ref.read(colouringParentGateProvider);
    return gate();
  }

  void _toGallery() => setState(() {
    _stage = _Stage.gallery;
    _page = null;
    _record = null;
    _candidate = null;
    _refresh++;
  });

  Future<void> _import() async {
    setState(() {
      _problem = null;
      _deleting = null;
    });
    // The gate comes first and alone: no picker, no file, unless it says yes.
    final allowed = await _ask();
    if (!allowed || !mounted) return;
    setState(() => _busy = true);
    final outcome = await pickForColouring(
      askParent: () async => true,
      picker: ref.read(colouringPickerProvider),
      importer: ref.read(colouringImporterProvider),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (outcome.candidate != null) {
        _candidate = outcome.candidate;
        _stage = _Stage.prep;
      } else {
        _problem = outcome.error;
      }
    });
  }

  Future<void> _askDelete(PictureRecord r) async {
    if (!await _ask() || !mounted) return;
    setState(() => _deleting = r);
  }

  @override
  Widget build(BuildContext context) {
    final storeAsync = ref.watch(colouringStoreProvider);
    return PopScope(
      canPop: _stage == _Stage.gallery,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toGallery();
      },
      child: KidsBackdrop(
        top: KidsColors.rose100,
        child: storeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: KidsColors.rose500)),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SoftRetryBanner(text: L10n.of(context).kidsColCantRead),
            ),
          ),
          data: _body,
        ),
      ),
    );
  }

  Widget _body(ColouringStore store) {
    switch (_stage) {
      case _Stage.page:
        return _WithBack(
          onBack: _toGallery,
          child: VectorBoard(key: ValueKey(_page!.id), page: _page!, store: store, onDone: _toGallery),
        );
      case _Stage.picture:
        return _WithBack(
          onBack: _toGallery,
          child: PictureBoard(key: ValueKey(_record!.id), record: _record!, store: store, onDone: _toGallery),
        );
      case _Stage.prep:
        return _WithBack(
          onBack: _toGallery,
          child: PrepView(
            candidate: _candidate!,
            onCancel: _toGallery,
            onSave: (art, mode) async {
              try {
                await store.addPicture(_candidate!, art, mode);
              } catch (_) {
                if (mounted) setState(() => _problem = ImportError.unreadable);
              }
              if (mounted) _toGallery();
            },
          ),
        );
      case _Stage.gallery:
        return _Gallery(
          key: ValueKey(_refresh),
          store: store,
          problem: _problem,
          busy: _busy,
          deleting: _deleting,
          onImport: _import,
          onOpenPage: (p) => setState(() {
            _page = p;
            _stage = _Stage.page;
          }),
          onOpenPicture: (r) => setState(() {
            _record = r;
            _stage = _Stage.picture;
          }),
          onAskDelete: _askDelete,
          onConfirmDelete: (r) async {
            await store.deletePicture(r.id);
            if (mounted) {
              setState(() {
                _deleting = null;
                _refresh++;
              });
            }
          },
          onCancelDelete: () => setState(() => _deleting = null),
        );
    }
  }
}

/// A body with a back button row on top (the shell's home button leaves the
/// whole section; this one goes back to the gallery).
class _WithBack extends StatelessWidget {
  const _WithBack({required this.child, required this.onBack});
  final Widget child;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: KidsRoundButton(icon: Icons.arrow_forward_rounded, semanticLabel: l.kidsColBack, onTap: onBack),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({
    super.key,
    required this.store,
    required this.problem,
    required this.busy,
    required this.deleting,
    required this.onImport,
    required this.onOpenPage,
    required this.onOpenPicture,
    required this.onAskDelete,
    required this.onConfirmDelete,
    required this.onCancelDelete,
  });

  final ColouringStore store;
  final ImportError? problem;
  final bool busy;
  final PictureRecord? deleting;
  final VoidCallback onImport;
  final ValueChanged<VectorPage> onOpenPage;
  final ValueChanged<PictureRecord> onOpenPicture;
  final ValueChanged<PictureRecord> onAskDelete;
  final ValueChanged<PictureRecord> onConfirmDelete;
  final VoidCallback onCancelDelete;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  List<PictureRecord> _pictures = const [];
  final Map<String, Map<int, int>> _pageColours = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pictures = await widget.store.pictures();
    final colours = <String, Map<int, int>>{};
    for (final p in VectorPages.builtIn) {
      final ops = await widget.store.loadPageOps(p.id);
      if (ops.isNotEmpty) colours[p.id] = VectorColouring(p, ops).colours;
    }
    if (!mounted) return;
    setState(() {
      _pictures = pictures;
      _pageColours
        ..clear()
        ..addAll(colours);
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final f = MadarFormatter.of(context);
    final pages = VectorPages.builtIn;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ImportCard(onPick: widget.onImport, busy: widget.busy),
          if (widget.problem != null) ...[const SizedBox(height: 14), _Problem(error: widget.problem!)],
          if (widget.deleting != null) ...[
            const SizedBox(height: 14),
            _ConfirmDelete(onYes: () => widget.onConfirmDelete(widget.deleting!), onNo: widget.onCancelDelete),
          ],
          if (_loaded && _pictures.isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(l.kidsColMine, style: KidsType.title(28, color: KidsColors.rose700)),
            const SizedBox(height: 10),
            _Grid(
              children: [
                for (var i = 0; i < _pictures.length; i++)
                  _Tile(
                    label: l.kidsColPictureName(f.localizeDigits('${i + 1}')),
                    tag: l.kidsColMineTag,
                    done: _pictures[i].started,
                    onTap: () => widget.onOpenPicture(_pictures[i]),
                    onDelete: () => widget.onAskDelete(_pictures[i]),
                    deleteLabel: l.kidsColDelete,
                    child: _ArtThumb(store: widget.store, id: _pictures[i].id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Text(l.kidsColMadar, style: KidsType.title(28, color: KidsColors.rose700)),
          const SizedBox(height: 10),
          _Grid(
            children: [
              for (var i = 0; i < pages.length; i++)
                _Tile(
                  label: l.kidsColPatternName(f.localizeDigits('${i + 1}')),
                  done: (_pageColours[pages[i].id] ?? const {}).isNotEmpty,
                  onTap: () => widget.onOpenPage(pages[i]),
                  child: CustomPaint(
                    painter: VectorPagePainter(pages[i], _pageColours[pages[i].id] ?? const {}, lineWidth: 1.5),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const gap = 14.0;
      final w = (box.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final c in children) SizedBox(width: w, child: c)],
      );
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.child,
    required this.onTap,
    this.tag,
    this.done = false,
    this.onDelete,
    this.deleteLabel,
  });

  final String label;
  final Widget child;
  final VoidCallback onTap;
  final String? tag;
  final bool done;
  final VoidCallback? onDelete;
  final String? deleteLabel;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [BoxShadow(color: KidsColors.sand2, offset: Offset(0, 5))],
            ),
            child: AspectRatio(aspectRatio: 1, child: child),
          ),
        ),
      ),
      if (tag != null)
        PositionedDirectional(
          top: 10,
          end: 12,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: KidsColors.teal100, borderRadius: BorderRadius.circular(16)),
              child: Text(
                tag!,
                style: KidsType.bodyText(15, color: KidsColors.teal700, weight: FontWeight.w700),
              ),
            ),
          ),
        ),
      if (done)
        PositionedDirectional(
          bottom: 10,
          start: 10,
          child: IgnorePointer(
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: KidsColors.teal500, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      if (onDelete != null)
        PositionedDirectional(
          bottom: 4,
          end: 4,
          child: Semantics(
            button: true,
            label: deleteLabel,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDelete,
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Center(child: Icon(Icons.delete_outline_rounded, color: KidsColors.ink2, size: 26)),
              ),
            ),
          ),
        ),
    ],
  );
}

class _ArtThumb extends StatefulWidget {
  const _ArtThumb({required this.store, required this.id});
  final ColouringStore store;
  final String id;

  @override
  State<_ArtThumb> createState() => _ArtThumbState();
}

class _ArtThumbState extends State<_ArtThumb> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    () async {
      final art = await widget.store.loadArt(widget.id);
      if (art == null) return;
      final img = await imageFromArt(art, maxSide: 256);
      if (!mounted) {
        img.dispose();
        return;
      }
      setState(() => _image = img);
    }();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _image == null ? const SizedBox.shrink() : CustomPaint(painter: PicturePainter(_image!));
}

class _Problem extends StatelessWidget {
  const _Problem({required this.error});
  final ImportError error;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KidsColors.retryFill,
        border: Border.all(color: KidsColors.retry, width: 2),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(
            l.kidsColBadFile,
            textAlign: TextAlign.center,
            style: KidsType.title(22, color: KidsColors.retryText),
          ),
          const SizedBox(height: 4),
          Text(
            importErrorText(l, error),
            textAlign: TextAlign.center,
            style: KidsType.bodyText(18, color: KidsColors.retryText),
          ),
        ],
      ),
    );
  }
}

class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({required this.onYes, required this.onNo});
  final VoidCallback onYes, onNo;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return KidsCard(
      color: KidsColors.sun100,
      child: Column(
        children: [
          Text(l.kidsColDeleteAsk, textAlign: TextAlign.center, style: KidsType.title(22)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: KidsButton(label: l.kidsColDeleteYes, kind: KidsButtonKind.rose, onTap: onYes),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KidsButton(label: l.kidsColCancel, kind: KidsButtonKind.paper, onTap: onNo),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
