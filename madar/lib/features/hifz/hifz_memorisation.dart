/// «الحفظ» – memorisation at full strength (PLAN.md Part 14), **step 1:
/// the engine**.
///
/// Import `package:madar/features/hifz/hifz_memorisation.dart`.
///
/// The owner, 2026-10-15: the memorisation **methods, as modes** he chooses
/// between, on top of the Hifz tracking that already exists; a **daily
/// plan** of a new portion, a near review and a far one, spaced by how
/// strong each piece is; a **page map coloured by strength**; **missed days
/// that never pile up**; **goals in his own words** with reminders tied to
/// the prayer times; and **progress** he can see.
///
/// ## What is in this package, and what is not
///
/// * **It builds on Part 13 and duplicates none of it.** The hiding
///   machine, the blank drill, the aligner, the mistake log and the
///   statistics are «التسميع»'s (`lib/features/tasmee/`), and every result
///   «الحفظ» produces is written into **that** log, under its own
///   [TasmeeMode]. There is no second log, no second mistake table and no
///   second hiding machine here.
/// * **The strength is never stored.** It is computed from Part 13's rows
///   every time it is asked for ([HifzStrengths]), so it cannot drift away
///   from what actually happened, and opening a screen cannot raise it.
/// * **Nothing religious is generated.** Every letter comes from the
///   verified text through `lib/features/quran/`. The first-letters stage
///   is a *verbatim prefix* of the word; the blanks, the links and the
///   writing comparison are positions in the original ayah text.
/// * **There is no speech model in this build.** Every mode but «سمّع»
///   works without one – the written ones by typing – and
///   [HifzMethods.statusOf] says so plainly instead of throwing.
/// * **No audio, anywhere.** «اسمع وردّد» produces a *plan*
///   ([ListenRepeatPlan]) for the existing player; no type here holds
///   bytes, a file or a waveform.
///
/// ## The engine
///
/// | file | what it does |
/// |---|---|
/// | `domain/mushaf_shape.dart` | walking the mushaf: pages, juz', ranges, neighbours |
/// | `domain/hifz_marks.dart` | «مش عليّ» and «صفّر القوة» – his own decisions |
/// | `domain/hifz_strength.dart` | the strength per ayah, from real results only |
/// | `domain/hifz_modes.dart` | the seven methods, and what each needs to run |
/// | `domain/hifz_daily_plan.dart` | the day: new · near · far, the cap, and what it dropped |
/// | `domain/hifz_page_map.dart` | the mushaf coloured by strength, as data |
/// | `domain/hifz_goals.dart` | «الكهف كل جمعة» and friends, and where they stand |
/// | `domain/hifz_goal_reminders.dart` | their reminders, hung off the prayer times |
/// | `domain/hifz_progress.dart` | streaks and the heatmap |
/// | `domain/hifz_export.dart` | the `"hifz"` block inside Part 13's export |
/// | `data/hifz_plan_service.dart` | the two tables of schema v8, every write with an undo |
/// | `data/hifz_goal_notifications.dart` | the reminders over Madar's notification service |
/// | `data/hifz_plan_providers.dart` | what the screens of step 2 read |
///
/// ## Where a screen starts
///
/// 1. `ref.watch(hifzMethodsProvider)` – **before** offering a mode. A
///    mode with [HifzMethodStatus.typedOnly] is offered with the keyboard;
///    one that is [HifzMethodStatus.unavailable] is said to be not ready
///    on this phone, never silently hidden.
/// 2. `ref.watch(hifzDailyPlanProvider)` – today's three tracks, each
///    portion carrying its range, its band, the mode to use and the stage
///    to start at. [HifzDailyPlan.backlog] is what a week away cost, and
///    it is shown, not swallowed.
/// 3. `ref.watch(hifzTargetProvider(range))` – the words of the verified
///    text (Part 13's own target).
/// 4. Run the mode: [WritingDrill] for «اكتب من حفظك», [BlankDrill] and
///    [HiddenVerseMachine] from Part 13, [FirstLetters.ofTarget] for the
///    middle stage of the ladder, [Linking.of] for the joins,
///    [ListenRepeatPlan.build] for «اسمع وردّد».
/// 5. When he finishes: `hifzPlanServiceProvider` →
///    [HifzPlanService.recordDrill] (or [HifzPlanService.recordWriting]),
///    which writes into Part 13's log and returns the undo.
/// 6. `ref.watch(hifzPageMapProvider)` / `hifzProgressProvider` for the
///    map and the heatmap; `hifzGoalProgressProvider` for the goals.
///
/// ## The data (schema v8)
///
/// | table | what it is |
/// |---|---|
/// | `hifz_goals` | one goal in his own words, with the prayer its reminder hangs off |
/// | `hifz_marks` | one stretch he marked «مش عليّ» or reset the strength of |
///
/// and `key_values['hifz.plan']` for [HifzPlanSettings]. The results
/// themselves live in Part 13's three tables, and the inventory in the
/// `hifz_items` of schema v2.
library;

export '../../core/domain/enums.dart' show HifzGoalKind, HifzMarkKind, TasmeeMode;
export 'data/hifz_goal_notifications.dart';
export 'data/hifz_plan_providers.dart';
export 'data/hifz_plan_service.dart';
export 'domain/hifz_daily_plan.dart';
export 'domain/hifz_export.dart';
export 'domain/hifz_goal_reminders.dart';
export 'domain/hifz_goals.dart';
export 'domain/hifz_marks.dart';
export 'domain/hifz_modes.dart';
export 'domain/hifz_page_map.dart';
export 'domain/hifz_progress.dart';
export 'domain/hifz_strength.dart';
export 'domain/mushaf_shape.dart';
