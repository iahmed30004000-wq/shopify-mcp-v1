import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/repositories/repositories.dart';
import '../../../core/design/tokens.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../data/data_providers.dart';
import '../data/data_repository.dart';
import '../domain/passphrase_strength.dart';
import 'widgets/data_widgets.dart';
import 'widgets/file_panel.dart';

/// `key_values` key: when a backup last left the phone (shared or saved).
const String lastBackupKey = 'data.lastBackupAt';

/// Opens the encrypted-backup sheet: passphrase (with a strength meter) →
/// sealing → the ready file to share or save.
Future<void> showBackupSheet(BuildContext context) =>
    showInteractionSheet<void>(context, builder: (_) => const BackupSheet());

enum _BackupStage { form, working, ready, failed }

/// Creates a `.madarbackup` file. The passphrase lives only in this sheet's
/// text fields and is cleared when the sheet closes.
class BackupSheet extends ConsumerStatefulWidget {
  const BackupSheet({super.key, this.initialPassphrase});

  /// Pre-filled passphrase (screenshots / tests only).
  @visibleForTesting
  final String? initialPassphrase;

  @override
  ConsumerState<BackupSheet> createState() => _BackupSheetState();
}

class _BackupSheetState extends ConsumerState<BackupSheet> {
  late final TextEditingController _pass = TextEditingController(text: widget.initialPassphrase);
  late final TextEditingController _confirm = TextEditingController(text: widget.initialPassphrase);
  final _confirmFocus = FocusNode();
  _BackupStage _stage = _BackupStage.form;
  DataFile? _file;
  PassphraseCheck _check = const PassphraseCheck(level: PassphraseLevel.empty, bits: 0, length: 0);
  bool _confirmTouched = false;

  @override
  void initState() {
    super.initState();
    _check = PassphraseStrength.evaluate(_pass.text);
    _pass.addListener(_onPass);
    _confirm.addListener(_onConfirm);
  }

  void _onPass() {
    final next = PassphraseStrength.evaluate(_pass.text);
    if (next.level != _check.level && next.level.index > _check.level.index) Fx.fire(Sfx.countTick);
    setState(() => _check = next);
  }

  void _onConfirm() => setState(() => _confirmTouched = _confirmTouched || _confirm.text.isNotEmpty);

  @override
  void dispose() {
    // Never leave the passphrase behind in memory longer than needed.
    _pass
      ..removeListener(_onPass)
      ..clear()
      ..dispose();
    _confirm
      ..removeListener(_onConfirm)
      ..clear()
      ..dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool get _matches => _pass.text == _confirm.text;
  bool get _canCreate => _check.acceptable && _matches;

  Future<void> _create() async {
    if (!_canCreate) {
      Fx.fire(Sfx.error);
      setState(() => _confirmTouched = true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _stage = _BackupStage.working);
    final passphrase = _pass.text;
    try {
      final file = await ref.read(backupServiceProvider).create(passphrase);
      if (!mounted) return;
      _pass.clear();
      _confirm.clear();
      Fx.fire(Sfx.complete);
      setState(() {
        _file = file;
        _stage = _BackupStage.ready;
      });
    } catch (e) {
      debugPrint('backup failed: ${e.runtimeType}');
      if (!mounted) return;
      Fx.fire(Sfx.error);
      setState(() => _stage = _BackupStage.failed);
    }
  }

  Future<void> _delivered(DataDelivery _) async {
    try {
      await ref.read(repositoriesProvider).keyValues.setJson(lastBackupKey, ref.read(dataClockProvider)().toUtc().toIso8601String());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final Widget body = switch (_stage) {
      _BackupStage.form => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.dataBackupSheetBody, style: text.bodyMedium!.copyWith(color: t.textSecondary, height: 1.5)),
          const SizedBox(height: Space.l),
          PassphraseField(
            controller: _pass,
            label: l.dataPassphraseLabel,
            autofocus: widget.initialPassphrase == null,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _confirmFocus.requestFocus(),
          ),
          const SizedBox(height: Space.m),
          PassphraseStrengthMeter(check: _check),
          const SizedBox(height: Space.l),
          PassphraseField(
            controller: _confirm,
            focusNode: _confirmFocus,
            label: l.dataPassphraseConfirmLabel,
            error: _confirmTouched && _confirm.text.isNotEmpty && !_matches ? l.dataPassphraseMismatch : null,
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: Space.l),
          DataNote(text: l.dataPassphraseNeverStored, icon: Icons.key_rounded, color: t.gold),
        ],
      ),
      _BackupStage.working => DataBusy(title: l.dataBackupWorking, body: l.dataBackupWorkingHint),
      _BackupStage.ready => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DataFilePanel(file: _file!, subject: l.dataBackupShareSubject, onDelivered: _delivered),
          const SizedBox(height: Space.l),
          DataNote(text: l.dataBackupReadyHint, icon: Icons.tips_and_updates_outlined),
        ],
      ),
      _BackupStage.failed => Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: Space.l),
        child: DataNote(text: l.dataBackupFailed, icon: Icons.error_outline_rounded, color: t.danger),
      ),
    };

    final Widget? footer = switch (_stage) {
      _BackupStage.form => SheetButton(
        label: l.dataBackupCreateAction,
        icon: Icons.lock_rounded,
        primary: true,
        enabled: _canCreate,
        onPressed: _create,
        onDisabledTap: () {
          Fx.fire(Sfx.error);
          setState(() => _confirmTouched = true);
        },
      ),
      _BackupStage.working => null,
      _BackupStage.ready => SheetButton(label: l.dataDoneAction, onPressed: () => Navigator.of(context).maybePop()),
      _BackupStage.failed => SheetButton(
        label: l.dataTryAgainAction,
        primary: true,
        onPressed: () => setState(() => _stage = _BackupStage.form),
      ),
    };

    return PopScope(
      canPop: _stage != _BackupStage.working,
      child: InteractionSheetFrame(
        title: _stage == _BackupStage.ready ? l.dataBackupReadyTitle : l.dataBackupSheetTitle,
        subtitle: _stage == _BackupStage.ready ? l.dataBackupReadySubtitle : l.dataBackupSheetSubtitle,
        icon: _stage == _BackupStage.ready ? Icons.verified_user_rounded : Icons.lock_rounded,
        body: AnimatedSwitcher(
          duration: context.motion(MadarMotion.medium),
          switchInCurve: MadarMotion.decelerate,
          switchOutCurve: MadarMotion.accelerate,
          child: KeyedSubtree(key: ValueKey(_stage), child: body),
        ),
        footer: footer,
      ),
    );
  }
}
