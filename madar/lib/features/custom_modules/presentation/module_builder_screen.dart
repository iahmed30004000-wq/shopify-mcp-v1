import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/interaction/sheets/field_inputs.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../custom_texts.dart';
import '../data/custom_modules_providers.dart';
import '../data/custom_modules_service.dart';
import '../domain/field_migration.dart';
import '../domain/module_builder_rules.dart';
import '../domain/module_schema.dart';
import 'field_editor_sheet.dart';
import 'widgets/module_visuals.dart';

/// Creates or edits a module: name, kind, icon, colour, planet (built-in or
/// user-added), prayer window, the fields (add / edit / reorder / duplicate
/// / delete / restore hidden ones) and the chart. Saving a module that has
/// entries migrates them safely (see `FieldMigration`): blocked changes are
/// explained and nothing is written; warnings are confirmed first.
///
/// Pops with the saved module's id (or calls [onSaved]).
class ModuleBuilderScreen extends ConsumerStatefulWidget {
  const ModuleBuilderScreen({
    super.key,
    this.moduleId,
    this.draft,
    this.planetKey,
    this.onSaved,
    this.animateBackdrop = true,
  });

  /// The module to edit (null = a new one).
  final String? moduleId;

  /// A new module's starting point (a template); blank when null.
  final ModuleDefinition? draft;

  /// Attach a new blank module to this planet.
  final String? planetKey;

  /// Called with the saved module's id instead of popping.
  final ValueChanged<String>? onSaved;

  final bool animateBackdrop;

  @override
  ConsumerState<ModuleBuilderScreen> createState() => _ModuleBuilderScreenState();
}

class _ModuleBuilderScreenState extends ConsumerState<ModuleBuilderScreen> {
  static const int _defaultColor = 0xFFC9A45C;

  ModuleDefinition? _d;
  ModuleDefinition? _stored;
  final Set<String> _entryKeys = {};
  final TextEditingController _name = TextEditingController();
  bool _tried = false;
  bool _saving = false;
  bool _dirty = false;
  bool _iconsOpen = false;

