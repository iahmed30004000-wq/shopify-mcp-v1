// What he reads on every card: what would be written in his own words, where
// it lands, and what the reader could not resolve – in Arabic and in English,
// with his digits.
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/day_chat/day_chat.dart';

void main() {
  final now = DateTime(2026, 10, 14, 20, 30);
  final today = DateTime(2026, 10, 14);

  final vocabulary = DayChatVocabulary(
    modules: const [
      DayChatModule(
        id: 'm-sugar',
        name: 'سكر الدم',
        fields: [DayChatField(id: 'f1', label: 'القراءة', type: FieldType.number, min: 40, max: 500)],
      ),
    ],
    people: const [DayChatPerson(id: 'p-rana', name: 'رنا')],
    foods: const [DayChatNamed(id: 'fd', name: 'منسف')],
    exercises: const [DayChatNamed(id: 'ex', name: 'صدر')],
    openTasks: const [DayChatOpenTask(id: 't', title: 'تقرير الشغل')],
  );

  DayChatPiece piece(String line, [int index = 0]) => DayChatReader(
    vocabulary: vocabulary,
    baseCurrency: 'JOD',
  ).read(line, now: now, day: today).pieces[index];

  DayChatTexts texts([String language = 'ar']) =>
      DayChatTexts(lookupL10n(Locale(language)), MadarFormatter(languageCode: language));

  /// The sentence as he reads it: bidi controls gone and every kind of
  /// space the money formatter uses written as a plain one.
  String plain(String s) => BidiIsolate.strip(s).replaceAll(RegExp(r'[\u00A0\u202F\u2009\u2007]'), ' ');

  test('a card says what would be written, in his own words and his digits', () {
    final t = texts();
    expect(plain(t.title(piece('صرفت ٥ دنانير قهوة'))), 'صرفت ٥٫٠٠٠ د.أ على قهوة');
    expect(plain(t.title(piece('صليت العصر بالمسجد'))), 'صلّيت العصر بالمسجد');
    expect(plain(t.title(piece('تمرين صدر ٤×١٢'))), 'تمرين صدر ٤×١٢');
    expect(plain(t.title(piece('وجع الركبة ٦'))), 'وجع الركبة درجته ٦');
    expect(plain(t.title(piece('أكلت منسف الساعة ٢'))), contains('منسف'));
    expect(plain(t.title(piece('كلمت رنا'))), 'حكيت مع رنا');
    expect(plain(t.title(piece('سكر الدم ١٢٠'))), 'سكر الدم: ١٢٠');
    expect(plain(t.title(piece('خلصت تقرير الشغل'))), contains('تقرير الشغل'));
    expect(plain(t.title(piece('مشيت ٣٠ دقيقة'))), contains('٣٠'));
    // Never a Western digit in an Arabic sentence.
    for (final line in ['صرفت ٥ دنانير قهوة', 'مشيت ٣٠ دقيقة', 'سكر الدم ١٢٠', 'وجع الركبة ٦']) {
      expect(plain(t.title(piece(line))), isNot(matches(RegExp('[0-9]'))), reason: line);
    }
  });

  test('the same cards in English', () {
    final t = texts('en');
    expect(plain(t.title(piece('صرفت ٥ دنانير قهوة'))), 'Spent 5.000 JOD on قهوة');
    expect(plain(t.title(piece('صليت العصر بالمسجد'))), 'Prayed Asr at the mosque');
    expect(plain(t.title(piece('وجع الركبة ٦'))), 'الركبة pain 6');
  });

  test('where a piece lands is said in his words', () {
    final t = texts();
    expect(t.where(piece('صرفت ٥ دنانير قهوة')), 'بتنزل بالمصاري');
    expect(t.where(piece('صليت العصر بالمسجد')), 'بتنزل بمتابعة الصلاة');
    expect(t.where(piece('أكلت منسف')), 'بتنزل بالأكل');
    expect(plain(t.where(piece('سكر الدم ١٢٠'))), 'بتنزل بـسكر الدم');
    expect(t.where(piece('ضغط الدم ١٤')), 'ما بتنزل لحتى تقلّي');
  });

  test('a gap is a sentence he can act on', () {
    final t = texts();
    expect(t.gaps(piece('صرفت ٥ قهوة')).single, 'ما قلت العملة، بنحسبها JOD');
    expect(plain(t.gaps(piece('كلمت ابو محمود')).single), '«ابو محمود» مش بأهلك – بنضيفه جديد');
    expect(t.gaps(piece('ضغط الدم ١٤')).single, 'ما بعرف لوين هاد الرقم – اختار وحدة من وحداتك');
    expect(t.gaps(piece('صليت')).single, 'أي صلاة؟');
    expect(plain(t.gaps(piece('خلصت غسيل السيارة')).single), 'ما لقيت مهمة باسم «غسيل السيارة»');
    expect(t.gaps(piece('اليوم كان يوم طويل')).single, 'ما فهمت هاي – بتزبطها أو بتخليها ملاحظة');
  });

  test('a dose says why it is only a note: Madar tracks, medicine is his doctor\'s', () {
    final dose = piece('اخذت حبة بنادول ٥٠٠ ملغ');
    final sentence = plain(texts().gaps(dose).single);
    expect(sentence, contains('ملاحظة'));
    expect(sentence, contains('دكتورك'));
    expect(plain(texts().title(dose)), 'ملاحظة: اخذت حبة بنادول ٥٠٠ ملغ');
    expect(texts().where(dose), 'بتنزل بمهامك');
  });

  test('how sure it is, in one word', () {
    final t = texts();
    expect(t.confidence(piece('صرفت ٥ دنانير قهوة').confidence), 'متأكد');
    expect(t.confidence(piece('اليوم كان يوم طويل').confidence), 'مش متأكد');
  });

  test('the unread piece says it plainly', () {
    expect(texts().title(piece('اليوم كان يوم طويل')), 'ما فهمت هاي');
    expect(texts().kind(DayChatKind.unread), 'ما فهمتها');
  });
}
