/// What the reading planet needs from storage. The integrator implements these
/// over the database (the tables are theirs to define); tests use in-memory
/// fakes. Nothing here knows about the network.
library;

import 'daily_reading_goal.dart';
import 'highlight.dart';
import 'library_item.dart';
import 'reading_position.dart';
import 'reading_session.dart';

abstract interface class LibraryRepository {
  Future<List<LibraryItem>> all();
  Future<LibraryItem?> get(String bookId);
  Future<void> put(LibraryItem item);
  Future<void> remove(String bookId);
}

abstract interface class ReadingPositionRepository {
  Future<ReadingPosition?> get(String bookId);
  Future<List<ReadingPosition>> all();
  Future<void> put(ReadingPosition position);
  Future<void> remove(String bookId);
}

abstract interface class BookmarkRepository {
  Future<List<Bookmark>> forBook(String bookId);
  Future<void> put(Bookmark bookmark);
  Future<void> remove(String bookmarkId);
}

abstract interface class HighlightRepository {
  Future<List<Highlight>> forBook(String bookId);
  Future<void> put(Highlight highlight);
  Future<void> remove(String highlightId);
}

abstract interface class ReadingSessionRepository {
  Future<void> add(ReadingSession session);
  Future<List<ReadingSession>> all();
}

abstract interface class ReadingGoalRepository {
  /// Every goal he ever set, oldest first.
  Future<List<DailyReadingGoal>> history();
  Future<void> add(DailyReadingGoal goal);
  Future<void> remove(DailyReadingGoal goal);
}

/// The phone's own file area for books. Copy-on-device only: nothing here has
/// a network, and a file never leaves the app's storage.
abstract interface class LocalFileStore {
  /// Copies the picked file into the app's storage and returns the new path.
  Future<String> copyIn({required String bookId, required String sourcePath});

  /// Moves a stored file aside (so a removal can be undone) and returns a
  /// ticket for it.
  Future<String> trash(String path);
  Future<void> restore(String ticket);

  /// Deletes a trashed file for good.
  Future<void> purge(String ticket);

  /// Deletes a stored file for good.
  Future<void> delete(String path);
}
