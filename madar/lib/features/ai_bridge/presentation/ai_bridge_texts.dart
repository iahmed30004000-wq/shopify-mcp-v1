import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/db/database.dart' show AppliedPlanRow;
import '../../../core/domain/enums.dart' show PlanOrigin;
import '../../../core/i18n/formatters.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../data/domain/plain_numbers.dart';
import '../data/plan_apply_service.dart' show PlanProgress;
import '../domain/plan_catalog.dart' show PlanRef;
import '../domain/plan_contract.dart';
import '../domain/plan_preview.dart';
import '../domain/plan_problems.dart';

/// Every sentence the AI bridge says, in his language and his digits.
///
/// Three rules it keeps, because the screens on top of it must never break
/// them:
///
/// * a problem is a sentence he can act on – it names what is wrong and,
///   where it helps, quotes the value, never a code;
/// * a refused health suggestion always says *why* in his words: Madar
///   tracks and practises, and medicine is his doctor's;
/// * a change line is one short line, because the same line goes on the
///   checklist he ticks off.
class AiBridgeTexts {
  AiBridgeTexts(this.l, this.fmt);

  factory AiBridgeTexts.of(BuildContext context) => AiBridgeTexts(L10n.of(context), context.formatter);

  final L10n l;
  final MadarFormatter fmt;

  // A Monday, used to name ISO weekdays.
  static final DateTime _monday = DateTime(2026, 9, 28);

  /// A name the user typed, isolated for the sentence around it.
  String name(String value) => fmt.isolate(value);

  String _digits(String text) => fmt.localizeDigits(text);

  /// A record's machine-readable detail, made readable: the catalogue
  /// writes «120.000 JOD monthly» (plain text in every language, so the AI
  /// reads the same thing he sent), and the screens show his digits and
  /// his own words for the period.
  String _detail(String raw) {
    var text = _digits(raw);
    for (final (machine, word) in [('monthly', l.budgetMonthly), ('weekly', l.budgetWeekly)]) {
      text = text.replaceAll(machine, word);
    }
    return text.trim();
  }

  /// The plain default name of a plan that just arrived («خطة ١٠ تشرين الأول»).
  String defaultPlanName(DateTime day) => l.aiPlanDefaultName(fmt.formatDate(day, style: MadarDateStyle.medium));

  /// «٢ من ٤».
  String progress(PlanProgress p) => l.aiPlanProgress(fmt.formatInt(p.done), fmt.formatInt(p.total));

  /// The name he sees for a stored plan.
  String planName(AppliedPlanRow row) => name(row.name);

  String kind(PlanItemKind kind) => switch (kind) {
    PlanItemKind.task => l.aiPlanKindTask,
    PlanItemKind.habit => l.aiPlanKindHabit,
    PlanItemKind.routine => l.aiPlanKindRoutine,
    PlanItemKind.reminder => l.aiPlanKindReminder,
    PlanItemKind.note => l.aiPlanKindNote,
    PlanItemKind.food => l.aiPlanKindFood,
    PlanItemKind.mealChange => l.aiPlanKindMealChange,
    PlanItemKind.avoidItem => l.aiPlanKindAvoidItem,
    PlanItemKind.trackedSign => l.aiPlanKindTrackedSign,
    PlanItemKind.labTracker => l.aiPlanKindLabTracker,
    PlanItemKind.budgetTweak => l.aiPlanKindBudgetTweak,
    PlanItemKind.learningProgram => l.aiPlanKindLearningProgram,
    PlanItemKind.recipe => l.aiPlanKindRecipe,
    PlanItemKind.pantryItem => l.aiPlanKindPantryItem,
  };

  String status(PlanItemStatus status) => switch (status) {
    PlanItemStatus.ready => l.aiPlanStatusReady,
    PlanItemStatus.needsEdit => l.aiPlanStatusNeedsEdit,
    PlanItemStatus.blocked => l.aiPlanStatusBlocked,
    PlanItemStatus.deferred => l.aiPlanStatusDeferred,
    PlanItemStatus.rejected => l.aiPlanStatusRejected,
  };

  String editReason(PlanEditReason reason) => switch (reason) {
    PlanEditReason.dayPassed => l.aiPlanEditDayPassed,
    PlanEditReason.envelopeMode => l.aiPlanEditEnvelopeMode,
    PlanEditReason.foodMissing => l.aiPlanEditFoodMissing,
    PlanEditReason.mealPlanMissing => l.aiPlanEditMealPlanMissing,
  };

