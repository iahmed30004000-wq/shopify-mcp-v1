import 'dart:async';
import 'dart:typed_data';

import 'package:madar/features/reading/data/chunked_downloader.dart';
import 'package:madar/features/reading/data/download_ports.dart';
import 'package:madar/features/reading/domain/daily_reading_goal.dart';
import 'package:madar/features/reading/domain/highlight.dart';
import 'package:madar/features/reading/domain/library_item.dart';
import 'package:madar/features/reading/domain/reading_position.dart';
import 'package:madar/features/reading/domain/reading_repositories.dart';
import 'package:madar/features/reading/domain/reading_session.dart';

/// Deterministic bytes so a corrupt part is easy to make and to see.
Uint8List sampleBytes(int length, {int seed = 7}) =>
    Uint8List.fromList([for (var i = 0; i < length; i++) (i * 31 + seed + (i >> 8)) & 0xff]);

String hashOf(List<int> bytes) => sha256Hex(bytes);

/// Serves [content] with Range support and records every request.
final class FakeRangeHttpClient implements RangeHttpClient {
  FakeRangeHttpClient(this.content);

  Uint8List content;
  bool acceptsRanges = true;
  int? lengthOverride;

  int headCalls = 0;
  final List<(int, int)> rangeRequests = [];

  /// Runs before each range answer; throw a [TransportException] to cut it.
  FutureOr<void> Function(int start, int end)? beforeRange;

  /// Starts whose NEXT answer is corrupted (one bit flipped), once each.
  final Set<int> corruptOnce = {};

  /// Starts whose NEXT answer is one byte short, once each.
  final Set<int> shortReadOnce = {};

  /// Starts that are always corrupted.
  final Set<int> corruptAlways = {};

  int get totalRequests => headCalls + rangeRequests.length;

  @override
  Future<HeadInfo> head(Uri url) async {
    headCalls++;
    return HeadInfo(contentLength: lengthOverride ?? content.length, acceptsRanges: acceptsRanges);
  }

  @override
  Future<Uint8List> getRange(Uri url, int start, int end) async {
    rangeRequests.add((start, end));
    await beforeRange?.call(start, end);
    var out = Uint8List.fromList(content.sublist(start, end + 1));
    if (shortReadOnce.remove(start)) out = Uint8List.sublistView(out, 0, out.length - 1);
    if (corruptOnce.remove(start) || corruptAlways.contains(start)) out[0] ^= 0xff;
    return out;
  }
}

final class FakeDownloadStateStore implements DownloadStateStore {
  final Map<String, DownloadState> states = {};

  @override
  Future<DownloadState?> load(String id) async => states[id];

  @override
  Future<void> save(DownloadState state) async => states[state.id] = state;

  @override
  Future<void> delete(String id) async => states.remove(id);
}

final class FakeFreeSpaceProbe implements FreeSpaceProbe {
  FakeFreeSpaceProbe(this.free);

  int free;

  @override
  Future<int> freeBytes() async => free;
}

final class FakeConnectivityProbe implements ConnectivityProbe {
  FakeConnectivityProbe([this.kind = NetworkKind.wifi]);

  NetworkKind kind;

  @override
  Future<NetworkKind> current() async => kind;
}

final class FakeFileSink implements FileSink {
  /// Total bytes the pretend disk can hold; writes past it throw.
  int? capacityBytes;

  final Map<String, Uint8List> parts = {};
  final Map<String, Uint8List> finalFiles = {};
  final List<String> writes = [];

  String _k(String id, int i) => '$id#$i';

  int get usedBytes => parts.values.fold(0, (a, b) => a + b.length);

  @override
  Future<int?> partLength(String id, int index) async => parts[_k(id, index)]?.length;

  @override
  Future<void> writePart(String id, int index, Uint8List bytes) async {
    if (capacityBytes != null && usedBytes + bytes.length > capacityBytes!) throw const StorageFullException();
    writes.add(_k(id, index));
    parts[_k(id, index)] = bytes;
  }

