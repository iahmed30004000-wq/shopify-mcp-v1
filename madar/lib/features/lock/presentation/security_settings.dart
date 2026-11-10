import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart' show showInteractionSheet, InteractionSheetFrame, SheetButton;
import '../../../core/motion/motion.dart';
import '../../../core/sound/sound_api.dart';
import '../../settings/widgets/settings_widgets.dart';
import '../application/lock_controller.dart';
import '../data/biometric_auth.dart';
import '../domain/pin_hash.dart';
import 'lock_texts.dart';
import 'pin_sheets.dart';

/// Settings › Security: app lock on/off, fingerprint unlock, change or
/// remove the PIN, and how long the app may stay in the background before
/// it locks. Turning the lock or fingerprint on or off always requires the
/// owner (fingerprint or PIN); a first PIN is chosen on a sheet.
///
/// Drop it into the settings list like any `SettingsSection`.
class SecuritySettingsSection extends ConsumerStatefulWidget {
  const SecuritySettingsSection({super.key, this.seed = 0.45, this.showTitle = true});

  /// Off on the security page itself, whose app bar already names it.
  final bool showTitle;

  /// Glass sheen seed of the section's panel.
  final double seed;

  @override
  ConsumerState<SecuritySettingsSection> createState() => _SecuritySettingsSectionState();
}

class _SecuritySettingsSectionState extends ConsumerState<SecuritySettingsSection> {
  bool _busy = false;
  String? _notice;
  bool _noticeIsError = false;

  LockController get _lock => ref.read(lockControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    // The secure record (PIN length, fingerprint switch) – read lazily.
    unawaited(_lock.load());
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        Fx.fire(Sfx.error);
        setState(() {
          _notice = L10n.of(context).lockSettingsSaveFailed;
          _noticeIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String? message, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _notice = message;
      _noticeIsError = error;
    });
  }

  bool get _bioAvailable => ref.read(biometricAvailabilityProvider).value == BiometricAvailability.available;

  Future<void> _toggleLock(bool on) => _run(() async {
    final lock = ref.read(lockControllerProvider);
    if (on && !lock.hasPin) {
      final result = await showPinSetupSheet(context);
      if (result == null) return;
      await _lock.setPin(result.pin, biometrics: result.biometrics ?? false);
      Fx.fire(Sfx.complete);
      if (mounted) _say(L10n.of(context).lockPinSaved);
      return;
    }
    if (!await confirmLockIdentity(context, ref)) return;
    await _lock.setEnabled(on);
  });

  Future<void> _toggleBiometrics(bool on) => _run(() async {
    final l = L10n.of(context);
    if (on) {
      final outcome = await _lock.authenticateWithBiometrics(
        LockTexts.settingsPrompt(l),
        unlock: false,
        enrolling: true,
      );
      if (outcome != BiometricOutcome.success) {
        final m = LockTexts.biometricMessage(l, outcome);
        if (m != null) {
          Fx.fire(Sfx.error);
          _say(m, error: true);
        }
        return;
      }
      await _lock.setBiometrics(true);
      return;
    }
    if (!await confirmLockIdentity(context, ref)) return;
    await _lock.setBiometrics(false);
  });

  Future<void> _changePin() => _run(() async {
    final result = await showPinSetupSheet(context, mode: PinSetupMode.change);
    if (result == null) return;
    await _lock.setPin(result.pin);
    Fx.fire(Sfx.complete);
    if (mounted) _say(L10n.of(context).lockPinChanged);
  });