  /// The line the checklist shows.
  String checklistLine(String title) => name(title);

  /// What the suggestion would change, in his words – one short line each.
  List<String> changeLines(PlanItemPreview p) {
    final item = p.item;
    final out = <String>[];
    switch (item.kind) {
      case PlanItemKind.task:
        out.add(l.aiPlanChangeChecklist);
        final when = _when(item);
        if (when != null) out.add(l.aiPlanChangeTaskWhen(when));
      case PlanItemKind.note:
        out.add(l.aiPlanChangeNote);
      case PlanItemKind.reminder:
        final owner = p.target(PlanTargetSlot.owner);
        if (owner == null) {
          out.add(l.aiPlanChangeChecklist);
        } else {
          out.add(l.aiPlanChangeReminder(name(owner.name), _time(item.str('time')) ?? ''));
        }
      case PlanItemKind.habit:
        final existing = p.target(PlanTargetSlot.habit);
        out.add(
          existing == null || p.before.kind != PlanBeforeKind.habitOff
              ? l.aiPlanChangeHabitAdd(name(item.title))
              : l.aiPlanChangeHabitBack(name(existing.name)),
        );
      case PlanItemKind.routine:
        out.add(l.aiPlanChangeHabitAdd(name(item.title)));
        final times = [for (final t in item.strings('times')) _time(t) ?? t];
        if (times.isNotEmpty) out.add(l.aiPlanChangeRoutineTimes(times.join(l.recordListSeparator)));
        final steps = item.maps('steps');
        if (steps.isNotEmpty) {
          out.add(
            l.aiPlanChangeRoutineSteps(
              [for (final s in steps) if (s['title'] is String) name(s['title']! as String)].join(l.recordListSeparator),
            ),
          );
        }
      case PlanItemKind.food:
        out.add(
          p.before.kind == PlanBeforeKind.foodKnown
              ? l.aiPlanChangeFoodUpdate(name(item.title))
              : l.aiPlanChangeFoodAdd(name(item.title)),
        );
      case PlanItemKind.mealChange:
        final slot = p.target(PlanTargetSlot.slot);
        final food = p.target(PlanTargetSlot.food)?.name ?? item.str('foodRef') ?? item.title;
        switch (item.str('op')) {
          case 'addFood':
            out.add(l.aiPlanChangeMealAdd(name(food), name(slot?.name ?? '')));
          case 'removeFood':
            out.add(l.aiPlanChangeMealRemove(name(food), name(slot?.name ?? '')));
          case 'newSlot':
            out.add(
              l.aiPlanChangeMealNewSlot(name(item.str('slotName') ?? item.title), _time(item.str('time')) ?? ''),
            );
          case 'moveSlot':
            out.add(l.aiPlanChangeMealMove(name(slot?.name ?? ''), _time(item.str('time')) ?? ''));
        }
      case PlanItemKind.avoidItem:
        out.add(l.aiPlanChangeAvoid(name(item.title)));
      case PlanItemKind.trackedSign:
        out.add(l.aiPlanChangeSign(name(item.title)));
      case PlanItemKind.labTracker:
        out.add(l.aiPlanChangeLab(name(item.title)));
      case PlanItemKind.budgetTweak:
        final envelope = p.target(PlanTargetSlot.envelope);
        final amount = item.number('newAmount');
        final percent = item.number('newPercent');
        if (envelope != null && amount != null) {
          out.add(l.aiPlanChangeBudgetAmount(name(envelope.name), _digits(PlainNumbers.decimal(amount))));
        } else if (envelope != null && percent != null) {
          out.add(l.aiPlanChangeBudgetPercent(name(envelope.name), _digits(PlainNumbers.decimal(percent))));
        }
      case PlanItemKind.learningProgram:
        final target = item.number('target');
        out.add(
          l.aiPlanChangeGoal(
            name(item.title),
            [
              if (target != null) _digits(PlainNumbers.decimal(target)),
              ?item.str('unit'),
            ].join(' ').trim(),
          ),
        );
      case PlanItemKind.recipe:
      case PlanItemKind.pantryItem:
        out.add(l.aiPlanChangeDeferred);
    }
    return out;
  }

