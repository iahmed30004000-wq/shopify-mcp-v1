import '../core/audio.dart';
import 'runtime/music_director.dart';
import 'runtime/sfx_bank.dart';

// Audio agent entry points – the ONLY symbols the standard kit imports from
// engine/audio/.

/// The procedural score conductor every CinemaGame uses: era-styled cues
/// composed and rendered on background isolates, played on the games bus.
/// Silent (and free) when the app's sound service is not the SoLoud one.
MusicDirector createMusicDirector(CinemaAudioContext context) => ProceduralMusicDirector(context);

/// The era's procedurally synthesised sound-effect bank.
SfxBank createSfxBank(CinemaAudioContext context) => ProceduralSfxBank(context);
