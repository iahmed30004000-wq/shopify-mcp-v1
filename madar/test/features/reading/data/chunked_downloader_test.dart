import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/data/chunked_downloader.dart';
import 'package:madar/features/reading/data/download_ports.dart';
import 'package:madar/features/reading/domain/download_plan.dart';

import 'support/reading_fakes.dart';

const _partSize = 100;
const _parts = 8;

void main() {
  late FakeRangeHttpClient client;
  late FakeDownloadStateStore store;
  late FakeFreeSpaceProbe space;
  late FakeFileSink sink;
  late FakeConnectivityProbe net;
  late List<Duration> delays;

  final content = sampleBytes(_partSize * _parts);

  DownloadPlan plan({bool partHashes = false, bool wholeHash = true}) {
    final base = const DownloadPlanner(partSizeBytes: _partSize).forSize(
      id: 'book',
      url: Uri.parse('https://example.org/book.zim'),
      totalBytes: content.length,
      sha256: wholeHash ? hashOf(content) : null,
    );
    if (!partHashes) return base;
    return DownloadPlan(
      id: base.id,
      url: base.url,
      totalBytes: base.totalBytes,
      sha256: base.sha256,
      parts: [
        for (final p in base.parts)
          PlannedPart(index: p.index, start: p.start, length: p.length, sha256: hashOf(content.sublist(p.start, p.end + 1))),
      ],
    );
  }

  ChunkedDownloader make({DownloaderConfig? config}) => ChunkedDownloader(
    client: client,
    store: store,
    space: space,
    sink: sink,
    connectivity: net,
    delay: (d) async => delays.add(d),
    config: config ?? const DownloaderConfig(reserveBytes: 0, maxAttempts: 3),
  );

  setUp(() {
    client = FakeRangeHttpClient(content);
    store = FakeDownloadStateStore();
    space = FakeFreeSpaceProbe(1 << 40);
    sink = FakeFileSink();
    net = FakeConnectivityProbe();
    delays = [];
  });

  test('downloads every part, verifies the whole file and joins it', () async {
    final d = make();
    final events = <DownloadProgress>[];
    d.progress.listen(events.add);
    final r = await d.download(plan());
    await pumpEventQueue();
    expect(r.status, DownloadStatus.completed);
    expect(r.location, '/books/book');
    expect(sink.finalFiles['book'], content);
    expect(client.headCalls, 1);
    expect(client.rangeRequests.length, _parts);
    expect(client.rangeRequests.first, (0, 99));
    expect(client.rangeRequests.last, (700, 799));
    expect(events.map((e) => e.status), contains(DownloadStatus.verifying));
    final bytes = events.map((e) => e.completedBytes).toList();
    expect(bytes, orderedEquals([...bytes]..sort()));
    expect(events.last.status, DownloadStatus.completed);
    expect(events.last.fraction, 1.0);
    expect(store.states['book']!.status, DownloadStatus.completed);
  });

  test('a finished download is not fetched again', () async {
    await make().download(plan());
    client.rangeRequests.clear();
    final r = await make().download(plan());
    expect(r.status, DownloadStatus.completed);
    expect(client.totalRequests, 1); // just the earlier head
  });

  group('resume', () {
    test('a cut at part 3 of 8 pauses, and resuming after a restart refetches only what is missing', () async {
      client.beforeRange = (start, _) {
        if (start == 200) throw const TransportException('connection reset');
      };
      final first = await make().download(plan());
      expect(first.status, DownloadStatus.paused);
      expect(first.pauseReason, PauseReason.connectionLost);
      expect(first.completedParts, 2);
      expect(delays, [const Duration(seconds: 1), const Duration(seconds: 2)]);
      expect(store.states['book']!.completedParts, {0, 1});
      expect(sink.parts.length, 2);

      // The app is restarted: a brand-new downloader on the same store and disk.
      client.beforeRange = null;
      client.rangeRequests.clear();
      final second = await make().download(plan());
      expect(second.status, DownloadStatus.completed);
      expect(client.rangeRequests.map((r) => r.$1), [200, 300, 400, 500, 600, 700]);
      expect(sink.finalFiles['book'], content);
    });

    test('a part the note says is done but is missing on disk is fetched again', () async {
      store.states['book'] = DownloadState(
        id: 'book',
        fingerprint: plan().fingerprint,
        completedParts: {0, 1, 2},
        status: DownloadStatus.paused,
      );
      final r = await make().download(plan());
      expect(r.status, DownloadStatus.completed);
      expect(client.rangeRequests.length, _parts);
    });

    test('progress saved for a different file is thrown away', () async {
      client.beforeRange = (start, _) {
        if (start == 300) throw const TransportException('cut');
      };
      await make().download(plan());
      client.beforeRange = null;
      client.rangeRequests.clear();
      final other = DownloadPlan(
        id: 'book',
        url: Uri.parse('https://example.org/book-v2.zim'),
        totalBytes: content.length,
        sha256: hashOf(content),
        parts: plan().parts,
      );
      final r = await make().download(other);
      expect(r.status, DownloadStatus.completed);
      expect(client.rangeRequests.length, _parts);
    });
  });

  group('retries', () {
    test('backoff doubles and is capped; a recovered request continues without pausing', () async {
      var fails = 0;
      client.beforeRange = (start, _) {
        if (start == 100 && fails < 6) {
          fails++;
          throw const TransportException('timeout');
        }
      };
      final r = await make(
        config: const DownloaderConfig(
          reserveBytes: 0,
          maxAttempts: 8,
          backoffBase: Duration(seconds: 1),
          backoffCap: Duration(seconds: 4),
        ),
      ).download(plan());
      expect(r.status, DownloadStatus.completed);
      expect(delays.map((d) => d.inSeconds), [1, 2, 4, 4, 4, 4]);
    });

    test('a short read counts as a failed try', () async {
      client.shortReadOnce.add(0);
      final r = await make().download(plan());
      expect(r.status, DownloadStatus.completed);
      expect(delays.length, 1);
      expect(client.rangeRequests.where((q) => q.$1 == 0).length, 2);
    });

    test('a 404 is not retried and fails the download', () async {
      client.beforeRange = (start, _) {
        throw const TransportException('not found', statusCode: 404, retryable: false);
      };
      final r = await make().download(plan());
      expect(r.status, DownloadStatus.failed);
      expect(r.failure, DownloadFailure.serverRejected);
      expect(client.rangeRequests.length, 1);
      expect(delays, isEmpty);
    });
  });

  group('integrity', () {
    test('a corrupt part is caught by its SHA-256 and fetched once more', () async {
      client.corruptOnce.add(300);
      final r = await make().download(plan(partHashes: true));
      expect(r.status, DownloadStatus.completed);
      expect(client.rangeRequests.where((q) => q.$1 == 300).length, 2);
      expect(sink.writes.where((w) => w == 'book#3').length, 1); // the bad copy was never written
      expect(sink.finalFiles['book'], content);
    });

    test('a part that is corrupt twice fails instead of looping', () async {
      client.corruptAlways.add(300);
      final r = await make().download(plan(partHashes: true));
      expect(r.status, DownloadStatus.failed);
      expect(r.failure, DownloadFailure.partChecksumMismatch);
      expect(client.rangeRequests.where((q) => q.$1 == 300).length, 2);
      expect(r.completedParts, 3); // 0..2 are kept
    });

    test('with no part hashes a bad whole file is caught at the end and discarded', () async {
      client.corruptOnce.add(300);
      final r = await make().download(plan());
      expect(r.status, DownloadStatus.failed);
      expect(r.failure, DownloadFailure.checksumMismatch);
      expect(sink.parts, isEmpty);
      expect(sink.finalFiles, isEmpty);
      expect(store.states['book'], isNull);
    });

    test('a server that reports another length is refused before any range request', () async {
      client.lengthOverride = content.length + 1;
      final r = await make().download(plan());
      expect(r.failure, DownloadFailure.sizeMismatch);
      expect(client.rangeRequests, isEmpty);
    });

    test('a server without range support is refused', () async {
      client.acceptsRanges = false;
      final r = await make().download(plan());
      expect(r.failure, DownloadFailure.rangesUnsupported);
      expect(client.rangeRequests, isEmpty);
    });
  });

  group('storage full', () {
    test('detected BEFORE start: pauses with zero requests', () async {
      space.free = 799;
      final r = await make().download(plan());
      expect(r.status, DownloadStatus.paused);
      expect(r.pauseReason, PauseReason.storageFull);
      expect(client.totalRequests, 0);
    });

    test('the reserve is part of the check', () async {
      space.free = 800;
      final r = await make(config: const DownloaderConfig(reserveBytes: 1)).download(plan());
      expect(r.pauseReason, PauseReason.storageFull);
      expect(client.totalRequests, 0);
    });

    test('mid-way the disk fills: pauses cleanly and keeps the finished parts, then resumes', () async {
      sink.capacityBytes = 350; // three parts fit, the fourth write fails
      final r = await make().download(plan());
      expect(r.status, DownloadStatus.paused);
      expect(r.pauseReason, PauseReason.storageFull);
      expect(r.completedParts, 3);
      expect(sink.parts.length, 3);
      expect(store.states['book']!.completedParts, {0, 1, 2});
      expect(store.states['book']!.pauseReason, PauseReason.storageFull);

      sink.capacityBytes = null; // he cleared some space
      client.rangeRequests.clear();
      final again = await make().download(plan());
      expect(again.status, DownloadStatus.completed);
      expect(client.rangeRequests.map((q) => q.$1), [300, 400, 500, 600, 700]);
      expect(sink.finalFiles['book'], content);
    });

    test('space probe shrinking between parts pauses before the next request', () async {
      client.beforeRange = (start, _) {
        if (start == 200) space.free = 50;
      };
      final r = await make().download(plan());
      expect(r.pauseReason, PauseReason.storageFull);
      expect(r.completedParts, 3);
      expect(client.rangeRequests.last.$1, 200);
    });

    test('hasRoomFor counts only what is still missing', () async {
      final p = plan();
      space.free = 300;
      expect(await hasRoomFor(p, {0, 1, 2, 3, 4}, space), isTrue);
      expect(await hasRoomFor(p, {}, space), isFalse);
      expect(await hasRoomFor(p, {0, 1, 2, 3, 4}, space, reserveBytes: 1), isFalse);
    });
  });

  group('Wi-Fi only', () {
    test('on mobile data it waits and touches nothing', () async {
      net.kind = NetworkKind.cellular;
      final r = await make().download(plan(), wifiOnly: true);
      expect(r.status, DownloadStatus.paused);
      expect(r.pauseReason, PauseReason.waitingForWifi);
      expect(client.totalRequests, 0);
    });

    test('on ethernet it counts as unmetered and runs', () async {
      net.kind = NetworkKind.ethernet;
      expect((await make().download(plan(), wifiOnly: true)).status, DownloadStatus.completed);
    });

    test('the option off lets mobile data through', () async {
      net.kind = NetworkKind.cellular;
      expect((await make().download(plan())).status, DownloadStatus.completed);
    });

    test('no network at all pauses as offline', () async {
      net.kind = NetworkKind.none;
      final r = await make().download(plan());
      expect(r.pauseReason, PauseReason.offline);
      expect(client.totalRequests, 0);
    });

    test('leaving Wi-Fi mid-way pauses at the next part and keeps what is done', () async {
      client.beforeRange = (start, _) {
        if (start == 300) net.kind = NetworkKind.cellular;
      };
      final r = await make().download(plan(), wifiOnly: true);
      expect(r.pauseReason, PauseReason.waitingForWifi);
      expect(r.completedParts, 4);
    });
  });

  group('pause and cancel', () {
    test('pause lets the part in flight finish, then stops; resume completes', () async {
      final d = make();
      client.beforeRange = (start, _) {
        if (start == 200) d.pause();
      };
      final r = await d.download(plan());
      expect(r.status, DownloadStatus.paused);
      expect(r.pauseReason, PauseReason.user);
      expect(r.completedParts, 3);
      expect(d.isRunning, isFalse);

      client.beforeRange = null;
      client.rangeRequests.clear();
      final again = await d.download(plan()); // the same downloader can be restarted
      expect(again.status, DownloadStatus.completed);
      expect(client.rangeRequests.length, 5);
    });

    test('cancel removes the parts and the saved progress', () async {
      final d = make();
      client.beforeRange = (start, _) {
        if (start == 200) d.cancel();
      };
      final r = await d.download(plan());
      expect(r.status, DownloadStatus.cancelled);
      expect(sink.parts, isEmpty);
      expect(store.states['book'], isNull);
    });

    test('only one run at a time per downloader', () async {
      final d = make();
      final gate = Completer<void>();
      client.beforeRange = (_, _) => gate.future;
      final run = d.download(plan());
      await pumpEventQueue();
      await expectLater(d.download(plan()), throwsStateError);
      gate.complete();
      expect((await run).status, DownloadStatus.completed);
    });
  });

  test('limited parallelism fetches several parts at once and still joins them in order', () async {
    var inFlight = 0;
    var peak = 0;
    client.beforeRange = (_, _) async {
      peak = peak < ++inFlight ? inFlight : peak;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      inFlight--;
    };
    final r = await make(config: const DownloaderConfig(reserveBytes: 0, maxParallel: 3)).download(plan());
    expect(r.status, DownloadStatus.completed);
    expect(peak, 3);
    expect(sink.finalFiles['book'], content);
    expect(store.states['book']!.completedParts.length, _parts);
  });

  test('the state survives a JSON round-trip', () {
    const s = DownloadState(
      id: 'b', fingerprint: 'f', completedParts: {3, 1}, status: DownloadStatus.paused, pauseReason: PauseReason.storageFull,
    );
    final back = DownloadState.fromJson(s.toJson());
    expect(back.completedParts, {1, 3});
    expect(back.pauseReason, PauseReason.storageFull);
    expect(back.status, DownloadStatus.paused);
  });
}
