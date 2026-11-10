import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/domain/enums.dart' show PlanOrigin;
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/sound/sound_api.dart';
import '../../data/data.dart' show dataClockProvider;
import '../../data/presentation/widgets/data_widgets.dart';
import '../../import/import_controller.dart' show importFilePickerProvider;
import '../data/ai_bridge_providers.dart';
import '../data/plan_apply_service.dart' show PlanImport;
import '../data/share_intake.dart' show pendingSharedPlanProvider;
import 'ai_bridge_texts.dart';
import 'widgets/plan_widgets.dart';

/// Bringing an answer in: he pastes it, picks its file, or another app
/// shares it straight into Madar.
///
/// Three things this screen guarantees:
///
/// * **nothing leaves the phone and nothing is touched on the way in.**
///   Reading an answer stores the plan and its suggestions as *pending*
///   rows of the plan's own tables; not one record of his is written until
///   he taps Approve on a single card.
/// * **a payload the validator refuses shows its problems and nothing
///   else** – one plain Arabic sentence per problem, no Approve button
///   anywhere, never a crash and never a blank screen.
/// * a notice (extra text around the JSON) is a notice, not a refusal: the
///   plan inside is still reviewed, and the line says so.
class PlanImportScreen extends ConsumerStatefulWidget {
  const PlanImportScreen({super.key, this.animateBackdrop = true, this.onOpenPlan});

  final bool animateBackdrop;

  /// Opens the plan that just arrived (the router replaces this screen with
  /// it, so Android back returns to the plans).
  final void Function(String planId)? onOpenPlan;

  @override
  ConsumerState<PlanImportScreen> createState() => _PlanImportScreenState();
}

class _PlanImportScreenState extends ConsumerState<PlanImportScreen> {
  final _paste = TextEditingController();
  bool _busy = false;
  PlanImport? _result;
  String? _notice;
  bool _shared = false;

