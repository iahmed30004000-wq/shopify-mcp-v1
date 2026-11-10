import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/ambient.dart';
import 'package:madar/core/sound/profiles.dart';
import 'package:madar/core/sound/sound_kit.dart';

/// Writes every kit and ambient loop to `build/sound_preview/` for listening
/// sessions and critic passes:
///
///     MADAR_EXPORT_SOUNDS=1 flutter test test/core/sound/export_sounds_test.dart
void main() {
  final enabled = Platform.environment['MADAR_EXPORT_SOUNDS'] == '1';
  test('export kits and ambient loops as WAV files', () async {
    final root = Directory('build/sound_preview')..createSync(recursive: true);
    for (final id in SoundProfiles.ids) {
      final dir = Directory('${root.path}/$id')..createSync(recursive: true);
      final kit = SoundKitRenderer.render(id);
      for (final e in kit.wavs.entries) {
        File('${dir.path}/${e.key.index.toString().padLeft(2, '0')}_${e.key.name}.wav').writeAsBytesSync(e.value);
      }
      File('${dir.path}/ambient.wav').writeAsBytesSync(AmbientSoundscape.renderWav(id));
    }
    expect(root.listSync(), isNotEmpty);
  }, skip: enabled ? false : 'set MADAR_EXPORT_SOUNDS=1 to export');
}
