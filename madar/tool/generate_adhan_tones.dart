// Renders Madar's procedural "tanbih" tones (lib/features/adhan/sound/
// tanbih_synth.dart) into android/app/src/main/res/raw/, where the adhan
// notification channels play them from. Deterministic: re-running produces
// byte-identical files. Pure Dart (no Flutter), so:
//
//   dart run tool/generate_adhan_tones.dart
//
// Prints each tone's length, peak and size.
import 'dart:io';

import 'package:madar/core/sound/synth/wav.dart';
import 'package:madar/features/adhan/domain/adhan_sound.dart';
import 'package:madar/features/adhan/sound/tanbih_synth.dart';

void main(List<String> args) {
  final out = Directory(args.isNotEmpty ? args.first : 'android/app/src/main/res/raw')..createSync(recursive: true);
  var total = 0;
  for (final tone in TanbihTone.values) {
    final sw = Stopwatch()..start();
    final wav = TanbihSynth.renderWav(tone);
    sw.stop();
    final info = Wav.parse(wav);
    final samples = Wav.decodeChannel(wav, 0);
    var peak = 0.0;
    for (final s in samples) {
      if (s.abs() > peak) peak = s.abs();
    }
    File('${out.path}/${tone.rawName}.wav').writeAsBytesSync(wav);
    total += wav.length;
    stdout.writeln(
      '${tone.rawName}.wav  ${(info.duration.inMilliseconds / 1000).toStringAsFixed(2)} s  '
      'peak ${peak.toStringAsFixed(3)}  ${(wav.length / 1024).round()} KB  (${sw.elapsedMilliseconds} ms)',
    );
  }
  stdout.writeln('total ${(total / 1024).round()} KB → ${out.path}');
}
