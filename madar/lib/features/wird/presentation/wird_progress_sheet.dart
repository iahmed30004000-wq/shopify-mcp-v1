import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/quran/ayah.dart';
import '../../../core/quran/quran_catalog.dart';
import '../../../core/sound/sound_api.dart';
import '../domain/quran_axis.dart';
import '../domain/wird_engine.dart';
import 'wird_labels.dart';

/// "Where did you stop?" – a slider over today's remaining portion; returns
/// the last ayah read (null when dismissed).
Future<AyahRef?> showWirdProgressSheet(
  BuildContext context, {
  required WirdPlanState state,
  required QuranCatalog catalog,
}) {
  final from = state.target.resumeAt;
  if (from == null) return Future.value();
  final index = QuranIndex(catalog);
  final a = index.indexOf(from);
  final remaining = state.target.remaining;
  final b = remaining == null ? math.min(index.total - 1, a + 20) : index.indexOf(remaining.last);
  return showInteractionSheet<AyahRef>(
    context,
    builder: (_) => _ProgressSheet(index: index, catalog: catalog, from: a, to: math.max(a, b)),
  );
}

class _ProgressSheet extends StatefulWidget {
  const _ProgressSheet({required this.index, required this.catalog, required this.from, required this.to});

  final QuranIndex index;
  final QuranCatalog catalog;
  final int from;
  final int to;

  @override
  State<_ProgressSheet> createState() => _ProgressSheetState();
}

class _ProgressSheetState extends State<_ProgressSheet> {
  late int _at = widget.from + ((widget.to - widget.from) ~/ 2);
  int _lastTick = -1;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = L10n.of(context);
    final text = Theme.of(context).textTheme;
    final texts = WirdTexts.of(context, widget.catalog);
    final ref = widget.index.refAt(_at);
    final span = widget.to - widget.from;
    return InteractionSheetFrame(
      title: l.wirdStoppedAtTitle,
      subtitle: l.wirdStoppedAtHint,
      icon: Icons.bookmark_added_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            texts.ayah(ref),
            textAlign: TextAlign.center,
            style: text.headlineSmall!.copyWith(color: t.accent),
          ),
          const SizedBox(height: Space.xs),
          Text(texts.pages(AyahRange.single(ref)), textAlign: TextAlign.center, style: text.bodySmall),
          const SizedBox(height: Space.m),
          SizedBox(
            height: 96,
            child: FutureBuilder<String>(
              key: ValueKey(ref),
              future: widget.catalog.ayahText(ref),
              builder: (context, snap) => Center(
                child: Text(
                  snap.data ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: MadarTypography.quran(t, size: 22).copyWith(height: 1.9),
                ),
              ),
            ),
          ),
          if (span > 0)
            Slider(
              value: _at.toDouble(),
              min: widget.from.toDouble(),
              max: widget.to.toDouble(),
              divisions: span,
              label: texts.number(ref.ayah),
              onChanged: (v) {
                final i = v.round();
                if (i != _lastTick) {
                  _lastTick = i;
                  Fx.fire(Sfx.countTick);
                }
                setState(() => _at = i);
              },
            ),
        ],
      ),
      footer: SheetButton(
        label: l.wirdSaveProgress,
        primary: true,
        icon: Icons.check_rounded,
        sfx: Sfx.complete,
        onPressed: () => Navigator.of(context).pop(ref),
      ),
    );
  }
}
