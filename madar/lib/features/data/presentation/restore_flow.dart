import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../data/backup_service.dart';
import '../data/data_providers.dart';
import '../data/data_repository.dart';
import '../data/file_bridge.dart';
import '../domain/backup_format.dart';
import '../domain/data_areas.dart';
import 'widgets/data_widgets.dart';
import 'widgets/file_panel.dart';

/// Where the restore flow is.
enum RestoreStage { choose, unlock, opening, preview, restoring, done, failed }

/// Why the flow stopped (shown on the failure view).
enum RestoreFailure { notABackup, newerVersion, truncated, corrupted, unreadable, safetyCopyFailed, rejected }

/// Restores a `.madarbackup`: choose a file (or an on-device safety copy) →
/// passphrase → the file is verified and decrypted → preview of what is
/// inside → explicit confirmation → safety copy of the current data →
/// restore → done. Every failure before the last step changes nothing.
class RestoreFlow extends ConsumerStatefulWidget {
  const RestoreFlow({super.key, this.onRestored, this.onDone, this.debugState});

  /// Called after a successful restore (e.g. to reschedule reminders).
  final ValueChanged<RestoreResult>? onRestored;

  /// The Done button (defaults to popping the route).
  final VoidCallback? onDone;

  /// Starts at a given state (screenshots / tests only).
  @visibleForTesting
  final RestoreDebugState? debugState;

  @override
  ConsumerState<RestoreFlow> createState() => _RestoreFlowState();
}

/// A canned state for screenshots and tests.
@visibleForTesting
class RestoreDebugState {
  const RestoreDebugState({
    required this.stage,
    this.fileName,
    this.header,
    this.counts,
    this.currentCounts,
    this.failure,
    this.passError = false,
    this.result,
  });

  final RestoreStage stage;
  final String? fileName;
  final BackupHeader? header;
  final Map<String, int>? counts;
  final Map<String, int>? currentCounts;
  final RestoreFailure? failure;
  final bool passError;
  final RestoreResult? result;
}

class _RestoreFlowState extends ConsumerState<RestoreFlow> {
  RestoreStage _stage = RestoreStage.choose;
  final _pass = TextEditingController();
  Uint8List? _bytes;
  String? _fileName;
  BackupHeader? _header;
  OpenedBackup? _opened;
  Map<String, int>? _counts;
  Map<String, int>? _current;
  RestoreResult? _result;
  RestoreFailure? _failure;
  bool _passError = false;
  bool _understood = false;
  bool _savingSafety = true;

  @override
  void initState() {
    super.initState();
    final d = widget.debugState;
    if (d != null) {
      _stage = d.stage;
      _fileName = d.fileName;
      _header = d.header;
      _counts = d.counts;
      _current = d.currentCounts;
      _failure = d.failure;
      _passError = d.passError;
      _result = d.result;
    }
  }

  @override
  void dispose() {
    _opened?.dispose();
    _pass
      ..clear()
      ..dispose();
    super.dispose();
  }

  void _fail(RestoreFailure f) {
    Fx.fire(Sfx.error);
    if (!mounted) return;
    setState(() {
      _failure = f;
      _stage = RestoreStage.failed;
    });
  }

  static RestoreFailure _failureOf(BackupProblem p) => switch (p) {
    BackupProblem.notABackup => RestoreFailure.notABackup,
    BackupProblem.newerVersion => RestoreFailure.newerVersion,
    BackupProblem.truncated => RestoreFailure.truncated,
    BackupProblem.corrupted || BackupProblem.wrongPassphrase => RestoreFailure.corrupted,
  };

  void _reset() {
    _opened?.dispose();
    _pass.clear();
    setState(() {
      _opened = null;
      _bytes = null;
      _header = null;
      _fileName = null;
      _counts = null;
      _understood = false;
      _passError = false;
      _failure = null;
      _stage = RestoreStage.choose;
    });
  }

  void _accept(Uint8List bytes, String name) {
    try {
      final header = ref.read(backupServiceProvider).peek(bytes);
      Fx.fire(Sfx.sheetOpen);
      setState(() {
        _bytes = bytes;
        _fileName = name;
        _header = header;
        _passError = false;
        _stage = RestoreStage.unlock;
      });
    } on BackupException catch (e) {
      _fail(_failureOf(e.problem));
    }
  }

