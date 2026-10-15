# Where we are right now

**Read `madar/PLAN.md` first** – it is the complete ordered plan (every part, in order,
one APK each). This file keeps only the live state and the raw owner feedback.

## State (2026-10-10)
- Nothing is running. Everything is committed and pushed on `claude/madar-life-os-nmoysk`.
- Last shipped: **APK #28**, commit 94b68a3, CI run 38629797819, artifact madar-apk-28 (id 11928037229)
  - the games world and the re-laid-out orrery. (#26 was Part 5, 9ac81f8; #25 Part 3b; #24 Part 3.)
- **«الألعاب» is the tenth world** (`c3b80b4`), outside the balance and the Neglect Radar by two
  independent guards: every source spelled out at 0 (an *absent* source falls back to 0.2) and
  `weight: 0`, which makes `SceneSnapshotBuilder` skip it whatever its score. Growth lost the
  cinema card.
- **The orrery was re-laid-out for any count 1-16** (`99e0bd8`): `minLaneGap` derived from the
  band and a 16-world floor instead of a constant, the camera's 0.06 hero-bleed deleted (it had
  been pushing discs 18-20 px off-screen **even at eight worlds** - the owner spotted it at ten),
  `innerRadius` 0.95 measured off the dial's limb, even angular shares with a 10% jitter instead
  of the golden angle, the size spread clamped to 1.18, and discs shrinking past ten worlds.
  Cost: the system and the dial are 13% smaller. Put to the owner; if he wants it grander the
  lever is the camera elevation (opening the ellipses) or `coreRadius`, not the band.
- Fixed with it: a custom-modules test that tapped a row hidden under the sticky save bar (now
  `.hitTestable()`), and the search perf budget - see the measurement note below.
- **PLAN.md Part 5 is DONE** (`2a9b4da` engine + `9ac81f8` screens): «السفرة», a ninth planet
  for his wife - pantry (its own tables, schema **v6**), recipes with photos copied into app
  storage, the matcher that refuses to guess a conversion, the no-repeat window with her
  override, her constraints, and the missing becoming a list through Part 3b's engine. The
  world is dormant until she files a task under it (`{tasks: 1, activity: 0}`), so an unopened
  kitchen never dims the sky or reaches the Neglect Radar. An existing install gains the world
  through `_addMissingPlanets()` without re-seeding anything else. The AI bridge's `recipe` and
  `pantryItem` kinds now apply.
