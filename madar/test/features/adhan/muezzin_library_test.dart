import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/synth/wav.dart';
import 'package:madar/features/adhan/data/adhan_system.dart';
import 'package:madar/features/adhan/data/muezzin_library.dart';
import 'package:madar/features/adhan/domain/adhan_sound.dart';

class _Picker implements AudioFilePicker {
  _Picker(this.next);

  PickedAudio? next;

  @override
  Future<PickedAudio?> pick() async => next;
}

void main() {
  late Directory dir;
  late MuezzinLibrary library;
  late _Picker picker;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('madar_adhan_');
    addTearDown(() => dir.deleteSync(recursive: true));
    picker = _Picker(null);
    library = MuezzinLibrary(
      system: FakeAdhanSystem(directory: '${dir.path}/adhan_sounds'),
      picker: picker,
      clock: () => DateTime.utc(2026, 9, 28, 12),
      random: Random(7),
    );
  });

  test('copies a picked recording into the sound folder', () async {
    final wav = Wav.encodePcm16([Float64List(8000 * 4)], sampleRate: 8000);
    picker.next = PickedAudio(name: 'Adhan_Makkah-2024.WAV', read: () async => wav);
    final result = await library.pickAndImport();
    final m = result.muezzin!;
    expect(result.error, isNull);
    expect(CustomMuezzin.isValidId(m.id), isTrue);
    expect(m.fileName, '${m.id}.wav');
    expect(m.name, 'Adhan Makkah 2024');
    expect(m.length, const Duration(seconds: 4));
    expect(m.addedAt, DateTime.utc(2026, 9, 28, 12));
    expect(m.playableInApp, isTrue);
    final file = await library.fileOf(m);
    expect(file.path, '${dir.path}/adhan_sounds/${m.fileName}');
    expect(file.readAsBytesSync(), wav);
    expect(await library.bytesOf(m), wav);
    // The name satisfies AdhanSoundProvider.kt's SAFE_NAME.
    expect(RegExp(r'^[a-z0-9]{4,40}\.[a-z0-9]{2,5}$').hasMatch(m.fileName), isTrue);

    await library.delete(m);
    expect(file.existsSync(), isFalse);
    expect(await library.bytesOf(m), isNull);
  });

  test('refuses what cannot be an adhan recording', () async {
    expect((await library.pickAndImport()).error, MuezzinImportError.cancelled);
    picker.next = PickedAudio(name: 'notes.pdf', read: () async => Uint8List(10));
    expect((await library.pickAndImport()).error, MuezzinImportError.unsupported);
    picker.next = PickedAudio(name: 'adhan.mp3', read: () async => Uint8List(0));
    expect((await library.pickAndImport()).error, MuezzinImportError.unreadable);
    picker.next = PickedAudio(name: 'adhan.mp3', read: () async => throw const FileSystemException('gone'));
    expect((await library.pickAndImport()).error, MuezzinImportError.unreadable);
    picker.next = PickedAudio(name: 'huge.flac', read: () async => Uint8List(MuezzinLibrary.maxBytes + 1));
    expect((await library.pickAndImport()).error, MuezzinImportError.tooLarge);
    final sounds = Directory('${dir.path}/adhan_sounds');
    expect(!sounds.existsSync() || sounds.listSync().isEmpty, isTrue);
  });

  test('formats Android can play are accepted, the rest not', () {
    for (final ok in ['a.mp3', 'a.M4A', 'a.ogg', 'a.opus', 'a.flac', 'a.wav', 'a.aac']) {
      expect(MuezzinLibrary.extensionOf(ok), isNotNull, reason: ok);
    }
    for (final bad in ['a', 'a.', 'a.mid', 'a.exe', 'mp3']) {
      expect(MuezzinLibrary.extensionOf(bad), isNull, reason: bad);
    }
    expect(MuezzinLibrary.displayNameOf('${'x' * 60}.mp3').length, 40);
  });
}
