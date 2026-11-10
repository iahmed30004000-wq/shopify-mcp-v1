import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/features/health/meds/meds.dart';

void main() {
  final ar = MedsTexts.forLanguage('ar');
  final en = MedsTexts.forLanguage('en');
  // Durations keep their number and unit together with no-break spaces.
  String plain(String s) => BidiIsolate.strip(s).replaceAll('\u00A0', ' ');

  test('anchors read naturally, with the user’s digits', () {
    expect(plain(ar.anchor(const TimeAnchor(AnchorBase.fajr, 20))), 'بعد الفجر بـ٢٠ د');
    expect(plain(en.anchor(const TimeAnchor(AnchorBase.fajr, 20))), '20 min after Fajr');
    expect(ar.anchor(const TimeAnchor(AnchorBase.breakfast)), 'مع الفطور');
    expect(ar.anchor(const TimeAnchor(AnchorBase.maghrib)), 'عند المغرب');
    // Dinner (the meal) never reads as the Isha prayer.
    expect(plain(ar.anchor(const TimeAnchor(AnchorBase.dinner, -30))), 'قبل وجبة العشاء بـ٣٠ د');
    expect(en.anchor(const TimeAnchor(AnchorBase.bedtime)), 'At bedtime');
  });

  test('rules and conflicts are neutral descriptions, names isolated', () {
    String name(String id) => id == 'a' ? 'Levothyroxine' : 'Calcium';
    const r = RuleSpec(id: 'r', kind: MedRuleKind.separate, medAId: 'a', medBId: 'b', minutes: 240);
    final text = ar.rule(r, name);
    expect(text, contains('\u2068Levothyroxine\u2069'));
    expect(plain(text), '٤ س على الأقل بين Levothyroxine وCalcium');
    expect(
      plain(en.rule(const RuleSpec(id: 'f', kind: MedRuleKind.beforeFood, medAId: 'a', minutes: 30), name)),
      'Levothyroxine 30 min before food',
    );
  });

  test('a duration never breaks between its number and unit', () {
    expect(ar.duration(94), '١\u00A0س\u00A0٣٤\u00A0د');
    expect(en.duration(30), isNot(contains(' ')));
  });

  test('phases, doses and kinds', () {
    expect(plain(ar.phase(const CoursePhase(frequency: CourseFrequency.daily, count: 10))), 'يوميًا × ١٠');
    expect(plain(ar.phase(const CoursePhase(frequency: CourseFrequency.weekly, interval: 2, count: 4))), 'كل أسبوعين × ٤');
    expect(en.phase(const CoursePhase(frequency: CourseFrequency.monthly)), 'Monthly, ongoing');
    expect(plain(ar.dose('10 mg')), '١٠ mg');
    expect(en.kind(MedKind.injection), 'Injection');
    expect(ar.takenWith(TakenWith.emptyStomach), 'على الريق');
  });
}