- Known gaps from Part 5: no «السفرة» section in the AI export summary (deliberate - that
  would put her pantry into an AI prompt, and it is the owner's call); the diet link to Part 4
  is still `DietLink.off` with no producer; no kitchen notifications; `useUp`'s silent refusal
  is answered in the action layer, not the service.
- **Owner asked (2026-10-14)**: the games become their own planet (decided: it must NOT count
  in the balance or the Neglect Radar - the app must never scold him for not playing), and he
  asked about filing daily tasks under a planet, which already exists (tasks carry `planetKey`,
  the add sheet has a picker, the home row shows the planet's name and colour) - he may just
  not have noticed it.
- **Owner's concern (2026-10-14)**: a lot is left. Put to him: ~7 parts for the life side, but
  51 games is 10-12 APKs on its own. Recommended finishing the life side first and then doing
  games in batches with no deadline, and asked him to name the games he actually plays - every
  rules engine is already written and tested, so only the look of each is left.
- Last shipped before: APK #25, commit 08e2fd0, CI run 38487850797 (Part 3b).
  (#24 was Part 3, a908442; #22 was Part 2, c76a47d; #19 was Part 4's UI, e6cb0fc.)
- **PLAN.md Part 3b is DONE** (`08e2fd0`): `lib/features/lists/` on schema **v5**
  (`record_lists`, `record_list_items`), addressed by the same `(hostTable, hostId)` pair
  `LifeRecordLinks` resolves, so Part 5's pantry is a new host and nothing more. Shopping
  lists under a budget envelope post the ticked part as one transaction through the ledger's
  own service, claimed inside the writing transaction so it cannot charge twice; trips carry
  «قوائم ثانية للرحلة» beside their own packing list; `/lists` is every list grouped by its
  record, orphans last. Lists and items are searchable in his words and export.
- Known gaps from Part 3b: the trip's own `trip_items` packing list is still a second
  hand-rolled tick list (migrating it ripples through Orbit, Import and Search - its own
  part); no list CSV kind; ticking logs no activity row, so the Neglect Radar does not know
  about an unticked list; posting always uses today.
- **Measurement note**: `test/features/search/systems_perf_regression_test.dart` budgets the
  first query's UI block at <100 ms. Alone on this container it measures 73-96 ms; inside a
  whole-suite `-j 1` run the container is loaded and it reads 109-127 ms and fails. CI passes
  it. Do not "fix" it by raising the budget without measuring the same scope twice - an
  earlier comparison of mine was wrong because one side ran a single test and the other ran
  two hundred.
- **PLAN.md Part 3 is DONE** (commit `7c3d498`, with `a908442` fixing one test):
  the «خطة مدار» v1 contract and engine (`lib/features/ai_bridge/`), the export tile under
  Settings > «بياناتك», the paste box / file picker / **Android share intent**, the per-item
  review screen, the checklist with its home-panel line, and the history. Schema **v4**
  (`applied_plans`, `applied_plan_items`). 129 tests in `test/features/ai_bridge`.
  Owner additions folded in (2026-10-10): approved items become a named checklist he ticks
  («٢ من ٤»), and a line on the home panel under the Neglect Radar while anything is unticked.
- Known gaps from Part 3: an edited suggestion's stored `payload` keeps the AI's original
  value (the applied data and the screen are right; an engine change); `mealPlanMissing` has
  no edit sheet; the share intent is proven by aapt2/kotlinc and a Dart fake, never on a
  device; no duplicate detection, so the same answer imported twice makes two plans.
- **Orbit feedback on APK #22, fixed** (`cf1045c`, `79ea8d5`, `a908442`): the sky read as
  still, so the inner lane went 330 s -> 170 s a revolution and the moons 78 s -> 42 s; and
  the reset button wore the app's "restart" arrow, so it now wears a centre-focus crosshair.
  Two orbit tests had baked the old speed into a magic number - a 600-step ghost hunt that
  timed the whole file out, and a flat 24 px glide cap. Both were rewritten to assert the
  thing they meant (laps, and smoothness) rather than a number that only held at one speed.
- **Part 3b is next** (checklists anywhere: a shopping list under a budget item, a packing
  list on a trip, the kitchen pantry - one shared list engine), unless the owner's feedback
  on APK #24 changes it.
- **PLAN.md Part 1 is DONE** - all six APK #15 bugs fixed and verified (overlapping tabs via the
  new `MadarFadeStack`, the task "+" footer row, leaving a game, moons, the home panel extent +
  back handling, the icon-only reset-view button).
- **PLAN.md Part 4 is DONE** (pulled ahead of Part 2 at the owner's request - the food tracker and
  chronic conditions). Two commits:
  - `0632fcc` the engine: schema **v3** (foods, food_logs, meal_plans, meal_slots, meal_slot_foods,
    food_rules + `conditions.color`), `lib/features/nutrition/**` pure models/engines/providers,
    meal reminders on the free id block **139000-139499**.
  - the UI commit: `lib/features/nutrition/presentation/**` - the «الأكل» tab on the Body planet,
    quick log, food library, meal plan (build + planned-vs-eaten), conditions and his own rules with
    the live-preview rule editor, observations gated on `nutritionReadinessProvider`; routes
    `/food/{library,plan,rules,insights}`; `nutritionReminderSyncProvider` watched in
    `watchLifeServices`; `MealReminderTaps` -> `/body?tab=food`; `MealDescriber` in the notification
    centre; the six tables mapped in `data_areas.dart`; `NutritionTodayCard` on the Body hub.
  - 52 widget tests + 26 screenshots, ARB part `f2_nutrition_ui.json`, analyze clean.
- Known gaps from Part 4 (small follow-ups, not blockers): a meal reminder opens the day but does not
  highlight the slot it named (a `/food/plan?day=` deep link would fix it); no drag reorder for rules
  or conditions; the rule editor lists the whole library as chips with no search; importing rules from
  an AI plan is Part 3.
- Next: **PLAN.md Part 2** (wire the finished system packages: search, notification centre + gate,
  export/backup, AI chat, widgets, Together) - unless the owner's feedback on the new APK changes it.
- Note: the CI workflow only triggers on changes under `madar/**` - an empty or docs-only commit
  outside that path will not build.

- **Owner's six new requests (2026-10-15) are written into PLAN.md, each with a definition of
  done (works / tests / edge cases / blockers).** Where each landed: the iqama into **Part 9**;
  recitation checking into the new **Part 13 «التسميع»**; memorisation methods into the new
  **Part 14 «الحفظ»**; the on-device model into the new **Part 15**; the kids section into the
  new **Part 16 «مدار الصغار»**; the sky upgrade into **Part 12 «السما»**.
  Verified against the code before writing: there is no iqama, recitation is listening only
  (EveryAyah) with no microphone permission anywhere, hifz and wird exist, the star catalog and
  the orrery exist, there is no on-device model, and there is no kids version.
- **The order he approved (2026-10-15)**: after Part 7 ships → 9 (with «الإقامة») → 13 → 14 →
  15 → 16, then the remaining life and games parts (6, 8, 10, 11), and 12 (with «السما») last.
  *(His note listed Part 4 among the remaining; Part 4 shipped as APK #19 - flagged to him.)*
- **Three open questions, each a gate**: a reviewer he names for the kids section's religious
  content; his approval of the kids design; his approval of a visual reference for «السما».
- **Nothing new starts before Part 7 ships** - the working rule stands.

## STOPPED 2026-10-16 (weekly limit near; the OMS has priority until it renews Tue 20/10)

**Where it stopped.** Everything is committed and pushed on `claude/madar-life-os-nmoysk`,
head `39a84a1`, working tree clean. The last APK the owner has is **#36**
(run 38691456442) - the daily chat, the iqama and Hifz.

**The one thing outstanding, and it is the first step back:** the build of `f2b24aa`
(the Work board + the gym) **failed on 3 tests out of 8399** and no APK came out of it, so the
kanban, the gym and the AI-chat privacy work are on the branch but not yet in his hands. The
three were never identified - a whole-suite run was in flight when work stopped.

**First step when we return**, in order:
1. **One of the three is already found** (a whole-suite run got 4 minutes in before work stopped):
   `test/app/search_opener_test.dart:140` - the case `an exercise opens the plan` expects
   `/body?tab=plan`, but the gym gave an exercise its own screen, so `searchTargetOf` now returns
   `/body/gym/exercise/r1`. The new behaviour is the right one (search opens the exercise itself,
   not the tab above it), so the fix is the test's expectation, not the code. Check line 141
   (`a workout opens the plan`) in the same breath - it passed, but confirm it still should.
2. The other two are unknown: re-run `$SCRATCHPAD/ftfull --exclude-tags screenshot` from `madar/`
   and read `Failing tests:` at the end. The likely suites are the ones the gym and the board
   touched: data, app, import, search, notification_center, orbit, work. (The gym added schema
   **v10** and three tables and touched `data_areas.dart`, the routes and the deep links; the
   Work board added **v9** and two columns.)
3. Fix all three, push, and ship the APK - it carries the Work board, the gym and the chat privacy.
4. Then the next part by his order. «الموديل على الجوال» is the next one and is **unblocked
   now**: he decided on 2026-10-16 that the model is **not** bundled in the APK - the app
   downloads it on first use of «التسميع», over Wi-Fi, behind his fingerprint, and keeps it on
   the phone. Candidate reported to him and awaiting nothing: **tarteel-ai/whisper-base-ar-quran**,
   **Apache 2.0**, Whisper Base (77M params), WER 5.75%, with a whisper.cpp/GGML conversion
   available. One honesty note still to close before downloading: its model card does not
   document the training data.
5. Still waiting on him, and only when those parts come up: the reviewer for «مدار الصغار»'s
   religious content, the kids design, and the visual reference for «السما».

**Cancelled by the owner 2026-10-16:** linking the Work board to «فلك». No card-field document,
and no further features on the board.

**Answered 2026-10-16:** the Quran text is Tanzil (Uthmani, Hafs 'an 'Asim, v1.1), CC BY 3.0
with Tanzil's terms, bundled verbatim and pinned by SHA-256.

## Night of 2026-10-15 → 16 (he was asleep; one agent at a time)

Shipped, in his approved order, each its own commit:
- **Part 7 الشات اليومي** - engine + screen, reachable from the home panel's bar. APK **#32**.
- **AI chat off by default** (he asked twice; the second time won): its own stored setting, off
  on a fresh install, enforced at the transport **and** in the controller, with every way in
  saying so. Proved zero requests in the real app with a key in the vault. The summary's
  sections are untouched - he said the content itself was not his worry.
- **Part 9 «الإقامة»** - adhan + his own offset per prayer, Friday its own, «صلّيت» logging from
  the shade with the app dead (one row, never two), one «بعد شوي», id block 180000-180999.
  APK **#33**.
- **Part 13 «التسميع» step 1** - the checking engine against a **stub recogniser** (no model may
  be downloaded: his disk was full). Schema v7. No type in the package can hold audio.
- **Part 14 «الحفظ» step 1 + step 2** - the methods, the daily plan with its backlog cap, the
  strength that is recomputed and never stored, goals on prayer windows (ids 190000-190999),
  schema v8; then the screens, with the six typed methods working tonight and «سمّع بصوتك»
  listed-but-dark until the model lands. Typed «شازام القرآن» works.

**Disk**: started the night at **2.4 GB free**, under his 10 GB line. Deleted
`madar/screenshots/**` (5.6 GB of gitignored review PNGs, regenerable) and stale
`/tmp/flutter_tools.*` → **~8.7 GB**. No screenshot test was run after that, so no PNG exists
for anything built tonight - the next visual pass must regenerate them.

### «للصبح» - what waits for him
1. **A recitation model for «التسميع»**: an open model trained on Quranic recitation, licence
   checked, and the disk space to hold it. The engine is finished and the interface it must
   satisfy is written at the top of `lib/features/tasmee/domain/recogniser.dart`. Until then
   «سمّع بصوتك» is the one dark mode; everything else in Hifz works typed.
2. **The three approvals already on the list**: a reviewer he names for «مدار الصغار»'s
   religious content, the kids design, and a visual reference for «السما». None was started.
3. **Not visually reviewed**: everything built tonight has no screenshot pass.
4. **Planet size** stays 13% smaller unless he says otherwise (his instruction).

## How work is organised
- Working rule (standing): one part at a time → verify → APK → report in plain Arabic with
  an example → next part. Full rule in `/CLAUDE.md`.
- Test runs go through `scratchpad/ft` only (serialised, -j 1, waits for free memory).
- WIP commits are `[skip ci]`; a release commit is a normal commit (CI builds the APK).
- Never commit the keystore, `key.properties` or any `*.jks`.

---

# Raw history and owner feedback (source material for PLAN.md)

## OWNER FEEDBACK ON APK #15 (2026-10-09) – two screenshots attached in chat
### A. BUGS (fix first, one batch → APK)
B1. Overlapping text: the Money goals screen (المدّخرات والالتزامات) draws the empty states of ALL THREE tabs
    (الالتزامات / الديون / الحصّالات) on top of each other – title, body and buttons stacked. Screenshot 1.
    Likely the tab bodies are all built/painted at once (IndexedStack/Offstage/AnimatedSwitcher misuse) – check every
    tabbed screen built the same way (travel, body, goals …), not only this one.
B2. Orbit: planet motion is wrong/not nice; moons of each planet do not show at all.
B3. Back from a planet: screenshot 2 – returning shows the home panel pulled up over the screen (the sheet is at full
    height, blurred content behind) and back does not restore it; the user has to drag it down, and pressing back
    again exits the app. Fix the sheet state restore on pop + back behaviour (back should collapse the sheet first,
    then leave the planet, never exit the app from there).
B4. Tasks: the "+" (add task) button only shows for the first task; afterwards it disappears and the user must repeat
    actions to get it back.
B5. Reset-view button → icon only, no text, appears only when the orbit is off its default (already noted).
### B. CHANGES / NEW FEATURES (each one its own part + APK, in this order unless the owner says otherwise)
C1. Budget → shopping lists: when a budget item is e.g. "بقالة", be able to attach a list of things to buy
    (items, qty, optional price, check off, turn the checked list into one transaction).
C2. Work: a real workspace + kanban board like Trello (drag cards between columns) – the board exists but the owner
    could not find/use it; make it the main view with drag & drop.
C3. Body/gym: advanced exercise library – per exercise: photo of the machine, a video of the movement (user-added or
    a link), sets/reps/weight, rest timer, history and progression. Today it is too basic.
C4. Food tracker: log what he ate today, the app classifies it (type + a "how risky for you" rating) – tied to C5.
C5. Chronic conditions: record his chronic illnesses and connect everything to them (meals, meds, pain, labs, habits)
    so warnings/insights are condition-aware. Keep it tracking-only, no diagnosis.
C6. Daily chat as the main input: a chat where he types everything that happened during the day and the app files it
    into the right places (plus the manual entry that exists), and he can ask "شو صار اليوم؟" – on top of the AI chat
    with his own key (ai_chat package exists; the copy/share JSON round trip is the agreed default).
C7. Quran reader: reading themes independent of the app theme – white page, brown/sepia paper, reading mode.
C8. Adhan: real muezzin audio (owner asks for it). NOTE for the owner: we found no openly licensed recording;
    options = he supplies/records a file, we bundle a user-chosen file, or keep procedural. ASK before building.
C9. Adhkar notifications: show on time as a heads-up/overlay above the screen, with "done" / dismiss actions from the
    notification itself.
C10. NEW PLANET for his wife – kitchen/food («المطبخ» or similar): what is in the house (pantry), suggests dishes from
    what is available, never repeats the same dish, with quantities and step-by-step method, and constraints
    (special requests, allergies, time, diet). Offline-first; AI suggestions via the copy/share JSON round trip.


## Owner feedback on APK #15 + new requests (2026-10-07) – ALL FOR NEXT WEEK
Work style: one part at a time → APK after each part; save tokens; 1–2 agents max.
1. GAMES BUG (first): «ما بقدر اعمل مغادرة» – he cannot leave a game (no working exit/back from the game screen).
   Also unfinished games show in the hall – make it obvious which are playable (or hide unfinished).
2. DIET / MEAL PLAN: a meal plan with times («الساعة كذا آكل كذا، بعدين كذا») + log/track everything eaten
   (likely under the Body planet next to fasting/water; reminders per meal; planned vs eaten).
3. NEW IDEA – "learn from a source" planets (owner's own words, summarised):
   He picks any source he admires (e.g. a doctor's YouTube channel on OCD treatment, a philosophy channel,
   a porn-addiction recovery method, gym exercises), extracts its method/style/content with Gemini as a JSON file,
   imports it into a NEW planet in Madar. Madar turns it into a program: daily tasks, exercises, quizzes,
   interactive practice, graded step by step until he masters it; it evaluates his daily results, picks the next
   step from them, and keeps him going when he slacks or gets bored (plays on what motivates him).
   Design notes: we define the JSON format + a ready Gemini prompt; progression ladder with pass criteria so it
   works offline; health/therapy topics stay "practice & track" with a gentle note to see a professional
   (no diagnosis/treatment claims); content is his own import, stays on device.
4. AI LINK – DECIDED (owner, 2026-10-07): NO login. Copy/share round trip with any AI app (Gemini/ChatGPT/Claude):
   a) Madar EXPORTS everything he picks as one JSON (+ a ready prompt that tells the AI what to analyse and the exact
      JSON shape to answer in) → share sheet / copy.
   b) The AI analyses and answers with a "Madar plan" JSON (schema we define: suggested tasks, habits, routines,
      meal-plan changes, budget tweaks, learning-planet programs, reminders, notes – each item with a reason).
   c) He shares/pastes that JSON back into Madar → Madar validates it, shows every suggested change as a card with
      the AI's reason, he approves/edits/rejects each one, and only approved items are applied (never silent changes;
      health items stay "track & practice", no diagnosis). Madar keeps a history of applied plans and later shows
      what improved (before/after from his own data).
   Same import pipe also carries the "learn from a source" planet JSON (item 3). The existing data package already has
   the full JSON export + AI-ready Markdown summary with per-section choice – reuse it; the API-key chat stays optional.
