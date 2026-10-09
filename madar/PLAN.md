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
4. **History**: keep applied plans and later show before/after from his own data.
5. Health suggestions stay "track & practise", never diagnosis or treatment.
6. The same import pipe carries the learning-planet JSON (Part 6) and kitchen data (Part 5).
7. The API-key chat stays as an optional shortcut for the same round trip.

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

A new planet, Arabic name to confirm with the owner («المطبخ» / «السفرة» / «المونة»).

- **Pantry**: what is in the house (item, quantity, unit, expiry, where it is), fast add,
  low-stock marks, and a shopping list that flows into Part 8's budget lists.
- **Dish suggestions from what is available**: match recipes against the pantry, show what is
  missing for near-matches, **never repeat the same dish** within a window she sets.
- **Recipes**: ingredients with quantities, step-by-step method, time, servings, photos she
  adds; her own recipes and imported ones.
- **Constraints**: special requests, allergies, who is eating, time available, diet mode
  (ties into Part 4's meal plan when the owner wants to eat to a plan).
- Offline-first; AI help (new recipes from the pantry) via the Part 3 round trip.
- Her own space inside the app: simple, fast, and nothing from his health or money data.

---

## Part 6 — "Learn from a source" planets  → APK #21

The owner's idea, in his words: take any source he admires (a doctor's YouTube channel on
OCD, a philosophy channel, a recovery method, a gym programme), extract its method with
Gemini into a JSON file, import it as a new planet, and let Madar turn it into a programme.

- **The JSON format** we define + **a ready prompt** he gives to Gemini with the source link.
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
- **Shopping lists under a budget item**: e.g. "بقالة" → a list (item, qty, optional price),
  tick as you buy, then turn the ticked list into one transaction on that budget item.
  Shares the list engine with the kitchen pantry (Part 5).
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
- Re-check the brief's adhan guarantees on a real device: exact minute, locked screen, after
  reboot, Doze and battery saver.

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

**Open question for the owner:** the name "Flappy Orbit" echoes "Flappy Bird"
(A keep / B "Orbit Flutter" / C a new name).

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

## Part 12 — Polish, performance, delivery  → final APK

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

## Open questions waiting on the owner

| # | Question | Options |
|---|---|---|
| 1 | The name "Flappy Orbit" (echoes "Flappy Bird") | A keep · B "Orbit Flutter" · C a new name |
| 2 | The kitchen planet's Arabic name | «المطبخ» · «السفرة» · «المونة» · his own |
| 3 | Does the kitchen planet need its own simple lock/space for his wife? | yes · no |

**Decided already:** adhan audio = he supplies the file (A). AI link = copy/share JSON round
trip, no login. Card and board games = Jordanian rules, all nine defaults accepted.
EveryAyah recitations = approved.
