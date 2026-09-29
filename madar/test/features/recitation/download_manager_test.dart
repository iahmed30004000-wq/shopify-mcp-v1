import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/recitation/data/download_manager.dart';
import 'package:madar/features/recitation/data/network_probe.dart';
import 'package:madar/features/recitation/data/recitation_storage.dart';
import 'package:madar/features/recitation/domain/download_models.dart';
import 'package:madar/features/recitation/domain/reciters.dart';

import 'recitation_fakes.dart';

const reciter = Reciters.husaryMurattal;

void main() {
  late Directory root;
  late FakeTransport transport;
  late FixedNetworkProbe network;
  late bool wifiOnly;
  late RecitationDownloads downloads;

  RecitationDownloads make({int concurrency = 3}) => RecitationDownloads(
    storage: RecitationStorage.at(root),
    transport: transport,
    network: network,
    wifiOnly: () => wifiOnly,
    concurrency: concurrency,
    retryDelay: Duration.zero,
    progressInterval: Duration.zero,
  );

  File fileOf(String name) => File('${root.path}/${reciter.folder}/$name');

  setUp(() {
    root = Directory.systemTemp.createTempSync('madar_recitation_');
    transport = FakeTransport(fileSize: 1000, chunk: 250);
    network = FixedNetworkProbe(wifi: true);
    wifiOnly = true;
    downloads = make();
  });

  tearDown(() async {
    await downloads.whenIdle();
    await downloads.flush();
    downloads.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('downloads a surah with its basmala (stored once as basmala.mp3)', () async {
    await downloads.download(reciter, [112]);
    expect(downloads.statusOf(reciter.id, 112).status, isIn([DownloadStatus.queued, DownloadStatus.downloading]));
    await downloads.whenIdle();
    final d = downloads.statusOf(reciter.id, 112);
    expect(d.status, DownloadStatus.complete);
    expect(d.filesDone, 5);
    expect(d.filesTotal, 5);
    expect(d.bytes, 4000);
    for (var a = 1; a <= 4; a++) {
      final f = fileOf('11200$a.mp3');
      expect(
        f.readAsBytesSync(),
        FakeTransport.bytesFor(Uri.parse('https://everyayah.com/data/${reciter.folder}/11200$a.mp3'), 1000),
      );
    }
    expect(fileOf('basmala.mp3').existsSync(), isTrue);
    expect(transport.requests.map((r) => r.uri.path), contains('/data/${reciter.folder}/001001.mp3'));
    expect(downloads.summaryOf(reciter.id).bytes, 5000);
    expect(downloads.summaryOf(reciter.id).completeSurahs, 1);
    expect(downloads.localFile(reciter, const AyahRef(112, 2))!.path, fileOf('112002.mp3').path);
    expect(downloads.localFile(reciter, const AyahRef(112, 1), basmala: true)!.path, fileOf('basmala.mp3').path);
    expect(downloads.localFile(reciter, const AyahRef(113, 1)), isNull);
  });

  test('al-Fatihah and at-Tawbah need no extra basmala', () async {
    await downloads.download(reciter, [1]);
    await downloads.whenIdle();
    expect(downloads.statusOf(reciter.id, 1).filesTotal, 7);
    expect(fileOf('basmala.mp3').existsSync(), isFalse);
    // 001001 doubles as the basmala for other surahs.
    expect(downloads.localFile(reciter, const AyahRef(2, 1), basmala: true)!.path, fileOf('001001.mp3').path);
    await downloads.download(reciter, [113]);
    await downloads.whenIdle();
    expect(transport.requests.where((r) => r.uri.path.endsWith('001001.mp3')), hasLength(1));
    expect(downloads.statusOf(reciter.id, 113).isComplete, isTrue);
  });

  test('never exceeds the concurrency limit', () async {
    await downloads.flush();
    downloads.dispose();
    downloads = make(concurrency: 2);
    await downloads.download(reciter, [2]); // 287 files
    await downloads.whenIdle();
    expect(transport.maxConcurrent, 2);
    expect(downloads.statusOf(reciter.id, 2).isComplete, isTrue);
  });

  test('resumes a cut file with a range request', () async {
    transport.cutOnce['https://everyayah.com/data/${reciter.folder}/114003.mp3'] = 1;
    await downloads.download(reciter, [114]);
    await downloads.whenIdle();
    final third = transport.requests.where((r) => r.uri.path.endsWith('114003.mp3')).toList();
    expect(third, hasLength(2));
    expect(third.first.from, 0);
    expect(third.last.from, 500);
    expect(fileOf('114003.mp3').readAsBytesSync(), FakeTransport.bytesFor(third.first.uri, 1000));
    expect(downloads.statusOf(reciter.id, 114).isComplete, isTrue);
    expect(downloads.statusOf(reciter.id, 114).bytes, 6000);
  });

  test('a server ignoring the range rewrites the part from zero', () async {
    await fileOf('x').parent.create(recursive: true);
    File('${fileOf('114001.mp3').path}.part').writeAsBytesSync(List.filled(300, 7));
    transport.ignoreRanges = true;
    await downloads.download(reciter, [114]);
    await downloads.whenIdle();
    final first = transport.requests.firstWhere((r) => r.uri.path.endsWith('114001.mp3'));
    expect(first.from, 300);
    expect(fileOf('114001.mp3').readAsBytesSync(), FakeTransport.bytesFor(first.uri, 1000));
    expect(downloads.statusOf(reciter.id, 114).bytes, 6000);
  });

  test('pause keeps the parts; resume continues; nothing restarts by itself', () async {
    transport.gate = Completer<void>();
    await downloads.download(reciter, [114]);
    await settle();
    expect(downloads.statusOf(reciter.id, 114).status, DownloadStatus.downloading);
    await downloads.pause(reciter, 114);
    transport.gate!.complete();
    transport.gate = null;
    await settle(40);
    await downloads.whenIdle();
    expect(downloads.statusOf(reciter.id, 114).status, DownloadStatus.paused);
    final requested = transport.requests.length;
    await settle(40);
    expect(transport.requests.length, requested, reason: 'paused work never restarts by itself');

    await downloads.resume(reciter, 114);
    await downloads.whenIdle();
    expect(downloads.statusOf(reciter.id, 114).isComplete, isTrue);
  });

  test('cancel removes what the surah downloaded', () async {
    transport.gate = Completer<void>();
    await downloads.download(reciter, [114]);
    await settle();
    await downloads.cancel(reciter, 114);
    transport.gate!.complete();
    transport.gate = null;
    await downloads.whenIdle();
    expect(downloads.statusOf(reciter.id, 114).status, DownloadStatus.none);
    final left = Directory('${root.path}/${reciter.folder}')
        .listSync()
        .map((e) => e.path.split('/').last)
        .where((n) => n.startsWith('114'));
    expect(left, isEmpty);
    expect(downloads.summaryOf(reciter.id).bytes, 0);
  });

  test('a 404 fails the surah with notFound', () async {
    transport.missing.add('https://everyayah.com/data/${reciter.folder}/114004.mp3');
    await downloads.download(reciter, [114]);
    await downloads.whenIdle();
    final d = downloads.statusOf(reciter.id, 114);
    expect(d.status, DownloadStatus.failed);
    expect(d.error, DownloadError.notFound);
  });

  test('Wi-Fi only: off Wi-Fi nothing is fetched and the surahs wait', () async {
    network.wifi = false;
    await downloads.download(reciter, [113, 114]);
    await downloads.whenIdle();
    expect(transport.requests, isEmpty);
    expect(downloads.statusOf(reciter.id, 113).status, DownloadStatus.waitingForWifi);
    expect(downloads.statusOf(reciter.id, 114).status, DownloadStatus.waitingForWifi);
    // With Wi-Fi only off it goes over any network.
    wifiOnly = false;
    await downloads.resumeAll(reciter: reciter);
    await downloads.whenIdle();
    expect(downloads.statusOf(reciter.id, 114).isComplete, isTrue);
  });

  test('the index persists; in-flight work comes back paused; disk is re-counted', () async {
    transport.gate = Completer<void>();
    await downloads.download(reciter, [113, 114]);
    await settle();
    await downloads.pauseAll();
    transport.gate!.complete();
    transport.gate = null;
    await downloads.whenIdle();
    await downloads.flush();
    final index = jsonDecode(File('${root.path}/downloads.json').readAsStringSync()) as Map;
    expect(((index['reciters'] as Map)[reciter.id] as Map).keys, containsAll(['113', '114']));

    // Fake a crash mid-download: mark 114 as "downloading" in the index.
    final raw = jsonDecode(File('${root.path}/downloads.json').readAsStringSync()) as Map;
    ((raw['reciters'] as Map)[reciter.id] as Map)['114'] = {'s': 'downloading', 'done': 2, 'total': 7, 'bytes': 2000};
    File('${root.path}/downloads.json').writeAsStringSync(jsonEncode(raw));

    final again = make();
    await again.load();
    expect(again.statusOf(reciter.id, 114).status, DownloadStatus.paused);
    expect(again.statusOf(reciter.id, 113).status, DownloadStatus.paused);
    expect(again.busy, isFalse);
    await again.resumeAll();
    await again.whenIdle();
    expect(again.statusOf(reciter.id, 113).isComplete, isTrue);
    expect(again.statusOf(reciter.id, 114).isComplete, isTrue);
    await again.flush();
    again.dispose();
  });

  test('complete surahs are recognised from disk alone', () async {
    await downloads.download(reciter, [114]);
    await downloads.whenIdle();
    File('${root.path}/downloads.json').deleteSync();
    final again = make();
    await again.load();
    expect(again.statusOf(reciter.id, 114).isComplete, isTrue);
    expect(again.summaryOf(reciter.id).bytes, 7000);
    expect(again.totalBytes, 7000);
    await again.flush();
    again.dispose();
  });

  test('delete one surah keeps the shared basmala while another needs it', () async {
    await downloads.download(reciter, [113, 114]);
    await downloads.whenIdle();
    await downloads.delete(reciter, surah: 114);
    expect(downloads.statusOf(reciter.id, 114).status, DownloadStatus.none);
    expect(fileOf('basmala.mp3').existsSync(), isTrue);
    await downloads.delete(reciter, surah: 113);
    expect(fileOf('basmala.mp3').existsSync(), isFalse);
    expect(downloads.summaryOf(reciter.id).isEmpty, isTrue);
  });

  test('delete a reciter removes everything', () async {
    await downloads.download(reciter, [114]);
    await downloads.whenIdle();
    await downloads.delete(reciter);
    expect(Directory('${root.path}/${reciter.folder}').existsSync(), isFalse);
    expect(downloads.reciterIds, isEmpty);
    expect(downloads.totalBytes, 0);
  });
}
