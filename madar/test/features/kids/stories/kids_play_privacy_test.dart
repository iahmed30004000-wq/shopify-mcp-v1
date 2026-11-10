import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The recordings, the stars and the games never leave the phone and never
/// land in the gallery: asserted over the source of the three folders.
void main() {
  final files = [
    for (final dir in ['stories', 'games', 'rewards'])
      ...Directory('lib/features/kids/$dir')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
  ];

  test('there are source files to check', () {
    expect(files.length, greaterThan(20));
  });

  test('no network client, no sharing, no picker, no gallery in the kids play folders', () {
    const forbidden = [
      'HttpClient',
      'package:http/',
      'package:dio/',
      'dart:io\' show Socket',
      'WebSocket',
      'RawSocket',
      'url_launcher',
      'share_plus',
      'file_picker',
      'image_picker',
      'gallery_saver',
      'MediaStore',
      'getExternalStorageDirectory',
      'getDownloadsDirectory',
      'firebase',
      'webview_flutter',
      'nearby_connections',
    ];
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final word in forbidden) {
        expect(src.contains(word), isFalse, reason: '${f.path} mentions $word');
      }
    }
  });

  test('recordings go in the app\'s private support folder, nowhere else', () {
    final src = File('lib/features/kids/stories/data/voice_files.dart').readAsStringSync();
    expect(src, contains('getApplicationSupportDirectory'));
    expect(src, isNot(contains('getExternalStorage')));
    expect(
      src,
      isNot(contains('getTemporaryDirectory')),
      reason: 'the system may empty the cache; recordings must stay',
    );
  });

  test('the story microphone listens and keeps nothing: it uses a PCM stream, not a file', () {
    final src = File('lib/features/kids/stories/data/voice_recorder.dart').readAsStringSync();
    final meter = src.substring(src.indexOf('class RecordSoundMeter'));
    expect(meter, contains('startStream'));
    expect(meter, isNot(contains('path:')));
  });

  test('stars never lock anything and nothing takes them away', () {
    for (final f in files) {
      final src = f.readAsStringSync();
      expect(
        RegExp(r'kidsStarCountProvider\)\s*[<>]=?\s*\d').hasMatch(src),
        isFalse,
        reason: '${f.path} gates on the star count',
      );
    }
    final ledger = File('lib/features/kids/rewards/domain/rewards_ledger.dart').readAsStringSync();
    expect(RegExp(r'\b(remove|removeWhere|clear|subtract)\b').hasMatch(ledger), isFalse);
  });

  test('no red in the child screens (design: a child is never told he is wrong)', () {
    for (final f in files.where((f) => f.path.contains('presentation'))) {
      final src = f.readAsStringSync();
      expect(src.contains('Colors.red'), isFalse, reason: f.path);
      expect(src.contains('Colors.redAccent'), isFalse, reason: f.path);
    }
  });
}