  Future<void> _removePin() => _run(() async {
    final sure = await showInteractionSheet<bool>(context, builder: (_) => const _RemovePinSheet());
    if (sure != true || !mounted) return;
    if (!await confirmLockIdentity(context, ref)) return;
    await _lock.removePin();
    Fx.fire(Sfx.delete);
  });

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final fmt = context.formatter;
    final lock = ref.watch(lockControllerProvider);
    final availability = ref.watch(biometricAvailabilityProvider).value;
    final hasSensor = availability != null && availability != BiometricAvailability.noHardware;
    final bioSubtitle = switch (availability) {
      BiometricAvailability.notEnrolled => l.lockSettingsBiometricNotEnrolled,
      BiometricAvailability.unavailable => l.lockSettingsBiometricUnavailable,
      _ => l.lockSettingsBiometricHint,
    };
    final after = _nearestChoice(lock.lockAfter);
    final text = Theme.of(context).textTheme;

    return SettingsSection(
      title: widget.showTitle ? l.lockSettingsTitle : null,
      seed: widget.seed,
      children: [
        SettingsSwitchTile(
          icon: lock.armed ? Icons.lock_rounded : Icons.lock_open_rounded,
          title: l.lockSettingsLock,
          subtitle: lock.armed ? l.lockSettingsLockOn : l.lockSettingsLockOff,
          value: lock.armed,
          onChanged: _busy ? null : (v) => unawaited(_toggleLock(v)),
        ),
        if (lock.hasPin && hasSensor)
          SettingsSwitchTile(
            icon: Icons.fingerprint_rounded,
            title: l.lockSettingsBiometric,
            subtitle: bioSubtitle,
            value: lock.biometrics && _bioAvailable,
            onChanged: _busy || !_bioAvailable ? null : (v) => unawaited(_toggleBiometrics(v)),
          ),
        if (lock.hasPin)
          SettingsTile(
            icon: Icons.password_rounded,
            title: l.lockSettingsChangePin,
            subtitle: l.lockSettingsChangePinHint(fmt.formatInt(PinRules.minLength), fmt.formatInt(PinRules.maxLength)),
            navigates: true,
            onTap: _busy ? null : () => unawaited(_changePin()),
          ),
        if (lock.armed)
          SettingsChoiceTile<Duration>(
            icon: Icons.timer_outlined,
            title: l.lockSettingsLockAfter,
            subtitle: l.lockSettingsLockAfterHint,
            selected: after,
            options: [for (final d in lockAfterChoices) ChoiceOption(value: d, label: LockTexts.lockAfter(l, fmt, d))],
            onChanged: (d) => unawaited(_lock.setLockAfter(d)),
          ),
        if (lock.hasPin)
          SettingsTile(
            icon: Icons.no_encryption_gmailerrorred_rounded,
            iconColor: t.danger,
            title: l.lockSettingsRemovePin,
            subtitle: l.lockSettingsRemovePinHint,
            onTap: _busy ? null : () => unawaited(_removePin()),
          ),
        AnimatedSize(
          duration: context.motion(MadarMotion.short),
          alignment: AlignmentDirectional.topCenter,
          child: _notice == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.l, 0),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _notice!,
                      style: text.bodySmall!.copyWith(color: _noticeIsError ? t.danger : t.success, height: 1.4),
                    ),
                  ),
                ),
        ),
        SettingsNote(l.lockSettingsNote, icon: Icons.shield_outlined),
      ],
    );
  }

  static Duration _nearestChoice(Duration d) {
    var best = lockAfterChoices.first;
    for (final c in lockAfterChoices) {
      if ((c - d).abs() < (best - d).abs()) best = c;
    }
    return best;
  }
}

class _RemovePinSheet extends StatelessWidget {
  const _RemovePinSheet();

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    return InteractionSheetFrame(
      title: l.lockRemoveTitle,
      icon: Icons.no_encryption_gmailerrorred_rounded,
      body: Text(l.lockRemoveBody, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: t.textSecondary)),
      footer: Row(
        children: [
          Expanded(
            child: SheetButton(
              label: l.lockForgotBack,
              sfx: Sfx.back,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: SheetButton(
              label: l.lockRemoveConfirm,
              primary: true,
              tone: t.danger,
              sfx: Sfx.delete,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ),
        ],
      ),
    );
  }
}