  /// What his data says today about the thing this suggestion touches.
  List<String> beforeLines(PlanItemPreview p) {
    final ref = p.before.ref;
    return switch (p.before.kind) {
      PlanBeforeKind.nothingYet => [l.aiPlanBeforeNothing],
      PlanBeforeKind.habitOff => [l.aiPlanBeforeHabitOff(name(ref?.name ?? ''))],
      PlanBeforeKind.habitOn => [l.aiPlanBeforeHabitOn(name(ref?.name ?? ''))],
      PlanBeforeKind.envelope => [l.aiPlanBeforeEnvelope(name(ref?.name ?? ''), _detail(ref?.detail ?? ''))],
      PlanBeforeKind.slotTime => [l.aiPlanBeforeSlot(name(ref?.name ?? ''), _detail(ref?.detail ?? ''))],
      PlanBeforeKind.foodKnown => [l.aiPlanBeforeFoodKnown(name(ref?.name ?? ''))],
      PlanBeforeKind.foodInSlot => [l.aiPlanBeforeFoodInSlot(name(ref?.name ?? ''))],
      PlanBeforeKind.goal => [l.aiPlanBeforeGoal(name(ref?.name ?? ''), _detail(ref?.detail ?? ''))],
      PlanBeforeKind.lab => [l.aiPlanBeforeLab(name(ref?.name ?? ''))],
      PlanBeforeKind.tracker => [l.aiPlanBeforeTracker(name(ref?.name ?? ''))],
      PlanBeforeKind.avoidKnown => [l.aiPlanBeforeAvoid(name(ref?.name ?? ''))],
    };
  }

  /// Every reason the item cannot be applied as it stands, in order. A
  /// refused item always says something: an item the validator threw out
  /// without a sentence we can read still gets one.
  List<String> blockers(PlanItemPreview p) {
    final lines = [
      for (final r in p.editReasons) editReason(r),
      for (final problem in p.problems) this.problem(problem),
    ];
    if (lines.isEmpty && p.status == PlanItemStatus.rejected) return [l.aiPlanProblemUnknown];
    return lines;
  }

  /// How the answer reached the phone – never a download.
  String origin(PlanOrigin origin) => switch (origin) {
    PlanOrigin.paste => l.aiPlanOriginPaste,
    PlanOrigin.file => l.aiPlanOriginFile,
    PlanOrigin.share => l.aiPlanOriginShare,
    PlanOrigin.chat => l.aiPlanOriginChat,
  };

  /// What the AI said it read («فيديو»، «مقال»).
  String sourceKind(String? kind) => switch (kind) {
    'video' => l.aiPlanSourceKindVideo,
    'article' => l.aiPlanSourceKindArticle,
    'channel' => l.aiPlanSourceKindChannel,
    'book' => l.aiPlanSourceKindBook,
    'chat' => l.aiPlanSourceKindChat,
    _ => l.aiPlanSourceKindOther,
  };

  /// «وصلت ١٠ تشرين الأول».
  String importedOn(DateTime at) => l.aiPlanImportedOn(fmt.formatDate(at, style: MadarDateStyle.medium));

  /// «١ من ٤ اقتراحات» – how many suggestions a plan carries.
  String suggestionCount(int count) => _digits(l.aiPlanSuggestionCount(count));

  /// One compact side of the before/after: «بقالة: ١٢٠.٠٠٠ JOD monthly»,
  /// or null when there is no record to name (nothing like it yet).
  String? refLine(PlanBefore? before) {
    final ref = before?.ref;
    if (ref == null) return null;
    return _refLine(ref);
  }

  String _refLine(PlanRef ref) {
    final detail = ref.detail?.trim();
    return detail == null || detail.isEmpty ? name(ref.name) : l.aiPlanRefLine(name(ref.name), _detail(detail));
  }

  /// The names of the suggestions one item is waiting for – never an id.
  String waitingFor(Iterable<String> names) => l.aiPlanWaitingFor(names.map(name).join(l.recordListSeparator));

  /// What the plan's own `source` block says, as lines he can read. The
  /// flagged claims are **not** in here: they are a warning of their own
  /// ([L10n.aiPlanClaimsTitle]), never something to approve.
  List<String> sourceLines(PlanSource source) {
    final title = source.title?.trim();
    final url = source.url?.trim();
    final partial = source.completeness?.trim();
    return [
      if (source.kind != null || (title != null && title.isNotEmpty))
        [
          sourceKind(source.kind),
          if (title != null && title.isNotEmpty) name(title),
        ].join(l.recordListSeparator),
      if (url != null && url.isNotEmpty) name(url),
      if (partial != null && partial.isNotEmpty) l.aiPlanSourcePartial(name(partial)),
    ];
  }

