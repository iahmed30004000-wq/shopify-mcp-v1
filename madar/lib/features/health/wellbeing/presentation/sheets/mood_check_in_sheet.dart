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
import '../../domain/wellbeing_data.dart';
import '../../domain/wellbeing_drafts.dart';
import '../wellbeing_texts.dart';
import '../widgets/mood_face.dart';
import '../widgets/scale_inputs.dart';
import '../widgets/wb_palette.dart';
import '../widgets/wb_widgets.dart';
import 'tag_manager_sheet.dart';

/// Opens the mood & stress check-in (new, or editing [entry]). Completes
/// true when saved.
Future<bool> showMoodCheckInSheet(BuildContext context, {MoodEntryRow? entry, int? initialMood}) async {
  final saved = await showInteractionSheet<bool>(
    context,
    builder: (_) => MoodCheckInSheet(entry: entry, initialMood: initialMood),
  );
  return saved ?? false;
}

/// The daily check-in on one screen: mood face, stress / anxiety / energy
/// beads, sleep hours, caffeine cups, factor tags and a note. Every part is
/// optional – a face alone is a check-in.
class MoodCheckInSheet extends ConsumerStatefulWidget {
  const MoodCheckInSheet({super.key, this.entry, this.initialMood});

  final MoodEntryRow? entry;
  final int? initialMood;

  @override
  ConsumerState<MoodCheckInSheet> createState() => _MoodCheckInSheetState();
}

class _MoodCheckInSheetState extends ConsumerState<MoodCheckInSheet> {
  late MoodDraft _d;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    final now = ref.read(wellbeingClockProvider)();
    _d = e == null
        ? MoodDraft(at: now, mood: widget.initialMood)
        : MoodDraft(
            at: e.at,
            mood: e.mood,
            stress: e.stress,
            anxiety: e.anxiety,
            energy: e.energy,
            sleepHours: e.sleepHours,
            caffeineCups: e.caffeineCups,
            factors: e.factors,
            notes: e.notes,
          );
    _notes = TextEditingController(text: _d.notes ?? '');
    _notes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  MoodDraft get _current => MoodDraft(
    at: _d.at,
    mood: _d.mood,
    stress: _d.stress,
    anxiety: _d.anxiety,
    energy: _d.energy,
    sleepHours: _d.sleepHours,
    caffeineCups: _d.caffeineCups,
    factors: _d.factors,
    notes: _notes.text,
  );

  void _set(MoodDraft Function(MoodDraft d) f) => setState(() => _d = f(_d));

  MoodDraft _with({
    Object? mood = _keep,
    Object? stress = _keep,
    Object? anxiety = _keep,
    Object? energy = _keep,
    Object? sleep = _keep,
    Object? cups = _keep,
    List<String>? factors,
    DateTime? at,
  }) => MoodDraft(
    at: at ?? _d.at,
    mood: mood == _keep ? _d.mood : mood as int?,
    stress: stress == _keep ? _d.stress : stress as int?,
    anxiety: anxiety == _keep ? _d.anxiety : anxiety as int?,
    energy: energy == _keep ? _d.energy : energy as int?,
    sleepHours: sleep == _keep ? _d.sleepHours : sleep as double?,
    caffeineCups: cups == _keep ? _d.caffeineCups : cups as int?,
    factors: factors ?? _d.factors,
    notes: _d.notes,
  );

  Future<void> _save() async {
    if (_saving) return;
    final draft = _current;
    if (draft.isEmpty) {
      Fx.fire(Sfx.error);
      return;
    }
    setState(() => _saving = true);
    final service = ref.read(wellbeingServiceProvider);
    final e = widget.entry;
    if (e == null) {
      await service.logMood(draft);
    } else {
      await service.updateMood(e.id, draft);
    }
    Fx.fire(Sfx.complete);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = WbTexts.of(context);
    final now = ref.watch(wellbeingClockProvider)();
    final empty = _current.isEmpty;
    return InteractionSheetFrame(
      title: widget.entry == null ? l.wbCheckInTitle : l.wbCheckInEditTitle,
      subtitle: l.wbCheckInSubtitle,
      icon: Icons.self_improvement_rounded,
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
              enabled: !empty && !_saving,
              onDisabledTap: () => Fx.fire(Sfx.error),
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.wbMoodQuestion, style: text.titleSmall),
          const SizedBox(height: Space.s),
          MoodFacePicker(
            value: _d.mood,
            labels: tx.moodLabels,
            size: 50,
            onChanged: (v) => _set((_) => _with(mood: v)),
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          ScaleBeads(
            label: l.wbMetricStress,
            icon: Icons.waves_rounded,
            color: WbPalette.metric(t, WellMetric.stress),
            value: _d.stress,
            lowHint: l.wbScaleCalm,
            highHint: l.wbScaleVeryHigh,
            onChanged: (v) => _set((_) => _with(stress: v)),
          ),
          const SizedBox(height: Space.l),
          ScaleBeads(
            label: l.wbMetricAnxiety,
            icon: Icons.cloud_outlined,
            color: WbPalette.metric(t, WellMetric.anxiety),
            value: _d.anxiety,
            lowHint: l.wbScaleNone,
            highHint: l.wbScaleVeryHigh,
            onChanged: (v) => _set((_) => _with(anxiety: v)),
          ),
          const SizedBox(height: Space.l),
          ScaleBeads(
            label: l.wbMetricEnergy,
            icon: Icons.bolt_rounded,
            color: WbPalette.metric(t, WellMetric.energy),
            value: _d.energy,
            lowHint: l.wbScaleDrained,
            highHint: l.wbScaleFull,
            onChanged: (v) => _set((_) => _with(energy: v)),
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          WbStepper(
            label: l.wbSleepHours,
            icon: Icons.bedtime_outlined,
            color: WbPalette.metric(t, WellMetric.sleep),
            value: _d.sleepHours,
            step: 0.5,
            min: 0,
            max: MoodDraft.maxSleep,
            start: 7,
            format: tx.hours,
            decreaseLabel: l.wbLess,
            increaseLabel: l.wbMore,
            onChanged: (v) => _set((_) => _with(sleep: v)),
          ),
          const SizedBox(height: Space.m),
          WbStepper(
            label: l.wbCaffeine,
            icon: Icons.coffee_outlined,
            color: WbPalette.metric(t, WellMetric.caffeine),
            value: _d.caffeineCups?.toDouble(),
            step: 1,
            min: 0,
            max: MoodDraft.maxCups.toDouble(),
            start: 0,
            format: (v) => tx.cups(v.round()),
            decreaseLabel: l.wbLess,
            increaseLabel: l.wbMore,
            onChanged: (v) => _set((_) => _with(cups: v?.round())),
          ),
          const MadarDivider(ornament: false, height: Space.xl),
          WbTagPicker(
            kind: TagKind.moodFactor,
            label: l.wbFactors,
            icon: Icons.label_outline_rounded,
            selected: _d.factors,
            onChanged: (v) => _set((_) => _with(factors: v)),
            onManage: () => showTagManagerSheet(context, TagKind.moodFactor),
          ),
          const SizedBox(height: Space.l),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: l.wbNotes, hintText: l.wbMoodNotesHint),
          ),
          const SizedBox(height: Space.m),
          WbWhenField(
            value: _d.at,
            now: now,
            onChanged: (v) => _set((_) => _with(at: v)),
          ),
        ],
      ),
    );
  }
}

const Object _keep = Object();
