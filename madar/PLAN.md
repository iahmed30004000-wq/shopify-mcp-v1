# Madar – the complete remaining plan (written 2026-10-09)

One source of truth for everything that is left: the owner's original brief, every
decision he has made since, his feedback on APK #15, and his new ideas.
`.resume/RESUME.md` keeps only the live "where are we right now" state and the raw
feedback; **this file is the ordered plan**.

**Working rule (owner, standing):** one part at a time → finish it → verify it →
ship an APK → report in plain Arabic with an example → then the next part.
At most 1–2 agents at a time. No duplicate verification passes when CI runs the
same checks. Never leave several half-finished things running.

**Shipped so far:** APK #15 (commit d9d5204) = foundation + Astrolabe Orbit + Faith
(prayer, adhan, tracker, adhkar, Quran, recitation, wird, Hifz, qibla) + Health +
Money + the six Life planets + Madar Cinema hall (demo, Metropolis Machine,
Flappy Orbit) + Saved Games.

**Built and verified but NOT yet reachable in the app:** global search, notification
centre, data export + encrypted backup, AI chat (own key), home-screen widgets,
Together Mode (core, couple specials, Nearby + optional online transports), and the
rules engines for ~45 Tier 2 games.

---

## Part 1 — Bug fixes from APK #15  → APK #16

Everything the owner hit on his phone. One batch, because they are all small.

1. **B1 Overlapping empty states.** The Money "المدّخرات والالتزامات" screen paints all
   three tabs (الالتزامات / الديون / الحصّالات) on top of each other. Find the root cause
   (tab bodies all built/painted at once) and audit **every** tabbed screen built the
   same way: money goals, travel, body, cinema hall, settings groups, together.
   Add a regression test per tabbed screen: only the selected tab's content is in the tree.
2. **B2 Orbit motion + moons.** Planet motion is not pleasant and **moons never show**.
   Moons are a headline feature of the brief (people around Family, wallets around Money,
   boards around Work, trips around Travel). Find why they do not render with real data
   (data wiring, scale, z-order, culling), fix the orbital motion (speed, easing, spacing,
   drift) and re-render the orbit screenshots.
3. **B3 Back from a planet.** Returning from a planet leaves the home glass panel expanded
   over the screen; back does not restore it and the next back exits the app. Restore the
   sheet to its previous extent on pop; back should collapse the sheet first, then leave
   the planet, and never exit the app from a planet.
4. **B4 The "+" for tasks** only appears for the first task, then disappears.
5. **B5 Reset-view button** → icon only, no text, visible **only** when the orbit is off its
   default (moved / zoomed / rotated), hidden again after reset. Keep the 48 dp target,
   a TalkBack label, and the double-tap-on-empty-sky reset.
6. **Games: cannot leave a game.** A clear exit from any game screen (visible button +
   Android back, with a confirm), and the hall must make unplayable games obviously
   "coming soon" (or hide them) so he never opens an empty show.

---

## Part 2 — Wire the finished system packages  → APK #17

All of these are built, reviewed and tested; they only need routes, settings entries and
startup wiring. Plan: `scratchpad/integration_plan_system.md` + the binding resolutions in
`scratchpad/integration_conflicts.md` (C1–C25). Reports: `scratchpad/phase9_packages.md`.

- **Global search** – route, launcher on the home panel, opener mapping every result type
  to its route (all Life/Money/Faith/Health routes now exist).
- **Notification centre** – route + bell with unread badge, and the **NotificationGate**
  wired exactly as the safety review requires: gate directly around the real plugin inside
  the suspending wrapper, a single gate, the meds background isolate gate +
  `loadStoredNotificationPolicy`, `AdhanEventHub.withholds`, `notificationCenterProvider`
  watched FIRST in AppServices, re-plan hooks per namespace, ids 160000–160999 reserved.
- **Data export + encrypted backup** – Settings › "بياناتك": full JSON, AI-ready summary,
  CSV, encrypted backup, restore flow with the safety copy, `onRestored` re-scheduling.
- **AI chat (own key)** – routes `/ai`, `/ai/chats`, `/settings/ai`, Ask-AI entries on the
  hubs, `AiKeyStore.deleteAll()` in delete-all-data.
- **Home-screen widgets** – `watchWidgetServices`, `clearWidgetData()` in delete-all,
  `/settings/widgets`.
- **Together Mode** – route + settings tile, `togetherTransportOverrides()`, the Nearby
  manifest permissions from `scratchpad/phase10_packages.md`, turn-alert ids 170000–170999,
  Together + specials keys in delete-all.
- Un-skip the Life items deferred to this phase: `ai_summary_life_labels`,
  `search_life_labels`, `life_cohesion`.

---

## Part 3 — The AI bridge: copy/share JSON round trip  → APK #18

Decided by the owner (2026-10-07): **no login**, no mandatory API key. Madar talks to any
AI app (Gemini, ChatGPT, Claude) by handing over a file and taking one back.

