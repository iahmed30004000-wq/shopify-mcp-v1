/// The adhan: exact-time full-screen adhan notifications, muezzin choice,
/// pre-adhan reminders, permissions and prayer quiet.
///
/// Wiring (see each symbol's docs):
/// * `AdhanHost(backButtonDispatcher: router.backButtonDispatcher, child: …)`
///   once around the app, inside the database gate and outside the lock
///   gate (the dispatcher lets the back button close the adhan instead of
///   popping the hidden app's page).
/// * `AdhanSettingsScreen()` as a settings route.
/// * `AdhanScreen(event: …, onClose: …)` if an event is routed by hand.
/// * `adhanEventFromLaunchDetails` / `adhanEventFromResponse` map plugin
///   payloads to an [AdhanEvent].
library;

export 'application/adhan_providers.dart';
export 'data/adhan_audio.dart';
export 'data/adhan_permissions.dart';
export 'data/adhan_scheduler.dart';
export 'data/adhan_settings_repository.dart';
export 'data/adhan_system.dart';
export 'data/adhan_texts.dart';
export 'data/muezzin_library.dart';
export 'domain/adhan_dua.dart';
export 'domain/adhan_event.dart';
export 'domain/adhan_plan.dart';
export 'domain/adhan_screen_model.dart';
export 'domain/adhan_settings.dart';
export 'domain/adhan_slot.dart';
export 'domain/adhan_sound.dart';
export 'domain/audio_length.dart';
export 'presentation/adhan_host.dart';
export 'presentation/adhan_screen.dart';
export 'sound/tanbih_synth.dart';
