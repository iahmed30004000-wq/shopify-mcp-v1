import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/synth/wav.dart';
import 'package:madar/features/adhan/domain/adhan_sound.dart';
import 'package:madar/features/adhan/sound/tanbih_synth.dart';

void main() {
  for (final tone in TanbihTone.values) {
    group(tone.name, () {
      late final wav = TanbihSynth.renderWav(tone);

      test('a valid mono 22.05 kHz WAV of the catalogued length', () {
        final info = Wav.parse(wav);
        expect(info.channels, 1);
        expect(info.sampleRate, TanbihSynth.sampleRate);
        expect((info.duration - tone.length).abs(), lessThan(const Duration(milliseconds: 400)));
      });

      test('loud enough for an alarm, never clipping, clean edges', () {
        final s = Wav.decodeChannel(wav, 0);
        var peak = 0.0, sum = 0.0;
        for (final x in s) {
          peak = math.max(peak, x.abs());
          sum += x;
        }
        expect(peak, lessThanOrEqualTo(0.9), reason: '−1 dBFS ceiling');
        expect(peak, greaterThan(0.3));
        expect((sum / s.length).abs(), lessThan(0.002), reason: 'no DC offset');
        expect(s.first.abs(), lessThan(0.01));
        expect(s.last.abs(), lessThan(0.01));
      });

      test('the shipped notification sound is exactly this render', () {
        final raw = File('android/app/src/main/res/raw/${tone.rawName}.wav');
        expect(raw.existsSync(), isTrue, reason: 'run dart run tool/generate_adhan_tones.dart');
        expect(raw.readAsBytesSync(), wav, reason: 'regenerate: dart run tool/generate_adhan_tones.dart');
      });
    });
  }

  test('deterministic', () {
    expect(TanbihSynth.renderWav(TanbihTone.chime), TanbihSynth.renderWav(TanbihTone.chime));
  });

  test('the long calls keep sounding (no dead air between strikes)', () {
    for (final tone in TanbihTone.calls) {
      final s = Wav.decodeChannel(TanbihSynth.renderWav(tone), 0);
      const window = TanbihSynth.sampleRate ~/ 2;
      // Every half second until the last strike stays within 40 dB of the
      // peak (the final ring may then fade out naturally).
      var peak = 0.0;
      for (final x in s) {
        peak = math.max(peak, x.abs());
      }
      for (var i = 0; i + window <= 9 * TanbihSynth.sampleRate; i += window) {
        var e = 0.0;
        for (var j = i; j < i + window; j++) {
          e += s[j] * s[j];
        }
        final rms = math.sqrt(e / window);
        expect(
          20 * math.log(rms / peak) / math.ln10,
          greaterThan(-40),
          reason: '${tone.name} at ${i / TanbihSynth.sampleRate}s',
        );
      }
    }
  });
}