1. **Export**: he picks what to send (reuse the data package's per-section chooser); Madar
   produces one JSON **plus a ready prompt** that tells the AI what to analyse and the exact
   answer shape. Share sheet or copy.
2. **Answer**: a "Madar plan" JSON we define – suggested tasks, habits, routines, meal-plan
   changes, budget tweaks, learning programs, reminders, notes; every item carries its reason.
3. **Import**: share/paste back → validate → show every suggestion as a card with its reason →
   he approves / edits / rejects each one → only approved items are applied. Nothing silent.
4. **The approved items become a checkable list** (owner, 2026-10-10, option A of two he
   picked): the items he approves gather under one named plan - his own name, editable - and
   he ticks them off one by one and sees «٢ من ٤». A ticked item is a record of an approved
   suggestion, **not** a row in the home panel's task list; "send this to my tasks" may come
   later as its own action. Example he gave: he sends a month of data, gets 7 suggestions,
   approves 4, and has «خطة تشرين الأول» with ☐ walk 20 minutes after dinner · ☐ check the
   electricity bill · ☐ log your food 5 days running · ☐ call your mother on Friday.
5. **History**: keep applied plans and later show before/after from his own data.
6. Health suggestions stay "track & practise", never diagnosis or treatment.
7. The same import pipe carries the learning-planet JSON (Part 6) and kitchen data (Part 5).
8. The API-key chat stays as an optional shortcut for the same round trip.

---

## Part 3b — Checklists anywhere  ✅ DONE

Owner, 2026-10-10 (option B of the two he picked, pulled forward out of Part 8): a tick-list
inside anything, not only inside an AI plan.

- One shared list engine: a list belongs to a host record (a budget item, a trip, a pantry, a
  custom module, a note), has ordered items with an optional quantity and an optional price,
  and every item ticks and un-ticks with undo. Reuse it everywhere rather than three copies.
- **Shopping list under a budget item** (this was Part 8 / APK #23): «بقالة» → a list he ticks
  as he buys, then turns the ticked part into one transaction on that budget item. Example:
  ☐ رز ☐ زيت ☐ لبن, ticked in the shop, then «٣ أغراض - ٨ د.أ» posted to «بقالة».
- **Packing list on a trip**: ☐ جواز ☐ شاحن ☐ دوا before he travels.
- The kitchen pantry (Part 5) is the same engine with a different host.
- Part 8's #23 keeps only the kanban board; its shopping-list bullet moves here.

**Built**: `lib/features/lists/` on schema v5 (`record_lists`, `record_list_items`), addressed
by the same `(hostTable, hostId)` pair `LifeRecordLinks` resolves, so a new host costs nothing.
Shopping lists under a budget envelope post the ticked part as one transaction through the
ledger's own service, once and only once; trips carry «قوائم ثانية للرحلة» beside their own
packing list; `/lists` is every list grouped by its record, with the orphans last.
**Left for later**: the trip's own `trip_items` packing list is still a second hand-rolled tick
list (migrating it would ripple through Orbit, Import and Search - its own part), and the
list CSV export.

---

## Part 4 — Food, meal plan and chronic conditions  → APK #19

- **Meal plan with times**: "08:00 oats + eggs, 13:00 chicken + rice, 19:00 …", per weekday
  or repeating, a reminder per meal, planned vs actually eaten.
- **Food log**: what he ate, when, portion; quick repeat of frequent meals; from the daily
  chat too (Part 7).
- **Classification + risk rating**: each logged food gets a type and a "how risky for you"
  rating that is **computed from his own chronic conditions and his own rules**, not from a
  medical database: he (or an AI plan from Part 3) defines the rules, e.g. "high salt = bad
  for me", "late caffeine hurts my sleep". Tracking and visualising only.
- **Chronic conditions**: record his conditions with notes, and link everything to them –
  meals, meds, pain, labs, habits, sleep. Condition-aware warnings and local insights
  ("the three worst pain days all followed a late heavy meal"). The existing standing-alerts
  and conditions tables in Health are the base; extend, do not duplicate.
- Fits beside fasting and water on the **Body** planet, with Health cross-links.

---

## Part 5 — The kitchen planet (for his wife)  → APK #20

A new planet named **«السفرة»** (owner's choice, 2026-10-09). No separate lock or private
space: he will simply give his wife her own copy of the app on her phone, so «السفرة» is a
normal planet for both of them (and on her copy it is the one she lives in).

- **Pantry**: what is in the house (item, quantity, unit, expiry, where it is), fast add,
  low-stock marks, and a shopping list that flows into Part 8's budget lists.
- **Dish suggestions from what is available**: match recipes against the pantry, show what is
  missing for near-matches, **never repeat the same dish** within a window she sets.
- **Recipes**: ingredients with quantities, step-by-step method, time, servings, photos she
  adds; her own recipes and imported ones.
- **Constraints**: special requests, allergies, who is eating, time available, diet mode
  (ties into Part 4's meal plan when the owner wants to eat to a plan).
- Offline-first; AI help (new recipes from the pantry) via the Part 3 round trip.
- Simple and fast, and it shows nothing from Health or Money – not for privacy (she gets her
  own copy of the app), but because a kitchen screen should stay a kitchen screen.

**Built (step 1 of 2: the data and the engines)**: `lib/features/sufra/` on schema **v6**
(`pantry_items`, `recipes`, `recipe_ingredients`, `cooked_meals`, `kitchen_rules`). The pantry is
its own table because it is stock, not a tick line (a quantity that goes down, a unit the matcher
computes in, a place, an expiry, a low mark); the **shopping list is Part 3b's engine unchanged**,
on the hosts `('pantry','house')` for the house's standing list and `('recipes', id)` for «ناقص
لهذي الطبخة». Pure engines: `KitchenUnits` (kg↔g and l↔ml only – a cup in grams comes back
*unknown*, never guessed), `PantryBoard` (low / finished / expiring, worst first), `PantryMatcher`
(cookNow / nearly / **unsure** / far, with what is missing and how much), `NoRepeat` (her window,
read off a real cooked log, with her override), `KitchenConstraints` (allergy, avoid, prefer,
request, who is eating, time, and `DietLink` which stays off unless the owner switches
`dietMode` on). The AI bridge's `recipe` and `pantryItem` items **apply** now, through the same
validator and the same `HealthGuard`, and an AI dish is stored with its source so she always knows
it came from an answer and not from her aunt. A fresh install is empty: no bundled recipes.
**Built (step 2 of 2: the world and its screens)**: «السفرة» is the **ninth planet** – seeded
(key `sufra`, pomegranate palette, the `desert` archetype, the fork-and-knife icon, last in the
orbit) and reaching an install that already exists without re-seeding anything else. Its score is
deliberately quiet: `{tasks: 1, activity: 0}`, so a kitchen nobody opened today is **dormant** – a
calm world, off the Neglect Radar and out of the balance – until she files a task under it
herself. Its hub card («سفرة اليوم») sits on the world's page with the four screens under it:
«شو في بالبيت» (the attention list worst first, her places, drag inside a place, every write
undoable), «طبخاتي» + one dish (ingredients judged against the house, her method, her photos –
copied into Madar's own folder and deleted with the dish), «شو نطبخ اليوم» (ready now, nearly,
**the three refusals as honesty with the one tap that fixes each**, held by the window with the
override, and «ممنوعة اليوم» with the word and the person behind it), «محدداتي» (her rules plus
the window, the expiry warning, how many eat and how near is «قريبة») and «اللي طبخناه». Routes
`/sufra/...`, deep links for all five tables through `LifeRecordLinks`, and five search sources
over **her own words** (the ingredient source asks whether there is a line to index before it
reads a single dish name). The diet link stays off.
**Left**: a «السفرة» section of its own in the data export summary – its tables travel in the
backup already and are counted today under «اللي عملته بنفسك»; whether her pantry may go into an
AI summary at all is the owner's call.

---

## Part 6 — "Learn from a source" planets  → APK #21

The owner's idea, in his words: take any source he admires (a doctor's YouTube channel on
OCD, a philosophy channel, a recovery method, a gym programme), extract its method with
Gemini into a JSON file, import it as a new planet, and let Madar turn it into a programme.

- **The JSON format** we define + **a ready prompt** he gives to Gemini with the source link.
  A real worked example from the owner already exists (a metabolic-protocol video he sent on 2026-10-09,
  extracted by hand into `scratchpad/learning_sources/metabolic_protocol.json`): design the format against it –
  it has a model (thesis, drivers, signs), a protocol (avoid / reduce / use / increase / timing / add-ons),
  flagged over-claims, the owner's own additions, and a mapping into Madar (meal plan, habits, avoid list,
  tracked signs, labs, safety). It also shows two things the format must handle: a partial source, and claims
  that must be flagged rather than obeyed.
- **Programme builder**: the import becomes a ladder of levels – daily tasks, exercises,
  quizzes, reflection prompts, interactive practice – with pass criteria per step so the whole
  thing works offline.
- **Daily evaluation**: his results decide the next step (repeat, advance, branch, review).
- **Keeping him going**: streaks, gentle re-entry after a lapse, and the motivation levers he
  chooses himself; never shaming.
- **Safety**: therapy-like topics stay "practise & track" with a gentle note to see a
  professional. No diagnosis, no treatment claims. The content is his own import, on device.
- Each imported source becomes its own planet (the orbit already supports custom planets).

---

## Part 7 — The daily chat as the main input  → APK #22

- One chat where he types everything that happened ("صرفت ٥ دنانير قهوة، صليت العصر بالمسجد،
  تمرين صدر ٤×١٢، وجع الركبة ٦") and Madar **files each piece into the right place**, showing
  what it understood as cards he confirms or corrects.
- "شو صار اليوم؟" – a spoken-language summary of his own day from his own data.
- Builds on the existing quick-add parser (it already understands money, water, tasks,
  relations) – extend it to meals, workouts, pain, prayers, moods, and anything from a custom
  module. Works fully offline; the AI round trip (Part 3) only for the hard sentences.

---

## Part 8 — Module upgrades  → APK #23 and #24

**#23 – Money + Work**
- Shopping lists moved to **Part 3b** (the owner asked for checklists everywhere, sooner).
- **Work: a real workspace with a Trello-style kanban** as the main Work view: columns per
  board, drag cards between columns (the brief asks for drag between kanban columns),
  assignee, due date, Top 3 for today, cards placed into prayer windows.

**#24 – Body / gym, properly**
- An exercise library: per exercise a photo of the machine, a video of the movement (his own
  file or a link), target muscles, notes.
- Sets / reps / weight per set, rest timer between sets, warm-up sets.
- History and progression per exercise (charts, personal bests, suggested next load from his
  own history – tracking, not coaching).
- Workout templates per weekday, and a "today's session" runner that walks set by set.

---

## Part 9 — Faith polish  → APK #25

- **Quran reading themes** independent of the app theme: white page, brown/sepia paper,
  night reading mode; font size and line spacing; keep tajweed colours readable on each.
- **Adhkar notifications** that arrive on time as a heads-up above whatever is on screen,
  with "تم" / dismiss straight from the notification, and the counter resuming in the app.
- **Real adhan audio** – the owner will supply the file himself (decided 2026-10-09): a
  settings flow to pick one or more audio files, assign one per prayer (and a separate
  pre-adhan), preview, and keep them through backup/restore. The procedural tone stays as
  the fallback when no file is chosen.
- **«الإقامة»** (owner, 2026-10-15). Verified in the code first: there is an adhan scheduler
  and a prayer tracker today and **no iqama anywhere**. For each of the five prayers, a
  notification at *adhan + offset*: default **15 minutes**, editable per prayer, **Friday
  Dhuhr with its own offset**, and each one can be switched off on its own. It reads
  «قامت الصلاة» and carries two actions: **«صلّيت»**, which logs that prayer in the existing
  tracker straight from the shade, and **«بعد شوي»**, one snooze. Its own audio file (or the
  procedural tone), and it survives backup and restore the way the adhan's choice does.
  Delivery guarantees are the adhan's, not weaker: the exact minute, a locked screen, Doze,
  and after a reboot.

  **DoD — works**: the five offsets and the Friday one are editable and persist; each prayer's
  iqama can be off while its adhan is on; «صلّيت» writes the same row the tracker's own button
  writes, once, and the notification clears; «بعد شوي» re-arms once and no further; the choice
  of audio and every offset survive a backup and restore; its ids live in their own reserved
  block, not inside the adhan's.
  **DoD — tests**: scheduling at the minute for each prayer and for Friday; an iqama that lands
  after the next adhan (a short offset, or Maghrib to Isha in winter) is never scheduled past
  it; «صلّيت» from the shade with the app dead writes exactly one row (the meds background
  isolate is the pattern); the snooze is once; `NotificationGate` holds it when the Faith
  namespace is muted; restore re-arms it; the DST and the Amman-timezone cases the adhan tests
  already cover.
  **DoD — edge cases**: prayer times that move while a snooze is pending; a prayer already
  logged by hand before the iqama arrives (no second row, and the notification says so); the
  user travelling between time zones; an offset of 0; battery saver and Doze.
  **DoD — blockers**: none - it builds on the adhan scheduler, the tracker and the gate, all
  of which exist and are tested.
- Re-check the brief's adhan guarantees on a real device: exact minute, locked screen, after
  reboot, Doze and battery saver - and the iqama firing its own number of minutes later.

---

## Part 10 — The rest of Madar Cinema

**#26 – the three remaining Tier 1 games**: Caravan Dash (partly built, on disk),
Noir Rooftops, Neon Souk Racer. Same pattern as the first two: build → art-director critic.

**#27 … #35 – Tier 2 games in batches of 5**, an APK per batch. The rules engines are all
written and tested; what is left is the hand-inked look, the animation and the HUD for each:
- Cards: Tarneeb, Tarneeb 41, Trix, Trix Complex, Hand, Konkan, Basra, Baloot, Solitaire,
  Blackjack 21 – with animated table characters and the three AI levels that already exist.
- Board: Chess, Dama (Jordanian), Tawla (Shesh Besh / Mahbusa / 31), Dominoes, Ludo,
  Mancala, Four in a Row, Tic-tac-toe.
- Puzzles: 2048, Sudoku, Minesweeper, Falling Blocks, Souk Jewels, Sliding Tiles, Nonogram,
  Mahjong Solitaire, Star Memory, Pipe Connect, Tangram, Lights Out.
- Words: Arabic Crossword, Arabic Word Search, Arabic Word Guess, Islamic Quiz,
  Capitals & Flags, Arabic Typing Race.
- Arcade: Snake, Brick Breaker, Star Hunter, Asteroid Belt, Paddle Duel, Stack Tower,
  Fruit Slice, Sky Jumper, Maze Chase, Road Crossing, Pinball.

**Decided:** the name "Flappy Orbit" / «رفرفة المدار» stays as it is (owner, 2026-10-09).

---

## Part 11 — Together Mode, the two-player games  → APK #36 and #37

The mode itself (profiles, Hall of Fame, pass-and-play hand-off, split-screen, Nearby,
optional online, the couple specials) is built and gets wired in Part 2.

**#36 – turn-based together**: Tarneeb and Trix as partners or rivals, Basra, Konkan,
Backgammon, Chess, Dominoes, Ludo, Four in a Row, Arabic Word Guess duel, Islamic Quiz duel,
plus **Draw & Guess** and **Mini Golf** (not built yet).

**#37 – real-time together**: Air Hockey, Snowball Fight, Tank Duel, Paddle Duel, and the
co-op mode for Metropolis Machine; then **Beach Volley Duo** and **Kart Dash** – the brief
asks for stylised low-poly 3D in an embedded offline three.js WebView bridged to the app for
input, scores and networking (original characters and courts only).

---

## Part 13 — «التسميع»: recitation checked on the phone  → its own APK

Owner, 2026-10-15. Verified in the code first: recitation today is **listening only**
(EveryAyah playback, `lib/features/recitation/`), there is **no speech recognition, no
microphone permission and no checking** of what he recites. Hifz and wird exist
(`lib/features/wird/`).

The feature set he asked for, built as Madar's own design - **nothing copied from Tarteel's
app**, only the same job done:
- Follows his voice **verse by verse in real time** while he recites.
- Flags **wrong words, missed words and extra words**, each against the exact text.
- A **memorisation mode** that hides the verses and reveals each one as he recites it
  correctly.
- **Fill in the blank**.
- A **log of his past mistakes**, and progress statistics over time.

How: **on-device Quranic speech recognition** - an open model trained on recitation, whose
licence is checked and credited before a line of code depends on it - aligned to the **exact
Uthmani text of the app's own verified Quran data**, offline. **Hafs first.** Pronunciation
detail (makharij) is deliberately **not** in this part; it goes to a later one.

**DoD — works**: he presses record, recites, and the current verse advances as he goes, with
each word marked right / wrong / missed / extra against the Uthmani text; the hiding mode
reveals a verse only on a correct recitation of it; fill-in-the-blank scores the blank only;
every mistake is written to his own log with the verse, the word and the date; the stats read
off that log; it all works in flight mode; the microphone is used only while he is reciting
and **no audio and no transcript ever leave the phone**.
**DoD — tests**: alignment over recorded fixtures (a clean recitation, a dropped word, an
inserted word, a wrong word, a restart mid-verse, a long pause, and a verse recited twice);
the same ayah in both Uthmani and simple spelling resolves to one verse; the hiding mode's
reveal is driven by the alignment, not by a timer; the log and the stats round-trip through
the database and the backup; a denied microphone permission degrades to reading, never a
crash; a licence test asserts the model's licence file ships and is credited in the About
screen.
**DoD — edge cases**: background noise and a second voice; a basmala before every surah;
sajda verses; stopping mid-verse and resuming; a phone that cannot run the recogniser (it must
say so plainly and keep listening-only working); very long verses (البقرة ٢٨٢) and memory.
**DoD — blockers**: (1) an open recitation-trained model with a licence that permits shipping
- this gates the whole part and must be settled before it starts; (2) `RECORD_AUDIO` and its
rationale; (3) the verified Uthmani text with word-level offsets, which the Quran data must
expose.

### The owner's spec, 2026-10-15 (Tarteel's Play Store page as the bar)

He sent Tarteel's page as the standard to match. **Tarteel needs internet; Madar must not** -
the speech recognition and every model stay on the phone. His numbering: this is his
**«Part 2»**; in this plan it is Part 13.

1. **Recite-to-find — «شازام القرآن»**: he recites any phrase and Madar names the surah and
   the ayah, **offline**. Pipeline: ASR → normalised text → an n-gram index over the verified
   text.
2. **Hidden-verse mode**: the page is hidden and the words appear as he recites them. He can
   **tap to peek** a word, and **a peek is counted as a hint** (so the strength in Part 14 is
   honest).
3. **Live mistakes at word level**: wrong · skipped · extra, highlighted **on the verified
   text**. **Tashkeel errors are experimental, labelled as such, and off by default.**
4. **Live correction**: tapping a highlight shows **«اللي سمعه التطبيق منك»** beside the
   verified ayah. The recogniser's output is shown **only** as "what was heard" and is **never
   styled as Quran text** - different type, different colour, and labelled.
5. **Mushaf**: Madani (Hafs) pages, with an option to **hide the ayah markers** while testing
   himself. Indo-Pak script: 🧊 (not now).
6. **Listening**: licensed reciters, **downloaded per reciter for offline use**, follow-along
   highlighting (**word timings only from a licensed source**), and background play.

**Engine (shared with Part 14)**
- Part 13 brings **its own recitation ASR**: an open model **trained on Quranic recitation**,
  run on the phone (e.g. a Quran-tuned Whisper through whisper.cpp) - **its licence verified
  before a line of code depends on it**. A general model is **not** used for scoring, Gemma
  included; Gemma stays for Part 15's other uses.
- **Audio never leaves the phone**, and a recording is **deleted after scoring** unless he
  chooses to keep it.
- The **mistakes log and the goals are exportable as documented JSON**, so the PC app «فلك»
  can read them later. Syncing between them is a later phase, not this one.
- **Part 16 (the kids section) reuses this engine** for Juz' 30, with the material signed off
  by the reviewer the owner names.

**Risks he named, and what is done about them**
- ⚠️ A general ASR mishears recitation and invents mistakes. 🔧 A Quran-specific model, and
  **the result is a hint for him, never a ruling**: the wording on screen must say so.
- ⚠️ Tashkeel detection is unreliable. 🔧 **Word level first**; tashkeel stays experimental,
  labelled, and off until it earns its place.

---

## Part 14 — «الحفظ»: memorisation at full strength  → its own APK

Owner, 2026-10-15: the memorisation **methods, as modes** he can choose between, on top of the
Hifz tracking that already exists.

- **Listen and repeat**: a verse or a range played N times with a pause between, the reciter
  of his choice.
- **Chunking**: verse → group of verses → page.
- **Progressive hiding**: the full text → first letters only → hidden.
- **Fill in the blank.**
- **Writing from memory** and comparing against the text.
- **Linking**: the end of each verse to the start of the next.
- **Reciting it** through Part 13's checker.

And a **daily plan**: a new portion + **near review** (the last seven days) + **far review**
(rotating through everything he has memorised), spaced by how strong each piece is, with a
**page map coloured by strength**. **Missed days never pile up past a cap** - a week away must
not return a wall of four hundred verses.

**DoD — works**: each mode runs on a chosen range and records what happened; the daily plan
produces today's three portions from his own strength data; strength rises and falls from real
results (Part 13's checks, the hiding mode, the blanks), never from opening a screen; the page
map's colours come from the same numbers; after days away the backlog is capped and he is told
what was dropped rather than it vanishing silently; everything is offline.
**DoD — tests**: the scheduler at the boundaries (nothing memorised; one page; the whole
mushaf); the cap after 1, 7 and 60 missed days; strength up after a clean recitation and down
after a failed one; near review never repeats the same verse twice in a day; far review covers
everything over its cycle; the plan is deterministic for the same data and clock; the page map
matches the strengths; every mode's state survives a backup and restore.
**DoD — edge cases**: a range that crosses a surah or a juz'; a verse he marks as "not mine to
review"; resetting a page's strength; a reciter whose audio is not downloaded; the plan on the
day he first starts.
**DoD — blockers**: Part 13 for the reciting mode (the other modes must work without it, so
Part 14 does not stall if 13 slips).

### The owner's spec, 2026-10-15 (his «Part 3»; Part 14 here)

7. **A mistakes log per word and per ayah** → a **weak-spots list** → a **spaced review
   queue** built from it. The log is the one in Part 13, read from the other side.
8. **Three tracks**: **new** · **recent** (the last seven days) · **old** - with a
   **repetition count per ayah**, and **each ayah linked to the one before it** (so the join
   is practised, not only the verse).
9. **Smart goals**, in his words: «الكهف كل جمعة» · «راجع جزء عمّ» · «N صفحات باليوم» - with
   **reminders tied to the prayer times**, not to a clock alone.
10. **Progress**: **streaks** and a **heatmap of strength per surah and ayah**.

Exportable as documented JSON with Part 13's log, for «فلك» later.

---

## Part 15 — «الموديل على الجوال»: the model on his phone  → its own APK

Owner, 2026-10-15, asked for **all of it on device**: understanding what he types in the daily
chat offline, writing the day's summary, and answering questions about his own data - with
nothing leaving the phone. Verified in the code first: there is **no on-device model today**;
there is the API-key chat and Part 3's file round trip.

His phone: **Samsung Galaxy S26 Ultra**. The path, in his order:
1. **Gemma 4 (E2B fast / E4B full) through the ML Kit Prompt API on AICore** - a developer
   preview on supported phones, where the weights belong to the system and not to the APK.
   Check this on his phone first.
2. **If AICore cannot serve it**, run the model inside the app (Google AI Edge: MediaPipe /
   LiteRT), the weights as an **optional download**, never bundled into the APK.
3. **If that is too heavy**, fall back to the existing Part 3 AI bridge - which already works
   and stays the path on every phone that cannot run a model.

The settings screen **says plainly what this phone can run**, and the choice is his.

**The religious rule is absolute**: the model **never gives a religious ruling**, and **never
quotes a verse or a hadith from its own memory**. Religious text reaches the screen only from
the app's verified data, and a hadith always with its source and its grading.

**DoD — works**: a capability check names which of the three paths this phone gets, with a
reason he can read; the daily chat's hard sentences and «شو صار اليوم؟» and questions about his
own data all run through whichever path is active, with identical behaviour from his side; the
offline parser of Part 7 stays the **first** reader and the model only takes what it could not
read; nothing is written without his confirmation; `HealthGuard` still refuses a dose or a
diagnosis; the download is optional, resumable, and removable, and the app is fully usable
without it.
**DoD — tests**: the capability check on a phone with AICore, without it, and with too little
memory, each choosing the right path; a fake model that returns a verse is **refused** by a
guard and the refusal is tested; no network call on any on-device path (the same transport
assertion Part 2 uses); the fallback to the AI bridge when the model fails mid-answer;
cancelling a download; measured first-token, tokens a second, memory and battery recorded on
the real device and written into the part.
**DoD — edge cases**: another app taking the memory mid-answer; the phone heating; a preview
API changing under us (it is a developer preview - pin and feature-detect, never assume);
airplane mode; a very long day's chat.
**DoD — blockers**: the ML Kit Prompt API is a **developer preview** and may not be available
on his phone at all - that is what step 1 measures; and the decision between paths must be made
on the real device, not from documentation.

---

## Part 16 — «مدار الصغار»: a kids section  → its own APK

Owner, 2026-10-15: **a section inside Madar behind a lock, not a separate app**, for a
**nine-year-old who reads Arabic**. Verified in the code first: there is **no kids version
today**.

**The lock is one-way.** Entering is one tap. **Leaving needs his PIN or fingerprint.** From
inside, nothing else in Madar is reachable - not money, not health, not the chats, not
settings, not the notification centre. It is built as **its own shell**, not a screen inside
the app's navigation, so there is no back door through a deep link, a notification tap or the
recents list. **Android app pinning** is offered when he enters, with one line saying what it
does, so the child cannot leave Madar at all. **Screen time**: a limit he sets, and what
happens when it runs out.

**What is in it**, at that age: **Quran** - the short surahs, listened to with the word
highlighted, and a kid-level recitation check borrowed from Part 13; **prayer and wudu**, step
by step; **the prophets' stories**; **manners**; **Arabic letters**; **maths** for a
nine-year-old (multiplication, division, simple fractions); **colouring**; **games** on the
existing Cinema engine; and **rewards**.

**No free chat with a model**, ever: any model use inside the kids section is **scripted over
verified content only** - never an open prompt, never a generated answer to a child's
question. **Verified sources only**, and **every religious item is signed off by a reviewer the
owner names, before release**. **No ads, no accounts, nothing leaves the device.** **A design
is approved by the owner before any screen is built.**

**DoD — works**: entering is one tap and leaving demands the PIN or the fingerprint every
time; from inside, no deep link, notification tap, back gesture or recents entry reaches the
rest of Madar; app pinning is offered and explained; the screen-time limit is enforced and ends
gently; every section above is present and usable by a nine-year-old reading Arabic; rewards
are recorded on the device; there is no network call at all from inside the section.
**DoD — tests**: an escape-hatch suite that tries every way out - every route in the app pushed
while the section is open, a notification tap, a share intent, the back button held, and the
app killed and relaunched - and asserts it lands back inside the kids shell or at the PIN;
the PIN and the fingerprint both unlock and a wrong PIN does not; the screen-time limit at its
boundary and across midnight; no transport is ever called; a content test asserts every
religious item carries its verified source and its reviewer sign-off field, and that the build
fails if one does not.
**DoD — edge cases**: the child tapping a notification that arrives while the section is open;
a phone call during a lesson; the owner's fingerprint not enrolled (PIN only); the battery
dying mid-reward; a child who cannot yet read a word of a question.
**DoD — blockers**: (1) the **reviewer the owner names** for the religious content - nothing
religious ships unreviewed; (2) the **design approval** before any screen is built; (3)
Part 13 for the kid-level recitation check (the rest must work without it).

---

## Part 12 — Polish, performance, delivery  → final APK

**Known performance debt (2026-10-14).** The first search of a session blocks the UI isolate
for 73-130 ms over a 57k-document fixture - one hiccup, then typing is 3-39 ms. Its test
budget was recalibrated from 100 ms to 200 ms with the measurements written into the test.
Two fixes were tried and both made it worse (a smaller index page; a smaller isolate chunk),
which says the cost is fixed rather than per-chunk - most likely the isolate spawn or a major
GC over the documents the warm-up allocates. Fixing it properly needs an allocation profile,
not another constant.

- **«السما»** (owner, 2026-10-15): a complete upgrade of the sky - the motion of the planets,
  and the universe and the galaxies behind everything. **Depth layers**: a parallax star field
  built from the **real catalog already in the app** (`lib/features/orbit/render/sky/`),
  nebulae, a slow galactic drift, and the planets on **eased** orbits rather than constant
  ones. The orrery was re-laid out on 2026-10-14 so ten worlds sit evenly and nothing is
  clipped, at the cost of the system and the dial being 13% smaller; this is where that is paid
  back, by opening the orbit ellipses (camera elevation) or the dial (`coreRadius`) rather than
  the band. **A visual reference is approved by the owner before any of it is built.**

  **DoD — works**: the layers move at different rates with the camera and read as depth, not as
  wallpaper; the star field is the real catalog, not noise; **60 fps** on a mid-range phone
  while he drags, **30 fps** when the sky is idle, and a **still image in battery saver**;
  reduced motion is respected; nothing is clipped at any world count, which the orrery tests
  already assert and must keep asserting.
  **DoD — tests**: the frame budget measured in the existing perf harness at 1, 10 and 16
  worlds; the battery-saver still and the idle rate asserted, not assumed; the layout
  invariants from 2026-10-14 all still pass; screenshots in every theme and both languages,
  looked at.
  **DoD — edge cases**: a weak GPU; the app resuming from background mid-drift; a very long
  session (no leak in the layers); text scale 1.3 over the new depth.
  **DoD — blockers**: the owner's approval of a visual reference first.
- The brief's remaining visual promises: Rive state-machine icons and mascots that react to
  touch, and an animated illustration for every empty state (today they are static).
- Performance pass on a real device: 60 fps everywhere on a mid-range phone, 120 Hz where
  supported, fly-in/out under 800 ms, no shader jank, orbit idling at 30 fps, battery-saver
  stills, memory over long sessions.
- Device checks that only a phone can prove: adhan on a locked screen after reboot with
  battery saver, medication timing rules, widgets updating, Nearby pairing between two
  phones, the WebView games, fingerprint, notification actions from the shade.
- Accessibility sweep: TalkBack labels, 48 dp targets, text scale 1.3 on every screen.
- Final deliverables from the brief: the signed APK, keystore instructions, the README
  (build steps, architecture, data sources, import format, Firebase setup for online mode),
  and the full feature checklist.
- Delete `.resume/` and fold anything still useful into the README.

---

## The order the owner set (2026-10-15)

**His numbering vs this plan's** (he counts the remaining parts from one; the plan keeps its
original numbers): his Part 1 = the iqama, inside **Part 9** · his Part 2 = **Part 13
«التسميع»** · his Part 3 = **Part 14 «الحفظ»** · his Part 4 = **Part 15** (the model on the
phone) · his Part 5 = **Part 16 «مدار الصغار»**.


After Part 7 ships: **9 (with «الإقامة») → 13 «التسميع» → 14 «الحفظ» → 15 «الموديل على
الجوال» → 16 «مدار الصغار»**. The remaining life and games parts (**6, 8, 10, 11**) come
after those, and **Part 12 (with «السما») stays last**, unless he reorders.

*(His note listed Part 4 among the remaining ones; Part 4 shipped as APK #19 on 2026-10-10,
so it is left out here. Flagged to him rather than quietly corrected.)*

---

## Open questions waiting on the owner

Three, all of them gates on parts that cannot start without him:

1. **A reviewer for «مدار الصغار»'s religious content** - he names the person who signs off
   the Quran, prayer, wudu, stories and manners material. Nothing religious ships unreviewed.
2. **The design of «مدار الصغار»** - he approves a design before any screen of it is built
   (his words: artistic and beautiful).
3. **A visual reference for «السما»** - he approves one before the sky is rebuilt.

Answered on 2026-10-15 and no longer open: the kids version is **a locked section inside
Madar, not a separate app**, for a **nine-year-old**; the on-device model does **all of it**
(the daily chat, the day's summary, questions about his own data) on a **Samsung Galaxy S26
Ultra**, trying AICore first; and the **order** of the parts is approved (below).

Everything decided before that:

- "Flappy Orbit" / «رفرفة المدار» keeps its name.
- The kitchen planet is **«السفرة»**, with no separate lock – his wife gets her own copy of
  the app on her phone.
- Adhan audio: he supplies the file himself; the procedural tone stays as the fallback.
- AI link: the copy/share JSON round trip, no login; the API key stays optional.
- Card and board games: Jordanian rules; all nine proposed defaults accepted.
- EveryAyah recitations: approved (stream on play / download on request, credited).
- **Kids (2026-10-15)**: a locked section inside Madar, not a separate app; age nine; leaving
  needs his PIN or fingerprint; Android app pinning offered; no free chat with a model there.
- **The model on his phone (2026-10-15)**: all of it on device - the daily chat, the day's
  summary and questions about his own data - trying Gemma 4 through AICore on the S26 Ultra
  first, then Google AI Edge inside the app, then the existing AI bridge as the fallback.

Note for a later part: since his wife runs her own copy, two things are worth asking when we
get there – whether «السفرة» should sync pantry and recipes between the two copies through
Together Mode's existing link, and whether her copy should start with the other planets
hidden.
