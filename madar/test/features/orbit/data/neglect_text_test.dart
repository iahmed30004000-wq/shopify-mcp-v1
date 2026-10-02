import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/domain/neglect_text.dart';
import 'package:madar/features/orbit/domain/planet_scores.dart';

const _fsi = '\u2068', _pdi = '\u2069';
String iso(String s) => '$_fsi$s$_pdi';

void main() {
  final ar = lookupL10n(const Locale('ar'));
  final en = lookupL10n(const Locale('en'));
  const arFmt = MadarFormatter();
  const enFmt = MadarFormatter(languageCode: 'en');

  NeglectReason r(ReasonCode code, Map<String, Object> args) =>
      NeglectReason(planetKey: 'x', code: code, severity: 0.5, args: args);
  String tAr(ReasonCode c, Map<String, Object> a) => neglectReasonText(ar, r(c, a), arFmt);
  String tEn(ReasonCode c, Map<String, Object> a) => neglectReasonText(en, r(c, a), enFmt);

  test('the brief\'s examples', () {
    expect(tAr(ReasonCode.personOverdue, {'name': 'أبي', 'days': 3}), '${iso('أبي')} — متأخر ٣ أيام');
    expect(tEn(ReasonCode.personOverdue, {'name': 'Father', 'days': 3}), '${iso('Father')} — 3 days overdue');
    expect(tAr(ReasonCode.dosesPastDue, {'count': 2}), 'جرعتان فائتتان');
    expect(tEn(ReasonCode.dosesPastDue, {'count': 2}), '2 doses past due');
  });

  test('Arabic plural categories: one, two, few (3–10), many (11–99), other (100+)', () {
    String days(int n) => tAr(ReasonCode.personOverdue, {'name': 'أمي', 'days': n});
    final name = iso('أمي');
    expect(days(1), '$name — متأخر يومًا واحدًا');
    expect(days(2), '$name — متأخر يومين');
    expect(days(3), '$name — متأخر ٣ أيام');
    expect(days(10), '$name — متأخر ١٠ أيام');
    expect(days(11), '$name — متأخر ١١ يومًا');
    expect(days(99), '$name — متأخر ٩٩ يومًا');
    expect(days(100), '$name — متأخر ١٠٠ يوم');
    expect(days(103), '$name — متأخر ١٠٣ أيام');

    String doses(int n) => tAr(ReasonCode.dosesPastDue, {'count': n});
    expect(doses(1), 'جرعة فائتة');
    expect(doses(2), 'جرعتان فائتتان');
    expect(doses(5), '٥ جرعات فائتة');
    expect(doses(12), '١٢ جرعة فائتة');

    String workouts(int n) => tAr(ReasonCode.workoutsMissed, {'count': n});
    expect(workouts(1), 'تمرين فائت هذا الأسبوع');
    expect(workouts(2), 'تمرينان فائتان هذا الأسبوع');
    expect(workouts(4), '٤ تمارين فائتة هذا الأسبوع');
    expect(workouts(14), '١٤ تمرينًا فائتًا هذا الأسبوع');
  });

  test('English singular / plural', () {
    expect(tEn(ReasonCode.personOverdue, {'name': 'Ali', 'days': 1}), '${iso('Ali')} — 1 day overdue');
    expect(tEn(ReasonCode.tasksOverdue, {'count': 1}), '1 task overdue');
    expect(tEn(ReasonCode.tasksOverdue, {'count': 4}), '4 tasks overdue');
    expect(tEn(ReasonCode.prayersMissed, {'count': 1}), '1 prayer not logged this week');
    expect(tEn(ReasonCode.prayersMissed, {'count': 12}), '12 prayers not logged this week');
  });

  test('every reason code has a sentence in both languages', () {
    final samples = <ReasonCode, Map<String, Object>>{
      ReasonCode.personOverdue: {'name': 'N', 'days': 4},
      ReasonCode.dosesPastDue: {'count': 3},
      ReasonCode.prayersMissed: {'count': 3},
      ReasonCode.tasksOverdue: {'count': 3},
      ReasonCode.cardsOverdue: {'count': 3, 'board': 'B'},
      ReasonCode.budgetOverspent: {'item': 'I', 'percent': 30},
      ReasonCode.obligationOverdue: {'name': 'N', 'days': 4},
      ReasonCode.debtOverdue: {'person': 'P', 'days': 4},
      ReasonCode.goalBehind: {'name': 'G', 'percent': 40},
      ReasonCode.workoutsMissed: {'count': 3},
      ReasonCode.waterLow: {'percent': 20},
      ReasonCode.documentExpiring: {'name': 'D', 'days': 10},
      ReasonCode.tripUnpacked: {'destination': 'T', 'days': 5, 'percent': 20},
      ReasonCode.moduleStale: {'name': 'M', 'days': 5},
      ReasonCode.noActivity: {'days': 8},
      ReasonCode.habitsSlipping: {'count': 3},
      ReasonCode.projectItemsOverdue: {'count': 3, 'project': 'P'},
      ReasonCode.jarBehind: {'name': 'J', 'percent': 40},
      ReasonCode.sourceStale: {'source': 'adhkar', 'days': 4},
    };
    expect(samples.keys.toSet(), ReasonCode.values.toSet());
    for (final e in samples.entries) {
      final a = tAr(e.key, e.value), b = tEn(e.key, e.value);
      expect(a, isNotEmpty);
      expect(b, isNotEmpty);
      expect(a, isNot(contains('{')), reason: e.key.name);
      expect(b, isNot(contains('{')), reason: e.key.name);
      // Arabic text uses Arabic-Indic digits by default; English never does.
      expect(RegExp('[0-9]').hasMatch(BidiIsolate.strip(a)), isFalse, reason: a);
      expect(RegExp('[٠-٩]').hasMatch(b), isFalse, reason: b);
    }
  });

  test('specific sentences', () {
    expect(
      tAr(ReasonCode.budgetOverspent, {'item': 'الوقود', 'percent': 30}),
      '${iso('الوقود')} — تجاوز الميزانية بنسبة ٣٠٪',
    );
    expect(tEn(ReasonCode.budgetOverspent, {'item': 'Fuel', 'percent': 30}), '${iso('Fuel')} — 30% over budget');
    expect(tAr(ReasonCode.obligationOverdue, {'name': 'الإيجار', 'days': 2}), '${iso('الإيجار')} — تأخّر السداد يومين');
    expect(tAr(ReasonCode.debtOverdue, {'person': 'أحمد', 'days': 5}), 'دَين ${iso('أحمد')} — تأخّر السداد ٥ أيام');
    expect(tEn(ReasonCode.debtOverdue, {'person': 'Ahmad', 'days': 5}), 'Debt to ${iso('Ahmad')} — 5 days overdue');
    expect(tAr(ReasonCode.documentExpiring, {'name': 'الهوية', 'days': 0}), '${iso('الهوية')} — انتهاء الصلاحية اليوم');
    expect(tAr(ReasonCode.documentExpiring, {'name': 'الهوية', 'days': -3}), '${iso('الهوية')} — انتهت الصلاحية');
    expect(tEn(ReasonCode.documentExpiring, {'name': 'Visa', 'days': 1}), '${iso('Visa')} — expires in a day');
    expect(
      tAr(ReasonCode.tripUnpacked, {'destination': 'عمّان', 'days': 1, 'percent': 40}),
      '${iso('عمّان')} — السفر غدًا، والتجهيز ٤٠٪ فقط',
    );
    expect(
      tEn(ReasonCode.tripUnpacked, {'destination': 'Amman', 'days': 0, 'percent': 40}),
      '${iso('Amman')} — leaving today, only 40% packed',
    );
    expect(
      tAr(ReasonCode.goalBehind, {'name': 'دورة', 'percent': 40}),
      '${iso('دورة')} — أنجزتَ ٤٠٪ من المتوقَّع حتى الآن',
    );
    expect(
      tEn(ReasonCode.goalBehind, {'name': 'Course', 'percent': 40, 'days': 9}),
      '${iso('Course')} — no progress for 9 days',
    );
    expect(tAr(ReasonCode.sourceStale, {'source': 'adhkar', 'days': 4}), 'الأذكار — لا تسجيل منذ ٤ أيام');
    expect(
      tEn(ReasonCode.sourceStale, {'source': 'transactions', 'days': 6}),
      'Spending log — nothing logged for 6 days',
    );
    expect(
      tAr(ReasonCode.habitsSlipping, {'count': 1, 'name': 'المشي', 'days': 4}),
      '${iso('المشي')} — لم تُنجَز منذ ٤ أيام',
    );
    expect(tAr(ReasonCode.habitsSlipping, {'count': 2}), 'عادتان متعثّرتان هذا الأسبوع');
    expect(tEn(ReasonCode.dosesPastDue, {'count': 1, 'name': 'Metformin'}), '${iso('Metformin')} — 1 dose past due');
    expect(tAr(ReasonCode.noActivity, {'days': 12}), 'لا نشاط منذ ١٢ يومًا');
    expect(tAr(ReasonCode.projectItemsOverdue, {'count': 2, 'project': 'مدار'}), '${iso('مدار')} — بندان متأخران');
    expect(tAr(ReasonCode.waterLow, {'percent': 20}), 'الماء — ٢٠٪ فقط من هدف اليوم');
  });

  test('digit styles: Western digits in Arabic, Arabic-Indic in English', () {
    const arWestern = MadarFormatter(digits: DigitStyle.western);
    const enIndic = MadarFormatter(languageCode: 'en', digits: DigitStyle.arabicIndic);
    expect(neglectReasonText(ar, r(ReasonCode.tasksOverdue, {'count': 5}), arWestern), '5 مهام متأخرة');
    expect(neglectReasonText(en, r(ReasonCode.tasksOverdue, {'count': 5}), enIndic), '٥ tasks overdue');
    // Digits inside a user's name are never converted.
    expect(
      neglectReasonText(ar, r(ReasonCode.cardsOverdue, {'count': 3, 'board': 'Q3 2026'}), arFmt),
      '${iso('Q3 2026')} — ٣ بطاقات متأخرة',
    );
  });

  test('labels for sources, styles and states', () {
    expect(scoreSourceLabel(ar, 'medications'), 'جرعات الأدوية'); // alias
    expect(scoreSourceLabel(en, 'boards'), 'Work boards');
    expect(scoreSourceLabel(en, 'module:abc'), 'module:abc');
    for (final a in PlanetArchetype.values) {
      expect(planetArchetypeLabel(ar, a), isNotEmpty);
      expect(planetArchetypeLabel(en, a), isNotEmpty);
    }
    expect(planetStateLabel(ar, PlanetState.thriving), 'مزدهر');
    expect(planetStateLabel(en, PlanetState.neglected), 'Needs care');
  });
}
