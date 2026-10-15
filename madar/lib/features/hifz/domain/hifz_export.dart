/// «تصدير الحفظ» · the goals and the plan inside Part 13's export
/// (Part 14).
///
/// Pure Dart, plain data (pass it to `jsonEncode`). **It is not a second
/// format**: it adds one block, `"hifz"`, to the file
/// `TasmeeExport.build` already produces for «فلك» – same file, same
/// `format` (`madar.tasmee.log`), same rules about `heard` never being
/// Quran text. A reader that only knows Part 13's format keeps working and
/// simply ignores the block.
///
/// ## The block
///
/// ```json
/// "hifz": {
///   "blockVersion": 1,
///   "notice": "…what the numbers mean, in one paragraph…",
///   "settings": {"newAyatPerDay": 5, "newFrom": "18:1", "nearDays": 7,
///                "nearCapAyat": 30, "farCapAyat": 40, "dailyCapAyat": 80,
///                "repetitions": 3, "groupSize": 5, "practiseLinks": true},
///   "goals": [
///     {"id": "…", "title": "الكهف كل جمعة", "kind": "rangeOnWeekday",
///      "range": {"from": "18:1", "to": "18:110"}, "weekday": 5,
///      "amount": null, "unit": "pages", "window": "fajr",
///      "offsetMinutes": 15, "remind": true, "active": true,
///      "withinDays": 7,
///      "progress": {"day": "2026-10-16", "due": true, "done": 0,
///                   "target": 110, "unit": "ayat", "met": false}}
///   ],
///   "marks": [{"kind": "skipReview", "range": {"from": "2:1", "to": "2:5"},
///              "since": null, "note": null}],
///   "plan": {
///     "day": "2026-10-15", "cycleDays": 6, "memorisedAyat": 220,
///     "totalAyat": 61, "notes": ["recitingUnavailable"],
///     "portions": [{"track": "fresh", "range": {"from": "18:1", "to": "18:5"},
///                   "ayat": 5, "band": "unknown", "strength": null,
///                   "method": "listenRepeat", "stage": "full",
///                   "repetitions": 3, "pages": [293, 293], "seed": 12345}],
///     "backlog": {"missedDays": 7, "wouldHaveBeenAyat": 420,
///                 "todayAyat": 61, "droppedAyat": 359,
///                 "reasons": ["missedDays"],
///                 "dropped": [{"from": "2:1", "to": "2:40"}]}
///   },
///   "strength": [{"ref": "18:1", "surah": 18, "ayah": 1, "strength": 0.82,
///                 "band": "firm", "attempts": 3, "cleanAttempts": 2,
///                 "cleanRun": 1, "recall": 0.9, "freshness": 0.91,
///                 "halfLifeDays": 9.7, "hints": 1, "mistakes": 2,
///                 "lastDay": "2026-10-14", "resetSince": null}],
///   "pages": [{"page": 293, "memorised": 7, "tested": 5, "strength": 0.77,
///              "band": "firm", "coverage": 0.58}]
/// }
/// ```
///
/// ## The rules a reader must know
///
/// * **The strength is not stored anywhere** – it is computed from the
///   `sessions` of the same file every time, with the function documented
///   in `hifz_strength.dart`. A reader that wants a different model can
///   recompute it from the sessions; these numbers are Madar's own.
/// * **`band: "unknown"` is not zero.** It means "he was never tested on
///   this", which is a different thing from "he has forgotten it".
///   `"skipped"` means he marked it «مش عليّ».
/// * **`dropped` is not lost.** Those stretches were not scheduled today;
///   each comes round again on its own turn of the rotation.
/// * **A goal's `title` is the owner's own words** and must be shown as
///   he wrote it.
/// * **Days** (`day`, `lastDay`, `since`) are zone-free calendar days
///   `YYYY-MM-DD`, exactly as in Part 13's block.
library;

import '../../../core/domain/enums.dart';
import '../../../core/quran/ayah.dart';
import '../../tasmee/tasmee.dart';
import 'hifz_daily_plan.dart';
import 'hifz_goals.dart';
import 'hifz_marks.dart';
import 'hifz_page_map.dart';
import 'hifz_strength.dart';

/// Bumped when a reader of the `"hifz"` block would have to change.
const int hifzExportBlockVersion = 1;

/// The one-paragraph notice shipped inside the block.
const String hifzExportNotice =
    'هاد قسم «الحفظ». قوّة كل آية محسوبة من نتائج التسميع اللي بنفس الملف، '
    'مش مخزّنة ولا مكتوبة بإيد: «unknown» يعني ما انختبر عليها ولا مرة، مش يعني نسيها، '
    'و«skipped» يعني هو حدّد إنها مش عليه. وخطة اليوم محسوبة من نفس الأرقام ومن التاريخ، '
    'وكل إشي بـ «dropped» ما ضاع: رجع لدوره بالمراجعة. وعناوين الأهداف بكلامه هو، ما بتتغيّر.';

