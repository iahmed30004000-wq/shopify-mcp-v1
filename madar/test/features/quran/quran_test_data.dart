// The bundled Quran data read straight from assets/quran/ (synchronous, so
// it works inside fake-async widget tests).
import 'dart:convert';
import 'dart:io';

import 'package:madar/features/quran/data/quran_store.dart';
import 'package:madar/features/quran/domain/quran_meta.dart';
import 'package:madar/features/quran/domain/quran_text.dart';

abstract final class QuranTestData {
  static QuranMeta? _meta;
  static QuranText? _text;
  static TajweedIndex? _tajweed;

  static String read(String file) => File('${QuranAssets.dir}$file').readAsStringSync();

  static QuranMeta get meta =>
      _meta ??= QuranMeta.fromJson((jsonDecode(read(QuranAssets.meta)) as Map).cast<String, Object?>());

  static QuranText get text => _text ??= QuranText.parse(read(QuranAssets.text), meta);

  static TajweedIndex get tajweed => _tajweed ??= TajweedIndex.parse(read(QuranAssets.tajweed), meta);

  /// A store with everything loaded.
  static QuranStore store() => QuranStore.preloaded(meta: meta, text: text, tajweed: tajweed);
}

/// Reads the bundled files from disk (async API, real files).
class FileQuranAssetSource implements QuranAssetSource {
  const FileQuranAssetSource();

  @override
  Future<String> read(String file) async => QuranTestData.read(file);
}
