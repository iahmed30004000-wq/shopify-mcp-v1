# R0 — the before-picture of Madar (facts only)

Snapshot: 2026-11-10, branch HEAD `2d59b96` plus a working tree whose routing, home, orbit and settings files are unchanged
(only ARB/l10n, three tests and new un-wired folders differ: `features/today`, `guide`, `ramadan`, `reading`, `hajj`, `fasting`).
Everything below was read from the code; each fact has a `path:line` (paths are relative to `madar/`).
The only judgement calls are the columns/sections explicitly named **Proposed**. No screenshots were taken (this pass is read-only analysis).

**How taps are counted** (so R-P2's test can use the same rule): Today (`/`, `lib/features/home/home_screen.dart`) = 0 taps.
A tap on the item that opens the next screen/sheet = +1. Typing, picking a value and scrolling are **not** counted. "To finish" adds the one tap that
commits the action (Save / Taken / «صلّيت»). Cards lower in a planet page need a scroll first; the planet sheet starts at 45.5 % of the screen height
(`lib/features/orbit/presentation/scene/scene_composition.dart:108`), so about 54 % of a planet page is visible before scrolling.

---

## A. Every route

**Totals.** `AppRoutes` declares 101 string constants (`lib/core/routing/routes.dart`, lines 7–537; `prayerTrackerHistory` at :37 is a variant of `prayerTracker`).
`madarRoutes()` registers **102 `GoRoute`s** (`lib/core/routing/router.dart:101-978`; 100 real screens + the two redirect-only stubs `/food` :646 and `/sufra` :690).
**18 of them are settings routes** (`/settings` + 17 children, router.dart:107-257). All are nested under `/` except `/onboarding` (router.dart:973), so `context.go` always leaves home underneath.
Only redirect rules: `onboardingRedirect` (routes.dart:557-563, wired at router.dart:58-59), `/food`→`/food/library` (:647), `/sufra`→`/sufra/tonight` (:691), `/adhkar/:set` with an unknown set → `/adhkar` (:291-292), `/settings/recitation/downloads` with an unknown reciter → `/settings/recitation` (:183-185); `onException` sends anything unmatched to `/` (:60).
Registration: `router.dart` (tree) + `route_pages.dart` (Faith + settings-for-faith pages), `health_route_pages.dart`, `money_route_pages.dart`, `life_route_pages.dart` (life, kitchen, lists, trackers), `system_route_pages.dart` (daily chat, search, notifications, data, plans, AI, Together), `cinema_route_pages.dart` (games helpers only; its three routes are wired directly in router.dart:785-799, 847-854).
Planet pages are not a normal page: `/planet/:key` builds `PlanetRoutePage`, a transparent route over home whose animation drives the orrery fly-in (`lib/features/orbit/presentation/planet/planet_route.dart:12-76`; router.dart:952-961).

**Planets today are 10** (`lib/core/db/seed/defaults.dart:130-263`): faith, health, family, work, money, growth, body, travel, sufra, games (`games` has `weight: 0` — never counted, never on the radar, :257-263).

**Entry-point legend.** `Home` = `home_screen.dart`. `PP` = a tile/card on that planet's page (`planet_page.dart`, hubs in `faith_hub.dart`, `life_hubs.dart`, `health/hub/health_hub.dart`, `money/hub/money_hub.dart`).
"Taps" = minimum taps from Today. **UNREACHABLE** = no UI element navigates there; only links/search/notifications can (none of the 100 screens is fully unreachable except `/lists`, see below).

### A.1 Shell, settings (group: settings / system)

| Pattern | Screen | Group | How a user reaches it today (entry point) | Taps |
|---|---|---|---|---|
| `/` | `HomeScreen` (router.dart:104-105) | system | app start; back from everything | 0 |
| `/onboarding` | `OnboardingScreen`, 6 steps (onboarding_screen.dart:48-51) | system | forced by `onboardingRedirect` until `onboarded` (routes.dart:557-563); exit `home` or `import` (onboarding_screen.dart:24) | first run |
| `/settings` | `SettingsScreen` (settings_screen.dart:48) | settings | Home header ⚙ icon `home_screen.dart:519-524` (`context.go`) | 1 |
| `/settings/appearance` | `AppearanceScreen` | settings | Settings tile `settings_screen.dart:87` | 2 |
| `/settings/sound` | `SoundSettingsScreen` | settings | Settings tile `:94` | 2 |
| `/settings/licenses` | `LicensesScreen` — this is the *fonts & sources* credits page, not the OSS licence list (that is Flutter's `showLicensePage`, :236-239) | settings | Settings › About tile `:229` | 2 |
| `/settings/prayer` | `PrayerSettingsScreen` | settings (faith) | Settings tile `:109`; gear button in `/prayer-times` (`prayer_times_screen.dart:331`, `route_pages.dart:95`) | 2 |
| `/settings/adhan` | `AdhanSettingsScreen` | settings (faith) | Settings tile `:116`; **Faith page tool tile «الأذان»** `faith_hub.dart:304`; notification-centre group link `app/system_services.dart:119-121` | 2 |
| `/settings/iqama` | `IqamaSettingsScreen` | settings (faith) | Settings tile `:123`; notification-centre link (system_services.dart:119-121) | 2 |
| `/settings/security` | `SecuritySettingsScreen` | settings | Settings › Privacy tile `:209` | 2 |
| `/settings/quran` | `QuranSettingsScreen` | settings (faith) | Settings tile `:131` only (the reader has its own *sheet*, `quran_reader_screen.dart:339`) | 2 |
| `/settings/recitation` | `RecitationSettingsScreen` | settings (faith) | Settings tile `:138`; **Faith tool tile** `faith_hub.dart:301`; Quran settings row | 2 |
| `/settings/recitation/downloads?reciter=` | `RecitationDownloadsScreen` (route_pages.dart:309) | settings (faith) | recitation settings → a reciter (`app/faith_services.dart`, `FaithNav.recitationDownloads`) | 3 |
| `/settings/reminders` | `RemindersSettingsScreen` (adhkar + wird sections) | settings (faith) | Settings tile `:145`; notification-centre links `system_services.dart:122-124` | 2 |
| `/settings/health` | `HealthSettingsScreen` | settings (health) | Settings tile `:164`; centre links `system_services.dart:126,135`. `HealthNav.settings` (health_route_pages.dart:37) has **no caller** | 2 |
| `/settings/notifications` | `NotificationSettingsSummary` page (system_route_pages.dart:169-181) | settings | Settings › Notifications row `system_settings_sections.dart:79` | 2 |
| `/settings/data` | `DataCentreScreen` (system_route_pages.dart:193) | settings | Settings › Your data row `system_settings_sections.dart:205` — **only door** | 2 |
| `/settings/data/restore` | `RestoreFlow` (system_route_pages.dart:208) | settings | Data centre restore card `data_centre_screen.dart:207` | 3 |
| `/settings/ai` | `AiSettingsScreen` | settings | Settings › AI row `system_settings_sections.dart:163`; app-bar/gear inside the AI chat (`system_route_pages.dart:283,301`) | 2 |
| `/settings/widgets` | `WidgetsSettingsScreen` | settings | Settings › Widgets row `system_settings_sections.dart:101` — **only door** | 2 |
| `/import` | `ImportScreen` (sheet-rise transition, router.dart:947-950) | system | Settings › Your data tile `system_settings_sections.dart:213`; Data centre tile `data_centre_screen.dart:303`; onboarding exit `import` (onboarding_screen.dart:24) | 2 (first run: 0) |
| `/gallery` | `DesignGalleryScreen` | system | Settings › **Developer** section tile `settings_screen.dart:243-253`, shown to everyone (no debug guard) | 2 |

### A.2 Faith (group: faith)

| Pattern | Screen | Entry point | Taps |
|---|---|---|---|
| `/prayer-times` | `PrayerTimesScreen` (route_pages.dart:95) | **Home date line** `home_screen.dart:481-484`; panel chip «كل الأوقات» `task_panel.dart:84`; `NextPrayerCard` `faith_hub.dart:163`; prayer sheet footer `prayer_sheet.dart:134`; widget (G); centre «adhan» rows `system_services.dart:107-108` | 1 |
| `/prayer-tracker[?tab=history]` | `PrayerTrackerScreen` (route_pages.dart:110) | `PrayerTodayCard` header `faith_hub.dart:81`; prayer sheet footer `prayer_sheet.dart:145`; FaithTools «سجلّ الصلاة» (history tab) `faith_hub.dart:303`; iqama body tap (G) | 2 |
| `/adhkar` | `AdhkarHomeScreen` (route_pages.dart:119) | `AdhkarTodayCard` header `faith_hub.dart:82` | 2 |
| `/adhkar/tasbeeh` | `TasbeehScreen` (router.dart:281-288) | `AdhkarTodayCard` tile `adhkar_today_card.dart:128-129`; FaithTools tile `faith_hub.dart:302`; adhkar home | 2 |
| `/adhkar/:set[?prayer=]` | `AdhkarReaderScreen` (route_pages.dart:146); sets: morning, evening, afterPrayer, sleep, waking (`adhkar_models.dart:6-11`) | `AdhkarTodayCard` mini-set `adhkar_today_card.dart:107`; adhkar reminder tap (G) | 2 |
| `/quran` | `QuranHomeScreen` (route_pages.dart:161) | Faith header «الفهرس» `faith_hub.dart:85-88`; FaithTools mushaf tile `:299` | 2 |
| `/quran/read[?ayah=|?page=]` | `QuranReaderScreen` (route_pages.dart:187) | `QuranContinueCard` `faith_hub.dart:89` (+ `quran_continue_card.dart:42-44`); wird «اقرأ الآن» (`faith_services.dart`); search results; bookmarks | 2 |
| `/quran/search[?q=]` | `QuranSearchScreen` (route_pages.dart:199) | Quran home search | 3 |
| `/wird[?plan=]` | `WirdScreen` (route_pages.dart:215) | `WirdTodayCard` `faith_hub.dart:90`; wird reminder tap (G); search `wird_plans` | 2 |
| `/hifz` | `HifzScreen` (route_pages.dart:224) | FaithTools Hifz tile `faith_hub.dart:300`; `HifzTodayCard` header `:95-99` (only once something is memorised) | 2 |
| `/hifz/plan` | `HifzPlanScreen` (route_pages.dart:261) | `HifzPlanTodayCard` `faith_hub.dart:93` | 2 |
| `/hifz/plan/map`, `/hifz/plan/goals`, `/hifz/find[?q=]` | `HifzMapScreen`, `HifzGoalsScreen`, `HifzFindScreen` (route_pages.dart:269,277,288) | buttons on the plan screen `hifz_plan_screen.dart:63,71,79` | 3 |
| `/hifz/review[?card=]` | `HifzReviewScreen` (route_pages.dart:250) | `HifzTodayCard` «ابدأ المراجعة» `faith_hub.dart:97-98`; Hifz screen | 2–3 |
| `/qibla` | `QiblaScreen` (router.dart:393-401, scaled-axis zoom) | `QiblaCard` `faith_hub.dart:104` | 2 |
| `/now-playing` | `NowPlayingSheetPage` (router.dart:943-945) | mini player on home `home_screen.dart:422`; Quran pages' `NowPlayingDock`; recitation media-notification click `faith_services.dart:76-90` | 1 (only while audio plays) |

### A.3 Health (group: health) and Body/Food (group: life — planet «الجسد»)

| Pattern | Screen | Entry point | Taps |
|---|---|---|---|
| `/meds[?tab=meds|courses]` | `MedsScreen` (health_route_pages.dart:79) | `TodayDosesCard` `health_hub.dart:100`; tool «الأدوية» (tab=meds) `:463-467`; dose notification (G); widget (G) | 2 |
| `/record[?tab=labs|appointments|questions|conditions]` | `RecordScreen` (:92) | Health header «السجل» `health_hub.dart:109`; tool «التحاليل» `:469`; `LabFlagsCard` `:112` | 2 |
| `/record/appointments[?highlight=]` | `AppointmentsScreen` (:113) | tool `:470-475`; `NextAppointmentCard`; appointment reminder tap (G) | 2 |
| `/record/lab/:id` | `LabTestScreen` (:103) | record screen rows via `RoutedRecordNavigation` (health_route_pages.dart:48-50) | 3 |
| `/wellbeing[?tab=pain|habits|worries|insights]` | `WellbeingScreen` (:130) | `WellbeingTodayCard` `health_hub.dart:101-105`; tool `:476`; worry-window tap (G) | 2 |
| `/wellbeing/breathing[?pattern=]` | `BreathingScreen` (:155) | `WellbeingTodayCard.onBreathe` `:104`; tool `:477` | 2 |
| `/body[?tab=plan|fasting|water|avoid|food]` | `BodyScreen`, 6 tabs: today, food, plan, fasting, water, avoid (body_screen.dart:19) | Body page `BodyTodayCard` `life_hubs.dart:231`; `NutritionTodayCard` (food tab) `:232`; tools «الخطة» (plan) / «تجنّب» (avoid) `:237-249`; **fasting and water tabs have no hub tile** (reachable via the tab bar, Settings › Life `life_settings_section.dart:64`, fasting notification G) | 2 (tab via card/tile) / 3 (fasting, water) |
| `/body/gym/session` | `GymSessionScreen` (life_route_pages.dart:550) | «ابدأ الجلسة» button `body/presentation/tabs/today_tab.dart:50-58` and `plan_tab.dart:53-60` | 3 |
| `/body/gym/days` | `GymTemplatesScreen` (:558) | plan tab button `plan_tab.dart:62-70` | 3 |
| `/body/gym/exercise/:id` | `GymExerciseScreen` (:569) | plan tab list `plan_tab.dart:259` | 3 |
| `/food` | **redirect only** → `/food/library` (router.dart:646-648) | none (links) | — |
| `/food/library`, `/food/plan`, `/food/rules`, `/food/insights` | `FoodLibraryScreen`, `MealPlanScreen`, `ConditionsScreen`, `NutritionInsightsScreen` (life_route_pages.dart:581,589,597,605) | only from the Food tab tiles `nutrition/presentation/tabs/food_tab.dart:129,158-176`; meal-reminder centre link `system_services.dart:134` (`/food/plan`) | 3 |

### A.4 Money (group: money)

| Pattern | Screen | Entry point | Taps |
|---|---|---|---|
| `/ledger` | `MoneyLedgerScreen` (money_route_pages.dart:320) | Money header «الدفتر» `money_hub.dart:73`; `WalletsSummaryCard` `:74`; tool `:510-513` | 2 |
| `/ledger/wallet/:id` | `WalletScreen` (:331) | ledger wallet rows `money_ledger_screen.dart:218,260`; wallet moon sheet «افتح المحفظة» `moon_sheet.dart:146-148` | 2 (via orbit moon) / 3 |
| `/ledger/transactions[?filters]` | `TransactionsScreen` (:344) | tool `money_hub.dart:514-519`; day-chat/search links (`LoggedRecordLinks`, life_route_pages.dart:306-310) | 2 |
| `/ledger/currencies` | `CurrenciesScreen` (:356) | net-worth card button `money_hub.dart:171,389`; Settings › Money `money_settings_section.dart:68` | 2 |
| `/budget[?tab=spending]` | `BudgetScreen` (:369) | header `money_hub.dart:76`; `BudgetStatusCard` `:77-83`; tool `:520`; budget widget (G) | 2 |
| `/goals[?tab=debts|obligations][&debt=|&obligation=]` | `GoalsScreen` (:413) | header `money_hub.dart:86`; tools jars/debts/bills `:521-532`; due-reminder tap (G) | 2 |
| `/goals/jar/:id` | `JarScreen` (:424) | `JarsCard` rings on the Money page `goals_cards.dart:280`; goals tiles `goals_tiles.dart:86` | 2 |

### A.5 Life: work, family, travel, growth, kitchen, lists, trackers (group: life)

| Pattern | Screen | Entry point | Taps |
|---|---|---|---|
| `/work` | `WorkScreen` (life_route_pages.dart:411) | `WorkTodayCard` `life_hubs.dart:101`; tool «اللوحات» `:106` | 2 |
| `/work/board/:id` | `BoardScreen` (:421) | work screen / Top 3 via `RoutedWorkRoutes` (:327-339) | 3 |
| `/work/projects` | `ProjectsScreen` (:429) | tool `life_hubs.dart:107` (also **Growth** tool `:209`) | 2 |
| `/work/project/:id` | `ProjectScreen` (:440) | projects screen | 3 |
| `/family` | `FamilyScreen` (:449) | `FamilyTodayCard` `life_hubs.dart:127`; tool `:132`; family digest tap (G) | 2 |
| `/family/person/:id` | `PersonScreen` (:460) | `FamilyTodayCard` rows `family_today_card.dart:53-55,145,172`; moon sheet `moon_sheet.dart:148-150`; birthday tap (G) | 2 |
| `/travel[?tab=documents|templates]` | `TravelScreen` (:474) | `TravelTodayCard` `life_hubs.dart:160`; tools `:165-177`; document-expiry tap (G) | 2 |
| `/travel/trip/:id` | `TripScreen` (:489) | `TravelTodayCard.onOpenTrip` `life_hubs.dart:160` | 2 |
| `/travel/template/:id` | `PackingTemplateScreen` (:500) | travel screen templates tab | 3 |
| `/growth` | `GrowthScreen` (:512) | `GrowthTodayCard` «كل الأهداف» `life_hubs.dart:202`; `growth_today_card.dart:96` | 2 |
| `/growth/goal/:id` | `GoalScreen` (:524) | `GrowthTodayCard` rows `growth_today_card.dart:152`; `life_services.dart:46` | 2 |
| `/sufra` | **redirect only** → `/sufra/tonight` (router.dart:689-693) | none | — |
| `/sufra/tonight`, `/sufra/pantry`, `/sufra/recipes`, `/sufra/rules`, `/sufra/history` | `TonightScreen`, `PantryScreen`, `RecipesScreen`, `KitchenRulesScreen`, `CookedHistoryScreen` (life_route_pages.dart:359,367,375,395,403) | Kitchen page: `SufraTodayCard` `life_hubs.dart:271-274`; 4 tool tiles `:280-298` | 2 |
| `/sufra/recipe/:id` | `RecipeScreen` (:387) | recipes screen / tonight (`sufra_nav.dart:36`) | 3 |
| `/lists` | `AllListsScreen` (:676) | **UNREACHABLE from any UI**: `LifeNav.allLists` (life_route_pages.dart:96) has no caller. Only link fallbacks land here (`LifeRecordLinks` `record_lists`/`record_list_items` without ids, :255-262) | — |
| `/lists/:table/:id` | `HostListsScreen` (:639) | budget plan item `budget_actions.dart:126`; trip screen `trip_screen.dart:316` (hosts: budget_items, trips, recipes, pantry — `lists/domain/record_list.dart:27-39`) | 3 |
| `/list/:id` | `ListScreen` (:660) | host-lists rows; kitchen lists `sufra_nav.dart:44`; search | 3–4 |
| `/modules` | `CustomModulesScreen` (:615) | "see all" in the trackers section of every planet except Faith/Health/Money while empty (`life_hubs.dart:342-366`); Settings › Life `life_settings_section.dart:80` | 2 |
| `/modules/module/:id` | `ModuleScreen` (:627) | tracker card on the planet page; tracker reminder tap (G) | 2 |

### A.6 Games (group: games)

| Pattern | Screen | Entry point | Taps |
|---|---|---|---|
| `/cinema` | `CinemaHallScreen` (fade-through, router.dart:785-789) | Games page `CinemaEntryCard`/scores card `life_hubs.dart:329-330` | 2 |
| `/cinema/game/:id` | `CinemaGameScreen` (iris transition, router.dart:790-797) | hall posters | 3 |
| `/saved-games[?text=]` | `SavedGamesScreen` | `SavedGamesShelf` «عرض الكل» `life_hubs.dart:333`; hall `cinema_hall_screen.dart:185`. The `?text=` (shared-link pre-fill) has **no producer**: `savedGamesOf` is never called | 2 |

### A.7 System (group: system)

| Pattern | Screen | Entry point | Taps |
|---|---|---|---|
| `/day[?day=&tab=summary&q=]` | `DayChatScreen` (system_route_pages.dart:117) | **only** the hand-over button of the home quick-add bar `task_panel.dart:224` (`quick_add_bar.dart:303-308`). `DayChatNav.summary` (system_route_pages.dart:80) has no caller | 1 |
| `/plans` | `PlanHistoryScreen` (:221) | Data centre tile «خططك» `data_centre_screen.dart:296-303` | 3 |
| `/plans/import` | `PlanImportScreen` (:237) | Data centre tile `:287-294`; Plans history; Android share/open-with (G) | 3 |
| `/plans/plan/:id[?tab=list]` | `PlanScreen` (:260) | home panel line `PlanChecklistStrip` `task_panel.dart:94` (only while a plan has an unticked line); plans history | 2 (strip) / 4 |
| `/search[?q=]` | `GlobalSearchScreen` (:142, fade-through) | Home header 🔍 `home_screen.dart:503-508` | 1 |
| `/notifications[?tab=]` | `NotificationCenterScreen` (:161) | Home header bell `home_screen.dart:513-516`; Settings row `system_settings_sections.dart:72` | 1 |
| `/ai[?q=]` | `AiChatScreen` new (:280) | last row of **every** planet page (`planet_page.dart:669-670`, `planet_ask_ai.dart:53-57`; supported: faith, health, money and all `LifeHubs` keys); new-chat button of the chat list | 2 + scroll |
| `/ai/chats` | `AiChatListScreen` (:299) | Settings › AI row `system_settings_sections.dart:170`; chat screen app bar `system_route_pages.dart:284` | 2 |
| `/ai/chat/:id` | `AiChatScreen` saved (:280) | chat list rows | 3 |
| `/together` | `TogetherHomeScreen` (:312) | Settings › Together row `system_settings_sections.dart:129` — **only door** | 2 |
| `/together/hall-of-fame`, `/together/know-me`, `/together/weekly`, `/together/goal` | `HallOfFameScreen`, `KnowMeScreen`, `WeeklyChallengeScreen`, `CoopGoalScreen` (router.dart:909-941) | Together home (system_route_pages.dart:314-317) | 3 |
| `/planet/:key[?item=refTable:refId]` | `PlanetModulePage` (planet_page.dart:49) | Home orrery: planet tap `home_screen.dart:346`, moon tap `:347` (`item=moon.id`); Neglect Radar cards `task_panel.dart:88` / `neglect_radar_card.dart:96,170,212`; search `planets`; widgets (G) | 1 |

### A.8 Planet pages as routes

Planet pages by key as the router sees them: `/planet/faith|health|money|work|family|growth|body|travel|sufra|games` and any user-made key (customise sheet «إضافة كوكب», `customize_sheet.dart:130,500`). Unknown key → in-page "world missing" (`planet_page.dart:293`, `_Missing`).
Long-press a planet on Home → `showPlanetCustomizeSheet` (`home_screen.dart:348`); the planet page header already has a ⚙-style button (`Icons.tune_rounded`, `planet_page.dart:482-489`) that opens the **same customise sheet** (look, weight, sources, move orbit, hide, reset, delete, show hidden, add — `customize_sheet.dart:33,87-130`). It is not an "area settings" page.

---

## B. The twelve frequent actions: today's tap count

Taps listed as `tap → tap`. "To finish" = including the committing tap. Assumes the right planet is hit on the moving orrery (no tap is spent on missing).

| # | Action | Path today | Taps to open the control | To finish | Evidence / edge cases |
|---|---|---|---|---|---|
| 1 | Log a prayer | Home → **prayer pointer on the astrolabe** → sheet «صلّيت» | 2 | 2 | `home_screen.dart:349` → `prayer_sheet.dart:178-184,43-79`. Pointer hit area is a circle of radius `max(0.075·core, 22)` px (`scene_controller.dart:717-725`), i.e. ≥ 44 px. Alt: Faith planet → `PrayerTodayCard` tap cycles the status (`faith_hub.dart:81`, `prayer_today_card.dart:167-168`) = 2. Sheet also offers «متأخر/فاتت/مسح» and links to times/tracker. Not possible before the adhan (`orbitUiPrayerNotYet`, prayer_sheet.dart:150-161). Iqama notification has «صلّيت» (0 taps in-app, G) |
| 2 | Mark a medicine taken | Home → Health planet → ✓ icon on the dose row | 2 | 2 | `health_hub.dart:100`, `today_doses_card.dart:163-172` (undo toast). Standing-alerts banner (if any) sits above it (`health_hub.dart:96`). Dose notification has Taken/Snooze/Skip buttons (0 taps in-app; `app_services.dart:76-77`) |
| 3 | Add an expense | (a) Home quick-add bar: tap field → type «صرفت 5 بنزين» → send; (b) Home → Money planet → «مصروف» pill → keypad sheet → save | (a) 2 · (b) 2 | (a) 2 · (b) 3 | (a) `task_panel.dart:217-233`, `quick_add_bar.dart:309`, `MoneyQuickAdd` `quick_add_handlers.dart:122`; (b) `money_hub.dart:71,428-466` (`showTransactionSheet`) |
| 4 | Add a task | (a) Home quick-add bar (field → send); (b) expand the panel (+1: grab/drag) → «＋ مهمة» row; (c) any planet page «＋» next to "no tasks today" | (a) 2 · (b) 2 · (c) 2 | (a) 2 · (b) 3 | `TaskQuickAdd` `quick_add_handlers.dart:66`; `_AddTaskRow` `task_panel.dart:189,205`; `world_modules.dart:36-47` |
| 5 | Continue the Quran where he stopped | Home → Faith planet → `QuranContinueCard` (opens the reader at the last ayah) | 2 | 2 | `faith_hub.dart:89`, `quran_continue_card.dart:42-44`. The card is the 4th item of the Faith page (after next-prayer, prayers, adhkar) — needs a scroll on most phones |
| 6 | Morning or evening adhkar | Home → Faith planet → the suggested set on `AdhkarTodayCard` | 2 | 2 | `faith_hub.dart:82`, `adhkar_today_card.dart:100-109` (a mini-tile per set; the time-suggested one is highlighted); opens `/adhkar/morning` or `/adhkar/evening` |
| 7 | Tasbeeh | Home → Faith planet → tasbeeh tile (in the adhkar card or FaithTools grid) | 2 | 2 | `adhkar_today_card.dart:128-129`; `faith_hub.dart:302` |
| 8 | Qibla | Home → Faith planet → `QiblaCard` | 2 | 2 | `faith_hub.dart:104` — the 9th item (below the Quran and Hifz cards): needs a scroll |
| 9 | Log a meal | Home → Body planet → `NutritionTodayCard` (opens `/body?tab=food`) → FAB «تسجيل سريع» → tap a food chip | 3 (sheet open) | **4** | `life_hubs.dart:232` passes only `onOpen` — the card's own quick-log button (`nutrition_today_card.dart:75-87`) is **not shown** on the hub; FAB `body_screen.dart:53`; "one tap on a chip is a logged meal" `quick_log_sheet.dart:22-23`. There is no meal handler in the quick-add bar (handlers: task, money, water, pain, mood, contact — `quick_add_handlers.dart:66-245`) |
| 10 | Start today's workout | Home → Body planet → `BodyTodayCard` → «ابدأ الجلسة» | 3 | 3 | `life_hubs.dart:231`, `today_tab.dart:50-58` (only if a plan exists, today is not a rest day and not complete) → `/body/gym/session` |
| 11 | Money left this month | Home → Money planet → read the "left/over" line on `BudgetStatusCard` | 1 (+ scroll: it is the 4th card, after net-worth, quick-add row and wallets) | detail: 2 | `money_hub.dart:76-84`, `budget_status_card.dart:107-113` (`budgetLeft`/`budgetOverBy`). Tap on the card → `/budget?tab=spending`. Budget widget shows it with 0 in-app taps (`widget_links.dart:20`) |
| 12 | Today's wird | Home → Faith planet → `WirdTodayCard` → ✓ (mark done) or book icon (read now) | 2 | 2 | `faith_hub.dart:90`, `wird_today_card.dart:165-192`; buttons exist only while a plan is started, not paused/met. No plan → card shows «ابدأ خطة» (:76-90) |

Result: **10 of the 12 are already ≤ 2 taps to finish**; the two over are the meal (4) and the workout (3). Several of the 2-tap ones sit below the fold on a planet page (Quran-continue, wird, qibla, budget line) and a tap on the right moving planet is assumed.

---

## C. Buried features (reachable only through Settings or one deep path)

| Feature | Exact path today | Other doors | Evidence |
|---|---|---|---|
| Together Mode (`/together` + hall of fame, know-me, weekly, goal) | Home ⚙ → Settings → «معًا» section → «أنتما الاثنان» | none. Two more Together rows are Settings-only sheets (`TogetherSettingsTile`, `OnlinePlayTile`) | `system_settings_sections.dart:120-145` |
| AI chats list (`/ai/chats`) and AI settings | Home ⚙ → Settings → AI section → «المحادثات» / key row | a **new** chat `/ai` is also the last row of every planet page | `system_settings_sections.dart:155-176`; `planet_page.dart:669-670` |
| Import (`/import`) | Home ⚙ → Settings → «بياناتك» section → «استيراد من النموذج الأوّلي»; also Data centre → Import | first run (onboarding exit `import`) | `system_settings_sections.dart:206-215`; `data_centre_screen.dart:303` |
| Home-screen widgets (`/settings/widgets`) | Home ⚙ → Settings → «الودجات» row | none | `system_settings_sections.dart:93-103` |
| Data centre / backup / restore / exports | Home ⚙ → Settings → «بياناتك» row → `/settings/data` (restore +1) | none | `system_settings_sections.dart:197-206` |
| AI plan export / "AI-ready summary" / CSV / JSON | Settings → Data centre → Export group | the day-chat piece button «اسأل الذكاء» opens the same bridge sheet | `data_centre_screen.dart:233-272`; `day_chat_actions.dart:185-187` |
| Plans history (`/plans`) and plan import (`/plans/import`) | Settings → Data centre → import group | the home panel's one-line strip (`/plans/plan/<id>?tab=list`) appears only while a plan has an unticked line; Android share/open-with → `/plans/import` | `data_centre_screen.dart:285-303`; `task_panel.dart:94`; `app/system_services.dart:258-264` |
| Design gallery (`/gallery`) | Settings → "Developer" section (always visible) | none | `settings_screen.dart:243-255` |
| Quran text/tajweed/translation settings | Settings → «القرآن» row (the reader has only a per-surah sheet) | none | `settings_screen.dart:131`; `quran_reader_screen.dart:339` |
| Notification groups & mutes (`/settings/notifications`) | Settings → «الإشعارات» section → groups row | the notification centre (bell) is the other, separate screen | `system_settings_sections.dart:75-81` |
| Money currencies / rates | Money page net-worth card (2 taps) or Settings › Money | — | `money_hub.dart:171`; `money_settings_section.dart:68` |
| Fasting tab, water tab, gym training days, gym session | Body page card → tab bar → (button). No hub tile for fasting/water | Settings › Life row (fasting) | `life_hubs.dart:231-249`; `plan_tab.dart:62-70` |
| Food library / plan / rules / insights | Body page → food card → Food tab tiles | meal reminder centre link (plan) | `food_tab.dart:158-176` |
| Lists index (`/lists`) | **no door** | link fallbacks only | `life_route_pages.dart:96` (no callers), `:255-262` |
| Prayer calculation, adhan, iqama, recitation, reminders | Settings → Faith section rows; adhan and recitation also as Faith-page tool tiles | prayer settings also from the prayer-times gear | `settings_screen.dart:98-148`; `faith_hub.dart:301,304` |
| Health settings (meal times, dose reminders, doctor summary, worry window, emergency number) | Settings → Health row | notification-centre link | `settings_screen.dart:153-167`; `health_settings_screen.dart:228-349` |
| Trackers/lists (`/modules`) | Planet page "see all" (non-Faith/Health/Money planets) or Settings › Life | — | `life_hubs.dart:342-366`; `life_settings_section.dart:76-82` |

---

## D. The four "talk to the app" doors

| Door | Route(s) | What it does | Who calls it | Network / privacy |
|---|---|---|---|---|
| **Daily chat** | `/day` (`?day=`, `?tab=chat|summary`, `?q=`) | He types his whole day; an **offline rules reader** splits it into pieces (task, ledger entry, prayer, pain, mood, note); one card per piece with «سجّلها / عدّلها / لأ», no apply-all; second tab «شو صار اليوم؟». Past days via `?day=`. (`day_chat/day_chat.dart:1-30`) | Only the hand-over button of the home quick-add bar (`task_panel.dart:224`). `DayChatNav.summary` is unused | No network, no AI (:6-8). Its only door out is the per-card «اسأل الذكاء», which opens the AI-bridge export sheet (`day_chat_actions.dart:185-187`). Health sentences stay notes (`HealthGuard`) |
| **AI chat** | `/ai`, `/ai/chats`, `/ai/chat/:id`, `/settings/ai` | Chat with his own Anthropic/OpenAI key; summary preview on the first Send; "will send" strip; conversations stored encrypted (`ai_chat/ai_chat.dart:1-25`) | Last row of every planet page (`planet_page.dart:669-670`; planets: faith, health, money, work, family, travel, growth, body, sufra, games — the last two get a null prompt, `planet_ask_ai.dart:36-46`); Settings › AI rows (`system_settings_sections.dart:163,170`). `AskAiButton`/`openAskAi` have no caller outside the package | Off until `AiSettings.outsideAllowed` (default off); a call only on an explicit tap; health/medication/food/family cut by `ChatSummaryScope` + `ChatContextFilter` (`ai_chat.dart:16-22`) |
| **AI bridge** | no route: `showAiBridgeExportSheet` (sheet) + the return half on `/plans/import` | Copy/share one JSON with his data summary + ready prompt + required answer shape to any AI app; bring a «خطة مدار» back (`ai_bridge/ai_bridge.dart:1-30`) | Data centre tile «استشارة ذكاء اصطناعي» (`data_centre_screen.dart:248-253`); day-chat card (`day_chat_actions.dart:187`); plus a separate "AI-ready summary" export tile (`:240-246`) | No network, no key. He hands the file over himself, so the chat's privacy filter does **not** apply (`ai_chat.dart:22-23`); the bridge has its own `HealthGuard` |
| **Plans import / history** | `/plans`, `/plans/import`, `/plans/plan/:id` | Validate a pasted/shared/file answer, one preview card per suggestion with Approve/Edit/Refuse, no apply-all; ticking list; history re-reads old plans against today's data (`ai_bridge.dart:14-43`) | Data centre tiles (`data_centre_screen.dart:285-303`); home strip (`task_panel.dart:94`); Android `ACTION_SEND` text/plain|json and `ACTION_VIEW` json (`AndroidManifest.xml:141-152`) → `/plans/import` (`system_services.dart:264`) | No network |

**Overlap (facts):**
- Four screens/sheets accept "text from him that Madar turns into records": quick-add bar (parses 6 kinds in `quick_add_handlers.dart`), daily chat (parses a day), plan import (parses an AI answer), and the AI chat (free text, no records). The bar already hands its text to the chat (`quick_add_bar.dart:221-229`), so a line can end up in either.
- Three separate ways to give an AI his data: AI chat (direct, filtered), AI bridge file (manual, unfiltered by the chat filter), AI-ready summary export. All three sit in different places (planet page, Data centre ×2, day-chat card).
- All writes by chat/bridge go through "one decision per card with undo" — same pattern in `day_chat` and `ai_bridge`.
- `/plans/plan/:id` and the home strip are the only post-import UI; there is no link from the daily chat or the AI chat to the plans list.

---

## E. The settings screens

Settings hub (`settings_screen.dart:48-261`) order: Personalisation (appearance, sound) · Faith (6 rows) · adhan-permissions card (:151) · Health (1 row) · Money (inline, 4 rows) · Life (inline, 5 rows) · Notifications · Widgets · Together (1 row + 2 sheet tiles) · AI (2 rows) · Motion & power (2 inline choices) · Privacy & security (1 row) · Your data (2 rows + note) · About (3 rows) · Developer (gallery).

| # | Route / screen | Setting groups in it (file) | Proposed home (plan R-S6 / R-S7) |
|---|---|---|---|
| 1 | `/settings` hub | the 15 sections above | the single grouped, searchable «الإعدادات»: المظهر، الصوت، القفل، التنبيهات، بياناتي، الذكاء، أدوات الشاشة، عن مدار |
| 2 | `/settings/appearance` (`appearance_screen.dart:43-114`) | Theme (5 themes, follow-system switch) · accent colour · language · digits | المظهر |
| 3 | `/settings/sound` (`sound_settings_screen.dart:45-110`) | General (sound, haptics, ambient) · volumes per category · sound profile | الصوت |
| 4 | `/settings/security` (`lock/presentation/security_settings.dart:159-194`) | App lock switch · fingerprint · change PIN · lock-after-leaving · remove PIN | القفل |
| 5 | `/settings/notifications` (`notification_settings_summary.dart`) | one row per notification group with its mute | التنبيهات (the bell/centre stays on Today) |
| 6 | `/settings/data` (`data_centre_screen.dart:183-317`) | Backup (encrypted backup, restore card) · Export (AI-ready summary, AI consult, CSV, JSON) · Import (plan import, plans history, prototype import) | بياناتي (R-S7) |
| 7 | `/settings/data/restore` (`restore_flow.dart`) | file → passphrase → preview → safety copy → done | بياناتي › استعادة |
| 8 | `/import` (`features/import/import_screen.dart`) | prototype-file importer | بياناتي › استيراد, plus first-run (R-S7) |
| 9 | `/settings/ai` (`ai_settings_screen.dart:66-206`) | outside-sending switch · service & model · API keys · reply (tokens, temperature) · privacy (delete all) | الذكاء |
| 10 | `/settings/widgets` (`widgets_settings.dart:32-106`) | 4 widget previews (prayer, meds, tasks, budget) · show-details switches · budget period | أدوات الشاشة |
| 11 | `/settings/licenses` (`licenses_screen.dart`) | fonts & sources credits | عن مدار |
| 12 | `/settings/prayer` (`prayer_settings_screen.dart:65-229`) | Location · calculation method (+custom Fajr/Isha) · Asr rule · manual adjustments · Hijri offset · high latitudes · clock format | ⚙ of الإيمان |
| 13 | `/settings/adhan` (`adhan_settings_screen.dart:189-461`) | Prayers · muezzin · alert (vibrate, full screen, quiet, snooze, volume) · try it. Plus the permissions card in the hub (`adhan_permissions_card.dart`) | ⚙ of الإيمان |
| 14 | `/settings/iqama` (`iqama_settings_screen.dart:113-206`) | Prayers (offsets) · sound & alert | ⚙ of الإيمان |
| 15 | `/settings/quran` (`quran_settings_screen.dart:71-155`) | Reading (layout, text size) · tajweed (colours, legend, source) · translation · link to recitation | ⚙ of الإيمان |
| 16 | `/settings/recitation` (`recitation_settings_screen.dart:176-330`) | Reciters · repeat & playback (ayah repeat, range, gap, speed, basmala) · offline listening (choose surahs, Wi-Fi only, storage) | ⚙ of الإيمان |
| 17 | `/settings/recitation/downloads` | one reciter's per-surah downloads | ⚙ of الإيمان › التلاوة |
| 18 | `/settings/reminders` (`reminders_settings_screen.dart:43-44`, widgets/adhkar_reminder_settings.dart:75-105, wird_reminder_settings.dart:147) | Adhkar reminders (morning/evening, offset) · wird reminders (per plan) | ⚙ of الإيمان (R-S6: "reminders → their features") |
| 19 | `/settings/health` (`health_settings_screen.dart:228-349`) | Medications (dose reminders, snooze, meal times) · appointments & labs (reminders, times, borderline margin) · doctor summary (period, sections, name) · wellbeing (worry window, emergency number, breathing sound) | ⚙ of صحتي |
| 20 | Money rows inline in the hub (`money_settings_section.dart:62-100`) | currencies & rates (routes to `/ledger/currencies`) · weeks-per-month sheet · week start choice · debts/bills reminders sheet | ⚙ of فلوسي |
| 21 | Life rows inline in the hub (`life_settings_section.dart:56-82`) | family reach-out reminders (sheet) → ⚙ عيلتي; water target (sheet) and fasting plan (→ `/body?tab=fasting`) → ⚙ صحتي; packing lists (→ `/travel?tab=templates`) → ⚙ سفري; trackers (→ `/modules`) → **not named in the plan** |
| 22 | Together rows (`system_settings_sections.dart:120-145`) | the two-player entry, its settings sheet (default play mode, split layout, hide from recents, clear history), online-play sheet (his own Firebase project) | «مع بعض» in عيلتي + two-player games in ألعابي (R-S7) |
| 23 | Motion & power (`settings_screen.dart:171-198`) | motion (system/reduced/full) · power (auto/battery saver) | **not named in the plan**; fits المظهر |
| 24 | About / Developer (`settings_screen.dart:214-255`) | version, credits, OSS licences · design gallery | عن مدار; gallery leaves settings (R-S6) |

Count check: rows 1–7 and 9–19 are exactly the 18 routes under `/settings` (row 17 is `/settings/recitation/downloads`); `/import` (row 8) is outside `/settings`; rows 20–24 are inline rows of the hub with no route of their own (except where noted).

---

## F. The planet pages

Every planet page is one `ListView` in this order (`planet_page.dart:566-671`): balance row (ring + state, :569-575) → the world's own hub (:579-588) → trackers section (`PlanetModulesSection`, :590) → «مهام اليوم» world tasks (:592-593) → «reasons» (max 5, :554,595-630) → moons list (:631-657) → sources (:658-665) → «اسأل عن هذا الكوكب» (:669-670). **So the balance explanation and the tools share one page**; the tools hub comes right under the score ring, the explanation (reasons, moons, sources) is below the tools.

| Planet (key) | Cards on the hub | Tool tiles | Header links | Evidence |
|---|---|---|---|---|
| الإيمان `faith` | 7: next-prayer, today's prayers, adhkar, Quran-continue, wird, Hifz plan, Qibla (+ Hifz reviews card once something is memorised) | 6 (mushaf, Hifz, recitation, tasbeeh, prayer history, adhan) | Quran «الفهرس» | `faith_hub.dart:78-105,298-305` |
| الصحة `health` | 4–7: standing alerts (if any), today's doses, wellbeing, pain now, next appointment (+ open questions, + lab flags when data) | 6 (meds, labs, appointments, wellbeing, breathing, doctor report sheet) | «السجل» | `health_hub.dart:94-113,462-478` |
| المال `money` | 6: net worth, quick-add row (3 pills), wallets, budget status, upcoming dues, jars | 6 (ledger, transactions, budget, jars, debts, bills) | 3 (ledger, budget, goals) | `money_hub.dart:70-91,507-534` |
| العمل `work` | 2: Top 3, work-today | 2 (boards, projects) | — | `life_hubs.dart:99-110` |
| العائلة `family` | 1: family-today | 2 (people, reminders sheet) | — | `life_hubs.dart:126-142` |
| السفر `travel` | 1: travel-today | 3 (trips, documents, packing lists) | — | `life_hubs.dart:159-179` |
| النمو `growth` | 1: growth-today | 1 (projects) — goals deliberately have no tile | — | `life_hubs.dart:201-211` |
| الجسد `body` | 2: body-today (training, water, fasting gauges), nutrition-today | 2 (plan, avoid); no tile for fasting, water, gym days or the 4 food screens | — | `life_hubs.dart:230-250` |
| السفرة `sufra` | 1: kitchen-tonight | 4 (pantry, recipes, rules, history) | — | `life_hubs.dart:269-300` |
| الألعاب `games` | 3: cinema entry, best scores, saved-games shelf (full-width) | 0 | shelf «عرض الكل» | `life_hubs.dart:328-333` |

Common to all ten (below the hub): trackers card (empty prompt shown except on Faith/Health/Money, `life_hubs.dart:348`), world tasks with «＋», reasons (none for dormant/`games`), moons, sources, ask-AI (all ten are "supported", `planet_ask_ai.dart:32-33`; prompts exist for eight).
Header of every planet page: back, name + state + percent, one `tune` button → customise sheet (`planet_page.dart:438-489`). No «؟» guide button exists.

---

## G. Entry points that carry a route string (what R-S10 must keep working)

**Key finding: a scheduled notification stores no route.** The payload is `{"ns","v","c","at","late","ls","h","d":{feature data}}` (`core/notifications/notification_envelope.dart:5-12,26-39`); the screen is computed **at tap time** by `AppNotificationRouter.locationOf` (`app/app_services.dart:92-101`). The notification centre rebuilds the tap from the stored payload and calls the same function (`center_models.dart:74,103`; `system_services.dart:105-108`). So old, already-scheduled notifications follow the router function, not an old URL. The backup stores **no route strings** either (grep of `features/data/**`, `core/settings/**`, `core/db/tables/**`: only `planetKey`, `refTable/refId` columns).

### G.1 Notifications (taps → route, `AppNotificationRouter.locationOf`)

| Producer (tap data) | Route emitted | Source |
|---|---|---|
| Adhkar reminder | `/adhkar/<morning|evening|afterPrayer|sleep|waking>` (no `prayer` query) | `app_services.dart:93-94` |
| Wird reminder | `/wird?plan=<id>` (or `/wird`) | `:95-96`, routes.dart:93 |
| Iqama notification body | `/prayer-tracker` | `iqama_services.dart:27-29` |
| Dose / refill / not-recorded | `/meds` or `/meds?tab=meds` (refill); the Taken/Snooze/Skip buttons never navigate | `health_services.dart:65-67` |
| Appointment reminder | `/record/appointments?highlight=<id>` | `:69` |
| Worry window | `/wellbeing?tab=worries` | `:70` |
| Debt due | `/goals?tab=debts&debt=<id>` | `money_services.dart:48` |
| Bill / obligation due | `/goals?tab=obligations&obligation=<id>` | `:49` |
| Family digest / birthday | `/family` / `/family/person/<id>` | `life_services.dart:139` |
| Travel document expiry | `/travel?tab=documents` | `:141` |
| Fasting notices | `/body?tab=fasting` | `:142` |
| Meal reminder | `/body?tab=food` | `:143` |
| Tracker reminder | `/modules/module/<id>` | `:145` |
| Adhan | not routed by the app router (the adhan host shows the full-screen adhan); from the centre it opens `/prayer-times` | `system_services.dart:107-108` |
| Hifz goal reminders, Together "your turn" | **no route** (`locationOf` returns null) — namespaces `hifz`, `together` | `notification_models.dart:215,227` |
| Recitation media notification | pushes `/now-playing` | `faith_services.dart:90` |
| Notification-centre "Reminder settings" links | `/settings/iqama`, `/settings/adhan`, `/settings/reminders`, `/settings/health`, `/record/appointments?highlight=`, `/body?tab=fasting`, `/food/plan`, `/goals…`, `/family`, `/travel?tab=documents`, `/modules[/module/<id>]` | `system_services.dart:117-149` |

### G.2 Android widgets — **these do persist route strings** (in the widget snapshot held by Android)

The route travels in the widget snapshot and in the launch intent extra `route` (≤ 200 chars) (`widget_links.dart:3-12`; `MadarWidgetsChannel.kt:142-145`). Dart only opens a route that matches the exact allow-list `WidgetLinks.isAllowed` (`widget_links.dart:37-52`):

| Widget | Route string | Source |
|---|---|---|
| Prayer | `/prayer-times` | `widget_links.dart:15` |
| Meds (widget and each dose) | `/meds` | `:18` |
| Budget | `/budget?tab=spending` | `:21` |
| Top 3 (widget) | `/planet/work` | `:24,28` |
| Top 3 task | `/planet/work?item=tasks:<id>` | `:31` |
| Top 3 kanban card | `/planet/work?item=boards:<boardId>` (else `/planet/work`) | `:35-36` |

Four widgets only (`android/app/src/main/res/xml/widget_info_{prayer,meds,tasks,budget}.xml`). A pinned widget keeps its old string until the app next rewrites its snapshot (`watchSystemServices`, app_services.dart:171-174).

### G.3 Share / open-with intents

Android `ACTION_SEND` (text/plain, application/json) and `ACTION_VIEW` (json via content/file) → `PlanShareRouter` → `go('/plans/import')` (`AndroidManifest.xml:141-152`, `system_services.dart:258-265`). Not routes inside a backup, but a link that must keep landing.

### G.4 Search, daily-chat links, Neglect Radar, moons (computed at open time, nothing persisted)

All go through `searchTargetOf` (`system_route_pages.dart:333-397`) → `LoggedRecordLinks.locationOf` (`life_route_pages.dart:292-321`) → `LifeRecordLinks.locationOf` (:195-265); `openSearchResult` (:416-422) is installed at `app/system_services.dart:61` (there is no `lib/app/search_opener*` file; the test is `test/app/search_opener_test.dart`). Route strings they can emit:
- **Planet:** `/planet/<key>` (search `planets`, `health_alerts` → `/planet/health`), `/planet/<planetKey>?item=tasks:<id>` (a task), `/planet/<key>?item=<moon.id>` (orrery moon tap `home_screen.dart:347`; radar `neglect_radar_card.dart:96`).
- **Faith:** `/quran/read` (`?ayah=s:a`), `/wird?plan=`, `/hifz`, `/hifz/plan/goals`, `/hifz/plan/map`, `/prayer-tracker?tab=history` (prayer logs).
- **Health:** `/record?tab=conditions|questions`, `/record`, `/record/lab/<id>`, `/record/appointments?highlight=<id>`, `/meds`, `/meds?tab=meds|courses`, `/wellbeing`, `/wellbeing?tab=habits|worries|pain`.
- **Money:** `/ledger`, `/ledger/wallet/<id>`, `/ledger/transactions?wallet=<id>`, `/budget`, `/goals`, `/goals?tab=debts[&debt=<id>]`, `/goals?tab=obligations[&obligation=<id>]`, `/goals/jar/<id>`.
- **Life:** `/family`, `/family/person/<id>`, `/work`, `/work/board/<id>`, `/work/projects`, `/work/project/<id>`, `/travel`, `/travel?tab=documents|templates`, `/travel/trip/<id>`, `/travel/template/<id>`, `/growth`, `/growth/goal/<id>`, `/body?tab=plan|fasting|water|avoid|food`, `/body/gym/exercise/<id>`, `/body/gym/days`, `/food/library|plan|rules`, `/sufra/pantry|recipes|recipe/<id>|history|rules`, `/modules`, `/modules/module/<id>`, `/lists`, `/lists/<table>/<id>`, `/list/<id>`, `/cinema`, `/cinema/game/<id>`, `/saved-games`.
- Other persisted keys that route logic depends on: `planetKey` in `planets`, `activity_log`, `tasks`, `habits`, `projects`, `custom_modules` (`core/db/tables/core_tables.dart:8,61,84`, `health_tables.dart:168`, `life_tables.dart:41,268`); moon ids are `refTable:refId`.

---

## H. DRAFT redirect table (to be confirmed — proposal only)

Assumptions (all **Proposed**; the plan fixes the structure, not the paths): Today = `/`; Map = `/map`; planets keep `/planet/:key` with keys faith, health (absorbs body), money, work, family, growth, travel, games, sufra; assistant = `/assistant`; tasks = `/tasks`; one settings = `/settings` (+ `#group`). Feature screens that stay inside a planet **keep their current paths** (no redirect needed): that is what keeps old links, widgets and search results valid for free. Only the rows marked **Yes** need an entry in the redirect function. Query strings must be carried over (`?tab=`, `?item=`, `?highlight=`, `?plan=`, `?q=`).

| Old route | Proposed new route | Redirect? | Note |
|---|---|---|---|
| `/` | `/` (Today); the orrery moves to `/map` | Yes (meaning changes) | R-S1/R-S2; widget links never target `/` |
| `/onboarding` | `/onboarding` (guide, R-G1) | No | already 6 steps today |
| `/settings` | `/settings` | No | one grouped screen |
| `/settings/appearance` | `/settings#appearance` | Yes | |
| `/settings/sound` | `/settings#sound` | Yes | |
| `/settings/security` | `/settings#lock` | Yes | |
| `/settings/notifications` | `/settings#notifications` | Yes | |
| `/settings/data`, `/settings/data/restore` | `/settings#my-data`, `/settings#my-data/restore` | Yes | بياناتي |
| `/settings/ai` | `/settings#ai` | Yes | الذكاء |
| `/settings/widgets` | `/settings#screen-tools` | Yes | أدوات الشاشة |
| `/settings/licenses` | `/settings#about` | Yes | |
| `/settings/prayer`, `/settings/adhan`, `/settings/iqama`, `/settings/quran`, `/settings/recitation`, `/settings/recitation/downloads?reciter=`, `/settings/reminders` | `/planet/faith/settings?section=prayer|adhan|iqama|quran|recitation|recitation-downloads|reminders` | Yes | notification-centre links (G.1) must use the new strings |
| `/settings/health` | `/planet/health/settings` | Yes | |
| `/import` | `/settings#my-data/import` (and first run) | Yes | |
| `/gallery` | none in release (debug/test route only) | Yes (→ `/settings`) | R-S6 |
| `/day[?day,tab,q]` | `/assistant?tab=chat|summary&day=&q=` | Yes | keep «nothing sent» rule for `q` |
| `/ai[?q=]` | `/assistant?ask=ai&q=` | Yes | explicit button, shows what is sent |
| `/ai/chats`, `/ai/chat/:id` | `/assistant?tab=chats`, `/assistant/ai/:id` | Yes | |
| `/plans`, `/plans/import`, `/plans/plan/:id[?tab=list]` | `/assistant?tab=plans`, `/assistant?action=paste-plan`, `/assistant/plan/:id[?tab=list]` | Yes | share intent (G.3) and the home strip must target the new ones |
| `/search`, `/notifications`, `/now-playing` | same | No | dock «بحث», bell |
| `/planet/body[?item=]` | `/planet/health[?item=]` | Yes | also migrate `planets`/`tasks`/`projects`/`modules` rows with `planetKey = body` (data task, not a route) |
| `/planet/work?item=tasks:<id>`, `/planet/work?item=boards:<id>`, `/planet/work` | same (widgets pinned before the update); the task editor may later open from `/tasks` | No (keep allow-list entries) | G.2 |
| `/planet/<other>[?item=]` | same | No | custom planet keys must keep working |
| `/prayer-times`, `/prayer-tracker`, `/adhkar*`, `/quran*`, `/wird`, `/hifz*`, `/qibla` | same (under الإيمان) | No | `/prayer-times` is also a widget string |
| `/meds`, `/record*`, `/wellbeing*` | same (under صحتي) | No | `/meds` is also a widget string |
| `/body`, `/body?tab=…`, `/body/gym/*`, `/food/*` | same paths, now inside صحتي | No | fasting/meal notification taps keep landing |
| `/food`, `/sufra` | existing redirects stay | No | |
| `/ledger*`, `/budget`, `/goals*` | same (under فلوسي) | No | `/budget?tab=spending` is a widget string |
| `/work*` | same (under شغلي) | No | Work board = view of work tasks (R-S5) |
| `/family*` | same (under عيلتي) | No | |
| `/together`, `/together/know-me`, `/together/weekly`, `/together/goal` | `/planet/family/together[/know-me|/weekly|/goal]` | Yes | couple specials → عيلتي |
| `/together/hall-of-fame` (and the head-to-head part of `/together`) | `/planet/games/together[/hall-of-fame]` | Yes | the two-player games → ألعابي. **`/together` is one screen with both halves — needs a decision on how it splits** |
| `/travel*`, `/growth*` | same | No | |
| `/sufra/*` | same | No | |
| `/cinema*`, `/saved-games` | same (under ألعابي) | No | |
| `/lists`, `/lists/:table/:id`, `/list/:id` | `/tasks?tab=lists`, `/tasks/lists/:table/:id`, `/tasks/list/:id` | Yes | R-S5 «one index of every list»; `/lists` has no UI door today |
| `/modules`, `/modules/module/:id` | **undecided** (the plan names custom modules among the task-like things but gives them no home) | Open | tracker reminder taps (G.1) land here |

---

## Surprises (where the code differs from, or adds to, PLAN.md Part R)

1. **Notifications need no redirect table.** Scheduled notifications store a namespace and feature data, never a route; the route is computed at tap time (G). The edge case "tapped after the update" is solved by changing `AppNotificationRouter.locationOf` and `centerSettingsLinks`. What really carries old route strings is the **widgets** (4 widgets, 6 strings, exact-match allow-list) — the plan's DoD edge case about widgets is the real one.
2. **Backups carry no routes** either; what must survive the Health+Body merge are `planetKey` values (`body`) in six tables, the `planets` rows, moon ids and `/planet/body?item=` links.
3. **Route count:** 102 `GoRoute`s (100 real screens + two redirect stubs), not "about 95"; the 18 settings routes match.
4. **Onboarding already has six steps** (welcome, style, location, adhan, lock, start; `onboarding_screen.dart:51`; steps 3–5 skippable). The plan's R-G1 list (pick your planets, reminders permission, "do you have a backup?") differs from what exists; the import exit already exists.
5. **A per-planet gear already exists** (`planet_page.dart:482-489`) but opens the customise sheet (rename, weight, sources, orbit, hide, delete), not area settings. R-S3's «⚙️ for that planet's own settings» would have to be split from it.
6. **Some "settings" screens are already reachable from planets as tools:** `/settings/adhan` and `/settings/recitation` are tiles in the Faith tool grid (`faith_hub.dart:301,304`), and currencies is on the Money page; so "area settings live in Settings only" is not fully true.
7. **"Five features live only in Settings" is slightly off:** a new AI chat is on every planet page (`planet_page.dart:669`), import is also on onboarding and in the Data centre, and `/plans` is also reachable from a home-panel strip while a plan has unticked lines. Together and widgets and the Data centre are truly Settings-only; the AI chats *list* is Settings-only.
8. **Ten planets, not nine:** the seed has faith, health, family, work, money, growth, body, travel, **sufra and games** (`defaults.dart:130-263`); the plan's "eight planets" (Health+Body merged) plus السفرة equals nine, with games counted among the eight — consistent, but `games` is `weight: 0` and has no tool tiles, and `sufra` is a "dormant until she files a task" score.
9. **The daily chat has exactly one door** (the hand-over button in the home bar) — `DayChatNav.summary` is unused, so «شو صار اليوم؟» is reachable only by switching tab inside the chat. R-S4's "past days are a tab" is already a tab + day picker.
10. **Tap budget is closer than the plan implies:** 10 of 12 actions are already ≤ 2 taps to finish (B). The expensive ones are the meal log (4; the hub's nutrition card deliberately has no quick-log button, `life_hubs.dart:232`) and the workout (3). The bigger risk for R-P2 is scrolling: Quran-continue, wird, qibla and the budget line are below the fold of a planet page, and a test over the route graph will not see that.
11. **Dead or orphan wiring found:** `/lists` has no UI door; `savedGamesOf(sharedText)` and `DayChatNav.summary` and `HealthNav.settings` and `AskAiButton/openAskAi` have no callers; hifz-goal and Together "your turn" notifications have no tap route; adhkar reminder taps open `/adhkar/<set>` without `?prayer=` (`app_services.dart:94`), so an after-prayer reminder cannot open its prayer's set.
12. **Search opener location:** the brief and plan mention `lib/app/search_opener*`; no such file exists. The mapping is `searchTargetOf`/`openSearchResult` in `lib/core/routing/system_route_pages.dart:333-422`, installed by `lib/app/system_services.dart:61` (test: `test/app/search_opener_test.dart`).
13. **"Motion & power" and "custom trackers/modules" have no home in the plan's settings/planet lists** (E rows 21, 23; H last row).
14. **New un-wired code is already in the tree** (not in the router): `lib/features/today/domain/{objective,objective_engine,day_snapshot,objective_state,quick_add_wheel}.dart`, `guide/`, `ramadan/`, `reading/`, `hajj/`, `fasting/`, plus `lib/core/design/islamic_geometry/`. They did not change any route, entry point or count above.
15. **Planet pages have no "next action" and no guide button** (R-S3 «الآن» and «؟»): the first thing after the ring is the hub of cards, and the hub is different per planet (Faith 7 cards + 6 tiles vs Games 3 cards + 0 tiles; only Faith/Health/Money have a 6-tile grid).