/// Builds the `"hifz"` block and puts it inside Part 13's export.
abstract final class HifzExport {
  /// [base] is whatever `TasmeeExport.build` returned; the result is the
  /// same map with one more key.
  static Map<String, Object?> extend(
    Map<String, Object?> base, {
    required HifzPlanSettings settings,
    required List<HifzGoalProgress> goals,
    required HifzMarks marks,
    required HifzStrengths strengths,
    HifzDailyPlan? plan,
    HifzPageMap? pageMap,
  }) => {
    ...base,
    'hifz': block(
      settings: settings,
      goals: goals,
      marks: marks,
      strengths: strengths,
      plan: plan,
      pageMap: pageMap,
    ),
  };

  /// The block on its own.
  static Map<String, Object?> block({
    required HifzPlanSettings settings,
    required List<HifzGoalProgress> goals,
    required HifzMarks marks,
    required HifzStrengths strengths,
    HifzDailyPlan? plan,
    HifzPageMap? pageMap,
  }) {
    final refs = strengths.byRef.keys.toList()..sort();
    return {
      'blockVersion': hifzExportBlockVersion,
      'notice': hifzExportNotice,
      'settings': settings.toJson(),
      'goals': [for (final g in goals) goal(g)],
      'marks': [for (final m in marks.marks) mark(m)],
      if (plan != null) 'plan': dailyPlan(plan),
      'strength': [for (final r in refs) strength(strengths.of(r))],
      if (pageMap != null)
        'pages': [
          for (final p in pageMap.touchedPages)
            {
              'page': p.page,
              'memorised': p.memorised,
              'tested': p.tested,
              'skipped': p.skipped,
              'strength': p.strength,
              'band': p.band.name,
              'coverage': p.coverage,
              'lastDay': p.lastDay == null ? null : TasmeeExport.day(p.lastDay!),
            },
        ],
    };
  }

  static Map<String, Object?> goal(HifzGoalProgress p) {
    final g = p.goal;
    return {
      'id': g.id,
      'title': g.title,
      'kind': g.kind.name,
      'range': g.range == null ? null : range(g.range!),
      'weekday': g.weekday,
      'amount': g.amount,
      'unit': g.unit.name,
      'window': g.window?.name,
      'offsetMinutes': g.offsetMinutes,
      'remind': g.remind,
      'active': g.active,
      'withinDays': g.withinDays,
      'progress': {
        'day': TasmeeExport.day(p.day),
        'due': p.due,
        'done': p.done,
        'target': p.target,
        'unit': p.unitName,
        'met': p.met,
        'lastDoneDay': p.lastDoneDay == null ? null : TasmeeExport.day(p.lastDoneDay!),
        if (p.remaining != null) 'remaining': [for (final r in p.remaining!) range(r)],
      },
    };
  }

  static Map<String, Object?> mark(HifzMark m) => {
    'kind': m.kind.name,
    'range': range(m.range),
    'since': m.kind == HifzMarkKind.resetStrength ? TasmeeExport.day(m.day) : null,
    'note': m.note,
  };

  static Map<String, Object?> dailyPlan(HifzDailyPlan plan) => {
    'day': TasmeeExport.day(plan.day),
    'cycleDays': plan.cycleDays,
    'memorisedAyat': plan.memorisedAyat,
    'totalAyat': plan.totalAyat,
    'notes': [for (final n in plan.notes) n.name],
    'portions': [for (final p in plan.portions) portion(p)],
    'backlog': {
      'missedDays': plan.backlog.missedDays,
      'lastActiveDay': plan.backlog.lastActiveDay == null ? null : TasmeeExport.day(plan.backlog.lastActiveDay!),
      'wouldHaveBeenAyat': plan.backlog.wouldHaveBeenAyat,
      'todayAyat': plan.backlog.todayAyat,
      'droppedAyat': plan.backlog.droppedAyat,
      'reasons': [for (final r in HifzDropReason.values) if (plan.backlog.reasons.contains(r)) r.name],
      'dropped': [for (final r in plan.backlog.dropped) range(r)],
    },
  };

  static Map<String, Object?> portion(HifzPortion p) => {
    'track': p.track.name,
    'range': range(p.range),
    'ayat': p.ayahCount,
    'band': p.band.name,
    'strength': p.strength,
    'method': p.method.name,
    'stage': p.stage.name,
    'repetitions': p.repetitions,
    'practiseLinks': p.practiseLinks,
    'pages': [p.firstPage, p.lastPage],
    'seed': p.seed,
  };

  static Map<String, Object?> strength(AyahStrength s) => {
    ...TasmeeExport.ref(s.ref),
    'strength': s.strength,
    'band': s.band.name,
    'attempts': s.attempts,
    'cleanAttempts': s.cleanAttempts,
    'cleanRun': s.cleanRun,
    'recall': s.recall,
    'freshness': s.freshness,
    'halfLifeDays': s.halfLifeDays,
    'hints': s.hints,
    'mistakes': s.mistakes,
    'lastDay': s.lastDay == null ? null : TasmeeExport.day(s.lastDay!),
    'resetSince': s.resetSince == null ? null : TasmeeExport.day(s.resetSince!),
  };

  static Map<String, Object?> range(AyahRange r) => {'from': r.first.toString(), 'to': r.last.toString()};
}