  Future<void> _pickFile() async {
    final PickedDataFile? picked;
    try {
      picked = await ref.read(dataFileBridgeProvider).pickFile();
    } catch (_) {
      _fail(RestoreFailure.unreadable);
      return;
    }
    if (picked == null || !mounted) return;
    _accept(picked.bytes, picked.name);
  }

  Future<void> _useSafetyCopy(SafetyCopy copy) async {
    try {
      _accept(await copy.file.readAsBytes(), copy.name);
    } catch (_) {
      _fail(RestoreFailure.unreadable);
    }
  }

  Future<void> _unlock() async {
    final bytes = _bytes;
    if (bytes == null || _pass.text.isEmpty) {
      Fx.fire(Sfx.error);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _passError = false;
      _stage = RestoreStage.opening;
    });
    final service = ref.read(backupServiceProvider);
    try {
      final opened = await service.open(bytes, _pass.text, fileName: _fileName);
      final current = await service.currentCounts();
      if (!mounted) {
        opened.dispose();
        return;
      }
      _pass.clear();
      Fx.fire(Sfx.sparkle);
      setState(() {
        _opened = opened;
        _counts = opened.counts;
        _current = current;
        _understood = false;
        _stage = RestoreStage.preview;
      });
    } on BackupException catch (e) {
      if (e.problem == BackupProblem.wrongPassphrase) {
        Fx.fire(Sfx.error);
        if (mounted) {
          setState(() {
            _passError = true;
            _stage = RestoreStage.unlock;
          });
        }
      } else {
        _fail(_failureOf(e.problem));
      }
    } catch (_) {
      _fail(RestoreFailure.corrupted);
    }
  }

  Future<void> _restore() async {
    final opened = _opened;
    if (opened == null || !_understood) return;
    setState(() {
      _savingSafety = true;
      _stage = RestoreStage.restoring;
    });
    final service = ref.read(backupServiceProvider);
    try {
      final result = await service.restore(
        opened,
        onPhase: (phase) {
          if (mounted) setState(() => _savingSafety = phase == RestorePhase.safetyCopy);
        },
      );
      opened.dispose();
      _opened = null;
      if (!mounted) return;
      Fx.fire(Sfx.levelUp);
      setState(() {
        _result = result;
        _stage = RestoreStage.done;
      });
      ref.invalidate(safetyCopiesProvider);
      widget.onRestored?.call(result);
    } on RestoreException catch (e) {
      _fail(e.problem == RestoreProblem.safetyCopyFailed ? RestoreFailure.safetyCopyFailed : RestoreFailure.rejected);
    } catch (_) {
      _fail(RestoreFailure.rejected);
    }
  }

  Future<void> _shareSafetyCopy() async {
    final r = _result;
    if (r == null) return;
    final l = L10n.of(context);
    try {
      final bytes = await r.safetyCopy.file.readAsBytes();
      if (!mounted) return;
      await showDataFileSheet(
        context,
        title: l.dataSafetyCopyTitle,
        file: DataFile(name: r.safetyCopy.name, bytes: bytes, mimeType: madarBackupMimeType, encrypted: true),
      );
    } catch (_) {
      Fx.fire(Sfx.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final Widget body = switch (_stage) {
      RestoreStage.choose => _ChooseView(onPick: _pickFile, onSafetyCopy: _useSafetyCopy),
      RestoreStage.unlock => _UnlockView(
        fileName: _fileName ?? '',
        header: _header,
        controller: _pass,
        passError: _passError,
        onUnlock: _unlock,
        onBack: _reset,
      ),
      RestoreStage.opening => Center(child: DataBusy(title: l.dataRestoreOpening, body: l.dataRestoreOpeningHint)),
      RestoreStage.preview => _PreviewView(
        header: _header,
        counts: _counts ?? const {},
        current: _current ?? const {},
        understood: _understood,
        onUnderstood: (v) => setState(() => _understood = v),
        onRestore: _restore,
        onCancel: _reset,
      ),
      RestoreStage.restoring => Center(
        child: DataBusy(
          title: _savingSafety ? l.dataRestoreSavingSafety : l.dataRestoreRestoring,
          body: l.dataRestoreKeepOpen,
        ),
      ),
      RestoreStage.done => _DoneView(
        result: _result,
        onDone: widget.onDone ?? () => Navigator.of(context).maybePop(),
        onShareSafety: _shareSafetyCopy,
      ),
      RestoreStage.failed => _FailedView(failure: _failure ?? RestoreFailure.corrupted, onRetry: _reset),
    };

    final busy = _stage == RestoreStage.opening || _stage == RestoreStage.restoring;
    return PopScope(
      canPop: !busy,
      child: MadarScaffold(
        title: l.dataRestoreFlowTitle,
        showBack: !busy,
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
          child: KeyedSubtree(key: ValueKey(_stage), child: body),
        ),
      ),
    );
  }
}

