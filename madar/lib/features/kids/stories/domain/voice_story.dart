import 'package:flutter/foundation.dart';

/// One story the parent tells in their own voice. The words are the parent's:
/// the title, who is speaking («بصوت بابا») and the cover colour are all
/// typed by the parent, never fixed in the app.
@immutable
class VoiceStory {
  const VoiceStory({
    required this.id,
    required this.title,
    this.narrator = '',
    this.colorIndex = 0,
    this.fileName,
    this.durationMs = 0,
    this.createdAtMs = 0,
  });

  final String id;
  final String title;

  /// «بصوت بابا»: free text; empty hides the tag.
  final String narrator;

  /// Which of the cover colours (an index, wrapped by the screen).
  final int colorIndex;

  /// The recording inside the app's private folder (a bare file name, never a
  /// path outside it); null while the story has no recording yet.
  final String? fileName;

  final int durationMs;
  final int createdAtMs;

  bool get hasRecording => fileName != null;

  Duration get duration => Duration(milliseconds: durationMs);

  static const int maxTitleLength = 60;
  static const int maxNarratorLength = 30;
  static const int coverColours = 6;

  VoiceStory copyWith({
    String? title,
    String? narrator,
    int? colorIndex,
    String? fileName,
    bool clearRecording = false,
    int? durationMs,
  }) => VoiceStory(
    id: id,
    title: title ?? this.title,
    narrator: narrator ?? this.narrator,
    colorIndex: colorIndex ?? this.colorIndex,
    fileName: clearRecording ? null : (fileName ?? this.fileName),
    durationMs: clearRecording ? 0 : (durationMs ?? this.durationMs),
    createdAtMs: createdAtMs,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'narrator': narrator,
    'color': colorIndex,
    'file': fileName,
    'ms': durationMs,
    'at': createdAtMs,
  };

  /// Null for anything that is not a well-formed story. A file name that
  /// could leave the private folder is dropped (the story keeps its title).
  static VoiceStory? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], title = json['title'];
    if (id is! String || id.isEmpty || title is! String) return null;
    final file = json['file'];
    return VoiceStory(
      id: id,
      title: title,
      narrator: json['narrator'] is String ? json['narrator'] as String : '',
      colorIndex: json['color'] is num ? (json['color'] as num).toInt() : 0,
      fileName: file is String && isSafeFileName(file) ? file : null,
      durationMs: json['ms'] is num ? (json['ms'] as num).toInt() : 0,
      createdAtMs: json['at'] is num ? (json['at'] as num).toInt() : 0,
    );
  }

  /// A plain file name: no folders, no `..`.
  static bool isSafeFileName(String name) =>
      name.isNotEmpty && !name.contains('/') && !name.contains('\\') && !name.contains('..');

  /// Trims and caps a typed title.
  static String cleanTitle(String t) {
    final s = t.trim().replaceAll(RegExp(r'\s+'), ' ');
    return s.length > maxTitleLength ? s.substring(0, maxTitleLength) : s;
  }

  static String cleanNarrator(String t) {
    final s = t.trim().replaceAll(RegExp(r'\s+'), ' ');
    return s.length > maxNarratorLength ? s.substring(0, maxNarratorLength) : s;
  }
}

/// The stories in order (oldest first, so «next» goes down the list).
List<VoiceStory> decodeVoiceStories(Object? json) =>
    json is List ? [for (final j in json) ?VoiceStory.fromJson(j)] : const [];

List<Object?> encodeVoiceStories(List<VoiceStory> stories) => [for (final s in stories) s.toJson()];

/// A decorative, steady waveform for a story (the player shows it as a ring
/// and the parent corner as bars). It is NOT the audio's real shape; it only
/// gives each story its own look, derived from its id.
List<double> pseudoWaveform(String seed, int bars) {
  var h = 2166136261;
  for (final c in seed.codeUnits) {
    h = ((h ^ c) * 16777619) & 0x7fffffff;
  }
  final out = List<double>.filled(bars, 0);
  for (var i = 0; i < bars; i++) {
    h = (h * 1103515245 + 12345) & 0x7fffffff;
    final r = (h >> 8) % 1000 / 1000.0;
    out[i] = 0.25 + 0.75 * r;
  }
  return out;
}
