import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/search/domain/search_text.dart';

void main() {
  String fold(String s) => SearchText.fold(s);

  group('Arabic folding', () {
    test('drops diacritics, shadda, sukun and superscript alef', () {
      expect(fold('مُحَمَّدٌ'), 'محمد');
      expect(fold('الرَّحْمَٰنِ'), 'الرحمن');
      expect(fold('قُرْآنٌ'), 'قران');
    });

    test('drops tatweel without breaking the word', () {
      expect(fold('الحمــــد'), 'الحمد');
      expect(SearchText.tokenize('الحمــــد'), hasLength(1));
    });

    test('folds every alef form to ا', () {
      expect(fold('أحمد'), 'احمد');
      expect(fold('إسلام'), 'اسلام');
      expect(fold('آمنة'), 'امنه');
      expect(fold('ٱلْحَمْدُ'), 'الحمد');
    });

    test('folds hamza seats, alef maksura, farsi yeh and taa marbuta', () {
      expect(fold('مسؤول'), 'مسوول');
      expect(fold('سائق'), 'سايق');
      expect(fold('مصطفى'), 'مصطفي');
      expect(fold('فارسی'), 'فارسي');
      expect(fold('صلاة'), 'صلاه');
      expect(fold('سماء'), 'سما');
      expect(fold('کتاب'), 'كتاب');
    });

    test('Quranic annotation signs are dropped', () {
      // Small high meem / pause marks after a word.
      expect(fold('رَيْبَ ۛ فِيهِ ۛ'), 'ريب فيه');
    });

    test('Arabic punctuation separates words', () {
      expect(SearchText.terms('صلاة،زكاة؛صوم؟'), ['صلاه', 'زكاه', 'صوم']);
    });

    test('everyday and vowelled spellings fold the same', () {
      expect(fold('الصَّلاةُ عَلَى وَقْتِها'), fold('الصلاه علي وقتها'));
      expect(fold('إن شاء الله'), fold('ان شا الله'));
    });
  });

  group('digits', () {
    test('Arabic-Indic and Persian digits fold to Western digits', () {
      expect(fold('١٢٣'), '123');
      expect(fold('۴۵۶'), '456');
      expect(fold('غرفة ١٠٢'), 'غرفه 102');
    });

    test('decimal and grouping separators split numbers into parts', () {
      expect(SearchText.terms('١٢٫٥'), ['12', '5']);
      expect(SearchText.terms('12.5'), ['12', '5']);
      expect(SearchText.terms('1,250'), ['1', '250']);
    });

    test('a word breaks where Arabic letters meet digits or Latin', () {
      expect(SearchText.terms('ص10'), ['ص', '10']);
      expect(SearchText.terms('فيتامينB12'), ['فيتامين', 'b12']);
    });
  });

  group('Latin', () {
    test('case folding', () {
      expect(fold('Meeting WITH Omar'), 'meeting with omar');
    });

    test('accents are dropped (precomposed and combining)', () {
      expect(fold('Café Crème'), 'cafe creme');
      expect(fold('Café'), 'cafe');
      expect(fold('Straße'), 'strase'); // ß folds to one s
    });

    test('apostrophes and symbols separate words', () {
      expect(SearchText.terms("don't #tag @home"), ['don', 't', 'tag', 'home']);
    });
  });

  group('invisible characters', () {
    test('bidi isolates, marks and zero-width joiners are dropped inside words', () {
      expect(fold('⁨Omar⁩'), 'omar');
      expect(fold('مو‌سى'), 'موسي');
      expect(fold('a­b'), 'ab');
      expect(SearchText.tokenize('‏مرحبا‎'), hasLength(1));
    });
  });

  group('tokens', () {
    test('keep their original ranges, trailing marks included', () {
      const text = 'قالَ مُحَمَّدٌ';
      final tokens = SearchText.tokenize(text);
      expect(tokens.map((t) => t.term), ['قال', 'محمد']);
      expect(text.substring(tokens[1].start, tokens[1].end), 'مُحَمَّدٌ');
      expect(tokens[1].position, 1);
    });

    test('origins map a folded stretch back to the original', () {
      const text = 'الْكِتَابُ';
      final t = SearchText.tokenize(text, withOrigins: true).single;
      expect(t.term, 'الكتاب');
      final (a, b) = t.rangeOf(2, 6); // «كتاب» without the article
      expect(text.substring(a, b), 'كِتَابُ');
      final (c, d) = t.rangeOf(0, 2);
      expect(text.substring(c, d), 'الْ');
    });

    test('long words are cut to maxTermLength', () {
      final t = SearchText.tokenize('a' * 100).single;
      expect(t.term.length, SearchText.maxTermLength);
      expect(t.end, 100);
    });

    test('maxTokens stops early', () {
      expect(SearchText.tokenize('one two three four', maxTokens: 2), hasLength(2));
    });

    test('empty and punctuation-only texts have no tokens', () {
      expect(SearchText.tokenize(''), isEmpty);
      expect(SearchText.tokenize(' ،. !? '), isEmpty);
    });
  });

  group('stems', () {
    test('take the article off', () {
      expect(SearchText.stem('الكتاب'), 'كتاب');
      expect(SearchText.stem('والكتاب'), 'كتاب');
      expect(SearchText.stem('بالقلم'), 'قلم');
      expect(SearchText.stem('للبيت'), 'بيت');
    });

    test('leave short words and Latin alone', () {
      expect(SearchText.stem('الله'), isNull); // «له» would be too short
      expect(SearchText.stem('كتاب'), isNull);
      expect(SearchText.stem('allergy'), isNull);
    });
  });

  group('edit distance', () {
    test('one edit: substitute, insert, delete, swap', () {
      expect(SearchText.withinOneEdit('medicine', 'medicine'), isTrue);
      expect(SearchText.withinOneEdit('medicine', 'medicane'), isTrue);
      expect(SearchText.withinOneEdit('medicine', 'medcine'), isTrue);
      expect(SearchText.withinOneEdit('medicine', 'medicines'), isTrue);
      expect(SearchText.withinOneEdit('medicine', 'mediicne'), isTrue);
      expect(SearchText.withinOneEdit('medicine', 'medcnie'), isFalse);
      expect(SearchText.withinOneEdit('مستشفى', 'مستشفا'), isTrue);
    });

    test('prefix within one edit', () {
      expect(SearchText.prefixWithinOneEdit('medicaton', 'medications'), isTrue);
      expect(SearchText.prefixWithinOneEdit('mdeica', 'medications'), isTrue);
      expect(SearchText.prefixWithinOneEdit('xyzabc', 'medications'), isFalse);
    });
  });
}