EdgeInsetsGeometry get _pagePadding => const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxl);

// -------------------------------------------------------------- choose --

class _ChooseView extends ConsumerWidget {
  const _ChooseView({required this.onPick, required this.onSafetyCopy});

  final VoidCallback onPick;
  final ValueChanged<SafetyCopy> onSafetyCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final copies = ref.watch(safetyCopiesProvider).value ?? const <SafetyCopy>[];
    return ListView(
      padding: _pagePadding,
      children: [
        GlassPanel(
          padding: const EdgeInsetsDirectional.all(Space.xl),
          child: Column(
            children: [
              const DataEmblem(icon: Icons.settings_backup_restore_rounded),
              const SizedBox(height: Space.l),
              Text(l.dataRestoreChooseTitle, textAlign: TextAlign.center, style: text.headlineSmall!.copyWith(color: t.textPrimary)),
              const SizedBox(height: Space.s),
              Text(
                l.dataRestoreChooseBody(BidiIsolate.ltr('.$madarBackupExtension')),
                textAlign: TextAlign.center,
                style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.5),
              ),
              const SizedBox(height: Space.xl),
              MadarButton(
                label: l.dataRestorePickFile,
                icon: Icons.file_open_rounded,
                size: MadarButtonSize.large,
                expand: true,
                onPressed: onPick,
              ),
            ],
          ),
        ),
        if (copies.isNotEmpty) ...[
          SectionHeader(
            title: l.dataSafetyCopiesTitle,
            subtitle: l.dataSafetyCopiesHint,
            padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
          ),
          DataGroup(
            children: [
              for (final c in copies)
                DataTile(
                  icon: Icons.history_rounded,
                  iconColor: t.gold,
                  title: '${fmt.formatDate(c.createdAt.toLocal())} · ${fmt.formatTime(c.createdAt.toLocal())}',
                  subtitle: formatDataSize(l, fmt, c.size),
                  onTap: () => onSafetyCopy(c),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.l),
        DataNote(text: l.dataRestoreNothingChanges, icon: Icons.shield_outlined),
      ],
    );
  }
}

// -------------------------------------------------------------- unlock --

class _UnlockView extends StatelessWidget {
  const _UnlockView({
    required this.fileName,
    required this.header,
    required this.controller,
    required this.passError,
    required this.onUnlock,
    required this.onBack,
  });

