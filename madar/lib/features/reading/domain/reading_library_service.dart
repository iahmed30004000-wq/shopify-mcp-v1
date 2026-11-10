/// The shelf: add a PDF from the phone, list, continue reading, remove with
/// undo (Part 17). Pure orchestration over abstract repositories - there is no
/// network client anywhere in its constructor, so a PDF he adds cannot go
/// anywhere by construction.
library;

import 'dart:convert';

import 'package:cryptography/dart.dart';
import 'package:meta/meta.dart';

import 'book_direction.dart';
import 'library_entry.dart';
import 'library_item.dart';
import 'licence_policy.dart';
import 'reading_position.dart';
import 'reading_repositories.dart';

typedef UndoAction = Future<void> Function();

/// How many bytes from each end of a PDF are hashed to recognise it again.
/// A 900 MB file is identified without reading 900 MB.
const int pdfFingerprintSampleBytes = 1024 * 1024;

/// The book id of a PDF, from its size and its first and last bytes. The same
/// file added twice (or removed and added again) gets the same id, so his
/// place in it is found again.
String localPdfBookId({required int sizeBytes, required List<int> head, required List<int> tail}) {
  final sink = const DartSha256().newHashSink()
    ..add(utf8.encode('$sizeBytes:'))
    ..add(head)
    ..add(tail)
    ..close();
  final hex = [for (final b in sink.hashSync().bytes) b.toRadixString(16).padLeft(2, '0')].join();
  return 'pdf-${hex.substring(0, 32)}';
}

/// A PDF he just picked. [bookId] comes from [localPdfBookId], computed by the
/// file layer from the sampled bytes.
@immutable
final class PickedPdf {
  const PickedPdf({required this.displayName, required this.sourcePath, required this.sizeBytes, required this.bookId});

  final String displayName;
  final String sourcePath;
  final int sizeBytes;
  final String bookId;
}

@immutable
final class AddResult {
  const AddResult({required this.item, required this.alreadyOnShelf, required this.undo});

  final LibraryItem item;

  /// True when the same file was already on the shelf; nothing was copied.
  final bool alreadyOnShelf;
  final UndoAction undo;
}

@immutable
final class Removal {
  const Removal({required this.undo, required this.commit});

  final UndoAction undo;
  final Future<void> Function() commit;
}

@immutable
final class ContinueReading {
  const ContinueReading({required this.item, required this.position});

  final LibraryItem item;
  final ReadingPosition position;
}

final class ReadingLibraryService {
  ReadingLibraryService({
    required this.library,
    required this.positions,
    required this.files,
    this.gate = const LicenceGate(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LibraryRepository library;
  final ReadingPositionRepository positions;
  final LocalFileStore files;
  final LicenceGate gate;
  final DateTime Function() _clock;

  /// Copies a picked PDF into the app and puts it on the shelf. The entry is
  /// `localPdf`: no licence is asked, and it is device-only for good.
  Future<AddResult> addLocalPdf(PickedPdf pdf) async {
    final existing = await library.get(pdf.bookId);
    if (existing != null) {
      return AddResult(item: existing, alreadyOnShelf: true, undo: () async {});
    }
    final path = await files.copyIn(bookId: pdf.bookId, sourcePath: pdf.sourcePath);
    final item = LibraryItem(
      entry: LibraryEntry(id: pdf.bookId, title: _titleOf(pdf.displayName), sourceKind: LibrarySourceKind.localPdf),
      addedAt: _clock(),
      localPath: path,
    );
    await library.put(item);
    return AddResult(
      item: item,
      alreadyOnShelf: false,
      undo: () async {
        await library.remove(item.id);
        await files.delete(path);
      },
    );
  }

  /// Puts a catalogue book (already downloaded to [localPath]) on the shelf.
  /// An entry that breaks the licence rule is refused.
  Future<UndoAction> addCatalogEntry(LibraryEntry entry, {String? localPath}) async {
    final decision = gate.assess(entry);
    if (!decision.allowed) throw CatalogLicenceException(decision.violations);
    final previous = await library.get(entry.id);
    await library.put(LibraryItem(entry: entry, addedAt: previous?.addedAt ?? _clock(), localPath: localPath));
    return () async {
      if (previous == null) {
        await library.remove(entry.id);
      } else {
        await library.put(previous);
      }
    };
  }

  /// The shelf, most recently added first.
  Future<List<LibraryItem>> list() async {
    final items = await library.all();
    return items..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }

  /// The book he read last and where he stopped; null when nothing was read
  /// yet (or every book he read has been removed).
  Future<ContinueReading?> continueReading() async {
    final all = await positions.all();
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    for (final p in all) {
      final item = await library.get(p.bookId);
      if (item != null) return ContinueReading(item: item, position: p);
    }
    return null;
  }

  Future<UndoAction> savePosition(ReadingPosition position) async {
    final before = await positions.get(position.bookId);
    await positions.put(position);
    return () async {
      if (before == null) {
        await positions.remove(position.bookId);
      } else {
        await positions.put(before);
      }
    };
  }

  /// Fixes the turn direction of a book whose language tag is missing or
  /// wrong (`null` goes back to deciding by language).
  Future<UndoAction> setDirectionOverride(String bookId, BookDirection? direction) async {
    final item = await library.get(bookId);
    if (item == null) return () async {};
    await library.put(
      LibraryItem(
        entry: item.entry.copyWith(directionOverride: direction, clearDirectionOverride: direction == null),
        addedAt: item.addedAt,
        localPath: item.localPath,
      ),
    );
    return () => library.put(item);
  }

  /// Takes a book off the shelf. The file is set aside, not deleted, and his
  /// place, bookmarks and highlights are kept, so [Removal.undo] brings back
  /// everything and so does adding the same file again later. Call
  /// [Removal.commit] when the undo window closes to free the file.
  Future<Removal> remove(String bookId) async {
    final item = await library.get(bookId);
    if (item == null) return Removal(undo: () async {}, commit: () async {});
    final ticket = item.localPath == null ? null : await files.trash(item.localPath!);
    await library.remove(bookId);
    return Removal(
      undo: () async {
        if (ticket != null) await files.restore(ticket);
        await library.put(item);
      },
      commit: () async {
        if (ticket != null) await files.purge(ticket);
      },
    );
  }

  static String _titleOf(String displayName) {
    final t = displayName.trim();
    return t.toLowerCase().endsWith('.pdf') ? t.substring(0, t.length - 4).trim() : t;
  }
}
