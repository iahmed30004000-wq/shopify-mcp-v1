import '../../core/audio.dart';
import '../../core/era_skin.dart';
import 'cue_builder.dart';
import 'score.dart';
import 'styles/big_band.dart';
import 'styles/funk.dart';
import 'styles/noir.dart';
import 'styles/ragtime.dart';
import 'styles/swing.dart';
import 'styles/synthwave.dart';

/// The composer for each era's [MusicStyle].
StyleComposer composerFor(MusicStyle style) => switch (style) {
  MusicStyle.ragtime => const RagtimeComposer(),
  MusicStyle.swing => const SwingComposer(),
  MusicStyle.noirJazz => const NoirComposer(),
  MusicStyle.bigBand => const BigBandComposer(),
  MusicStyle.funk => const FunkComposer(),
  MusicStyle.synthwave => const SynthwaveComposer(),
};

/// Composes the cue for [mood] in [style] (pure and deterministic).
CueScore composeCue(ScoreStyle style, MusicMood mood, int seed) => composerFor(style.style).compose(mood, style, seed);
