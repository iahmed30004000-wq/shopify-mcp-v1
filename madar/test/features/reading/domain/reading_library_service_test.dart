import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/domain/book_direction.dart';
import 'package:madar/features/reading/domain/library_entry.dart';
import 'package:madar/features/reading/domain/licence_policy.dart';
import 'package:madar/features/reading/domain/reading_library_service.dart';
import 'package:madar/features/reading/domain/reading_position.dart';

import '../data/support/reading_fakes.dart';

void main() {
  late FakeLibraryRepository library;
  late FakePositionRepository positions;
  late FakeLocalFileStore files;
  late DateTime now;
  late ReadingLibraryService service;
  // A network client exists in the test world, but the service has no way to
  // be handed one: that is what "no transport from the local-PDF path" means.
  late FakeRangeHttpClient network;

  PickedPdf pdf(String name, {String? head}) => PickedPdf(
    displayName: name,
    sourcePath: '/storage/Download/$name',
    sizeBytes: 900 * 1024 * 1024,
    bookId: localPdfBookId(sizeBytes: 900 * 1024 * 1024, head: (head ?? name).codeUnits, tail: const [1, 2, 3]),
  );

  setUp(() {
    library = FakeLibraryRepository();
    positions = FakePositionRepository();
    files = FakeLocalFileStore();
    network = FakeRangeHttpClient(sampleBytes(10));
    now = DateTime(2026, 11, 10, 9);
    service = ReadingLibraryService(library: library, positions: positions, files: files, clock: () => now);
  });

  test('adding a local PDF copies it on the device only, as a device-only entry, with no client call', () async {
    final r = await service.addLocalPdf(pdf('كتاب.pdf'));
    expect(files.calls, ['copyIn:${r.item.id}']);
    expect(network.totalRequests, 0);
    expect(r.item.entry.sourceKind, LibrarySourceKind.localPdf);
    expect(r.item.entry.title, 'كتاب');
    expect(r.item.entry.deviceOnly, isTrue);
    expect(r.item.localPath, '/app/books/${r.item.id}.pdf');
    // The gate refuses to send it anywhere.
    var sent = false;
    await expectLater(const LicenceGate().exportToRemote(r.item.entry, () async => sent = true), throwsA(isA<DeviceOnlyException>()));
    expect(sent, isFalse);
    expect(network.totalRequests, 0);
  });

  test('a PDF with no language tag is LTR until he sets the direction by hand', () async {
    final r = await service.addLocalPdf(pdf('a.pdf'));
    expect(r.item.entry.direction, BookDirection.ltr);
    final undo = await service.setDirectionOverride(r.item.id, BookDirection.rtl);
    expect((await library.get(r.item.id))!.entry.direction, BookDirection.rtl);
    await undo();
    expect((await library.get(r.item.id))!.entry.direction, BookDirection.ltr);
  });

  test('the same file added again is recognised and not copied twice', () async {
    final first = await service.addLocalPdf(pdf('a.pdf'));
    final again = await service.addLocalPdf(pdf('a.pdf'));
    expect(again.alreadyOnShelf, isTrue);
    expect(again.item.id, first.item.id);
    expect(files.calls.where((c) => c.startsWith('copyIn')).length, 1);
  });

  test('different files get different ids', () {
    expect(pdf('a.pdf').bookId, isNot(pdf('b.pdf').bookId));
  });

  test('undo of an add removes the book and the copy', () async {
    final r = await service.addLocalPdf(pdf('a.pdf'));
    await r.undo();
    expect(await service.list(), isEmpty);
    expect(files.calls, contains('delete:${r.item.localPath}'));
  });

  test('list is newest first', () async {
    final a = await service.addLocalPdf(pdf('a.pdf'));
    now = now.add(const Duration(hours: 1));
    final b = await service.addLocalPdf(pdf('b.pdf'));
    expect((await service.list()).map((i) => i.id), [b.item.id, a.item.id]);
  });

  group('continue reading', () {
    test('nothing read yet gives null', () async {
      await service.addLocalPdf(pdf('a.pdf'));
      expect(await service.continueReading(), isNull);
    });

    test('returns the most recently read book at its exact page and scroll offset', () async {
      final a = await service.addLocalPdf(pdf('a.pdf'));
      final b = await service.addLocalPdf(pdf('b.pdf'));
      await service.savePosition(ReadingPosition(bookId: a.item.id, page: 10, updatedAt: DateTime(2026, 11, 10, 10)));
      await service.savePosition(
        ReadingPosition(bookId: b.item.id, page: 41, scrollOffsetFraction: 0.62, updatedAt: DateTime(2026, 11, 10, 11)),
      );
      final c = (await service.continueReading())!;
      expect(c.item.id, b.item.id);
      expect(c.position.page, 41);
      expect(c.position.scrollOffsetFraction, 0.62);
    });

    test('savePosition returns an undo that restores the previous place', () async {
      final a = await service.addLocalPdf(pdf('a.pdf'));
      await service.savePosition(ReadingPosition(bookId: a.item.id, page: 5, updatedAt: DateTime(2026, 11, 10, 10)));
      final undo = await service.savePosition(ReadingPosition(bookId: a.item.id, page: 9, updatedAt: DateTime(2026, 11, 10, 11)));
      await undo();
      expect((await positions.get(a.item.id))!.page, 5);
    });
  });

  group('remove', () {
    test('sets the file aside, keeps his place, and undo brings everything back', () async {
      final a = await service.addLocalPdf(pdf('a.pdf'));
      await service.savePosition(ReadingPosition(bookId: a.item.id, page: 7, updatedAt: DateTime(2026, 11, 10, 10)));
      final removal = await service.remove(a.item.id);
      expect(await service.list(), isEmpty);
      expect(await service.continueReading(), isNull);
      expect(files.trashed, isNotEmpty);
      await removal.undo();
      expect((await service.list()).single.id, a.item.id);
      expect((await service.continueReading())!.position.page, 7);
      expect(files.trashed, isEmpty);
    });

    test('commit frees the file for good', () async {
      final a = await service.addLocalPdf(pdf('a.pdf'));
      final removal = await service.remove(a.item.id);
      await removal.commit();
      expect(files.calls.last, startsWith('purge:'));
      expect(files.trashed, isEmpty);
    });

    test('re-importing the same file after removal lands on the exact page again', () async {
      final a = await service.addLocalPdf(pdf('a.pdf'));
      await service.savePosition(
        ReadingPosition(bookId: a.item.id, page: 120, scrollOffsetFraction: 0.25, updatedAt: DateTime(2026, 11, 10, 10)),
      );
      final removal = await service.remove(a.item.id);
      await removal.commit();
      final again = await service.addLocalPdf(pdf('a.pdf'));
      expect(again.item.id, a.item.id);
      final c = (await service.continueReading())!;
      expect(c.position.page, 120);
      expect(c.position.scrollOffsetFraction, 0.25);
    });

    test('removing an unknown book is a harmless no-op', () async {
      final r = await service.remove('nope');
      await r.undo();
      await r.commit();
      expect(files.calls, isEmpty);
    });
  });

  group('catalogue books', () {
    LibraryEntry good() => LibraryEntry(
      id: 'g1',
      title: 'Book',
      language: 'en',
      sourceKind: LibrarySourceKind.gutenberg,
      sourceUrl: 'https://www.gutenberg.org/ebooks/1',
      licenceId: 'pg-license',
      licenceUrl: 'https://www.gutenberg.org/policy/license.html',
      credit: 'Project Gutenberg',
      sizeBytes: 10,
      sha256: 'b' * 64,
    );

    test('a licensed entry goes on the shelf and the undo takes it off', () async {
      final undo = await service.addCatalogEntry(good(), localPath: '/app/books/g1.epub');
      expect((await service.list()).single.localPath, '/app/books/g1.epub');
      await undo();
      expect(await service.list(), isEmpty);
    });

    test('an entry that breaks the licence rule is refused and nothing is stored', () async {
      final bad = LibraryEntry(
        id: 'g2', title: 'x', sourceKind: LibrarySourceKind.gutenberg, sourceUrl: 'https://x.org/1',
        licenceUrl: 'https://x.org/l', credit: 'c', sizeBytes: 1, sha256: 'b' * 64,
      );
      await expectLater(service.addCatalogEntry(bad), throwsA(isA<CatalogLicenceException>()));
      expect(await service.list(), isEmpty);
    });
  });
}
