import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/domain/download_plan.dart';
import 'package:madar/features/reading/domain/library_entry.dart';

import 'support/reading_fakes.dart';

const _mib = 1024 * 1024;

void main() {
  LibraryEntry entry({int size = 3 * 1024 * _mib, List<LibraryPart> parts = const []}) => LibraryEntry(
    id: 'wiki-ar',
    title: 'Wikipedia',
    sourceKind: LibrarySourceKind.kiwix,
    sourceUrl: 'https://download.kiwix.org/zim/wikipedia_ar.zim',
    licenceId: 'cc-by-sa-4.0',
    licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
    credit: 'Wikipedia contributors',
    sizeBytes: size,
    sha256: 'c' * 64,
    parts: parts,
  );

  test('the plan states total size and parts without any request', () {
    final client = FakeRangeHttpClient(sampleBytes(10));
    final plan = const DownloadPlanner().forEntry(entry());
    expect(plan.totalBytes, 3 * 1024 * _mib);
    expect(plan.partCount, 48); // 3 GiB / 64 MiB
    expect(plan.parts.first.length, 64 * _mib);
    // The planner has no client, and nothing was asked of one.
    expect(client.headCalls, 0);
    expect(client.rangeRequests, isEmpty);
    expect(client.totalRequests, 0);
  });

  test('parts tile the file exactly, last part is the remainder', () {
    final plan = const DownloadPlanner(partSizeBytes: 100).forSize(id: 'x', url: Uri.parse('https://a/b'), totalBytes: 250);
    expect(plan.parts.map((p) => (p.start, p.end)), [(0, 99), (100, 199), (200, 249)]);
    expect(plan.parts.fold<int>(0, (a, p) => a + p.length), 250);
  });

  test('an exact multiple has no empty last part', () {
    final plan = const DownloadPlanner(partSizeBytes: 100).forSize(id: 'x', url: Uri.parse('https://a/b'), totalBytes: 300);
    expect(plan.partCount, 3);
  });

  test('a ZIM size alone is enough to plan (tens of gigabytes)', () {
    final plan = const DownloadPlanner().forSize(
      id: 'zim', url: Uri.parse('https://download.kiwix.org/x.zim'), totalBytes: 110 * 1024 * _mib,
    );
    expect(plan.partCount, 110 * 16);
    expect(plan.totalBytes, 110 * 1024 * _mib);
  });

  test('parts declared by the entry are used as they are, with their hashes', () {
    final plan = const DownloadPlanner().forEntry(
      entry(size: 300, parts: [LibraryPart(sizeBytes: 100, sha256: 'd' * 64), const LibraryPart(sizeBytes: 200)]),
    );
    expect(plan.parts.map((p) => (p.start, p.length, p.sha256)), [(0, 100, 'd' * 64), (100, 200, null)]);
  });

  test('unknown size, non-downloadable entries and bad parts are refused', () {
    const planner = DownloadPlanner();
    expect(() => planner.forSize(id: 'x', url: Uri.parse('https://a/b'), totalBytes: 0), throwsArgumentError);
    expect(
      () => planner.forEntry(const LibraryEntry(id: 'p', title: 'p', sourceKind: LibrarySourceKind.localPdf)),
      throwsArgumentError,
    );
    expect(() => planner.forEntry(entry(size: 300, parts: const [LibraryPart(sizeBytes: 100)])), throwsArgumentError);
  });

  test('the fingerprint changes when the file changes', () {
    final a = const DownloadPlanner().forEntry(entry());
    final b = const DownloadPlanner().forEntry(entry(size: 4 * 1024 * _mib));
    expect(a.fingerprint, isNot(b.fingerprint));
  });
}
