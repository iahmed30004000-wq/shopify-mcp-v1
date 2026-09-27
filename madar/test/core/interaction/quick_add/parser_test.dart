import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/interaction/quick_add/parser.dart';

/// Sunday 27 September 2026, 10:00.
final now = DateTime(2026, 9, 27, 10);

QuickAddIntent p(String input) => QuickAddParser.parse(input, now: now);

DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

void main() {
  test('reference date is a Sunday', () => expect(now.weekday, DateTime.sunday));

  group('money – expenses', () {
    test('صرفت 12.5 دينار بنزين', () {
      final r = p('صرفت 12.5 دينار بنزين');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 12500);
      expect(r.currency, 'JOD');
      expect(r.title, 'بنزين');
      expect(r.planetKey, 'money');
      expect(r.confidence, greaterThan(0.9));
    });

    test('دفعت ٣٥ دولار اشتراك (Arabic-Indic digits)', () {
      final r = p('دفعت ٣٥ دولار اشتراك');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 35000);
      expect(r.currency, 'USD');
      expect(r.title, 'اشتراك');
    });

    test('Arabic decimal separator ٫', () {
      final r = p('صرفت ٧٫٢٥ دينار غدا');
      expect(r.amountMilli, 7250);
      expect(r.currency, 'JOD');
      expect(r.title, isNot(contains('٧')));
    });

    test('spent 20 usd on lunch', () {
      final r = p('spent 20 usd on lunch');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 20000);
      expect(r.currency, 'USD');
      expect(r.title, 'lunch');
    });

    test(r'dollar sign before the number: paid $15.99 netflix', () {
      final r = p(r'paid $15.99 netflix');
      expect(r.amountMilli, 15990);
      expect(r.currency, 'USD');
      expect(r.title, 'netflix');
    });

    test(r'dollar sign after the number', () {
      final r = p(r'bought book 12$');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 12000);
      expect(r.currency, 'USD');
      expect(r.title, 'book');
    });

    test('JD code', () {
      final r = p('spent 3.5 JD coffee');
      expect(r.currency, 'JOD');
      expect(r.amountMilli, 3500);
      expect(r.title, 'coffee');
    });

    test('JD before the number', () {
      final r = p('paid JD 40 electricity');
      expect(r.currency, 'JOD');
      expect(r.amountMilli, 40000);
      expect(r.title, 'electricity');
    });

    test('د.أ abbreviation', () {
      final r = p('دفعت 9 د.أ مواصلات');
      expect(r.currency, 'JOD');
      expect(r.amountMilli, 9000);
      expect(r.title, 'مواصلات');
    });

    test('Libyan dinar is not confused with Jordanian', () {
      final r = p('صرفت 50 دينار ليبي أكل');
      expect(r.currency, 'LYD');
      expect(r.amountMilli, 50000);
      expect(r.title, 'أكل');
    });

    test('LYD code', () {
      expect(p('paid 30 LYD taxi').currency, 'LYD');
    });

    test('Syrian lira with thousands', () {
      final r = p('دفعت 25000 ليرة خبز');
      expect(r.currency, 'SYP');
      expect(r.amountMilli, 25000000);
      expect(r.title, 'خبز');
    });

    test('ألف multiplier', () {
      final r = p('صرفت 3 آلاف ليرة سورية مواصلات');
      expect(r.currency, 'SYP');
      expect(r.amountMilli, 3000000);
      expect(r.title, 'مواصلات');
    });

    test('comma thousands separator', () {
      final r = p('paid 1,250 usd rent');
      expect(r.amountMilli, 1250000);
    });

    test('Egyptian pound', () {
      final r = p('دفعت 200 جنيه مصري كتب');
      expect(r.currency, 'EGP');
      expect(r.amountMilli, 200000);
      expect(r.title, 'كتب');
    });

    test('جنيه alone is EGP', () {
      expect(p('صرفت 40 جنيه').currency, 'EGP');
    });

    test('piasters (قرش) are hundredths of a dinar', () {
      final r = p('دفعت 50 قرش خبز');
      expect(r.currency, 'JOD');
      expect(r.amountMilli, 500);
    });

    test('dual form دينارين = 2 JOD', () {
      final r = p('اشتريت فلافل بدينارين');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 2000);
      expect(r.currency, 'JOD');
      expect(r.title, 'فلافل');
    });

    test('number word + currency: خمس دنانير', () {
      final r = p('صرفت خمس دنانير قهوة');
      expect(r.amountMilli, 5000);
      expect(r.currency, 'JOD');
      expect(r.title, 'قهوة');
    });

    test('ميه دينار is 100 dinars, not water', () {
      final r = p('دفعت ميه دينار ايجار');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 100000);
    });

    test('currency without a verb is an expense', () {
      final r = p('بنزين 10 دنانير');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 10000);
      expect(r.title, 'بنزين');
      expect(r.confidence, greaterThan(0.7));
    });

    test('expense verb without currency keeps a bare amount', () {
      final r = p('صرفت 15 على الغدا');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 15000);
      expect(r.currency, isNull);
      expect(r.title, 'الغدا');
    });

    test('expense verb without amount has low confidence', () {
      final r = p('صرفت على البنزين');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, isNull);
      expect(r.title, 'البنزين');
      expect(r.confidence, lessThan(0.6));
    });

    test('bill noun keeps its title', () {
      final r = p('فاتورة كهرباء 25 دينار');
      expect(r.kind, QuickAddKind.expense);
      expect(r.title, 'فاتورة كهرباء');
      expect(r.amountMilli, 25000);
    });

    test('yesterday on an expense', () {
      final r = p('امبارح صرفت 8 دنانير عشا');
      expect(r.date, day(-1));
      expect(r.amountMilli, 8000);
      expect(r.title, 'عشا');
    });
  });

  group('money – income', () {
    test('قبضت 500 دينار', () {
      final r = p('قبضت 500 دينار');
      expect(r.kind, QuickAddKind.income);
      expect(r.amountMilli, 500000);
      expect(r.currency, 'JOD');
      expect(r.title, '');
      expect(r.planetKey, 'money');
    });

    test('راتب noun with currency is income and stays in the title', () {
      final r = p('راتب 750 دينار');
      expect(r.kind, QuickAddKind.income);
      expect(r.title, 'راتب');
    });

    test('received 300 usd from client', () {
      final r = p('received 300 usd from client');
      expect(r.kind, QuickAddKind.income);
      expect(r.amountMilli, 300000);
      expect(r.title, 'client');
    });

    test('weak verb needs an amount: وصلني 200 دولار', () {
      final r = p('وصلني 200 دولار من أخوي');
      expect(r.kind, QuickAddKind.income);
      expect(r.title, 'أخوي');
    });

    test('weak verb without an amount stays a task', () {
      expect(p('استلمت الطلبية').kind, QuickAddKind.task);
    });
  });

  group('tasks, dates and prayer windows', () {
    test('بكرا بعد المغرب اجتماع مع فريق مصر', () {
      final r = p('بكرا بعد المغرب اجتماع مع فريق مصر');
      expect(r.kind, QuickAddKind.task);
      expect(r.date, day(1));
      expect(r.window, PrayerWindow.maghrib);
      expect(r.title, 'اجتماع مع فريق مصر');
      expect(r.currency, isNull, reason: 'مصر is not a currency');
      expect(r.planetKey, 'work');
    });

    test('بكرة spelling with teh marbuta', () {
      expect(p('بكرة مراجعة التقرير').date, day(1));
    });

    test('غدًا with tanween', () {
      final r = p('غدًا تسليم المشروع');
      expect(r.date, day(1));
      expect(r.title, 'تسليم المشروع');
    });

    test('بعد بكرا is the day after tomorrow', () {
      final r = p('بعد بكرا زيارة الدكتور');
      expect(r.date, day(2));
    });

    test('اليوم', () => expect(p('اليوم تنظيف البيت').date, day(0)));

    test('weekday: يوم الخميس (next occurrence)', () {
      final r = p('يوم الخميس عشاء العيلة');
      expect(r.date!.weekday, DateTime.thursday);
      expect(r.date, day(4));
    });

    test('weekday: السبت', () => expect(p('السبت غسيل السيارة').date, day(6)));

    test('weekday equal to today means today; الجاي means next week', () {
      expect(p('الأحد مراجعة').date, day(0));
      expect(p('الأحد الجاي مراجعة').date, day(7));
    });

    test('الجمعة الجاية is next Friday', () => expect(p('الجمعة الجاية عزومة عند ستي').date!.weekday, DateTime.friday));

    test('English weekday: friday', () => expect(p('friday gym').date, day(5)));

    test('English next monday', () => expect(p('next monday dentist').date, day(1)));

    test('in 3 days / بعد 3 أيام', () {
      expect(p('in 3 days renew visa').date, day(3));
      expect(p('بعد 3 أيام تجديد الجواز').date, day(3));
    });

    test('next week', () => expect(p('next week call bank').date, day(7)));

    test('explicit d/m date', () {
      final r = p('15/10 موعد الأسنان');
      expect(r.date, DateTime(2026, 10, 15));
      expect(r.title, 'موعد الأسنان');
      expect(r.planetKey, 'health');
    });

    test('ISO date', () => expect(p('2026-12-01 renew passport').date, DateTime(2026, 12, 1)));

    test('tomorrow after isha call supplier', () {
      final r = p('tomorrow after isha call supplier');
      expect(r.kind, QuickAddKind.contact);
      expect(r.channel, ContactChannel.call);
      expect(r.date, day(1));
      expect(r.window, PrayerWindow.isha);
      expect(r.title, 'supplier');
      expect(r.planetKey, 'work');
    });

    test('قبل المغرب maps to the Asr window', () {
      expect(p('قبل المغرب مشي').window, PrayerWindow.asr);
    });

    test('before fajr maps to the Isha window', () {
      expect(p('before fajr qiyam').window, PrayerWindow.isha);
    });

    test('bare الظهر is a window; بعد صلاة الفجر too', () {
      expect(p('اجتماع الظهر').window, PrayerWindow.dhuhr);
      expect(p('بعد صلاة الفجر أذكار').window, PrayerWindow.fajr);
    });

    test('الضحى', () => expect(p('صلاة الضحى').window, PrayerWindow.duha));

    test('الصبح without a number means the morning (Duha window)', () {
      final r = p('بكرا الصبح أشتري خبز');
      expect(r.window, PrayerWindow.duha);
      expect(r.date, day(1));
    });

    test('tonight → today + Isha window', () {
      final r = p('tonight read quran');
      expect(r.date, day(0));
      expect(r.window, PrayerWindow.isha);
      expect(r.planetKey, 'faith');
    });

    test('ذكرني prefix → task, strips ب', () {
      final r = p('ذكرني باجتماع بكرا');
      expect(r.kind, QuickAddKind.task);
      expect(r.title, 'اجتماع');
      expect(r.date, day(1));
    });

    test('imperative with an amount stays a task', () {
      final r = p('ادفع الإيجار 300 دينار بكرا');
      expect(r.kind, QuickAddKind.task);
      expect(r.amountMilli, 300000);
      expect(r.currency, 'JOD');
      expect(r.title, 'ادفع الإيجار');
      expect(r.planetKey, 'money');
    });

    test('plain text is a task with modest confidence', () {
      final r = p('تنظيف المكتب');
      expect(r.kind, QuickAddKind.task);
      expect(r.title, 'تنظيف المكتب');
      expect(r.confidence, lessThan(0.7));
    });

    test('planet inference: gym → body, flight → travel, course → growth', () {
      expect(p('gym session').planetKey, 'body');
      expect(p('book flight to cairo').planetKey, 'travel');
      expect(p('start the flutter course').planetKey, 'growth');
    });
  });

  group('times', () {
    test('الساعة 5 → 17:00 (afternoon default)', () {
      final r = p('اجتماع الساعة 5');
      expect(r.time, '17:00');
      expect(r.title, 'اجتماع');
    });

    test('17:30', () => expect(p('call ahmad 17:30').time, '17:30'));

    test('5pm / 5 pm / 9am', () {
      expect(p('dentist 5pm').time, '17:00');
      expect(p('dentist 5 pm').time, '17:00');
      expect(p('standup 9am').time, '09:00');
    });

    test('٥ المسا → 17:00', () {
      final r = p('بكرا ٥ المسا عزومة');
      expect(r.time, '17:00');
      expect(r.date, day(1));
      expect(r.title, 'عزومة');
    });

    test('8 الصبح → 08:00', () => expect(p('8 الصبح دوام').time, '08:00'));

    test('الساعة ٨ ونص → 08:30', () => expect(p('الساعة ٨ ونص فطور').time, '08:30'));

    test('الساعة 7 الا ربع بالليل → 18:45', () => expect(p('الساعة 7 الا ربع بالليل عشا').time, '18:45'));

    test('10 بالليل → 22:00', () => expect(p('10 بالليل مراجعة').time, '22:00'));

    test('at 7 → 07:00 but guessed', () {
      final r = p('run at 7');
      expect(r.time, '07:00');
    });

    test('3 العصر → 15:00 and no separate window', () {
      final r = p('3 العصر تمرين');
      expect(r.time, '15:00');
      expect(r.window, isNull);
    });

    test('dateTime combines date and time', () {
      final r = p('tomorrow 18:15 football');
      expect(r.dateTime, DateTime(2026, 9, 28, 18, 15));
    });
  });

  group('water', () {
    test('شرب ماء 500 مل', () {
      final r = p('شرب ماء 500 مل');
      expect(r.kind, QuickAddKind.water);
      expect(r.ml, 500);
      expect(r.amountMilli, 500000);
      expect(r.unit, 'ml');
      expect(r.title, '');
      expect(r.planetKey, 'health');
    });

    test('water 750ml', () {
      final r = p('water 750ml');
      expect(r.kind, QuickAddKind.water);
      expect(r.ml, 750);
    });

    test('litres: شربت 1.5 لتر مي', () => expect(p('شربت 1.5 لتر مي').ml, 1500));

    test('نص لتر مي', () => expect(p('نص لتر مي').ml, 500));

    test('glasses: كاستين مي = 500 ml, 2 glasses water = 500 ml', () {
      expect(p('كاستين مي').ml, 500);
      expect(p('2 glasses water').ml, 500);
    });

    test('a glass of water', () => expect(p('a glass of water').ml, 250));

    test('water without an amount defaults to one glass with lower confidence', () {
      final r = p('شربت مي');
      expect(r.kind, QuickAddKind.water);
      expect(r.ml, 250);
      expect(r.confidence, lessThan(p('شربت مي 300 مل').confidence));
    });

    test('drinking coffee is not water', () => expect(p('شربت قهوة').kind, isNot(QuickAddKind.water)));
  });

  group('pain & mood', () {
    test('ألم ظهر 6', () {
      final r = p('ألم ظهر 6');
      expect(r.kind, QuickAddKind.pain);
      expect(r.score, 6);
      expect(r.amountMilli, 6000);
      expect(r.title, 'ظهر');
      expect(r.window, isNull, reason: 'ظهر here is the back, not Dhuhr');
      expect(r.planetKey, 'health');
    });

    test('ألم في الظهر 7/10 keeps الظهر as the location', () {
      final r = p('ألم في الظهر 7/10');
      expect(r.score, 7);
      expect(r.title, 'الظهر');
      expect(r.window, isNull);
    });

    test('صداع 4 بعد العصر', () {
      final r = p('صداع 4 بعد العصر');
      expect(r.kind, QuickAddKind.pain);
      expect(r.score, 4);
      expect(r.title, 'صداع');
      expect(r.window, PrayerWindow.asr);
    });

    test('headache 8', () {
      final r = p('headache 8');
      expect(r.kind, QuickAddKind.pain);
      expect(r.score, 8);
    });

    test('pain word severity: وجع ركبة خفيف', () {
      final r = p('وجع ركبة خفيف');
      expect(r.kind, QuickAddKind.pain);
      expect(r.score, 3);
      expect(r.title, 'ركبة');
    });

    test('مزاجي 4', () {
      final r = p('مزاجي 4');
      expect(r.kind, QuickAddKind.mood);
      expect(r.score, 4);
      expect(r.amountMilli, 4000);
      expect(r.title, '');
    });

    test('mood out of ten is scaled to 1–5', () => expect(p('mood 8/10').score, 4));

    test('mood word: مزاجي تعبان', () {
      final r = p('مزاجي تعبان');
      expect(r.kind, QuickAddKind.mood);
      expect(r.score, 2);
      expect(r.title, 'تعبان');
    });
  });

  group('contact', () {
    test('اتصل بأبوي بعد العصر', () {
      final r = p('اتصل بأبوي بعد العصر');
      expect(r.kind, QuickAddKind.contact);
      expect(r.channel, ContactChannel.call);
      expect(r.title, 'أبوي');
      expect(r.window, PrayerWindow.asr);
      expect(r.planetKey, 'family');
    });

    test('كلم أمي does not strip letters', () {
      final r = p('كلم أمي');
      expect(r.title, 'أمي');
      expect(r.planetKey, 'family');
    });

    test('زور جدتي يوم الجمعة', () {
      final r = p('زور جدتي يوم الجمعة');
      expect(r.channel, ContactChannel.visit);
      expect(r.title, 'جدتي');
      expect(r.date!.weekday, DateTime.friday);
    });

    test('ابعث لأحمد الملف → message, strips ل', () {
      final r = p('ابعث لأحمد الملف');
      expect(r.channel, ContactChannel.message);
      expect(r.title, 'أحمد الملف');
    });

    test('text sara tonight', () {
      final r = p('text sara tonight');
      expect(r.kind, QuickAddKind.contact);
      expect(r.channel, ContactChannel.message);
      expect(r.title, 'sara');
      expect(r.window, PrayerWindow.isha);
    });

    test('calling about water is a contact, not water', () {
      expect(p('اتصل بشركة المياه').kind, QuickAddKind.contact);
    });
  });

  group('notes & edge cases', () {
    test('note: prefix', () {
      final r = p('note: buy milk');
      expect(r.kind, QuickAddKind.note);
      expect(r.title, 'buy milk');
      expect(r.confidence, greaterThan(0.85));
    });

    test('ملاحظة: prefix', () {
      final r = p('ملاحظة: فكرة تطبيق جديد');
      expect(r.kind, QuickAddKind.note);
      expect(r.title, 'فكرة تطبيق جديد');
    });

    test('empty and whitespace input', () {
      expect(p('').title, '');
      expect(p('   ').confidence, 0);
    });

    test('diacritics and tatweel are ignored', () {
      final r = p('صَرَفْتُ ١٠ دنانيـــر');
      expect(r.kind, QuickAddKind.expense);
      expect(r.amountMilli, 10000);
    });

    test('mixed Arabic and English', () {
      final r = p('بكرا meeting مع Ahmad الساعة 4');
      expect(r.date, day(1));
      expect(r.time, '16:00');
      expect(r.title, 'meeting مع Ahmad');
    });

    test('raw keeps the original input', () => expect(p('  مزاجي 4 ').raw, '  مزاجي 4 '));

    test('toJson round-trip fields', () {
      final j = p('صرفت 5 دنانير قهوة').toJson();
      expect(j['kind'], 'expense');
      expect(j['amountMilli'], 5000);
      expect(j['currency'], 'JOD');
    });
  });
}
