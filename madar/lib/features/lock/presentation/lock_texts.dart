import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../application/lock_controller.dart';
import '../data/biometric_auth.dart';

/// Localised texts shared by the lock screen and the security settings.
abstract final class LockTexts {
  /// The system prompt on the lock screen; its negative button switches to
  /// the PIN when one exists.
  static BiometricPromptText unlockPrompt(L10n l, {bool pinFallback = true}) => BiometricPromptText(
    reason: l.lockPromptReason,
    title: l.lockPromptTitle,
    hint: l.lockPromptHint,
    cancel: pinFallback ? l.lockPromptCancel : l.lockPromptCancelPlain,
  );

  /// The system prompt confirming a change in Settings.
  static BiometricPromptText settingsPrompt(L10n l) => BiometricPromptText(
    reason: l.lockPromptSettingsReason,
    title: l.lockConfirmTitle,
    hint: l.lockPromptHint,
    cancel: l.lockUsePin,
  );

  /// What to tell the owner after a biometric [outcome] (null: nothing).
  static String? biometricMessage(L10n l, BiometricOutcome outcome) => switch (outcome) {
    BiometricOutcome.success || BiometricOutcome.cancelled || BiometricOutcome.disabled => null,
    BiometricOutcome.interrupted => l.lockBioInterrupted,
    BiometricOutcome.lockedOut => l.lockBioLockedOut,
    BiometricOutcome.lockedOutPermanently => l.lockBioLockedOutPermanently,
    BiometricOutcome.notEnrolled => l.lockBioNotEnrolled,
    BiometricOutcome.noHardware => l.lockBioNoHardware,
    BiometricOutcome.unavailable => l.lockBioUnavailable,
    BiometricOutcome.error => l.lockBioError,
  };

  /// Whether [outcome] means the fingerprint can't be used for now (the
  /// lock screen then switches to the PIN).
  static bool biometricBlocked(BiometricOutcome outcome) => switch (outcome) {
    BiometricOutcome.lockedOut ||
    BiometricOutcome.lockedOutPermanently ||
    BiometricOutcome.notEnrolled ||
    BiometricOutcome.noHardware ||
    BiometricOutcome.unavailable ||
    BiometricOutcome.disabled => true,
    _ => false,
  };

  /// The message after a PIN [result] (null when accepted or busy).
  static String? pinMessage(L10n l, MadarFormatter fmt, PinCheckResult result) => switch (result.check) {
    PinCheck.accepted || PinCheck.busy => null,
    PinCheck.wrong => l.lockPinWrong(result.remaining, fmt.formatInt(result.remaining)),
    PinCheck.lockedOut => lockedOut(l, fmt, result.lockout),
    PinCheck.unavailable => l.lockStorageError,
  };

  /// "Try again in 27 seconds" / "… in m:ss".
  static String lockedOut(L10n l, MadarFormatter fmt, Duration wait) {
    final seconds = (wait.inMilliseconds / 1000).ceil();
    if (seconds < 60) return l.lockLockedOut(l.lockSeconds(seconds, fmt.formatInt(seconds)));
    return l.lockLockedOut(fmt.isolate(fmt.formatDuration(Duration(seconds: seconds), seconds: true)));
  }

  /// A "lock after" choice's label.
  static String lockAfter(L10n l, MadarFormatter fmt, Duration d) =>
      d == Duration.zero ? l.lockAfterImmediately : l.lockAfterMinutes(d.inMinutes, fmt.formatInt(d.inMinutes));
}
