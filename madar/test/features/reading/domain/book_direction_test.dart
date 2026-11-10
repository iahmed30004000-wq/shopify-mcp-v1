import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/reading/domain/book_direction.dart';
import 'package:madar/features/reading/domain/library_entry.dart';

void main() {
  group('bookDirectionOf', () {
    test('right-to-left languages', () {
      for (final l in ['ar', 'he', 'fa', 'ur', 'ps', 'sd', 'ug', 'yi', 'dv']) {
        expect(bookDirectionOf(l), BookDirection.rtl, reason: l);
      }
    });

    test('left-to-right languages', () {
      for (final l in ['en', 'fr', 'de', 'tr', 'id', 'es', 'ru', 'zh', 'ja']) {
        expect(bookDirectionOf(l), BookDirection.ltr, reason: l);
      }
    });

    test('regional subtags, case and underscores do not matter', () {
      expect(bookDirectionOf('ar-EG'), BookDirection.rtl);
      expect(bookDirectionOf('AR-sa'), BookDirection.rtl);
      expect(bookDirectionOf('fa_IR'), BookDirection.rtl);
      expect(bookDirectionOf('ur-PK'), BookDirection.rtl);
      expect(bookDirectionOf('en-GB'), BookDirection.ltr);
      expect(bookDirectionOf(' he '), BookDirection.rtl);
    });

    test('three-letter and retired codes', () {
      expect(bookDirectionOf('ara'), BookDirection.rtl);
      expect(bookDirectionOf('iw'), BookDirection.rtl);
      expect(bookDirectionOf('eng'), BookDirection.ltr);
    });

    test('a script subtag is more specific than the language', () {
      expect(bookDirectionOf('ar-Latn'), BookDirection.ltr); // Arabic in Latin letters
      expect(bookDirectionOf('pa-Arab-PK'), BookDirection.rtl); // Shahmukhi
      expect(bookDirectionOf('ku-Arab'), BookDirection.rtl);
      expect(bookDirectionOf('sd-Deva'), BookDirection.ltr);
    });

    test('missing, empty and unknown default to LTR', () {
      expect(bookDirectionOf(null), BookDirection.ltr);
      expect(bookDirectionOf(''), BookDirection.ltr);
      expect(bookDirectionOf('   '), BookDirection.ltr);
      expect(bookDirectionOf('zz-ZZ'), BookDirection.ltr);
      expect(bookDirectionOf('-'), BookDirection.ltr);
    });

    test('an explicit override wins over the language', () {
      expect(bookDirectionOf('en', directionOverride: BookDirection.rtl), BookDirection.rtl);
      expect(bookDirectionOf('ar', directionOverride: BookDirection.ltr), BookDirection.ltr);
      expect(bookDirectionOf('', directionOverride: BookDirection.rtl), BookDirection.rtl);
    });

    test('RTL books open from the right', () {
      expect(BookDirection.rtl.opensFromRight, isTrue);
      expect(BookDirection.ltr.opensFromRight, isFalse);
    });
  });

  group('LibraryEntry direction', () {
    LibraryEntry book(String lang, {BookDirection? o}) => LibraryEntry(
      id: 'x',
      title: 'x',
      language: lang,
      sourceKind: LibrarySourceKind.bundled,
      directionOverride: o,
    );

    test('follows the BOOK language, an Arabic book is RTL whatever the app language', () {
      expect(book('ar').direction, BookDirection.rtl);
      expect(book('en').direction, BookDirection.ltr);
    });

    test('a book with no language tag is LTR until the override is set', () {
      expect(book('').direction, BookDirection.ltr);
      expect(book('', o: BookDirection.rtl).direction, BookDirection.rtl);
    });

    test('a mixed book is decided by its declared primary language', () {
      expect(book('ar-Latn').direction, BookDirection.ltr);
      expect(book('ar').direction, BookDirection.rtl);
    });
  });
}
