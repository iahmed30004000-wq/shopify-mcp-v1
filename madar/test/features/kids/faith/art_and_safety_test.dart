// ArtRule (no person is ever drawn), no network, no red, all sections dark.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/faith/domain/kids_art.dart';

List<File> _sources() => [
  for (final f in Directory('lib/features/kids/faith').listSync(recursive: true).whereType<File>())
    if (f.path.endsWith('.dart')) f,
];

void main() {
  group('ArtRule: places, light and objects only', () {
    test('the enum is exactly the allow-list', () {
      expect({for (final a in KidsArt.values) a.name}, kidsArtAllowList);
    });

    test('no value can name a person, a face or a figure', () {
      final banned = RegExp(
        r'person|people|prophet|nabi|rasul|man$|woman|face|figure|human|child|boy|girl|companion|sahab|angel|body|hand|silhouette|portrait',
        caseSensitive: false,
      );
      for (final a in KidsArt.values) {
        expect(banned.hasMatch(a.name), isFalse, reason: '${a.name} looks like a figure');
      }
    });

    test('byName refuses anything outside the list', () {
      for (final n in ['person', 'prophet', 'face', 'man', 'sahabi', 'Dunes', '']) {
        expect(KidsArt.byName(n), isNull, reason: n);
      }
      expect(KidsArt.byName('dunes'), KidsArt.dunes);
    });

    test('no person icon is used anywhere in the faith folder', () {
      final icon = RegExp(
        r'Icons\.(person|face|man|woman|boy|girl|child|people|accessibility|emoji_people|elderly|sentiment|group)',
      );
      for (final f in _sources()) {
        expect(icon.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });

    test('no image asset is shipped in the faith content folder', () {
      final dir = Directory('assets/kids_religious');
      final imgs = [
        for (final f in dir.listSync(recursive: true).whereType<File>())
          if (RegExp(r'\.(png|jpe?g|webp|svg|gif)$').hasMatch(f.path)) f.path,
      ];
      expect(imgs, isEmpty);
    });
  });

  group('the kids faith code makes no network call and shows no red', () {
    test('no http client, socket, download or Quran.com symbol appears in the folder', () {
      final net = RegExp(
        r'HttpClient|package:http|dart:io|Socket|quranHttpProvider|quranComClientProvider|recitationTransportProvider|QuranComClient|DownloadTransport|quranDownloadsProvider|QuranDownloads|\.download\(',
      );
      for (final f in _sources()) {
        expect(net.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });

    test('no red anywhere', () {
      final red = RegExp(
        r'Colors\.red|redAccent|0xFFFF0000|0xFFE53935|colorScheme\.error|errorContainer|Icons\.(close|cancel|error|dangerous)',
      );
      for (final f in _sources()) {
        expect(red.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
      }
    });
  });

  test('every section of the folder is religious: true, and none says false', () {
    final src = File('lib/features/kids/faith/faith.dart').readAsStringSync();
    expect(RegExp(r'religious: true').allMatches(src).length, 5);
    expect(src.contains('religious: false'), isFalse);
  });
}
