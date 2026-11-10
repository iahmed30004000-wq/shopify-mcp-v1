import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/kids/learn/data/arabic_letters.dart';
import 'package:madar/features/kids/learn/domain/letter_quiz_engine.dart';
import 'package:madar/features/kids/learn/letters/letter_picture.dart';
import 'package:madar/features/kids/learn/voice/kids_voice.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.have);
  final Set<String> have;
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    if (!have.contains(key)) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('the 28 letters', () {
    test('there are 28, each with a distinct id, glyph, name and word', () {
      expect(arabicLetters.length, 28);
      for (final pick in <String Function(ArabicLetter)>[(l) => l.id, (l) => l.glyph, (l) => l.name, (l) => l.word]) {
        expect({for (final l in arabicLetters) pick(l)}.length, 28);
      }
    });

    test('the alphabet is complete and in order', () {
      expect(arabicLetters.map((l) => l.glyph).join(), 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي');
    });

    test('ids are safe voice file stems', () {
      for (final l in arabicLetters) {
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(l.id), isTrue, reason: l.id);
      }
    });

    test('forms are shaped with joiners, not hand drawn', () {
      final ba = arabicLetters.firstWhere((l) => l.id == 'ba');
      expect(ba.form(LetterForm.isolated), 'ب');
      expect(ba.form(LetterForm.initial), 'ب‍');
      expect(ba.form(LetterForm.medial), '‍ب‍');
      expect(ba.form(LetterForm.final_), '‍ب');
    });

    test('exactly the six non-joining letters have no initial or medial form', () {
      final nonJoining = arabicLetters.where((l) => !l.joinsNext).map((l) => l.glyph).toSet();
      expect(nonJoining, {'ا', 'د', 'ذ', 'ر', 'ز', 'و'});
      for (final l in arabicLetters.where((l) => !l.joinsNext)) {
        expect(l.hasForm(LetterForm.initial), isFalse);
        expect(l.hasForm(LetterForm.medial), isFalse);
        expect(l.hasForm(LetterForm.final_), isTrue);
      }
    });

    test('every example word carries the letter, and the highlight covers it with its vowel marks', () {
      for (final l in arabicLetters) {
        final (from, to) = l.highlight;
        expect(from, lessThan(to), reason: l.id);
        expect(to, lessThanOrEqualTo(l.word.length));
        final hit = l.word.substring(from, to);
        // alef may appear as hamza-on-alef (أ) at the start of أرنب
        final base = l.glyph == 'ا' ? hit.startsWith('أ') || hit.startsWith('ا') : hit.startsWith(l.glyph);
        expect(base, isTrue, reason: '${l.id}: $hit');
        // the rest of the highlight is vowel marks only
        for (final u in hit.runes.skip(1)) {
          expect(
            (u >= 0x064B && u <= 0x0652) || u == 0x0670,
            isTrue,
            reason: '${l.id} has a non-mark in its highlight',
          );
        }
      }
    });

    test('no religious wording sneaks into the example words', () {
      const banned = ['الله', 'قرآن', 'محمد', 'مسجد', 'صلاة', 'هلال', 'رسول'];
      for (final l in arabicLetters) {
        for (final b in banned) {
          expect(l.word.contains(b), isFalse, reason: l.word);
        }
      }
    });

    test('every letter has a drawn picture, 28 of 28', () {
      expect(letterPictureCount, 28);
      expect({for (final l in arabicLetters) l.picture}.length, 28, reason: 'one picture per letter');
    });
  });

  group('quiz engine', () {
    test('choices are distinct, contain the target once, and never repeat the target twice in a row', () {
      final engine = LetterQuizEngine(seed: 11);
      String? last;
      for (var i = 0; i < 1000; i++) {
        final q = engine.next();
        expect(q.choices.length, 3);
        expect({for (final c in q.choices) c.id}.length, 3);
        expect(q.choices.where(q.isCorrect).length, 1);
        expect(q.target.id, isNot(last));
        expect(q.target.hasForm(q.form), isTrue, reason: 'a real form is shown');
        last = q.target.id;
        for (final c in q.choices) {
          expect(q.isCorrect(c), c.id == q.target.id);
        }
      }
    });

    test('is reproducible from its seed', () {
      final a = LetterQuizEngine(seed: 3), b = LetterQuizEngine(seed: 3);
      for (var i = 0; i < 30; i++) {
        final qa = a.next(), qb = b.next();
        expect(qa.target.id, qb.target.id);
        expect([for (final c in qa.choices) c.id], [for (final c in qb.choices) c.id]);
      }
    });
  });

  group('KidsVoice', () {
    test('a recording that does not exist is silent and never throws', () async {
      final bundle = _Bundle({});
      final played = <String>[];
      final voice = AssetKidsVoice(bundle: bundle, player: (p) async => played.add(p));
      await voice.play('letter_ain');
      expect(played, isEmpty);
      expect(bundle.loads, 1);
    });

    test('an existing recording plays through the player', () async {
      final bundle = _Bundle({'assets/kids/voice/letter_ain.mp3'});
      final played = <String>[];
      final voice = AssetKidsVoice(bundle: bundle, player: (p) async => played.add(p));
      await voice.play('letter_ain');
      expect(played, ['assets/kids/voice/letter_ain.mp3']);
    });

    test('a failing player never breaks the lesson', () async {
      final bundle = _Bundle({'assets/kids/voice/x.mp3'});
      final voice = AssetKidsVoice(bundle: bundle, player: (p) async => throw StateError('no audio device'));
      await voice.play('x');
    });

    test('an id that is not a plain file stem is refused without touching the bundle', () async {
      final bundle = _Bundle({'assets/kids/voice/../secret.mp3'});
      final voice = AssetKidsVoice(bundle: bundle, player: (p) async => fail('must not play'));
      for (final bad in ['../secret', 'a/b', 'A', '', 'x.mp3', 'a b']) {
        await voice.play(bad);
      }
      expect(bundle.loads, 0);
    });

    test('the default asset bundle simply has no recordings yet (silent)', () async {
      final voice = AssetKidsVoice(player: (p) async => fail('nothing is bundled yet'));
      await voice.play('letter_ain');
    });
  });
}
