import 'package:meta/meta.dart';

import 'library_entry.dart';

/// A book on his shelf: the catalogue facts plus where the file is on THIS
/// phone.
@immutable
final class LibraryItem {
  const LibraryItem({required this.entry, required this.addedAt, this.localPath});

  final LibraryEntry entry;
  final DateTime addedAt;

  /// The file inside the app's own storage; null for a book not downloaded.
  final String? localPath;

  String get id => entry.id;

  Map<String, Object?> toJson() => {
    'entry': entry.toJson(),
    'addedAt': addedAt.toIso8601String(),
    if (localPath != null) 'localPath': localPath,
  };

  factory LibraryItem.fromJson(Map<String, Object?> json) => LibraryItem(
    entry: LibraryEntry.fromJson((json['entry'] as Map).cast<String, Object?>()),
    addedAt: DateTime.parse(json['addedAt'] as String),
    localPath: json['localPath'] as String?,
  );
}
