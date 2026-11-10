// Fixtures for the AI bridge tests: a catalogue of "his" things and a
// realistic answer from an AI app. Generic data only – nothing personal
// ships, in the app or in these tests.
import 'dart:convert';

import 'package:madar/features/ai_bridge/ai_bridge.dart';

/// The day every fixture is written against.
final DateTime planToday = DateTime(2026, 10, 10);

String isoDay(DateTime day) => planDay(day);

/// What he already has: one budget envelope set by amount and one by
/// percentage, two foods, two meals, a switched-off habit, a lab test, a
/// tracker, a project and a learning goal.
PlanCatalog testCatalog({bool money = true, bool body = true, bool health = true}) => PlanCatalog(
  today: planToday,
  baseCurrency: money ? 'JOD' : '',
  currencyCodes: money ? const {'JOD', 'USD'} : const {},
  budgetItems: PlanRefSet([
    if (money) ...[
      PlanRef(
        id: 'env-grocery',
        name: 'بقالة',
        detail: '120 JOD monthly',
        extra: const {'mode': 'amount', 'period': 'monthly', 'amountMilli': 120000, 'currency': 'JOD'},
      ),
      PlanRef(
        id: 'env-save',
        name: 'توفير',
        detail: '10% parent monthly',
        extra: const {'mode': 'percent', 'period': 'monthly', 'percent': 10.0},
      ),
    ],
  ]),
  foods: PlanRefSet([
    if (body) ...[
      PlanRef(id: 'food-maqluba', name: 'مقلوبة', extra: const {'portion': 1.5, 'unit': 'طبق'}),
      PlanRef(id: 'logged:كنافة', name: 'كنافة'),
    ],
  ]),
  mealPlans: PlanRefSet([if (body) const PlanRef(id: 'mplan-1', name: 'خطتي', extra: {'active': true})]),
  mealSlots: PlanRefSet([
    if (body)
      const PlanRef(
        id: 'slot-lunch',
        name: 'غدا',
        detail: '13:00',
        extra: {'planId': 'mplan-1', 'timeMinutes': 780},
      ),
  ]),
  habits: PlanRefSet([
    if (health) const PlanRef(id: 'habit-walk', name: 'مشي', extra: {'active': false, 'category': 'حركة'}),
  ]),
  labTests: PlanRefSet([if (health) const PlanRef(id: 'lab-a1c', name: 'سكر صائم', detail: 'mg/dL')]),
  projects: PlanRefSet(const [PlanRef(id: 'proj-1', name: 'البيت')]),
  learningGoals: PlanRefSet(const [PlanRef(id: 'goal-1', name: 'حفظ', detail: '10 صفحة')]),
  trackers: PlanRefSet(const [PlanRef(id: 'mod-1', name: 'مزاجي')]),
);

/// A realistic answer: eight suggestions of eight kinds, each with its
/// reason, including a new food another suggestion then uses.
Map<String, Object?> goodPlan({DateTime? day}) => {
  'madar': 'plan',
  'version': 1,
  'title': 'خطة تشرين الأول',
  'summary': 'ثلاث حركات صغيرة على المصاري والأكل والمشي.',
  'generatedFor': isoDay(day ?? planToday),
  'source': {
    'kind': 'video',
    'title': 'حلقة عن الأكل',
    'completeness': 'النص بيوقف عند النص',
    'claimsFlagged': ['بيحكي إنه بيشفي ٩٩٪ من الأمراض المزمنة — ما بنبني عليه إشي'],
  },
  'items': [
    {
      'id': 'h1',
      'kind': 'habit',
      'title': 'مشي عشرين دقيقة بعد العشا',
      'reason': 'المشي عندك مسجّل ستة أيام من ثلاثين بس.',
      'area': 'body',
      'confidence': 0.8,
      'data': {'existingRef': 'habit-walk'},
    },
    {
      'id': 'b1',
      'kind': 'budgetTweak',
      'title': 'نزّل مصروف البقالة لمية',
      'reason': 'آخر ثلاث شهور صرفت أقل من المرصود بعشرين دينار.',
      'area': 'money',
      'data': {'envelopeRef': 'بقالة', 'newAmount': 100, 'period': 'monthly'},
    },
    {
      'id': 'f1',
      'kind': 'food',
      'title': 'شوفان',
      'reason': 'فطورك المسجّل كله خبز أبيض.',
      'area': 'body',
      'data': {'tags': ['فطور'], 'portion': 1, 'unit': 'كوب'},
    },
    {
      'id': 'm1',
      'kind': 'mealChange',
      'title': 'حطّ الشوفان على الغدا',
      'reason': 'الغدا عندك نشويات لحالها بأربعة أيام من سبعة.',
      'area': 'body',
      'dependsOn': ['f1'],
      'data': {'op': 'addFood', 'slotRef': 'غدا', 'foodRef': 'شوفان', 'portion': 1, 'unit': 'كوب'},
    },
    {
      'id': 't1',
      'kind': 'task',
      'title': 'راجع فاتورة الكهربا',
      'reason': 'آخر فاتورتين أعلى من المعدل.',
      'area': 'money',
      'data': {'window': 'asr', 'priority': 2},
    },
    {
      'id': 's1',
      'kind': 'trackedSign',
      'title': 'نوم متقطع',
      'reason': 'أيام الوجع العالي كلها بعد ليلة نوم قصير.',
      'area': 'health',
      'data': {'scale': 'zeroToTen', 'everyDay': true},
    },
    {
      'id': 'n1',
      'kind': 'note',
      'title': 'الصلاة بالمسجد بترفع يومك',
      'reason': 'أيام الجماعة عندك أعلى بالمهام المخلّصة.',
      'data': {'body': 'جرّب تربط المشي بالرجعة من المسجد.'},
    },
    {
      'id': 'r1',
      'kind': 'reminder',
      'title': 'تذكير بالمشي',
      'reason': 'كل أيام المشي المسجّلة كانت بعد تذكير.',
      'data': {'time': '20:30', 'repeat': 'day', 'ownerRef': {'table': 'habits', 'id': 'habit-walk'}},
    },
  ],
};

String encodePlan(Map<String, Object?> plan) => jsonEncode(plan);

/// [goodPlan] with one item replaced or added.
Map<String, Object?> planWith(Map<String, Object?> item, {bool only = true}) => {
  'madar': 'plan',
  'version': 1,
  'items': [
    if (!only) ...(goodPlan()['items']! as List),
    item,
  ],
};
