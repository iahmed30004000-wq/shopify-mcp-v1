import 'dart:io';

import '../../../core/quran/ayah.dart';
import '../domain/reciters.dart';

/// Downloaded recitation files, as the player sees them.
abstract class LocalRecitationFiles {
  /// Resolves storage and reads the download index (cheap after the first
  /// call).
  Future<void> prepare();

  /// The file of [ayah] for [reciter] (the reciter's basmala when
  /// [basmala]), or null to stream it.
  File? localFile(Reciter reciter, AyahRef ayah, {bool basmala = false});
}

/// Nothing downloaded (tests).
class NoLocalRecitationFiles implements LocalRecitationFiles {
  const NoLocalRecitationFiles();

  @override
  Future<void> prepare() async {}

  @override
  File? localFile(Reciter reciter, AyahRef ayah, {bool basmala = false}) => null;
}
