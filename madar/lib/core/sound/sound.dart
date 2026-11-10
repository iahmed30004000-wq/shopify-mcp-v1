/// Madar's sound system: procedural per-theme UI kits, the deep-space
/// ambient bed, the flutter_soloud engine service, haptics and the settings
/// sync. Widgets should only ever call `Fx.fire(Sfx.…)`.
library;

export 'ambient.dart' show AmbientSoundscape, AmbientSpec;
export 'audio_engine.dart' show AudioEngine, SoloudAudioEngine;
export 'haptics.dart';
export 'profiles.dart' show SfxSpecs, SoundProfile, SoundProfiles;
export 'soloud_sound_service.dart';
export 'sound_api.dart';
export 'sound_kit.dart';
export 'sound_labels.dart';
export 'sound_settings_sync.dart';
