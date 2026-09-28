import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/design/widgets/shader_cache.dart';
import '../core/settings/app_settings.dart';
import '../core/sound/haptics.dart';
import '../core/sound/profiles.dart';
import '../core/sound/soloud_sound_service.dart';
import '../core/sound/sound_api.dart';
import '../features/orbit/presentation/orbit_ui_providers.dart' show OrbitWarmUp;
import 'app.dart';
import 'app_preferences.dart';
import 'app_services.dart';
import 'licenses.dart';
import 'suspending_flows.dart';

/// Starts Madar.
///
/// 1. Error hooks (log in debug builds only – nothing leaves the device).
/// 2. Edge-to-edge system UI with transparent bars; portrait only for now.
/// 3. Shader programs start loading (surfaces paint a gradient until then)
///    and the Astrolabe Orbit's programs are compiled and warmed up, so the
///    splash hides the work and the first orbit frame never stutters.
/// 4. UI preferences are read from SharedPreferences (theme, language …) –
///    the encrypted database opens later, behind the splash (see AppGate).
/// 5. The sound engine and haptics are constructed and [Fx] is installed;
///    the audio device opens after the first frame so it never delays it
///    (the service falls back to silence if audio is unavailable).
/// 6. After the first frame, while the splash is up: the time-zone database
///    and the notifications plugin (launch details – was Madar opened by an
///    adhan?) are prepared ([warmUpServices]). Failures only log: without
///    notifications the app still runs. The adhan planner, prayer quiet,
///    adhkar reminders and notification routing start once the encrypted
///    database is open (`AppGate`); the app lock is the default
///    `lockGateProvider` (`BiometricLockGate`).
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  installErrorHooks();
  MadarLicenses.register();
  await _configureSystemUi();
  unawaited(MadarShaders.preload());
  // Orbit shaders compile while the database unlocks behind the splash.
  unawaited(OrbitWarmUp.start());

  final prefs = await SharedPreferences.getInstance();
  final settings = _readSettings(prefs);
  final brightness = PlatformDispatcher.instance.platformBrightness;

  final sound = SoloudSoundService(profileId: SoundProfiles.idForTheme(settings.effectiveTheme(brightness)));
  final haptics = PlatformHapticsService(enabled: settings.hapticsEnabled);
  sound.enabled = settings.soundEnabled;
  Fx.install(FeedbackService(sound, haptics));

  final container = ProviderContainer(
    overrides: [
      ...madarAppOverrides(prefs: prefs, sound: sound, haptics: haptics),
      // System dialogs and pickers the app opens never trip the app lock.
      ...suspendingFlowOverrides(),
    ],
  );
  runApp(UncontrolledProviderScope(container: container, child: const MadarApp()));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(sound.init().catchError((Object e, StackTrace s) => _log('sound init', e, s)));
    unawaited(_preferHighRefreshRate());
    unawaited(warmUpServices(container));
  });
}

/// Debug-only logging for framework and uncaught async errors. Release
/// builds stay silent: Madar has no crash reporting by design (privacy).
void installErrorHooks() {
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _log('uncaught', error, stack);
    return true;
  };
}

void _log(String what, Object error, StackTrace stack) {
  if (kDebugMode) debugPrint('Madar $what: $error\n$stack');
}

Future<void> _configureSystemUi() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(systemBarsFor(Brightness.dark));
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
}

AppSettings _readSettings(SharedPreferences prefs) {
  final probe = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  try {
    return probe.read(appSettingsProvider);
  } finally {
    probe.dispose();
  }
}

/// Physics-based motion deserves 90/120 Hz where the panel offers it.
Future<void> _preferHighRefreshRate() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    await FlutterDisplayMode.setHighRefreshRate();
  } catch (e, s) {
    _log('display mode', e, s);
  }
}