  /// One problem as a sentence he can act on.
  String problem(PlanProblem p) {
    final field = p.detail ?? p.path ?? '';
    final limit = p.limit == null ? '' : _digits(PlainNumbers.decimal(p.limit!));
    return switch (p.code) {
      PlanProblemCode.notJson => l.aiPlanProblemNotJson,
      PlanProblemCode.notAnObject => l.aiPlanProblemNotAnObject,
      PlanProblemCode.notAMadarPlan => l.aiPlanProblemNotAPlan,
      PlanProblemCode.unsupportedVersion => l.aiPlanProblemVersion(
        _digits(p.detail ?? ''),
        _digits('$madarPlanVersion'),
      ),
      PlanProblemCode.tooBig => l.aiPlanProblemTooBig(_digits(p.detail ?? ''), limit),
      PlanProblemCode.tooDeep => l.aiPlanProblemTooDeep,
      PlanProblemCode.trailingText => l.aiPlanProblemTrailingText,
      PlanProblemCode.noItems => l.aiPlanProblemNoItems,
      PlanProblemCode.tooManyItems => l.aiPlanProblemTooMany(limit),
      PlanProblemCode.duplicateItemId => l.aiPlanProblemDuplicate(name(field)),
      PlanProblemCode.missingField => l.aiPlanProblemMissingField(name(field)),
      PlanProblemCode.missingReason => l.aiPlanProblemMissingReason,
      PlanProblemCode.wrongType => l.aiPlanProblemWrongType(name(p.path ?? field)),
      PlanProblemCode.blankText => l.aiPlanProblemBlank(name(p.path ?? field)),
      PlanProblemCode.tooLong => l.aiPlanProblemTooLong(name(p.path ?? field), limit),
      PlanProblemCode.unknownField => l.aiPlanProblemUnknownField(name(field)),
      PlanProblemCode.unknownKind => l.aiPlanProblemUnknownKind(name(field)),
      PlanProblemCode.unknownValue => l.aiPlanProblemUnknownValue(name(p.path ?? ''), name(p.detail ?? '')),
      PlanProblemCode.outOfRange => l.aiPlanProblemOutOfRange(name(p.path ?? field)),
      PlanProblemCode.badDay => l.aiPlanProblemBadDay(_digits(field)),
      PlanProblemCode.badTime => l.aiPlanProblemBadTime(_digits(field)),
      PlanProblemCode.badWeekday => l.aiPlanProblemBadWeekday(_digits(field)),
      PlanProblemCode.unknownReference => l.aiPlanProblemUnknownRef(name(field)),
      PlanProblemCode.missingDependency => l.aiPlanProblemMissingDep(name(field)),
      PlanProblemCode.circularDependency => l.aiPlanProblemCircularDep,
      PlanProblemCode.controlCharacters => l.aiPlanProblemControlChars(name(p.path ?? field)),
      PlanProblemCode.healthAdvice => l.aiPlanProblemHealth(name(field)),
      PlanProblemCode.deferredKind => l.aiPlanProblemDeferred,
    };
  }

  /// Every problem of a payload as sentences, payload-level first.
  List<String> problems(Iterable<PlanProblem> problems) => [for (final p in problems) problem(p)];

  // ------------------------------------------------------------- utilities --

  String? _time(String? raw) {
    if (raw == null) return null;
    final minutes = planMinutes(raw);
    if (minutes == null) return null;
    return fmt.formatTime(DateTime(2026, 1, 1, minutes ~/ 60, minutes % 60));
  }

  /// «الخميس ٨ تشرين الأول، العصر» from a task's day and window.
  String? _when(PlanItem item) {
    final day = item.str('day');
    final window = item.str('window');
    final parts = <String>[
      if (day != null && planParseDay(day) != null)
        fmt.formatDate(planParseDay(day)!, style: MadarDateStyle.weekdayDayMonth),
      if (window != null) _windowLabel(window),
      for (final d in item.ints('weekdays')) _weekday(d),
    ];
    final text = parts.where((s) => s.isNotEmpty).join(l.recordListSeparator);
    return text.isEmpty ? null : text;
  }

  String _weekday(int iso) => DateFormat('EEEE', fmt.languageCode).format(_monday.add(Duration(days: iso - 1)));

  String _windowLabel(String window) => switch (window) {
    'fajr' => l.prayerFajr,
    'dhuhr' => l.prayerDhuhr,
    'asr' => l.prayerAsr,
    'maghrib' => l.prayerMaghrib,
    'isha' => l.prayerIsha,
    _ => '',
  };
}
