import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/db/database.dart';
import '../../../../core/db/repositories/repositories.dart';
import '../../../../core/design/themes.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion.dart';
import '../../../../core/sound/sound_api.dart';
import '../../data/orbit_providers.dart';
import '../../data/orbit_repository.dart';
import '../../data/planet_customization_service.dart';
import '../../domain/neglect_text.dart';
import '../../domain/orbit_labels.dart';
import '../../domain/planet_archetypes.dart';
import '../../domain/planet_scores.dart' show PlanetState;
import '../../domain/scene_snapshot.dart';
import '../../domain/score_sources.dart';
import '../../render/planets/planets.dart';

/// What the customisation sheet can do.
enum PlanetCustomizeAction { look, weight, sources, move, hide, reset, delete, showHidden, add }

/// Long-press on a world: a glass sheet to rename / recolour / restyle it,
/// weigh it in the balance, pick its data sources, move its orbit, hide it,
/// reset or delete it, bring hidden worlds back or add a new one. Every
/// change shows an undo toast.
Future<void> showPlanetCustomizeSheet(BuildContext context, WidgetRef ref, String planetKey) async {
  final repos = ref.read(repositoriesProvider);
  final rows = await repos.planets.getAll();
  if (!context.mounted) return;
  final row = rows.where((r) => r.key == planetKey).firstOrNull;
  if (row == null) {
    Fx.fire(Sfx.error);
    return;
  }
  final config = OrbitRepository.configOf(row);
  final languageCode = Localizations.localeOf(context).languageCode;
  final hidden = [
    for (final r in rows)
      if (r.hidden) r,
  ];
  final action = await showInteractionSheet<PlanetCustomizeAction>(
    context,
    builder: (sheetContext) => _CustomizeSheet(config: config, languageCode: languageCode, hiddenCount: hidden.length),
  );
  if (action == null || !context.mounted) return;
  final actions = _PlanetActions(context, ref, config, rows);
  await actions.run(action);
}

class _CustomizeSheet extends ConsumerWidget {
  const _CustomizeSheet({required this.config, required this.languageCode, required this.hiddenCount});

  final PlanetConfig config;
  final String languageCode;
  final int hiddenCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final name = config.nameFor(languageCode);
    final snapshot = ref.watch(sceneSnapshotProvider).value;
    final planet = snapshot?.planet(config.key);
    void pick(PlanetCustomizeAction a) => Navigator.of(context).pop(a);
    return InteractionSheetFrame(
      // A name typed in the other script stays whole inside the title.
      title: l.orbitUiCustomizeTitle(BidiIsolate.isolate(name)),
      subtitle: l.orbitUiCustomizeSubtitle,
      icon: Icons.tune_rounded,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (planet != null) _WorldOrb(body: PlanetBody.fromOrbitPlanet(planet)),
          const SizedBox(height: Space.m),
          _Tile(icon: Icons.palette_outlined, label: l.orbitUiEditLook, onTap: () => pick(PlanetCustomizeAction.look)),
          _Tile(
            icon: Icons.balance_rounded,
            label: l.orbitUiEditWeight,
            onTap: () => pick(PlanetCustomizeAction.weight),
          ),
          _Tile(
            icon: Icons.stream_rounded,
            label: l.orbitUiEditSources,
            onTap: () => pick(PlanetCustomizeAction.sources),
          ),
          _Tile(
            icon: Icons.swap_vert_rounded,
            label: l.orbitUiMoveOrbit,
            onTap: () => pick(PlanetCustomizeAction.move),
          ),
          _Tile(
            icon: Icons.visibility_off_outlined,
            label: l.orbitUiHide,
            onTap: () => pick(PlanetCustomizeAction.hide),
          ),
          if (config.isCustom)
            _Tile(
              icon: Icons.delete_outline_rounded,
              label: l.orbitUiDelete,
              color: t.danger,
              onTap: () => pick(PlanetCustomizeAction.delete),
            )
          else
            _Tile(
              icon: Icons.restart_alt_rounded,
              label: l.orbitUiReset,
              onTap: () => pick(PlanetCustomizeAction.reset),
            ),
          const MadarDivider(height: 20),
          if (hiddenCount > 0)
            _Tile(
              icon: Icons.visibility_outlined,
              label: l.orbitUiHiddenWorlds,
              onTap: () => pick(PlanetCustomizeAction.showHidden),
            ),
          _Tile(
            icon: Icons.add_circle_outline_rounded,
            label: l.orbitUiAddPlanet,
            onTap: () => pick(PlanetCustomizeAction.add),
          ),
        ],
      ),
    );
  }
}

