import '../core/audio.dart';
import 'placeholder_audio.dart';

// Audio agent entry points – the ONLY symbols the standard kit imports from
// engine/audio/. Swap the placeholders for the real implementations here.

/// The procedural score conductor every CinemaGame uses.
MusicDirector createMusicDirector(CinemaAudioContext context) => SilentMusicDirector(context);

/// The era sound-effects bank every CinemaGame uses.
SfxBank createSfxBank(CinemaAudioContext context) => SilentSfxBank(context);