  @override
  Stream<List<int>> readPart(String id, int index) => Stream.value(parts[_k(id, index)]!);

  @override
  Future<void> deletePart(String id, int index) async => parts.remove(_k(id, index));

  @override
  Future<String> finalize(String id, int partCount) async {
    final b = BytesBuilder();
    for (var i = 0; i < partCount; i++) {
      b.add(parts.remove(_k(id, i))!);
    }
    finalFiles[id] = b.toBytes();
    return '/books/$id';
  }

  @override
  Future<void> discard(String id) async => parts.removeWhere((k, _) => k.startsWith('$id#'));
}

final class FakeLibraryRepository implements LibraryRepository {
  final Map<String, LibraryItem> items = {};

  @override
  Future<List<LibraryItem>> all() async => items.values.toList();

  @override
  Future<LibraryItem?> get(String bookId) async => items[bookId];

  @override
  Future<void> put(LibraryItem item) async => items[item.id] = item;

  @override
  Future<void> remove(String bookId) async => items.remove(bookId);
}

final class FakePositionRepository implements ReadingPositionRepository {
  final Map<String, ReadingPosition> byBook = {};

  @override
  Future<ReadingPosition?> get(String bookId) async => byBook[bookId];

  @override
  Future<List<ReadingPosition>> all() async => byBook.values.toList();

  @override
  Future<void> put(ReadingPosition position) async => byBook[position.bookId] = position;

  @override
  Future<void> remove(String bookId) async => byBook.remove(bookId);
}

final class FakeBookmarkRepository implements BookmarkRepository {
  final Map<String, Bookmark> byId = {};

  @override
  Future<List<Bookmark>> forBook(String bookId) async => byId.values.where((b) => b.bookId == bookId).toList();

  @override
  Future<void> put(Bookmark bookmark) async => byId[bookmark.id] = bookmark;

  @override
  Future<void> remove(String bookmarkId) async => byId.remove(bookmarkId);
}

final class FakeHighlightRepository implements HighlightRepository {
  final Map<String, Highlight> byId = {};

  @override
  Future<List<Highlight>> forBook(String bookId) async => byId.values.where((h) => h.bookId == bookId).toList();

  @override
  Future<void> put(Highlight highlight) async => byId[highlight.id] = highlight;

  @override
  Future<void> remove(String highlightId) async => byId.remove(highlightId);
}

final class FakeSessionRepository implements ReadingSessionRepository {
  final List<ReadingSession> sessions = [];

  @override
  Future<void> add(ReadingSession session) async => sessions.add(session);

  @override
  Future<List<ReadingSession>> all() async => List.of(sessions);
}

final class FakeGoalRepository implements ReadingGoalRepository {
  final List<DailyReadingGoal> goals = [];

  @override
  Future<List<DailyReadingGoal>> history() async => List.of(goals);

  @override
  Future<void> add(DailyReadingGoal goal) async => goals.add(goal);

  @override
  Future<void> remove(DailyReadingGoal goal) async => goals.remove(goal);
}

/// Records every call so a test can assert what the local-PDF path touched.
final class FakeLocalFileStore implements LocalFileStore {
  final List<String> calls = [];
  final Map<String, String> stored = {};
  final Map<String, String> trashed = {};

  @override
  Future<String> copyIn({required String bookId, required String sourcePath}) async {
    calls.add('copyIn:$bookId');
    return stored[bookId] = '/app/books/$bookId.pdf';
  }

  @override
  Future<String> trash(String path) async {
    calls.add('trash:$path');
    final ticket = 'trash-$path';
    trashed[ticket] = path;
    return ticket;
  }

  @override
  Future<void> restore(String ticket) async {
    calls.add('restore:$ticket');
    trashed.remove(ticket);
  }

  @override
  Future<void> purge(String ticket) async {
    calls.add('purge:$ticket');
    trashed.remove(ticket);
  }

  @override
  Future<void> delete(String path) async => calls.add('delete:$path');
}