  final String fileName;
  final BackupHeader? header;
  final TextEditingController controller;
  final bool passError;
  final VoidCallback onUnlock;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final created = header?.createdAt.toLocal();
    return ListView(
      padding: _pagePadding,
      children: [
        GlassPanel(
          padding: const EdgeInsetsDirectional.all(Space.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DataIconBadge(Icons.lock_rounded, color: t.success, size: 44),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          BidiIsolate.ltr(fileName),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall!.copyWith(color: t.textPrimary),
                        ),
                        if (created != null)
                          Text(
                            l.dataBackupMadeOn('${fmt.formatDate(created)} · ${fmt.formatTime(created)}'),
                            style: text.bodySmall!.copyWith(color: t.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.xl),
              Text(l.dataRestoreUnlockBody, style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.5)),
              const SizedBox(height: Space.l),
              PassphraseField(
                controller: controller,
                label: l.dataPassphraseLabel,
                autofocus: true,
                error: passError ? l.dataErrWrongPassphrase : null,
                onSubmitted: (_) => onUnlock(),
              ),
              const SizedBox(height: Space.xl),
              MadarButton(
                label: l.dataRestoreUnlockAction,
                icon: Icons.lock_open_rounded,
                size: MadarButtonSize.large,
                expand: true,
                onPressed: onUnlock,
              ),
              const SizedBox(height: Space.s),
              MadarButton(
                label: l.dataRestoreOtherFile,
                variant: MadarButtonVariant.ghost,
                expand: true,
                sfx: Sfx.back,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- preview --

String dataAreaLabel(L10n l, DataArea a) => switch (a) {
  DataArea.faith => l.dataSumFaith,
  DataArea.health => l.dataSumHealth,
  DataArea.money => l.dataSumMoney,
  DataArea.family => l.dataSumFamily,
  DataArea.work => l.dataSumWork,
  DataArea.growth => l.dataSumGrowth,
  DataArea.body => l.dataSumBody,
  DataArea.travel => l.dataSumTravel,
  DataArea.custom => l.dataSumCustom,
  DataArea.other => l.dataAreaOther,
};

IconData dataAreaIcon(DataArea a) => switch (a) {
  DataArea.faith => Icons.mosque_outlined,
  DataArea.health => Icons.favorite_border_rounded,
  DataArea.money => Icons.account_balance_wallet_outlined,
  DataArea.family => Icons.diversity_3_rounded,
  DataArea.work => Icons.work_outline_rounded,
  DataArea.growth => Icons.spa_outlined,
  DataArea.body => Icons.fitness_center_rounded,
  DataArea.travel => Icons.flight_takeoff_rounded,
  DataArea.custom => Icons.dashboard_customize_outlined,
  DataArea.other => Icons.tune_rounded,
};

class _PreviewView extends StatelessWidget {
  const _PreviewView({
    required this.header,
    required this.counts,
    required this.current,
    required this.understood,
    required this.onUnderstood,
    required this.onRestore,
    required this.onCancel,
  });

  final BackupHeader? header;
  final Map<String, int> counts;
  final Map<String, int> current;
  final bool understood;
  final ValueChanged<bool> onUnderstood;
  final VoidCallback onRestore;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final areas = DataAreas.totals(counts);
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final now = current.values.fold<int>(0, (a, b) => a + b);
    final created = header?.createdAt.toLocal();
    return ListView(
      padding: _pagePadding,
      children: [
        GlassPanel(
          padding: const EdgeInsetsDirectional.all(Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  DataIconBadge(Icons.verified_rounded, color: t.success, size: 44),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.dataRestorePreviewTitle, style: text.titleMedium!.copyWith(color: t.textPrimary)),
                        if (created != null)
                          Text(
                            l.dataBackupMadeOn('${fmt.formatDate(created)} · ${fmt.formatTime(created)}'),
                            style: text.bodySmall!.copyWith(color: t.textSecondary),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.l),
              Row(
                children: [
                  Expanded(
                    child: StatTile(label: l.dataRestoreInBackup, value: fmt.formatInt(total), icon: Icons.inventory_2_outlined),
                  ),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: StatTile(
                      label: l.dataRestoreOnPhone,
                      value: fmt.formatInt(now),
                      icon: Icons.smartphone_rounded,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(
          title: l.dataRestoreWhatsInside,
          padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
        ),
        DataGroup(
          children: [
            for (final a in DataArea.values)
              if (areas[a]! > 0)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s + 2, Space.l, Space.s + 2),
                  child: Row(
                    children: [
                      DataIconBadge(dataAreaIcon(a), size: 32),
                      const SizedBox(width: Space.m),
                      Expanded(child: Text(dataAreaLabel(l, a), style: text.bodyMedium!.copyWith(color: t.textPrimary))),
                      Text(
                        recordsText(l, fmt, areas[a]!),
                        style: text.bodySmall!.copyWith(color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
          ],
        ),
        const SizedBox(height: Space.l),
        GlassPanel(
          tint: t.danger.withValues(alpha: 0.08),
          borderColor: t.danger.withValues(alpha: 0.35),
          glowColor: t.danger.withValues(alpha: 0.2),
          padding: const EdgeInsetsDirectional.all(Space.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: t.warning, size: 22),
                  const SizedBox(width: Space.s),
                  Expanded(
                    child: Text(
                      l.dataRestoreReplaceWarning,
                      style: text.bodyMedium!.copyWith(color: t.textPrimary, height: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.m),
              MadarPressable(
                onTap: () => onUnderstood(!understood),
                sfx: null,
                semanticLabel: l.dataRestoreUnderstand,
                toggled: understood,
                excludeChildSemantics: true,
                child: Row(
                  children: [
                    Expanded(child: Text(l.dataRestoreUnderstand, style: text.bodyMedium!.copyWith(color: t.textPrimary))),
                    const SizedBox(width: Space.s),
                    MadarSwitch(value: understood, onChanged: onUnderstood, activeColor: t.danger),
                  ],
                ),
              ),
              const SizedBox(height: Space.l),
              MadarButton(
                label: l.dataRestoreConfirmAction,
                icon: Icons.restore_rounded,
                variant: MadarButtonVariant.danger,
                size: MadarButtonSize.large,
                expand: true,
                onPressed: understood ? onRestore : null,
              ),
              const SizedBox(height: Space.s),
              MadarButton(
                label: l.dataCancelAction,
                variant: MadarButtonVariant.ghost,
                expand: true,
                sfx: Sfx.back,
                onPressed: onCancel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- done --

class _DoneView extends StatelessWidget {
  const _DoneView({required this.result, required this.onDone, required this.onShareSafety});

  final RestoreResult? result;
  final VoidCallback onDone;
  final VoidCallback onShareSafety;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final fmt = context.formatter;
    final r = result;
    return ListView(
      padding: _pagePadding,
      children: [
        GlassPanel(
          padding: const EdgeInsetsDirectional.all(Space.xl),
          glowColor: t.success.withValues(alpha: 0.35),
          child: Column(
            children: [
              DataEmblem(icon: Icons.check_rounded, color: t.success),
              const SizedBox(height: Space.l),
              Text(l.dataRestoreDoneTitle, textAlign: TextAlign.center, style: text.headlineSmall!.copyWith(color: t.textPrimary)),
              const SizedBox(height: Space.s),
              if (r != null)
                Text(
                  l.dataRestoreDoneBody(fmt.formatInt(r.restoredRecords)),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.5),
                ),
              const SizedBox(height: Space.l),
              DataNote(text: l.dataRestoreSafetyKept, icon: Icons.history_rounded, color: t.gold),
              const SizedBox(height: Space.xl),
              MadarButton(label: l.dataDoneAction, size: MadarButtonSize.large, expand: true, sfx: Sfx.complete, onPressed: onDone),
              const SizedBox(height: Space.s),
              MadarButton(
                label: l.dataSafetyCopySave,
                icon: Icons.save_alt_rounded,
                variant: MadarButtonVariant.secondary,
                expand: true,
                onPressed: r == null ? null : onShareSafety,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------- failed --

class _FailedView extends StatelessWidget {
  const _FailedView({required this.failure, required this.onRetry});

  final RestoreFailure failure;
  final VoidCallback onRetry;

  static (String, String) texts(L10n l, RestoreFailure f) => switch (f) {
    RestoreFailure.notABackup => (l.dataErrNotBackupTitle, l.dataErrNotBackupBody(BidiIsolate.ltr('.$madarBackupExtension'))),
    RestoreFailure.newerVersion => (l.dataErrNewerTitle, l.dataErrNewerBody),
    RestoreFailure.truncated => (l.dataErrTruncatedTitle, l.dataErrTruncatedBody),
    RestoreFailure.corrupted => (l.dataErrCorruptedTitle, l.dataErrCorruptedBody),
    RestoreFailure.unreadable => (l.dataErrUnreadableTitle, l.dataErrUnreadableBody),
    RestoreFailure.safetyCopyFailed => (l.dataErrSafetyTitle, l.dataErrSafetyBody),
    RestoreFailure.rejected => (l.dataErrRejectedTitle, l.dataErrRejectedBody),
  };

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (title, body) = texts(l, failure);
    return ListView(
      padding: _pagePadding,
      children: [
        GlassPanel(
          padding: const EdgeInsetsDirectional.all(Space.xl),
          child: Column(
            children: [
              DataEmblem(
                icon: failure == RestoreFailure.newerVersion ? Icons.system_update_rounded : Icons.report_gmailerrorred_rounded,
                color: failure == RestoreFailure.newerVersion ? t.info : t.warning,
              ),
              const SizedBox(height: Space.l),
              Semantics(
                liveRegion: true,
                child: Text(title, textAlign: TextAlign.center, style: text.headlineSmall!.copyWith(color: t.textPrimary)),
              ),
              const SizedBox(height: Space.s),
              Text(body, textAlign: TextAlign.center, style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.5)),
              const SizedBox(height: Space.l),
              DataNote(text: l.dataNothingChanged, icon: Icons.shield_outlined, color: t.success),
              const SizedBox(height: Space.xl),
              MadarButton(
                label: l.dataRestoreOtherFile,
                icon: Icons.file_open_rounded,
                size: MadarButtonSize.large,
                expand: true,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
