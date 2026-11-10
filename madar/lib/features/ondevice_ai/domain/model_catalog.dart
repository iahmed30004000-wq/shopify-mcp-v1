/// The weights Madar may offer to download (Part 15, DoD: «the download is
/// optional, resumable, and removable, and the app is fully usable without
/// it»).
///
/// **Every entry below is a PLACEHOLDER** until the owner picks the real
/// files: a size, a SHA-256 and a download address are facts that must come
/// from the model's publisher, and nothing here may be guessed. An entry with
/// [ModelCatalogEntry.unverified] set can never start a download
/// ([ModelCatalogEntry.canDownload] is false): the real values are filled in
/// together with `unverified: false`.
///
/// Pure Dart.
library;

import 'package:meta/meta.dart';

enum ModelKind {
  /// Understands and writes text (the daily chat, the day's summary).
  language,

  /// Listens to a recitation (Part 13).
  recitation,
}

@immutable
class ModelCatalogEntry {
  const ModelCatalogEntry({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.license,
    required this.sourcePage,
    required this.notes,
    this.sizeBytes,
    this.sha256,
    this.downloadUrl,
    this.unverified = true,
  });

  /// Stable key (also the folder name on the phone).
  final String id;

  /// The model's own name (not translated).
  final String displayName;
  final ModelKind kind;

  /// The licence as published (an SPDX-style id, or «to verify»).
  final String license;

  /// A web page about the model (never fetched by the app).
  final String sourcePage;

  /// For the people maintaining the app: what is and is not known.
  final String notes;

  /// Exact size in bytes; null until verified.
  final int? sizeBytes;

  /// Lowercase hex SHA-256 of the whole file; null until verified.
  final String? sha256;

  /// The file's address (HTTPS); null until verified.
  final String? downloadUrl;

  /// True while any of the facts above is a placeholder. Blocks the download.
  final bool unverified;

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Everything a safe download needs is present and verified.
  bool get canDownload {
    final url = downloadUrl == null ? null : Uri.tryParse(downloadUrl!);
    return !unverified &&
        (sizeBytes ?? 0) > 0 &&
        sha256 != null &&
        _hex64.hasMatch(sha256!) &&
        url != null &&
        url.scheme == 'https' &&
        url.host.isNotEmpty;
  }
}

abstract final class ModelCatalog {
  static const String recitationId = 'tarteel-ai/whisper-base-ar-quran';
  static const String gemmaId = 'gemma-e2b-placeholder';

  static const List<ModelCatalogEntry> entries = [
    ModelCatalogEntry(
      id: recitationId,
      displayName: 'Whisper Base (Quran recitation)',
      kind: ModelKind.recitation,
      license: 'Apache-2.0',
      sourcePage: 'https://huggingface.co/tarteel-ai/whisper-base-ar-quran',
      notes:
          'PLACEHOLDER. A Whisper Base model, about 77M parameters, Apache-2.0. '
          'The model card does not document its training data. Size, SHA-256 and the file '
          'address are filled in when the owner picks the exact file.',
    ),
    ModelCatalogEntry(
      id: gemmaId,
      displayName: 'Gemma (E2B)',
      kind: ModelKind.language,
      license: 'to verify',
      sourcePage: 'https://ai.google.dev/gemma',
      notes:
          'PLACEHOLDER, unverified. Stands for the Gemma E2B weights of the in-app engine path. '
          'The exact file, its size, SHA-256, the licence terms and the engine format '
          '(MediaPipe / LiteRT) are decided after the measurements on the owner\'s phone.',
    ),
  ];

  static ModelCatalogEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}