  @override
  void initState() {
    super.initState();
    // An answer another app shared arrives before this screen is built:
    // read it here, where his language is, so the plan gets its plain
    // default name («خطة ١٠ تشرين الأول»).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _takeShared();
    });
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  Future<void> _take(String text, PlanOrigin origin) async {
    final l = L10n.of(context);
    if (text.trim().isEmpty) {
      Fx.fire(Sfx.error);
      setState(() {
        _notice = l.aiPlanPasteEmpty;
        _result = null;
      });
      return;
    }
    final name = AiBridgeTexts.of(context).defaultPlanName(ref.read(dataClockProvider)());
    setState(() {
      _busy = true;
      _notice = null;
      _result = null;
    });
    try {
      final catalog = await ref.read(aiBridgeRepositoryProvider).loadCatalog(ref.read(dataClockProvider)());
      final import = await ref
          .read(planApplyServiceProvider)
          .take(text, catalog: catalog, origin: origin, name: name);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = import;
      });
      final plan = import.plan;
      if (import.isUsable && plan != null) {
        Fx.fire(Sfx.complete);
        widget.onOpenPlan?.call(plan.id);
      } else {
        Fx.fire(Sfx.error);
      }
    } catch (_) {
      Fx.fire(Sfx.error);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _notice = l.aiPlanImportFailed;
      });
    }
  }

  /// Takes whatever is parked, once. Called from the first frame (an
  /// answer offered before this screen mounted) and from the listener in
  /// [build] (one offered while it is open).
  void _takeShared() {
    final shared = ref.read(pendingSharedPlanProvider.notifier).take();
    if (shared == null) return;
    setState(() => _shared = true);
    unawaited(_take(shared.text, PlanOrigin.share));
  }

  Future<void> _pick() async {
    final picked = await ref.read(importFilePickerProvider)();
    if (picked == null || !mounted) return;
    await _take(picked.text, PlanOrigin.file);
  }

  @override
  Widget build(BuildContext context) {
    // Another answer shared while this screen is open.
    ref.listen(pendingSharedPlanProvider, (_, next) {
      if (next != null && mounted) _takeShared();
    });
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final tx = AiBridgeTexts.of(context);
    final result = _result;
    final refused = result != null && !result.isUsable;

    final children = <Widget>[
      GlassPanel(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.xl, Space.xl, Space.l),
        child: Column(
          children: [
            const DataEmblem(icon: Icons.move_to_inbox_rounded, size: 86),
            const SizedBox(height: Space.l),
            Text(
              l.aiPlanImportTitle,
              textAlign: TextAlign.center,
              style: text.headlineSmall?.copyWith(color: t.textPrimary),
            ),
            const SizedBox(height: Space.s),
            Text(
              l.aiPlanImportBody,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: t.textSecondary, height: 1.55),
            ),
          ],
        ),
      ),
      if (_shared) DataNote(text: l.aiPlanImportShared, icon: Icons.ios_share_rounded, color: t.accent, dense: true),
      SectionHeader(
        title: l.aiPlanPasteLabel,
        subtitle: l.aiPlanPasteHint,
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.l, Space.xs, Space.m),
      ),
      TextField(
        key: const ValueKey('aiPlan.paste'),
        controller: _paste,
        minLines: 4,
        maxLines: 10,
        keyboardType: TextInputType.multiline,
        style: text.bodySmall?.copyWith(color: t.textPrimary, height: 1.5),
        cursorColor: t.accent,
        decoration: dataInputDecoration(context, label: l.aiPlanPasteLabel, hint: l.aiPlanPasteHint),
      ),
      const SizedBox(height: Space.m),
      MadarButton(
        key: const ValueKey('aiPlan.read'),
        label: l.aiPlanPasteAction,
        icon: Icons.fact_check_rounded,
        expand: true,
        sfx: Sfx.tap,
        onPressed: _busy ? null : () => _take(_paste.text, PlanOrigin.paste),
      ),
      const SizedBox(height: Space.s),
      MadarButton(
        key: const ValueKey('aiPlan.pick'),
        label: l.aiPlanPickAction,
        icon: Icons.file_open_rounded,
        variant: MadarButtonVariant.secondary,
        expand: true,
        sfx: Sfx.navigate,
        onPressed: _busy ? null : _pick,
      ),
      if (_busy) ...[const SizedBox(height: Space.l), DataBusy(title: l.aiPlanImportBusy)],
      if (_notice != null) ...[
        const SizedBox(height: Space.l),
        DataNote(key: const ValueKey('aiPlan.notice'), text: _notice!, icon: Icons.error_outline_rounded, color: t.danger),
      ],

      // ------------------------------------------------- what refused it --
      if (refused) ...[
        SectionHeader(
          title: l.aiPlanProblemsTitle,
          padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
        ),
        GlassPanel(
          key: const ValueKey('aiPlan.problems'),
          padding: const EdgeInsetsDirectional.all(Space.l),
          seed: 3.3,
          // The section header above already names this block, so the
          // panel is nothing but the sentences themselves.
          child: PlanLines(lines: tx.problems(result.problems), color: t.danger),
        ),
        const SizedBox(height: Space.m),
        DataNote(text: l.aiPlanProblemsHint, icon: Icons.refresh_rounded, color: t.textSecondary),
      ] else if (result != null && !result.isNew)
        Padding(
          padding: const EdgeInsetsDirectional.only(top: Space.l),
          child: DataNote(text: l.aiPlanImportAgain, icon: Icons.history_rounded, color: t.gold, dense: true),
        ),
    ];

    return MadarScaffold(
      title: l.aiPlanImportTitle,
      backdropSeed: 9.1,
      animateBackdrop: widget.animateBackdrop,
      body: EntranceChoreo(
        id: 'aiPlan-import',
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 120),
          children: [for (var i = 0; i < children.length; i++) StaggerItem(index: i, child: children[i])],
        ),
      ),
    );
  }
}
