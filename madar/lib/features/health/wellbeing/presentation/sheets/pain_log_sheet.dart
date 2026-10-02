import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/db/database.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/widgets/widgets.dart';
import '../../../../../core/domain/enums.dart';
import '../../../../../core/i18n/gen/app_localizations.dart';
import '../../../../../core/interaction/interaction.dart';
import '../../../../../core/sound/sound_api.dart';
import '../../data/wellbeing_providers.dart';
import '../../domain/body_map.dart';
import '../../domain/wellbeing_drafts.dart';
import '../wellbeing_texts.dart';
import '../widgets/body_map.dart';
import '../widgets/scale_inputs.dart';
import '../widgets/wb_palette.dart';
import '../widgets/wb_widgets.dart';
import 'tag_manager_sheet.dart';

/// Opens the pain log (new, or editing [entry]). Completes true when saved.
Future<bool> showPainLogSheet(BuildContext context, {PainEntryRow? entry, int? initialScore}) async {
  final saved = await showInteractionSheet<bool>(
    context,
    builder: (_) => PainLogSheet(entry: entry, initialScore: initialScore),
  );
  return saved ?? false;
}

/// The full pain log: score on a calm 0–10 scale, time (now by default),
/// body map front/back, locations, triggers and notes.
class PainLogSheet extends ConsumerStatefulWidget {
  const PainLogSheet({super.key, this.entry, this.initialScore});

  final PainEntryRow? entry;
  final int? initialScore;

  @override
  ConsumerState<PainLogSheet> createState() => _PainLogSheetState();
}

class _PainLogSheetState extends ConsumerState<PainLogSheet> {
  late PainDraft _draft;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final now = ref.read(wellbeingClockProvider)();
    _draft = e == null
        ? PainDraft(at: now, score: widget.initialScore ?? 3)
        : PainDraft(
            at: e.at,
            score: e.score,
            locations: e.locations,
            triggers: e.triggers,
            points: BodyPoint.listFrom(e.bodyPoints),
            notes: e.notes,
          );
    _notes = TextEditingController(text: _draft.notes ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _suggestRegion(BodyRegion region) {
    final name = WbTexts.of(context).region(region);
    final options = ref.read(wellbeingTagsProvider(TagKind.painLocation)).value ?? const <TagOptionRow>[];
    if (!options.any((o) => o.label == name) || _draft.locations.contains(name)) return;
    setState(() => _draft = _draft.copyWith(locations: [..._draft.locations, name]));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final service = ref.read(wellbeingServiceProvider);
    final draft = _draft.copyWith(notes: _notes.text);
    final e = widget.entry;
    if (e == null) {
      await service.logPain(draft);
    } else {
      await service.updatePain(e.id, draft);
    }
    Fx.fire(Sfx.complete);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final tx = WbTexts.of(context);
    final now = ref.watch(wellbeingClockProvider)();
    final color = WbPalette.pain(t, _draft.score);
    return InteractionSheetFrame(
      title: widget.entry == null ? l.wbPainLogTitle : l.wbPainEditTitle,
      subtitle: l.wbPainLogSubtitle,
      icon: Icons.healing_rounded,
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(label: l.wbCancel, onPressed: () => Navigator.of(context).maybePop()),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            flex: 2,
            child: SheetButton(
              label: l.wbSave,
              primary: true,
              icon: Icons.check_rounded,
              sfx: null,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PainScoreSlider(
            value: _draft.score,
            label: l.wbPainScore,
            caption: tx.painWord(_draft.score),
            onChanged: (v) => setState(() => _draft = _draft.copyWith(score: v)),
          ),
          const SizedBox(height: Space.m),
          WbWhenField(
            value: _draft.at,
            now: now,
            onChanged: (v) => setState(() => _draft = _draft.copyWith(at: v)),
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          Row(
            children: [
              Icon(Icons.accessibility_new_rounded, size: 18, color: t.gold),
              const SizedBox(width: Space.s),
              Expanded(child: Text(l.wbBodyMap, style: Theme.of(context).textTheme.titleSmall)),
              if (_draft.points.isNotEmpty)
                MadarButton(
                  label: l.wbClearPoints,
                  icon: Icons.layers_clear_rounded,
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  sfx: Sfx.delete,
                  onPressed: () => setState(() => _draft = _draft.copyWith(points: const [])),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          WbHint(l.wbBodyMapHint, icon: Icons.touch_app_outlined),
          const SizedBox(height: Space.s),
          BodyMapView(
            points: _draft.points,
            pointColor: color,
            height: 290,
            frontLabel: l.wbFront,
            backLabel: l.wbBack,
            semanticLabel: l.wbBodyMapSemantics(_draft.points.length),
            onChanged: (pts) =>
                setState(() => _draft = _draft.copyWith(points: pts.take(PainDraft.maxPoints).toList())),
            onRegionTapped: _suggestRegion,
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          WbTagPicker(
            kind: TagKind.painLocation,
            label: l.wbLocations,
            icon: Icons.place_outlined,
            selected: _draft.locations,
            onChanged: (v) => setState(() => _draft = _draft.copyWith(locations: v)),
            onManage: () => showTagManagerSheet(context, TagKind.painLocation),
          ),
          const SizedBox(height: Space.l),
          WbTagPicker(
            kind: TagKind.painTrigger,
            label: l.wbTriggers,
            icon: Icons.bolt_outlined,
            selected: _draft.triggers,
            onChanged: (v) => setState(() => _draft = _draft.copyWith(triggers: v)),
            onManage: () => showTagManagerSheet(context, TagKind.painTrigger),
          ),
          const SizedBox(height: Space.l),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.wbNotes, hintText: l.wbPainNotesHint),
          ),
        ],
      ),
    );
  }
}
