// THE CONTENT CONTRACT. These tests fail the build when any religious item
// that is bundled lacks its source, a hadith lacks its grading, or an item is
// half signed off; and they pin how an unapproved item is treated.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/kids/faith/data/kids_religious_loader.dart';
import 'package:madar/features/kids/faith/domain/kids_religious_item.dart';

import '../../quran/quran_test_data.dart';
import 'faith_harness.dart';

KidsReligiousItem _base({
  String id = 'a',
  KidsReligiousKind kind = KidsReligiousKind.manner,
  String text = 'T',
  String source = 'Some source',
  String? grading,
  bool hadith = false,
  String? reviewer,
  DateTime? reviewedOn,
  AyahRef? ref,
  String? group,
  int? repeat,
}) => KidsReligiousItem(
  id: id,
  kind: kind,
  arabicText: text,
  source: source,
  grading: grading,
  isHadith: hadith,
  reviewer: reviewer,
  reviewedOn: reviewedOn,
  quranRef: ref,
  group: group,
  repeat: repeat,
);

List<String> _problems(List<KidsReligiousItem> i) => [for (final p in validateKidsReligiousItems(i)) p.message];

void main() {
  group('the validator', () {
    test('a complete, signed item has no problem', () {
      expect(_problems([_base(reviewer: 'R', reviewedOn: signedOn)]), isEmpty);
    });

    test('a missing or blank source is a problem', () {
      expect(_problems([_base(source: '')]), contains('missing source'));
      expect(_problems([_base(source: '   ')]), contains('missing source'));
    });

    test('a hadith needs its grading', () {
      expect(_problems([_base(hadith: true)]), contains('a hadith needs its grading (sahih / hasan ...)'));
      expect(_problems([_base(hadith: true, grading: 'sahih')]), isEmpty);
    });

    test('a source that reads like a hadith book needs a grading even if nobody ticked hadith', () {
      expect(_problems([_base(source: 'Sahih Muslim #12')]), isNotEmpty);
      expect(_problems([_base(source: 'Sahih Muslim #12', grading: 'sahih')]), isEmpty);
      expect(_problems([_base(source: 'رواه البخاري')]), isNotEmpty);
    });

    test('half a sign-off is a problem, in both directions', () {
      expect(_problems([_base(reviewer: 'R')]), contains('reviewer and reviewedOn must be set together'));
      expect(_problems([_base(reviewedOn: signedOn)]), contains('reviewer and reviewedOn must be set together'));
    });

    test('ids are required and unique, text is required', () {
      expect(_problems([_base(id: '')]), contains('missing id'));
      expect(_problems([_base(id: 'x'), _base(id: 'x')]), contains('duplicate id'));
      expect(_problems([_base(text: ' ')]), contains('empty text'));
    });

    test('kind-specific fields: quranRef, dhikr group and repeat, story group', () {
      expect(_problems([_base(kind: KidsReligiousKind.quran)]), contains('a Quran item needs quranRef'));
      expect(_problems([_base(kind: KidsReligiousKind.dhikr)]), hasLength(2));
      expect(_problems([_base(kind: KidsReligiousKind.dhikr, group: 'morning', repeat: 3)]), isEmpty);
      expect(_problems([_base(kind: KidsReligiousKind.story)]), contains('a story page needs its story group'));
    });

    test('approved means reviewer and date, both', () {
      expect(_base().approved, isFalse);
      expect(_base(reviewer: 'R').approved, isFalse);
      expect(_base(reviewer: ' ', reviewedOn: signedOn).approved, isFalse);
      expect(_base(reviewer: 'R', reviewedOn: signedOn).approved, isTrue);
    });
  });

  group('parsing', () {
    test('a name outside the art allow-list is refused (there is no person to ask for)', () {
      expect(
        () => KidsReligiousItem.fromJson({
          'id': 'x',
          'kind': 'story',
          'art': ['dunes', 'person'],
        }),
        throwsFormatException,
      );
    });

    test('an unknown kind is refused', () {
      expect(() => KidsReligiousItem.fromJson({'id': 'x', 'kind': 'poem'}), throwsFormatException);
    });
  });

  group('the loader', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('kids_religious_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<KidsReligiousLoadResult> load() => loadKidsReligious(DiskAssetBundle(), dir: tmp.path);

    void write(String name, Object json) => File('${tmp.path}/$name').writeAsStringSync(jsonEncode(json));

    test('no index at all is simply no content', () async {
      final r = await load();
      expect(r.items, isEmpty);
      expect(r.problems, isEmpty);
    });

    test('an index that lists a file that is not there is reported', () async {
      write('index.json', {
        'files': ['gone.json'],
      });
      expect((await load()).problems.single.message, contains('missing'));
    });

    test('garbage does not throw', () async {
      File('${tmp.path}/index.json').writeAsStringSync('not json');
      expect((await load()).problems, isNotEmpty);
      write('index.json', {
        'files': ['a.json'],
      });
      File('${tmp.path}/a.json').writeAsStringSync('{{');
      expect((await load()).problems, isNotEmpty);
    });

    test('only signed, valid items are approved', () async {
      write('index.json', {
        'files': ['a.json'],
      });
      write('a.json', {
        'items': [
          {
            'id': 'signed',
            'kind': 'manner',
            'arabicText': 'T',
            'source': 'S',
            'reviewer': 'R',
            'reviewedOn': '2026-11-01',
          },
          {'id': 'unsigned', 'kind': 'manner', 'arabicText': 'T', 'source': 'S'},
          // signed but no source: must never reach a child
          {'id': 'nosource', 'kind': 'manner', 'arabicText': 'T', 'reviewer': 'R', 'reviewedOn': '2026-11-01'},
        ],
      });
      final r = await load();
      expect(r.items, hasLength(3));
      expect([for (final i in r.approved) i.id], ['signed']);
      expect(r.problems.map((p) => p.itemId), ['nosource']);
    });
  });

  // ---------------------------------------------------------------- the gate
  group('THE BUILD-FAILING CHECK over assets/kids_religious/', () {
    const dir = 'assets/kids_religious';

    test('the folder ships with its index', () {
      expect(File('$dir/index.json').existsSync(), isTrue);
    });

    test('every bundled item has its source, every hadith its grading, no half sign-off', () async {
      final r = await loadKidsReligious(DiskAssetBundle(), dir: dir);
      expect(r.problems, isEmpty, reason: 'Religious content breaks the contract:\n${r.problems.join('\n')}');
    });

    test('no json file sits in the folder unlisted (it would be silently ignored)', () {
      final listed = ((jsonDecode(File('$dir/index.json').readAsStringSync()) as Map)['files'] as List).cast<String>();
      final onDisk = [
        for (final f in Directory(dir).listSync().whereType<File>())
          if (f.path.endsWith('.json') && !f.path.endsWith('index.json')) f.uri.pathSegments.last,
      ];
      expect(onDisk.toSet().difference(listed.toSet()), isEmpty);
    });

    test('a Quran item is exactly the bundled Tanzil text of its ayah (never typed by hand)', () async {
      final r = await loadKidsReligious(DiskAssetBundle(), dir: dir);
      final meta = QuranTestData.meta;
      final text = QuranTestData.text;
      for (final i in r.items.where((i) => i.kind == KidsReligiousKind.quran)) {
        expect(i.arabicText, text.ayahText(meta.indexOf(i.quranRef!)), reason: '${i.id} differs from Tanzil');
      }
    });

    test('nothing is rendered without approval: unapproved items are not in `approved`', () async {
      final r = await loadKidsReligious(DiskAssetBundle(), dir: dir);
      expect(r.approved.every((i) => i.approved), isTrue);
    });
  });
}
