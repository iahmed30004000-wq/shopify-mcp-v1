import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';
import '../../core/design/widgets/widgets.dart';
import '../../core/i18n/gen/app_localizations.dart';
import '../../core/import/import.dart';
import '../../core/motion/motion.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sound/sound_api.dart';
import 'import_controller.dart';
import 'import_presentation.dart';
import 'widgets/import_emblem.dart';
import 'widgets/import_motion.dart';
import 'widgets/import_preview.dart';

/// Imports the HTML prototype's JSON export: pick a `.json` file or paste
/// its text → animated analysis preview (per-section counts, warnings,
/// what is archived, duplicate-file check) → import with progress →
/// summary. All logic lives in [ImportController].
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key, this.onDone});

  /// Called by the summary's Done button (defaults to popping the route).
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final state = ref.watch(importControllerProvider);
    final digits = ref.watch(appSettingsProvider.select((s) => s.digits));
    final formats = ImportFormats(languageCode: Localizations.localeOf(context).languageCode, digits: digits);

    ref.listen(importControllerProvider.select((s) => s.stage), (previous, next) {
      if (previous == next) return;
      switch (next) {
        case ImportStage.preview when previous == ImportStage.analyzing:
          Fx.fire(Sfx.sparkle);
        case ImportStage.done:
          Fx.fire(Sfx.levelUp);
        case ImportStage.failure:
          Fx.fire(Sfx.error);
        default:
          break;
      }
    });

    final Widget body = switch (state.stage) {
      ImportStage.idle => const _IdleView(),
      ImportStage.analyzing => _BusyView(label: l.importAnalyzing),
      ImportStage.preview => ImportPreview(state: state, formats: formats),
      ImportStage.importing => _ImportingView(progress: state.progress, formats: formats),
      ImportStage.done => _DoneView(report: state.result!, formats: formats),
      ImportStage.failure => _FailureView(failure: state.failure ?? ImportFailure.unreadable),
    };

    return MadarScaffold(
      title: l.importTitle,
      bottomBar: switch (state.stage) {
        ImportStage.preview => ImportActionBar(state: state, formats: formats),
        ImportStage.done => _DoneBar(onDone: onDone),
        _ => null,
      },
      body: AnimatedSwitcher(
        duration: context.motion(MadarMotion.medium),
        switchInCurve: MadarMotion.decelerate,
        switchOutCurve: MadarMotion.accelerate,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: context.reducedMotion ? 1.0 : 0.985, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey(state.stage), child: body),
      ),
    );
  }
}

// ----------------------------------------------------------------- idle --

class _IdleView extends ConsumerStatefulWidget {
  const _IdleView();

  @override
  ConsumerState<_IdleView> createState() => _IdleViewState();
}

