import 'package:flutter/services.dart' show PlatformException, MissingPluginException;
import 'package:local_auth/local_auth.dart';
// AndroidAuthMessages lives in the endorsed Android implementation, which
// local_auth itself depends on (pubspec.yaml is not ours to change; the
// import only reaches a class local_auth already bundles).
// ignore: depend_on_referenced_packages
import 'package:local_auth_android/local_auth_android.dart' show AndroidAuthMessages;

/// Whether fingerprint / face unlock can be used right now.
enum BiometricAvailability {
  /// Hardware present and at least one biometric enrolled.
  available,

  /// Hardware present, nothing enrolled in the phone's settings.
  notEnrolled,

  /// No biometric hardware on this phone.
  noHardware,

  /// Hardware present but unusable right now (busy, security update …).
  unavailable,
}

/// How a biometric prompt ended.
enum BiometricOutcome {
  success,

  /// The user dismissed the prompt (or chose the negative button).
  cancelled,

  /// The system dismissed it (app backgrounded, another prompt …).
  interrupted,

  /// Too many attempts: biometrics are paused for ~30 seconds.
  lockedOut,

  /// Too many attempts: biometrics stay locked until the phone itself is
  /// unlocked with its screen lock.
  lockedOutPermanently,
  notEnrolled,
  noHardware,

  /// Hardware busy / temporarily unavailable / needs a security update.
  unavailable,

  /// Anything else (no activity, unknown error).
  error,

  /// Fingerprint unlock is switched off in Madar (no prompt was shown).
  disabled,
}

/// The texts of the system prompt, localised by the caller.
class BiometricPromptText {
  const BiometricPromptText({required this.reason, required this.title, required this.hint, required this.cancel});

  /// Why the app asks (shown as the prompt's description).
  final String reason;
  final String title;
  final String hint;
  final String cancel;
}

/// Biometric authentication (local_auth in the app; fakes in tests).
abstract interface class BiometricAuth {
  Future<BiometricAvailability> availability();

  /// Shows the system prompt (biometrics only – the Madar PIN is the
  /// fallback, not the phone's screen lock).
  Future<BiometricOutcome> authenticate(BiometricPromptText text);

  /// Dismisses a prompt in progress (best effort).
  Future<void> cancel();
}

/// Maps local_auth's error codes onto [BiometricOutcome].
BiometricOutcome biometricOutcomeFor(LocalAuthExceptionCode code) => switch (code) {
  LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.userRequestedFallback => BiometricOutcome.cancelled,
  LocalAuthExceptionCode.systemCanceled ||
  LocalAuthExceptionCode.timeout ||
  LocalAuthExceptionCode.authInProgress => BiometricOutcome.interrupted,
  LocalAuthExceptionCode.temporaryLockout => BiometricOutcome.lockedOut,
  LocalAuthExceptionCode.biometricLockout => BiometricOutcome.lockedOutPermanently,
  LocalAuthExceptionCode.noBiometricsEnrolled ||
  LocalAuthExceptionCode.noCredentialsSet => BiometricOutcome.notEnrolled,
  LocalAuthExceptionCode.noBiometricHardware => BiometricOutcome.noHardware,
  LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable => BiometricOutcome.unavailable,
  LocalAuthExceptionCode.deviceError ||
  LocalAuthExceptionCode.uiUnavailable ||
  LocalAuthExceptionCode.unknownError => BiometricOutcome.error,
};

/// [BiometricAuth] over the local_auth plugin (Android BiometricPrompt:
/// MainActivity is a FlutterFragmentActivity and the manifest declares
/// USE_BIOMETRIC).
class LocalAuthBiometricAuth implements BiometricAuth {
  LocalAuthBiometricAuth([LocalAuthentication? plugin]) : _auth = plugin ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<BiometricAvailability> availability() async {
    try {
      final hardware = await _auth.canCheckBiometrics;
      if (!hardware) return BiometricAvailability.noHardware;
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty ? BiometricAvailability.notEnrolled : BiometricAvailability.available;
    } on LocalAuthException catch (e) {
      return switch (biometricOutcomeFor(e.code)) {
        BiometricOutcome.noHardware => BiometricAvailability.noHardware,
        BiometricOutcome.notEnrolled => BiometricAvailability.notEnrolled,
        _ => BiometricAvailability.unavailable,
      };
    } on MissingPluginException {
      return BiometricAvailability.noHardware;
    } on PlatformException {
      return BiometricAvailability.unavailable;
    }
  }

  @override
  Future<BiometricOutcome> authenticate(BiometricPromptText text) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: text.reason,
        authMessages: [AndroidAuthMessages(signInTitle: text.title, signInHint: text.hint, cancelButton: text.cancel)],
        biometricOnly: true,
        // No extra "confirm" tap after face unlock: this is an unlock, not
        // a payment.
        sensitiveTransaction: false,
        persistAcrossBackgrounding: true,
      );
      return ok ? BiometricOutcome.success : BiometricOutcome.cancelled;
    } on LocalAuthException catch (e) {
      return biometricOutcomeFor(e.code);
    } on MissingPluginException {
      return BiometricOutcome.noHardware;
    } on PlatformException {
      return BiometricOutcome.error;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {
      // Nothing in progress / unsupported.
    }
  }
}
