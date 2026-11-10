// The download of the optional weights: unverified entries never start, the
// fingerprint gates the start, Wi-Fi only by default, resumable, cancellable,
// removable, SHA-256 verified, stored in a private folder. Built on Part 17's
// ChunkedDownloader and its fakes; the sink is the real one over a temporary
// directory.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ondevice_ai/data/model_download_manager.dart';
import 'package:madar/features/ondevice_ai/data/model_storage.dart';
import 'package:madar/features/ondevice_ai/domain/model_catalog.dart';
import 'package:madar/features/reading/data/chunked_downloader.dart';
import 'package:madar/features/reading/data/download_ports.dart';
import 'package:madar/features/reading/domain/download_plan.dart';

import '../reading/data/support/reading_fakes.dart';
import 'support/ondevice_fakes.dart';

void main() {
  late Directory root;
  late Uint8List content;
  late FakeRangeHttpClient http;
  late FakeFreeSpaceProbe space;
  late FakeConnectivityProbe net;
  late FakeAuthGate auth;
  late DirectoryModelSink sink;
  late FileDownloadStateStore store;
  late ModelDownloadManager manager;
  late ModelCatalogEntry entry;

  ModelDownloadManager build() => ModelDownloadManager(
    auth: auth,
    store: store,
    sink: sink,
    planner: const DownloadPlanner(partSizeBytes: 16),
    newDownloader: () => ChunkedDownloader(
      client: http,
      store: store,
      space: space,
      sink: sink,
      connectivity: net,
      delay: (_) async {},
      config: const DownloaderConfig(maxAttempts: 2, reserveBytes: 0),
    ),
  );

  setUp(() async {
    root = await Directory.systemTemp.createTemp('madar-ondevice-');
    content = sampleBytes(50); // 4 parts of 16, 16, 16, 2
    http = FakeRangeHttpClient(content);
    space = FakeFreeSpaceProbe(1 << 30);
    net = FakeConnectivityProbe(NetworkKind.wifi);
    auth = FakeAuthGate();
    Future<Directory> dir() async => root;
    sink = DirectoryModelSink(dir);
    store = FileDownloadStateStore(dir);
    manager = build();
    entry = ModelCatalogEntry(
      id: 'test-org/test-model',
      displayName: 'Test model',
      kind: ModelKind.language,
      license: 'Apache-2.0',
      sourcePage: 'https://example.com/model',
      notes: 'test',
      sizeBytes: content.length,
      sha256: hashOf(content),
      downloadUrl: 'https://example.com/model.bin',
      unverified: false,
    );
  });

  tearDown(() async {
    await manager.dispose();
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('the catalogue', () {
    test('both placeholder entries are unverified and can never start', () async {
      expect(ModelCatalog.entries.length, 2);
      for (final e in ModelCatalog.entries) {
        expect(e.unverified, isTrue, reason: e.id);
        expect(e.canDownload, isFalse, reason: e.id);
        final r = await manager.start(e);
        expect(r.started, isFalse);
        expect(r.refusal, StartRefusal.unverified);
      }
      expect(auth.asked, 0, reason: 'nothing is asked of him for a download that cannot run');
      expect(http.totalRequests, 0, reason: 'not one request');
    });

    test('the recitation placeholder says what is and is not known', () {
      final e = ModelCatalog.byId(ModelCatalog.recitationId)!;
      expect(e.id, 'tarteel-ai/whisper-base-ar-quran');
      expect(e.license, 'Apache-2.0');
      expect(e.kind, ModelKind.recitation);
      expect(e.notes, contains('Whisper Base'));
      expect(e.notes, contains('77M'));
      expect(e.notes, contains('does not document its training data'));
      expect(e.sha256, isNull);
      expect(e.downloadUrl, isNull);
    });

    test('the Gemma entry is marked unverified', () {
      final e = ModelCatalog.byId(ModelCatalog.gemmaId)!;
      expect(e.unverified, isTrue);
      expect(e.kind, ModelKind.language);
    });

    test('verified is not enough: a download also needs a size, a SHA-256 and an HTTPS address', () async {
      ModelCatalogEntry with_({int? size, String? sha, String? url}) => ModelCatalogEntry(
        id: 'x',
        displayName: 'x',
        kind: ModelKind.language,
        license: 'MIT',
        sourcePage: 'https://example.com',
        notes: '',
        sizeBytes: size,
        sha256: sha,
        downloadUrl: url,
        unverified: false,
      );
      final good = hashOf(content);
      expect(with_(size: 50, sha: good, url: 'https://example.com/a.bin').canDownload, isTrue);
      for (final e in [
        with_(size: 0, sha: good, url: 'https://example.com/a.bin'),
        with_(size: 50, sha: null, url: 'https://example.com/a.bin'),
        with_(size: 50, sha: 'ABC', url: 'https://example.com/a.bin'),
        with_(size: 50, sha: good, url: null),
        with_(size: 50, sha: good, url: 'http://example.com/a.bin'),
        with_(size: 50, sha: good, url: 'ftp://example.com/a.bin'),
      ]) {
        expect(e.canDownload, isFalse);
        final r = await manager.start(e);
        expect(r.refusal, StartRefusal.incomplete);
      }
      expect(http.totalRequests, 0);
    });
  });

  group('the fingerprint gates the start', () {
    test('refused fingerprint: nothing is downloaded and nothing is written', () async {
      auth.allow = false;
      final r = await manager.start(entry);
      expect(r.refusal, StartRefusal.authDenied);
      expect(auth.asked, 1);
      expect(http.totalRequests, 0);
      expect(root.listSync(), isEmpty);
    });

    test('accepted fingerprint: the download runs', () async {
      final r = await manager.start(entry);
      expect(r.started, isTrue);
      final s = await r.finished!;
      expect(s.status, ModelInstallStatus.installed);
      expect(auth.asked, 1);
    });
  });

  group('a download', () {
    test('lands in the private folder, whole, with its SHA-256 verified', () async {
      final s = await (await manager.start(entry)).finished!;
      expect(s.status, ModelInstallStatus.installed);
      expect(s.location, startsWith(root.path), reason: 'inside the private folder we were given');
      expect(s.location, isNot(contains('..')));
      expect(File(s.location!).readAsBytesSync(), content);
      expect(sink.finalExists(entry.id), completion(isTrue));
      expect(Directory('${root.path}/test-org_test-model').existsSync(), isFalse, reason: 'the parts are gone');
    });

    test('a model id with a slash becomes one flat, safe name', () {
      expect(DirectoryModelSink.safe('tarteel-ai/whisper-base-ar-quran'), 'tarteel-ai_whisper-base-ar-quran');
      expect(DirectoryModelSink.safe('../../evil'), '.._.._evil');
      expect(DirectoryModelSink.safe('a b/c'), 'a_b_c');
    });

    test('a file that does not match its SHA-256 is deleted and reported', () async {
      http.corruptAlways.add(16);
      // The part has no hash of its own here: the whole-file check catches it.
      final s = await (await manager.start(entry)).finished!;
      expect(s.status, ModelInstallStatus.failed);
      expect(s.failure, DownloadFailure.checksumMismatch);
      expect(await sink.finalExists(entry.id), isFalse);
      expect((await manager.stateOf(entry)).status, ModelInstallStatus.notInstalled);
    });

    test('Wi-Fi only by default: on mobile data it waits and makes no request', () async {
      net.kind = NetworkKind.cellular;
      final s = await (await manager.start(entry)).finished!;
      expect(s.status, ModelInstallStatus.paused);
      expect(s.pauseReason, PauseReason.waitingForWifi);
      expect(http.totalRequests, 0);
    });

    test('with Wi-Fi only switched off, mobile data is allowed', () async {
      net.kind = NetworkKind.cellular;
      final s = await (await manager.start(entry, wifiOnly: false)).finished!;
      expect(s.status, ModelInstallStatus.installed);
    });

    test('no room on the phone: it stops before the first byte', () async {
      space.free = 10;
      final s = await (await manager.start(entry)).finished!;
      expect(s.status, ModelInstallStatus.paused);
      expect(s.pauseReason, PauseReason.storageFull);
      expect(http.rangeRequests, isEmpty);
    });

    test('resumable: a dropped connection keeps the finished parts and the next start fetches only the rest', () async {
      var cut = true;
      http.beforeRange = (start, end) {
        if (cut && start >= 32) throw const TransportException('reset');
      };
      final first = await (await manager.start(entry)).finished!;
      expect(first.status, ModelInstallStatus.paused);
      expect(first.pauseReason, PauseReason.connectionLost);
      expect(first.completedBytes, 32);
      expect((await manager.stateOf(entry)).status, ModelInstallStatus.paused);

      cut = false;
      http.rangeRequests.clear();
      final second = await (await manager.start(entry)).finished!;
      expect(second.status, ModelInstallStatus.installed);
      expect(http.rangeRequests.map((r) => r.$1), [32, 48], reason: 'only the missing parts');
      expect(File(second.location!).readAsBytesSync(), content);
    });

    test('resumable across an app restart: a new manager reads the saved parts', () async {
      http.beforeRange = (start, end) {
        if (start >= 16) throw const TransportException('reset');
      };
      await (await manager.start(entry)).finished!;
      await manager.dispose();

      manager = build();
      http.beforeRange = null;
      http.rangeRequests.clear();
      final s = await (await manager.start(entry)).finished!;
      expect(s.status, ModelInstallStatus.installed);
      expect(http.rangeRequests.map((r) => r.$1), [16, 32, 48]);
    });
  });

  group('cancel and remove', () {
    test('cancel mid-download stops it, throws away the parts, and leaves nothing installed', () async {
      http.beforeRange = (start, end) {
        if (start == 16) manager.cancel(entry.id);
      };
      final states = <ModelInstallStatus>[];
      final sub = manager.changes.listen((s) => states.add(s.status));
      final s = await (await manager.start(entry)).finished!;
      await sub.cancel();
      expect(s.status, ModelInstallStatus.notInstalled);
      expect(await sink.finalExists(entry.id), isFalse);
      expect(Directory('${root.path}/test-org_test-model').existsSync(), isFalse, reason: 'the parts are removed');
      expect((await manager.stateOf(entry)).status, ModelInstallStatus.notInstalled);
      expect(states, contains(ModelInstallStatus.downloading));
      expect(http.rangeRequests.length, lessThan(4), reason: 'it did not carry on to the end');
    });

    test('a second start while one runs is refused', () async {
      Future<StartResult>? second;
      http.beforeRange = (start, end) {
        if (start == 0) second = manager.start(entry);
      };
      final first = await manager.start(entry);
      await first.finished;
      expect((await second!).refusal, StartRefusal.alreadyRunning);
    });

    test('remove frees the file, the saved note and says so', () async {
      await (await manager.start(entry)).finished!;
      expect((await manager.stateOf(entry)).status, ModelInstallStatus.installed);
      final seen = <ModelInstallStatus>[];
      final sub = manager.changes.listen((s) => seen.add(s.status));
      await manager.remove(entry);
      await Future<void>.delayed(Duration.zero); // broadcast events arrive a microtask later
      await sub.cancel();
      expect(await sink.finalExists(entry.id), isFalse);
      expect((await manager.stateOf(entry)).status, ModelInstallStatus.notInstalled);
      expect(seen, [ModelInstallStatus.notInstalled]);
      expect(root.listSync(), isEmpty, reason: 'nothing left in the private folder');
    });

    test('remove works without the fingerprint (it frees space, it costs nothing)', () async {
      await (await manager.start(entry)).finished!;
      auth.allow = false;
      auth.asked = 0;
      await manager.remove(entry);
      expect(auth.asked, 0);
    });

    test('installed survives a restart: a new manager sees the file on disk', () async {
      await (await manager.start(entry)).finished!;
      await manager.dispose();
      manager = build();
      expect((await manager.stateOf(entry)).status, ModelInstallStatus.installed);
      // If the file is deleted behind its back, it is no longer "installed".
      File('${root.path}/test-org_test-model.bin').deleteSync();
      expect((await manager.stateOf(entry)).status, ModelInstallStatus.notInstalled);
    });
  });

  test('a damaged note on disk reads as "not started", never a crash', () async {
    File('${root.path}/test-org_test-model.state.json').writeAsStringSync('{not json');
    expect((await manager.stateOf(entry)).status, ModelInstallStatus.notInstalled);
  });
}
