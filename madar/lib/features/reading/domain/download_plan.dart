/// What a download WILL be, worked out before a single byte is fetched: the
/// total size and the parts. The screen shows "3.2 GB" from this, and only
/// then does the person decide to start (a Kiwix Wikipedia is tens of GB).
library;

import 'package:meta/meta.dart';

import 'library_entry.dart';

/// 64 MiB: big enough that a 40 GB file is ~600 parts, small enough that a
/// cut connection costs at most one part.
const int defaultPartSizeBytes = 64 * 1024 * 1024;

@immutable
final class PlannedPart {
  const PlannedPart({required this.index, required this.start, required this.length, this.sha256});

  final int index;

  /// First byte of the part in the whole file.
  final int start;
  final int length;
  final String? sha256;

  /// Last byte (inclusive), the form an HTTP Range header uses.
  int get end => start + length - 1;
}

@immutable
final class DownloadPlan {
  const DownloadPlan({required this.id, required this.url, required this.totalBytes, required this.parts, this.sha256});

  /// Stable key for the saved progress; one id per book.
  final String id;
  final Uri url;
  final int totalBytes;
  final List<PlannedPart> parts;

  /// Lowercase hex SHA-256 of the whole file; null only when the source
  /// publishes none (the downloader then checks sizes and part hashes only).
  final String? sha256;

  int get partCount => parts.length;

  /// Changes whenever the file or its layout changes, so progress saved for
  /// an older file is never mixed into a newer one.
  String get fingerprint => '$url|$totalBytes|${sha256 ?? ''}|${parts.map((p) => '${p.length}:${p.sha256 ?? ''}').join(',')}';
}

final class DownloadPlanner {
  const DownloadPlanner({this.partSizeBytes = defaultPartSizeBytes});

  final int partSizeBytes;

  /// The plan for a catalogue entry. When the entry declares its own parts
  /// they are used as they are; otherwise the file is cut into equal parts.
  /// Pure: it takes no client, so it cannot touch the network.
  DownloadPlan forEntry(LibraryEntry e) {
    final url = e.sourceUrl;
    if (!e.sourceKind.isDownloadable || url == null) {
      throw ArgumentError.value(e.id, 'entry', 'is not a downloadable book');
    }
    if (e.parts.isNotEmpty) {
      var start = 0;
      final parts = <PlannedPart>[];
      for (final p in e.parts) {
        parts.add(PlannedPart(index: parts.length, start: start, length: p.sizeBytes, sha256: p.sha256));
        start += p.sizeBytes;
      }
      if (start != e.sizeBytes) throw ArgumentError.value(e.id, 'entry', 'parts do not add up to sizeBytes');
      return DownloadPlan(id: e.id, url: Uri.parse(url), totalBytes: start, parts: parts, sha256: e.sha256);
    }
    return forSize(id: e.id, url: Uri.parse(url), totalBytes: e.sizeBytes, sha256: e.sha256);
  }

  /// The plan for a file whose size is known up front (a Kiwix ZIM from the
  /// Kiwix library listing).
  DownloadPlan forSize({required String id, required Uri url, required int totalBytes, String? sha256}) {
    if (totalBytes <= 0) throw ArgumentError.value(totalBytes, 'totalBytes', 'must be known and positive');
    if (partSizeBytes <= 0) throw ArgumentError.value(partSizeBytes, 'partSizeBytes');
    final parts = <PlannedPart>[];
    for (var start = 0; start < totalBytes; start += partSizeBytes) {
      final len = totalBytes - start < partSizeBytes ? totalBytes - start : partSizeBytes;
      parts.add(PlannedPart(index: parts.length, start: start, length: len));
    }
    return DownloadPlan(id: id, url: url, totalBytes: totalBytes, parts: parts, sha256: sha256);
  }
}
