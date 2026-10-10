import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/adhkar_models.dart';

/// The bundled Hisn al-Muslim adhkar (see assets/licenses/adhkar_credits.txt).
const String kAdhkarAsset = 'assets/adhkar/hisn_al_muslim.json';

/// Loads and validates the bundled adhkar.
class AdhkarLoader {
  const AdhkarLoader(this.bundle, {this.asset = kAdhkarAsset});

  final AssetBundle bundle;
  final String asset;

  /// Reads the bytes (not `loadString`, which hands files over 50 KB to an
  /// isolate) and parses them on this isolate: ~100 KB, a few milliseconds.
  Future<AdhkarLibrary> load() async {
    final data = await bundle.load(asset);
    final text = utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    return AdhkarLibrary.fromJson(jsonDecode(text));
  }
}