/// The real world, turning slowly in a studio light (the same shader as
/// the orbit behind the sheet), about 45 % of the sheet's width – on the
/// sheet's glass itself (no backdrop of its own).
class _WorldOrb extends StatelessWidget {
  const _WorldOrb({required this.body});

  final PlanetBody body;

  /// The portrait's square box for a sheet [width]: the disc is
  /// box / haloFactor (≈ 45 % of the width for most worlds; the gas giant's
  /// rings take the same box around a smaller globe).
  static double sideFor(double width) => math.min(width * 0.62, 236);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = sideFor(box.maxWidth);
        return ExcludeSemantics(
          child: Center(
            child: SizedBox.square(
              dimension: side,
              child: PlanetPortrait(body: body, animate: true),
            ),
          ),
        );
      },
    );
  }
}

/// The look editor's live preview: the world recoloured / restyled and
/// renamed as the fields change.
class _LookPreview extends StatelessWidget {
  const _LookPreview({required this.planet, required this.config, required this.values, required this.fallbackName});

  final OrbitPlanet? planet;
  final PlanetConfig config;
  final Map<String, Object?> values;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final typed = (values['name'] as String?)?.trim();
    final name = typed == null || typed.isEmpty ? fallbackName : typed;
    final color = values['color'] is int ? values['color']! as int : config.color;
    final style = values['style'];
    final archetype = style is String
        ? PlanetArchetype.values.firstWhere((a) => a.name == style, orElse: () => config.archetype)
        : config.archetype;
    final p = planet;
    final body = PlanetBody(
      key: config.key,
      name: name,
      archetype: archetype,
      palette: OrbitArchetypes.paletteFor(config.key, color),
      score: p?.uScore ?? 0.7,
      state: p?.state ?? PlanetState.steady,
      extras: p?.extras ?? const [0, 0, 0, 0],
      seed: p?.seed ?? 0,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WorldOrb(body: body),
        const SizedBox(height: Space.xs),
        AnimatedSwitcher(
          duration: context.motion(MadarMotion.short),
          child: Text(
            name,
            key: ValueKey(name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.titleLarge!.copyWith(
              color: t.textPrimary,
              fontFamily: MadarTypography.displayFamily,
              fontFamilyFallback: const [MadarTypography.uiFamily],
            ),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.textPrimary;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Space.s),
      child: GlassCard(
        glow: false,
        onTap: onTap,
        semanticLabel: label,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? t.accent),
            const SizedBox(width: Space.m),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleSmall!.copyWith(color: c)),
            ),
            // Mirrors itself in right-to-left layouts.
            Icon(Icons.chevron_right_rounded, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Runs one customisation with its sub-sheet and undo toast.
class _PlanetActions {
  _PlanetActions(this.context, this.ref, this.config, this.rows);

  final BuildContext context;
  final WidgetRef ref;
  final PlanetConfig config;
  final List<PlanetRow> rows;

  PlanetCustomizationService get _service => ref.read(planetCustomizationProvider);
  L10n get _l => L10n.of(context);
  MadarFormatter get _fmt => MadarFormatter.of(context);
  String get _lang => Localizations.localeOf(context).languageCode;
  String get _name => config.nameFor(_lang);

  Future<void> run(PlanetCustomizeAction action) async {
    try {
      switch (action) {
        case PlanetCustomizeAction.look:
          await _look();
        case PlanetCustomizeAction.weight:
          await _weight();
        case PlanetCustomizeAction.sources:
          await _sources();
        case PlanetCustomizeAction.move:
          await _move();
        case PlanetCustomizeAction.hide:
          final undo = await _service.setHidden(config.key, true);
          _leavePage();
          _toast(PlanetEdit.hide, undo);
        case PlanetCustomizeAction.reset:
          _toast(PlanetEdit.reset, await _service.resetToDefaults(config.key));
        case PlanetCustomizeAction.delete:
          final undo = await _service.deletePlanet(config.key);
          _leavePage();
          _toast(PlanetEdit.delete, undo, sfx: Sfx.delete);
        case PlanetCustomizeAction.showHidden:
          await _showHidden();
        case PlanetCustomizeAction.add:
          await _add();
      }
    } on PlanetCustomizationException {
      Fx.fire(Sfx.error);
    }
  }

  /// A hidden / deleted world's page cannot stay open.
  void _leavePage() {
    if (!context.mounted) return;
    final location = GoRouter.maybeOf(context)?.state.uri.path ?? '';
    if (location.startsWith('/planet/')) context.go('/');
  }

  void _toast(PlanetEdit edit, OrbitUndo undo, {String? name, Sfx sfx = Sfx.drop}) {
    if (!context.mounted) return;
    Fx.fire(sfx);
    unawaited(
      showUndoToast(
        context,
        UndoableAction(
          label: planetEditUndoLabel(_l, _fmt, edit, name: name ?? _name),
          undo: undo,
        ),
      ),
    );
  }

  List<SelectOption> _styles() => [
    for (final a in OrbitArchetypes.choices)
      SelectOption(id: a.name, label: planetArchetypeLabel(_l, a), color: OrbitArchetypes.defaultColor(a)),
  ];

  Future<void> _look() async {
    final planet = ref.read(sceneSnapshotProvider).value?.planet(config.key);
    final values = await showEditSheet(
      context,
      title: _l.orbitUiEditLook,
      icon: Icons.palette_outlined,
      preview: (context, v) => _LookPreview(planet: planet, config: config, values: v, fallbackName: _name),
      initial: {'name': _name, 'color': config.color, 'style': config.archetype.name},
      fields: [
        FieldSpec.text('name', _l.orbitUiFieldName, required: true, maxLength: 40, icon: Icons.edit_rounded),
        FieldSpec.color('color', _l.orbitUiFieldColor),
        FieldSpec.singleSelect('style', _l.orbitUiFieldStyle, options: _styles(), icon: Icons.public_rounded),
      ],
    );
    if (values == null || !context.mounted) return;
    final undos = <OrbitUndo>[];
    PlanetEdit? first;
    final name = (values['name'] as String?)?.trim() ?? _name;
    if (name.isNotEmpty && name != _name) {
      undos.add(await _service.rename(config.key, name, languageCode: _lang));
      first ??= PlanetEdit.rename;
    }
    final color = values['color'];
    if (color is int && color != config.color) {
      undos.add(await _service.recolor(config.key, Color(color)));
      first ??= PlanetEdit.recolor;
    }
    final style = values['style'];
    if (style is String && style != config.archetype.name) {
      undos.add(await _service.setArchetype(config.key, PlanetArchetype.values.byName(style)));
      first ??= PlanetEdit.style;
    }
    if (first == null) return;
    _toast(first, () async {
      for (final u in undos.reversed) {
        await u();
      }
    }, name: name);
  }

  Future<void> _weight() async {
    final values = await showEditSheet(
      context,
      title: _l.orbitUiEditWeight,
      icon: Icons.balance_rounded,
      initial: {'weight': (config.weight * 2).round().clamp(0, 6)},
      fields: [
        FieldSpec.slider(
          'weight',
          _l.orbitUiFieldWeight,
          min: 0,
          max: 6,
          labels: {0: _l.orbitUiWeightNone, 2: _l.orbitUiWeightNormal, 6: _l.orbitUiWeightMost},
        ),
      ],
    );
    final v = values?['weight'];
    if (v is! num || !context.mounted) return;
    final weight = v / 2;
    if (weight == config.weight) return;
    _toast(PlanetEdit.weight, await _service.setWeight(config.key, weight.toDouble()));
  }

  Future<void> _sources() async {
    final current = ScoreSources.canonicalWeights(config.sources);
    final builtIn = ScoreSources.builtIn[config.key] ?? const <String>[];
    final offered = <String>[
      ...builtIn,
      for (final s in current.keys)
        if (!builtIn.contains(s) && ScoreSources.isKnown(s) && !s.startsWith(ScoreSources.modulePrefix)) s,
      if (!builtIn.contains(ScoreSources.tasks) && !current.containsKey(ScoreSources.tasks)) ScoreSources.tasks,
      if (!current.containsKey(ScoreSources.habits) && !builtIn.contains(ScoreSources.habits)) ScoreSources.habits,
    ];
    final values = await showEditSheet(
      context,
      title: _l.orbitUiEditSources,
      subtitle: _l.orbitUiSourcesHint,
      icon: Icons.stream_rounded,
      initial: {
        for (final s in offered) s: ((current[s] ?? (builtIn.contains(s) ? 1.0 : 0.0)) * 5).round().clamp(0, 10),
      },
      fields: [
        for (final s in offered)
          FieldSpec.slider(s, scoreSourceLabel(_l, s), min: 0, max: 10, labels: {0: _l.orbitUiSourceOff}),
      ],
    );
    if (values == null || !context.mounted) return;
    final next = <String, double>{
      for (final e in current.entries)
        if (!offered.contains(e.key) && ScoreSources.isKnown(e.key)) e.key: e.value,
      for (final s in offered)
        if (values[s] case final num v) s: v / 5,
    };
    _toast(PlanetEdit.sources, await _service.setSources(config.key, next));
  }

  Future<void> _move() async {
    final ordered = [
      for (final r in rows)
        if (!r.hidden) r,
    ];
    final index = ordered.indexWhere((r) => r.key == config.key);
    String nameOf(PlanetRow r) =>
        _lang == 'en' ? (r.nameEn.isEmpty ? r.nameAr : r.nameEn) : (r.nameAr.isEmpty ? r.nameEn : r.nameAr);
    final targets = <MoveTarget>[
      for (var i = 0; i < ordered.length; i++)
        if (ordered[i].key != config.key)
          MoveTarget(
            id: ordered[i].key,
            label: _l.orbitUiMoveBefore(BidiIsolate.isolate(nameOf(ordered[i]))),
            subtitle: _l.orbitUiOrbitNumber(_fmt.formatInt(i < index ? i + 1 : i)),
            color: PlanetPalettes.byKey[ordered[i].key]?.surface ?? Color(ordered[i].color),
            icon: InteractionIcons.resolve(ordered[i].icon),
            isCurrent: i == index + 1,
          ),
      MoveTarget(
        id: '',
        label: _l.orbitUiMoveLast,
        subtitle: _l.orbitUiOrbitNumber(_fmt.formatInt(ordered.length)),
        icon: Icons.trip_origin_rounded,
        isCurrent: index == ordered.length - 1,
      ),
    ];
    final target = await showMoveSheet(
      context,
      title: _l.orbitUiMoveTitle,
      subtitle: _l.orbitUiMoveSubtitle,
      icon: Icons.swap_vert_rounded,
      targets: targets,
    );
    if (target == null || !context.mounted) return;
    final keys = [for (final r in rows) r.key]..remove(config.key);
    final at = target.id.isEmpty ? keys.length : keys.indexOf(target.id);
    keys.insert(at < 0 ? keys.length : at, config.key);
    _toast(PlanetEdit.reorder, await _service.reorder(keys));
  }

  Future<void> _showHidden() async {
    String nameOf(PlanetRow r) =>
        _lang == 'en' ? (r.nameEn.isEmpty ? r.nameAr : r.nameEn) : (r.nameAr.isEmpty ? r.nameEn : r.nameAr);
    final hidden = [
      for (final r in rows)
        if (r.hidden) r,
    ];
    final target = await showMoveSheet(
      context,
      title: _l.orbitUiHiddenWorlds,
      icon: Icons.visibility_outlined,
      targets: [
        for (final r in hidden)
          MoveTarget(
            id: r.key,
            label: nameOf(r),
            color: PlanetPalettes.byKey[r.key]?.surface ?? Color(r.color),
            icon: InteractionIcons.resolve(r.icon),
          ),
      ],
    );
    if (target == null || !context.mounted) return;
    final row = hidden.firstWhere((r) => r.key == target.id);
    _toast(PlanetEdit.show, await _service.setHidden(row.key, false), name: nameOf(row));
  }

  Future<void> _add() async {
    final values = await showEditSheet(
      context,
      title: _l.orbitUiAddPlanet,
      icon: Icons.add_circle_outline_rounded,
      initial: {'name': _l.orbitNewPlanetName, 'style': PlanetArchetype.ice.name},
      fields: [
        FieldSpec.text('name', _l.orbitUiFieldName, required: true, maxLength: 40, autofocus: true),
        FieldSpec.singleSelect('style', _l.orbitUiFieldStyle, options: _styles(), icon: Icons.public_rounded),
        FieldSpec.color('color', _l.orbitUiFieldColor),
      ],
    );
    if (values == null || !context.mounted) return;
    final style = PlanetArchetype.values.byName((values['style'] as String?) ?? PlanetArchetype.ice.name);
    final color = values['color'];
    final name = (values['name'] as String).trim();
    final (_, undo) = await _service.addPlanet(name: name, archetype: style, color: color is int ? Color(color) : null);
    _toast(PlanetEdit.add, undo, name: name, sfx: Sfx.levelUp);
  }
}