  bool get _isNew => widget.moduleId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _apply(widget.draft ?? ModuleBuilderRules.blank(colorArgb: _defaultColor, planetKey: widget.planetKey));
    } else {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final service = ref.read(customModulesServiceProvider);
    final m = await service.module(widget.moduleId!);
    final entries = await service.entries(widget.moduleId!);
    if (!mounted) return;
    setState(() {
      _stored = m;
      for (final e in entries) {
        _entryKeys.addAll(e.values.keys);
      }
    });
    if (m != null) setState(() => _apply(m));
  }

  void _apply(ModuleDefinition d) {
    _d = d;
    if (_name.text != d.name) _name.text = d.name;
  }

  /// A change from the UI (the name field keeps its own text).
  void _set(ModuleDefinition d, {bool dirty = true}) {
    setState(() {
      _d = d.copyWith(name: _name.text);
      if (dirty) _dirty = true;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- fields --

  Set<String> _otherLabels(String exceptId) => {
    for (final f in _d!.visibleFields)
      if (f.id != exceptId) f.label.trim().toLowerCase(),
  };

  Future<void> _addField() async {
    final type = await showFieldTypePicker(context);
    if (type == null || !mounted) return;
    final (withField, field) = ModuleBuilderRules.addField(_d!, type, '', takenIds: _entryKeys);
    final result = await showFieldEditorSheet(context, field: field, isNew: true, otherLabels: _otherLabels(field.id));
    if (result?.field == null || !mounted) return;
    _set(ModuleBuilderRules.replaceField(withField, result!.field!));
  }

  Future<UndoableAction?> _editField(ModuleField f) async {
    final result = await showFieldEditorSheet(context, field: f, otherLabels: _otherLabels(f.id));
    if (result == null || !mounted) return null;
    if (result.deleted) return _removeField(f);
    _set(ModuleBuilderRules.replaceField(_d!, result.field!));
    return null;
  }

  UndoableAction _removeField(ModuleField f) {
    final before = _d!;
    final tx = CustomTexts.of(context);
    _set(ModuleBuilderRules.removeField(before, f.id));
    return UndoableAction(label: tx.l.cmodFieldDeleted(tx.name(f.label)), undo: () async => _set(before));
  }

  UndoableAction _duplicateField(ModuleField f) {
    final before = _d!;
    final tx = CustomTexts.of(context);
    _set(ModuleBuilderRules.duplicateField(before, f.id, tx.l.cmodFieldCopyLabel(f.label), takenIds: _entryKeys));
    return UndoableAction(label: tx.l.cmodFieldDuplicated, undo: () async => _set(before));
  }

  // --------------------------------------------------------------- save --

  Future<void> _save() async {
    final d = _d;
    if (d == null || _saving) return;
    final problems = ModuleBuilderRules.check(d.copyWith(name: _name.text));
    if (problems.isNotEmpty) {
      Fx.fire(Sfx.error);
      setState(() => _tried = true);
      return;
    }
    final draft = d.copyWith(name: _name.text.trim());
    final service = ref.read(customModulesServiceProvider);
    final tx = CustomTexts.of(context);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    setState(() => _saving = true);
    try {
      String id;
      if (_stored == null) {
        final created = await service.createModule(draft);
        id = created.id;
      } else {
        final plan = await service.planUpdate(draft);
        if (!mounted) return;
        if (!plan.canApply || plan.warnings.isNotEmpty) setState(() => _saving = false);
        if (!plan.canApply) {
          Fx.fire(Sfx.error);
          await _showPlan(plan, blocked: true);
          return;
        }
        if (plan.warnings.isNotEmpty) {
          final ok = await _showPlan(plan);
          if (ok != true || !mounted) return;
          setState(() => _saving = true);
        }
        final (_, undo) = await service.updateModule(draft);
        id = draft.id;
        if (overlay != null && overlay.mounted) {
          unawaited(
            UndoToast.show(overlay, UndoableAction(label: tx.l.cmodToastSaved(tx.name(draft.name)), undo: undo)),
          );
        }
      }
      if (!mounted) return;
      Fx.fire(Sfx.complete);
      Celebrate.burstFrom(context, kind: CelebrationKind.orbitalRing, color: Color(draft.colorArgb), intensity: 0.8);
      setState(() => _dirty = false);
      final cb = widget.onSaved;
      if (cb != null) {
        cb(id);
      } else {
        Navigator.of(context).pop(id);
      }
    } on MigrationBlockedException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        await _showPlan(e.plan, blocked: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Explains what saving will do (warnings: confirm) or why it cannot.
  Future<bool?> _showPlan(FieldMigrationPlan plan, {bool blocked = false}) {
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final issues = blocked ? plan.blocking : plan.warnings;
    return showInteractionSheet<bool>(
      context,
      builder: (ctx) {
        final t = ctx.tokens;
        final text = Theme.of(ctx).textTheme;
        return InteractionSheetFrame(
          title: blocked ? l.cmodMigrationBlockedTitle : l.cmodMigrationTitle,
          icon: blocked ? Icons.block_rounded : Icons.fact_check_outlined,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in issues)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        blocked ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                        size: 18,
                        color: blocked ? t.danger : t.info,
                      ),
                      const SizedBox(width: Space.s),
                      Expanded(child: Text(tx.migration(i), style: text.bodyMedium)),
                    ],
                  ),
                ),
              if (blocked) ...[
                const SizedBox(height: Space.s),
                Text(l.cmodMigrationBlockedBody, style: text.bodySmall!.copyWith(color: t.textSecondary)),
              ],
            ],
          ),
          footer: blocked
              ? SheetButton(label: l.cmodMigrationOk, primary: true, onPressed: () => Navigator.of(ctx).pop(false))
              : Row(
                  children: [
                    Expanded(child: SheetButton(label: l.cmodCancel, onPressed: () => Navigator.of(ctx).pop(false))),
                    const SizedBox(width: Space.m),
                    Expanded(
                      flex: 2,
                      child: SheetButton(
                        label: l.cmodSave,
                        primary: true,
                        icon: Icons.check_rounded,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _maybeLeave() async {
    final tx = CustomTexts.of(context);
    final nav = Navigator.of(context);
    final discard = await showInteractionSheet<bool>(
      context,
      builder: (ctx) => InteractionSheetFrame(
        title: tx.l.cmodDiscardTitle,
        icon: Icons.edit_off_rounded,
        body: Text(tx.l.cmodDiscardBody, style: Theme.of(ctx).textTheme.bodyMedium),
        footer: Row(
          children: [
            Expanded(child: SheetButton(label: tx.l.cmodKeepEditing, onPressed: () => Navigator.of(ctx).pop(false))),
            const SizedBox(width: Space.m),
            Expanded(
              child: SheetButton(
                label: tx.l.cmodDiscard,
                primary: true,
                tone: ctx.tokens.danger,
                sfx: Sfx.delete,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
    if (discard == true && mounted) {
      setState(() => _dirty = false);
      nav.pop();
    }
  }

  // -------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final d = _d;
    final problems = d == null || !_tried ? const <DraftProblem>[] : ModuleBuilderRules.check(d.copyWith(name: _name.text));
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_maybeLeave());
      },
      child: MadarScaffold(
        title: _isNew ? l.cmodBuilderNewTitle : l.cmodBuilderEditTitle,
        backdropSeed: 5.1,
        animateBackdrop:
            widget.animateBackdrop &&
            ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
        bottomBar: d == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.m),
                child: MadarButton(
                  label: _isNew ? l.cmodCreate : l.cmodSave,
                  icon: Icons.check_rounded,
                  expand: true,
                  size: MadarButtonSize.large,
                  loading: _saving,
                  sfx: Sfx.tap,
                  onPressed: _save,
                ),
              ),
        body: d == null
            ? const Center(child: OrbitLoader(size: 40))
            : _body(context, d, tx, problems, t),
      ),
    );
  }

  Widget _body(BuildContext context, ModuleDefinition d, CustomTexts tx, List<DraftProblem> problems, MadarTokens t) {
    final l = tx.l;
    final text = Theme.of(context).textTheme;
    final planets = ref.watch(customPlanetChoicesProvider).value ?? const [];
    String? problem(DraftIssue issue) =>
        problems.any((p) => p.issue == issue && p.fieldId == null) ? tx.issue(issue) : null;
    final nameError = problem(DraftIssue.nameMissing) ?? problem(DraftIssue.nameTooLong);
    final fieldsError = problem(DraftIssue.noFields) ?? problem(DraftIssue.tooManyFields);
    var i = 0;
    return EntranceChoreo(
      id: 'cmod-builder',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxl),
        children: [
          StaggerItem(index: i++, child: _Preview(draft: d.copyWith(name: _name.text))),

          // ------------------------------------------------------ basics
          StaggerItem(index: i++, child: ModuleSectionTitle(title: l.cmodSectionBasics)),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.cmodName,
              icon: Icons.drive_file_rename_outline_rounded,
              error: nameError,
              child: TextField(
                controller: _name,
                maxLength: ModuleBuilderRules.maxNameLength,
                textCapitalization: TextCapitalization.sentences,
                autofocus: _isNew && widget.draft == null,
                decoration: kitInputDecoration(context, hint: l.cmodNameHint, error: nameError != null),
                onChanged: (_) => setState(() => _dirty = true),
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.cmodKind,
              icon: Icons.category_outlined,
              child: Row(
                children: [
                  for (final k in CustomModuleKind.values) ...[
                    if (k != CustomModuleKind.values.first) const SizedBox(width: Space.s),
                    Expanded(
                      child: _KindOption(
                        kind: k,
                        selected: d.kind == k,
                        onTap: () => _set(d.copyWith(kind: k)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.cmodIcon,
              icon: Icons.emoji_symbols_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PickerButton(
                    icon: ModuleIcons.module(d.iconKey),
                    text: l.cmodIcon,
                    active: _iconsOpen,
                    onTap: () {
                      Fx.fire(Sfx.tap);
                      setState(() => _iconsOpen = !_iconsOpen);
                    },
                  ),
                  AnimatedSize(
                    duration: context.motion(MadarMotion.medium),
                    curve: MadarMotion.emphasized,
                    alignment: Alignment.topCenter,
                    child: _iconsOpen
                        ? Padding(
                            padding: const EdgeInsetsDirectional.only(top: Space.s),
                            child: IconGrid(
                              icons: InteractionIcons.curated,
                              value: d.iconKey,
                              onChanged: (k) {
                                if (k == null) return;
                                _set(d.copyWith(iconKey: k));
                              },
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.cmodColor,
              icon: Icons.palette_outlined,
              child: SwatchPicker(
                colors: CuratedPalette.colors,
                value: d.colorArgb,
                onChanged: (c) {
                  if (c != null) _set(d.copyWith(colorArgb: c));
                },
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.cmodPlanet,
              icon: Icons.public_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: Space.s,
                    runSpacing: Space.s,
                    children: [
                      KitChip(
                        label: l.cmodPlanetNone,
                        selected: d.planetKey == null,
                        dense: true,
                        onTap: () => _set(d.copyWith(clearPlanet: true)),
                      ),
                      // A planet hidden (or removed) since: keep it visible.
                      if (d.planetKey != null && !planets.any((p) => p.key == d.planetKey))
                        KitChip(
                          label: tx.planet(d.planetKey) ?? d.planetKey!,
                          selected: true,
                          dense: true,
                          onTap: () {},
                        ),
                      for (final p in planets)
                        KitChip(
                          label: tx.arabic ? p.nameAr : p.nameEn,
                          swatch: Color(p.color),
                          selected: d.planetKey == p.key,
                          dense: true,
                          onTap: () => _set(d.copyWith(planetKey: p.key)),
                        ),
                    ],
                  ),
                  const SizedBox(height: Space.xs + 2),
                  Text(l.cmodPlanetHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: FieldShell(
              label: l.cmodWindow,
              icon: Icons.mosque_rounded,
              optional: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrayerWindowPicker(
                    value: d.window,
                    includeAnytime: true,
                    allowClear: true,
                    onChanged: (w) => _set(w == null ? d.copyWith(clearWindow: true) : d.copyWith(window: w)),
                  ),
                  const SizedBox(height: Space.xs + 2),
                  Text(l.cmodWindowHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
                ],
              ),
            ),
          ),

          // ------------------------------------------------------ fields
          StaggerItem(
            index: i++,
            child: ModuleSectionTitle(
              title: l.cmodSectionFields,
              count: tx.count(d.visibleFields.length),
            ),
          ),
          if (d.visibleFields.isEmpty)
            StaggerItem(
              index: i++,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s, start: Space.xs),
                child: Text(
                  fieldsError ?? (d.isTracker ? l.cmodFieldsEmptyTracker : l.cmodFieldsEmptyList),
                  style: text.bodySmall!.copyWith(color: fieldsError != null ? t.danger : t.textSecondary),
                ),
              ),
            ),
          ReorderableGlassList<ModuleField>(
            items: d.visibleFields,
            itemKey: (f) => f.id,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            animateEntrance: false,
            itemBorderRadius: BorderRadius.circular(t.radiusM),
            onReorder: (order) => _set(ModuleBuilderRules.reorderFields(d, [for (final f in order) f.id])),
            itemBuilder: (context, f, index, handle) {
              final fieldProblems = [
                for (final p in problems)
                  if (p.fieldId == f.id) tx.issue(p.issue),
              ];
              return _FieldRow(
                key: ValueKey(f.id),
                field: f,
                handle: handle,
                problem: fieldProblems.firstOrNull,
                onEdit: () => _editField(f),
                onDuplicate: () => _duplicateField(f),
                onDelete: () => _removeField(f),
              );
            },
          ),
          const SizedBox(height: Space.s),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: MadarButton(
              label: l.cmodAddField,
              icon: Icons.add_rounded,
              variant: MadarButtonVariant.secondary,
              sfx: Sfx.sheetOpen,
              onPressed: _addField,
            ),
          ),
          if (d.hiddenFields.isNotEmpty) ...[
            ModuleSectionTitle(title: l.cmodHiddenFields, count: tx.count(d.hiddenFields.length), color: t.textTertiary),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: Space.xs, bottom: Space.s),
              child: Text(l.cmodHiddenFieldsHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
            ),
            for (final f in d.hiddenFields)
              Padding(
                padding: const EdgeInsetsDirectional.only(bottom: Space.s),
                child: _HiddenFieldRow(field: f, onRestore: () => _set(ModuleBuilderRules.restoreField(d, f.id))),
              ),
          ],

          // ------------------------------------------------------- chart
          if (d.isTracker) ...[
            ModuleSectionTitle(title: l.cmodSectionChart),
            _ChartSettings(draft: d, onChanged: (c) => _set(d.copyWith(chart: c))),
          ],
        ],
      ),
    );
  }
}

/// The live card at the top: the module as it will look.
class _Preview extends StatelessWidget {
  const _Preview({required this.draft});

  final ModuleDefinition draft;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    final c = ModuleColors.of(draft.colorArgb, t);
    final name = draft.name.trim();
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusXL),
      padding: const EdgeInsets.all(Space.l),
      glowColor: c.glow,
      child: Row(
        children: [
          ModuleOrb.of(draft, size: 64),
          const SizedBox(width: Space.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? tx.l.cmodPreviewUntitled : tx.name(name),
                  style: text.titleLarge!.copyWith(color: name.isEmpty ? t.textTertiary : t.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: Space.xs),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  children: [
                    ModuleBadge(label: tx.kind(draft.kind), color: c.ink, icon: ModuleIcons.kind(draft.kind)),
                    if (draft.window != null && draft.window != PrayerWindow.anytime)
                      ModuleBadge(label: tx.window(draft.window)!, color: t.textSecondary, icon: Icons.mosque_rounded),
                  ],
                ),
                if (draft.visibleFields.isNotEmpty) ...[
                  const SizedBox(height: Space.s),
                  Wrap(
                    spacing: Space.s,
                    children: [
                      for (final f in draft.visibleFields.take(8))
                        Icon(ModuleIcons.field(f.type), size: 16, color: t.textTertiary),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KindOption extends StatelessWidget {
  const _KindOption({required this.kind, required this.selected, required this.onTap});

  final CustomModuleKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${tx.kind(kind)}. ${tx.kindHint(kind)}',
      excludeSemantics: true,
      child: SpringPress(
        sfx: Sfx.tap,
        onTap: onTap,
        child: AnimatedContainer(
          duration: context.motion(MadarMotion.short),
          padding: const EdgeInsets.all(Space.m),
          decoration: BoxDecoration(
            color: selected ? t.accent.withValues(alpha: 0.14) : t.glassFill,
            borderRadius: BorderRadius.circular(t.radiusM),
            border: Border.all(color: selected ? t.accent : t.glassBorder, width: selected ? 1.4 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ModuleIcons.kind(kind), size: 20, color: selected ? t.accent : t.textSecondary),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      tx.kind(kind),
                      style: text.titleSmall!.copyWith(color: selected ? t.textPrimary : t.textSecondary),
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, size: 18, color: t.accent),
                ],
              ),
              const SizedBox(height: Space.xs),
              Text(
                tx.kindHint(kind),
                style: text.bodySmall!.copyWith(color: t.textTertiary, height: 1.25),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({
    super.key,
    required this.field,
    required this.handle,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    this.problem,
  });

  final ModuleField field;
  final Widget handle;
  final String? problem;
  final Future<UndoableAction?> Function() onEdit;
  final UndoableAction Function() onDuplicate;
  final UndoableAction Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    final label = field.label.trim();
    return ActionableItem(
      semanticLabel: '${label.isEmpty ? '—' : label} · ${tx.fieldSummary(field)}',
      borderRadius: BorderRadius.circular(t.radiusM),
      swipeEnabled: false,
      onTap: () => unawaited(onEdit()),
      actions: ItemActions(onEdit: onEdit, onDuplicate: onDuplicate, onDelete: onDelete),
      child: GlassCard(
        borderRadius: BorderRadius.circular(t.radiusM),
        borderColor: problem != null ? t.danger.withValues(alpha: 0.6) : null,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.s + 2, 0, Space.s + 2),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: t.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(t.radiusS)),
              child: Icon(ModuleIcons.field(field.type), color: t.accent, size: 19),
            ),
            const SizedBox(width: Space.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.isEmpty ? '—' : tx.name(label),
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    problem ?? tx.fieldSummary(field),
                    style: text.bodySmall!.copyWith(color: problem != null ? t.danger : t.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            handle,
          ],
        ),
      ),
    );
  }
}

class _HiddenFieldRow extends StatelessWidget {
  const _HiddenFieldRow({required this.field, required this.onRestore});

  final ModuleField field;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tx = CustomTexts.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs, Space.xs, Space.xs),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        border: Border.all(color: t.glassBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined, size: 18, color: t.textTertiary),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(
              '${tx.name(field.label)} · ${tx.fieldType(field.type)}',
              style: text.bodyMedium!.copyWith(color: t.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MadarButton(
            label: tx.l.cmodRestoreField,
            icon: Icons.visibility_outlined,
            variant: MadarButtonVariant.ghost,
            size: MadarButtonSize.small,
            sfx: Sfx.toggleOn,
            onPressed: onRestore,
          ),
        ],
      ),
    );
  }
}

/// Style (line / bars / calendar / streak), what to plot and the period.
class _ChartSettings extends StatelessWidget {
  const _ChartSettings({required this.draft, required this.onChanged});

  final ModuleDefinition draft;
  final ValueChanged<ModuleChartConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final tx = CustomTexts.of(context);
    final l = tx.l;
    final c = draft.effectiveChart;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldShell(
          label: l.cmodChartStyle,
          icon: Icons.insert_chart_outlined_rounded,
          child: Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              for (final type in ModuleChartType.values)
                KitChip(
                  label: tx.chartType(type),
                  icon: ModuleIcons.chart(type),
                  selected: c.type == type,
                  dense: true,
                  onTap: () => onChanged(c.copyWith(type: type)),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        FieldShell(
          label: l.cmodChartField,
          icon: Icons.stacked_line_chart_rounded,
          child: Wrap(
            spacing: Space.s,
            runSpacing: Space.s,
            children: [
              KitChip(
                label: l.cmodChartEntries,
                selected: c.fieldId == null,
                dense: true,
                onTap: () => onChanged(c.copyWith(clearField: true)),
              ),
              for (final f in draft.chartableFields)
                KitChip(
                  label: f.label.trim().isEmpty ? tx.fieldType(f.type) : f.label,
                  icon: ModuleIcons.field(f.type),
                  selected: c.fieldId == f.id,
                  dense: true,
                  onTap: () => onChanged(c.copyWith(fieldId: f.id)),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.m),
        FieldShell(
          label: l.cmodChartRange,
          icon: Icons.date_range_rounded,
          child: Wrap(
            spacing: Space.s,
            children: [
              for (final r in ModuleChartConfig.ranges)
                KitChip(
                  label: tx.range(r),
                  selected: c.range == r,
                  dense: true,
                  onTap: () => onChanged(c.copyWith(range: r)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