class _IdleViewState extends ConsumerState<_IdleView> {
  final _text = TextEditingController();
  bool _paste = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
  }

  void _onText() => setState(() {});

  @override
  void dispose() {
    _text
      ..removeListener(_onText)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final controller = ref.read(importControllerProvider.notifier);
    final labels = ImportLabels.of(l);
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxl),
      children: [
        ImportRise(
          child: GlassPanel(
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xl, Space.xl, Space.xl, Space.xl),
            child: Column(
              children: [
                const ImportEmblem(),
                const SizedBox(height: Space.l),
                Text(
                  l.importHeroTitle,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium!.copyWith(color: t.textPrimary),
                ),
                const SizedBox(height: Space.s),
                Text(
                  l.importHeroBody,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(color: t.textSecondary),
                ),
                const SizedBox(height: Space.xl),
                MadarButton(
                  label: l.importPickFile,
                  icon: Icons.upload_file_rounded,
                  size: MadarButtonSize.large,
                  expand: true,
                  onPressed: () => controller.pickFile(labels),
                ),
                const SizedBox(height: Space.m),
                MadarButton(
                  label: l.importPasteToggle,
                  icon: Icons.content_paste_rounded,
                  trailingIcon: _paste ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  variant: MadarButtonVariant.secondary,
                  expand: true,
                  sfx: _paste ? Sfx.sheetClose : Sfx.sheetOpen,
                  onPressed: () => setState(() => _paste = !_paste),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: context.motion(MadarMotion.medium),
          curve: MadarMotion.emphasized,
          alignment: AlignmentDirectional.topCenter,
          child: !_paste
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.only(top: Space.l),
                  child: GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _text,
                          minLines: 6,
                          maxLines: 12,
                          textDirection: TextDirection.ltr,
                          keyboardType: TextInputType.multiline,
                          style: text.bodySmall!.copyWith(color: t.textPrimary, height: 1.45),
                          cursorColor: t.accent,
                          decoration: InputDecoration(
                            hintText: l.importPasteHint,
                            hintStyle: text.bodySmall!.copyWith(color: t.textTertiary),
                            hintTextDirection: Directionality.of(context),
                            filled: true,
                            fillColor: t.space0.withValues(alpha: t.isDark ? 0.35 : 0.5),
                            contentPadding: const EdgeInsetsDirectional.all(Space.m),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(t.radiusS),
                              borderSide: BorderSide(color: t.glassBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(t.radiusS),
                              borderSide: BorderSide(color: t.glassBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(t.radiusS),
                              borderSide: BorderSide(color: t.accent, width: 1.2),
                            ),
                          ),
                        ),
                        const SizedBox(height: Space.m),
                        MadarButton(
                          label: l.importAnalyzeAction,
                          icon: Icons.auto_awesome_rounded,
                          onPressed: _text.text.trim().isEmpty
                              ? null
                              : () => controller.analyzeText(_text.text, labels: labels),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: Space.xl),
        ImportRise(
          index: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsetsDirectional.only(top: Space.xs),
                child: IslamicStar(size: 12),
              ),
              const SizedBox(width: Space.s),
              Expanded(
                child: Text(l.importAcceptedHint, style: text.bodySmall!.copyWith(color: t.textTertiary)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- busy --

class _BusyView extends StatelessWidget {
  const _BusyView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OrbitLoader(size: 88, semanticLabel: label),
            const SizedBox(height: Space.xl),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportingView extends StatelessWidget {
  const _ImportingView({required this.progress, required this.formats});

  final double progress;
  final ImportFormats formats;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.5,
                  child: Transform.rotate(
                    angle: progress * 3.14159,
                    child: const AstrolabeRing(size: 228, showNumerals: false),
                  ),
                ),
                ProgressRing(
                  value: progress,
                  size: 164,
                  strokeWidth: 10,
                  gradientEnd: t.highlight,
                  semanticLabel: l.importWriting,
                  child: Text(
                    formats.percent((progress * 100).roundToDouble()),
                    style: text.headlineMedium!.copyWith(color: t.gold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xl),
            Text(l.importWriting, style: text.titleMedium!.copyWith(color: t.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- done --

class _DoneView extends StatelessWidget {
  const _DoneView({required this.report, required this.formats});

  final ImportReport report;
  final ImportFormats formats;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final written = [
      for (final e in report.sections.entries)
        if ((e.value.inserted ?? 0) > 0) e,
    ];
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.xxl),
      children: [
        ImportRise(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Opacity(opacity: 0.6, child: GirihRosette(size: 236)),
                ProgressRing(
                  value: 1,
                  size: 150,
                  strokeWidth: 9,
                  color: t.success,
                  gradientEnd: t.gold,
                  semanticValue: l.importDoneTitle,
                  child: Icon(Icons.check_rounded, size: 64, color: t.success),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.l),
        ImportRise(
          index: 1,
          child: Column(
            children: [
              Text(l.importDoneTitle, style: text.headlineLarge!.copyWith(color: t.textPrimary), textAlign: TextAlign.center),
              const SizedBox(height: Space.s),
              Text(
                formats.digitsOf(l.importDoneBody(report.totalInserted)),
                style: text.titleMedium!.copyWith(color: t.gold),
                textAlign: TextAlign.center,
              ),
              if (report.totalExisting > 0) ...[
                const SizedBox(height: Space.xs),
                Text(
                  formats.digitsOf(l.importDoneExisting(report.totalExisting)),
                  style: text.bodyMedium!.copyWith(color: t.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        if (written.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          ImportRise(
            index: 2,
            child: GlassCard(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: Space.l, vertical: Space.s),
              child: LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth >= 300 ? 2 : 1;
                  final width = (box.maxWidth - Space.l * (columns - 1)) / columns;
                  return Wrap(
                    spacing: Space.l,
                    children: [
                      for (final e in written)
                        SizedBox(
                          width: width,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(vertical: Space.s),
                            child: Row(
                              children: [
                                Icon(e.key.icon, size: 16, color: e.key.color(t)),
                                const SizedBox(width: Space.s),
                                Expanded(
                                  child: Text(
                                    e.key.label(l),
                                    style: text.bodySmall!.copyWith(color: t.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: Space.xs),
                                Text(formats.count(e.value.inserted!), style: text.labelLarge!.copyWith(color: t.gold)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.l),
        ImportRise(
          index: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_rounded, size: 16, color: t.textTertiary),
              const SizedBox(width: Space.s),
              Flexible(
                child: Text(l.importDoneArchived, style: text.bodySmall!.copyWith(color: t.textTertiary)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sticky Done action of the summary.
class _DoneBar extends StatelessWidget {
  const _DoneBar({this.onDone});

  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.space0.withValues(alpha: 0), t.space0.withValues(alpha: t.isDark ? 0.92 : 0.85)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.l, Space.gutter, Space.m),
          child: ImportRise(
            index: 4,
            child: MadarButton(
              label: L10n.of(context).actionDone,
              icon: Icons.check_rounded,
              size: MadarButtonSize.large,
              expand: true,
              sfx: Sfx.complete,
              onPressed: onDone ?? () => Navigator.maybePop(context),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- failure --

class _FailureView extends ConsumerWidget {
  const _FailureView({required this.failure});

  final ImportFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final title = switch (failure) {
      ImportFailure.invalidJson => l.importErrorInvalidJson,
      ImportFailure.empty => l.importErrorEmpty,
      ImportFailure.notAnObject => l.importErrorNotObject,
      ImportFailure.unreadable => l.importErrorRead,
      ImportFailure.commitFailed => l.importErrorCommit,
    };
    return Center(
      child: SingleChildScrollView(
        child: AnimatedEmptyState(
          kind: EmptyStateKind.noData,
          title: title,
          body: l.importAcceptedHint,
          actionLabel: l.importTryAgain,
          actionIcon: Icons.refresh_rounded,
          onAction: ref.read(importControllerProvider.notifier).reset,
        ),
      ),
    );
  }
}
