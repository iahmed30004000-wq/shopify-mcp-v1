import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/guide/guide.dart';

GuideEntrySpec _spec(String id, {List<String>? doKeys, List<String> related = const []}) => GuideEntrySpec(
  id: id,
  titleKey: 't.$id',
  purposeKey: 'p.$id',
  exampleKey: 'e.$id',
  doKeys: doKeys ?? ['d1.$id', 'd2.$id'],
  relatedIds: related,
);

void main() {
  group('registry and resolver', () {
    test('builds entries from keys through the resolver, in registry order', () {
      final r = GuideRegistry([_spec('a'), _spec('b', related: ['a'])]);
      expect(r.ids.toList(), ['a', 'b']);
      final e = r.entry('b', (k) => '<$k>')!;
      expect(e.title, '<t.b>');
      expect(e.purpose, '<p.b>');
      expect(e.example, '<e.b>');
      expect(e.doItems, ['<d1.b>', '<d2.b>']);
      expect(e.related, ['a']);
      expect(r.entry('zzz', (k) => k), isNull);
      expect(r.all((k) => k).map((x) => x.id), ['a', 'b']);
    });

    test('the same registry follows the language: only the resolver changes', () {
      final r = GuideRegistry([_spec('a')]);
      expect(r.entry('a', (k) => 'ar:$k')!.title, 'ar:t.a');
      expect(r.entry('a', (k) => 'en:$k')!.title, 'en:t.a');
    });

    test('a resolver that throws on an unknown key fails loudly', () {
      final r = GuideRegistry([_spec('a')]);
      expect(() => r.entry('a', (k) => throw ArgumentError(k)), throwsArgumentError);
    });

    test('duplicate ids are refused, merged registries keep every entry', () {
      expect(() => GuideRegistry([_spec('a'), _spec('a')]), throwsArgumentError);
      final m = GuideRegistry([_spec('a')]).merged(GuideRegistry([_spec('b')]));
      expect(m.ids.toList(), ['a', 'b']);
      expect(() => m.merged(GuideRegistry([_spec('a')])), throwsArgumentError);
    });

    test('validate flags a wrong do-item count and unknown or self related ids', () {
      final r = GuideRegistry([
        _spec('one', doKeys: ['x']),
        _spec('four', doKeys: ['a', 'b', 'c', 'd']),
        _spec('lost', related: ['nope']),
        _spec('me', related: ['me']),
        _spec('ok'),
      ]);
      final problems = {for (final i in r.validate()) '${i.entryId}:${i.problem.name}'};
      expect(problems, {'one:badDoCount', 'four:badDoCount', 'lost:unknownRelated', 'me:selfRelated'});
    });

    test('relatedOf skips unknown ids', () {
      final r = GuideRegistry([_spec('a', related: ['b', 'ghost']), _spec('b')]);
      final a = r.entry('a', (k) => k)!;
      expect(r.relatedOf(a, (k) => k).map((e) => e.id), ['b']);
    });
  });

  group('sample entries', () {
    final registry = GuideSamples.registry();

    test('three samples with the ids the brief names, all valid', () {
      expect(registry.ids.toList(), ['today', 'planet.faith', 'add.expense']);
      expect(registry.validate(), isEmpty);
      expect(registry.spec('today')!.tourId, 'today');
    });

    for (final code in ['ar', 'en']) {
      test('every sample resolves to non-empty $code text', () {
        final l10n = lookupL10n(Locale(code));
        final resolve = guideResolverFor(l10n);
        for (final e in registry.all(resolve)) {
          expect(e.title.trim(), isNotEmpty, reason: e.id);
          expect(e.purpose.trim(), isNotEmpty, reason: e.id);
          expect(e.example.trim(), isNotEmpty, reason: e.id);
          expect(e.keywords.trim(), isNotEmpty, reason: e.id);
          expect(e.doItems, hasLength(3), reason: e.id);
        }
      });
    }

    test('every example starts with «مثال» and shows an amount or time in Arabic-Indic digits', () {
      final resolve = guideResolverFor(lookupL10n(const Locale('ar')));
      for (final e in registry.all(resolve)) {
        expect(e.example, startsWith('مثال'), reason: e.id);
      }
      expect(registry.entry('add.expense', resolve)!.example, contains('٥ دنانير بنزين'));
      expect(RegExp('[0-9]').hasMatch(registry.entry('today', resolve)!.example), isFalse);
    });

    test('the resolver refuses a key it does not know', () {
      final resolve = guideResolverFor(lookupL10n(const Locale('ar')));
      expect(() => resolve('guideNoSuchKey'), throwsArgumentError);
    });

    test('every key a sample uses exists in guide.json with Arabic and English', () {
      final json = jsonDecode(File('lib/core/i18n/arb_parts/guide.json').readAsStringSync()) as Map<String, dynamic>;
      for (final s in GuideSamples.all) {
        for (final k in [s.titleKey, s.purposeKey, s.exampleKey, ...s.doKeys, ?s.keywordsKey]) {
          expect(json[k], isNotNull, reason: k);
          expect((json[k] as Map)['ar'], isNotEmpty, reason: k);
          expect((json[k] as Map)['en'], isNotEmpty, reason: k);
        }
      }
    });
  });

  group('seen store', () {
    test('marks, reads and forgets ids', () async {
      final s = MemoryGuideSeenStore(['a']);
      expect(await s.isSeen('a'), isTrue);
      expect(await s.isSeen('b'), isFalse);
      await s.markSeen('b');
      expect(await s.read(), {'a', 'b'});
      await s.forget('a');
      expect(await s.read(), {'b'});
    });

    test('the set it hands out is a copy', () async {
      final s = MemoryGuideSeenStore();
      (await s.read()).add('x');
      expect(await s.read(), isEmpty);
    });
  });
}