5. Pending from before: «Flappy Orbit» name question (A keep / B Orbit Flutter / C new name).
Then continue the earlier plan (system integration, remaining Tier 1 games, Tier 2 batches).

Preview APK #15 shipped: commit d9d5204, CI run 37652536745 green, artifact madar-apk-15 (id 11500185799).
It contains: everything up to Money (APK #14) + Life planets (integrated, reviewed, fixed) + Madar Cinema hall
(Growth planet card) with the demo, Metropolis Machine, Flappy Orbit and Saved Games.

NEXT WEEK, in this order:
1. System integration: run the System part of scratchpad/life_system_integration.js (system:integrate → 2 finders → fix):
   search, notification center + NotificationGate (safety wiring as specified), data export/backup, AI chat,
   home-screen widgets, Together (route, settings tile, togetherTransportOverrides, manifest Nearby permissions
   from scratchpad/phase10_packages.md, delete-all keys). Deferred Life items are skipped tests (ai_summary_life_labels,
   search_life_labels, life_cohesion) – un-skip them there.
2. Tier 1 games: Caravan Dash (partial on disk), Noir Rooftops, Neon Souk Racer – scratchpad/tier1_games.js pattern
   (build → critic). Title note: the critic flagged that "Flappy Orbit" echoes "Flappy Bird" (owner's own spec name – ask).
3. Tier 2 game UIs in batches of 5 (rules engines done), APK per batch; Together game modes; performance pass; final delivery.

## WRAP-UP FOR THE OWNER'S PREVIEW (2026-10-07, owner: «finish the right things, then stop until next week») – DONE
Running now:
1. scratchpad/wrapup_life_cinema.js (wf_2352f0e4-20e): Life integrate (resume) → 2 finders → fix → wire /cinema, /cinema/game/:id, /saved-games + Growth hub card.
2. scratchpad/wrapup_games.js (wf_88b3ab12-7ae): Metropolis Machine critic; Flappy Orbit build (resume, ~4k lines on disk) → critic.
Then: release prep (snapshot + full suite through scratchpad/ft, exclude unfinished caravan_dash/noir/neon if they break analyze) → CI APK → send link → STOP.
NEXT WEEK: system integration (search, notification center + gate, backup/export, AI chat, widgets, Together wiring + manifest Nearby permissions) via life_system_integration.js's System part; Caravan Dash (partial ~1.2k lines), Noir Rooftops, Neon Souk Racer; then Tier 2 game UIs in batches of 5.

## Session limit hit 2026-10-07 ~04:30 (reset 06:00); resumed 06:06
- Life+System integration: relaunched fresh again (RESUMING note; ~5 h of partial work on disk and committed).
- Tier 1 games: build:metropolis_machine DONE (cached); caravan_dash / flappy_orbit / noir_rooftops / neon_souk_racer builds and the MM critic re-run with RESUMING notes via resumeFromRunId wf_ab3e4411-e23 (script copy scratchpad/tier1_games.js).

## Weekly usage limit hit 2026-10-02 22:41 (reset Oct 6); resumed 2026-10-07 01:10
- Life+System integration: relaunched fresh (wf_8e85fa56-570); the earlier 2-hour partial work (life_route_pages, life_services, life_hubs, life_settings_section …) is on disk and committed.
- Engine: audio + hall DONE (reports in scratchpad/phase7_engine_packages.md); critic re-run via resumeFromRunId wf_4495c71d-7d5.
- Tier 1 games started (owner: «والالعاب نفسها مع المحرك»): wf_ab3e4411-e23, script copy scratchpad/tier1_games.js – flappy_orbit, metropolis_machine, caravan_dash, noir_rooftops, neon_souk_racer, each build → critic, 2 at a time; each game owns games/<id>/**, test/features/cinema/games/<id>/**, c5–c9 ARB parts.

## Container restart #3 (20:33 UTC, three agents running tests at once). All test runs now go through scratchpad/ft (flock-serialised, -j 1, memory wait). Life+System integration relaunched fresh (little lost: its work was in 47b2644); engine audio+hall re-run with resumeFromRunId.

## Resumed 2026-10-02 on the owner's «كمل»: Life+System integration (new run wf_73ea237d-651), Together transports review (wf_7135f615-749), engine audio+hall (wf_4495c71d-7d5) – all RUNNING with RESUMING notes.

## Talking to the owner (standing rule)
Every decision or report to the owner: plain Jordanian Arabic, no technical words, one concrete example per item. Decisions: think first, ask only what needs him, put the BEST answer first with a detailed why, then every other option with details, mark the current one, short answer format. Full rule + example in /CLAUDE.md.

## Owner decisions
- EveryAyah recitations: approved (stream on play / download on request; credited).
- Card and board games: Jordanian rules as defaults.
- 2026-10-02: owner accepted all 9 proposed rule defaults (Tarneeb all-pass same dealer, Trix partner double no bonus, Hand joker 15 / printed jokers only, Konkan own game to 301, Basra 7♦ sweeps, Ludo pairs captured, Tawla 31 contrary layout, dominoes lock ends round). No code change needed – all were already the defaults.

## Next
1. Money integration green → snapshot build → APK.
2. Life integration + review (shared files one at a time); register
   assets/licenses/games_words_credits.txt in lib/app/licenses.dart.
3. Wire export/backup, search, notification center (Phase 9), then AI chat,
   widgets; Tier 1 games on the engine; Tier 2 UIs in batches of 5.
4. Delete this .resume folder once everything is integrated and green.
